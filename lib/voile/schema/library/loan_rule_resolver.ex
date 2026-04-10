defmodule Voile.Schema.Library.LoanRuleResolver do
  @moduledoc """
  Resolves loan rules with proper precedence:
  1. Node-level rules (if override_loan_rules is true)
  2. Member type rules
  3. System defaults

  This allows flexible policy management across different branches/nodes
  while maintaining member type-based rules as the foundation.
  """

  alias Voile.Schema.System.Node
  alias Voile.Schema.Master.MemberType
  alias Decimal

  @system_defaults %{
    max_items: 3,
    max_days: 7,
    max_renewals: 1,
    max_reserves: 2,
    max_concurrent_loans: 3,
    fine_per_day: Decimal.new("5000"),
    max_fine: Decimal.new("100000"),
    can_reserve: true,
    can_renew: true,
    currency: "IDR"
  }

  @doc """
  Resolves the effective loan rules for a given node and member type.

  ## Examples

      # Node overrides member type
      resolve_rules(node_with_override, member_type)
      # => %{max_items: 10, source: :node, ...}

      # Member type rules apply
      resolve_rules(node_without_override, member_type)
      # => %{max_items: 5, source: :member_type, ...}

      # Falls back to defaults
      resolve_rules(nil, nil)
      # => %{max_items: 3, source: :system_default, ...}
  """
  def resolve_rules(node \\ nil, member_type \\ nil)

  def resolve_rules(%Node{override_loan_rules: true} = node, _member_type) do
    %{
      max_items: if(is_nil(node.max_items), do: @system_defaults.max_items, else: node.max_items),
      max_days: if(is_nil(node.max_days), do: @system_defaults.max_days, else: node.max_days),
      max_renewals:
        if(is_nil(node.max_renewals), do: @system_defaults.max_renewals, else: node.max_renewals),
      max_reserves:
        if(is_nil(node.max_reserves), do: @system_defaults.max_reserves, else: node.max_reserves),
      max_concurrent_loans:
        if(is_nil(node.max_concurrent_loans),
          do: @system_defaults.max_concurrent_loans,
          else: node.max_concurrent_loans
        ),
      fine_per_day:
        if(is_nil(node.fine_per_day), do: @system_defaults.fine_per_day, else: node.fine_per_day),
      max_fine: if(is_nil(node.max_fine), do: @system_defaults.max_fine, else: node.max_fine),
      can_reserve:
        if(is_nil(node.can_reserve), do: @system_defaults.can_reserve, else: node.can_reserve),
      can_renew: if(is_nil(node.can_renew), do: @system_defaults.can_renew, else: node.can_renew),
      currency: node.currency || @system_defaults.currency,
      source: :node,
      node_id: node.id,
      node_name: node.name
    }
  end

  def resolve_rules(_node, %MemberType{} = member_type) do
    %{
      max_items:
        if(is_nil(member_type.max_items),
          do: @system_defaults.max_items,
          else: member_type.max_items
        ),
      max_days:
        if(is_nil(member_type.max_days),
          do: @system_defaults.max_days,
          else: member_type.max_days
        ),
      max_renewals:
        if(is_nil(member_type.max_renewals),
          do: @system_defaults.max_renewals,
          else: member_type.max_renewals
        ),
      max_reserves:
        if(is_nil(member_type.max_reserves),
          do: @system_defaults.max_reserves,
          else: member_type.max_reserves
        ),
      max_concurrent_loans:
        if(is_nil(member_type.max_concurrent_loans),
          do: @system_defaults.max_concurrent_loans,
          else: member_type.max_concurrent_loans
        ),
      fine_per_day:
        if(is_nil(member_type.fine_per_day),
          do: @system_defaults.fine_per_day,
          else: member_type.fine_per_day
        ),
      max_fine:
        if(is_nil(member_type.max_fine),
          do: @system_defaults.max_fine,
          else: member_type.max_fine
        ),
      can_reserve: member_type.can_reserve,
      can_renew: member_type.can_renew,
      currency: member_type.currency || @system_defaults.currency,
      source: :member_type,
      member_type_id: member_type.id,
      member_type_name: member_type.name
    }
  end

  def resolve_rules(_node, nil) do
    Map.put(@system_defaults, :source, :system_default)
  end

  @doc """
  Checks if a specific operation is allowed based on node and member type rules.

  ## Examples

      can_perform?(node, member_type, :reserve)
      # => true | false

      can_perform?(node, member_type, :renew)
      # => true | false
  """
  def can_perform?(node, member_type, operation)

  def can_perform?(%Node{override_loan_rules: true} = node, _member_type, :reserve) do
    if is_nil(node.can_reserve), do: true, else: node.can_reserve
  end

  def can_perform?(%Node{override_loan_rules: true} = node, _member_type, :renew) do
    if is_nil(node.can_renew), do: true, else: node.can_renew
  end

  def can_perform?(_node, %MemberType{} = member_type, :reserve) do
    member_type.can_reserve
  end

  def can_perform?(_node, %MemberType{} = member_type, :renew) do
    member_type.can_renew
  end

  def can_perform?(_node, _member_type, :reserve), do: @system_defaults.can_reserve
  def can_perform?(_node, _member_type, :renew), do: @system_defaults.can_renew

  @doc """
  Checks node-specific operational policies.
  """
  def allows_node_operation?(%Node{} = node, :external_return) do
    node.allow_external_returns != false
  end

  def allows_node_operation?(%Node{} = node, :inter_node_loan) do
    node.allow_inter_node_loans != false
  end

  def allows_node_operation?(%Node{} = node, :digital_access) do
    node.digital_access_enabled != false
  end

  def allows_node_operation?(nil, _operation), do: true

  @doc """
  Calculates fine amount based on resolved rules.
  """
  def calculate_fine(node, member_type, days_overdue) when days_overdue > 0 do
    rules = resolve_rules(node, member_type)
    fine = Decimal.mult(rules.fine_per_day, Decimal.new(days_overdue))

    # Apply max fine if set
    case rules.max_fine do
      nil -> fine
      max_fine -> Enum.min_by([fine, max_fine], &Decimal.to_float/1)
    end
  end

  def calculate_fine(_node, _member_type, _days_overdue), do: Decimal.new("0")

  @doc """
  Returns a human-readable explanation of which rules are being applied.
  """
  def explain_rules(node, member_type) do
    rules = resolve_rules(node, member_type)

    case rules.source do
      :node ->
        "Using #{rules.node_name} branch-specific rules"

      :member_type ->
        "Using #{rules.member_type_name} membership rules"

      :system_default ->
        "Using system default rules"
    end
  end

  @doc """
  Returns system defaults for reference.
  """
  def system_defaults, do: @system_defaults
end
