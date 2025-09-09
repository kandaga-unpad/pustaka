defmodule Voile.Schema.Master.Locations do
  use Ecto.Schema
  import Ecto.Changeset

  schema "mst_locations" do
    field :location_code, :string
    field :location_name, :string
    field :location_place, :string

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(locations, attrs) do
    locations
    |> cast(attrs, [:location_code, :location_name, :location_place])
    |> validate_required([:location_code, :location_name, :location_place])
  end
end
