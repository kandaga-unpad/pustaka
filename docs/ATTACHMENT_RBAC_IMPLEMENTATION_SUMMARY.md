# Attachment RBAC Implementation Summary

## Overview
Implemented comprehensive Role-Based Access Control (RBAC) and embargo system for attachments in the Voile application.

## Features Implemented

### 1. Three Access Levels
- **Public**: Accessible to everyone (default)
- **Limited**: Accessible only to specific roles or users
- **Restricted**: Accessible only to super_admin users

### 2. Embargo System
- **Start Date**: Attachment becomes visible after this date
- **End Date**: Attachment stops being visible after this date
- Can set either, both, or neither
- Super admins bypass embargo restrictions

### 3. Role-Based Access
- Grant access to entire roles
- Supports multiple roles per attachment
- Efficient for managing large groups

### 4. User-Specific Access
- Grant access to individual users
- Tracks who granted the access and when
- Useful for temporary or guest access

### 5. Audit Trail
- Tracks who last modified access settings
- Tracks when access settings were modified
- User-specific access logs who granted access

## Files Created

### Migrations
- `20250819090901_add_rbac_to_attachments.exs`
  - Adds access control fields to attachments table
  - Creates attachment_role_access join table
  - Creates attachment_user_access join table
  - Adds appropriate indexes and constraints

### Schemas
- `lib/voile/schema/catalog/attachment_role_access.ex`
  - Junction table for attachment-role relationships
  
- `lib/voile/schema/catalog/attachment_user_access.ex`
  - Junction table for attachment-user relationships
  - Includes granted_by tracking

### Context
- `lib/voile/catalog/attachment_access.ex`
  - Comprehensive access control logic
  - Functions for checking permissions
  - Functions for granting/revoking access
  - Query helpers for filtering accessible attachments

### Tests
- `test/voile/catalog/attachment_access_test.exs`
  - Complete test coverage for all features
  - Examples of usage patterns

### Documentation
- `docs/ATTACHMENT_ACCESS_CONTROL.md`
  - Comprehensive guide with examples
  - Best practices and security considerations
  
- `docs/ATTACHMENT_ACCESS_QUICK_REFERENCE.md`
  - Common use cases with code snippets
  - Template and controller examples
  - Quick reference matrix

## Files Modified

### Updated Attachment Schema
- `lib/voile/schema/catalog/attachment.ex`
  - Added access_level field
  - Added embargo date fields
  - Added audit fields for access settings
  - Added relationships to role and user access tables
  - Added access_control_changeset/3
  - Added embargo date validation
  - Added query helpers for access filtering

## Database Schema Changes

### attachments table additions:
```sql
access_level VARCHAR DEFAULT 'public' NOT NULL
embargo_start_date TIMESTAMP
embargo_end_date TIMESTAMP
access_settings_updated_by_id UUID REFERENCES users(id)
access_settings_updated_at TIMESTAMP
```

### attachment_role_access table:
```sql
id UUID PRIMARY KEY
attachment_id UUID REFERENCES attachments(id) ON DELETE CASCADE
role_id INTEGER REFERENCES roles(id) ON DELETE CASCADE
inserted_at TIMESTAMP
updated_at TIMESTAMP
UNIQUE(attachment_id, role_id)
```

### attachment_user_access table:
```sql
id UUID PRIMARY KEY
attachment_id UUID REFERENCES attachments(id) ON DELETE CASCADE
user_id UUID REFERENCES users(id) ON DELETE CASCADE
granted_by_id UUID REFERENCES users(id)
granted_at TIMESTAMP NOT NULL
inserted_at TIMESTAMP
updated_at TIMESTAMP
UNIQUE(attachment_id, user_id)
```

## API Reference

### Main Functions

#### Check Access
```elixir
AttachmentAccess.can_access?(attachment, user)
# Returns: boolean
```

#### Update Access Settings
```elixir
AttachmentAccess.update_access_control(attachment, attrs, admin_user)
# Returns: {:ok, attachment} | {:error, changeset}
```

#### Grant Access
```elixir
AttachmentAccess.grant_role_access(attachment_id, role_id)
AttachmentAccess.grant_user_access(attachment_id, user_id, granted_by_id)
# Returns: {:ok, struct} | {:error, changeset}
```

#### Revoke Access
```elixir
AttachmentAccess.revoke_role_access(attachment_id, role_id)
AttachmentAccess.revoke_user_access(attachment_id, user_id)
# Returns: {count, nil}
```

#### Bulk Operations
```elixir
AttachmentAccess.bulk_grant_role_access(attachment_ids, role_id)
AttachmentAccess.bulk_grant_user_access(attachment_ids, user_id, granted_by_id)
# Returns: {count, nil}
```

#### Query Filtering
```elixir
Attachment
|> AttachmentAccess.accessible_by(user)
|> Repo.all()
```

#### Access Summary
```elixir
AttachmentAccess.get_access_summary(attachment)
# Returns: map with access details
```

## Usage Examples

### Public Document (Default)
```elixir
# Nothing special needed - public by default
attachment = create_attachment(%{...})
```

### Staff-Only Document
```elixir
attachment = create_attachment(%{access_level: "limited"})
AttachmentAccess.grant_role_access(attachment.id, staff_role.id)
```

### Embargoed Research Paper
```elixir
AttachmentAccess.update_access_control(
  attachment,
  %{
    access_level: "public",
    embargo_start_date: ~U[2025-12-01 00:00:00Z]
  },
  admin_user
)
```

### Temporary Guest Access
```elixir
attachment = create_attachment(%{access_level: "limited"})
AttachmentAccess.grant_user_access(attachment.id, guest_user.id, admin_user.id)
```

## Security Features

1. **Super Admin Override**: Super admins always have access
2. **Automatic Audit Trail**: Changes tracked with user and timestamp
3. **Database Constraints**: Invalid access levels prevented at DB level
4. **Embargo Validation**: Start date must be before end date
5. **Cascade Deletes**: Access grants automatically removed when attachment deleted
6. **No Direct Access**: All access through controlled functions

## Integration Points

### LiveView
```elixir
def mount(_params, _session, socket) do
  attachments = 
    Attachment
    |> AttachmentAccess.accessible_by(socket.assigns.current_scope.user)
    |> Repo.all()
  
  {:ok, assign(socket, attachments: attachments)}
end
```

### Controller
```elixir
def download(conn, %{"id" => id}) do
  attachment = Repo.get!(Attachment, id)
  
  if AttachmentAccess.can_access?(attachment, conn.assigns.current_scope.user) do
    send_file(conn, 200, attachment.file_path)
  else
    redirect(conn, to: ~p"/")
  end
end
```

## Migration Instructions

1. Run migration: `mix ecto.migrate`
2. Existing attachments default to "public" access
3. No data migration needed
4. System ready to use immediately

## Testing

Run the test suite:
```bash
mix test test/voile/catalog/attachment_access_test.exs
```

Tests cover:
- Public access
- Limited access (role-based)
- Limited access (user-specific)
- Restricted access
- Embargo functionality
- Super admin override
- Bulk operations
- Query filtering
- Access summary

## Future Enhancements (Optional)

1. **Access Request System**: Users can request access to limited content
2. **Expiring Access**: User-specific access that expires after N days
3. **Access Analytics**: Track who accessed what and when
4. **Notification System**: Alert users when embargo lifts
5. **Access Templates**: Pre-defined access patterns for common scenarios
6. **Download Limits**: Restrict number of downloads per user

## Support

- Full documentation: `docs/ATTACHMENT_ACCESS_CONTROL.md`
- Quick reference: `docs/ATTACHMENT_ACCESS_QUICK_REFERENCE.md`
- Test examples: `test/voile/catalog/attachment_access_test.exs`
- Code examples in all documentation files

## Compatibility

- Phoenix v1.8+
- Ecto 3.x
- PostgreSQL (uses UUID and JSONB types)
- Works with existing authentication system (phx.gen.auth)
