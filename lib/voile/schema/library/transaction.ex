defmodule Voile.Schema.Library.Transaction do
  use Ecto.Schema
  import Ecto.Changeset

  alias Voile.Schema.Catalog.Item
  alias Voile.Schema.Accounts.User

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "lib_transactions" do
    field :transaction_type, :string
    field :transaction_date, :utc_datetime
    field :due_date, :utc_datetime
    field :return_date, :utc_datetime
    field :renewal_count, :integer, default: 0
    field :notes, :string
    field :status, :string
    field :fine_amount, :decimal, default: 0.0
    field :is_overdue, :boolean, default: false

    belongs_to :item, Item, type: :binary_id
    belongs_to :member, User, type: :binary_id
    belongs_to :librarian, User, foreign_key: :librarian_id, type: :binary_id

    timestamps(type: :utc_datetime)
  end

  @transaction_types ~w(loan return renewal lost_item damaged_item cancel)
  @statuses ~w(active returned overdue lost damaged canceled)

  @doc false
  def changeset(transaction, attrs) do
    transaction
    |> cast(attrs, [
      :transaction_type,
      :transaction_date,
      :due_date,
      :return_date,
      :renewal_count,
      :notes,
      :status,
      :fine_amount,
      :is_overdue,
      :member_id,
      :item_id,
      :librarian_id
    ])
    |> validate_required([
      :transaction_type,
      :transaction_date,
      :member_id,
      :item_id,
      :librarian_id
    ])
    |> validate_inclusion(:transaction_type, @transaction_types)
    |> validate_inclusion(:status, @statuses)
    |> validate_number(:renewal_count, greater_than_or_equal_to: 0)
    |> validate_number(:fine_amount, greater_than_or_equal_to: 0)
    |> foreign_key_constraint(:member_id)
    |> foreign_key_constraint(:item_id)
    |> foreign_key_constraint(:librarian_id)
  end

  def overdue?(%__MODULE__{due_date: due_date, return_date: nil}) do
    DateTime.compare(due_date, DateTime.utc_now()) == :lt
  end

  def overdue?(_), do: false

  def days_overdue(%__MODULE__{due_date: due_date, return_date: nil}) do
    case DateTime.compare(due_date, DateTime.utc_now()) do
      :lt -> DateTime.diff(DateTime.utc_now(), due_date, :day)
      _ -> 0
    end
  end

  def days_overdue(_), do: 0
end
