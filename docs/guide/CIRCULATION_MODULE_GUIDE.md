# Circulation Module Family Documentation

## Overview

The **Circulation** module family (`VoileWeb.Dashboard.Circulation.*`) manages all library circulation activities including checkouts, returns, renewals, reservations, requisitions, fines, and circulation history. This is the operational heart of the library system.

## Architecture

```
VoileWeb.Dashboard.Circulation
├── Index                          # Circulation dashboard/overview
├── Transaction
│   ├── Index                      # List/manage transactions
│   └── Show                       # View transaction details
├── Reservation
│   ├── Index                      # List/manage reservations
│   └── Show                       # View reservation details
├── Requisition
│   ├── Index                      # List/manage requisitions
│   └── Show                       # View requisition details
├── Fine
│   ├── Index                      # List/manage fines
│   └── Show                       # View/pay fine details
├── CirculationHistory
│   ├── Index                      # View circulation history
│   └── Show                       # View history details
└── Components
    ├── Components                 # Reusable UI components
    └── Helpers                    # Helper functions
```

## Module Descriptions

### VoileWeb.Dashboard.Circulation.Index

**Purpose:** Main circulation dashboard showing real-time statistics and quick access

**Route:** `/manage/circulation`

**Features:**
- **Quick Stats Dashboard:**
  - Active transactions count
  - Overdue items count
  - Pending reservations count
  - Total fines amount
  - Today's checkouts
  - Today's returns
- **Quick Actions:**
  - Quick checkout
  - Quick return
  - Search member
  - Search item
- **Recent Activity:** Latest transactions and reservations
- **Overdue Alert:** Highlighted overdue items
- **Loading States:** Spinners while fetching data

**Key Functions:**
- `mount/3` - Load dashboard statistics
- `handle_event("quick_checkout", ...)` - Process quick checkout
- `handle_event("quick_return", ...)` - Process quick return
- `handle_event("search", ...)` - Search members or items

**Assigns:**
- `@stats.active_transactions` - Count of active loans
- `@stats.overdue_count` - Count of overdue items
- `@stats.pending_reservations` - Count of pending reservations
- `@stats.total_fines` - Total outstanding fines amount
- `@stats.today_checkouts` - Checkouts today
- `@stats.today_returns` - Returns today

---

### VoileWeb.Dashboard.Circulation.Transaction.Index

**Purpose:** Comprehensive transaction management interface

**Route:** `/manage/circulation/transactions`

**Features:**
- **Transaction List:** Paginated table of all transactions
- **Checkout:** Create new checkouts (borrow items)
- **Return:** Process returns with fine calculation
- **Renew:** Extend loan periods
- **Search & Filter:**
  - Filter by status (active, overdue, returned)
  - Search by member or item
  - Date range filters
- **Quick Actions:**
  - Bulk operations
  - Quick checkout from list
  - Mark as overdue
- **Status Tracking:**
  - Active loans (in progress)
  - Overdue loans (past due date)
  - Returned loans (completed)

**Key Functions:**
- `mount/3` - Initialize transactions with stats
- `handle_event("checkout", ...)` - Process checkout
- `handle_event("return", ...)` - Process return with fine calculation
- `handle_event("renew", ...)` - Renew transaction
- `handle_event("search", ...)` - Filter transactions
- `handle_event("paginate", ...)` - Navigate pages

**Assigns:**
- `@streams.transactions` - Stream of transactions
- `@page` - Current page
- `@total_pages` - Total pages
- `@search_query` - Current search query
- `@filter_status` - Current status filter (all/active/overdue/returned)
- `@checkout_changeset` - Changeset for new checkout
- `@count_active_collection` - Count of active transactions
- `@count_overdue_collection` - Count of overdue transactions
- `@count_returned_collection` - Count of returned transactions
- `@return_modal_visible` - Toggle return modal
- `@predicted_fine` - Calculated fine amount
- `@payment_method` - Selected payment method
- `@renew_modal_visible` - Toggle renew modal
- `@recommended_renew_days` - Suggested renewal period

**Events:**
- `checkout` - Create new transaction
- `return` - Process item return
- `renew` - Renew loan period
- `search` - Filter transactions
- `paginate` - Change page
- `show_return_modal` - Open return interface
- `calculate_fine` - Calculate overdue fine

**Checkout Process:**
1. Enter member identifier (ID, barcode, or email)
2. Enter item code or scan barcode
3. System validates member eligibility
4. System checks item availability
5. System calculates due date
6. Transaction created
7. Item status updated to "checked_out"

**Return Process:**
1. Scan item barcode or enter item code
2. System finds active transaction
3. System calculates if overdue
4. If overdue, calculate fine
5. Process fine payment (if applicable)
6. Mark transaction as returned
7. Item status updated to "available"

**Renew Process:**
1. Select transaction to renew
2. System checks renewal eligibility
3. System calculates new due date
4. Transaction updated with new dates
5. Renewal count incremented

---

### VoileWeb.Dashboard.Circulation.Transaction.Show

**Purpose:** Detailed view of a specific transaction

**Route:** `/manage/circulation/transactions/:id`

**Features:**
- View complete transaction details
- Member information
- Item information
- Checkout date and time
- Due date
- Return date (if returned)
- Fine details (if applicable)
- Renewal history
- Transaction timeline
- Edit transaction (if needed)

**Key Functions:**
- `mount/3` - Load transaction with all associations
- `handle_event("renew_from_detail", ...)` - Renew from detail page
- `handle_event("return_from_detail", ...)` - Return from detail page

**Assigns:**
- `@transaction` - Current transaction
- `@member` - Associated member
- `@item` - Associated item
- `@fine` - Associated fine (if exists)
- `@renewal_history` - List of renewals

---

### VoileWeb.Dashboard.Circulation.Reservation.Index

**Purpose:** Manage item reservations (holds)

**Route:** `/manage/circulation/reservations`

**Features:**
- **Reservation List:** All active and past reservations
- **Create Reservation:** Place hold on items
- **Status Tracking:**
  - Pending: Waiting for item availability
  - Available: Item ready for pickup
  - Fulfilled: Member picked up item
  - Cancelled: Reservation cancelled
  - Expired: Pickup window passed
- **Notifications:** Alert when item becomes available
- **Priority Queue:** First-come, first-served
- **Expiration:** Auto-expire if not picked up

**Key Functions:**
- `mount/3` - Load reservations list
- `handle_event("create_reservation", ...)` - Create new reservation
- `handle_event("cancel_reservation", ...)` - Cancel reservation
- `handle_event("mark_available", ...)` - Mark item ready for pickup
- `handle_event("fulfill_reservation", ...)` - Complete pickup
- `handle_event("paginate", ...)` - Navigate pages

**Assigns:**
- `@streams.reservations` - Stream of reservations
- `@page` - Current page
- `@total_pages` - Total pages
- `@filter_status` - Status filter

**Events:**
- `create_reservation` - Place new hold
- `cancel_reservation` - Cancel hold
- `mark_available` - Item ready notification
- `fulfill_reservation` - Complete pickup
- `paginate` - Change page

**Reservation Workflow:**
1. Member requests item (currently checked out)
2. Reservation created with "pending" status
3. When item returned, system checks reservations
4. First reservation marked "available"
5. Member notified to pickup
6. Member has X days to pickup
7. If picked up: Status → "fulfilled"
8. If not picked up: Status → "expired"

---

### VoileWeb.Dashboard.Circulation.Reservation.Show

**Purpose:** Detailed view of a specific reservation

**Route:** `/manage/circulation/reservations/:id`

**Features:**
- View reservation details
- Member information
- Item information
- Reservation date
- Status and timeline
- Pickup deadline (if available)
- Notification history
- Quick actions (cancel, mark picked up)

---

### VoileWeb.Dashboard.Circulation.Requisition.Index

**Purpose:** Manage acquisition requests from members

**Route:** `/manage/circulation/requisitions`

**Features:**
- **Requisition List:** Member requests for materials
- **Create Requisition:** Submit acquisition request
- **Status Tracking:**
  - Submitted: New request
  - Under Review: Being evaluated
  - Approved: Will be acquired
  - Ordered: Order placed
  - Received: Item arrived
  - Rejected: Request denied
  - Cancelled: Request withdrawn
- **Priority Assignment:** Prioritize requests
- **Budget Tracking:** Link to acquisition budget
- **Notifications:** Update requestor on status

**Key Functions:**
- `mount/3` - Load requisitions list
- `handle_event("create_requisition", ...)` - Submit new request
- `handle_event("update_status", ...)` - Change requisition status
- `handle_event("assign_priority", ...)` - Set priority
- `handle_event("paginate", ...)` - Navigate pages

**Assigns:**
- `@streams.requisitions` - Stream of requisitions
- `@page` - Current page
- `@total_pages` - Total pages
- `@filter_status` - Status filter
- `@filter_type` - Type filter (book, journal, media)

**Events:**
- `create_requisition` - Submit request
- `update_status` - Change status
- `assign_priority` - Set priority level
- `add_notes` - Add staff notes
- `paginate` - Change page

**Requisition Workflow:**
1. Member submits request with details
2. Staff reviews request
3. Decide: Approve or Reject
4. If approved: Create purchase order
5. Track order status
6. When received: Add to catalog
7. Notify requestor
8. Option to reserve for requestor

---

### VoileWeb.Dashboard.Circulation.Requisition.Show

**Purpose:** Detailed view of a specific requisition

**Route:** `/manage/circulation/requisitions/:id`

**Features:**
- Complete requisition details
- Requestor information
- Item details requested
- Justification/reason
- Status timeline
- Staff notes
- Budget allocation
- Edit requisition
- Approve/reject actions

---

### VoileWeb.Dashboard.Circulation.Fine.Index

**Purpose:** Manage library fines and payments

**Route:** `/manage/circulation/fines`

**Features:**
- **Fine List:** All fines (paid and unpaid)
- **Create Fine:** Manual fine entry
- **Filter By:**
  - Status (unpaid, paid, waived)
  - Type (overdue, damage, lost, other)
  - Date range
  - Amount range
- **Payment Processing:**
  - Cash payment
  - Card payment
  - Online payment
  - Check payment
- **Waive Fines:** Forgive fines with reason
- **Payment History:** Track all transactions
- **Reports:** Fine collection reports

**Key Functions:**
- `mount/3` - Load fines with filters
- `handle_event("create_fine", ...)` - Create manual fine
- `handle_event("record_payment", ...)` - Process payment
- `handle_event("waive_fine", ...)` - Forgive fine
- `handle_event("item_search", ...)` - Search for item
- `handle_event("paginate", ...)` - Navigate pages

**Assigns:**
- `@streams.fines` - Stream of fines
- `@page` - Current page
- `@total_pages` - Total pages
- `@filter_status` - Status filter (all/unpaid/paid/waived)
- `@filter_type` - Type filter (all/overdue/damage/lost)
- `@fine_form` - Form for creating fine
- `@item_suggestions` - Item search results
- `@item_search_text` - Search query
- `@selected_item_id` - Selected item ID

**Events:**
- `create_fine` - Create new fine
- `record_payment` - Process payment
- `waive_fine` - Forgive fine
- `item_search` - Search items
- `choose_item` - Select item
- `paginate` - Change page

**Fine Types:**
1. **Overdue:** Calculated based on days late × daily rate
2. **Damage:** Assessed for damaged items
3. **Lost:** Charged for lost/missing items (typically replacement cost)
4. **Other:** Manual fines (lost card, printing, etc.)

**Payment Methods:**
- Cash
- Credit/Debit Card
- Online Payment
- Check
- Account Credit

---

### VoileWeb.Dashboard.Circulation.Fine.Show

**Purpose:** Detailed view of a specific fine

**Route:** `/manage/circulation/fines/:id`

**Features:**
- Fine details (amount, type, reason)
- Associated transaction
- Member information
- Item information
- Payment history
- Process payment interface
- Waive fine interface
- Partial payment support
- Receipt generation

**Key Functions:**
- `mount/3` - Load fine with details
- `handle_event("process_payment", ...)` - Record payment
- `handle_event("waive", ...)` - Waive fine
- `handle_event("send_reminder", ...)` - Send payment reminder

**Additional Routes:**
- `/manage/circulation/fines/:id/payment` - Payment interface
- `/manage/circulation/fines/:id/waive` - Waive interface

---

### VoileWeb.Dashboard.Circulation.CirculationHistory.Index

**Purpose:** View complete circulation history and analytics

**Route:** `/manage/circulation/circulation_history`

**Features:**
- **Complete History:** All circulation activities
- **Analytics:**
  - Most borrowed items
  - Most active members
  - Peak borrowing times
  - Collection popularity
- **Reports:**
  - Daily circulation report
  - Monthly statistics
  - Annual summaries
- **Export:** CSV/PDF export for reports
- **Filters:**
  - Date range
  - Member
  - Item
  - Collection
  - Transaction type

**Key Functions:**
- `mount/3` - Load circulation history
- `handle_event("filter", ...)` - Apply filters
- `handle_event("export", ...)` - Export data
- `handle_event("generate_report", ...)` - Generate report

---

### VoileWeb.Dashboard.Circulation.CirculationHistory.Show

**Purpose:** Detailed view of historical circulation data

**Route:** `/manage/circulation/circulation_history/:id`

**Features:**
- View specific historical record
- Complete activity timeline
- Member history
- Item history
- Associated fines
- Notes and comments

---

### VoileWeb.Dashboard.Circulation.Components

**Purpose:** Reusable UI components for circulation interfaces

**Components:**
- `circulation_breadcrumb/1` - Navigation breadcrumbs
- `status_badge/1` - Colored status indicators
- `transaction_card/1` - Transaction summary card
- `member_search/1` - Member search interface
- `item_search/1` - Item search interface
- `date_picker/1` - Date selection component
- `payment_form/1` - Payment processing form
- `fine_calculator/1` - Fine amount calculator

---

### VoileWeb.Dashboard.Circulation.Helpers

**Purpose:** Helper functions used across circulation modules

**Functions:**
- `calculate_due_date/2` - Calculate loan due date
- `calculate_fine/2` - Calculate overdue fine
- `format_currency/1` - Format money values
- `extract_error_message/1` - Extract changeset errors
- `get_id_from_member_identifier/1` - Parse member identifier
- `get_transaction_status/1` - Determine transaction status
- `can_renew?/1` - Check renewal eligibility
- `format_date_time/1` - Format timestamps

---

## Routes Reference

```elixir
# Circulation Dashboard
GET  /manage/circulation                               # Index

# Transactions
GET  /manage/circulation/transactions                  # Transaction.Index :index
GET  /manage/circulation/transactions/checkout         # Transaction.Index :checkout
GET  /manage/circulation/transactions/:id/return      # Transaction.Index :return
GET  /manage/circulation/transactions/:id/renew       # Transaction.Index :renew
GET  /manage/circulation/transactions/:id             # Transaction.Show :show

# Reservations
GET  /manage/circulation/reservations                  # Reservation.Index :index
GET  /manage/circulation/reservations/new              # Reservation.Index :new
GET  /manage/circulation/reservations/:id             # Reservation.Show :show

# Requisitions
GET  /manage/circulation/requisitions                  # Requisition.Index :index
GET  /manage/circulation/requisitions/new              # Requisition.Index :new
GET  /manage/circulation/requisitions/:id             # Requisition.Show :show
GET  /manage/circulation/requisitions/:id/edit        # Requisition.Index :edit

# Fines
GET  /manage/circulation/fines                         # Fine.Index :index
GET  /manage/circulation/fines/new                     # Fine.Index :new
GET  /manage/circulation/fines/:id                    # Fine.Show :show
GET  /manage/circulation/fines/:id/payment            # Fine.Show :payment
GET  /manage/circulation/fines/:id/waive              # Fine.Show :waive

# Circulation History
GET  /manage/circulation/circulation_history           # CirculationHistory.Index
GET  /manage/circulation/circulation_history/:id      # CirculationHistory.Show
```

## Database Schema

### Transaction

```elixir
schema "transactions" do
  field :checkout_date, :utc_datetime
  field :due_date, :utc_datetime
  field :return_date, :utc_datetime
  field :status, :string                  # active, returned, overdue
  field :renewal_count, :integer, default: 0
  field :notes, :text
  
  belongs_to :member, User
  belongs_to :item, Item
  belongs_to :checked_out_by, User       # Staff member who processed
  belongs_to :returned_by, User          # Staff member who processed return
  
  has_one :fine, Fine
  
  timestamps()
end
```

### Reservation

```elixir
schema "reservations" do
  field :reservation_date, :utc_datetime
  field :available_date, :utc_datetime
  field :expiration_date, :utc_datetime
  field :status, :string                  # pending, available, fulfilled, cancelled, expired
  field :pickup_deadline, :utc_datetime
  field :notes, :text
  
  belongs_to :member, User
  belongs_to :item, Item
  belongs_to :created_by, User
  belongs_to :fulfilled_by, User
  
  timestamps()
end
```

### Requisition

```elixir
schema "requisitions" do
  field :title, :string
  field :author, :string
  field :isbn, :string
  field :publisher, :string
  field :year, :integer
  field :type, :string                    # book, journal, media, other
  field :priority, :string                # low, medium, high, urgent
  field :status, :string                  # submitted, under_review, approved, ordered, received, rejected, cancelled
  field :justification, :text
  field :estimated_cost, :decimal
  field :notes, :text
  field :rejection_reason, :text
  
  belongs_to :requested_by, User
  belongs_to :reviewed_by, User
  belongs_to :collection, Collection      # Target collection (if approved)
  
  timestamps()
end
```

### Fine

```elixir
schema "fines" do
  field :amount, :decimal
  field :amount_paid, :decimal, default: Decimal.new("0")
  field :amount_remaining, :decimal
  field :fine_type, :string               # overdue, damage, lost, other
  field :status, :string                  # unpaid, paid, partially_paid, waived
  field :reason, :text
  field :waive_reason, :text
  field :payment_method, :string          # cash, card, check, online, credit
  field :payment_date, :utc_datetime
  field :payment_reference, :string
  
  belongs_to :member, User
  belongs_to :item, Item
  belongs_to :transaction, Transaction
  belongs_to :created_by, User
  belongs_to :waived_by, User
  
  timestamps()
end
```

## Business Rules

### Transaction Rules

1. **Checkout Eligibility:**
   - Member must not be suspended
   - Member fines must be below limit
   - Item must be available
   - Member must not exceed checkout limit

2. **Loan Periods:**
   - Regular: 14 days
   - Reference: 3 days
   - Reserved: 2 hours
   - Media: 7 days
   - Configurable by item type

3. **Renewal Rules:**
   - Maximum renewals: 3 times
   - Cannot renew if overdue
   - Cannot renew if reserved by another member
   - Each renewal extends by original loan period

4. **Overdue Policy:**
   - Grace period: 1 day
   - Daily fine rate: Configurable
   - Maximum fine per item: Configurable
   - Auto-suspend if fines exceed limit

### Reservation Rules

1. **Reservation Limits:**
   - Maximum active reservations per member: 5
   - Cannot reserve available items (checkout instead)
   - Priority: First-come, first-served

2. **Pickup Window:**
   - Default: 3 days after available notification
   - Configurable per library policy
   - Auto-expire if not picked up

3. **Fulfillment:**
   - Must create checkout transaction when picked up
   - Reservation removed from queue
   - Next reservation (if any) becomes active

### Fine Rules

1. **Calculation:**
   - Overdue: `days_late × daily_rate`
   - Damage: Manual assessment
   - Lost: Replacement cost + processing fee
   - Maximum fine cap applies

2. **Payment:**
   - Partial payments allowed
   - Track payment method
   - Generate receipts
   - Update member account balance

3. **Waiver:**
   - Requires authorization
   - Must provide reason
   - Logged for audit
   - Member account credited

## Integration Points

### With Catalog Module
- Items availability status
- Collection information
- Item details for display

### With Accounts Module
- Member eligibility checks
- Member information display
- Staff authorization for operations

### With Notification System (if implemented)
- Overdue reminders
- Reservation available notifications
- Fine payment reminders
- Receipt delivery

## Common Workflows

### Standard Checkout
1. Librarian scans/enters member ID
2. System validates member eligibility
3. Librarian scans item barcode
4. System checks item availability
5. System calculates due date
6. Transaction created
7. Receipt printed/emailed

### Standard Return
1. Librarian scans item barcode
2. System finds active transaction
3. If overdue: Calculate fine, display amount
4. If fine exists: Process payment
5. Mark transaction as returned
6. Check for reservations on this item
7. If reserved: Notify next person in queue
8. Receipt printed/emailed

### Process Reservation
1. Member requests item (online or in-person)
2. System creates reservation with "pending" status
3. When item returned: System checks reservations
4. First reservation marked "available"
5. Member notified (email/SMS)
6. Member has X days to pickup
7. Librarian processes pickup as regular checkout
8. Reservation marked "fulfilled"

## Performance Considerations

1. **Pagination:** All lists use pagination (default: 15 per page)
2. **Indexing:** Database indexes on frequently queried fields
3. **Eager Loading:** Strategic preloading of associations
4. **Caching:** Statistics cached with periodic refresh
5. **Background Jobs:** Fine calculations run asynchronously
6. **Real-time Updates:** LiveView for immediate feedback

## Security Considerations

- Staff authorization required for all operations
- Member privacy protected (GDPR compliant)
- Payment information encrypted
- Audit trail for all transactions
- Fine waiver requires elevated permissions
- Access logs maintained

## Reports Available

1. **Daily Circulation Report**
   - Checkouts today
   - Returns today
   - Overdue items
   - Fines collected

2. **Member Activity Report**
   - Most active members
   - Delinquent members
   - Outstanding fines by member

3. **Item Popularity Report**
   - Most borrowed items
   - Never borrowed items
   - Items on reserve

4. **Financial Report**
   - Fines collected
   - Fines outstanding
   - Fines waived
   - Revenue by period

## Testing Checklist

### Transactions
- [ ] Checkout available item
- [ ] Return item on time
- [ ] Return overdue item (fine calculated)
- [ ] Renew active loan
- [ ] Attempt checkout when ineligible
- [ ] Exceed checkout limit
- [ ] Multi-item checkout

### Reservations
- [ ] Create reservation for checked-out item
- [ ] Cancel reservation
- [ ] Mark reservation available
- [ ] Fulfill reservation (pickup)
- [ ] Reservation expires
- [ ] Queue management (multiple reservations)

### Fines
- [ ] Create manual fine
- [ ] Process full payment
- [ ] Process partial payment
- [ ] Waive fine with reason
- [ ] Generate fine report
- [ ] Apply fine to suspended member

### Requisitions
- [ ] Submit acquisition request
- [ ] Approve requisition
- [ ] Reject requisition
- [ ] Track order status
- [ ] Complete requisition workflow

## Configuration

Fine rates, loan periods, and other circulation policies are typically configured in:
- System settings
- Item type configurations
- Member type configurations
- Library policies table
