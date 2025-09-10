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
    field :paid_amount, :decimal, default: 0
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
    # Set default values for Indonesian context
    attrs =
      attrs
      |> set_default_fine_date()
      |> set_default_fine_status()
      |> set_default_amount_for_type()

    # Normalize param keys to strings to avoid mixed atom/string maps
    attrs = normalize_params(attrs)

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

  # Convert any atom keys to string keys to keep params consistent for Ecto.cast
  defp normalize_params(params) when is_map(params) do
    params
    |> Enum.map(fn {k, v} ->
      key = if is_atom(k), do: Atom.to_string(k), else: k
      {key, v}
    end)
    |> Enum.into(%{})
  end

  defp normalize_params(val), do: val

  @doc """
  Changeset for payment/waiver updates that preserves original fine amount.
  Does not apply default value helpers to avoid overriding existing data.
  """
  def payment_changeset(fine, attrs) do
    fine
    |> cast(attrs, [
      :paid_amount,
      :balance,
      :fine_status,
      :payment_date,
      :payment_method,
      :processed_by_id,
      :receipt_number,
      :waived,
      :waived_date,
      :waived_reason,
      :waived_by_id
    ])
    |> validate_required([:fine_status])
    |> validate_inclusion(:fine_status, @statuses)
    |> validate_inclusion(:payment_method, @payment_methods)
    |> validate_number(:paid_amount, greater_than_or_equal_to: 0)
    |> validate_number(:balance, greater_than_or_equal_to: 0)
    |> calculate_balance()
  end

  # Helper functions for setting defaults
  defp set_default_fine_date(attrs) do
    if attrs["fine_date"] || attrs[:fine_date] do
      attrs
    else
      Map.put(attrs, :fine_date, DateTime.utc_now())
    end
  end

  defp set_default_fine_status(attrs) do
    if attrs["fine_status"] || attrs[:fine_status] do
      attrs
    else
      Map.put(attrs, :fine_status, "pending")
    end
  end

  # Set default amounts based on member type and Indonesian library standards (in IDR)
  defp set_default_amount_for_type(attrs) do
    if attrs["amount"] || attrs[:amount] do
      attrs
    else
      fine_type = attrs["fine_type"] || attrs[:fine_type]
      member_id = attrs["member_id"] || attrs[:member_id]

      default_amount =
        case fine_type do
          "overdue" ->
            # For overdue fines, try to use member type's fine_per_day, fallback to Rp 5,000
            get_member_type_fine_per_day(member_id) || "5000"

          # Rp 50,000 for lost items
          "lost_item" ->
            "50000"

          # Rp 25,000 for damaged items
          "damaged_item" ->
            "25000"

          # Rp 10,000 processing fee
          "processing" ->
            "10000"

          _ ->
            # For other types, try to use member type's daily fine as base, fallback to Rp 5,000
            get_member_type_fine_per_day(member_id) || "5000"
        end

      Map.put(attrs, :amount, default_amount)
    end
  end

  # Helper to get member type's fine_per_day setting
  defp get_member_type_fine_per_day(member_id) when is_binary(member_id) do
    try do
      case Voile.Repo.get(User, member_id) |> Voile.Repo.preload([:user_type]) do
        %User{user_type: %{fine_per_day: fine_per_day}} when not is_nil(fine_per_day) ->
          Decimal.to_string(fine_per_day)

        _ ->
          nil
      end
    rescue
      _ -> nil
    end
  end

  defp get_member_type_fine_per_day(_), do: nil

  defp calculate_balance(changeset) do
    # If balance explicitly provided in attrs, keep it
    case get_change(changeset, :balance) do
      nil ->
        amount = get_field(changeset, :amount) || Decimal.new("0")

        paid_amount =
          case get_field(changeset, :paid_amount) do
            nil -> Decimal.new("0")
            val when is_float(val) -> Decimal.from_float(val)
            val when is_integer(val) -> Decimal.new(val)
            val -> val
          end

        balance = Decimal.sub(amount, paid_amount)
        put_change(changeset, :balance, balance)

      _balance ->
        changeset
    end
  end

  def fully_paid?(%__MODULE__{balance: balance}) do
    Decimal.equal?(balance, 0)
  end
end
