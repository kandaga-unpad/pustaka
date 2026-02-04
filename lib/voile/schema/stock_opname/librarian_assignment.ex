defmodule Voile.Schema.StockOpname.LibrarianAssignment do
  use Ecto.Schema
  import Ecto.Changeset

  alias Voile.Schema.Accounts.User
  alias Voile.Schema.StockOpname.Session

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "stock_opname_librarian_assignments" do
    field :work_status, :string, default: "pending"
    field :items_checked, :integer, default: 0
    field :started_at, :utc_datetime
    field :completed_at, :utc_datetime
    field :notes, :string

    belongs_to :session, Session, type: :binary_id
    belongs_to :user, User, type: :binary_id

    timestamps(type: :utc_datetime)
  end

  @work_statuses ~w(pending in_progress completed)

  @doc false
  def changeset(assignment, attrs) do
    assignment
    |> cast(attrs, [
      :session_id,
      :user_id,
      :work_status,
      :items_checked,
      :started_at,
      :completed_at,
      :notes
    ])
    |> validate_required([:session_id, :user_id, :work_status])
    |> validate_inclusion(:work_status, @work_statuses)
    |> unique_constraint([:session_id, :user_id],
      name: :stock_opname_librarian_assignments_session_id_user_id_index,
      message: "librarian already assigned to this session"
    )
  end

  @doc """
  Returns work status options for display
  """
  def work_status_options do
    [
      {"Pending", "pending"},
      {"In Progress", "in_progress"},
      {"Completed", "completed"}
    ]
  end

  @doc """
  Get work status badge color for UI
  """
  def work_status_color(status) do
    case status do
      "pending" -> "gray"
      "in_progress" -> "blue"
      "completed" -> "green"
      _ -> "gray"
    end
  end
end
