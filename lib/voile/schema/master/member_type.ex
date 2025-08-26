defmodule Voile.Schema.Master.MemberType do
  use Ecto.Schema
  import Ecto.Changeset

  alias Decimal

  schema "mst_member_types" do
    field :name, :string
    field :slug, :string
    field :description, :string

    field :max_items, :integer, default: 0
    field :max_days, :integer, default: 0
    field :max_renewals, :integer, default: 0
    field :max_reserves, :integer, default: 0
    field :max_concurrent_loans, :integer, default: 0

    field :fine_per_day, :decimal, default: Decimal.new("0.0")
    field :max_fine, :decimal
    field :membership_fee, :decimal, default: Decimal.new("0.0")
    field :currency, :string, default: "USD"

    field :can_reserve, :boolean, default: true
    field :can_renew, :boolean, default: true
    field :digital_access, :boolean, default: false
    field :exhibition_preview_access, :boolean, default: false
    field :ticket_discount_percent, :integer, default: 0
    field :shop_discount_percent, :integer, default: 0
    field :max_event_bookings_per_year, :integer, default: 0

    field :membership_period_days, :integer
    field :auto_renew, :boolean, default: false
    field :recurrence_unit, :string
    field :recurrence_interval, :integer

    field :priority_level, :integer, default: 1
    field :is_active, :boolean, default: true
    field :publicly_listed, :boolean, default: true

    field :institutional, :boolean, default: false
    field :allowed_collections, :map, default: %{}
    field :metadata, :map, default: %{}

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(member_type, attrs \\ %{}) do
    member_type
    |> cast(attrs, [
      :name,
      :slug,
      :description,
      :max_items,
      :max_days,
      :max_renewals,
      :max_reserves,
      :max_concurrent_loans,
      :fine_per_day,
      :max_fine,
      :membership_fee,
      :currency,
      :can_reserve,
      :can_renew,
      :digital_access,
      :exhibition_preview_access,
      :ticket_discount_percent,
      :shop_discount_percent,
      :max_event_bookings_per_year,
      :membership_period_days,
      :auto_renew,
      :recurrence_unit,
      :recurrence_interval,
      :priority_level,
      :is_active,
      :publicly_listed,
      :institutional,
      :allowed_collections,
      :metadata
    ])
    |> validate_required([:name, :slug])
    |> validate_number(:max_items, greater_than_or_equal_to: 0)
    |> validate_number(:max_days, greater_than_or_equal_to: 0)
    |> validate_number(:max_renewals, greater_than_or_equal_to: 0)
    |> validate_number(:max_reserves, greater_than_or_equal_to: 0)
    |> validate_number(:max_concurrent_loans, greater_than_or_equal_to: 0)
    |> validate_number(:max_event_bookings_per_year, greater_than_or_equal_to: 0)
    |> validate_number(:ticket_discount_percent,
      greater_than_or_equal_to: 0,
      less_than_or_equal_to: 100
    )
    |> validate_number(:shop_discount_percent,
      greater_than_or_equal_to: 0,
      less_than_or_equal_to: 100
    )
    |> validate_decimal_non_negative(:fine_per_day)
    |> validate_decimal_non_negative(:membership_fee)
    |> unique_constraint(:slug)
  end

  @doc "Use for patch-style updates where not all fields are present"
  def update_changeset(member_type, attrs \\ %{}) do
    member_type
    |> changeset(attrs)
  end

  defp validate_decimal_non_negative(changeset, field) do
    case get_field(changeset, field) do
      %Decimal{} = d ->
        if Decimal.compare(d, Decimal.new("0")) in [:gt, :eq] do
          changeset
        else
          add_error(changeset, field, "must be greater than or equal to 0")
        end

      nil ->
        changeset

      other when is_integer(other) or is_float(other) ->
        # cast might leave it as number; normalize to Decimal
        dec = Decimal.new(other)

        if Decimal.compare(dec, Decimal.new("0")) in [:gt, :eq] do
          changeset
        else
          add_error(changeset, field, "must be greater than or equal to 0")
        end

      _ ->
        add_error(changeset, field, "invalid value")
    end
  end

  # -------------------------
  # Entitlement helpers
  # -------------------------

  @doc "Return true if this member type can make reservations"
  @spec can_reserve?(t :: %__MODULE__{}) :: boolean
  def can_reserve?(%__MODULE__{can_reserve: v}), do: !!v

  @doc "Return true if this member type can renew loans"
  def can_renew?(%__MODULE__{can_renew: v}), do: !!v

  @doc "Max number of items this member type can borrow"
  def max_items(%__MODULE__{max_items: max}), do: max || 0

  @doc "Return the allowed collections map (jsonb) for policy checks"
  def allowed_collections(%__MODULE__{allowed_collections: m}), do: m || %{}

  @doc "Return true if member type is institutional"
  def institutional?(%__MODULE__{institutional: v}), do: !!v

  # -------------------------
  # Date / Subscription helpers
  # -------------------------
  @doc """
  Compute ends_at given a start_date (NaiveDateTime or DateTime) and the member type's
  `membership_period_days`. Returns `{:ok, NaiveDateTime}` or `:no_period`.

  Example:
    MemberType.compute_ends_at(member_type, ~N[2025-01-01 00:00:00])
  """
  def compute_ends_at(%__MODULE__{membership_period_days: nil}, _start), do: :no_period

  def compute_ends_at(%__MODULE__{membership_period_days: days}, %NaiveDateTime{} = start)
      when is_integer(days) and days > 0 do
    ends_at = NaiveDateTime.add(start, days * 24 * 60 * 60, :second)
    {:ok, ends_at}
  end

  def compute_ends_at(%__MODULE__{membership_period_days: days}, %DateTime{} = start)
      when is_integer(days) and days > 0 do
    start_naive = DateTime.to_naive(start)
    ends_at = NaiveDateTime.add(start_naive, days * 24 * 60 * 60, :second)
    {:ok, ends_at}
  end

  @doc """
  Compute next renewal datetime using `recurrence_unit` and `recurrence_interval`.
  - Supports `recurrence_unit: "days"` out of the box.
  - For `"months"` or `"years"` we recommend using Timex or Calendar operations
    in your application code because months/years are variable-length.
  Returns `{:ok, NaiveDateTime}` | `:not_applicable` | `{:error, reason}`.
  """
  def compute_next_renewal(%__MODULE__{auto_renew: false}, _from), do: :not_applicable

  def compute_next_renewal(
        %__MODULE__{recurrence_unit: "days", recurrence_interval: n},
        %NaiveDateTime{} = from
      )
      when is_integer(n) and n > 0 do
    {:ok, NaiveDateTime.add(from, n * 24 * 60 * 60, :second)}
  end

  def compute_next_renewal(
        %__MODULE__{recurrence_unit: "days", recurrence_interval: n},
        %DateTime{} = from
      )
      when is_integer(n) and n > 0 do
    from_naive = DateTime.to_naive(from)
    {:ok, NaiveDateTime.add(from_naive, n * 24 * 60 * 60, :second)}
  end

  def compute_next_renewal(%__MODULE__{recurrence_unit: unit} = _mt, _from)
      when unit in ["months", "years"] do
    {:error, :use_timex_for_months_or_years}
  end

  def compute_next_renewal(_, _), do: {:error, :invalid_recurrence}

  # -------------------------
  # Convenience: entitlement summary map
  # -------------------------
  @doc "Return a map summarizing entitlements / quotas for UI or checks"
  def entitlement_summary(%__MODULE__{} = mt) do
    %{
      can_reserve: can_reserve?(mt),
      can_renew: can_renew?(mt),
      digital_access: mt.digital_access,
      max_items: max_items(mt),
      max_days: mt.max_days || 0,
      max_renewals: mt.max_renewals || 0,
      ticket_discount_percent: mt.ticket_discount_percent || 0,
      shop_discount_percent: mt.shop_discount_percent || 0,
      max_event_bookings_per_year: mt.max_event_bookings_per_year || 0,
      institution: institutional?(mt)
    }
  end
end
