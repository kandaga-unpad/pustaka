defmodule Voile.Schema.Master.Location do
  use Ecto.Schema
  import Ecto.Changeset

  alias Voile.Schema.System.Node

  schema "mst_locations" do
    field :location_code, :string
    field :location_name, :string
    field :location_place, :string
    field :location_type, :string
    field :description, :string
    field :notes, :string
    field :is_active, :boolean, default: true

    belongs_to :node, Node

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(locations, attrs) do
    locations
    |> cast(attrs, [
      :location_code,
      :location_name,
      :location_place,
      :location_type,
      :description,
      :notes,
      :is_active,
      :node_id
    ])
    |> validate_required([:location_code, :location_name, :location_place, :node_id])
    |> unique_constraint(:location_code)
  end
end
