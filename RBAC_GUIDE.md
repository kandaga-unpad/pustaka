# RBAC System Documentation

## Overview

This application uses a comprehensive Role-Based Access Control (RBAC) system that supports:

- **Global permissions**: Apply system-wide
- **Scoped permissions**: Apply to specific resources (collections, items)
- **Role-based permissions**: Permissions granted through roles
- **Direct permissions**: Permissions granted directly to users (can override role permissions)
- **Permission denials**: Explicitly deny permissions (overrides role permissions)
- **Time-based permissions**: Permissions that expire after a certain date

## Architecture

### Schema Structure

```
User
├── UserRoleAssignment (join table)
│   └── Role
│       └── RolePermission (join table)
│           └── Permission
├── UserPermission (direct permissions, including denies)
│   └── Permission
└── CollectionPermission (collection-specific permissions)
    └── Collection
```

### Permission Hierarchy

1. **Explicit user denials** (highest priority)
2. **Explicit user grants**
3. **Role-based permissions**
4. **Collection-specific permissions** (lowest priority)

## Usage in LiveViews

### 1. Require Authentication Only

```elixir
live_session :authenticated,
  on_mount: [{VoileWeb.UserAuth, :require_authenticated}] do
  live "/profile", ProfileLive, :index
end
```

### 2. Require Global Permission

```elixir
live_session :admin_only,
  on_mount: [
    {VoileWeb.UserAuth, :require_authenticated},
    {VoileWeb.UserAuth, {:require_permission, "system.settings"}}
  ] do
  live "/admin/settings", AdminSettingsLive, :index
end
```

### 3. Require Scoped Permission

```elixir
live_session :collection_manager,
  on_mount: [
    {VoileWeb.UserAuth, :require_authenticated},
    {VoileWeb.UserAuth, {:require_permission, "collections.update", scope: {:collection, :id}}}
  ] do
  live "/collections/:id/edit", CollectionEditLive, :edit
end
```

### 4. Check Permission in LiveView Code

```elixir
defmodule VoileWeb.CollectionLive do
  use VoileWeb, :live_view
  
  # Authorization helpers are automatically imported
  
  def mount(_params, _session, socket) do
    if can?(socket, "collections.create") do
      {:ok, socket}
    else
      {:ok, redirect(socket, to: "/")}
    end
  end
  
  def handle_event("delete", %{"id" => id}, socket) do
    # Authorize and raise on failure
    authorize!(socket, "collections.delete", scope: {:collection, id})
    
    # Proceed with deletion
    {:noreply, socket}
  end
end
```

### 5. Conditional UI Rendering

```heex
<%= if can?(@socket, "collections.create") do %>
  <.button phx-click="new_collection">Create Collection</.button>
<% end %>

<%= if can?(@socket, "items.delete", scope: {:item, @item.id}) do %>
  <.button phx-click="delete" phx-value-id={@item.id}>Delete</.button>
<% end %>
```

## Usage in Controllers

### 1. Use Authorization Plug

```elixir
defmodule VoileWeb.CollectionController do
  use VoileWeb, :controller
  
  # Require permission for all actions
  plug VoileWeb.Plugs.Authorization, 
    permission: "collections.read"
  
  # Require permission for specific actions
  plug VoileWeb.Plugs.Authorization,
    permission: "collections.update"
    when action in [:edit, :update]
  
  # Scoped permission (gets ID from params)
  plug VoileWeb.Plugs.Authorization,
    permission: "collections.delete",
    scope: {:collection, :id}
    when action in [:delete]
    
  def index(conn, _params), do: render(conn, :index)
end
```

### 2. Check Permission in Controller Code

```elixir
defmodule VoileWeb.ItemController do
  use VoileWeb, :controller
  
  def update(conn, %{"id" => id} = params) do
    # Check permission
    if can?(conn, "items.update", scope: {:item, id}) do
      # Proceed with update
    else
      conn
      |> put_flash(:error, "Insufficient permissions")
      |> redirect(to: ~p"/")
    end
  end
  
  def delete(conn, %{"id" => id}) do
    # Authorize or raise
    authorize!(conn, "items.delete", scope: {:item, id})
    
    # Proceed with deletion
  end
end
```

## Helper Functions

The following helpers are automatically imported in all LiveViews and Controllers:

### `can?(socket_or_conn, permission, opts \\ [])`

Check if the current user has a permission. Returns `true` or `false`.

```elixir
can?(socket, "collections.create")
can?(conn, "items.delete", scope: {:item, item_id})
```

### `authorize!(socket_or_conn, permission, opts \\ [])`

Check permission and raise `VoileWeb.Auth.Authorization.UnauthorizedError` if denied.

```elixir
authorize!(socket, "collections.update", scope: {:collection, id})
```

### `current_user(socket_or_conn)`

Get the current authenticated user or `nil`.

```elixir
user = current_user(socket)
```

### `authenticated?(socket_or_conn)`

Check if a user is authenticated. Returns `true` or `false`.

```elixir
if authenticated?(socket) do
  # User is logged in
end
```

### `require_all_permissions(socket_or_conn, permissions, opts \\ [])`

Check if user has ALL listed permissions.

```elixir
require_all_permissions(socket, [
  "collections.update",
  "items.delete"
])
```

### `require_any_permission(socket_or_conn, permissions, opts \\ [])`

Check if user has ANY of the listed permissions.

```elixir
require_any_permission(socket, [
  "collections.update",
  "collections.publish"
])
```

## Managing Permissions Programmatically

### Assign a Role to a User

```elixir
alias VoileWeb.Auth.Authorization

# Global role
Authorization.assign_role(user_id, role_id)

# Scoped role (collection-level)
Authorization.assign_role(user_id, role_id,
  scope_type: "collection",
  scope_id: collection_id,
  assigned_by_id: admin_user_id
)

# Temporary role (expires)
Authorization.assign_role(user_id, role_id,
  expires_at: ~U[2025-12-31 23:59:59Z]
)
```

### Grant Direct Permission

```elixir
# Grant permission
Authorization.grant_permission(user_id, permission_id,
  scope_type: "global"
)

# Scoped permission
Authorization.grant_permission(user_id, permission_id,
  scope_type: "collection",
  scope_id: collection_id
)
```

### Deny Permission

```elixir
# Explicitly deny a permission (overrides role permissions)
Authorization.deny_permission(user_id, permission_id,
  scope_type: "global"
)
```

### Revoke Role

```elixir
Authorization.revoke_role(user_id, role_id,
  scope_type: "global"
)
```

## Default Permissions

The system comes with pre-defined permissions:

### Collection Permissions
- `collections.create` - Create new collections
- `collections.read` - View collections
- `collections.update` - Edit collections
- `collections.delete` - Delete collections
- `collections.publish` - Publish collections
- `collections.archive` - Archive collections

### Item Permissions
- `items.create` - Create new items
- `items.read` - View items
- `items.update` - Edit items
- `items.delete` - Delete items
- `items.export` - Export items
- `items.import` - Import items

### Metadata Permissions
- `metadata.edit` - Edit metadata fields
- `metadata.manage` - Manage metadata schemas

### User Management
- `users.create` - Create new users
- `users.read` - View users
- `users.update` - Edit users
- `users.delete` - Delete users
- `users.manage_roles` - Manage user roles

### Role Management
- `roles.create` - Create new roles
- `roles.update` - Edit roles
- `roles.delete` - Delete roles
- `permissions.manage` - Manage permissions

### System Permissions
- `system.settings` - Manage system settings
- `system.audit` - View audit logs
- `system.backup` - Perform system backups

## Default Roles

### super_admin
Full system access with all permissions.

### admin
Administrative access without system settings.

### editor
Can manage collections and items.

### contributor
Can create and edit own content.

### viewer
Read-only access to collections and items.

## Seeding Data

To seed default permissions and roles:

```elixir
alias VoileWeb.Auth.PermissionManager

# Seed permissions
PermissionManager.seed_default_permissions()

# Seed roles
PermissionManager.seed_default_roles()
```

Or run the authorization seeds file:

```bash
mix run priv/repo/seeds/authorization_seeds.ex
```

## Migration Guide

If you're upgrading from the old hardcoded authorization:

### Before (Hardcoded User Type Check):

```elixir
def on_mount(:require_authenticated_and_verified_staff_user, _params, session, socket) do
  socket = mount_current_scope(socket, session)

  if socket.assigns.current_scope && socket.assigns.current_scope.user do
    user = socket.assigns.current_scope.user

    case user.user_type do
      %{slug: slug} when slug in ["administrator", "staff"] ->
        {:cont, socket}
      _ ->
        # deny access
    end
  end
end
```

### After (RBAC):

```elixir
live_session :admin_area,
  on_mount: [
    {VoileWeb.UserAuth, :require_authenticated},
    {VoileWeb.UserAuth, {:require_permission, "system.settings"}}
  ] do
  # admin routes
end
```

Or use the helper in the LiveView:

```elixir
def mount(_params, _session, socket) do
  if require_any_permission(socket, ["system.settings", "users.manage_roles"]) do
    {:ok, socket}
  else
    {:ok, redirect(socket, to: "/")}
  end
end
```

## Best Practices

1. **Use scoped permissions** for resource-specific actions
2. **Use on_mount callbacks** for route-level authorization in LiveViews
3. **Use plugs** for controller-level authorization
4. **Check permissions in event handlers** for granular control
5. **Use helper functions** instead of directly calling Authorization module
6. **Seed permissions early** in development to establish access patterns
7. **Document custom permissions** in your team's documentation
8. **Audit permission changes** in production environments

## Performance Considerations

- Permission checks are cached per request/socket lifecycle
- Use `preload` when fetching users to reduce database queries
- Consider adding database indexes on frequently queried permission fields
- The current implementation uses `Repo.exists?` for efficient permission checks

## Security Notes

- Permission denials always take precedence over grants
- Expired permissions are automatically ignored
- Scoped permissions do not inherit from global permissions (explicit is better)
- Always check permissions before performing sensitive operations
- Consider logging permission checks for audit trails
