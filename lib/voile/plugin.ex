defmodule Voile.Plugin do
  @moduledoc """
  The behaviour that every Voile plugin must implement.

  A plugin is an Elixir module (typically the main module of an OTP application)
  that implements this behaviour and ships its own migrations, schemas,
  contexts, and optionally LiveView UI.

  ## Minimal Example

      defmodule VoileLockerLuggage do
        @behaviour Voile.Plugin

        @impl true
        def metadata do
          %{
            id: "locker_luggage",
            name: "Locker & Luggage",
            version: "1.0.0",
            author: "Your Institution",
            description: "Visitor locker management system",
            license_type: :free
          }
        end

        @impl true
        def on_install,    do: VoileLockerLuggage.Migrator.run()
        @impl true
        def on_activate,   do: :ok
        @impl true
        def on_deactivate, do: :ok
        @impl true
        def on_uninstall,  do: VoileLockerLuggage.Migrator.rollback()
        @impl true
        def on_update(_old, _new), do: VoileLockerLuggage.Migrator.run()
        @impl true
        def hooks,           do: []
        @impl true
        def routes,          do: []
        @impl true
        def settings_schema, do: []
      end
  """

  # ── Types ────────────────────────────────────────────────────────────────────

  @type license_type :: :free | :premium

  @type metadata :: %{
          required(:id) => String.t(),
          required(:name) => String.t(),
          required(:version) => String.t(),
          required(:author) => String.t(),
          required(:description) => String.t(),
          required(:license_type) => license_type(),
          optional(:min_voile_version) => String.t(),
          optional(:icon) => String.t(),
          optional(:tags) => [String.t()]
        }

  @type hook_entry :: {hook_name :: atom(), handler :: function()}

  @type route_entry :: {path :: String.t(), live_view :: module(), action :: atom()}

  @type setting_field :: %{
          required(:key) => atom(),
          required(:type) => :string | :integer | :boolean | :select,
          required(:label) => String.t(),
          optional(:required) => boolean(),
          optional(:default) => term(),
          optional(:secret) => boolean(),
          optional(:options) => [{String.t(), String.t()}]
        }

  # ── Callbacks ────────────────────────────────────────────────────────────────

  @doc """
  Returns a map describing this plugin.
  The `id` field is the primary identifier — it must be unique, snake_case,
  and never change after release.
  """
  @callback metadata() :: metadata()

  @doc """
  Called ONCE when the plugin is first installed.
  Run your migrations here. Must be idempotent (safe to call twice).

  Return `:ok` or `{:error, reason}`.
  """
  @callback on_install() :: :ok | {:error, term()}

  @doc """
  Called every time the plugin is activated (including after server restart).
  Do NOT run migrations here — they run in on_install/0.

  Return `:ok` or `{:error, reason}`.
  """
  @callback on_activate() :: :ok | {:error, term()}

  @doc """
  Called when the plugin is deactivated by an admin.
  Do NOT drop tables — data must persist.
  """
  @callback on_deactivate() :: :ok

  @doc """
  Called when an admin explicitly uninstalls the plugin with data removal.
  This should rollback your migrations (drops tables).

  WARNING: This permanently destroys plugin data.
  """
  @callback on_uninstall() :: :ok | {:error, term()}

  @doc """
  Called when a plugin is updated to a new version.
  Receives the old and new version strings.
  Default implementation: run pending migrations.

  Return `:ok` or `{:error, reason}`.
  """
  @callback on_update(old_version :: String.t(), new_version :: String.t()) ::
              :ok | {:error, term()}

  @doc """
  Returns a list of `{hook_name, handler_function}` tuples.
  Called by PluginManager during activation to register hook handlers.

  Example:

      def hooks do
        [
          {:dashboard_widgets, &__MODULE__.add_widget/1},
          {:collection_before_save, &__MODULE__.enrich_collection/1}
        ]
      end
  """
  @callback hooks() :: [hook_entry()]

  @doc """
  Returns a list of `{path, live_view_module, action}` tuples.
  These are mounted under `/manage/plugins/:plugin_id/...` dynamically.

  Example:

      def routes do
        [
          {"/", VoileLockerLuggage.Web.IndexLive, :index},
          {"/settings", VoileLockerLuggage.Web.SettingsLive, :index},
          {"/:id", VoileLockerLuggage.Web.ShowLive, :show}
        ]
      end
  """
  @callback routes() :: [route_entry()]

  @doc """
  Returns a list of setting field definitions for this plugin.
  Used by the admin UI to render a settings form automatically.

  Example:

      def settings_schema do
        [
          %{key: :api_key, type: :string, label: "API Key", required: true, secret: true},
          %{key: :max_lockers, type: :integer, label: "Max Lockers", default: 50}
        ]
      end
  """
  @callback settings_schema() :: [setting_field()]

  # ── Helper ───────────────────────────────────────────────────────────────────

  @doc """
  Check if a module implements the Voile.Plugin behaviour.
  """
  def plugin?(module) do
    Code.ensure_loaded?(module) and
      function_exported?(module, :metadata, 0) and
      function_exported?(module, :on_install, 0) and
      function_exported?(module, :hooks, 0)
  end
end
