# Transfer Location Feature

## Overview

The Transfer Location feature enables librarians and staff to request and manage the transfer of items between different nodes (locations/faculties) within the system. This feature implements a request-and-approval workflow to ensure proper control over item movements.

## Key Components

### 1. Database Schema

**Table: `transfer_requests`**
- Stores all transfer requests with their status and details
- Tracks from/to locations and nodes
- Records who requested and who reviewed the transfer
- Maintains audit trail with timestamps

### 2. Transfer Request States

- **Pending**: Initial state when a transfer is requested
- **Approved**: Transfer has been reviewed and approved; item location is updated
- **Denied**: Transfer has been reviewed and rejected
- **Cancelled**: Requester cancelled their own pending request

## Workflow

### Creating a Transfer Request

1. **Who can request**: Any librarian with `transfer_requests.create` permission
2. **How to request**: 
   - From the collection show page, click "Transfer Location" button on any item card
   - Fill in the transfer form:
     - Select target node (required)
     - Enter target location (required)
     - Provide reason for transfer (required)
   - Submit the request

3. **What happens**:
   - A new transfer request is created with status "pending"
   - The request is recorded with the current item location
   - No changes are made to the item until approval

### Reviewing Transfer Requests

1. **Who can review**: Librarians assigned to the target node with `transfer_requests.review` permission
2. **Where to review**: Navigate to `/manage/transfers`
3. **Review process**:
   - View pending transfer requests filtered by your node
   - Click on a request to see full details
   - Add review notes (optional for approval, recommended for denial)
   - Choose to approve or deny

4. **What happens on approval**:
   - Transfer request status changes to "approved"
   - Item's `unit_id` and `location` fields are updated immediately
   - Approval timestamp and reviewer are recorded
   - Completion timestamp is set

5. **What happens on denial**:
   - Transfer request status changes to "denied"
   - Item location remains unchanged
   - Review notes and timestamp are recorded

### Managing Transfer Requests

**List View** (`/manage/transfers`)
- View all transfer requests
- Filter by:
  - Status (pending, approved, denied, cancelled)
  - Target node
- Default view shows pending requests for your node
- See requester, item details, and dates

**Detail View** (`/manage/transfers/:id`)
- Full request information
- Item details
- Transfer from/to information
- Request and review history
- Review interface (if you can review)

### Deleting Transfer Requests

- Only the requester can delete their own pending requests
- Approved, denied, or cancelled requests cannot be deleted (audit trail)

## Permissions

### Required Permissions

1. **transfer_requests.create** - Create new transfer requests
2. **transfer_requests.read** - View transfer requests
3. **transfer_requests.update** - Update transfer requests
4. **transfer_requests.delete** - Delete own pending requests
5. **transfer_requests.review** - Approve or deny transfer requests

### Role Assignments

- **super_admin**: All transfer permissions
- **librarian**: All transfer permissions (can request and review)
- **Other roles**: No transfer permissions by default

## Technical Implementation

### Schema

```elixir
defmodule Voile.Schema.Catalog.TransferRequest do
  # Fields:
  # - item_id: Item being transferred
  # - from_node_id: Current node
  # - to_node_id: Target node
  # - from_location: Current location description
  # - to_location: Target location description
  # - status: pending/approved/denied/cancelled
  # - reason: Why transfer is needed
  # - notes: Review notes
  # - requested_by_id: Who requested
  # - reviewed_by_id: Who reviewed
  # - reviewed_at: When reviewed
  # - completed_at: When transfer completed
end
```

### Context Functions

**Voile.Schema.Catalog**
- `list_transfer_requests/1` - List with filtering
- `get_transfer_request!/1` - Get single request
- `create_transfer_request/1` - Create new request
- `update_transfer_request/2` - Update request
- `approve_transfer_request/2` - Approve and execute transfer
- `deny_transfer_request/3` - Deny transfer
- `cancel_transfer_request/1` - Cancel request
- `list_pending_transfers_for_node/1` - Get pending for node
- `list_transfer_history_for_item/1` - Get item's history

### LiveView Modules

1. **TransferRequestLive.Index** - List and filter transfers
2. **TransferRequestLive.Show** - View and review transfers
3. **TransferRequestLive.FormComponent** - Create transfer requests

## Usage Examples

### As a Requester (Faculty of Science Librarian)

1. You notice an item should be moved to Faculty of Arts
2. Navigate to the collection containing the item
3. Click "Transfer Location" on the item card
4. Fill in the form:
   - Target Node: Faculty of Arts
   - Target Location: "Shelf A-12, Reading Room"
   - Reason: "This item is more relevant to Arts curriculum"
5. Submit request
6. Wait for Faculty of Arts librarian to review

### As a Reviewer (Faculty of Arts Librarian)

1. Navigate to Transfer Requests page (`/manage/transfers`)
2. See pending requests for your faculty (auto-filtered)
3. Click on a request to review details
4. Check if the transfer makes sense for your collection
5. Add notes if needed: "Accepted. We have space in the Arts reading room."
6. Click "Approve Transfer"
7. Item is now in your faculty's inventory

### Checking Transfer History

1. Navigate to an item's detail page
2. Use `Catalog.list_transfer_history_for_item(item_id)` in code
3. See all past transfer requests for this item

## Future Enhancements

Potential improvements to consider:

1. **Notifications**: Email notifications to reviewers when new requests arrive
2. **Bulk Transfers**: Transfer multiple items at once
3. **Transfer Templates**: Save common transfer destinations
4. **Scheduled Transfers**: Set future date for transfer execution
5. **Transfer Reports**: Analytics on transfer patterns
6. **Physical Transfer**: Track physical item movement with checkpoints
7. **Transfer Notes**: Allow adding tracking notes during physical transfer

## Troubleshooting

### "You cannot delete this transfer request"
- Only pending requests can be deleted, and only by the requester

### "You are not authorized to review this transfer"
- Only librarians assigned to the target node can review transfers to their node

### Transfer request created but item not moved
- Transfer doesn't execute until approved
- Check if request is still pending

### Cannot see transfer requests
- Check you have `transfer_requests.read` permission
- Check your node assignment matches the transfer target

## Database Migration

Run the migration to create the transfer_requests table:

```bash
mix ecto.migrate
```

## Seeding Permissions

To add transfer permissions to your database:

```bash
mix run priv/repo/seeds/authorization_seeds.ex
```

This will create the transfer permissions and assign them to appropriate roles.
