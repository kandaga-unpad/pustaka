# Catalog & Circulation Quick Reference

## Module Quick Links

### Catalog Modules
- **Dashboard:** `VoileWeb.Dashboard.Catalog.Index`
- **Collections:** `VoileWeb.Dashboard.Catalog.CollectionLive.*`
- **Items:** `VoileWeb.Dashboard.Catalog.ItemLive.*`

### Circulation Modules
- **Dashboard:** `VoileWeb.Dashboard.Circulation.Index`
- **Transactions:** `VoileWeb.Dashboard.Circulation.Transaction.*`
- **Reservations:** `VoileWeb.Dashboard.Circulation.Reservation.*`
- **Requisitions:** `VoileWeb.Dashboard.Circulation.Requisition.*`
- **Fines:** `VoileWeb.Dashboard.Circulation.Fine.*`
- **History:** `VoileWeb.Dashboard.Circulation.CirculationHistory.*`

## Route Quick Reference

### Catalog Routes
```
/manage/catalog                                # Overview
/manage/catalog/collections                    # Collections list
/manage/catalog/collections/new                # New collection
/manage/catalog/collections/:id                # Collection details
/manage/catalog/collections/:id/attachments    # Collection files
/manage/catalog/items                          # Items list
/manage/catalog/items/new                      # New item
/manage/catalog/items/:id                      # Item details
```

### Circulation Routes
```
/manage/circulation                            # Overview
/manage/circulation/transactions               # Transactions list
/manage/circulation/transactions/checkout      # Checkout interface
/manage/circulation/reservations               # Reservations list
/manage/circulation/requisitions               # Requisitions list
/manage/circulation/fines                      # Fines list
/manage/circulation/circulation_history        # History
```

## Common Code Patterns

### Catalog - List Collections
```elixir
# In IEx
alias Voile.Schema.Catalog

# Get paginated collections
{collections, total_pages} = Catalog.list_collections_paginated(page, per_page)

# Get tree view (limited)
tree_collections = Catalog.list_collections_tree(50)

# Get specific collection with associations
collection = Catalog.get_collection!(id)
```

### Catalog - Create Collection
```elixir
# Create collection
attrs = %{
  title: "Historical Archives",
  description: "Documents from 1800s",
  resource_class_id: 1,
  node_id: 1,
  visibility: "public"
}

{:ok, collection} = Catalog.create_collection(attrs)
```

### Catalog - Create Item
```elixir
# Create item
attrs = %{
  item_code: "ITEM-001",
  collection_id: 1,
  status: "available",
  location: "Main Library - Shelf A1",
  call_number: "973.7 SMI"
}

{:ok, item} = Catalog.create_item(attrs)
```

### Circulation - Checkout
```elixir
alias Voile.Schema.Library.Circulation

# Process checkout
{:ok, transaction} = Circulation.checkout_item(
  member_id: "member-123",
  item_id: 1,
  checked_out_by_id: staff_user_id
)
```

### Circulation - Return
```elixir
# Process return
{:ok, transaction} = Circulation.return_item(
  transaction_id: 1,
  returned_by_id: staff_user_id
)

# If overdue, fine is automatically calculated
```

### Circulation - Renew
```elixir
# Renew transaction
{:ok, transaction} = Circulation.renew_transaction(
  transaction_id: 1,
  renewed_by_id: staff_user_id
)
```

### Circulation - Create Reservation
```elixir
# Create reservation
{:ok, reservation} = Circulation.create_reservation(
  member_id: "member-123",
  item_id: 1
)
```

### Circulation - Process Fine
```elixir
# Record payment
{:ok, fine} = Circulation.record_fine_payment(
  fine_id: 1,
  amount: Decimal.new("5.00"),
  payment_method: "cash"
)

# Waive fine
{:ok, fine} = Circulation.waive_fine(
  fine_id: 1,
  waived_by_id: staff_user_id,
  reason: "First offense, good standing member"
)
```

## LiveView Event Patterns

### Catalog Events
```elixir
# In CollectionLive.Index
def handle_event("paginate", %{"page" => page}, socket)
def handle_event("toggle_view", %{"mode" => mode}, socket)
def handle_event("search", %{"query" => query}, socket)

# In ItemLive.Index
def handle_event("delete", %{"id" => id}, socket)
def handle_event("paginate", %{"page" => page}, socket)
```

### Circulation Events
```elixir
# In Transaction.Index
def handle_event("checkout", params, socket)
def handle_event("return", %{"id" => id}, socket)
def handle_event("renew", %{"id" => id}, socket)
def handle_event("search", %{"query" => query}, socket)

# In Fine.Index
def handle_event("record_payment", params, socket)
def handle_event("waive_fine", %{"id" => id, "reason" => reason}, socket)

# In Reservation.Index
def handle_event("create_reservation", params, socket)
def handle_event("cancel_reservation", %{"id" => id}, socket)
def handle_event("mark_available", %{"id" => id}, socket)
```

## Database Query Helpers

### Get Catalog Data
```elixir
# Get items in a collection
items = Catalog.list_items_by_collection(collection_id)

# Search items
{items, total} = Catalog.search_items_paginated(query, page, per_page)

# Get item availability
available? = Catalog.item_available?(item_id)
```

### Get Circulation Data
```elixir
# Get active transactions
transactions = Circulation.list_active_transactions()

# Get overdue transactions
overdue = Circulation.list_overdue_transactions()

# Get member's active loans
loans = Circulation.list_member_transactions(member_id, status: "active")

# Get unpaid fines
fines = Circulation.list_unpaid_fines()

# Count statistics
stats = %{
  active_transactions: Circulation.count_active_transactions(),
  overdue: Circulation.count_overdue_transactions(),
  pending_reservations: Circulation.count_pending_reservations()
}
```

## Component Usage

### In Templates (HEEx)

#### Catalog Components
```heex
<%!-- Attachment upload --%>
<.live_component
  module={VoileWeb.Dashboard.Catalog.Components.AttachmentUpload}
  id="attachment-upload"
  collection={@collection}
/>

<%!-- Collection tree --%>
<.collection_tree collections={@tree_collections} />
```

#### Circulation Components
```heex
<%!-- Status badge --%>
<.status_badge status={@transaction.status} />

<%!-- Transaction card --%>
<.transaction_card transaction={@transaction} />

<%!-- Member search --%>
<.member_search on_select={fn member -> ... end} />

<%!-- Fine calculator --%>
<.fine_calculator 
  days_overdue={@days_overdue}
  daily_rate={@daily_rate}
/>
```

## Helper Functions

### Catalog Helpers
```elixir
# Format collection visibility
visibility_label("public")  # => "Public"
visibility_label("private") # => "Private"

# Generate item code
generate_item_code(collection_prefix, sequence) # => "COLL-001"

# Check collection hierarchy depth
max_depth = get_collection_depth(collection)
```

### Circulation Helpers
```elixir
# From VoileWeb.Dashboard.Circulation.Helpers

# Calculate due date (14 days default)
due_date = calculate_due_date(checkout_date, loan_period_days)

# Calculate fine
fine_amount = calculate_fine(days_overdue, daily_rate)

# Format currency
format_currency(Decimal.new("15.50")) # => "$15.50"

# Check renewal eligibility
can_renew?(transaction) # => true/false

# Get member identifier
member_id = get_id_from_member_identifier("M12345")
```

## Status Values

### Collection Status
- `"draft"` - Not published
- `"published"` - Public/available
- `"archived"` - No longer active

### Item Status
- `"available"` - Can be checked out
- `"checked_out"` - Currently borrowed
- `"on_hold"` - Reserved for someone
- `"lost"` - Missing
- `"damaged"` - Needs repair
- `"withdrawn"` - Removed from collection

### Transaction Status
- `"active"` - Currently checked out
- `"overdue"` - Past due date
- `"returned"` - Completed

### Reservation Status
- `"pending"` - Waiting for availability
- `"available"` - Ready for pickup
- `"fulfilled"` - Picked up
- `"cancelled"` - Cancelled by member/staff
- `"expired"` - Pickup deadline passed

### Requisition Status
- `"submitted"` - New request
- `"under_review"` - Being evaluated
- `"approved"` - Approved for purchase
- `"ordered"` - Order placed
- `"received"` - Item received
- `"rejected"` - Request denied
- `"cancelled"` - Request withdrawn

### Fine Status
- `"unpaid"` - Outstanding balance
- `"partially_paid"` - Partial payment made
- `"paid"` - Fully paid
- `"waived"` - Forgiven

### Fine Types
- `"overdue"` - Late return fee
- `"damage"` - Damage assessment
- `"lost"` - Lost item replacement
- `"other"` - Manual/miscellaneous

## Form Changesets

### Collection Changeset
```elixir
changeset = Collection.changeset(%Collection{}, %{
  title: "New Collection",
  description: "Description here",
  resource_class_id: 1,
  visibility: "public"
})
```

### Item Changeset
```elixir
changeset = Item.changeset(%Item{}, %{
  item_code: "ITEM-001",
  collection_id: 1,
  status: "available",
  location: "Shelf A1"
})
```

### Transaction Changeset
```elixir
changeset = Transaction.changeset(%Transaction{}, %{
  member_id: member_id,
  item_id: item_id,
  checkout_date: DateTime.utc_now(),
  due_date: calculate_due_date(DateTime.utc_now(), 14)
})
```

### Fine Changeset
```elixir
changeset = Fine.changeset(%Fine{}, %{
  member_id: member_id,
  item_id: item_id,
  transaction_id: transaction_id,
  amount: Decimal.new("10.00"),
  fine_type: "overdue",
  reason: "5 days overdue"
})
```

## Testing Helpers

### Seeds for Testing

```elixir
# In test/support/fixtures.ex

def collection_fixture(attrs \\ %{}) do
  {:ok, collection} = 
    attrs
    |> Enum.into(%{
      title: "Test Collection",
      visibility: "public",
      resource_class_id: 1
    })
    |> Catalog.create_collection()
  
  collection
end

def item_fixture(attrs \\ %{}) do
  collection = collection_fixture()
  
  {:ok, item} = 
    attrs
    |> Enum.into(%{
      item_code: "TEST-#{System.unique_integer([:positive])}",
      collection_id: collection.id,
      status: "available"
    })
    |> Catalog.create_item()
  
  item
end

def transaction_fixture(attrs \\ %{}) do
  member = user_fixture()
  item = item_fixture()
  
  {:ok, transaction} =
    attrs
    |> Enum.into(%{
      member_id: member.id,
      item_id: item.id,
      checkout_date: DateTime.utc_now(),
      due_date: calculate_due_date(DateTime.utc_now(), 14)
    })
    |> Circulation.create_transaction()
  
  transaction
end
```

## Common Errors & Solutions

### "Item not available"
**Cause:** Item status is not "available"  
**Solution:** Check item status, ensure it's returned first

### "Member not eligible"
**Cause:** Member has too many checkouts or unpaid fines  
**Solution:** Check member's account, resolve fines or returns

### "Cannot renew transaction"
**Cause:** Max renewals reached or item is reserved  
**Solution:** Check renewal count and reservation queue

### "Collection has items"
**Cause:** Trying to delete collection with items  
**Solution:** Remove or reassign items first

### "Parent collection not found"
**Cause:** Invalid parent_id reference  
**Solution:** Verify parent collection exists

## Performance Tips

1. **Use Pagination:** Always paginate large lists
   ```elixir
   {items, total_pages} = Catalog.list_items_paginated(page, 15)
   ```

2. **Preload Associations:** Load related data upfront
   ```elixir
   collection = Repo.preload(collection, [:items, :resource_class, :node])
   ```

3. **Use Streams:** For LiveView lists
   ```elixir
   socket |> stream(:items, items)
   ```

4. **Limit Tree Depth:** Don't load entire tree
   ```elixir
   tree_collections = Catalog.list_collections_tree(50) # Limit to 50
   ```

5. **Cache Statistics:** Use assigns_async for slow queries
   ```elixir
   socket |> assign_async(:stats, fn -> load_stats() end)
   ```

## Keyboard Shortcuts (if implemented)

- `Ctrl+N` - New collection/item
- `Ctrl+F` - Focus search
- `Ctrl+S` - Save form
- `Esc` - Close modal
- `/` - Quick search

## API Endpoints (if REST API exists)

```
GET    /api/catalog/collections
POST   /api/catalog/collections
GET    /api/catalog/collections/:id
PUT    /api/catalog/collections/:id
DELETE /api/catalog/collections/:id

GET    /api/catalog/items
POST   /api/catalog/items
GET    /api/catalog/items/:id
PUT    /api/catalog/items/:id
DELETE /api/catalog/items/:id

POST   /api/circulation/checkout
POST   /api/circulation/return
POST   /api/circulation/renew
GET    /api/circulation/transactions
GET    /api/circulation/transactions/:id
```

## Related Documentation

- [Catalog Module Guide](./module-guide.md) - Complete catalog documentation
[Circulation Module Guide](../circulation/module-guide.md) - Complete circulation documentation
- [RBAC Guide](../../authentication/rbac-complete-guide.md) - Authorization system
- [Database Schema](../../architecture/overview.md) - Database structure
