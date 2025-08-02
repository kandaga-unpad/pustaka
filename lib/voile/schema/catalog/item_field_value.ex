defmodule Voile.Schema.Catalog.ItemFieldValue do
  use Ecto.Schema
  import Ecto.Changeset

  alias Voile.Schema.Catalog.Item
  alias Voile.Schema.Catalog.CollectionField

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "item_field_values" do
    field :value, :string
    field :locale, :string
    belongs_to :item, Item, type: :binary_id
    belongs_to :collection_field, CollectionField, type: :binary_id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(item_field_value, attrs) do
    item_field_value
    |> cast(attrs, [:value, :locale, :item_id, :collection_field_id])
    |> validate_required([:value, :locale, :item_id, :collection_field_id])
  end
end
