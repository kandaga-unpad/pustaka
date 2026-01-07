# Stock Opname Testing Guide

## Test Environment Setup

### Prerequisites

1. Database migrated with stock opname tables
2. At least 2 test users:
   - One with Super Admin role
   - One with Librarian role
3. Test data:
   - Multiple nodes
   - Multiple collection types
   - Collections with items
   - Items with barcodes

### Test Data Creation

```elixir
# In IEx console
alias Voile.Schema.{Catalog, Accounts}

# Create test librarian
{:ok, librarian} = Accounts.register_user(%{
  email: "librarian@test.com",
  password: "TestPassword123!",
  full_name: "Test Librarian"
})

# Assign librarian role (adjust based on your role system)
# ...

# Ensure items have barcodes for scanning
Catalog.list_items() |> Enum.take(50) |> Enum.map(fn item ->
  if is_nil(item.barcode) do
    Catalog.update_item(item, %{barcode: "BC#{String.pad_leading(to_string(item.id), 6, "0")}"})
  end
end)
```

## Test Scenarios

### Scenario 1: Complete Happy Path

**Objective**: Test full workflow from creation to approval

**Steps**:

1. **Login as Super Admin**

   - Navigate to `/manage/stock-opname`
   - Click "New Session"

2. **Create Session**

   - Title: "Test Session - January 2025"
   - Description: "Testing complete workflow"
   - Select 1-2 nodes
   - Select 1-2 collection types
   - Scope: "All"
   - Assign test librarian
   - Submit form
   - **Expected**: Redirects to index, session in "draft" status

3. **Start Session**

   - Click on created session
   - Click "Start Session" button
   - **Expected**: Status changes to "in_progress", librarian receives email

4. **Login as Librarian**

   - Navigate to `/manage/stock-opname`
   - Click on test session
   - Click "Continue Scanning"

5. **Scan Items**

   - Scan/enter 10 item identifiers
   - For 3 items: Update status or condition
   - Add notes to 1 item
   - **Expected**:
     - Each item appears in recent checks
     - Progress bar updates
     - Personal and overall counts increase

6. **Complete Librarian Work**

   - Click "Complete My Work"
   - **Expected**: Work status changes to "completed", admin receives email

7. **Login as Super Admin**

   - Navigate to session details
   - **Expected**: All librarians shown as "completed"
   - Click "Complete Session"
   - **Expected**: Status changes to "pending_review"

8. **Review Session**
   - Click "Review & Approve"
   - Review items with changes
   - Review missing items
   - Add approval notes
   - Click "Approve & Apply Changes"
   - **Expected**:
     - Status changes to "approved"
     - All changes applied to items
     - Missing items marked
     - Librarians receive approval email

**Pass Criteria**:

- ✅ Session created successfully
- ✅ Emails sent at each stage
- ✅ Items scanned and updated
- ✅ Missing items detected correctly
- ✅ Changes applied to database
- ✅ No errors in any step

---

### Scenario 2: Duplicate Item Handling

**Objective**: Test scanning items with same barcode

**Setup**: Create 2-3 items with identical barcodes

**Steps**:

1. Create and start session (as admin)
2. Login as librarian, start scanning
3. Enter barcode that has duplicates
4. **Expected**: UI shows all matching items
5. Select correct item from list
6. Complete check-in
7. **Expected**: Only selected item is checked

**Pass Criteria**:

- ✅ All duplicates displayed
- ✅ Only selected item checked
- ✅ Can scan other duplicates separately

---

### Scenario 3: Permission Tests

**Objective**: Verify authorization rules

**Test Cases**:

#### Test 3.1: Non-assigned Librarian

1. Create session, assign Librarian A
2. Login as Librarian B (not assigned)
3. Try to access scan page
4. **Expected**: "Permission denied" error, redirect to index

#### Test 3.2: Librarian Create Session

1. Login as librarian (not super admin)
2. Try to access `/manage/stock-opname/new`
3. **Expected**: Redirect with permission error

#### Test 3.3: Librarian Complete Session

1. Login as assigned librarian
2. Navigate to session details
3. **Expected**: No "Complete Session" button visible

#### Test 3.4: Librarian Approve Session

1. Login as librarian
2. Try to access review page
3. **Expected**: Permission denied, redirect

**Pass Criteria**:

- ✅ All unauthorized actions blocked
- ✅ Appropriate error messages shown
- ✅ Redirects to safe pages

---

### Scenario 4: Concurrent Scanning

**Objective**: Test multiple librarians scanning simultaneously

**Setup**: Assign 2+ librarians to same session

**Steps**:

1. Create and start session with 2 librarians
2. Login as Librarian A in Browser 1
3. Login as Librarian B in Browser 2
4. Both scan different items simultaneously
5. Both scan the same item
6. **Expected**:
   - Different items: Both succeed
   - Same item: First one succeeds, second gets "already checked" error

**Pass Criteria**:

- ✅ No deadlocks or race conditions
- ✅ Progress updates for both librarians
- ✅ Duplicate check prevents double-checking
- ✅ Row locking works correctly

---

### Scenario 5: Session Cancellation

**Objective**: Test cancelling sessions at various stages

**Test Cases**:

#### Test 5.1: Cancel Draft Session

1. Create session, don't start
2. Click "Cancel Session"
3. **Expected**: Session deleted or status = "cancelled"

#### Test 5.2: Cancel In-Progress Session

1. Create and start session
2. Librarian scans some items
3. Admin cancels session
4. **Expected**:
   - Status = "cancelled"
   - Scanned items remain checked
   - Librarians notified

**Pass Criteria**:

- ✅ Cancellation at any stage works
- ✅ Data preserved if needed
- ✅ Notifications sent

---

### Scenario 6: Missing Item Detection

**Objective**: Test smart missing detection logic

**Setup**:

- Create session for Node A, Type "Book"
- Have items:
  - Item 1: Node A, Book ✓ (in scope)
  - Item 2: Node A, Journal ✗ (different type)
  - Item 3: Node B, Book ✗ (different node)

**Steps**:

1. Create session: Node A, Books, Scope = All
2. Scan only Item 1
3. Complete session
4. **Expected**: Only Item 1 marked as "checked", other in-scope items marked "missing"
5. Verify Item 2 and Item 3 NOT marked missing (out of scope)

**Pass Criteria**:

- ✅ Only in-scope items can be missing
- ✅ Out-of-scope items ignored
- ✅ Missing count accurate

---

### Scenario 7: Revision Request

**Objective**: Test revision workflow

**Steps**:

1. Complete session through scanning
2. Admin reviews and clicks "Request Revision"
3. Enter notes: "Please re-check items in Location X"
4. Submit
5. **Expected**:
   - Status changes to "in_progress"
   - Librarians receive email with notes
6. Librarian makes corrections
7. Completes work again
8. Admin approves

**Pass Criteria**:

- ✅ Status reverts to "in_progress"
- ✅ Librarians can scan again
- ✅ Previous scans preserved
- ✅ Email with notes sent

---

### Scenario 8: Large Dataset Performance

**Objective**: Test with many items

**Setup**: Create session with 1000+ items in scope

**Steps**:

1. Create session for large collection
2. Start scanning
3. Scan 100+ items
4. Monitor:
   - Page load time
   - Scan response time
   - Memory usage
5. Complete session
6. Monitor missing detection time

**Pass Criteria**:

- ✅ Scan response < 1 second
- ✅ Missing detection < 30 seconds for 1000 items
- ✅ No memory leaks
- ✅ UI remains responsive

---

### Scenario 9: Edge Cases

**Test Cases**:

#### Test 9.1: Item Not Found

1. Scan non-existent barcode
2. **Expected**: "Item not found" message

#### Test 9.2: Empty Session

1. Create session with scope that matches 0 items
2. **Expected**: Warning about 0 items

#### Test 9.3: All Items Checked

1. Check all items in session
2. Try to find more items to scan
3. **Expected**: Message indicating all items checked

#### Test 9.4: Incomplete Librarian Work

1. Admin tries to complete session before all librarians done
2. **Expected**: Error message, cannot complete

**Pass Criteria**:

- ✅ All edge cases handled gracefully
- ✅ Appropriate error messages
- ✅ No crashes or exceptions

---

## Automated Test Examples

### Unit Test: Smart Missing Detection

```elixir
defmodule Voile.Schema.CatalogTest do
  use Voile.DataCase

  alias Voile.Schema.Catalog

  describe "complete_stock_opname_session/2" do
    test "marks only in-scope items as missing" do
      # Setup
      admin = insert(:user, :super_admin)
      node = insert(:node)
      other_node = insert(:node)

      collection = insert(:collection, node_id: node.id, collection_type: "book")
      other_collection = insert(:collection, node_id: other_node.id, collection_type: "book")

      # Items
      item_in_scope = insert(:item, collection: collection)
      item_out_scope = insert(:item, collection: other_collection)

      # Session
      session = insert(:stock_opname_session, %{
        node_ids: [node.id],
        collection_types: ["book"],
        scope_type: "all"
      })

      # Don't check any items

      # Act
      {:ok, session} = Catalog.complete_stock_opname_session(session, admin)

      # Assert
      assert session.missing_items == 1

      items = Catalog.list_session_items(session)
      in_scope_item = Enum.find(items, &(&1.item_id == item_in_scope.id))

      assert in_scope_item.check_status == "missing"
      refute Enum.any?(items, &(&1.item_id == item_out_scope.id))
    end
  end
end
```

### Integration Test: Full Workflow

```elixir
defmodule VoileWeb.StockOpnameLiveTest do
  use VoileWeb.ConnCase

  import Phoenix.LiveViewTest

  test "complete workflow from creation to approval", %{conn: conn} do
    admin = insert(:user, :super_admin)
    librarian = insert(:user, :librarian)
    item = insert(:item, barcode: "TEST001")

    conn = log_in_user(conn, admin)

    # Create session
    {:ok, view, _html} = live(conn, "/manage/stock-opname/new")

    view
    |> form("#session-form", session: %{
      title: "Test Session",
      node_ids: [item.collection.node_id],
      collection_types: ["book"],
      librarian_ids: [librarian.id]
    })
    |> render_submit()

    # ... continue with full workflow test
  end
end
```

---

## Performance Benchmarks

### Expected Performance

| Operation                     | Target Time | Max Acceptable |
| ----------------------------- | ----------- | -------------- |
| Create session                | < 500ms     | 1s             |
| Start session                 | < 200ms     | 500ms          |
| Scan single item              | < 300ms     | 1s             |
| Complete session (100 items)  | < 5s        | 10s            |
| Complete session (1000 items) | < 30s       | 60s            |
| Review page load              | < 1s        | 2s             |
| Approve session (100 changes) | < 3s        | 10s            |

### Load Testing

Use tools like Apache Bench or k6 to test:

- Multiple concurrent scanning sessions
- Many items scanned per second
- Large batch approvals

---

## Regression Tests

After any code changes, verify:

1. ✅ All existing sessions still accessible
2. ✅ Scanning still works correctly
3. ✅ Permissions not broken
4. ✅ Emails still sent
5. ✅ Missing detection logic unchanged

---

## Bug Report Template

When reporting issues:

```
**Title**: Brief description

**Steps to Reproduce**:
1.
2.
3.

**Expected Behavior**:

**Actual Behavior**:

**User Role**: Super Admin / Librarian

**Session Status**: Draft / In Progress / etc.

**Browser**: Chrome / Firefox / etc.

**Error Messages** (if any):

**Screenshots** (if applicable):
```

---

**Testing Status**: Ready for QA
**Last Updated**: 2025-01-07
