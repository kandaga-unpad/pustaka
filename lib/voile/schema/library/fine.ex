defmodule Voile.Schema.Library.Fine do
  use Ecto.Schema
  import Ecto.Changeset

  alias Voile.Schema.Accounts.User
  alias Voile.Schema.Catalog.Item
  alias Voile.Schema.Library.Transaction

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "lib_fines" do
    field :fine_type, :string
    field :amount, :decimal
    field :paid_amount, :decimal, default: 0.0
    field :balance, :decimal
    field :fine_date, :utc_datetime
    field :payment_date, :utc_datetime
    field :fine_status, :string
    field :description, :string
    field :waived, :boolean, default: false
    field :waived_date, :utc_datetime
    field :waived_reason, :string
    field :payment_method, :string
    field :receipt_number, :string

    belongs_to :member, User, foreign_key: :member_id, type: :binary_id
    belongs_to :item, Item, type: :binary_id
    belongs_to :transaction, Transaction, type: :binary_id
    belongs_to :processed_by, User, foreign_key: :processed_by_id, type: :binary_id
    belongs_to :waived_by, User, foreign_key: :waived_by_id, type: :binary_id

    timestamps(type: :utc_datetime)
  end

  @fine_types ~w(overdue lost_item damaged_item processing)
  @statuses ~w(pending partial_paid paid waived)
  @payment_methods ~w(cash credit_card debit_card bank_transfer online)

  def changeset(fine, attrs) do
    fine
    |> cast(attrs, [
      :fine_type,
      :amount,
      :paid_amount,
      :balance,
      :fine_date,
      :payment_date,
      :fine_status,
      :description,
      :waived,
      :waived_date,
      :waived_reason,
      :payment_method,
      :receipt_number,
      :member_id,
      :item_id,
      :transaction_id,
      :processed_by_id,
      :waived_by_id
    ])
    |> validate_required([:fine_type, :amount, :fine_date, :fine_status, :member_id])
    |> validate_inclusion(:fine_type, @fine_types)
    |> validate_inclusion(:fine_status, @statuses)
    |> validate_inclusion(:payment_method, @payment_methods)
    |> validate_number(:amount, greater_than: 0)
    |> validate_number(:paid_amount, greater_than_or_equal_to: 0)
    |> validate_number(:balance, greater_than_or_equal_to: 0)
    |> calculate_balance()
    |> foreign_key_constraint(:member_id)
    |> foreign_key_constraint(:item_id)
    |> foreign_key_constraint(:transaction_id)
  end

  defp calculate_balance(changeset) do
    amount = get_field(changeset, :amount) || Decimal.new("0")
    paid_amount = get_field(changeset, :paid_amount) || Decimal.new("0")
    balance = Decimal.sub(amount, paid_amount)
    put_change(changeset, :balance, balance)
  end

  def fully_paid?(%__MODULE__{balance: balance}) do
    Decimal.equal?(balance, 0)
  end
end
