defmodule Voile.Schema.Library.Transaction do
  use Ecto.Schema
  import Ecto.Changeset

  alias Voile.Schema.Catalog.Item
  alias Voile.Schema.Accounts.User
  alias Voile.Schema.System.Node

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "lib_transactions" do
    field :transaction_type, :string
    field :transaction_date, :utc_datetime
    field :due_date, :utc_datetime
    field :return_date, :utc_datetime
    field :renewal_count, :integer, default: 0
    field :notes, :string
    field :status, :string
    field :fine_amount, :decimal, default: Decimal.new("0")
    field :is_overdue, :boolean, default: false

    belongs_to :item, Item, type: :binary_id
    belongs_to :member, User, type: :binary_id
    belongs_to :librarian, User, foreign_key: :librarian_id, type: :binary_id
    belongs_to :node, Node, foreign_key: :unit_id

    has_one :collection, through: [:item, :collection]

    timestamps(type: :utc_datetime)
  end

  @transaction_types ~w(loan return renewal lost_item damaged_item cancel)
  @statuses ~w(active returned overdue lost damaged canceled)

  @doc false
  def changeset(transaction, attrs) do
    attrs = normalize_params(attrs)

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
      :unit_id,
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
    |> foreign_key_constraint(:unit_id)
    |> validate_inclusion(:transaction_type, @transaction_types)
    |> validate_inclusion(:status, @statuses)
    |> validate_number(:renewal_count, greater_than_or_equal_to: 0)
    |> validate_number(:fine_amount, greater_than_or_equal_to: 0)
    |> foreign_key_constraint(:member_id)
    |> foreign_key_constraint(:item_id)
    |> foreign_key_constraint(:librarian_id)
  end

  defp normalize_params(params) when is_map(params) do
    params
    |> Enum.map(fn {k, v} ->
      key = if is_atom(k), do: Atom.to_string(k), else: k
      {key, v}
    end)
    |> Enum.into(%{})
  end

  defp normalize_params(val), do: val

  def overdue?(%__MODULE__{due_date: due_date, return_date: nil}) do
    # use UTC dates by default; function accepts a timezone if needed later
    due_date_only = local_date(due_date)
    today = local_today()
    Date.compare(due_date_only, today) == :lt
  end

  def overdue?(_), do: false

  @doc """
  Calculates days overdue using business days (excluding holidays and weekends).
  This is the default calculation that respects the library's holiday calendar.
  """
  def days_overdue(%__MODULE__{due_date: due_date, return_date: nil}) do
    due_date_only = local_date(due_date)
    today = local_today()

    case Date.compare(due_date_only, today) do
      :lt ->
        alias Voile.Schema.System.LibHoliday
        start_day = Date.add(due_date_only, 1)
        LibHoliday.business_days_between(start_day, today)

      _ ->
        0
    end
  end

  def days_overdue(_), do: 0

  @doc """
  Calculates days overdue using calendar days (ALL days, no holiday exclusion).
  Use this when the library policy is to count every single day for fines,
  regardless of whether it's a holiday or weekend.
  """
  def calendar_days_overdue(%__MODULE__{due_date: due_date, return_date: nil}) do
    due_date_only = local_date(due_date)
    today = local_today()

    case Date.compare(due_date_only, today) do
      :lt ->
        Date.diff(today, due_date_only)

      _ ->
        0
    end
  end

  def calendar_days_overdue(_), do: 0

  # helper to convert UTC datetime to a local date
  defp local_date(dt, tz \\ "UTC")

  defp local_date(%DateTime{} = dt, tz) do
    case DateTime.shift_zone(dt, tz) do
      {:ok, shifted} -> DateTime.to_date(shifted)
      _ -> DateTime.to_date(dt)
    end
  end

  defp local_date(%Date{} = d, _tz), do: d

  defp local_today(tz \\ "UTC") do
    DateTime.utc_now()
    |> DateTime.shift_zone(tz)
    |> case do
      {:ok, shifted} -> DateTime.to_date(shifted)
      _ -> Date.utc_today()
    end
  end

  @doc """
  Calculates days overdue with optional skip_holidays flag.

  - When skip_holidays is true: counts ALL calendar days (no holiday exclusion)
  - When skip_holidays is false (default): counts only business days (excludes holidays)

  This allows flexible fine calculation based on library policy configuration.
  """
  def calculate_days_overdue(%__MODULE__{} = transaction, skip_holidays \\ false) do
    if skip_holidays do
      calendar_days_overdue(transaction)
    else
      days_overdue(transaction)
    end
  end
end
