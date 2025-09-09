defmodule Voile.Schema.System.Setting do
  use Ecto.Schema
  import Ecto.Changeset

  schema "settings" do
    field :setting_name, :string
    field :setting_value, :string

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(setting, attrs) do
    setting
    |> cast(attrs, [:setting_name, :setting_value])
    |> validate_required([:setting_name, :setting_value])
  end
end
