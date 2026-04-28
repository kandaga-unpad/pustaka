defmodule Voile.PluginManager do
  @moduledoc """
  Manages the full lifecycle of plugins in Voile.

  Uses an ETS table for the plugin registry so `active?/1` and `status/1`
  are concurrent reads with no GenServer bottleneck. State-changing operations
  (install, activate, etc.) go through GenServer calls.

  ## Plugin States

      :installed  → on_install/0 ran, migrations done, not yet active
      :active     → on_activate/0 ran, hooks registered, fully running
      :inactive   → on_deactivate/0 ran, hooks removed, data intact
      :error      → install or activate failed
      :uninstalled → on_uninstall/0 ran, data optionally removed

  ## Usage

      Voile.PluginManager.install("Elixir.VoileLockerLuggage")
      Voile.PluginManager.activate("Elixir.VoileLockerLuggage")
      Voile.PluginManager.deactivate("Elixir.VoileLockerLuggage")
      Voile.PluginManager.uninstall("Elixir.VoileLockerLuggage", remove_data: true)
  """

  use GenServer
  require Logger

  alias Voile.{Plugins, Hooks}

  @ets_table :voile_plugins_registry

  # ── Public API — Reads (direct ETS, no GenServer call) ───────────────────────

  @doc "Check if a plugin is currently active."
  def active?(module) when is_atom(module) do
    case :ets.lookup(@ets_table, module) do
      [{^module, :active}] -> true
      _ -> false
    end
  end

  @doc "Get the current status of a plugin. Accepts either an atom or a module string."
  def status(module) when is_atom(module) do
    case :ets.lookup(@ets_table, module) do
      [{^module, status}] -> status
      _ -> :unknown
    end
  end

  def status(module_str) when is_binary(module_str) do
    module = String.to_existing_atom(module_str)
    status(module)
  end

  @doc "List all known plugins and their states."
  def list_all do
    :ets.tab2list(@ets_table) |> Map.new()
  end

  @doc "List only active plugin modules."
  def list_active do
    :ets.match_object(@ets_table, {:_, :active})
    |> Enum.map(fn {module, _} -> module end)
  end

  @doc """
  Returns plugin modules that are loaded in the VM but not yet installed.

  Scans all started OTP applications, derives the likely root module name by
  camelising the app atom (e.g. `:voile_locker_luggage` → `VoileLockerLuggage`),
  tries to load it, and keeps those that implement the Voile.Plugin contract.
  Filters out modules already recorded in the database.
  """
  def discover_available do
    installed =
      try do
        Plugins.list_plugins() |> Enum.map(& &1.module) |> MapSet.new()
      rescue
        _ -> MapSet.new()
      end

    Application.loaded_applications()
    |> Enum.flat_map(fn {app, _desc, _vsn} ->
      module = app_to_module(app)
      module_str = module && Atom.to_string(module)

      if Code.ensure_loaded?(module) and plugin_module?(module) and
           module_str not in installed do
        meta = module.metadata()

        [
          %{
            module: module_str,
            name: meta.name,
            version: meta.version,
            description: Map.get(meta, :description, ""),
            author: Map.get(meta, :author, "")
          }
        ]
      else
        []
      end
    end)
    |> Enum.sort_by(& &1.name)
  end

  # Derives the conventional root module for an OTP app atom.
  # e.g. :voile_locker_luggage -> VoileLockerLuggage  (i.e. :"Elixir.VoileLockerLuggage")
  defp app_to_module(app) do
    camelized =
      app
      |> Atom.to_string()
      |> Macro.camelize()

    Module.concat([camelized])
  rescue
    _ -> nil
  end

  defp plugin_module?(nil), do: false

  defp plugin_module?(module) do
    function_exported?(module, :metadata, 0) and
      function_exported?(module, :on_install, 0) and
      function_exported?(module, :routes, 0)
  rescue
    _ -> false
  end

  # ── Public API — Writes (go through GenServer) ───────────────────────────────

  @doc "Install a plugin for the first time (runs migrations)."
  def install(module_str) when is_binary(module_str) do
    GenServer.call(__MODULE__, {:install, module_str}, 60_000)
  end

  @doc "Activate an installed plugin (registers hooks)."
  def activate(module_str) when is_binary(module_str) do
    GenServer.call(__MODULE__, {:activate, module_str}, 30_000)
  end

  @doc "Deactivate a plugin (removes hooks, keeps data)."
  def deactivate(module_str) when is_binary(module_str) do
    GenServer.call(__MODULE__, {:deactivate, module_str})
  end

  @doc """
  Uninstall a plugin.

  Options:
  - `remove_data: true` — calls on_uninstall/0 which drops tables.
    Default is `false` (keeps data, just marks as uninstalled).
  """
  def uninstall(module_str, opts \\ []) when is_binary(module_str) do
    GenServer.call(__MODULE__, {:uninstall, module_str, opts}, 60_000)
  end

  @doc """
  Update a plugin to a new version.
  Runs on_update/2 with old and new version strings.
  """
  def update(module_str) when is_binary(module_str) do
    GenServer.call(__MODULE__, {:update, module_str}, 60_000)
  end

  # ── GenServer ────────────────────────────────────────────────────────────────

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    @ets_table =
      :ets.new(@ets_table, [
        :named_table,
        :public,
        :set,
        read_concurrency: true
      ])

    {:ok, %{}, {:continue, :rehydrate}}
  end

  @impl true
  def handle_continue(:rehydrate, state) do
    plugins =
      try do
        Plugins.list_plugins()
      rescue
        e in [Postgrex.Error, Ecto.QueryError] ->
          Logger.debug(
            "[PluginManager] Could not load plugins (likely missing plugin table): #{inspect(e)}"
          )

          []
      end

    Enum.each(plugins, fn record ->
      try do
        module = String.to_existing_atom(record.module)
        status_atom = String.to_existing_atom(to_string(record.status))
        :ets.insert(@ets_table, {module, status_atom})

        if status_atom == :active do
          case safe_callback(module, :on_activate, []) do
            :ok ->
              register_hooks(module)
              Logger.info("[PluginManager] Reactivated: #{inspect(module)}")

            {:error, reason} ->
              Logger.error(
                "[PluginManager] Failed to reactivate #{inspect(module)}: #{inspect(reason)}"
              )

              :ets.insert(@ets_table, {module, :error})

              Plugins.update_plugin_status(record.plugin_id, :error,
                error_message: "Reactivation failed: #{inspect(reason)}"
              )
          end
        end
      rescue
        ArgumentError ->
          Logger.warning(
            "[PluginManager] Plugin module #{record.module} not found in code. " <>
              "The plugin OTP app may not be loaded. Skipping."
          )
      end
    end)

    {:noreply, state}
  end

  # ── Install ──────────────────────────────────────────────────────────────────

  @impl true
  def handle_call({:install, module_str}, _from, state) do
    module = String.to_existing_atom(module_str)

    with :ok <- validate_plugin(module),
         :ok <- check_not_installed(module),
         :ok <- safe_callback(module, :on_install, []) do
      meta = module.metadata()

      Plugins.upsert_plugin(%{
        module: Atom.to_string(module),
        plugin_id: meta.id,
        name: meta.name,
        version: meta.version,
        author: Map.get(meta, :author, ""),
        description: Map.get(meta, :description, ""),
        license_type: to_string(meta.license_type),
        status: :installed,
        installed_at: DateTime.utc_now() |> DateTime.truncate(:second)
      })

      :ets.insert(@ets_table, {module, :installed})
      Logger.info("[PluginManager] Installed: #{inspect(module)}")
      {:reply, :ok, state}
    else
      {:error, reason} = error ->
        try do
          meta = module.metadata()

          Plugins.upsert_plugin(%{
            module: Atom.to_string(module),
            plugin_id: meta.id,
            name: meta.name,
            version: meta.version,
            status: :error,
            error_message: inspect(reason)
          })

          :ets.insert(@ets_table, {module, :error})
        rescue
          _ -> :ok
        end

        Logger.error("[PluginManager] Install failed for #{inspect(module)}: #{inspect(reason)}")

        {:reply, error, state}
    end
  end

  # ── Activate ─────────────────────────────────────────────────────────────────

  @impl true
  def handle_call({:activate, module_str}, _from, state) do
    module = String.to_existing_atom(module_str)

    with :ok <- validate_plugin(module),
         :ok <- check_installed_or_inactive(module),
         :ok <- safe_callback(module, :on_activate, []) do
      register_hooks(module)
      meta = module.metadata()
      Plugins.update_plugin_status(meta.id, :active)
      :ets.insert(@ets_table, {module, :active})

      Logger.info("[PluginManager] Activated: #{inspect(module)}")
      {:reply, :ok, state}
    else
      {:error, reason} = error ->
        Logger.error("[PluginManager] Activate failed for #{inspect(module)}: #{inspect(reason)}")

        {:reply, error, state}
    end
  end

  # ── Deactivate ───────────────────────────────────────────────────────────────

  @impl true
  def handle_call({:deactivate, module_str}, _from, state) do
    module = String.to_existing_atom(module_str)

    with :ok <- check_active(module),
         :ok <- safe_callback(module, :on_deactivate, []) do
      Hooks.unregister_all(module)
      meta = module.metadata()
      Plugins.update_plugin_status(meta.id, :inactive)
      :ets.insert(@ets_table, {module, :inactive})

      Logger.info("[PluginManager] Deactivated: #{inspect(module)}")
      {:reply, :ok, state}
    else
      {:error, _reason} = error ->
        {:reply, error, state}
    end
  end

  # ── Uninstall ────────────────────────────────────────────────────────────────

  @impl true
  def handle_call({:uninstall, module_str, opts}, _from, state) do
    module = String.to_existing_atom(module_str)
    remove_data = Keyword.get(opts, :remove_data, false)

    # Deactivate hooks first
    Hooks.unregister_all(module)

    # Optionally destroy data
    if remove_data do
      case safe_callback(module, :on_uninstall, []) do
        :ok ->
          :ok

        {:error, reason} ->
          Logger.error(
            "[PluginManager] on_uninstall error for #{inspect(module)}: #{inspect(reason)}"
          )
      end
    end

    meta = module.metadata()
    Plugins.update_plugin_status(meta.id, :uninstalled)
    :ets.insert(@ets_table, {module, :uninstalled})

    Logger.info("[PluginManager] Uninstalled: #{inspect(module)} (data removed: #{remove_data})")

    {:reply, :ok, state}
  end

  # ── Update ───────────────────────────────────────────────────────────────────

  @impl true
  def handle_call({:update, module_str}, _from, state) do
    module = String.to_existing_atom(module_str)

    with :ok <- validate_plugin(module) do
      meta = module.metadata()
      record = Plugins.get_plugin_by_plugin_id(meta.id)
      old_version = if record, do: record.version, else: "0.0.0"
      new_version = meta.version

      if old_version == new_version do
        {:reply, {:error, :same_version}, state}
      else
        case safe_callback(module, :on_update, [old_version, new_version]) do
          :ok ->
            Plugins.upsert_plugin(%{
              plugin_id: meta.id,
              module: Atom.to_string(module),
              name: meta.name,
              version: new_version,
              status: if(status(module) == :active, do: :active, else: :installed)
            })

            Logger.info(
              "[PluginManager] Updated #{inspect(module)}: #{old_version} → #{new_version}"
            )

            {:reply, :ok, state}

          {:error, _} = error ->
            {:reply, error, state}
        end
      end
    else
      error -> {:reply, error, state}
    end
  end

  # ── Private Helpers ──────────────────────────────────────────────────────────

  defp validate_plugin(module) do
    cond do
      not Code.ensure_loaded?(module) ->
        {:error, "Module #{inspect(module)} not found. Is the plugin OTP app started?"}

      not Voile.Plugin.plugin?(module) ->
        {:error, "#{inspect(module)} does not implement the Voile.Plugin behaviour"}

      true ->
        :ok
    end
  end

  defp check_not_installed(module) do
    case status(module) do
      :unknown -> :ok
      :uninstalled -> :ok
      other -> {:error, "Plugin already in state: #{other}"}
    end
  end

  defp check_installed_or_inactive(module) do
    case status(module) do
      s when s in [:installed, :inactive] -> :ok
      :unknown -> {:error, "Plugin not installed. Call install/1 first."}
      :active -> {:error, "Plugin is already active."}
      other -> {:error, "Cannot activate from state: #{other}"}
    end
  end

  defp check_active(module) do
    case status(module) do
      :active -> :ok
      _ -> {:error, "Plugin is not active."}
    end
  end

  defp safe_callback(module, callback, args) do
    result = apply(module, callback, args)

    case result do
      :ok -> :ok
      {:ok, _} -> :ok
      {:error, _} = err -> err
      other -> {:error, "Unexpected return from #{callback}: #{inspect(other)}"}
    end
  rescue
    e -> {:error, Exception.message(e)}
  end

  defp register_hooks(module) do
    module.hooks()
    |> Enum.each(fn {hook_name, handler} ->
      Hooks.register(hook_name, handler, owner: module)
    end)
  end
end
