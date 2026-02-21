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
    field :plugin_id, :string
    field :module, :string
    field :name, :string
    field :version, :string
    field :author, :string
    field :description, :string
    field :license_type, :string, default: "free"
    field :license_key, :string
    field :status, Ecto.Enum, values: @statuses, default: :installed
    field :error_message, :string
    field :settings, :map, default: %{}
    field :installed_at, :utc_datetime
    field :activated_at, :utc_datetime
    field :deactivated_at, :utc_datetime

    timestamps()
  end

  @doc false
  def changeset(record, attrs) do
    record
    |> cast(attrs, [
      :plugin_id,
      :module,
      :name,
      :version,
      :author,
      :description,
      :license_type,
      :license_key,
      :status,
      :error_message,
      :settings,
      :installed_at,
      :activated_at,
      :deactivated_at
    ])
    |> validate_required([:plugin_id, :module, :name, :version, :status])
    |> unique_constraint(:plugin_id)
    |> unique_constraint(:module)
  end

  @doc "Returns all valid status values"
  def statuses, do: @statuses
end
