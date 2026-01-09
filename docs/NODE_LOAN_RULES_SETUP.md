# Node-Based Loan Rules Setup Guide

## Overview

The node-based loan rules system allows each branch/node to either:

1. Follow standard member type rules (default)
2. Override with branch-specific lending policies

## Quick Setup

### Step 1: Run Migration

```bash
cd f:\dev\voile
mix ecto.migrate
```

### Step 2: Add Route to Router

Add this route to your router file (`lib/voile_web/router.ex`):

```elixir
scope "/admin", VoileWeb.Dashboard.Admin do
  pipe_through [:browser, :require_authenticated_user]

  live "/node-rules", NodeRulesLive, :index
end
```

### Step 3: Access Admin Interface

Navigate to: `http://localhost:4000/admin/node-rules`

## Configuration Options

### Basic Setup

1. **Select Branch** - Choose which branch/node to configure
2. **Enable Override** - Toggle "Enable Branch-Specific Rules"
   - When **ON**: Branch rules override member type rules
   - When **OFF**: Standard member type rules apply

### Loan Limits

Configure borrowing restrictions:

- **Max Items per Loan** - Number of items per transaction
- **Max Loan Days** - Duration of loan period
- **Max Renewals** - How many times items can be renewed
- **Max Reserves** - Number of simultaneous reservations allowed
- **Max Concurrent Loans** - Total active loans per patron

### Fine Configuration

Set penalty amounts for overdue items:

- **Fine per Day** - Daily charge for late returns
- **Max Fine** - Maximum penalty cap (optional)
- **Currency** - IDR, USD, EUR, SGD, or MYR

### Features & Permissions

Control what patrons can do:

- ✅ **Allow Reservations** - Enable/disable item holds
- ✅ **Allow Renewals** - Enable/disable loan extensions
- ✅ **Enable Digital Access** - Grant online resource access

### Operational Policies

Branch-level operational rules:

- **Allow Returns from Other Branches** - Accept external returns
- **Allow Inter-Branch Loans** - Permit borrowing from other locations
- **Require Security Deposit** - Mandate refundable deposit
  - Set deposit amount when enabled

## Usage Examples

### Example 1: Rural Branch with Relaxed Rules

```elixir
# For a rural branch with limited staff, extend loan periods
node_attrs = %{
  "override_loan_rules" => true,
  "max_items" => 5,
  "max_days" => 30,        # Longer than standard
  "max_renewals" => 3,
  "fine_per_day" => Decimal.new("2000"),  # Lower fines
  "allow_external_returns" => true
}

System.update_node_rules(rural_branch, node_attrs)
```

### Example 2: University Library with Strict Rules

```elixir
# Academic branch with research needs
node_attrs = %{
  "override_loan_rules" => true,
  "max_items" => 10,       # More items for research
  "max_days" => 14,
  "max_renewals" => 2,
  "fine_per_day" => Decimal.new("10000"),  # Stricter penalties
  "require_deposit" => true,
  "deposit_amount" => Decimal.new("100000"),
  "allow_inter_node_loans" => false  # Keep resources local
}

System.update_node_rules(university_branch, node_attrs)
```

### Example 3: Public Library (Standard Rules)

```elixir
# Use member type rules - no override needed
node_attrs = %{
  "override_loan_rules" => false,  # Follows member type rules
  "allow_external_returns" => true,
  "allow_inter_node_loans" => true
}

System.update_node_rules(public_branch, node_attrs)
```

## Programmatic Usage

### Check Effective Rules

```elixir
# Get the rules that will apply for a loan
alias Voile.Schema.Library.LoanRuleResolver

node = System.get_node!(1)
member_type = MemberType |> Repo.get!(member.member_type_id)

rules = LoanRuleResolver.resolve_rules(node, member_type)
# => %{
#   max_items: 10,
#   max_days: 14,
#   fine_per_day: Decimal.new("5000"),
#   source: :node  # or :member_type or :system_default
# }
```

### Check Permissions

```elixir
# Can this patron reserve at this branch?
can_reserve? = LoanRuleResolver.can_perform?(node, member_type, :reserve)

# Check branch operational policies
allows_external? = LoanRuleResolver.allows_node_operation?(node, :external_return)
allows_inter_branch? = LoanRuleResolver.allows_node_operation?(node, :inter_node_loan)
```

### Calculate Fines

```elixir
# Calculate fine based on node/member type rules
days_overdue = 5
fine = LoanRuleResolver.calculate_fine(node, member_type, days_overdue)
# => Decimal.new("25000") if fine_per_day is 5000
```

### Explain Rules

```elixir
# Get human-readable explanation
explanation = LoanRuleResolver.explain_rules(node, member_type)
# => "Using Downtown Branch branch-specific rules"
# or "Using Premium Member membership rules"
# or "Using system default rules"
```

## Integration with Circulation System

### In Your Loan Creation Logic

```elixir
# Node rules are already integrated into Voile.Schema.Library.Circulation!
alias Voile.Schema.Library.{Circulation, LoanRuleResolver}

def create_loan(patron, item, node) do
  member_type = get_member_type(patron)
  rules = LoanRuleResolver.resolve_rules(node, member_type)

    # Check if allowed
    unless LoanRuleResolver.can_perform?(node, member_type, :borrow) do
      {:error, "Borrowing not allowed at this branch"}
    end

    # Check limits
    active_loans = count_active_loans(patron)
    if active_loans >= rules.max_concurrent_loans do
      {:error, "Maximum concurrent loans reached"}
    end

    # Create loan with correct due date
    due_date = DateTime.add(DateTime.utc_now(), rules.max_days * 24 * 60 * 60, :second)

    %Loan{}
    |> Loan.changeset(%{
      patron_id: patron.id,
      item_id: item.id,
      node_id: node.id,
      due_date: due_date,
      max_renewals: rules.max_renewals
    })
    |> Repo.insert()
  end
end
```

### In Your Fine Calculation

The circulation context is already integrated! Fine calculation automatically uses node-based rules:

```elixir
# Node rules are automatically resolved with precedence
alias Voile.Schema.Library.Circulation

node = Repo.get(Node, loan.node_id)
member_type = get_member_type_for_loan(loan)

# Pass node to fine calculation for rule resolution
Circulation.calculate_fine_amount(transaction, member_type, node: node, skip_holidays: false)

# Or use the resolver directly
alias Voile.Schema.Library.LoanRuleResolver

days_overdue = Date.diff(Date.utc_today(), loan.due_date)
LoanRuleResolver.calculate_fine(node, member_type, days_overdue)
```

## Best Practices

1. **Start with Member Types** - Set up member type rules first as your foundation
2. **Override Sparingly** - Only enable node overrides when truly needed
3. **Document Changes** - Keep notes on why specific rules were set
4. **Review Regularly** - Audit node rules quarterly
5. **Test Before Deploy** - Test rule changes with test accounts first
6. **Communicate Changes** - Inform staff when branch rules change
7. **Monitor Impact** - Track circulation metrics after rule changes

## Troubleshooting

### Rules Not Applying

**Problem**: Changes don't seem to take effect

**Solution**:

- Check `override_loan_rules` is set to `true`
- Verify fields have non-null values
- Clear any cached member type data
- Check logs for rule resolution: `LoanRuleResolver.explain_rules(node, member_type)`

### Permission Denied

**Problem**: "Borrowing not allowed" errors

**Solution**:

- Check `can_reserve` and `can_renew` flags
- Verify member type hasn't expired
- Check branch operational policies (`allow_inter_node_loans`)

### Fine Calculation Issues

**Problem**: Fines calculated incorrectly

**Solution**:

- Verify `fine_per_day` is set correctly (use Decimal, not float)
- Check `currency` matches expected currency
- Ensure `max_fine` isn't capping unexpectedly
- Test: `LoanRuleResolver.calculate_fine(node, member_type, 1)`

## Advanced: Custom Rules

Use the `custom_rules` JSONB field for extensions:

```elixir
node_attrs = %{
  "custom_rules" => %{
    "special_collections" => %{
      "rare_books_max_days" => 3,
      "reference_only" => ["collection_id_1", "collection_id_2"]
    },
    "age_restrictions" => %{
      "min_age_adult_content" => 18
    },
    "seasonal_rules" => %{
      "summer_extended_hours" => true
    }
  }
}

System.update_node_rules(node, node_attrs)
```

Access in code:

```elixir
custom = node.custom_rules || %{}
rare_books_days = get_in(custom, ["special_collections", "rare_books_max_days"]) || 7
```

## Support

For questions or issues:

1. Check this guide
2. Review `LoanRuleResolver` module documentation
3. Examine existing node configurations: `System.list_nodes()`
4. Test rule resolution: `LoanRuleResolver.resolve_rules(node, member_type)`
