# Authorization System

A comprehensive Role-Based Access Control (RBAC) system with support for scoped permissions.

## Overview

The authorization system provides:

- **Role-Based Permissions**: Assign permissions to roles and roles to users
- **Direct User Permissions**: Grant or deny specific permissions to individual users
- **Scoped Permissions**: Apply permissions globally or to specific resources (collections, items)
- **Permission Hierarchy**: Explicit denials override role-based grants
- **Time-Based Permissions**: Support for expiring permissions and role assignments
- **Collection-Level Permissions**: Fine-grained control over collection access (owner, editor, viewer)

## Architecture

### Core Modules

- `VoileWeb.Auth.Authorization` - Core authorization logic
- `VoileWeb.Auth.ControllerHelpers` - Helpers for Phoenix controllers
- `VoileWeb.Auth.LiveHelpers` - Helpers for Phoenix LiveView
- `VoileWeb.Auth.PermissionManager` - Manage roles and permissions
- `VoileWeb.Plugs.Authorization` - Plug for controller-wide authorization

### Database Schema

```
users
  └─ user_role_assignments (with scope and expiry)
       └─ roles
            └─ role_permissions
                 └─ permissions
  └─ user_permissions (direct grants/denials with scope and expiry)
       └─ permissions
  └─ collection_permissions (collection-level access)
       └─ collections
```

## Usage Examples

### Using the Authorization Plug

For controller-wide authorization, use the plug:

```elixir
defmodule VoileWeb.CollectionController do
  use VoileWeb, :controller

  # Require permission for all actions
  plug VoileWeb.Plugs.Authorization, permission: "collections.read"

  # Require permission for specific actions
  plug VoileWeb.Plugs.Authorization,
    permission: "collections.update"
    when action in [:edit, :update]

  # Require scoped permission (gets ID from params)
  plug VoileWeb.Plugs.Authorization,
    permission: "collections.delete",
    scope: {:collection, :id}
    when action in [:delete]

  def index(conn, _params) do
    # User already authorized by plug
    render(conn, :index)
  end
end
```

### In Controllers (Manual Checks)

```elixir
defmodule VoileWeb.CollectionController do
  use VoileWeb, :controller
  import VoileWeb.Auth.ControllerHelpers

  def edit(conn, %{"id" => id}) do
    # Authorize or raise error
    authorize!(conn, "collections.update", scope: {:collection, id})
    
    # ... rest of action
  end

  def delete(conn, %{"id" => id}) do
    # Check permission conditionally
    if can?(conn, "collections.delete", scope: {:collection, id}) do
      # ... perform deletion
    else
      conn
      |> put_flash(:error, "You don't have permission to delete this collection")
      |> redirect(to: ~p"/collections")
    end
  end
end
```

### In LiveView

```elixir
defmodule VoileWeb.CollectionLive.Show do
  use VoileWeb, :live_view
  import VoileWeb.Auth.LiveHelpers

  def mount(%{"id" => id}, _session, socket) do
    # Authorize on mount
    socket = authorize!(socket, "collections.read", scope: {:collection, id})
    
    # Assign permissions for template use
    socket = assign_permissions(socket, id)
    
    {:ok, socket}
  end

  def handle_event("delete", _params, socket) do
    case authorize(socket, "collections.delete", scope: {:collection, @collection.id}) do
      {:ok, socket} ->
        # ... perform deletion
        {:noreply, socket}
      
      {:error, reason} ->
        {:noreply, put_flash(socket, :error, reason)}
    end
  end
end
```

### In Templates

```heex
<%= if can?(@socket, "collections.update", scope: {:collection, @collection.id}) do %>
  <.button navigate={~p"/collections/#{@collection.id}/edit"}>
    Edit Collection
  </.button>
<% end %>

<!-- Or using pre-assigned permissions -->
<%= if @permissions.can_delete do %>
  <.button phx-click="delete" data-confirm="Are you sure?">
    Delete Collection
  </.button>
<% end %>
```

## Permission Naming Convention

Permissions follow the format: `resource.action`

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

### User Management Permissions
- `users.create` - Create new users
- `users.read` - View users
- `users.update` - Edit users
- `users.delete` - Delete users
- `users.manage_roles` - Manage user roles

### System Permissions
- `system.settings` - Manage system settings
- `system.audit` - View audit logs
- `system.backup` - Perform system backups

## Permission Scopes

### Global Scope
Applies everywhere in the system:

```elixir
Authorization.can?(user, "collections.create")
# or explicitly:
Authorization.can?(user, "collections.create", scope: :global)
```

### Collection Scope
Applies to a specific collection:

```elixir
Authorization.can?(user, "items.update", scope: {:collection, collection_id})
```

### Item Scope
Applies to a specific item:

```elixir
Authorization.can?(user, "items.delete", scope: {:item, item_id})
```

## Default Roles

### Super Admin
Full system access with all permissions.

### Admin
Administrative access without system settings.

### Editor
Can manage collections and items:
- Create, read, update collections
- Full CRUD on items
- Edit metadata
- Export/import items

### Contributor
Can create and edit own content:
- Read collections
- Create, read, update own items
- Export items

### Viewer
Read-only access:
- Read collections
- Read items
- Export items

## Collection-Level Permissions

In addition to role-based permissions, users can be granted collection-specific access:

### Owner Level
- Full control over collection
- Can delete collection and items
- Maps to: `collections.delete`, `items.delete`

### Editor Level
- Can modify collection and items
- Cannot delete
- Maps to: `collections.update`, `items.update`, `items.create`, `metadata.edit`

### Viewer Level
- Read-only access
- Can export data
- Maps to: `collections.read`, `items.read`, `items.export`

## Managing Permissions

### Seeding Default Permissions and Roles

```elixir
# In seeds.exs or migration
alias VoileWeb.Auth.PermissionManager

# Create all default permissions
PermissionManager.seed_default_permissions()

# Create all default roles with associated permissions
PermissionManager.seed_default_roles()
```

### Assigning Roles to Users

```elixir
alias VoileWeb.Auth.Authorization

# Global role assignment
{:ok, assignment} = Authorization.assign_role(user_id, role_id)

# Scoped role assignment (e.g., editor for specific collection)
{:ok, assignment} = Authorization.assign_role(
  user_id,
  role_id,
  scope_type: "collection",
  scope_id: collection_id
)

# Temporary role assignment (expires after 30 days)
{:ok, assignment} = Authorization.assign_role(
  user_id,
  role_id,
  expires_at: DateTime.utc_now() |> DateTime.add(30, :day)
)
```

### Granting Direct Permissions

```elixir
# Grant a specific permission
{:ok, user_perm} = Authorization.grant_permission(user_id, permission_id)

# Grant scoped permission
{:ok, user_perm} = Authorization.grant_permission(
  user_id,
  permission_id,
  scope_type: "collection",
  scope_id: collection_id
)

# Explicitly deny a permission (overrides role permissions)
{:ok, user_perm} = Authorization.deny_permission(user_id, permission_id)
```

### Revoking Access

```elixir
# Revoke a role assignment
Authorization.revoke_role(user_id, role_id)

# Revoke a scoped role
Authorization.revoke_role(
  user_id,
  role_id,
  scope_type: "collection",
  scope_id: collection_id
)
```

### Querying Permissions

```elixir
# Get all permissions for a user
permissions = Authorization.get_user_permissions(user_id)

# Get user's roles
role_assignments = PermissionManager.list_user_roles(user_id)

# Get direct permissions
user_permissions = PermissionManager.list_user_direct_permissions(user_id)

# Check if user can perform action
can_edit = Authorization.can?(user, "collections.update", scope: {:collection, id})
```

## Permission Resolution Order

When checking permissions, the system follows this hierarchy:

1. **Explicit Denials** - Direct user permissions with `granted: false`
2. **Explicit Grants** - Direct user permissions with `granted: true`
3. **Role-Based Permissions** - Permissions inherited from assigned roles
4. **Collection-Level Permissions** - Fine-grained collection access
5. **Default** - If none of the above apply, permission is denied

This allows for flexible permission management where:
- Explicit denials always win (can revoke specific permissions from admins)
- Direct grants override role permissions
- Collection-level permissions provide fine-grained control

## Expiring Permissions

Both role assignments and direct permissions support expiration:

```elixir
# Temporary access (expires in 7 days)
expires_at = DateTime.utc_now() |> DateTime.add(7, :day)

Authorization.assign_role(user_id, role_id, expires_at: expires_at)
Authorization.grant_permission(user_id, permission_id, expires_at: expires_at)
```

Expired permissions are automatically excluded from authorization checks.

## Testing

```elixir
# In your tests
defmodule MyAppWeb.MyControllerTest do
  use VoileWeb.ConnCase
  
  setup do
    user = insert_user()
    permission = insert_permission("collections.read")
    grant_permission(user.id, permission.id)
    
    {:ok, user: user}
  end
  
  test "authorized user can view collection", %{user: user} do
    conn = build_conn() |> assign(:current_user, user)
    # ... test
  end
end
```

See `test/voile_web/auth/authorization_test.exs` for comprehensive test examples.

## Best Practices

1. **Check permissions at the boundary** - Authorize in controllers/LiveViews, not in business logic
2. **Use scoped permissions** - Apply permissions to specific resources when possible
3. **Deny explicitly when needed** - Use explicit denials for exceptions to role permissions
4. **Assign roles over direct permissions** - Prefer role-based access for easier management
5. **Use collection-level permissions** - For fine-grained collection access control
6. **Set expiration dates** - For temporary access grants
7. **Check permissions in templates** - Show/hide UI elements based on user permissions
8. **Test permission logic** - Write tests to verify authorization rules

## Error Handling

When authorization fails, the system raises `Authorization.UnauthorizedError`:

```elixir
defmodule VoileWeb.FallbackController do
  use VoileWeb, :controller
  
  def call(conn, {:error, %Authorization.UnauthorizedError{} = error}) do
    conn
    |> put_flash(:error, error.message)
    |> redirect(to: ~p"/")
  end
end
```

In LiveView, use the safe `authorize/3` function for graceful error handling:

```elixir
case authorize(socket, permission, opts) do
  {:ok, socket} -> 
    # ... proceed
  {:error, reason} -> 
    # ... handle error
end
```
