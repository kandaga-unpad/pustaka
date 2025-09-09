defmodule Voile.Schema.System.SystemLog do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "system_logs" do
    field :log_msg, :string
    field :log_type, :string
    field :log_location, :string
    field :log_date, :utc_datetime
    field :users, :binary_id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(system_log, attrs) do
    system_log
    |> cast(attrs, [:log_type, :log_location, :log_msg, :log_date])
    |> validate_required([:log_type, :log_location, :log_msg, :log_date])
  end
end
