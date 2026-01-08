defmodule Voile.Schema.StockOpname.Item do
  use Ecto.Schema
  import Ecto.Changeset

  alias Voile.Schema.Accounts.User
  alias Voile.Schema.StockOpname.Session
  alias Voile.Schema.Catalog.Item, as: CatalogItem
  alias Voile.Schema.Catalog.Collection

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "stock_opname_items" do
    # Changes recorded by librarian (only when differences found)
    # Structure: %{"status" => "damaged", "condition" => "poor", "location" => "Storage"}
    field :changes, :map
    field :scanned_barcode, :string

    # Check result
    field :check_status, :string, default: "pending"
    field :has_changes, :boolean, default: false
    field :notes, :string
    field :scanned_at, :utc_datetime

    belongs_to :session, Session, type: :binary_id
    belongs_to :item, CatalogItem, type: :binary_id
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
      :changes,
      :scanned_barcode,
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
      changes = get_field(changeset, :changes) || %{}
      has_changes = map_size(changes) > 0
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
  Create minimal item record for stock opname initialization.
  Only stores item_id and collection_id - changes recorded later by librarian.
  """
  def minimal_item_attrs(item_id, collection_id, session_id) do
    %{
      session_id: session_id,
      item_id: item_id,
      collection_id: collection_id,
      check_status: "pending"
    }
  end

  @doc """
  Record changes found by librarian during checking.
  Only stores the changed fields in JSONB.

  Example changes: %{
    "status" => "damaged",
    "condition" => "poor",
    "location" => "Storage Room",
    "availability" => "unavailable"
  }
  """
  def record_changes_changeset(opname_item, changes, checked_by_id) do
    opname_item
    |> changeset(%{
      changes: changes,
      check_status: "checked",
      scanned_at: DateTime.utc_now(),
      checked_by_id: checked_by_id,
      has_changes: map_size(changes) > 0
    })
  end
end
