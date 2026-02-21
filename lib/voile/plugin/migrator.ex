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

      # ── Private ────────────────────────────────────────────────────────────────

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
