# Attachment Access Control System

This document explains how to use the Role-Based Access Control (RBAC) and embargo system for attachments.

## Overview

The attachment system now supports three levels of access control:
- **Public**: Anyone can view (default)
- **Limited**: Only specific roles or users can view
- **Restricted**: Only super_admin can view

Additionally, attachments can have embargo dates that control when they become visible.

## Access Levels

### Public
Public attachments are visible to everyone, including anonymous users.

```elixir
attachment = Repo.get!(Attachment, attachment_id)
|> Ecto.Changeset.change(access_level: "public")
|> Repo.update!()
```

### Limited
Limited attachments require either:
1. Role-based access (user must have one of the specified roles)
2. User-specific access (user's ID must be in the allowed list)

```elixir
# Set as limited
{:ok, attachment} = AttachmentAccess.update_access_control(
  attachment,
  %{access_level: "limited"},
  admin_user
)

# Grant access to a role
AttachmentAccess.grant_role_access(attachment.id, role_id)

# Grant access to a specific user
AttachmentAccess.grant_user_access(attachment.id, user_id, granted_by_user_id)
```

### Restricted
Restricted attachments are only accessible to super_admin users.

```elixir
{:ok, attachment} = AttachmentAccess.update_access_control(
  attachment,
  %{access_level: "restricted"},
  admin_user
)
```

## Embargo System

Embargos control time-based access to attachments. You can set:
- **Start date**: Attachment becomes visible after this date
- **End date**: Attachment stops being visible after this date

### Setting Embargo Dates

```elixir
start_date = DateTime.utc_now() |> DateTime.add(7, :day)
end_date = DateTime.utc_now() |> DateTime.add(30, :day)

{:ok, attachment} = AttachmentAccess.update_access_control(
  attachment,
  %{
    embargo_start_date: start_date,
    embargo_end_date: end_date
  },
  admin_user
)
```

### Common Embargo Patterns

#### Make available after specific date
```elixir
# Available starting next week
start_date = ~U[2025-11-14 00:00:00Z]

AttachmentAccess.update_access_control(
  attachment,
  %{embargo_start_date: start_date, embargo_end_date: nil},
  admin_user
)
```

#### Make available until specific date
```elixir
# Available until end of month
end_date = ~U[2025-11-30 23:59:59Z]

AttachmentAccess.update_access_control(
  attachment,
  %{embargo_start_date: nil, embargo_end_date: end_date},
  admin_user
)
```

#### Make available during specific window
```elixir
# Available only during November 2025
start_date = ~U[2025-11-01 00:00:00Z]
end_date = ~U[2025-11-30 23:59:59Z]

AttachmentAccess.update_access_control(
  attachment,
  %{
    embargo_start_date: start_date,
    embargo_end_date: end_date
  },
  admin_user
)
```

## Checking Access

### Single Attachment
```elixir
if AttachmentAccess.can_access?(attachment, current_user) do
  # Show attachment
else
  # Show access denied message
end
```

### Filtering Query Results
```elixir
# Get all attachments the user can access
accessible_attachments = 
  Attachment
  |> Attachment.for_entity(collection_id, "collection")
  |> AttachmentAccess.accessible_by(current_user)
  |> Repo.all()
```

## Managing Access Lists

### Role-Based Access

```elixir
# Grant access to a role
{:ok, _} = AttachmentAccess.grant_role_access(attachment_id, role_id)

# Revoke access from a role
{1, _} = AttachmentAccess.revoke_role_access(attachment_id, role_id)

# List all roles with access
roles = AttachmentAccess.list_allowed_roles(attachment_id)

# Bulk grant to multiple attachments
AttachmentAccess.bulk_grant_role_access([id1, id2, id3], role_id)
```

### User-Specific Access

```elixir
# Grant access to a user
{:ok, _} = AttachmentAccess.grant_user_access(
  attachment_id,
  user_id,
  granted_by_user_id
)

# Revoke access from a user
{1, _} = AttachmentAccess.revoke_user_access(attachment_id, user_id)

# List all users with access
users = AttachmentAccess.list_allowed_users(attachment_id)

# Bulk grant to multiple attachments
AttachmentAccess.bulk_grant_user_access(
  [id1, id2, id3],
  user_id,
  granted_by_user_id
)
```

## Getting Access Summary

```elixir
summary = AttachmentAccess.get_access_summary(attachment)

# Returns:
# %{
#   access_level: "limited",
#   embargo_start_date: ~U[2025-11-01 00:00:00Z],
#   embargo_end_date: ~U[2025-11-30 23:59:59Z],
#   is_under_embargo: false,
#   allowed_roles: [%{id: "...", name: "staff"}],
#   allowed_users: [%{id: "...", email: "user@example.com", fullname: "John Doe"}],
#   last_updated_by: %{id: "...", email: "admin@example.com", fullname: "Admin User"},
#   last_updated_at: ~U[2025-11-07 10:30:00Z]
# }
```

## LiveView Integration Example

```elixir
defmodule MyAppWeb.AttachmentLive.Show do
  use MyAppWeb, :live_view
  alias Voile.Catalog.AttachmentAccess

  def mount(%{"id" => id}, _session, socket) do
    attachment = Repo.get!(Attachment, id) |> Repo.preload(:allowed_roles)
    current_user = socket.assigns.current_scope.user

    if AttachmentAccess.can_access?(attachment, current_user) do
      {:ok, assign(socket, attachment: attachment)}
    else
      {:ok, 
       socket
       |> put_flash(:error, "You don't have permission to view this attachment")
       |> redirect(to: ~p"/")}
    end
  end
end
```

## Controller Integration Example

> **Note:** the download controller should always perform an explicit
> permission check using `AttachmentAccess.can_access?/2`. this function
> checks not only the access level (public/limited/restricted) but also
> evaluates embargo start/end dates. without this guard users could
> bypass embargo windows by hitting the download URL directly.

```elixir
defmodule MyAppWeb.AttachmentController do
  use MyAppWeb, :controller
  alias Voile.Catalog.AttachmentAccess

  def download(conn, %{"id" => id}) do
    attachment = Repo.get!(Attachment, id)
    current_user = conn.assigns.current_scope[:user]

    if AttachmentAccess.can_access?(attachment, current_user) do
      # use whatever delivery mechanism your app prefers; we show
      # `send_download/2` from Phoenix as a shorthand.
      send_download(conn, {:file, attachment.file_path}, filename: attachment.original_name)
    else
      conn
      |> put_status(:forbidden)
      |> put_flash(:error, "Access denied")
      |> redirect(to: ~p"/")
    end
  end
end
```

## Database Schema

### attachments table additions
- `access_level`: "public" | "limited" | "restricted"
- `embargo_start_date`: when attachment becomes visible
- `embargo_end_date`: when attachment stops being visible
- `access_settings_updated_by_id`: who last modified access settings
- `access_settings_updated_at`: when access settings were last modified

### attachment_role_access table
Links attachments to roles for limited access.

### attachment_user_access table
Links attachments to specific users for limited access.

## Migration

Run the migration to add RBAC support:

```bash
mix ecto.migrate
```

This will add the new fields and tables for access control.

## Best Practices

1. **Default to public**: Unless there's a specific reason, keep attachments public
2. **Use roles over users**: Role-based access is easier to manage at scale
3. **Track changes**: Access control changes are automatically tracked with user ID and timestamp
4. **Super admin override**: Super admins always have access, useful for system maintenance
5. **Test thoroughly**: Use the provided test suite as examples for your own tests
6. **Preload associations**: When checking access for multiple attachments, preload roles to avoid N+1 queries

## Security Considerations

- Always check `can_access?/2` before serving file content
- Embargo dates are checked server-side; don't rely on client-side filtering
- Super admin role name must be exactly "super_admin"
- Access grants are logged with who granted them and when
- Revoking access is immediate and doesn't require additional cleanup
