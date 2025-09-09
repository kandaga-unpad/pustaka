# Library Holiday System

This document explains the holiday system implementation for the Voile library circulation system.

## Overview

The holiday system ensures fair fine calculations by excluding weekends and holidays from overdue day counts. Only business days are counted when calculating late return fines.

## Features

### 🗓️ **Holiday Types**
- **Public Holidays**: National and local government holidays
- **Library Holidays**: Library-specific closure days (inventory, maintenance)
- **Custom Holidays**: Institution-specific holidays
- **Weekends**: Automatically handled (Saturday & Sunday)

### 🧮 **Business Day Calculation**
- Excludes weekends (Saturday/Sunday) from fine calculations
- Excludes active holidays from fine calculations
- Only counts actual business days when library is open
- Supports date ranges and multi-day calculations

### 🎯 **Admin Management**
- Web interface at `/manage/settings/holidays`
- Add, edit, delete holidays
- Enable/disable holidays temporarily
- Import common Indonesian holidays
- Holiday statistics and reporting

## Database Schema

### LibHoliday Table
```sql
CREATE TABLE lib_holidays (
  id UUID PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  holiday_date DATE NOT NULL,
  holiday_type VARCHAR(50) NOT NULL,  -- 'public', 'library', 'custom'
  is_recurring BOOLEAN DEFAULT false,
  description TEXT,
  is_active BOOLEAN DEFAULT true,
  inserted_at TIMESTAMP,
  updated_at TIMESTAMP,
  
  CONSTRAINT unique_holiday_date_type UNIQUE (holiday_date, holiday_type)
);
```

## Code Structure

### Core Modules

1. **`LibHoliday`** (`/lib/voile/schema/system/lib_holiday.ex`)
   - Ecto schema for holidays
   - Core business day calculation functions
   - Holiday checking logic

2. **`LibHolidays`** (`/lib/voile/schema/system/lib_holidays.ex`)
   - Context module for holiday management
   - CRUD operations
   - Holiday import functions

3. **`HolidayLive`** (`/lib/voile_web/live/dashboard/settings/holiday_live.ex`)
   - Admin interface for managing holidays
   - Holiday statistics dashboard
   - Import/export functionality

### Integration Points

4. **`Transaction`** (`/lib/voile/schema/library/transaction.ex`)
   - Updated `days_overdue/1` function
   - Uses business day calculation instead of calendar days

## Fine Calculation Flow

### Before Holiday System:
```elixir
# Old calculation - counts all days including weekends/holidays
days_overdue = DateTime.diff(DateTime.utc_now(), due_date, :day)
fine_amount = days_overdue * daily_fine
```

### After Holiday System:
```elixir
# New calculation - only counts business days
days_overdue = LibHoliday.business_days_between(due_date, DateTime.utc_now())
fine_amount = days_overdue * daily_fine
```

### Example:
- **Book due**: Friday, Dec 22, 2023
- **Returned**: Tuesday, Jan 2, 2024
- **Calendar days**: 11 days
- **Business days**: 5 days (excluding weekends + holidays)
- **Fine**: Only charged for 5 business days

## Setup Instructions

### 1. Run Migration
```bash
mix ecto.migrate
```

### 2. Seed Initial Holidays
```bash
# Seed holidays for current year
mix voile.seed_holidays

# Seed for specific year
mix voile.seed_holidays --year 2025

# Seed only Indonesian holidays
mix voile.seed_holidays --year 2025 --type indonesian
```

### 3. Access Admin Interface
Navigate to: `/manage/settings/holidays`

## Usage Examples

### Admin Tasks

#### Add Holiday via Web Interface:
1. Go to `/manage/settings/holidays`
2. Click "Add Holiday"
3. Fill in holiday details
4. Save

#### Import Indonesian Holidays:
1. Click "Import Common Holidays"
2. Select year
3. Click "Import Indonesian Public Holidays"

#### Bulk Import via Command:
```bash
mix voile.seed_holidays --year 2025
```

### Programmatic Usage

#### Check if Date is Holiday:
```elixir
LibHoliday.is_holiday?(~D[2023-12-25])  # true (Christmas)
LibHoliday.is_weekend?(~D[2023-12-24])  # true (Sunday)
```

#### Calculate Business Days:
```elixir
# Between two dates
start_date = ~D[2023-12-20]
end_date = ~D[2023-12-27]
business_days = LibHoliday.business_days_between(start_date, end_date)
```

#### Add Business Days:
```elixir
# Add 7 business days to a date (skipping weekends/holidays)
due_date = LibHolidays.add_business_days(~D[2023-12-20], 7)
```

## Configuration

### Weekend Configuration
Currently hardcoded as Saturday (6) and Sunday (7). Can be modified in:
```elixir
# In LibHoliday.is_weekend?/1
day_of_week == 6 or day_of_week == 7  # Saturday = 6, Sunday = 7
```

### Holiday Import
Common holidays can be added to:
- `LibHolidays.import_indonesian_holidays/1` - Public holidays
- `LibHolidays.import_library_holidays/1` - Library-specific holidays

## Testing

### Test Fine Calculations
```bash
# In IEx console
iex> alias Voile.Schema.Library.Transaction
iex> alias Voile.Schema.System.LibHoliday

# Create a test transaction (past due)
iex> transaction = %Transaction{
  due_date: ~U[2023-12-20 10:00:00Z],
  return_date: nil
}

# Check overdue days
iex> Transaction.days_overdue(transaction)
# Returns business days only
```

### Test Holiday Functions
```bash
iex> LibHoliday.is_holiday?(~D[2023-12-25])  # Christmas
iex> LibHoliday.is_weekend?(~D[2023-12-24])  # Sunday
iex> LibHoliday.business_days_between(~D[2023-12-20], ~D[2023-12-27])
```

## Management Commands

### Available Mix Tasks

```bash
# Seed holidays
mix voile.seed_holidays                    # All holidays, current year
mix voile.seed_holidays --year 2025        # All holidays, specific year
mix voile.seed_holidays --type indonesian  # Only Indonesian holidays

# Database management
mix ecto.migrate                          # Run holiday migration
mix ecto.rollback                         # Rollback if needed
```

### Web Interface Features

- **Dashboard**: View holiday statistics
- **Add/Edit**: Create or modify holidays
- **Import**: Bulk import common holidays
- **Enable/Disable**: Temporarily activate/deactivate holidays
- **Delete**: Remove holidays permanently

## Troubleshooting

### Common Issues

1. **Fines still calculating weekend days**
   - Check if migration was run: `mix ecto.migrate`
   - Verify Transaction.days_overdue/1 was updated
   - Check LibHoliday.business_days_between/2 function

2. **Holidays not showing effect**
   - Ensure holidays are marked as `is_active: true`
   - Check holiday dates are correct
   - Verify database has holidays for the date range

3. **Import errors**
   - Holidays might already exist (unique constraint)
   - Check date formats are valid
   - Verify database connection

### Debug Commands

```bash
# Check current holidays
iex> Voile.Schema.System.LibHolidays.list_holidays()

# Check holiday stats
iex> Voile.Schema.System.LibHolidays.get_holiday_stats()

# Test business day calculation
iex> LibHoliday.business_days_between(~D[2023-12-20], ~D[2023-12-27])
```

## Related Files

- **Schema**: `/lib/voile/schema/system/lib_holiday.ex`
- **Context**: `/lib/voile/schema/system/lib_holidays.ex`  
- **LiveView**: `/lib/voile_web/live/dashboard/settings/holiday_live.ex`
- **Migration**: `/priv/repo/migrations/*_create_lib_holidays.exs`
- **Mix Tasks**: `/lib/mix/tasks/seed_holidays.ex`
- **Transaction Update**: `/lib/voile/schema/library/transaction.ex`

## Future Enhancements

1. **Holiday API Integration**: Connect to external holiday APIs for automatic updates
2. **Regional Holidays**: Support for province-specific Indonesian holidays
3. **Holiday Templates**: Predefined holiday sets for different regions
4. **Bulk Holiday Operations**: Import/export holiday data via CSV
5. **Holiday Notifications**: Alert staff about upcoming holidays
6. **Fine Policy Override**: Per-holiday fine calculation rules
