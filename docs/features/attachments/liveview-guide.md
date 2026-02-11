# Attachment Management LiveView

This document explains the LiveView interface for managing attachments and their access control.

## Location

All attachment management LiveViews are located in:
```
lib/voile_web/live/dashboard/catalog/attachment/
```

## Files

### 1. `index.ex` - Main Attachment List
The main LiveView that displays all attachments with filtering, search, and pagination.

**Features**:
- List all attachments with pagination (20 per page)
- Search by filename, original name, or description
- Filter by:
  - Access level (public, limited, restricted)
  - File type (document, image, video, etc.)
  - Attachable type (collection, item)
- View attachment statistics
- Quick actions: Manage access, Download, Delete
- Real-time updates when access is modified

### 2. `index.html.heex` - Main Template
The template for displaying the attachment list.

**Key sections**:
- Search bar with clear functionality
- Filter dropdowns
- Stats cards showing attachment counts by access level
- Responsive table with attachment details
- Pagination controls

### 3. `access_component.ex` - Access Management Component
LiveComponent for managing individual attachment access control.

**Features**:
- Update access level (public, limited, restricted)
- Set embargo start and end dates
- Manage role-based access (for limited attachments)
- Manage user-specific access (for limited attachments)
- Live user search with autocomplete
- Display access summary

### 4. `access_component.html.heex` - Access Component Template
The modal template for access management.

**Key sections**:
- File information display
- Access level selection with embargo dates
- Role selection checkboxes
- User search and management
- Access summary panel

## Routes

Added to `/manage/catalog/attachments`:

```elixir
scope "/attachments" do
  live "/", Dashboard.Catalog.Attachment.Index, :index
  live "/:id/access", Dashboard.Catalog.Attachment.Index, :manage_access
end
```

**URLs**:
- List: `http://localhost:4000/manage/catalog/attachments`
- Manage Access: `http://localhost:4000/manage/catalog/attachments/{id}/access`

## Permissions

The LiveView checks for these permissions:
- `attachments.read` - View attachments list
- `attachments.update` - Manage access control
- `attachments.delete` - Delete attachments

## Usage

### Accessing the Attachment Manager

1. Navigate to `/manage/catalog/attachments`
2. You'll see a list of all attachments in the system

### Searching and Filtering

**Search**:
- Type in the search box to find attachments by filename or description
- Press Enter or click the search icon
- Click the X to clear search

**Filters**:
- Use the dropdown menus to filter by:
  - Access Level
  - File Type
  - Attachable Type
- Click "Clear" to remove all filters

### Managing Access Control

1. Click the lock icon (🔒) on any attachment
2. A modal opens with access management options

**Access Level Options**:
- **Public**: Anyone can view (default)
- **Limited**: Only specific roles or users
- **Restricted**: Only super_admin

**Setting Embargos**:
1. Select embargo start date (available after)
2. Select embargo end date (available until)
3. Leave either blank for one-sided embargo
4. Click "Update Access Settings"

**Role-Based Access** (Limited only):
1. Check/uncheck roles that should have access
2. Changes apply immediately
3. Green badges show active roles

**User-Specific Access** (Limited only):
1. Type user email or name in search box
2. Click "Add" on the user you want to grant access
3. Click "Remove" to revoke access
4. Useful for guest access or temporary permissions

### Viewing Statistics

The dashboard shows:
- Total attachments
- Public attachments count
- Limited attachments count
- Restricted attachments count

### Downloading Attachments

Click the download icon (⬇️) to download any attachment.

### Deleting Attachments

1. Click the trash icon (🗑️)
2. Confirm the deletion
3. Attachment is permanently removed

## Features

### Real-Time Updates

The interface updates in real-time when:
- Access settings are changed
- Roles are added/removed
- Users are granted/revoked access

### Responsive Design

The interface works on:
- Desktop (full table view)
- Tablet (optimized layout)
- Mobile (stacked cards)

### Smart Filtering

Filters can be combined:
- Search + Access Level filter
- File Type + Attachable Type filter
- All filters work together

### Pagination

- 20 items per page
- Previous/Next navigation
- Page counter display

## Integration with Existing Features

### From Collection Management

Attachments can be viewed and managed from:
1. Collection detail page
2. Item detail page
3. Central attachment manager (this LiveView)

### Access Control Flow

```
Collection/Item → Upload Attachment → Set Initial Access
                                    ↓
                              Default: Public
                                    ↓
                    Staff → Manage Access (this LiveView)
                                    ↓
                    Update level, embargo, roles, users
```

## Developer Notes

### Adding New Filters

To add a new filter:

1. Add assign in `mount/3`:
   ```elixir
   |> assign(:filter_new_field, "")
   ```

2. Add to `build_filters_from_params/1`:
   ```elixir
   |> maybe_add_filter(:new_field, params["new_field"])
   ```

3. Add to query in `list_attachments_paginated/4`

4. Add dropdown in template

### Customizing Display

Edit `index.html.heex` to:
- Change columns displayed
- Modify stats cards
- Adjust pagination size
- Customize badges and icons

### Extending Access Component

Edit `access_component.ex` to:
- Add new access rules
- Customize validation
- Add bulk operations
- Extend audit logging

## Examples

### Example 1: Make Document Staff-Only

1. Find document in list
2. Click lock icon
3. Change access level to "Limited"
4. Check "staff" role
5. Click "Update Access Settings"

### Example 2: Set Publication Embargo

1. Find attachment
2. Click lock icon
3. Set access level to "Public"
4. Set embargo start date to publication date
5. Click "Update Access Settings"

### Example 3: Grant Guest Access

1. Find attachment
2. Click lock icon
3. Set access level to "Limited"
4. Search for guest user email
5. Click "Add" on the user
6. User now has access

## Troubleshooting

### Can't see attachments
- Check you have `attachments.read` permission
- Verify filters aren't too restrictive

### Can't modify access
- Requires `attachments.update` permission
- Contact admin if needed

### User search not working
- Type at least 2 characters
- Check spelling
- User must exist in system

### Changes not saving
- Check form validation errors
- Ensure embargo dates are valid (start < end)
- Check network connection

## Future Enhancements

Potential additions:
- Bulk access management
- Access request system
- Download analytics
- Access expiration dates
- Email notifications on embargo lift
- Access templates

## Support

For issues or questions:
1. Check this documentation
2. Review code comments
3. Test in development environment
4. Contact development team
