# Stock Opname / Inventory Check Feature Design

## Overview

Complete inventory checking system for collections and items with node-centric sessions, barcode scanning, review workflow, and admin approval mechanism.

## Business Flow

### 1. Session Creation (Super Admin Only)

- **Only Super Admin** can create a new stock opname session
- Admin selects:
  - Target node(s) for the session
  - Collection type(s) to include (gallery, archive, museum, library, etc.)
  - Specific collection or location (optional)
  - Title and description
- System generates expected item list based on:
  - Selected node(s)
  - Selected collection type(s)
  - Scope filters (collection/location if specified)
- Admin assigns librarians to the session
- Session status: `draft`
- Admin starts the session: `draft` → `in_progress`
- Email notification sent to assigned librarians

### 2. Item Scanning & Checking (Librarian)

- Assigned librarian scans items one by one using:
  - Barcode (primary)
  - Legacy item code (fallback for migrated items)
  - Manual search by item code
- **Duplicate Handling**:
  - If search returns multiple items (e.g., same barcode and legacy_item_code value), display all matches
  - Librarian selects the correct item from the list
  - No race condition: Transaction-based item locking during check-in
- For each scanned item:
  - Display item detail card with current data
  - Show editable fields using existing schema options:
    - Status: Use `Item.status_options/0`
    - Condition: Use `Item.condition_options/0`
    - Availability: Use `Item.availability_options/0`
  - Librarian confirms and marks as "checked"
  - Item added to session with before/after snapshot
- Real-time progress tracking: X of Y items checked (per librarian)
- Each librarian tracks their own work session progress

### 3. Session Completion (Librarian → Super Admin)

- **Librarian Work Session**:
  - When librarian finishes their assigned items, they mark their work session as "completed"
  - Librarian work session status tracked separately: `in_progress` → `completed`
  - Other librarians can continue working independently
- **Super Admin Oversight**:
  - Super admin monitors all librarians' progress
  - System provides function to check if all assigned librarians completed their work
  - Super admin reviews completion status
  - Super admin decides when to finalize the entire session
- **Smart Missing Item Detection**:
  - System only flags items as "missing" if they:
    1. Are in the selected node(s)
    2. Match the selected collection type(s)
    3. Match scope filters (collection/location if specified)
    4. Were NOT scanned during the session
  - Items outside the session scope are NOT flagged
- **Session Completion Flow**:
  - All librarians mark work sessions as completed
  - Super admin reviews completion
  - Super admin clicks "Complete Session"
  - System flags appropriate unscanned items as "missing"
  - Session status: `in_progress` → `pending_review`
  - Summary report generated showing:
    - Checked items count (by librarian and total)
    - Missing items count (within scope only)
    - Items with changes (condition, location, etc.)
  - Email notification sent to Super Admin (from settings context)

### 4. Admin Review & Approval (Super Admin/Manager)

- Super admin reviews completed sessions
- Views summary and detailed change list
- Can add notes for each item or session
- Decision options:
  - **Approve**: Apply all changes to main item/collection tables
  - **Reject**: Discard session, no changes applied
  - **Request Revision**: Send back to librarian
- Session status: `pending_review` → `approved` or `rejected`

### 5. Finalization

- Upon approval, system updates:
  - Item status, condition, availability, location (using values from schema options)
  - Missing items marked with appropriate status
  - Audit trail recorded (who, when, what changed)
- Session status: `approved`
- Session archived for historical record
- Email notification sent to Super Admin and assigned librarians

## Database Schema

### Table: `stock_opname_sessions`

```elixir
create table(:stock_opname_sessions, primary_key: false) do
  add :id, :binary_id, primary_key: true
  add :session_code, :string, null: false  # Auto-generated: "SO-2026-001"
  add :title, :string, null: false
  add :description, :text

  # Scope configuration
  add :node_ids, {:array, :integer}, null: false  # Multiple nodes can be selected
  add :collection_types, {:array, :string}, null: false  # gallery, archive, museum, library, etc.
  add :scope_type, :string, null: false  # "all", "collection", "location"
  add :scope_id, :string  # collection_id or location_id if scoped

  add :status, :string, null: false, default: "draft"
    # draft, in_progress, completed, pending_review, approved, rejected, cancelled

  # Timestamps
  add :started_at, :utc_datetime
  add :completed_at, :utc_datetime
  add :reviewed_at, :utc_datetime
  add :approved_at, :utc_datetime

  # Counters
  add :total_items, :integer, default: 0
  add :checked_items, :integer, default: 0
  add :missing_items, :integer, default: 0
  add :items_with_changes, :integer, default: 0

  # Notes & Review
  add :notes, :text
  add :review_notes, :text
  add :rejection_reason, :text

  # User tracking
  add :created_by_id, references(:users, type: :binary_id), null: false
  add :updated_by_id, references(:users, type: :binary_id)
  add :reviewed_by_id, references(:users, type: :binary_id)

  timestamps(type: :utc_datetime)
end

create unique_index(:stock_opname_sessions, [:session_code])
create index(:stock_opname_sessions, [:status])
create index(:stock_opname_sessions, [:created_by_id])
```

### Table: `stock_opname_librarian_assignments`

```elixir
create table(:stock_opname_librarian_assignments, primary_key: false) do
  add :id, :binary_id, primary_key: true
  add :session_id, references(:stock_opname_sessions, type: :binary_id, on_delete: :delete_all), null: false
  add :user_id, references(:users, type: :binary_id), null: false
  add :work_status, :string, null: false, default: "pending"
    # pending, in_progress, completed
  add :items_checked, :integer, default: 0
  add :started_at, :utc_datetime
  add :completed_at, :utc_datetime
  add :notes, :text

  timestamps(type: :utc_datetime)
end

create index(:stock_opname_librarian_assignments, [:session_id])
create index(:stock_opname_librarian_assignments, [:user_id])
create unique_index(:stock_opname_librarian_assignments, [:session_id, :user_id])
```

### Table: `stock_opname_items`

```elixir
create table(:stock_opname_items, primary_key: false) do
  add :id, :binary_id, primary_key: true
  add :session_id, references(:stock_opname_sessions, type: :binary_id, on_delete: :delete_all), null: false
  add :item_id, references(:items, type: :binary_id), null: false
  add :collection_id, references(:collections, type: :binary_id)

  # Snapshot of item data at scan time
  add :item_code, :string
  add :inventory_code, :string
  add :barcode, :string
  add :legacy_item_code, :string
  add :collection_title, :string

  # Before state (current in database)
  add :status_before, :string
  add :condition_before, :string
  add :availability_before, :string
  add :location_before, :string
  add :item_location_id_before, :integer

  # After state (as checked by librarian)
  add :status_after, :string
  add :condition_after, :string
  add :availability_after, :string
  add :location_after, :string
  add :item_location_id_after, :integer

  # Check result
  add :check_status, :string, null: false, default: "pending"
    # pending, checked, missing, needs_attention
  add :has_changes, :boolean, default: false
  add :notes, :text
  add :scanned_at, :utc_datetime
  add :checked_by_id, references(:users, type: :binary_id)

  timestamps(type: :utc_datetime)
end

create index(:stock_opname_items, [:session_id])
create index(:stock_opname_items, [:item_id])
create index(:stock_opname_items, [:check_status])
create unique_index(:stock_opname_items, [:session_id, :item_id])
```

## Context Functions (Voile.Schema.Catalog)

### Session Management

```elixir
# Create new session (Super Admin only)
create_stock_opname_session(attrs, admin_user)

# List sessions with filters (node, status, date range)
list_stock_opname_sessions(page, per_page, filters)

# Get session with all items and assignments preloaded
get_stock_opname_session!(id)

# Update session (Super Admin only)
update_stock_opname_session(session, attrs, admin_user)

# Assign librarians to session
assign_librarians_to_session(session, user_ids, admin_user)

# Start session (draft → in_progress, Super Admin only)
start_stock_opname_session(session, admin_user)

# Complete session (in_progress → pending_review, Super Admin only)
# Flags unscanned items as missing (within scope only)
complete_stock_opname_session(session, admin_user)

# Cancel session
cancel_stock_opname_session(session, admin_user)

# Check if all librarians completed their work
all_librarians_completed?(session)

# Get librarian work session status
get_librarian_work_status(session, user_id)
```

### Librarian Work Session

```elixir
# Start librarian's work session
start_librarian_work(session, user)

# Complete librarian's work session
complete_librarian_work(session, user, notes \\ nil)

# Get librarian's progress
get_librarian_progress(session, user)
```

### Item Checking

```elixir
# Search item by barcode/legacy_code/item_code in session context
# Returns list of matching items (handles duplicates)
find_items_for_scanning(session, search_term)

# Add item to session with snapshot (transaction-based, prevents race conditions)
add_item_to_session(session, item_id, user)

# Mark item as checked with optional updates
check_item_in_session(session, item_id, attrs, user)

# Get session progress statistics
get_session_statistics(session)

# Get items by check status
list_session_items(session, check_status \\ nil)
```

### Admin Review

```elixir
# List sessions pending review
list_sessions_pending_review(page, per_page)

# Get session review summary
get_session_review_summary(session)

# Approve session (apply all changes to main tables)
approve_stock_opname_session(session, admin_user, notes \\ nil)

# Reject session
reject_stock_opname_session(session, admin_user, reason)

# Request revision (send back to librarians)
request_session_revision(session, admin_user, notes)
```

### Email Notifications

```elixir
# Send notification to admin (get email from settings context)
send_admin_notification(session, event_type)

# Send notification to assigned librarians
send_librarian_notifications(session, event_type)
```

## LiveView Structure

### 1. `VoileWeb.Dashboard.StockOpnameLive.Index`

**Path**: `/dashboard/stock-opname`

**Features**:

- **For Librarians**: List sessions they're assigned to
- **For Super Admin**: List all sessions with filters
- Filter by status, date range, node
- Create new session button (Super Admin only)
- Session cards showing:
  - Session code, title, status
  - Progress: X/Y items checked
  - Librarian assignments and their progress
  - Created by, started date
  - Action buttons based on role and status

### 2. `VoileWeb.Dashboard.StockOpnameLive.New`

**Path**: `/dashboard/stock-opname/new` (Super Admin only)

**Features**:

- Form to create new session:
  - Title (required)
  - Description
  - **Node Selection**: Multi-select for nodes
  - **Collection Type Selection**: Checkboxes for types (gallery, archive, museum, library, etc.)
  - Scope selection: All items / Specific collection / Location
  - Librarian assignments: Multi-select users with librarian role
- Real-time item count preview based on selections
- Creates session and sends email notifications to assigned librarians

### 3. `VoileWeb.Dashboard.StockOpnameLive.Scan`

**Path**: `/dashboard/stock-opname/:id/scan`

**Features**:

- Large search input (auto-focus) for barcode scanning
- **Duplicate Item Handling**:
  - If multiple items match, display selection modal
  - Show all matching items with differentiating details
  - Librarian selects correct item
- Real-time progress bar: X of Y items checked (personal progress)
- Quick stats: Checked, Pending, Needs Attention
- Scanned item appears as card:
  - Item details (code, title, collection, current status/condition)
  - Editable fields with schema-based options:
    - Status dropdown: `Item.status_options/0`
    - Condition dropdown: `Item.condition_options/0`
    - Availability dropdown: `Item.availability_options/0`
  - Notes textarea
  - "Mark as Checked" button
- List of recently scanned items (LiveView streams)
- "Complete My Work" button (marks librarian's work session as completed)
- Cannot access if not assigned to session

### 4. `VoileWeb.Dashboard.StockOpnameLive.Show`

**Path**: `/dashboard/stock-opname/:id`

**Features**:

- Session details and scope information (nodes, collection types)
- Librarian assignments with individual progress
- Overall statistics
- Tabs:
  - **All Items**: Full list with filters
  - **Checked**: Items successfully scanned (grouped by librarian)
  - **Pending**: Items not yet scanned
  - **With Changes**: Items that have updates
- Export to CSV/Excel
- Action buttons based on role and status:
  - **Librarian**: Resume scanning (if assigned and in_progress)
  - **Super Admin**: Complete session (if all librarians done)
- View-only for completed sessions

### 5. `VoileWeb.Dashboard.StockOpnameLive.Review`

**Path**: `/dashboard/stock-opname/:id/review` (Super Admin only)

**Features**:

- Session summary card
- Change summary statistics
- Filterable list of all items with before/after comparison
- Highlight changed fields
- Approve/Reject buttons with notes
- Preview changes before applying

## Router Configuration

```elixir
# Inside :require_authenticated_user live_session
live "/dashboard/stock-opname", VoileWeb.Dashboard.StockOpnameLive.Index, :index
live "/dashboard/stock-opname/new", VoileWeb.Dashboard.StockOpnameLive.New, :new
live "/dashboard/stock-opname/:id", VoileWeb.Dashboard.StockOpnameLive.Show, :show
live "/dashboard/stock-opname/:id/scan", VoileWeb.Dashboard.StockOpnameLive.Scan, :scan
live "/dashboard/stock-opname/:id/review", VoileWeb.Dashboard.StockOpnameLive.Review, :review
```

## RBAC Integration

### Permission Checks

```elixir
# Super Admin permissions (use existing RBAC system)
can_create_session?(user)      # Check if user is super admin
can_start_session?(user)       # Check if user is super admin
can_complete_session?(user)    # Check if user is super admin
can_approve_session?(user)     # Check if user is super admin

# Librarian permissions
can_scan_items?(user, session) # Check if user is assigned to session
can_complete_work?(user, session) # Check if user is assigned and has scanned items

# View permissions
can_view_session?(user, session) # Assigned librarian or admin
```

### Role Detection

Use existing RBAC system to check:

- Super Admin: User has admin role/group
- Librarian: User has librarian role assigned
- Reference `Voile.Schema.Accounts` functions for role checks

## UI/UX Features

### Scanner Interface

- Auto-focus on search input after each scan
- Debounced search (300ms) for manual typing
- Success feedback: Green flash + sound (optional)
- Error feedback: Red flash + error message
- Keyboard shortcuts:
  - `Ctrl+Enter`: Quick mark as checked (no changes)
  - `Esc`: Clear search input
  - `Ctrl+F`: Focus search

### Item Detail Card

- Clean, card-based design
- Color-coded condition badges
- Side-by-side before/after comparison
- Quick action buttons
- Collapsible notes section

### Progress Tracking

- Animated progress bar
- Real-time counter updates via LiveView
- Milestone notifications (25%, 50%, 75%, 100%)

### Admin Review Interface

- Diff view for changes (highlight what changed)
- Batch approval option
- Export detailed report

## Node Isolation & Smart Scope

Each session configuration includes:

- **Multiple Nodes**: Array of node IDs to include in session
- **Collection Types**: Array of types (gallery, archive, museum, library)
- **Scope Filters**: Optional collection or location filters

### Missing Item Logic

An item is flagged as "missing" ONLY if:

1. Item's `unit_id` is in session's `node_ids` array
2. Item's collection type is in session's `collection_types` array
3. Item matches scope filters (if specified)
4. Item was NOT scanned during the session

This prevents false positives for items outside the session scope.

## Audit Trail

All changes tracked via:

- Session metadata (who created, who reviewed, when)
- Item-level tracking (who checked, when scanned)
- Before/after snapshots
- Session notes and review notes

## Suggested Improvements

1. **Barcode Scanning Hardware Support**

   - WebSocket integration for barcode scanners
   - Mobile app with camera scanning
   - Bluetooth scanner integration

2. **Batch Operations**

   - Bulk mark as checked (for obvious cases)
   - Import item list from CSV
   - Batch condition updates

3. **Reports & Analytics**

   - Historical stock opname trends
   - Missing item patterns by node/type
   - Condition degradation over time
   - Librarian performance metrics

4. **Photos**

   - Allow librarians to attach photos of damaged items
   - Before/after photos for condition changes
   - Image annotations

5. **Real-time Collaboration**

   - Live updates when other librarians scan items
   - Chat or notes between assigned librarians
   - Conflict resolution for simultaneous scans

6. **Mobile Optimization**
   - PWA for mobile scanning
   - Offline mode with sync
   - Native camera barcode scanning

## Email Notifications

All emails sent to admin address from Settings context:

### Events Triggering Emails

1. **Session Started**: Notify assigned librarians
2. **Librarian Completed Work**: Notify super admin
3. **Session Completed**: Notify super admin (ready for review)
4. **Session Approved**: Notify assigned librarians
5. **Session Rejected**: Notify assigned librarians with reason
6. **Revision Requested**: Notify assigned librarians

### Email Content

- Session code and title
- Status change information
- Action required (if any)
- Link to session
- Summary statistics (for completion emails)

## Implementation Order

1. ✅ Create migration files
2. ✅ Create schema modules
3. ✅ Implement context functions
4. ✅ Create session index LiveView
5. ✅ Create session creation LiveView
6. ✅ Create scanning interface LiveView
7. ✅ Create admin review LiveView
8. ✅ Add router routes
9. ✅ Add navigation links
10. ✅ Testing and refinement

---

Ready to implement? Let's build this feature step by step!
