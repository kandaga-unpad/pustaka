defmodule Voile.Schema.Catalog.Item do
  use Ecto.Schema
  import Ecto.Changeset

  alias Voile.Schema.System.Node
  alias Voile.Schema.Catalog.Collection

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "items" do
    field :status, :string
    field :location, :string
    field :item_code, :string
    field :inventory_code, :string
    field :condition, :string
    field :availability, :string
    belongs_to :collection, Collection, type: :binary_id
    belongs_to :node, Node, foreign_key: :unit_id

    timestamps(type: :utc_datetime)
  end

  @statuses ~w(active inactive lost damaged)
  @conditions ~w(new good fair poor)
  @availabilities ~w(available checked_out reserved maintenance)

  @doc false
  def changeset(item, attrs) do
    item
    |> cast(attrs, [
      :item_code,
      :inventory_code,
      :location,
      :status,
      :condition,
      :availability,
      :collection_id,
      :unit_id
    ])
    |> validate_required([
      :item_code,
      :inventory_code,
      :location,
      :status,
      :condition,
      :availability
    ])
    |> unique_constraint(:item_code)
    |> unique_constraint(:inventory_code)
    |> validate_inclusion(:status, @statuses)
    |> validate_inclusion(:condition, @conditions)
    |> validate_inclusion(:availability, @availabilities)
  end
end
