defmodule Voile.Schema.Library.ReadOnSpot do
  use Ecto.Schema
  import Ecto.Changeset

  alias Voile.Schema.Catalog.Item
  alias Voile.Schema.Accounts.User
  alias Voile.Schema.System.Node
  alias Voile.Schema.Master.Location

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "lib_read_on_spots" do
    field :read_at, :utc_datetime
    field :notes, :string

    belongs_to :item, Item, type: :binary_id
    belongs_to :node, Node
    belongs_to :location, Location
    belongs_to :recorded_by, User, foreign_key: :recorded_by_id, type: :binary_id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(read_on_spot, attrs) do
    read_on_spot
    |> cast(attrs, [:read_at, :notes, :item_id, :node_id, :location_id, :recorded_by_id])
    |> validate_required([:item_id, :node_id, :recorded_by_id])
    |> foreign_key_constraint(:item_id)
    |> foreign_key_constraint(:node_id)
    |> foreign_key_constraint(:location_id)
    |> foreign_key_constraint(:recorded_by_id)
  end
end
