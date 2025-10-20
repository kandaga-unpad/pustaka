# Library Ledger Testing Guide

## Overview

This document provides comprehensive testing instructions for the Library Ledger (Transaction) system, including both the Index page (member search) and Transaction page (loan management).

## Test Files

- **Index Tests**: `test/voile_web/live/dashboard/glam/library/ledger/index_test.exs`
- **Transact Tests**: `test/voile_web/live/dashboard/glam/library/ledger/transact_test.exs`

## Running Tests

### Run All Ledger Tests

```cmd
mix test test/voile_web/live/dashboard/glam/library/ledger/
```

### Run Individual Test Files

```cmd
REM Index page tests only
mix test test/voile_web/live/dashboard/glam/library/ledger/index_test.exs

REM Transaction page tests only
mix test test/voile_web/live/dashboard/glam/library/ledger/transact_test.exs
```

### Run Specific Test Cases

```cmd
REM Run only Index page tests
mix test test/voile_web/live/dashboard/glam/library/ledger/index_test.exs --only describe:"Index page"

REM Run only Loan Tab tests
mix test test/voile_web/live/dashboard/glam/library/ledger/transact_test.exs --only describe:"Loan Tab"

REM Run specific test by line number
mix test test/voile_web/live/dashboard/glam/library/ledger/index_test.exs:45
```

### Run with Verbose Output

```cmd
mix test test/voile_web/live/dashboard/glam/library/ledger/ --trace
```

### Run Failed Tests Only

```cmd
mix test --failed
```

### Run with Coverage

```cmd
mix test --cover test/voile_web/live/dashboard/glam/library/ledger/
```

## Test Coverage

### Index Page Tests (`index_test.exs`)

#### Basic UI Tests
- ✅ Displays search interface
- ✅ Shows search input and labels
- ✅ Has correct page title

#### Search Functionality Tests
- ✅ Search by identifier (decimal)
- ✅ Search by member name
- ✅ Search by email
- ✅ Shows dropdown with results
- ✅ Displays "No results" message
- ✅ Clears search when input is empty
- ✅ Limits results to 10 members

#### Member Selection Tests
- ✅ Selects member from dropdown
- ✅ Shows member profile preview
- ✅ Displays all member information
- ✅ Shows expired badge for expired members
- ✅ Can clear selection and search again
- ✅ Navigates to transaction page on continue

### Transaction Page Tests (`transact_test.exs`)

#### Initialization Tests
- ✅ Loads member information correctly
- ✅ Redirects when member not found
- ✅ Displays all five tabs
- ✅ Default tab is "Loan"

#### Loan Tab Tests
- ✅ Search and add items to temporary loan list
- ✅ Remove items from temporary loan list
- ✅ Finish transaction and create loans
- ✅ Prevents adding unavailable items
- ✅ Shows success message after checkout

#### Current Loans Tab Tests
- ✅ Displays current loans
- ✅ Shows overdue indicator
- ✅ Return item with confirmation modal
- ✅ Extend/renew loan with confirmation modal
- ✅ Shows "No active loans" message

#### Reserve Tab Tests
- ✅ Add items to reservation list
- ✅ Remove items from reservation list
- ✅ Finish reservation transaction
- ✅ Shows success message

#### Fines Tab Tests
- ✅ Displays unpaid fines with amounts
- ✅ Create manual fine with confirmation
- ✅ Pay fine with confirmation modal
- ✅ Shows "No unpaid fines" message
- ✅ Formats currency correctly (Rupiah)

#### Loan History Tab Tests
- ✅ Displays returned loans
- ✅ Shows return dates and status
- ✅ Shows "No loan history" message

## Test Data Setup

Each test uses the following fixtures:

### Member Type
- Name: "Regular Member"
- Max concurrent loans: 5
- Max loan days: 14
- Can renew: true
- Max renewals: 2
- Can reserve: true
- Max reserves: 3
- Fine per day: Rp 5,000
- Max fine: Rp 100,000

### Test Members
- **Member 1**: John Doe (ID: 12345) - Active member
- **Member 2**: Jane Smith (ID: 67890) - Active member
- **Expired Member**: (ID: 11111) - Expired membership

### Test Items
- Item 1: ITEM001 - "Test Book 1"
- Item 2: ITEM002 - "Test Book 2"
- Item 3: ITEM003 - "Test Book 3"

## Debugging Failed Tests

### View Test Output Details

```cmd
mix test test/voile_web/live/dashboard/glam/library/ledger/index_test.exs --trace
```

### Run Single Test with Full Error Stack

```cmd
mix test test/voile_web/live/dashboard/glam/library/ledger/index_test.exs:45 --trace
```

### Check Database State During Tests

Add `IO.inspect/2` in test code to debug:

```elixir
test "my test", %{member: member} do
  IO.inspect(member, label: "Member data")
  # ... rest of test
end
```

### Common Issues and Solutions

#### 1. Member Not Found Errors
**Problem**: Tests fail because member fixtures aren't created properly
**Solution**: Check that `create_member_with_identifier/2` is setting `user_type_id` correctly

#### 2. Modal Not Showing
**Problem**: Tests fail because modal elements aren't found
**Solution**: Ensure modal IDs match between test assertions and LiveView templates

#### 3. Transaction Creation Fails
**Problem**: Circulation context functions return errors
**Solution**: Verify all required fields are present and item status is "available"

#### 4. Search Not Working
**Problem**: Dropdown doesn't show results
**Solution**: Check that `search_members/1` query matches the schema fields (identifier, fullname, email)

## Testing Best Practices

### 1. Always Run Tests Before Committing

```cmd
mix test test/voile_web/live/dashboard/glam/library/ledger/
```

### 2. Use `mix precommit` Alias

```cmd
mix precommit
```

This runs:
- All tests
- Code formatting checks
- Compilation warnings
- Linting

### 3. Test Isolation

Each test is isolated with:
- Fresh database via `Ecto.Adapters.SQL.Sandbox`
- Unique test data per test case
- Proper setup and teardown

### 4. Integration with CI/CD

Add to your CI pipeline:

```yaml
- name: Run Ledger Tests
  run: mix test test/voile_web/live/dashboard/glam/library/ledger/
```

## Manual Testing Checklist

After running automated tests, manually verify:

### Index Page
- [ ] Navigate to `/manage/glam/library/ledger`
- [ ] Type member identifier - dropdown appears
- [ ] Click member in dropdown - profile shows
- [ ] Click "Continue to Transaction" - navigates correctly
- [ ] Click "Change Member" - returns to search

### Transaction Page - Loan Tab
- [ ] Search for item by barcode
- [ ] Add multiple items to loan list
- [ ] Remove item from loan list
- [ ] Click "Finish Transaction" - confirmation modal appears
- [ ] Confirm transaction - items are checked out

### Transaction Page - Current Loans Tab
- [ ] View active loans
- [ ] Check overdue indicator shows correctly
- [ ] Click "Return" - modal appears
- [ ] Confirm return - item is returned
- [ ] Click "Extend" - modal appears
- [ ] Confirm extend - due date is updated

### Transaction Page - Reserve Tab
- [ ] Search for item
- [ ] Add items to reservation list
- [ ] Finish reservation transaction

### Transaction Page - Fines Tab
- [ ] View unpaid fines
- [ ] Create manual fine
- [ ] Pay fine with confirmation
- [ ] Verify currency formatting

### Transaction Page - History Tab
- [ ] View past transactions
- [ ] Verify dates and status display correctly

## Performance Testing

### Test Database Query Performance

```cmd
mix test test/voile_web/live/dashboard/glam/library/ledger/ --trace
```

Look for slow queries in output. Optimize with:
- Database indexes on `identifier`, `fullname`, `email`
- Proper preloading of associations
- Limit search results (currently 10)

### Load Testing

For production readiness, consider:
- Multiple concurrent users searching
- Large datasets (1000+ members)
- Many active transactions per member

## Continuous Monitoring

### Add Test Metrics

Track:
- Test execution time
- Test coverage percentage
- Number of passing/failing tests
- Flaky test detection

### Example Coverage Report

```cmd
mix test --cover
```

Then open `cover/excoveralls.html` to view detailed coverage.

## Next Steps

1. **Add Integration Tests**: Test full user workflows end-to-end
2. **Add Performance Tests**: Measure response times under load
3. **Add Accessibility Tests**: Verify WCAG compliance
4. **Add Security Tests**: Test authorization and input validation

## Support

For issues with tests:
1. Check test output for error messages
2. Verify database schema matches test expectations
3. Review LEDGER_IMPLEMENTATION.md for context functions
4. Check fixture data is valid and complete
