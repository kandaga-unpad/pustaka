defmodule Voile.Schema.Master.Frequency do
  use Ecto.Schema
  import Ecto.Changeset

  schema "mst_frequency" do
    field :time_unit, :string
    field :frequency, :string
    field :time_increment, :integer

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(frequency, attrs) do
    frequency
    |> cast(attrs, [:frequency, :time_increment, :time_unit])
    |> validate_required([:frequency, :time_increment, :time_unit])
  end
end
