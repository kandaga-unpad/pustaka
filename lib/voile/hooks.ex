defmodule Voile.Hooks do
  @moduledoc """
  Action and filter hook system for Voile plugins.

  Uses `:persistent_term` for hook storage, providing zero-cost concurrent
  reads. Registration and unregistration go through a GenServer to serialize
  writes to `:persistent_term`.

  ## Action Hooks

  Plugins react to events. Return values are ignored.

      Voile.Hooks.run_action(:visitor_checked_in, %{visitor_id: id})

  ## Filter Hooks

  Plugins transform data. Each handler receives the accumulated value
  and must return a possibly-modified version.

      widgets = Voile.Hooks.run_filter(:dashboard_widgets, base_widgets)

  ## Registering Handlers

      Voile.Hooks.register(:dashboard_widgets, &MyPlugin.add_widget/1,
        owner: MyPlugin, priority: 30)

  ## Unregistering (on plugin deactivation)

      Voile.Hooks.unregister_all(MyPlugin)
  """

  use GenServer
  require Logger

  @type hook_name :: atom()
  @type hook_entry :: %{handler: function(), owner: module(), priority: integer()}

  # ── Public API — Reads (no GenServer call, direct persistent_term) ───────────

  @doc """
  Run action hooks. All handlers are called with `payload`.
  Return values are ignored. Errors in one handler do NOT stop others.
  """
  @spec run_action(hook_name(), term()) :: :ok
  def run_action(hook_name, payload \\ nil) do
    get_handlers(hook_name)
    |> Enum.each(fn %{handler: handler, owner: owner} ->
      try do
        handler.(payload)
      rescue
        e ->
          Logger.error(
            "[Hooks] Action handler error for :#{hook_name} " <>
              "(owner: #{inspect(owner)}): #{Exception.message(e)}"
          )
      end
    end)

    :ok
  end

  @doc """
  Run filter hooks. Handlers are called in priority order, each receiving
  the return value of the previous. The final accumulated value is returned.

  If a handler raises, the error is logged and the previous value is kept.
  """
  @spec run_filter(hook_name(), term()) :: term()
  def run_filter(hook_name, initial_value) do
    get_handlers(hook_name)
    |> Enum.reduce(initial_value, fn %{handler: handler, owner: owner}, acc ->
      try do
        handler.(acc)
      rescue
        e ->
          Logger.error(
            "[Hooks] Filter handler error for :#{hook_name} " <>
              "(owner: #{inspect(owner)}): #{Exception.message(e)}"
          )

          acc
      end
    end)
  end

  @doc "List all registered hook names."
  def list_hooks do
    GenServer.call(__MODULE__, :list_hooks)
  end

  @doc "Get all handlers for a specific hook (for debugging/inspection)."
  def list_handlers(hook_name) do
    get_handlers(hook_name)
  end

  # ── Public API — Writes (go through GenServer) ────────────────────────────────

  @doc """
  Register a handler for a named hook.

  Options:
  - `owner:` (module) — used to unregister all hooks for a plugin at once
  - `priority:` (integer) — lower numbers run first, default 50
  """
  def register(hook_name, handler, opts \\ [])
      when is_atom(hook_name) and is_function(handler) do
    GenServer.call(__MODULE__, {:register, hook_name, handler, opts})
  end

  @doc "Unregister ALL hooks registered by a specific plugin module."
  def unregister_all(owner_module) when is_atom(owner_module) do
    GenServer.call(__MODULE__, {:unregister_all, owner_module})
  end

  # ── GenServer ────────────────────────────────────────────────────────────────

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    # State tracks which hook names we've registered, for cleanup
    {:ok, %{known_hooks: MapSet.new()}}
  end

  @impl true
  def handle_call({:register, hook_name, handler, opts}, _from, state) do
    entry = %{
      handler: handler,
      owner: Keyword.get(opts, :owner),
      priority: Keyword.get(opts, :priority, 50)
    }

    current = get_handlers(hook_name)
    updated = Enum.sort_by([entry | current], & &1.priority)
    :persistent_term.put({__MODULE__, hook_name}, updated)

    new_state = %{state | known_hooks: MapSet.put(state.known_hooks, hook_name)}
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call({:unregister_all, owner_module}, _from, state) do
    Enum.each(state.known_hooks, fn hook_name ->
      current = get_handlers(hook_name)
      filtered = Enum.reject(current, &(&1.owner == owner_module))
      :persistent_term.put({__MODULE__, hook_name}, filtered)
    end)

    {:reply, :ok, state}
  end

  @impl true
  def handle_call(:list_hooks, _from, state) do
    hooks =
      state.known_hooks
      |> MapSet.to_list()
      |> Enum.filter(fn hook_name ->
        get_handlers(hook_name) != []
      end)

    {:reply, hooks, state}
  end

  # ── Private ──────────────────────────────────────────────────────────────────

  defp get_handlers(hook_name) do
    :persistent_term.get({__MODULE__, hook_name}, [])
  end
end
