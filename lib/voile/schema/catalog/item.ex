defmodule Voile.Schema.Catalog.Item do
  use Ecto.Schema
  import Ecto.Changeset

  alias Voile.Schema.System.Node
  alias Voile.Schema.Catalog.Collection
  alias Voile.Schema.Catalog.Attachment

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "items" do
    field :item_code, :string
    field :inventory_code, :string
    field :location, :string
    field :status, :string
    field :condition, :string
    field :availability, :string
    field :price, :decimal
    field :acquisition_date, :date
    field :last_inventory_date, :date
    field :last_circulated, :naive_datetime
    field :rfid_tag, :string
    belongs_to :collection, Collection, type: :binary_id
    belongs_to :node, Node, foreign_key: :unit_id

    has_many :attachments, Attachment,
      where: [attachable_type: "item"],
      foreign_key: :attachable_id,
      on_delete: :delete_all

    timestamps(type: :naive_datetime)
  end

  @statuses ~w(active inactive lost damaged discarded)
  @conditions ~w(excellent good fair poor damaged)
  @availabilities ~w(available loaned reserved maintenance)

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
      :price,
      :acquisition_date,
      :last_inventory_date,
      :last_circulated,
      :rfid_tag,
      :location,
      :collection_id,
      :unit_id
    ])
    |> cast_assoc(:attachments, with: &Attachment.changeset/2, required: false)
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

  @doc """
  Get attachments for this item filtered by file type
  """
  def attachments_by_type(item, file_type) do
    item.attachments
    |> Enum.filter(&(&1.file_type == file_type))
  end

  @doc """
  Get primary attachment for this item
  """
  def primary_attachment(item) do
    item.attachments
    |> Enum.find(&(&1.is_primary == true))
  end
end
