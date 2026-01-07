defmodule Voile.Schema.Catalog.StockOpnameItem do
  use Ecto.Schema
  import Ecto.Changeset

  alias Voile.Schema.Accounts.User
  alias Voile.Schema.Catalog.{StockOpnameSession, Item, Collection}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "stock_opname_items" do
    # Snapshot data
    field :item_code, :string
    field :inventory_code, :string
    field :barcode, :string
    field :legacy_item_code, :string
    field :collection_title, :string

    # Before state
    field :status_before, :string
    field :condition_before, :string
    field :availability_before, :string
    field :location_before, :string
    field :item_location_id_before, :integer

    # After state
    field :status_after, :string
    field :condition_after, :string
    field :availability_after, :string
    field :location_after, :string
    field :item_location_id_after, :integer

    # Check result
    field :check_status, :string, default: "pending"
    field :has_changes, :boolean, default: false
    field :notes, :string
    field :scanned_at, :utc_datetime

    belongs_to :session, StockOpnameSession, type: :binary_id
    belongs_to :item, Item, type: :binary_id
    belongs_to :collection, Collection, type: :binary_id
    belongs_to :checked_by, User, foreign_key: :checked_by_id, type: :binary_id

    timestamps(type: :utc_datetime)
  end

  @check_statuses ~w(pending checked missing needs_attention)

  @doc false
  def changeset(opname_item, attrs) do
    opname_item
    |> cast(attrs, [
      :session_id,
      :item_id,
      :collection_id,
      :item_code,
      :inventory_code,
      :barcode,
      :legacy_item_code,
      :collection_title,
      :status_before,
      :condition_before,
      :availability_before,
      :location_before,
      :item_location_id_before,
      :status_after,
      :condition_after,
      :availability_after,
      :location_after,
      :item_location_id_after,
      :check_status,
      :has_changes,
      :notes,
      :scanned_at,
      :checked_by_id
    ])
    |> validate_required([:session_id, :item_id, :check_status])
    |> validate_inclusion(:check_status, @check_statuses)
    |> unique_constraint([:session_id, :item_id],
      name: :stock_opname_items_session_id_item_id_index,
      message: "item already added to this session"
    )
    |> detect_changes()
  end

  defp detect_changes(changeset) do
    if changeset.valid? do
      status_before = get_field(changeset, :status_before)
      status_after = get_field(changeset, :status_after)
      condition_before = get_field(changeset, :condition_before)
      condition_after = get_field(changeset, :condition_after)
      availability_before = get_field(changeset, :availability_before)
      availability_after = get_field(changeset, :availability_after)
      location_before = get_field(changeset, :location_before)
      location_after = get_field(changeset, :location_after)
      location_id_before = get_field(changeset, :item_location_id_before)
      location_id_after = get_field(changeset, :item_location_id_after)

      has_changes =
        status_before != status_after or
          condition_before != condition_after or
          availability_before != availability_after or
          location_before != location_after or
          location_id_before != location_id_after

      put_change(changeset, :has_changes, has_changes)
    else
      changeset
    end
  end

  @doc """
  Returns check status options for display
  """
  def check_status_options do
    [
      {"Pending", "pending"},
      {"Checked", "checked"},
      {"Missing", "missing"},
      {"Needs Attention", "needs_attention"}
    ]
  end

  @doc """
  Get check status badge color for UI
  """
  def check_status_color(status) do
    case status do
      "pending" -> "gray"
      "checked" -> "green"
      "missing" -> "red"
      "needs_attention" -> "yellow"
      _ -> "gray"
    end
  end

  @doc """
  Create snapshot from an Item struct
  """
  def snapshot_from_item(%Item{} = item, session_id) do
    %{
      session_id: session_id,
      item_id: item.id,
      collection_id: item.collection_id,
      item_code: item.item_code,
      inventory_code: item.inventory_code,
      barcode: item.barcode,
      legacy_item_code: item.legacy_item_code,
      collection_title: if(item.collection, do: item.collection.title, else: nil),
      status_before: item.status,
      condition_before: item.condition,
      availability_before: item.availability,
      location_before: item.location,
      item_location_id_before: item.item_location_id,
      status_after: item.status,
      condition_after: item.condition,
      availability_after: item.availability,
      location_after: item.location,
      item_location_id_after: item.item_location_id,
      check_status: "pending"
    }
  end
end
