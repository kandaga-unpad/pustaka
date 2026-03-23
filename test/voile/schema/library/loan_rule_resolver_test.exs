defmodule Voile.Schema.Library.LoanRuleResolverTest do
  use ExUnit.Case, async: true

  alias Voile.Schema.Library.LoanRuleResolver
  alias Voile.Schema.System.Node
  alias Voile.Schema.Master.MemberType

  # System defaults for reference in assertions
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

  describe "resolve_rules/2" do
    test "returns system defaults when both node and member_type are nil" do
      rules = LoanRuleResolver.resolve_rules(nil, nil)

      assert rules.source == :system_default
      assert rules.max_items == @system_defaults.max_items
      assert rules.max_days == @system_defaults.max_days
      assert rules.max_renewals == @system_defaults.max_renewals
      assert rules.max_reserves == @system_defaults.max_reserves
      assert rules.max_concurrent_loans == @system_defaults.max_concurrent_loans
      assert rules.fine_per_day == @system_defaults.fine_per_day
      assert rules.max_fine == @system_defaults.max_fine
      assert rules.can_reserve == @system_defaults.can_reserve
      assert rules.can_renew == @system_defaults.can_renew
      assert rules.currency == @system_defaults.currency
    end

    test "returns system defaults when called with no arguments" do
      rules = LoanRuleResolver.resolve_rules()
      assert rules.source == :system_default
    end

    test "uses node rules when node has override_loan_rules: true" do
      node = %Node{
        id: "node-1",
        name: "Main Library",
        override_loan_rules: true,
        max_items: 10,
        max_days: 14,
        max_renewals: 3,
        max_reserves: 5,
        max_concurrent_loans: 10,
        fine_per_day: Decimal.new("1000"),
        max_fine: Decimal.new("50000"),
        can_reserve: true,
        can_renew: true,
        currency: "IDR"
      }

      rules = LoanRuleResolver.resolve_rules(node, nil)

      assert rules.source == :node
      assert rules.node_id == "node-1"
      assert rules.node_name == "Main Library"
      assert rules.max_items == 10
      assert rules.max_days == 14
      assert rules.max_renewals == 3
      assert rules.max_reserves == 5
      assert rules.max_concurrent_loans == 10
      assert rules.fine_per_day == Decimal.new("1000")
      assert rules.max_fine == Decimal.new("50000")
    end

    test "node rules fall back to system defaults for nil fields" do
      node = %Node{
        id: "node-2",
        name: "Branch Library",
        override_loan_rules: true,
        max_items: nil,
        max_days: 14,
        max_renewals: nil,
        max_reserves: nil,
        max_concurrent_loans: nil,
        fine_per_day: nil,
        max_fine: nil,
        can_reserve: nil,
        can_renew: nil,
        currency: nil
      }

      rules = LoanRuleResolver.resolve_rules(node, nil)

      assert rules.source == :node
      assert rules.max_items == @system_defaults.max_items
      assert rules.max_days == 14
      assert rules.max_renewals == @system_defaults.max_renewals
      assert rules.max_reserves == @system_defaults.max_reserves
      assert rules.max_concurrent_loans == @system_defaults.max_concurrent_loans
      assert rules.fine_per_day == @system_defaults.fine_per_day
      assert rules.max_fine == @system_defaults.max_fine
      assert rules.can_reserve == @system_defaults.can_reserve
      assert rules.can_renew == @system_defaults.can_renew
      assert rules.currency == @system_defaults.currency
    end

    test "uses member type rules when node does not override" do
      node = %Node{
        id: "node-3",
        name: "Branch Library",
        override_loan_rules: false
      }

      member_type = %MemberType{
        id: Ecto.UUID.generate(),
        name: "Student",
        max_items: 5,
        max_days: 14,
        max_renewals: 2,
        max_reserves: 3,
        max_concurrent_loans: 5,
        fine_per_day: Decimal.new("2000"),
        max_fine: Decimal.new("30000"),
        can_reserve: true,
        can_renew: true,
        currency: "IDR"
      }

      rules = LoanRuleResolver.resolve_rules(node, member_type)

      assert rules.source == :member_type
      assert rules.member_type_id == member_type.id
      assert rules.member_type_name == "Student"
      assert rules.max_items == 5
      assert rules.max_days == 14
      assert rules.max_renewals == 2
      assert rules.can_reserve == true
      assert rules.can_renew == true
    end

    test "uses member type rules when node is nil" do
      member_type = %MemberType{
        id: Ecto.UUID.generate(),
        name: "Faculty",
        max_items: 15,
        max_days: 30,
        max_renewals: 5,
        max_reserves: 10,
        max_concurrent_loans: 15,
        fine_per_day: Decimal.new("500"),
        max_fine: Decimal.new("25000"),
        can_reserve: true,
        can_renew: true,
        currency: "IDR"
      }

      rules = LoanRuleResolver.resolve_rules(nil, member_type)

      assert rules.source == :member_type
      assert rules.member_type_name == "Faculty"
      assert rules.max_items == 15
      assert rules.max_days == 30
    end

    test "member type rules fall back to system defaults for nil fields" do
      member_type = %MemberType{
        id: Ecto.UUID.generate(),
        name: "General",
        max_items: nil,
        max_days: nil,
        max_renewals: nil,
        max_reserves: nil,
        max_concurrent_loans: nil,
        fine_per_day: nil,
        max_fine: nil,
        can_reserve: true,
        can_renew: false,
        currency: nil
      }

      rules = LoanRuleResolver.resolve_rules(nil, member_type)

      assert rules.source == :member_type
      assert rules.max_items == @system_defaults.max_items
      assert rules.max_days == @system_defaults.max_days
      # can_reserve and can_renew from member_type, not defaults
      assert rules.can_reserve == true
      assert rules.can_renew == false
      assert rules.currency == @system_defaults.currency
    end

    test "node override takes precedence over member type" do
      node = %Node{
        id: "node-4",
        name: "Special Library",
        override_loan_rules: true,
        max_items: 20,
        max_days: 60
      }

      member_type = %MemberType{
        id: Ecto.UUID.generate(),
        name: "Premium",
        max_items: 8,
        max_days: 21
      }

      rules = LoanRuleResolver.resolve_rules(node, member_type)

      assert rules.source == :node
      assert rules.max_items == 20
      assert rules.max_days == 60
    end
  end

  describe "can_perform?/3" do
    test "allows reserve when node overrides and can_reserve is nil (defaults to true)" do
      node = %Node{override_loan_rules: true, can_reserve: nil}
      assert LoanRuleResolver.can_perform?(node, nil, :reserve) == true
    end

    test "uses node can_reserve when node overrides and value is set" do
      node_allows = %Node{override_loan_rules: true, can_reserve: true}
      node_denies = %Node{override_loan_rules: true, can_reserve: false}

      assert LoanRuleResolver.can_perform?(node_allows, nil, :reserve) == true
      assert LoanRuleResolver.can_perform?(node_denies, nil, :reserve) == false
    end

    test "allows renew when node overrides and can_renew is nil (defaults to true)" do
      node = %Node{override_loan_rules: true, can_renew: nil}
      assert LoanRuleResolver.can_perform?(node, nil, :renew) == true
    end

    test "uses node can_renew when node overrides and value is set" do
      node_allows = %Node{override_loan_rules: true, can_renew: true}
      node_denies = %Node{override_loan_rules: true, can_renew: false}

      assert LoanRuleResolver.can_perform?(node_allows, nil, :renew) == true
      assert LoanRuleResolver.can_perform?(node_denies, nil, :renew) == false
    end

    test "uses member type can_reserve when node doesn't override" do
      node = %Node{override_loan_rules: false}
      member_type_allows = %MemberType{can_reserve: true}
      member_type_denies = %MemberType{can_reserve: false}

      assert LoanRuleResolver.can_perform?(node, member_type_allows, :reserve) == true
      assert LoanRuleResolver.can_perform?(node, member_type_denies, :reserve) == false
    end

    test "uses member type can_renew when node doesn't override" do
      node = %Node{override_loan_rules: false}
      member_type_allows = %MemberType{can_renew: true}
      member_type_denies = %MemberType{can_renew: false}

      assert LoanRuleResolver.can_perform?(node, member_type_allows, :renew) == true
      assert LoanRuleResolver.can_perform?(node, member_type_denies, :renew) == false
    end

    test "falls back to system defaults when node and member_type are both nil" do
      # System defaults: can_reserve: true, can_renew: true
      assert LoanRuleResolver.can_perform?(nil, nil, :reserve) == true
      assert LoanRuleResolver.can_perform?(nil, nil, :renew) == true
    end
  end

  describe "allows_node_operation?/2" do
    test "allows external_return when allow_external_returns is not false" do
      node_allows = %Node{allow_external_returns: true}
      node_nil = %Node{allow_external_returns: nil}

      assert LoanRuleResolver.allows_node_operation?(node_allows, :external_return) == true
      assert LoanRuleResolver.allows_node_operation?(node_nil, :external_return) == true
    end

    test "denies external_return when allow_external_returns is false" do
      node = %Node{allow_external_returns: false}
      assert LoanRuleResolver.allows_node_operation?(node, :external_return) == false
    end

    test "allows inter_node_loan when allow_inter_node_loans is not false" do
      node_allows = %Node{allow_inter_node_loans: true}
      node_nil = %Node{allow_inter_node_loans: nil}

      assert LoanRuleResolver.allows_node_operation?(node_allows, :inter_node_loan) == true
      assert LoanRuleResolver.allows_node_operation?(node_nil, :inter_node_loan) == true
    end

    test "denies inter_node_loan when allow_inter_node_loans is false" do
      node = %Node{allow_inter_node_loans: false}
      assert LoanRuleResolver.allows_node_operation?(node, :inter_node_loan) == false
    end

    test "allows digital_access when digital_access_enabled is not false" do
      node_allows = %Node{digital_access_enabled: true}
      node_nil = %Node{digital_access_enabled: nil}

      assert LoanRuleResolver.allows_node_operation?(node_allows, :digital_access) == true
      assert LoanRuleResolver.allows_node_operation?(node_nil, :digital_access) == true
    end

    test "denies digital_access when digital_access_enabled is false" do
      node = %Node{digital_access_enabled: false}
      assert LoanRuleResolver.allows_node_operation?(node, :digital_access) == false
    end

    test "returns true for nil node regardless of operation" do
      assert LoanRuleResolver.allows_node_operation?(nil, :external_return) == true
      assert LoanRuleResolver.allows_node_operation?(nil, :inter_node_loan) == true
      assert LoanRuleResolver.allows_node_operation?(nil, :digital_access) == true
    end
  end

  describe "calculate_fine/3" do
    test "returns zero for zero or negative days overdue" do
      assert LoanRuleResolver.calculate_fine(nil, nil, 0) == Decimal.new("0")
      assert LoanRuleResolver.calculate_fine(nil, nil, -5) == Decimal.new("0")
    end

    test "calculates fine using system defaults" do
      # System fine_per_day is 5000 IDR
      fine = LoanRuleResolver.calculate_fine(nil, nil, 3)
      assert fine == Decimal.new("15000")
    end

    test "caps fine at max_fine when exceeded" do
      # System max_fine is 100000. With 5000/day, it would take 21 days to reach max
      fine = LoanRuleResolver.calculate_fine(nil, nil, 30)
      # 30 * 5000 = 150000, but max is 100000
      assert Decimal.compare(fine, Decimal.new("100000")) == :eq
    end

    test "does not cap fine when below max_fine" do
      fine = LoanRuleResolver.calculate_fine(nil, nil, 5)
      # 5 * 5000 = 25000, which is below max_fine of 100000
      assert fine == Decimal.new("25000")
    end

    test "uses node fine_per_day when node overrides" do
      node = %Node{
        override_loan_rules: true,
        fine_per_day: Decimal.new("1000"),
        max_fine: Decimal.new("50000")
      }

      fine = LoanRuleResolver.calculate_fine(node, nil, 3)
      assert fine == Decimal.new("3000")
    end

    test "uses member type fine_per_day" do
      member_type = %MemberType{
        fine_per_day: Decimal.new("2000"),
        max_fine: Decimal.new("20000")
      }

      fine = LoanRuleResolver.calculate_fine(nil, member_type, 5)
      # 5 * 2000 = 10000, below max_fine
      assert fine == Decimal.new("10000")
    end

    test "caps member type fine at max_fine" do
      member_type = %MemberType{
        fine_per_day: Decimal.new("2000"),
        max_fine: Decimal.new("8000")
      }

      fine = LoanRuleResolver.calculate_fine(nil, member_type, 5)
      # 5 * 2000 = 10000, exceeds max_fine of 8000
      assert fine == Decimal.new("8000")
    end
  end

  describe "explain_rules/2" do
    test "returns node-specific message when node overrides" do
      node = %Node{
        id: "n1",
        name: "Central Library",
        override_loan_rules: true
      }

      explanation = LoanRuleResolver.explain_rules(node, nil)
      assert explanation =~ "Central Library"
      assert explanation =~ "branch-specific rules"
    end

    test "returns member type message when member type applies" do
      member_type = %MemberType{
        id: 1,
        name: "Student",
        max_days: 14
      }

      explanation = LoanRuleResolver.explain_rules(nil, member_type)
      assert explanation =~ "Student"
      assert explanation =~ "membership rules"
    end

    test "returns system default message when no rules specified" do
      explanation = LoanRuleResolver.explain_rules(nil, nil)
      assert explanation =~ "system default rules"
    end
  end

  describe "system_defaults/0" do
    test "returns a map with all expected keys" do
      defaults = LoanRuleResolver.system_defaults()

      assert Map.has_key?(defaults, :max_items)
      assert Map.has_key?(defaults, :max_days)
      assert Map.has_key?(defaults, :max_renewals)
      assert Map.has_key?(defaults, :max_reserves)
      assert Map.has_key?(defaults, :max_concurrent_loans)
      assert Map.has_key?(defaults, :fine_per_day)
      assert Map.has_key?(defaults, :max_fine)
      assert Map.has_key?(defaults, :can_reserve)
      assert Map.has_key?(defaults, :can_renew)
      assert Map.has_key?(defaults, :currency)
    end

    test "returns sensible default values" do
      defaults = LoanRuleResolver.system_defaults()

      assert is_integer(defaults.max_items)
      assert defaults.max_items > 0
      assert is_integer(defaults.max_days)
      assert defaults.max_days > 0
      assert is_boolean(defaults.can_reserve)
      assert is_boolean(defaults.can_renew)
      assert is_binary(defaults.currency)
    end
  end
end
