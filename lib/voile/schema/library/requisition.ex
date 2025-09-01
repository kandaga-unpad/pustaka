defmodule Voile.Schema.Library.Requisition do
  use Ecto.Schema
  import Ecto.Changeset

  alias Voile.Schema.Accounts.User
  alias Voile.Schema.System.Node

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "lib_requisitions" do
    field :request_date, :utc_datetime
    field :request_type, :string
    field :status, :string
    field :title, :string
    field :author, :string
    field :publisher, :string
    field :isbn, :string
    field :publication_year, :integer
    field :description, :string
    field :justification, :string
    field :priority, :string, default: "normal"
    field :estimated_cost, :decimal
    field :notes, :string
    field :staff_notes, :string
    field :due_date, :date
    field :fulfilled_date, :utc_datetime

    belongs_to :requested_by, User, foreign_key: :requested_by_id, type: :binary_id
    belongs_to :assigned_to, User, foreign_key: :assigned_to_id, type: :binary_id
    belongs_to :unit, Node, foreign_key: :unit_id, type: :binary_id

    timestamps(type: :utc_datetime)
  end

  @patron_request_type ~w(purchase_request interlibrary_loan digitization_request reference_question)
  @patron_request_status ~w(submitted reviewing approved rejected fulfilled cancelled)
  @priority ~w(low normal high urgent)

  @doc false
  def changeset(requisition, attrs) do
    requisition
    |> cast(attrs, [
      :request_date,
      :request_type,
      :status,
      :title,
      :author,
      :publisher,
      :isbn,
      :publication_year,
      :description,
      :justification,
      :priority,
      :estimated_cost,
      :notes,
      :staff_notes,
      :due_date,
      :fullfilled_date,
      :requested_by_id,
      :assigned_to_id,
      :unit_id
    ])
    |> validate_required([
      :request_date,
      :request_type,
      :status,
      :title,
      :requested_by_id
    ])
    |> unique_constraint(:title)
    |> validate_inclusion(:request_type, @patron_request_type)
    |> validate_inclusion(:status, @patron_request_status)
    |> validate_inclusion(:priority, @priority)
    |> validate_isbn_format()
    |> validate_cost_positive()
    |> validate_dates_logical()
  end

  defp validate_isbn_format(changeset) do
    validate_change(changeset, :isbn, fn :isbn, isbn ->
      if isbn && !String.match?(isbn, ~r/^(?:\d{10}|\d{13})$/) do
        [isbn: "must be a valid 10 or 13 digit ISBN"]
      else
        []
      end
    end)
  end

  defp validate_cost_positive(changeset) do
    validate_change(changeset, :estimated_cost, fn :estimated_cost, cost ->
      if cost && Decimal.compare(cost, Decimal.new(0)) == :lt do
        [estimated_cost: "must be positive"]
      else
        []
      end
    end)
  end

  defp validate_dates_logical(changeset) do
    request_date = get_field(changeset, :request_date)
    due_date = get_field(changeset, :due_date)

    if request_date && due_date && Date.compare(due_date, DateTime.to_date(request_date)) == :lt do
      add_error(changeset, :due_date, "cannot be before request date")
    else
      changeset
    end
  end
end
