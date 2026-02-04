# Stock Opname Librarian Work Completion Feature

## Overview

This feature allows administrators to manage and track librarian work completion status in stock opname sessions. Librarians can mark their work as completed, and administrators can view reports, manually complete work, or reopen completed sessions.

## Features

### 1. Librarian Work Completion with Confirmation

When librarians finish scanning items, they can mark their work as completed:

- **Confirmation Modal**: Before completing work, librarians see a confirmation modal warning them that they won't be able to scan more items after completion.
- **Status Change**: Once confirmed, their work status changes from "in_progress" to "completed".
- **Scan Prevention**: Completed librarians cannot access the scanning interface unless an admin reopens their session.

### 2. Admin Librarian Reports Page

A dedicated admin page (`/manage/stock_opname/report`) shows all sessions and librarian work status:

#### Report Features:
- **Session List**: Displays all stock opname sessions with expandable details
- **Pagination**: Sessions are paginated (10 per page) with previous/next navigation
- **Librarian Details**: Shows each librarian's work status including:
  - Name/Email
  - Items checked count
  - Work status (pending/in_progress/completed)
  - Started and completed timestamps
  - Notes (if any)
- **Admin Operations**:
  - **Complete Work**: Manually mark a librarian's work as completed
  - **Reopen Work**: Cancel completion and allow librarian to scan again

### 3. Scan Prevention After Completion

When a librarian's work is completed:
- They are automatically redirected from the scan page
- A flash message informs them to contact an admin to reopen
- The session must be reopened by an admin before they can scan again

## Database Schema

The `stock_opname_librarian_assignments` table tracks work status:

```elixir
field :work_status, :string, default: "pending"
# Values: "pending" | "in_progress" | "completed"

field :items_checked, :integer, default: 0
field :started_at, :utc_datetime
field :completed_at, :utc_datetime
field :notes, :string
```

## Context Functions

### `StockOpname.complete_librarian_work/3`

Marks a librarian's work as completed (called by the librarian).

```elixir
StockOpname.complete_librarian_work(session, user, notes \\ nil)
```

**Parameters:**
- `session`: The stock opname session struct
- `user`: The librarian user struct
- `notes`: Optional completion notes

**Returns:** `{:ok, assignment}` or `{:error, reason}`

### `StockOpname.cancel_librarian_completion/2`

Reopens a completed librarian session (admin only).

```elixir
StockOpname.cancel_librarian_completion(session, user)
```

**Parameters:**
- `session`: The stock opname session struct
- `user`: The librarian user struct

**Returns:** `{:ok, assignment}` or `{:error, reason}`

### `StockOpname.admin_complete_librarian_work/3`

Manually completes a librarian's work (admin only).

```elixir
StockOpname.admin_complete_librarian_work(session, user, notes \\ nil)
```

**Parameters:**
- `session`: The stock opname session struct
- `user`: The librarian user struct
- `notes`: Optional completion notes

**Returns:** `{:ok, assignment}` or `{:error, reason}`

### `StockOpname.get_session_librarian_report/1`

Gets detailed work report for all librarians in a session.

```elixir
StockOpname.get_session_librarian_report(session)
```

**Parameters:**
- `session`: The stock opname session struct

**Returns:** List of maps containing:
```elixir
%{
  assignment: %LibrarianAssignment{},
  items_checked: integer(),
  user: %User{}
}
```

## User Flow

### Librarian Completing Work

1. Librarian finishes scanning items in a session
2. Clicks "Complete Work" button on scan page
3. Confirmation modal appears (using core components modal) with warning message
4. Librarian can:
   - Click "Cancel" or press ESC to dismiss
   - Click outside modal to dismiss
   - Click "Yes, Complete Work" to confirm
5. If confirmed:
   - Work status changes to "completed"
   - `completed_at` timestamp is recorded
   - Librarian is redirected to session show page
6. If librarian tries to access scan page again:
   - Redirected with error message
   - Must contact admin to reopen session

### Admin Managing Completion

1. Admin navigates to `/manage/stock_opname/report`
2. Views paginated list of sessions (10 per page)
3. Uses pagination controls to navigate through sessions if needed
4. Clicks on a session to expand librarian details
5. For each librarian, admin can:
   - **If not completed**: Click "Complete" to manually mark as done
   - **If completed**: Click "Reopen" to cancel completion
6. Actions are confirmed before execution
7. Report updates in real-time after each action

## Routes

```elixir
# Librarian scanning (checks completion status)
GET /manage/stock_opname/:id/scan

# Admin librarian reports
GET /manage/stock_opname/report
```

## LiveView Events

### Scan Page (`scan.ex`)

- `confirm_complete_work` - Completes the work and redirects

**Note:** The modal is controlled entirely by JS commands, no event handlers needed for show/hide.

**Modal Implementation:**
```heex
<!-- Trigger Button -->
<button
  type="button"
  phx-click={show_modal("complete-work-modal")}
  class="px-4 sm:px-6 py-2 sm:py-3 bg-blue-600 hover:bg-blue-700 text-white font-medium rounded-lg transition-colors touch-manipulation"
>
  <.icon name="hero-check-circle" class="w-5 h-5 inline mr-1 sm:mr-2" /> Complete Work
</button>

<!-- Modal -->
<.modal
  id="complete-work-modal"
  show={false}
  on_cancel={hide_modal("complete-work-modal")}
>
  <!-- Modal content with cancel and confirm buttons -->
</.modal>
```

### Report Page (`report.ex`)

- `toggle_session` - Expands/collapses session details
- `complete_work` - Admin manually completes librarian work
- `reopen_work` - Admin reopens completed work

## Authorization

- **Scan Page**: Only assigned librarians or super admins can access
- **Report Page**: Only super admins can access
- **Complete Work**: Librarians can complete their own work
- **Reopen/Manual Complete**: Only super admins can perform these actions

## UI Components

### Work Status Badge

Displays librarian work status with appropriate colors:
- **Pending**: Gray badge with clock icon
- **In Progress**: Blue badge with arrow-path icon
- **Completed**: Green badge with check-circle icon

### Confirmation Modal

A modal dialog that:
- Uses the `<.modal>` component from `core_components.ex`
- Controlled entirely by JS commands (`show_modal` / `hide_modal`)
- No LiveView assigns needed for visibility state
- Warns about consequences of completion
- Prevents accidental completion
- Provides cancel option (using `hide_modal` JS command)
- Uses accessible design patterns (ARIA labels, focus management)
- Supports keyboard navigation (ESC to close, click-outside to dismiss)

## Best Practices

1. **Always show confirmation** before completing work
2. **Use JS-controlled modals** for better performance (no LiveView round-trips)
3. **Check work status** in mount to prevent access after completion
4. **Update reports in real-time** after admin actions
5. **Log completion events** for audit trail
6. **Provide clear feedback** to users about completion status

## Testing

Test scenarios to cover:

1. **Librarian completion flow**:
   - Can complete work when items are scanned
   - Confirmation modal appears and works
   - Cannot access scan page after completion

2. **Admin operations**:
   - Can view all sessions and librarians
   - Can manually complete librarian work
   - Can reopen completed work
   - Reports update after actions

3. **Edge cases**:
   - Super admin scanning without assignment
   - Librarian with no items checked
   - Multiple sessions and librarians
   - Concurrent completion attempts
   - Pagination with many sessions

## Related Documentation

- [STOCK_OPNAME_DESIGN.md](./STOCK_OPNAME_DESIGN.md)
- [STOCK_OPNAME_IMPLEMENTATION_SUMMARY.md](./STOCK_OPNAME_IMPLEMENTATION_SUMMARY.md)
- [STOCK_OPNAME_QUICK_REFERENCE.md](./STOCK_OPNAME_QUICK_REFERENCE.md)

## Future Enhancements

- Email notifications when work is completed
- Completion statistics and analytics
- Bulk completion operations
- Completion history and audit log
- Custom completion notes and comments
- Advanced filtering for sessions (status, date range, etc.)
- Export reports to CSV/PDF