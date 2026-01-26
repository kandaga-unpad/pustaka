defmodule Voile.Schema.Catalog.Item do
  use Ecto.Schema
  import Ecto.Changeset

  alias Voile.Schema.Accounts.User
  alias Voile.Schema.System.Node
  alias Voile.Schema.Catalog.Collection
  alias Voile.Schema.Catalog.Attachment
  alias Voile.Schema.Master.Location

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "items" do
    field :item_code, :string
    field :inventory_code, :string
    field :barcode, :string
    field :location, :string
    field :status, :string
    field :condition, :string
    field :availability, :string
    field :price, :decimal
    field :acquisition_date, :date
    field :last_inventory_date, :date
    field :last_circulated, :utc_datetime
    field :rfid_tag, :string
    field :legacy_item_code, :string
    belongs_to :collection, Collection, type: :binary_id
    belongs_to :node, Node, foreign_key: :unit_id
    belongs_to :item_location, Location
    belongs_to :created_by, User, foreign_key: :created_by_id, type: :binary_id
    belongs_to :updated_by, User, foreign_key: :updated_by_id, type: :binary_id

    has_many :attachments, Attachment,
      where: [attachable_type: "item"],
      foreign_key: :attachable_id,
      on_delete: :delete_all

    timestamps(type: :utc_datetime)
  end

  @statuses ~w(active inactive lost damaged discarded)
  @conditions ~w(excellent good fair poor damaged)
  @availabilities ~w(available loaned reserved reference_only non_circulating maintenance conservation in_processing exhibition restricted in_transit missing quarantine)

  @doc """
  Returns availability options suitable for form selects as {label, value} tuples.
  Labels are humanized (underscores replaced with spaces and words capitalized).
  """
  def availability_options do
    Enum.map(@availabilities, fn val ->
      label =
        val
        |> String.replace("_", " ")
        |> String.split(" ")
        |> Enum.map(&String.capitalize/1)
        |> Enum.join(" ")

      {label, val}
    end)
  end

  @doc """
  Returns status options for form selects as {label, value} tuples.
  """
  def status_options do
    Enum.map(@statuses, fn val ->
      label = val |> String.replace("_", " ") |> String.capitalize()
      {label, val}
    end)
  end

  @doc """
  Returns condition options for form selects as {label, value} tuples.
  """
  def condition_options do
    Enum.map(@conditions, fn val ->
      label = val |> String.replace("_", " ") |> String.capitalize()
      {label, val}
    end)
  end

  @doc false
  def changeset(item, attrs) do
    item
    |> cast(attrs, [
      :item_code,
      :inventory_code,
      :barcode,
      :location,
      :status,
      :condition,
      :availability,
      :price,
      :acquisition_date,
      :last_inventory_date,
      :last_circulated,
      :rfid_tag,
      :barcode,
      :legacy_item_code,
      :location,
      :collection_id,
      :unit_id,
      :item_location_id,
      :created_by_id,
      :updated_by_id
    ])
    |> cast_assoc(:attachments, with: &Attachment.changeset/2, required: false)
    |> validate_required([
      :item_code,
      :inventory_code,
      :barcode,
      :location,
      :status,
      :condition,
      :availability
    ])
    |> unique_constraint(:item_code)
    |> unique_constraint(:inventory_code)
    |> unique_constraint(:barcode)
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
