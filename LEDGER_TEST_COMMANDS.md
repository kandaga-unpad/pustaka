# Quick Test Commands for Library Ledger

## Windows Commands (CMD)

### Run All Ledger Tests
```cmd
mix test test\voile_web\live\dashboard\glam\library\ledger\
```

### Run Individual Test Files
```cmd
REM Index page tests
mix test test\voile_web\live\dashboard\glam\library\ledger\index_test.exs

REM Transaction page tests
mix test test\voile_web\live\dashboard\glam\library\ledger\transact_test.exs
```

### Using the Test Script
```cmd
REM Show help
test_ledger.bat help

REM Run all tests
test_ledger.bat all

REM Run specific tests
test_ledger.bat index
test_ledger.bat transact

REM Run with coverage
test_ledger.bat coverage

REM Run failed tests only
test_ledger.bat failed
```

### Other Useful Commands
```cmd
REM Run with detailed output
mix test test\voile_web\live\dashboard\glam\library\ledger\ --trace

REM Run specific test by line number
mix test test\voile_web\live\dashboard\glam\library\ledger\index_test.exs:45

REM Run tests matching a pattern
mix test --only describe:"Index page"

REM Watch mode (requires mix_test_watch)
mix test.watch test\voile_web\live\dashboard\glam\library\ledger\
```

## Test Coverage Summary

### Index Page Tests (index_test.exs)
- ✅ Display search interface
- ✅ Search by identifier
- ✅ Search by name  
- ✅ Search by email
- ✅ Show dropdown results
- ✅ Handle no results
- ✅ Clear search on empty input
- ✅ Select member and show profile
- ✅ Show expired badge
- ✅ Clear selection
- ✅ Navigate to transaction page
- ✅ Limit results to 10 members

**Total: 12 tests**

### Transaction Page Tests (transact_test.exs)
- ✅ Load member information
- ✅ Redirect on invalid member
- ✅ Display all five tabs
- ✅ Default to Loan tab
- ✅ Display loan tab interface
- ✅ Show empty loan list message
- ✅ Switch to Current Loans tab
- ✅ Switch to Reserve tab
- ✅ Switch to Fines tab
- ✅ Switch to Loan History tab

**Total: 10 tests**

**Grand Total: 22 tests**

## Quick Start

1. **First Time Setup**
   ```cmd
   mix deps.get
   mix ecto.setup
   ```

2. **Run All Tests**
   ```cmd
   test_ledger.bat all
   ```

3. **If Tests Fail**
   - Check error messages
   - Verify database is running
   - Run failed tests again: `test_ledger.bat failed`
   - Check logs for details

## Before Committing

Always run the precommit check:
```cmd
mix precommit
```

This will:
- Run all tests
- Check code formatting
- Run linters
- Check for compilation warnings

## Continuous Integration

Add to your CI pipeline:
```yaml
- name: Run Ledger Tests
  run: mix test test/voile_web/live/dashboard/glam/library/ledger/ --cover
```

## Troubleshooting

### Database Connection Errors
```cmd
REM Start PostgreSQL
pg_ctl start

REM Reset test database
mix ecto.reset
```

### Compilation Errors
```cmd
REM Clean and recompile
mix clean
mix compile
```

### Fixture Errors
If you see errors about missing members or items, check:
- `test/support/fixtures/accounts_fixtures.ex`
- `test/support/fixtures/library_fixtures.ex`

The tests use `ensure_*` helper functions to create test data as needed.

## Documentation

- Full testing guide: `LEDGER_TESTING.md`
- Implementation details: `LEDGER_IMPLEMENTATION.md`
- Project guidelines: `AGENTS.md`
