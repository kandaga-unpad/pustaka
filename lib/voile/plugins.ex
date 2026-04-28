defmodule Voile.Plugins do
  @moduledoc "Context for managing plugin records in the Voile database."

  import Ecto.Query
  alias Voile.{Repo, PluginRecord}

  @doc "List all plugins ordered by name."
  def list_plugins do
    PluginRecord
    |> order_by(:name)
    |> Repo.all()
  end

  @doc "List plugins filtered by status."
  def list_plugins_by_status(status) do
    PluginRecord
    |> where([p], p.status == ^status)
    |> Repo.all()
  end

  @doc "Get a plugin by its primary key."
  def get_plugin!(id), do: Repo.get!(PluginRecord, id)

  @doc "Get a plugin by its unique plugin_id."
  def get_plugin_by_plugin_id(plugin_id) do
    Repo.get_by(PluginRecord, plugin_id: plugin_id)
  end

  @doc """
  Insert or update a plugin record based on plugin_id.
  If the plugin_id exists, updates the existing record.
  """
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

  @doc """
  Update the status of a plugin by plugin_id.
  Optionally accepts an error_message for :error status.
  Automatically sets activated_at or deactivated_at timestamps.
  """
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

  # ── Settings ─────────────────────────────────────────────────────────────────

  @doc """
  Get a single setting value for a plugin.
  Returns default if plugin or key not found.
  """
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
          update: [
            set: [
              settings:
                fragment(
                  "COALESCE(?, '{}'::jsonb) || ?",
                  p.settings,
                  type(^%{to_string(key) => value}, :map)
                )
            ]
          ]
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
          update: [
            set: [
              settings:
                fragment(
                  "COALESCE(?, '{}'::jsonb) || ?",
                  p.settings,
                  type(^stringified, :map)
                )
            ]
          ]
        )
        |> Repo.update_all([])

        {:ok, get_plugin_by_plugin_id(plugin_id)}
    end
  end

  @doc """
  Delete a plugin record by plugin_id.
  Used during uninstall when remove_data is true.
  """
  def delete_plugin(plugin_id) do
    case get_plugin_by_plugin_id(plugin_id) do
      nil -> {:error, :not_found}
      record -> Repo.delete(record)
    end
  end
end
