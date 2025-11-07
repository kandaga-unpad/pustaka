# Fine Calculation - Holiday Skip Feature

## Overview

The fine calculation system now supports two modes:

1. **Business Days Mode** (default): Excludes holidays and weekends from fine calculations
2. **All Days Mode**: Counts ALL calendar days including holidays and weekends

This allows libraries to choose their fine policy based on their rules.

## How It Works

### Transaction Schema Functions

Three functions are available in `Voile.Schema.Library.Transaction`:

```elixir
# 1. Business days only (excludes holidays/weekends) - DEFAULT
Transaction.days_overdue(transaction)
# Returns: 7 (if 7 business days late)

# 2. All calendar days (includes everything)
Transaction.calendar_days_overdue(transaction)
# Returns: 10 (if 10 total days late, including 3 weekend/holiday days)

# 3. Flexible calculation with flag
Transaction.calculate_days_overdue(transaction, skip_holidays)
# When skip_holidays = false: returns business days (7)
# When skip_holidays = true: returns all days (10)
```

### Circulation Context Functions

Helper functions in `Voile.Schema.Library.Circulation`:

```elixir
alias Voile.Schema.Library.Circulation

# Calculate days for fine with option
days = Circulation.calculate_days_for_fine(transaction, skip_holidays: true)
# Returns total days when skip_holidays: true
# Returns business days when skip_holidays: false (default)

# Calculate fine amount with option
amount = Circulation.calculate_fine_amount(transaction, member_type, skip_holidays: true)
# Calculates fine using all calendar days
```

## Usage Examples

### Example 1: Return Item with Holiday-Aware Fines (DEFAULT)

```elixir
# This will count only business days (excludes weekends/holidays)
{:ok, transaction} = Circulation.return_item(transaction_id, librarian_id, %{})
```

### Example 2: Return Item Counting ALL Days

```elixir
# This will count ALL calendar days including holidays and weekends
{:ok, transaction} = Circulation.return_item(
  transaction_id,
  librarian_id,
  %{},
  skip_holidays: true
)
```

### Example 3: Calculate Fine Preview

```elixir
# Preview fine with business days (default)
business_days = Circulation.calculate_days_for_fine(transaction)
business_fine = Circulation.calculate_fine_amount(transaction, member_type)
# business_days = 7, business_fine = Rp 35,000 (7 × 5,000)

# Preview fine with all calendar days
all_days = Circulation.calculate_days_for_fine(transaction, skip_holidays: true)
all_fine = Circulation.calculate_fine_amount(transaction, member_type, skip_holidays: true)
# all_days = 10, all_fine = Rp 50,000 (10 × 5,000)
```

## Integration with System Configuration

You can create a system configuration setting (e.g., in a settings table):

```elixir
defmodule Voile.Schema.System.LibrarySettings do
  schema "library_settings" do
    field :skip_holidays_in_fines, :boolean, default: false
    # ... other settings
  end
end
```

Then use it when processing returns:

```elixir
# In your LiveView or controller
def handle_event("return_item", %{"transaction_id" => id}, socket) do
  settings = LibrarySettings.get_settings()

  case Circulation.return_item(
    id,
    socket.assigns.current_user.id,
    %{},
    skip_holidays: settings.skip_holidays_in_fines
  ) do
    {:ok, transaction} ->
      # Success
    {:error, reason} ->
      # Error
  end
end
```

## Fine Description

The system automatically includes information about the calculation method in the fine description:

- **Business Days Mode**: "Late return fine - 7 business days overdue at Rp 5,000/day (holidays excluded)"
- **All Days Mode**: "Late return fine - 10 calendar days overdue at Rp 5,000/day (all days counted)"

## Scenario Example

**Scenario**: A book was due on Monday, October 1, 2025. It's returned on Monday, October 15, 2025.

**Calendar Days**: 14 days
**Business Days** (assuming weekends + 2 holidays): 10 days

**Fine Calculation**:

- With `skip_holidays: false` → 10 business days × Rp 5,000 = **Rp 50,000**
- With `skip_holidays: true` → 14 calendar days × Rp 5,000 = **Rp 70,000**

## Configuration UI Example

In your settings page (`/manage/settings/circulation`), you could add:

```heex
<.input
  field={@form[:skip_holidays_in_fines]}
  type="checkbox"
  label="Count ALL days for fines (including holidays and weekends)"
  help="When enabled, fines will be calculated for every single day, regardless of library holidays or weekends. When disabled, only business days are counted."
/>
```

## Testing

You can test both modes:

```elixir
# In IEx or tests
alias Voile.Schema.Library.{Transaction, Circulation}
alias Voile.Schema.Master.MemberType

# Get or create a test transaction that's overdue
transaction = Repo.get(Transaction, transaction_id)
member_type = Repo.get(MemberType, member_type_id)

# Test business days mode
business_days = Transaction.calculate_days_overdue(transaction, false)
business_fine = Circulation.calculate_fine_amount(transaction, member_type, skip_holidays: false)

# Test all days mode
all_days = Transaction.calculate_days_overdue(transaction, true)
all_fine = Circulation.calculate_fine_amount(transaction, member_type, skip_holidays: true)

IO.puts("Business days: #{business_days}, Fine: #{business_fine}")
IO.puts("All days: #{all_days}, Fine: #{all_fine}")
```

## Notes

- The default behavior (`skip_holidays: false`) maintains backward compatibility by using business days
- The holiday calendar is managed through `/manage/settings/holidays`
- Weekly schedules (which days are business days) are also configurable
- The `max_fine` setting in member types is respected in both modes
