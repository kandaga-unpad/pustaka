defmodule Voile.Schema.StockOpname.Session do
  use Ecto.Schema
  import Ecto.Changeset

  alias Voile.Schema.Accounts.User
  alias Voile.Schema.StockOpname.{Item, LibrarianAssignment}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "stock_opname_sessions" do
    field :session_code, :string
    field :title, :string
    field :description, :string

    # Scope configuration
    field :node_ids, {:array, :integer}
    field :collection_types, {:array, :string}
    field :scope_type, :string
    field :scope_id, :string

    # Status tracking
    field :status, :string, default: "draft"

    # Workflow timestamps
    field :started_at, :utc_datetime
    field :completed_at, :utc_datetime
    field :reviewed_at, :utc_datetime
    field :approved_at, :utc_datetime

    # Counters
    field :total_items, :integer, default: 0
    field :checked_items, :integer, default: 0
    field :missing_items, :integer, default: 0
    field :items_with_changes, :integer, default: 0

    # Notes
    field :notes, :string
    field :review_notes, :string
    field :rejection_reason, :string

    # User tracking
    belongs_to :created_by, User, foreign_key: :created_by_id, type: :binary_id
    belongs_to :updated_by, User, foreign_key: :updated_by_id, type: :binary_id
    belongs_to :reviewed_by, User, foreign_key: :reviewed_by_id, type: :binary_id

    # Associations
    has_many :items, Item, foreign_key: :session_id
    has_many :librarian_assignments, LibrarianAssignment, foreign_key: :session_id

    timestamps(type: :utc_datetime)
  end

  @statuses ~w(draft initializing in_progress completed pending_review applying approved rejected cancelled)
  @scope_types ~w(all collection location)
  @collection_types ~w(Gallery Archive Museum Library)

  @doc false
  def changeset(session, attrs) do
    session
    |> cast(attrs, [
      :session_code,
      :title,
      :description,
      :node_ids,
      :collection_types,
      :scope_type,
      :scope_id,
      :status,
      :started_at,
      :completed_at,
      :reviewed_at,
      :approved_at,
      :total_items,
      :checked_items,
      :missing_items,
      :items_with_changes,
      :notes,
      :review_notes,
      :rejection_reason,
      :created_by_id,
      :updated_by_id,
      :reviewed_by_id
    ])
    |> validate_required([
      :title,
      :node_ids,
      :collection_types,
      :scope_type,
      :status,
      :created_by_id
    ])
    |> validate_inclusion(:status, @statuses)
    |> validate_inclusion(:scope_type, @scope_types)
    |> validate_length(:node_ids, min: 1, message: "at least one node must be selected")
    |> validate_length(:collection_types,
      min: 1,
      message: "at least one collection type must be selected"
    )
    |> validate_collection_types()
    |> maybe_generate_session_code()
    |> unique_constraint(:session_code,
      name: :stock_opname_sessions_session_code_index,
      message: "session code already exists"
    )
  end

  defp validate_collection_types(changeset) do
    types = get_field(changeset, :collection_types) || []
    invalid_types = types -- @collection_types

    if invalid_types == [] do
      changeset
    else
      add_error(changeset, :collection_types, "contains invalid types: #{inspect(invalid_types)}")
    end
  end

  defp maybe_generate_session_code(changeset) do
    if get_field(changeset, :session_code) do
      changeset
    else
      # Generate code like "SO-2026-ABC123"
      now = DateTime.utc_now()
      year = now.year
      # Use timestamp + random string for uniqueness
      timestamp = :os.system_time(:millisecond)

      random_suffix =
        timestamp
        |> Integer.to_string(36)
        |> String.upcase()
        |> String.slice(-6..-1)

      code = "SO-#{year}-#{random_suffix}"
      put_change(changeset, :session_code, code)
    end
  end

  @doc """
  Returns status options for display
  """
  def status_options do
    [
      {"Draft", "draft"},
      {"In Progress", "in_progress"},
      {"Completed", "completed"},
      {"Pending Review", "pending_review"},
      {"Applying", "applying"},
      {"Approved", "approved"},
      {"Rejected", "rejected"},
      {"Cancelled", "cancelled"}
    ]
  end

  @doc """
  Returns scope type options
  """
  def scope_type_options do
    [
      {"All Items", "all"},
      {"Specific Collection", "collection"},
      {"Specific Location", "location"}
    ]
  end

  @doc """
  Returns collection type options
  """
  def collection_type_options do
    [
      {"Gallery", "gallery"},
      {"Archive", "archive"},
      {"Museum", "museum"},
      {"Library", "library"}
    ]
  end

  @doc """
  Get status badge color for UI
  """
  def status_color(status) do
    case status do
      "draft" -> "gray"
      "in_progress" -> "blue"
      "completed" -> "yellow"
      "pending_review" -> "orange"
      "applying" -> "blue"
      "approved" -> "green"
      "rejected" -> "red"
      "cancelled" -> "gray"
      _ -> "gray"
    end
  end
end
