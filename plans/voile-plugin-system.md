# Voile Plugin System — Corrected Implementation Guide

> A production-ready plugin architecture for **Voile** (Elixir/Phoenix 1.8).
> Enables institutions to extend Voile with custom features without forking the core.
>
> This document is the corrected version of the original plan, fixing critical issues
> identified during architectural review while preserving the good design decisions.

---

## Table of Contents

1. [Design Goals](#1-design-goals)
2. [Architecture Overview](#2-architecture-overview)
3. [How Plugin Data Works](#3-how-plugin-data-works)
4. [Core Files to Add to Voile](#4-core-files-to-add-to-voile)
   - 4.1 [Voile.Plugin — Behaviour Contract](#41-voileplugin--behaviour-contract)
   - 4.2 [Voile.Plugin.Migrator — Per-Plugin Migration Runner](#42-voilepluginmigrator--per-plugin-migration-runner)
   - 4.3 [Voile.Hooks — Action & Filter System](#43-voilehooks--action--filter-system)
   - 4.4 [Voile.PluginManager — Lifecycle Manager](#44-voilepluginmanager--lifecycle-manager)
   - 4.5 [Voile.PluginRecord — Ecto Schema](#45-voilepluginrecord--ecto-schema)
   - 4.6 [Voile.Plugins — Context Module](#46-voileplugins--context-module)
5. [Plugin Lifecycle](#5-plugin-lifecycle)
   - 5.1 [Install](#51-install)
   - 5.2 [Activate / Deactivate](#52-activate--deactivate)
   - 5.3 [Uninstall](#53-uninstall)
   - 5.4 [Update](#54-update)
6. [Dynamic Plugin Routing](#6-dynamic-plugin-routing)
7. [Plugin Settings System](#7-plugin-settings-system)
8. [Wiring Into Voile — Host App Changes](#8-wiring-into-voile--host-app-changes)
   - 8.1 [Application Supervisor](#81-application-supervisor)
   - 8.2 [Router](#82-router)
   - 8.3 [Dashboard Hook Integration](#83-dashboard-hook-integration)
   - 8.4 [Sidebar Navigation Hook](#84-sidebar-navigation-hook)
   - 8.5 [Catalog Context Hooks](#85-catalog-context-hooks)
9. [Writing a Plugin — Developer Contract](#9-writing-a-plugin--developer-contract)
   - 9.1 [Required Files](#91-required-files)
   - 9.2 [Implementing the Behaviour](#92-implementing-the-behaviour)
   - 9.3 [Plugin Tables & Schemas](#93-plugin-tables--schemas)
   - 9.4 [Hooks](#94-hooks)
   - 9.5 [Plugin Settings](#95-plugin-settings)
   - 9.6 [Plugin LiveViews](#96-plugin-liveviews)
10. [Error Handling & Safety](#10-error-handling--safety)
11. [Naming Conventions & Rules](#11-naming-conventions--rules)
12. [Testing Plugins](#12-testing-plugins)
13. [Implementation Phases](#13-implementation-phases)
14. [Complete File Tree Reference](#14-complete-file-tree-reference)

---

## 1. Design Goals

Voile is an Apache 2.0 GLAM management system. Different institutions (universities, museums,
archives, public libraries) have unique needs that don't belong in the core:

- A university library needs **locker/luggage management** for visitors
- A museum needs **exhibit rotation scheduling** tied to collections
- An archive needs **digitization workflow tracking** for items
- A public library needs **ISBN lookup enrichment** for new acquisitions

**The plugin system allows institutions to build these as separate OTP apps** that:

1. Ship their own database migrations and schemas
2. Register hooks to extend core behaviour (add dashboard widgets, modify save pipelines, etc.)
3. Mount their own LiveView UI under `/manage/plugins/:plugin_id/...`
4. Store configuration in Voile's database
5. Can be installed, activated, deactivated, and uninstalled by admins at runtime

**Explicit non-goals:**

- No plugin marketplace or automatic download/install from the web
- No sandboxing or untrusted code execution — plugins are trusted Elixir code
- No hot code loading — adding a plugin requires adding the dep to `mix.exs` and redeploying
- No inter-plugin dependencies or resolution (keep it simple)

---

## 2. Architecture Overview

```
┌──────────────────────────────────────────────────────────────────┐
│                       Voile Host App                             │
│                                                                  │
│  ┌──────────────────┐    ┌─────────────────────────────────┐     │
│  │  PluginManager   │    │         Voile.Hooks              │     │
│  │  GenServer+ETS   │    │  persistent_term backed          │     │
│  │                  │    │                                  │     │
│  │ - ETS registry   │    │ - register/3  (GenServer write)  │     │
│  │ - install/1      │    │ - run_action/2 (direct read)     │     │
│  │ - activate/1     │    │ - run_filter/2 (direct read)     │     │
│  │ - deactivate/1   │    │ - unregister_all/1               │     │
│  └────────┬─────────┘    └─────────────────────────────────┘     │
│           │ calls                                                │
│           ▼                                                      │
│  ┌──────────────────────────────────────────────────────┐        │
│  │              Voile.Plugin (Behaviour)                 │        │
│  │  metadata/0  on_install/0  on_activate/0             │        │
│  │  on_deactivate/0  on_uninstall/0  on_update/2        │        │
│  │  hooks/0  routes/0  nav/0  settings_schema/0          │        │
│  └──────────────────────────────────────────────────────┘        │
│                                                                  │
│  ┌────────────────────┐   ┌────────────────────────────┐         │
│  │  Voile.Repo        │   │  voile_plugins table       │         │
│  │  (Ecto Repo)       │   │  (plugin state + settings) │         │
│  └────────┬───────────┘   └────────────────────────────┘         │
│           │                                                      │
│    Shared PostgreSQL DB                                          │
│           │                                                      │
│  ┌────────┴───────────────────────────────────────────────┐      │
│  │               Tables in the same DB                    │      │
│  │                                                        │      │
│  │  [Voile core tables]                                   │      │
│  │  users, collections, items, visitors, fines ...        │      │
│  │                                                        │      │
│  │  [Plugin tables — namespaced with plugin_ prefix]      │      │
│  │  plugin_locker_luggage_lockers                         │      │
│  │  plugin_locker_luggage_sessions                        │      │
│  │  plugin_isbn_lookup_cache                              │      │
│  │  plugin_exhibit_scheduler_rotations                    │      │
│  └────────────────────────────────────────────────────────┘      │
└──────────────────────────────────────────────────────────────────┘
         ▲                    ▲                   ▲
         │                    │                   │
  ┌──────┴───────┐   ┌───────┴──────────┐  ┌─────┴───────────┐
  │   Plugin A   │   │   Plugin B       │  │   Plugin C      │
  │  (Locker     │   │  (ISBN Lookup)   │  │  (Exhibit       │
  │   Luggage)   │   │                  │  │   Scheduler)    │
  │              │   │                  │  │                 │
  │ priv/        │   │ priv/            │  │ priv/           │
  │  migrations/ │   │  migrations/     │  │  migrations/    │
  └──────────────┘   └──────────────────┘  └─────────────────┘
```

**Key design decisions vs. the original plan:**

| Decision         | Original Plan                              | This Version                                                     | Why                                                                                                                                       |
| ---------------- | ------------------------------------------ | ---------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------- |
| Hook storage     | GenServer state                            | `:persistent_term`                                               | Zero-cost reads; hooks fire on every save/query                                                                                           |
| Plugin registry  | GenServer state                            | ETS table                                                        | Concurrent reads; no bottleneck on `active?/1`                                                                                            |
| Repo proxy       | `Voile.Plugin.Repo` macro                  | Plugins use `Voile.Repo` directly                                | Always complete, zero maintenance                                                                                                         |
| Plugin routes    | Compile-time `use` macro in router         | Dynamic catch-all `/:plugin_id/*path`                            | No recompile needed for plugin install                                                                                                    |
| Update flow      | Reuse `on_install/0`                       | Dedicated `on_update/2` callback                                 | Prevents conflating install with update                                                                                                   |
| Migration safety | No collision detection                     | Version collision validation                                     | Prevents silent migration skipping                                                                                                        |
| Public API type  | `install(module)` accepts atom             | `install(module_str)` accepts string                             | Plugins are path deps compiled before host; atom table has a finite limit; `String.to_existing_atom` resolves safely inside the GenServer |
| DB module column | `inspect(module)` → `"VoileLockerLuggage"` | `Atom.to_string(module)` → `"Elixir.VoileLockerLuggage"`         | Only the full-prefixed form round-trips with `String.to_existing_atom`                                                                    |
| Plugin discovery | Manual                                     | `discover_available/0` scans `Application.loaded_applications()` | Admin UI shows "not yet installed" plugins automatically                                                                                  |

---

## 3. How Plugin Data Works

### 3.1 The Strategy: Shared DB, Namespaced Tables

Voile uses **one PostgreSQL database**. Plugins add tables to this same database.
There is no second database, no schema separation, no dynamic connection strings.

**Rules for plugin table naming:**

| Rule                                      | Example                                  |
| ----------------------------------------- | ---------------------------------------- |
| Prefix all tables with `plugin_`          | `plugin_locker_luggage_lockers`          |
| Use the plugin's `id` as the next segment | `plugin_isbn_lookup_cache`               |
| Use a meaningful suffix for the entity    | `plugin_exhibit_scheduler_rotations`     |
| Never reuse core Voile table names        | users, collections, items are off-limits |

### 3.2 Plugin Migrations

Plugins ship their migrations in `priv/migrations/` inside their OTP app.
These are **standard Ecto migrations** — nothing special:

```elixir
# priv/migrations/20240601000001_create_plugin_locker_luggage_lockers.exs
defmodule VoileLockerLuggage.Migrations.CreateLockers do
  use Ecto.Migration

  def change do
    create table(:plugin_locker_luggage_lockers, primary_key: false) do
      add :id,          :binary_id, primary_key: true
      add :locker_number, :string, null: false
      add :status,      :string, default: "available"
      add :node_id,     :integer  # soft ref to Voile core nodes table

      timestamps()
    end

    create unique_index(:plugin_locker_luggage_lockers, [:locker_number, :node_id])
    create index(:plugin_locker_luggage_lockers, [:status])
  end
end
```

**Important:** migration module names must be globally unique. Always namespace them:
`VoileLockerLuggage.Migrations.CreateLockers`, not just `CreateLockers`.

### 3.3 Migration Tracking

`Ecto.Migrator.run/4` tracks applied migrations in the `schema_migrations` table.
Migration version numbers (timestamps) are global — **plugin versions share the same
space as core migrations**. The plugin migrator validates for collisions before running.

### 3.4 Plugins Use Voile.Repo Directly

Plugins call `Voile.Repo` for all database operations. This is simpler, always
correct, and requires zero maintenance from the core team:

```elixir
# In a plugin context module
defmodule VoileLockerLuggage.Lockers do
  import Ecto.Query
  alias Voile.Repo
  alias VoileLockerLuggage.Locker

  def list_lockers(node_id) do
    Locker
    |> where([l], l.node_id == ^node_id)
    |> order_by(:locker_number)
    |> Repo.all()
  end

  def create_locker(attrs) do
    %Locker{}
    |> Locker.changeset(attrs)
    |> Repo.insert()
  end
end
```

This is completely standard Ecto usage — the plugin code looks identical to core
Voile context code.

---

## 4. Core Files to Add to Voile

These files live in the **Voile host app**. They form the plugin engine.

---

### 4.1 `Voile.Plugin` — Behaviour Contract

**File:** `lib/voile/plugin.ex`

This is the contract every plugin must implement.

```elixir
defmodule Voile.Plugin do
  @moduledoc """
  The behaviour that every Voile plugin must implement.

  A plugin is an Elixir module (typically the main module of an OTP application)
  that implements this behaviour and ships its own migrations, schemas,
  contexts, and optionally LiveView UI.

  ## Compile-time constraint

  Plugins are added as `path:` dependencies and are compiled **before** the
  Voile host app. This means a plugin module CANNOT reference host-app modules
  at compile time. Specifically:

  - Do NOT add `@behaviour Voile.Plugin` (causes undefined module warning)
  - Do NOT add `@impl true` annotations (requires `@behaviour` to be meaningful)
  - Do NOT use `VoileWeb`, `~p` sigils, `<.icon>`, or `<.input>` in plugin LiveViews
  - Plugin LiveViews must use `use Phoenix.LiveView` directly and plain HTML
  - Add `@compile {:no_warn_undefined, [Voile.Plugin, Voile.Repo, ...]}` to silence
    runtime-only reference warnings

  The behaviour contract is still enforced dynamically at runtime via
  `function_exported?/3` checks in `Voile.Plugin.plugin?/1`.

  ## Minimal Example

      defmodule VoileLockerLuggage do
        # Note: NO @behaviour or @impl true — see compile-time constraint above
        @compile {:no_warn_undefined, [Voile.Plugin, Voile.Hooks]}

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

        def on_install,    do: VoileLockerLuggage.Migrator.run()
        def on_activate,   do: :ok
        def on_deactivate, do: :ok
        def on_uninstall,  do: VoileLockerLuggage.Migrator.rollback()
        def on_update(_old, _new), do: VoileLockerLuggage.Migrator.run()
        def hooks,           do: []
        def routes,          do: []
        def nav,             do: []
        def settings_schema, do: []
      end
  """

  # ── Types ──────────────────────────────────────────────────────────────────

  @type license_type :: :free | :premium

  @type metadata :: %{
    required(:id)           => String.t(),
    required(:name)         => String.t(),
    required(:version)      => String.t(),
    required(:author)       => String.t(),
    required(:description)  => String.t(),
    required(:license_type) => license_type(),
    optional(:min_voile_version) => String.t(),
    optional(:icon)         => String.t(),
    optional(:tags)         => [String.t()]
  }

  @type hook_entry :: {hook_name :: atom(), handler :: function()}

  @type route_entry :: {path :: String.t(), live_view :: module(), action :: atom()}

  @type setting_field :: %{
    required(:key)   => atom(),
    required(:type)  => :string | :integer | :boolean | :select,
    required(:label) => String.t(),
    optional(:required) => boolean(),
    optional(:default)  => term(),
    optional(:secret)   => boolean(),
    optional(:options)  => [{String.t(), String.t()}]
  }

  # ── Callbacks ──────────────────────────────────────────────────────────────

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

  @typedoc """
  One entry in a plugin's navigation menu.

  - `:path` — relative path appended to `/manage/plugins/:plugin_id`, e.g. `"/"` or `"/lockers"`
  - `:label` — human-readable menu label shown in the sidebar
  - `:icon` — hero-icon name, e.g. `"hero-archive-box"`
  - `:description` — optional short description
  """
  @type nav_entry :: %{
          required(:path) => String.t(),
          required(:label) => String.t(),
          required(:icon) => String.t(),
          optional(:description) => String.t()
        }

  @doc """
  Returns navigation entries shown in the plugin sidebar.

  The admin dashboard uses these to render a per-plugin menu so admins can
  navigate between all pages the plugin provides without going back to the
  plugin index. Each entry's `:path` is appended to `/manage/plugins/:plugin_id`.
  A "Settings" link is always appended automatically — do not include it here.

  Example:

      def nav do
        [
          %{path: "/",         label: "Overview",    icon: "hero-home"},
          %{path: "/lockers",  label: "Lockers",     icon: "hero-archive-box"},
          %{path: "/sessions", label: "Sessions",    icon: "hero-clock"},
          %{path: "/nodes",    label: "Node Config", icon: "hero-server"}
        ]
      end
  """
  @callback nav() :: [nav_entry()]

  # ── Helper ─────────────────────────────────────────────────────────────────

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
```

---

### 4.2 `Voile.Plugin.Migrator` — Per-Plugin Migration Runner

**File:** `lib/voile/plugin/migrator.ex`

This macro generates a Migrator for a plugin and includes collision detection.

```elixir
defmodule Voile.Plugin.Migrator do
  @moduledoc """
  Macro that generates a Migrator for a plugin.

  Each plugin defines:

      defmodule VoileLockerLuggage.Migrator do
        use Voile.Plugin.Migrator, otp_app: :voile_locker_luggage
      end

  The `otp_app` option tells the migrator where to find
  `priv/migrations/` for this plugin's OTP application.

  Generates `run/0`, `rollback/0`, `migrated?/0`, and `status/0`.
  """

  defmacro __using__(opts) do
    otp_app = Keyword.fetch!(opts, :otp_app)

    quote do
      @otp_app unquote(otp_app)

      require Logger

      @doc "Run all pending migrations for this plugin."
      def run do
        migrations_path = migrations_path()
        repo = Voile.Repo

        unless File.dir?(migrations_path) do
          Logger.info("[PluginMigrator] No migrations directory for #{@otp_app}, skipping")
          :ok
        else
          validate_no_version_collisions!(migrations_path)

          case Ecto.Migrator.run(repo, migrations_path, :up, all: true) do
            versions when is_list(versions) -> {:ok, versions}
            _ -> :ok
          end
        end
      rescue
        e -> {:error, "Migration failed for #{@otp_app}: #{Exception.message(e)}"}
      end

      @doc """
      Rollback all migrations for this plugin.
      WARNING: This drops plugin tables and destroys all plugin data.
      """
      def rollback do
        migrations_path = migrations_path()
        repo = Voile.Repo

        case Ecto.Migrator.run(repo, migrations_path, :down, all: true) do
          versions when is_list(versions) -> {:ok, versions}
          _ -> :ok
        end
      rescue
        e -> {:error, "Rollback failed for #{@otp_app}: #{Exception.message(e)}"}
      end

      @doc "Returns true if all migrations for this plugin have been applied."
      def migrated? do
        migrations_path()
        |> then(&Ecto.Migrator.migrations(Voile.Repo, [&1]))
        |> Enum.all?(fn {status, _, _} -> status == :up end)
      end

      @doc "Returns list of {status, version, name} for all plugin migrations."
      def status do
        Ecto.Migrator.migrations(Voile.Repo, [migrations_path()])
      end

      # ── Private ──────────────────────────────────────────────────────────

      defp migrations_path do
        case :code.priv_dir(@otp_app) do
          {:error, :bad_name} ->
            raise "Could not find priv dir for :#{@otp_app}. " <>
                  "Make sure the plugin OTP app name is correct."
          path ->
            Path.join(to_string(path), "migrations")
        end
      end

      @doc false
      defp validate_no_version_collisions!(plugin_migrations_path) do
        # Get plugin migration versions from the filesystem
        plugin_versions =
          plugin_migrations_path
          |> File.ls!()
          |> Enum.filter(&String.ends_with?(&1, ".exs"))
          |> Enum.map(fn filename ->
            filename
            |> String.split("_", parts: 2)
            |> List.first()
            |> String.to_integer()
          end)
          |> MapSet.new()

        # Get all already-applied migration versions from the DB
        applied_versions =
          Ecto.Migrator.migrations(Voile.Repo)
          |> Enum.map(fn {_status, version, _name} -> version end)
          |> MapSet.new()

        # Also get core app pending migrations
        core_path = Application.app_dir(:voile, "priv/repo/migrations")
        core_versions =
          if File.dir?(core_path) do
            core_path
            |> File.ls!()
            |> Enum.filter(&String.ends_with?(&1, ".exs"))
            |> Enum.map(fn filename ->
              filename
              |> String.split("_", parts: 2)
              |> List.first()
              |> String.to_integer()
            end)
            |> MapSet.new()
          else
            MapSet.new()
          end

        all_existing = MapSet.union(applied_versions, core_versions)
        collisions = MapSet.intersection(plugin_versions, all_existing)

        if MapSet.size(collisions) > 0 do
          raise """
          Migration version collision detected for :#{@otp_app}!

          Colliding versions: #{inspect(MapSet.to_list(collisions))}

          Plugin migration timestamps must not overlap with core Voile
          migrations or other plugin migrations. Use unique timestamps
          for your plugin's migrations.
          """
        end
      end
    end
  end
end
```

---

### 4.3 `Voile.Hooks` — Action & Filter System

**File:** `lib/voile/hooks.ex`

Uses `:persistent_term` for zero-cost reads. GenServer only handles writes.

```elixir
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

  # ── Public API — Reads (no GenServer call, direct persistent_term) ────────

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

  # ── Public API — Writes (go through GenServer) ────────────────────────────

  @doc """
  Register a handler for a named hook.

  Options:
  - `owner:` (module) — used to unregister all hooks for a plugin at once
  - `priority:` (integer) — lower numbers run first, default 50
  """
  def register(hook_name, handler, opts \\ []) when is_atom(hook_name) and is_function(handler) do
    GenServer.call(__MODULE__, {:register, hook_name, handler, opts})
  end

  @doc "Unregister ALL hooks registered by a specific plugin module."
  def unregister_all(owner_module) when is_atom(owner_module) do
    GenServer.call(__MODULE__, {:unregister_all, owner_module})
  end

  # ── GenServer ──────────────────────────────────────────────────────────────

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
      handler:  handler,
      owner:    Keyword.get(opts, :owner),
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

  # ── Private ────────────────────────────────────────────────────────────────

  defp get_handlers(hook_name) do
    :persistent_term.get({__MODULE__, hook_name}, [])
  end
end
```

---

### 4.4 `Voile.PluginManager` — Lifecycle Manager

**File:** `lib/voile/plugin_manager.ex`

Uses ETS for the plugin registry. GenServer only handles state-changing operations.

```elixir
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

  All public write functions accept a **string** module name (the value returned by
  `Atom.to_string(ModuleName)`, e.g. `"Elixir.VoileLockerLuggage"`). This avoids
  creating new atoms from untrusted input and prevents BEAM atom table exhaustion.
  Atom resolution happens inside `handle_call` using `String.to_existing_atom/1`,
  which is safe because it raises rather than creates if the module isn't loaded.
  """

  use GenServer
  require Logger

  alias Voile.{Plugins, Hooks}

  @ets_table :voile_plugins_registry

  # ── Public API — Reads (direct ETS, no GenServer call) ─────────────────────

  @doc "Check if a plugin is currently active."
  def active?(module) when is_atom(module) do
    case :ets.lookup(@ets_table, module) do
      [{^module, :active}] -> true
      _ -> false
    end
  end

  @doc "Get the current status of a plugin."
  def status(module) when is_atom(module) do
    case :ets.lookup(@ets_table, module) do
      [{^module, status}] -> status
      _ -> :unknown
    end
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

  # ── Public API — Discovery ─────────────────────────────────────────────────

  @doc """
  Returns metadata maps for plugin modules that are loaded in the VM but
  not yet installed in the database.

  Scans `Application.loaded_applications()`, derives the conventional root
  module name by camelising the app atom (e.g. `:voile_locker_luggage` →
  `VoileLockerLuggage`), checks it implements the plugin contract, and
  excludes modules already recorded in the DB.

  Returns a list of plain maps:

      [
        %{
          module: "Elixir.VoileLockerLuggage",
          name: "Locker & Luggage",
          version: "1.0.0",
          description: "...",
          author: "..."
        }
      ]

  Plugin metadata is eagerly fetched here so callers (e.g. templates) never
  need to call module functions on user-supplied input.
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

        [%{
          module: module_str,
          name: meta.name,
          version: meta.version,
          description: Map.get(meta, :description, ""),
          author: Map.get(meta, :author, "")
        }]
      else
        []
      end
    end)
    |> Enum.sort_by(& &1.name)
  end

  defp app_to_module(app) do
    Module.concat([app |> Atom.to_string() |> Macro.camelize()])
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

  # ── Public API — Writes (go through GenServer) ─────────────────────────────

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

  # ── GenServer ──────────────────────────────────────────────────────────────

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    @ets_table = :ets.new(@ets_table, [
      :named_table, :public, :set,
      read_concurrency: true
    ])

    {:ok, %{}, {:continue, :rehydrate}}
  end

  @impl true
  def handle_continue(:rehydrate, state) do
    Plugins.list_plugins()
    |> Enum.each(fn record ->
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
              Logger.error("[PluginManager] Failed to reactivate #{inspect(module)}: #{inspect(reason)}")
              :ets.insert(@ets_table, {module, :error})
              Plugins.update_plugin_status(record.plugin_id, :error,
                error_message: "Reactivation failed: #{inspect(reason)}")
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

  # ── Install ────────────────────────────────────────────────────────────────

  # String → atom conversion happens here, inside the GenServer, using
  # String.to_existing_atom/1. This is safe: it raises ArgumentError rather
  # than creating a new atom if the module is not already loaded.
  #
  # The `module` column in the DB stores Atom.to_string(module) which gives
  # the full Elixir-prefixed atom string ("Elixir.VoileLockerLuggage"),
  # NOT inspect(module) (which would give "VoileLockerLuggage" without the
  # prefix and cannot be round-tripped with String.to_existing_atom).

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

  # ── Activate ───────────────────────────────────────────────────────────────

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

  # ── Deactivate ─────────────────────────────────────────────────────────────

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
      {:error, reason} = error ->
        {:reply, error, state}
    end
  end

  # ── Uninstall ──────────────────────────────────────────────────────────────

  @impl true
  def handle_call({:uninstall, module_str, opts}, _from, state) do
    module = String.to_existing_atom(module_str)
    remove_data = Keyword.get(opts, :remove_data, false)

    # Deactivate hooks first
    Hooks.unregister_all(module)

    # Optionally destroy data
    if remove_data do
      case safe_callback(module, :on_uninstall, []) do
        :ok -> :ok
        {:error, reason} ->
          Logger.error("[PluginManager] on_uninstall error for #{inspect(module)}: #{inspect(reason)}")
      end
    end

    meta = module.metadata()
    Plugins.update_plugin_status(meta.id, :uninstalled)
    :ets.insert(@ets_table, {module, :uninstalled})

    Logger.info("[PluginManager] Uninstalled: #{inspect(module)} (data removed: #{remove_data})")
    {:reply, :ok, state}
  end

  # ── Update ─────────────────────────────────────────────────────────────────

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

            Logger.info("[PluginManager] Updated #{inspect(module)}: #{old_version} → #{new_version}")
            {:reply, :ok, state}

          {:error, _} = error ->
            {:reply, error, state}
        end
      end
    else
      error -> {:reply, error, state}
    end
  end

  # ── Private Helpers ────────────────────────────────────────────────────────

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
```

---

### 4.5 `Voile.PluginRecord` — Ecto Schema

**File:** `lib/voile/plugin_record.ex`

```elixir
defmodule Voile.PluginRecord do
  @moduledoc """
  Persists the state of each plugin installation.
  Allows Voile to know which plugins are installed and active
  across server restarts.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @statuses [:installed, :active, :inactive, :error, :uninstalled]

  @primary_key {:id, :binary_id, autogenerate: true}

  schema "voile_plugins" do
    field :plugin_id,      :string
    field :module,         :string
    field :name,           :string
    field :version,        :string
    field :author,         :string
    field :description,    :string
    field :license_type,   :string, default: "free"
    field :license_key,    :string
    field :status,         Ecto.Enum, values: @statuses, default: :installed
    field :error_message,  :string
    field :settings,       :map, default: %{}
    field :installed_at,   :utc_datetime
    field :activated_at,   :utc_datetime
    field :deactivated_at, :utc_datetime

    timestamps()
  end

  def changeset(record, attrs) do
    record
    |> cast(attrs, [
      :plugin_id, :module, :name, :version, :author, :description,
      :license_type, :license_key, :status, :error_message,
      :settings, :installed_at, :activated_at, :deactivated_at
    ])
    |> validate_required([:plugin_id, :module, :name, :version, :status])
    |> unique_constraint(:plugin_id)
    |> unique_constraint(:module)
  end
end
```

**Migration:**

```elixir
# priv/repo/migrations/YYYYMMDDHHMMSS_create_voile_plugins.exs
defmodule Voile.Repo.Migrations.CreateVoilePlugins do
  use Ecto.Migration

  def change do
    create table(:voile_plugins, primary_key: false) do
      add :id,             :binary_id, primary_key: true
      add :plugin_id,      :string, null: false
      add :module,         :string, null: false
      add :name,           :string, null: false
      add :version,        :string, null: false
      add :author,         :string
      add :description,    :text
      add :license_type,   :string, default: "free"
      add :license_key,    :string
      add :status,         :string, null: false, default: "installed"
      add :error_message,  :text
      add :settings,       :map, default: %{}
      add :installed_at,   :utc_datetime
      add :activated_at,   :utc_datetime
      add :deactivated_at, :utc_datetime

      timestamps()
    end

    create unique_index(:voile_plugins, [:plugin_id])
    create unique_index(:voile_plugins, [:module])
    create index(:voile_plugins, [:status])
  end
end
```

---

### 4.6 `Voile.Plugins` — Context Module

**File:** `lib/voile/plugins.ex`

```elixir
defmodule Voile.Plugins do
  @moduledoc "Context for managing plugin records in the Voile database."

  import Ecto.Query
  alias Voile.{Repo, PluginRecord}

  def list_plugins do
    PluginRecord
    |> order_by(:name)
    |> Repo.all()
  end

  def list_plugins_by_status(status) do
    PluginRecord
    |> where([p], p.status == ^status)
    |> Repo.all()
  end

  def get_plugin!(id), do: Repo.get!(PluginRecord, id)

  def get_plugin_by_plugin_id(plugin_id) do
    Repo.get_by(PluginRecord, plugin_id: plugin_id)
  end

  def upsert_plugin(attrs) when is_map(attrs) do
    case get_plugin_by_plugin_id(attrs.plugin_id) do
      nil ->
        %PluginRecord{}
        |> PluginRecord.changeset(attrs)
        |> Repo.insert()

      existing ->
        existing
        |> PluginRecord.changeset(attrs)
        |> Repo.update()
    end
  end

  def update_plugin_status(plugin_id, status, opts \\ []) do
    case get_plugin_by_plugin_id(plugin_id) do
      nil ->
        {:error, :not_found}

      record ->
        timestamp_field =
          case status do
            :active -> %{activated_at: DateTime.utc_now() |> DateTime.truncate(:second)}
            :inactive -> %{deactivated_at: DateTime.utc_now() |> DateTime.truncate(:second)}
            _ -> %{}
          end

        attrs =
          %{status: status, error_message: opts[:error_message]}
          |> Map.merge(timestamp_field)

        record
        |> PluginRecord.changeset(attrs)
        |> Repo.update()
    end
  end

  # ── Settings ─────────────────────────────────────────────────────────────

  def get_plugin_setting(plugin_id, key, default \\ nil) do
    case get_plugin_by_plugin_id(plugin_id) do
      nil -> default
      record -> Map.get(record.settings || %{}, to_string(key), default)
    end
  end

  @doc """
  Update a single setting using JSONB merge to avoid race conditions.
  """
  def put_plugin_setting(plugin_id, key, value) do
    case get_plugin_by_plugin_id(plugin_id) do
      nil ->
        {:error, :plugin_not_found}

      record ->
        # Use Ecto's fragment for atomic JSONB merge
        from(p in PluginRecord,
          where: p.id == ^record.id,
          update: [set: [
            settings: fragment(
              "COALESCE(?, '{}'::jsonb) || ?::jsonb",
              p.settings,
              ^Jason.encode!(%{to_string(key) => value})
            )
          ]]
        )
        |> Repo.update_all([])

        {:ok, get_plugin_by_plugin_id(plugin_id)}
    end
  end

  @doc """
  Update multiple settings at once using JSONB merge.
  """
  def put_plugin_settings(plugin_id, settings_map) when is_map(settings_map) do
    case get_plugin_by_plugin_id(plugin_id) do
      nil ->
        {:error, :plugin_not_found}

      record ->
        stringified = Map.new(settings_map, fn {k, v} -> {to_string(k), v} end)

        from(p in PluginRecord,
          where: p.id == ^record.id,
          update: [set: [
            settings: fragment(
              "COALESCE(?, '{}'::jsonb) || ?::jsonb",
              p.settings,
              ^Jason.encode!(stringified)
            )
          ]]
        )
        |> Repo.update_all([])

        {:ok, get_plugin_by_plugin_id(plugin_id)}
    end
  end
end
```

---

## 5. Plugin Lifecycle

```
                  ┌──────────────────────────────────────────────────┐
     mix deps.get │                                                  │
     + redeploy   │    Plugin OTP app loaded in code                 │
                  │    Not yet in voile_plugins DB table             │
                  └─────────────────┬────────────────────────────────┘
                                    │
                                    │  PluginManager.install/1
                                    │  - validates module implements behaviour
                                    │  - calls on_install/0 (runs migrations)
                                    │  - inserts record in voile_plugins
                                    ▼
                  ┌──────────────────────────────────────────────────┐
                  │    INSTALLED                                     │
                  │    Tables created, data can exist                │
                  │    Hooks NOT registered yet                      │
                  └─────────────────┬────────────────────────────────┘
                                    │
                                    │  PluginManager.activate/1
                                    │  - calls on_activate/0
                                    │  - registers all hooks from hooks/0
                                    │  - updates DB status to :active
                                    ▼
                  ┌──────────────────────────────────────────────────┐
                  │    ACTIVE  ◄───────────────────┐                │
                  │    Hooks running               │                │
                  │    Routes accessible        re-activate         │
                  │    Fully operational           │                │
                  └────┬───────────────────────────┘                │
                       │                                            │
                       │  PluginManager.deactivate/1                │
                       │  - calls on_deactivate/0                   │
                       │  - unregisters all hooks                   │
                       │  - status to :inactive                     │
                       ▼                                            │
                  ┌─────────────────────────────────────────────────┤
                  │    INACTIVE                                     │
                  │    Tables and data intact                       │
                  │    Hooks NOT running                            │
                  │    Routes NOT accessible                        │
                  └─────────────────┬───────────────────────────────┘
                                    │
                            ┌───────┴──────────┐
                            │                  │
                   remove_data: false  remove_data: true
                            │                  │
                            │       PluginManager.uninstall/2
                            │       - calls on_uninstall/0
                            │       - Migrator.rollback() DROPS TABLES
                            ▼                  ▼
                  ┌──────────────┐   ┌──────────────────────┐
                  │ UNINSTALLED  │   │ UNINSTALLED + NO DATA │
                  │ (data kept)  │   │ (tables dropped)      │
                  └──────────────┘   └──────────────────────┘
```

### 5.1 Install

```elixir
# What on_install/0 should do:
@impl Voile.Plugin
def on_install do
  case VoileLockerLuggage.Migrator.run() do
    {:ok, _versions} -> :ok
    :ok -> :ok
    {:error, reason} -> {:error, reason}
  end
end
```

### 5.2 Activate / Deactivate

```elixir
@impl Voile.Plugin
def on_activate do
  # Hooks are registered automatically by PluginManager from hooks/0.
  # Only do extra work here if needed (e.g., start GenServers):
  :ok
end

@impl Voile.Plugin
def on_deactivate do
  # Hooks are unregistered automatically by PluginManager.
  :ok
end
```

### 5.3 Uninstall

```elixir
@impl Voile.Plugin
def on_uninstall do
  case VoileLockerLuggage.Migrator.rollback() do
    {:ok, _} -> :ok
    :ok -> :ok
    {:error, reason} -> {:error, reason}
  end
end
```

### 5.4 Update

```elixir
@impl Voile.Plugin
def on_update(old_version, new_version) do
  Logger.info("Updating #{old_version} → #{new_version}")

  # Run any new migrations added since last version
  case VoileLockerLuggage.Migrator.run() do
    {:ok, _versions} -> :ok
    :ok -> :ok
    {:error, reason} -> {:error, reason}
  end
end
```

---

## 6. Dynamic Plugin Routing

Plugins mount their LiveViews dynamically — **no compile-time router macros needed**.

### 6.1 How It Works

1. A single catch-all route is defined in the Voile router
2. `PluginRouterLive` resolves the plugin module from the URL
3. It checks the plugin is active and finds the matching route
4. It renders the plugin's LiveView inside the standard dashboard layout

### 6.2 The Router Live Module

**File:** `lib/voile_web/live/plugin_router_live.ex`

```elixir
defmodule VoileWeb.PluginRouterLive do
  use VoileWeb, :live_view_dashboard

  require Logger

  @impl true
  def mount(%{"plugin_id" => plugin_id} = params, _session, socket) do
    path_segments = Map.get(params, "path", [])
    path = "/" <> Enum.join(path_segments, "/")

    with {:ok, record} <- find_plugin_record(plugin_id),
         {:ok, module} <- resolve_module(record),
         true <- Voile.PluginManager.active?(module),
         {:ok, live_view, action} <- match_route(module, path) do

      socket =
        socket
        |> assign(:plugin_record, record)
        |> assign(:plugin_module, module)
        |> assign(:plugin_live_view, live_view)
        |> assign(:plugin_action, action)
        |> assign(:plugin_path, path)
        |> assign(:page_title, record.name)

      {:ok, socket}
    else
      _ ->
        {:ok,
         socket
         |> put_flash(:error, "Plugin not found or not active.")
         |> push_navigate(to: ~p"/manage")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id="plugin-container">
      {live_render(@socket, @plugin_live_view,
        id: "plugin-#{@plugin_record.plugin_id}",
        session: %{
          "plugin_id" => @plugin_record.plugin_id,
          "plugin_path" => @plugin_path,
          "action" => to_string(@plugin_action)
        }
      )}
    </div>
    """
  end

  defp find_plugin_record(plugin_id) do
    case Voile.Plugins.get_plugin_by_plugin_id(plugin_id) do
      nil -> {:error, :not_found}
      record -> {:ok, record}
    end
  end

  defp resolve_module(record) do
    try do
      {:ok, String.to_existing_atom(record.module)}
    rescue
      ArgumentError -> {:error, :module_not_loaded}
    end
  end

  defp match_route(module, request_path) do
    module.routes()
    |> Enum.find_value(fn {route_path, live_view, action} ->
      if route_matches?(route_path, request_path) do
        {:ok, live_view, action}
      end
    end)
    |> case do
      nil -> {:error, :no_matching_route}
      result -> result
    end
  end

  # Simple path matching — supports static paths and `:id` params
  defp route_matches?(route_path, request_path) do
    route_parts = String.split(route_path, "/", trim: true)
    request_parts = String.split(request_path, "/", trim: true)

    if length(route_parts) == length(request_parts) do
      Enum.zip(route_parts, request_parts)
      |> Enum.all?(fn
        {":" <> _, _} -> true  # param segment matches anything
        {a, b} -> a == b       # static segment must match exactly
      end)
    else
      # Allow root route "/" to match empty path
      route_parts == [] and request_parts == []
    end
  end
end
```

!!! note
The `live_render/3` approach is one option. An alternative is to use the plugin's
LiveView module directly in mount and delegate all callbacks. The `live_render` approach
is simpler but nests LiveViews. Choose based on how much isolation you want.

---

## 7. Plugin Settings System

### 7.1 How It Works End-to-End

1. Plugin declares `settings_schema/0` in its behaviour implementation
2. Admin navigates to `/manage/plugins/:plugin_id/settings`
3. The settings LiveView reads the schema and renders a dynamic form
4. On save, values are stored in `voile_plugins.settings` JSONB column
5. Plugin reads settings at runtime via `Voile.Plugins.get_plugin_setting/3`

### 7.2 Reading Settings in Plugin Code

```elixir
# Helper module in your plugin (optional convenience wrapper)
defmodule VoileLockerLuggage.Settings do
  @plugin_id "locker_luggage"

  def get(key, default \\ nil) do
    Voile.Plugins.get_plugin_setting(@plugin_id, key, default)
  end

  def put(key, value) do
    Voile.Plugins.put_plugin_setting(@plugin_id, key, value)
  end
end

# Usage:
max_lockers = VoileLockerLuggage.Settings.get(:max_lockers, 50)
```

---

## 8. Wiring Into Voile — Host App Changes

### 8.1 Application Supervisor

```elixir
# lib/voile/application.ex — add to children list, BEFORE VoileWeb.Endpoint
base_children = [
  VoileWeb.Telemetry,
  Voile.Repo,
  {DNSCluster, query: Application.get_env(:voile, :dns_cluster_query) || :ignore},
  {Phoenix.PubSub, name: Voile.PubSub},
  {Voile.RateLimiter, clean_period: :timer.minutes(10)},
  {Finch, name: Voile.Finch},
  {Task.Supervisor, name: Voile.TaskSupervisor},

  # Plugin infrastructure — start before endpoint, after Repo
  Voile.Hooks,
  Voile.PluginManager
]
```

### 8.2 Router

Add a single catch-all route inside the authenticated staff scope:

```elixir
# In the :require_authenticated_user_and_verified_staff_user live_session,
# inside the /manage scope:

scope "/plugins" do
  live "/", Dashboard.Plugins.Index, :index
  live "/:plugin_id/settings", Dashboard.Plugins.Settings, :settings
  live "/:plugin_id/*path", PluginRouterLive, :index
end
```

This adds:

- `/manage/plugins` — plugin management admin page
- `/manage/plugins/:id/settings` — per-plugin settings form
- `/manage/plugins/:id/*` — dynamic plugin-owned routes

### 8.3 Dashboard Hook Integration

Modify `DashboardLive.mount/3` to include plugin widgets:

```elixir
# In lib/voile_web/live/dashboard/dashboard_live.ex mount/3:
# After loading core stats, let plugins add widgets:

# Core widgets (existing stat cards etc.)
base_widgets = [
  %{key: :quick_stats, component: nil, priority: 1},
  %{key: :member_overview, component: nil, priority: 10},
  %{key: :circulation_overview, component: nil, priority: 20},
  %{key: :catalog_overview, component: nil, priority: 30},
  %{key: :search_widget, component: nil, priority: 40}
]

# Let plugins inject their own widgets
plugin_widgets = Voile.Hooks.run_filter(:dashboard_widgets, [])
all_extra_widgets = Enum.sort_by(plugin_widgets, & &1.priority)

socket = assign(socket, :plugin_widgets, all_extra_widgets)
```

Then in the template, after the core dashboard content:

```heex
<%!-- Plugin Dashboard Widgets --%>
<%= for widget <- @plugin_widgets do %>
  <div class="bg-white dark:bg-gray-700 rounded-xl shadow p-6">
    <h3 class="text-lg font-semibold text-gray-900 dark:text-white mb-4">
      {widget.title}
    </h3>
    <.live_component module={widget.component} id={to_string(widget.key)} />
  </div>
<% end %>
```

### 8.4 Sidebar Navigation Hook

Modify `SideBarMenuMaster` to include plugin nav items:

```elixir
# In lib/voile_web/utils/side_bar_menu_master.ex
def on_mount(:master_menu, _params, _session, socket) do
  master_menu = master_menu()
  metaresource_menu = metaresource_menu()

  # Let active plugins add navigation items
  plugin_nav = Voile.Hooks.run_filter(:admin_nav_items, [])

  socket =
    socket
    |> Phoenix.Component.assign(:master_menu, master_menu)
    |> Phoenix.Component.assign(:metaresource_menu, metaresource_menu)
    |> Phoenix.Component.assign(:plugin_nav_items, plugin_nav)

  {:cont, socket}
end
```

### 8.5 Catalog Context Hooks

Add hook points to core context operations:

```elixir
# In lib/voile/schema/catalog.ex

def create_collection(attrs \\ %{}) do
  # Let plugins modify attrs before save
  enriched_attrs = Voile.Hooks.run_filter(:collection_before_save, attrs)

  result =
    %Collection{}
    |> Collection.changeset(enriched_attrs)
    |> Repo.insert()

  case result do
    {:ok, collection} ->
      # Let plugins react to the new collection
      Voile.Hooks.run_action(:collection_after_save, collection)
      {:ok, collection}

    error ->
      error
  end
end
```

---

## 9. Writing a Plugin — Developer Contract

### 9.1 Required Files

```
voile_locker_luggage/
├── mix.exs                                      # OTP app definition
├── README.md
├── lib/
│   ├── voile_locker_luggage.ex                  # @behaviour Voile.Plugin
│   └── voile_locker_luggage/
│       ├── migrator.ex                          # use Voile.Plugin.Migrator
│       ├── locker.ex                            # Ecto Schema
│       ├── lockers.ex                           # Context (business logic)
│       ├── settings.ex                          # Settings convenience wrapper
│       └── web/
│           └── live/
│               ├── index_live.ex                # Plugin UI
│               └── components/
│                   └── dashboard_widget.ex      # Dashboard widget component
└── priv/
    └── migrations/
        └── 20240601000001_create_plugin_locker_luggage_lockers.exs
```

### 9.2 Implementing the Behaviour

```elixir
defmodule VoileLockerLuggage do
  @behaviour Voile.Plugin

  @impl true
  def metadata do
    %{
      id: "locker_luggage",
      name: "Locker & Luggage Management",
      version: "1.0.0",
      author: "Your Institution",
      description: "Manage visitor lockers and luggage storage for your GLAM facility.",
      license_type: :free,
      icon: "🔐",
      tags: ["visitors", "facilities"]
    }
  end

  @impl true
  def on_install do
    case VoileLockerLuggage.Migrator.run() do
      {:ok, _} -> :ok
      :ok -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def on_activate, do: :ok

  @impl true
  def on_deactivate, do: :ok

  @impl true
  def on_uninstall do
    case VoileLockerLuggage.Migrator.rollback() do
      {:ok, _} -> :ok
      :ok -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def on_update(_old_version, _new_version) do
    # Run any new migrations
    case VoileLockerLuggage.Migrator.run() do
      {:ok, _} -> :ok
      :ok -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def hooks do
    [
      {:dashboard_widgets, &__MODULE__.add_dashboard_widget/1},
      {:admin_nav_items, &__MODULE__.add_nav_item/1},
      {:visitor_checked_in, &__MODULE__.on_visitor_checkin/1}
    ]
  end

  @impl true
  def routes do
    [
      {"/", VoileLockerLuggage.Web.Live.IndexLive, :index},
      {"/:id", VoileLockerLuggage.Web.Live.ShowLive, :show}
    ]
  end

  @impl true
  def settings_schema do
    [
      %{key: :max_lockers, type: :integer, label: "Maximum Lockers Per Node", default: 50},
      %{key: :auto_release_hours, type: :integer, label: "Auto-release After (hours)", default: 8},
      %{key: :require_id, type: :boolean, label: "Require ID for Locker Assignment", default: false}
    ]
  end

  # ── Hook Handlers ──────────────────────────────────────────────────────

  def add_dashboard_widget(widgets) do
    widget = %{
      key: :locker_stats,
      title: "Locker Status",
      component: VoileLockerLuggage.Web.Components.DashboardWidget,
      priority: 50
    }
    widgets ++ [widget]
  end

  def add_nav_item(nav_items) do
    item = %{
      name: "Locker Management",
      url: "/manage/plugins/locker_luggage",
      icon: "hero-lock-closed"
    }
    nav_items ++ [item]
  end

  def on_visitor_checkin(%{visitor_id: _id, node_id: _node_id} = _payload) do
    # Could auto-assign a locker, send notification, etc.
    :ok
  end
end
```

### 9.3 Plugin Tables & Schemas

```elixir
# lib/voile_locker_luggage/migrator.ex
defmodule VoileLockerLuggage.Migrator do
  use Voile.Plugin.Migrator, otp_app: :voile_locker_luggage
end
```

```elixir
# lib/voile_locker_luggage/locker.ex
defmodule VoileLockerLuggage.Locker do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}

  schema "plugin_locker_luggage_lockers" do
    field :locker_number, :string
    field :status, :string, default: "available"
    field :node_id, :integer              # soft ref to Voile nodes
    field :assigned_visitor_id, :binary_id # soft ref to visitor logs
    field :assigned_at, :utc_datetime

    timestamps()
  end

  def changeset(locker, attrs) do
    locker
    |> cast(attrs, [:locker_number, :status, :node_id, :assigned_visitor_id, :assigned_at])
    |> validate_required([:locker_number, :node_id])
    |> validate_inclusion(:status, ["available", "occupied", "maintenance"])
  end
end
```

### 9.4 Hooks

| Hook Name                 | Type   | Payload / Initial Value        | Plugin Can...              |
| ------------------------- | ------ | ------------------------------ | -------------------------- |
| `:dashboard_widgets`      | Filter | `[widget_map]`                 | Append widget maps         |
| `:admin_nav_items`        | Filter | `[nav_item_map]`               | Append nav links           |
| `:collection_before_save` | Filter | `attrs :: map`                 | Modify attrs before insert |
| `:collection_after_save`  | Action | `%Collection{}`                | React to new collections   |
| `:item_after_create`      | Action | `%Item{}`                      | React to new items         |
| `:visitor_checked_in`     | Action | `%{visitor_id, node_id, name}` | React to visitor events    |
| `:visitor_session_ended`  | Action | `%{visitor_id}`                | React to checkout          |
| `:search_results`         | Filter | `[result]`                     | Modify search results      |
| `:circulation_checkout`   | Action | `%Transaction{}`               | React to checkouts         |
| `:admin_sidebar_menu`     | Filter | `[menu_item]`                  | Add sidebar sections       |

### 9.5 Plugin Settings

See section 7.2 above. The convention is:

```elixir
# lib/voile_locker_luggage/settings.ex
defmodule VoileLockerLuggage.Settings do
  @plugin_id "locker_luggage"

  def get(key, default \\ nil),
    do: Voile.Plugins.get_plugin_setting(@plugin_id, key, default)

  def put(key, value),
    do: Voile.Plugins.put_plugin_setting(@plugin_id, key, value)
end
```

### 9.6 Plugin LiveViews

Plugin LiveViews are standard Phoenix LiveViews. They use `VoileWeb` helpers
for access to layouts, components, and verified routes:

```elixir
# lib/voile_locker_luggage/web/live/index_live.ex
defmodule VoileLockerLuggage.Web.Live.IndexLive do
  use Phoenix.LiveView

  alias VoileLockerLuggage.{Lockers, Settings}

  @impl true
  def mount(_params, %{"plugin_id" => plugin_id}, socket) do
    lockers = Lockers.list_lockers()
    max_lockers = Settings.get(:max_lockers, 50)

    {:ok,
     socket
     |> assign(:lockers, lockers)
     |> assign(:max_lockers, max_lockers)
     |> assign(:page_title, "Locker Management")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <h2 class="text-2xl font-bold">Locker Management</h2>
      <p class="text-gray-600">
        Managing {@max_lockers} lockers. {length(@lockers)} configured.
      </p>

      <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
        <div :for={locker <- @lockers} class={[
          "p-4 rounded-lg border-2",
          locker.status == "available" && "border-green-300 bg-green-50",
          locker.status == "occupied" && "border-red-300 bg-red-50",
          locker.status == "maintenance" && "border-yellow-300 bg-yellow-50"
        ]}>
          <div class="font-mono text-lg font-bold">{locker.locker_number}</div>
          <div class="text-sm text-gray-500 mt-1">{locker.status}</div>
        </div>
      </div>
    </div>
    """
  end
end
```

---

## 10. Error Handling & Safety

### Plugin Isolation Principles

- **Hook errors don't crash the host.** `Voile.Hooks` wraps all handler calls in `try/rescue`.
  A broken plugin filter logs an error and returns the previous value.
- **Migration failures are reported, not ignored.** `PluginManager.install/1` returns
  `{:error, reason}` and sets status `:error` in the DB. The admin sees the error.
- **`on_activate` failure doesn't leave partial state.** If `on_activate/0` fails,
  PluginManager does not register any hooks.
- **No hard FK constraints from plugin tables to core tables.** Plugins reference core
  entities (e.g., `node_id`, `visitor_id`) as soft references (plain column, no
  `references/2`). If a core entity is deleted, the plugin data is orphaned but the
  DB doesn't error. Plugins should handle this in their context logic.
- **Migration collisions are caught before running.** The Migrator validates that no
  plugin migration version overlaps with existing migrations.

### Error Recovery

```elixir
# Admin can check error details:
case Voile.PluginManager.status(VoileLockerLuggage) do
  :error ->
    record = Voile.Plugins.get_plugin_by_plugin_id("locker_luggage")
    IO.puts("Error: #{record.error_message}")
  status ->
    IO.puts("Status: #{status}")
end

# And retry:
Voile.PluginManager.install(VoileLockerLuggage)
```

---

## 11. Naming Conventions & Rules

| Item             | Convention                         | Example                                       |
| ---------------- | ---------------------------------- | --------------------------------------------- |
| OTP app name     | `:voile_` prefix                   | `:voile_locker_luggage`                       |
| Main module      | `Voile` prefix recommended         | `VoileLockerLuggage`                          |
| Plugin `id`      | lowercase snake_case, never change | `"locker_luggage"`                            |
| Table names      | `plugin_<id>_<entity>`             | `plugin_locker_luggage_lockers`               |
| Migration module | `<Module>.Migrations.<Name>`       | `VoileLockerLuggage.Migrations.CreateLockers` |
| Hook names       | lowercase snake_case atoms         | `:dashboard_widgets`                          |
| Settings keys    | lowercase snake_case atoms         | `:max_lockers`                                |
| Migrator module  | `<Module>.Migrator`                | `VoileLockerLuggage.Migrator`                 |
| Route URL prefix | `/manage/plugins/<id>`             | `/manage/plugins/locker_luggage`              |

### Golden Rules

1. **Use `Voile.Repo` directly** — no wrapper modules.
2. **Never create FK constraints pointing at core tables.** Use soft references.
3. **Always prefix plugin table names with `plugin_`.**
4. **Never change the plugin `id` after release** — it's the primary key for settings and DB records.
5. **`on_install/0` must be idempotent** — Ecto Migrator skips already-run migrations.
6. **`on_deactivate/0` must never drop data** — only deactivate hooks and processes.
7. **Use globally unique migration module names** — always namespace with your plugin module.
8. **Use unique migration timestamps** — check for collisions against core migrations.

---

## 12. Testing Plugins

### Testing Plugin Contexts

```elixir
# test/voile_locker_luggage/lockers_test.exs
defmodule VoileLockerLuggage.LockersTest do
  use Voile.DataCase  # or your test setup that provides Ecto sandbox

  alias VoileLockerLuggage.{Lockers, Locker}

  setup do
    # Run plugin migrations in test
    VoileLockerLuggage.Migrator.run()
    :ok
  end

  test "creates a locker" do
    {:ok, locker} = Lockers.create_locker(%{
      locker_number: "A-001",
      node_id: 1
    })

    assert locker.locker_number == "A-001"
    assert locker.status == "available"
  end
end
```

### Testing Hooks

```elixir
# test/voile/hooks_test.exs
defmodule Voile.HooksTest do
  use ExUnit.Case

  setup do
    start_supervised!(Voile.Hooks)
    :ok
  end

  test "run_filter chains handlers" do
    Voile.Hooks.register(:test_filter, fn list -> list ++ [:a] end, owner: TestPlugin)
    Voile.Hooks.register(:test_filter, fn list -> list ++ [:b] end, owner: TestPlugin)

    result = Voile.Hooks.run_filter(:test_filter, [])
    assert result == [:a, :b]
  end

  test "handler error doesn't crash the chain" do
    Voile.Hooks.register(:test_filter, fn _ -> raise "boom" end, owner: BadPlugin)
    Voile.Hooks.register(:test_filter, fn list -> list ++ [:ok] end, owner: GoodPlugin)

    result = Voile.Hooks.run_filter(:test_filter, [])
    assert result == [:ok]
  end

  test "unregister_all removes all hooks for a plugin" do
    Voile.Hooks.register(:test_hook, fn x -> x end, owner: MyPlugin)
    Voile.Hooks.unregister_all(MyPlugin)

    assert Voile.Hooks.list_handlers(:test_hook) == []
  end
end
```

---

## 13. Implementation Phases

| Phase                         | Description                                                                                                                     | Files to Create/Modify                                                                              |
| ----------------------------- | ------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------- |
| **Phase 0: Prep**             | Refactor dashboard to extract widget rendering into components                                                                  | `dashboard_live.ex`                                                                                 |
| **Phase 1: Hooks**            | Build `Voile.Hooks` with persistent_term. Wire into 2-3 core hook points (dashboard_widgets, admin_nav, collection_before_save) | `lib/voile/hooks.ex`, `dashboard_live.ex`, `catalog.ex`                                             |
| **Phase 2: Plugin Behaviour** | Create `Voile.Plugin` behaviour and `Voile.Plugin.Migrator` macro                                                               | `lib/voile/plugin.ex`, `lib/voile/plugin/migrator.ex`                                               |
| **Phase 3: Plugin Manager**   | Build `Voile.PluginManager` with ETS, `PluginRecord` schema, `Plugins` context, DB migration                                    | `lib/voile/plugin_manager.ex`, `lib/voile/plugin_record.ex`, `lib/voile/plugins.ex`, migration file |
| **Phase 4: Wiring**           | Add to Application supervisor, add plugin routes to router, build plugin admin page                                             | `application.ex`, `router.ex`, `Dashboard.Plugins.Index`, `PluginRouterLive`                        |
| **Phase 5: Settings UI**      | Build plugin settings LiveView                                                                                                  | `Dashboard.Plugins.Settings`                                                                        |
| **Phase 6: First Plugin**     | Build `voile_locker_luggage` as a separate OTP app to validate the full lifecycle                                               | Separate repo/app                                                                                   |
| **Phase 7: Documentation**    | Write plugin developer guide, create template repository                                                                        | `docs/features/plugins/`, template repo                                                             |

---

## 14. Complete File Tree Reference

### Files to add to Voile core:

```
lib/voile/
├── hooks.ex                          # Action/filter hook system (persistent_term)
├── plugin.ex                         # Behaviour definition
├── plugin_manager.ex                 # GenServer+ETS lifecycle manager
├── plugin_record.ex                  # Ecto schema for voile_plugins table
├── plugins.ex                        # Context for plugin DB records
└── plugin/
    └── migrator.ex                   # use Voile.Plugin.Migrator macro

lib/voile_web/live/
├── plugin_router_live.ex             # Dynamic plugin route dispatcher
└── dashboard/
    └── plugins/
        ├── index.ex                  # Plugin management admin page
        └── settings.ex              # Per-plugin settings form

priv/repo/migrations/
└── YYYYMMDDHHMMSS_create_voile_plugins.exs
```

### Files in every plugin OTP app:

```
voile_my_plugin/
├── mix.exs
├── README.md
├── lib/
│   ├── voile_my_plugin.ex              # @behaviour Voile.Plugin (main entry)
│   └── voile_my_plugin/
│       ├── migrator.ex                 # use Voile.Plugin.Migrator, otp_app: :voile_my_plugin
│       ├── settings.ex                 # Settings convenience wrapper
│       ├── my_entity.ex                # Ecto Schema(s)
│       ├── my_entities.ex              # Context (business logic)
│       └── web/
│           └── live/
│               ├── index_live.ex       # Plugin UI LiveViews
│               └── components/
│                   └── dashboard_widget.ex
├── priv/
│   └── migrations/
│       └── 20240601000001_create_plugin_my_plugin_entities.exs
└── test/
    └── voile_my_plugin/
        └── my_entities_test.exs
```
