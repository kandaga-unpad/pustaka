defmodule Voile.Schema.System.Node do
  use Ecto.Schema
  import Ecto.Changeset

  alias Decimal

  schema "nodes" do
    field :name, :string
    field :image, :string
    field :abbr, :string
    field :description, :string

    # Node-specific loan rules (optional overrides)
    field :override_loan_rules, :boolean, default: false
    field :max_items, :integer
    field :max_days, :integer
    field :max_renewals, :integer
    field :max_reserves, :integer
    field :max_concurrent_loans, :integer

    # Node-specific fine rules
    field :fine_per_day, :decimal
    field :max_fine, :decimal
    field :currency, :string, default: "IDR"

    # Node-specific features
    field :can_reserve, :boolean
    field :can_renew, :boolean
    field :digital_access_enabled, :boolean, default: true

    # Operating hours and availability
    field :operating_hours, :map
    field :holiday_schedule, :map
    field :auto_close_on_holidays, :boolean, default: true

    # Node-specific policies
    field :require_deposit, :boolean, default: false
    field :deposit_amount, :decimal
    field :allow_external_returns, :boolean, default: true
    field :allow_inter_node_loans, :boolean, default: true

    # Metadata for additional custom rules
    field :custom_rules, :map, default: %{}

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(node, attrs) do
    node
    |> cast(attrs, [
      :name,
      :abbr,
      :image,
      :description,
      :override_loan_rules,
      :max_items,
      :max_days,
      :max_renewals,
      :max_reserves,
      :max_concurrent_loans,
      :fine_per_day,
      :max_fine,
      :currency,
      :can_reserve,
      :can_renew,
      :digital_access_enabled,
      :operating_hours,
      :holiday_schedule,
      :auto_close_on_holidays,
      :require_deposit,
      :deposit_amount,
      :allow_external_returns,
      :allow_inter_node_loans,
      :custom_rules
    ])
    |> validate_required([:name, :abbr])
    |> validate_number(:max_items, greater_than_or_equal_to: 0)
    |> validate_number(:max_days, greater_than_or_equal_to: 0)
    |> validate_number(:max_renewals, greater_than_or_equal_to: 0)
    |> validate_number(:max_reserves, greater_than_or_equal_to: 0)
    |> validate_number(:max_concurrent_loans, greater_than_or_equal_to: 0)
    |> validate_decimal_non_negative(:fine_per_day)
    |> validate_decimal_non_negative(:max_fine)
    |> validate_decimal_non_negative(:deposit_amount)
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
        dec = Decimal.new(to_string(other))

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
  # Rule Resolution Helpers
  # -------------------------

  @doc """
  Returns effective loan rules for this node, considering member type.
  If `override_loan_rules` is true, node rules take precedence.
  Otherwise, falls back to member type rules.

  ## Examples

      effective_rules(node, member_type)
      # => %{max_items: 5, max_days: 14, fine_per_day: Decimal.new("5000"), ...}
  """
  def effective_rules(%__MODULE__{override_loan_rules: true} = node, _member_type) do
    %{
      max_items: node.max_items,
      max_days: node.max_days,
      max_renewals: node.max_renewals,
      max_reserves: node.max_reserves,
      max_concurrent_loans: node.max_concurrent_loans,
      fine_per_day: node.fine_per_day,
      max_fine: node.max_fine,
      can_reserve: node.can_reserve,
      can_renew: node.can_renew,
      currency: node.currency || "IDR",
      source: :node
    }
  end

  def effective_rules(%__MODULE__{} = _node, member_type) do
    %{
      max_items: member_type.max_items,
      max_days: member_type.max_days,
      max_renewals: member_type.max_renewals,
      max_reserves: member_type.max_reserves,
      max_concurrent_loans: member_type.max_concurrent_loans,
      fine_per_day: member_type.fine_per_day,
      max_fine: member_type.max_fine,
      can_reserve: member_type.can_reserve,
      can_renew: member_type.can_renew,
      currency: member_type.currency || "IDR",
      source: :member_type
    }
  end

  @doc """
  Checks if the node allows a specific operation.
  Useful for checking node-level restrictions.
  """
  def allows_operation?(%__MODULE__{} = node, :reserve) do
    if node.override_loan_rules do
      node.can_reserve
    else
      # Defer to member type
      true
    end
  end

  def allows_operation?(%__MODULE__{} = node, :renew) do
    if node.override_loan_rules do
      node.can_renew
    else
      # Defer to member type
      true
    end
  end

  def allows_operation?(%__MODULE__{} = node, :external_return) do
    node.allow_external_returns != false
  end

  def allows_operation?(%__MODULE__{} = node, :inter_node_loan) do
    node.allow_inter_node_loans != false
  end

  @doc """
  Returns a summary of node-specific policies for UI display.
  """
  def policy_summary(%__MODULE__{} = node) do
    %{
      override_rules: node.override_loan_rules || false,
      require_deposit: node.require_deposit || false,
      deposit_amount: node.deposit_amount,
      allow_external_returns: node.allow_external_returns != false,
      allow_inter_node_loans: node.allow_inter_node_loans != false,
      digital_access: node.digital_access_enabled != false,
      has_operating_hours: not is_nil(node.operating_hours),
      has_holiday_schedule: not is_nil(node.holiday_schedule)
    }
  end
end
