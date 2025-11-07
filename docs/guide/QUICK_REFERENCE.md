# Authorization Quick Reference

## Quick Start

### 1. Seed the Database
```elixir
# In IEx or seeds.exs
Voile.Repo.Seeds.AuthorizationSeeds.run()
```

### 2. Assign Admin Role
```elixir
Voile.Repo.Seeds.AuthorizationSeeds.assign_super_admin("user@example.com")
```

## Common Tasks

### Check Permission
```elixir
# In controller
if can?(conn, "collections.update", scope: {:collection, id}) do
  # allowed
end

# In LiveView
if can?(socket, "items.delete", scope: {:item, item_id}) do
  # allowed
end
```

### Require Permission
```elixir
# In controller (raises if unauthorized)
authorize!(conn, "collections.delete", scope: {:collection, id})

# In LiveView (safe version)
case authorize(socket, "items.create", scope: {:collection, coll_id}) do
  {:ok, socket} -> # proceed
  {:error, msg} -> # handle error
end
```

### Assign Role to User
```elixir
alias VoileWeb.Auth.Authorization

# Global role
role = Repo.get_by(Voile.Schema.Accounts.Role, name: "editor")
Authorization.assign_role(user_id, role.id)

# Scoped role (editor for specific collection)
Authorization.assign_role(user_id, role.id,
  scope_type: "collection",
  scope_id: collection_id
)

# Temporary role (expires in 30 days)
Authorization.assign_role(user_id, role.id,
  expires_at: DateTime.utc_now() |> DateTime.add(30, :day)
)
```

### Grant Direct Permission
```elixir
perm = Repo.get_by(Voile.Schema.Accounts.Permission, name: "items.export")

# Global permission
Authorization.grant_permission(user_id, perm.id)

# Scoped permission
Authorization.grant_permission(user_id, perm.id,
  scope_type: "collection",
  scope_id: collection_id
)
```

### Deny Permission
```elixir
# Override role permission for specific user
perm = Repo.get_by(Voile.Schema.Accounts.Permission, name: "collections.delete")
Authorization.deny_permission(user_id, perm.id)
```

## In Templates

### Show/Hide Based on Permission
```heex
<%= if can?(@socket, "collections.update", scope: {:collection, @collection.id}) do %>
  <.button navigate={~p"/collections/#{@collection.id}/edit"}>
    Edit
  </.button>
<% end %>
```

### Pre-assign Permissions for Multiple Checks
```elixir
# In mount/handle_event
socket = assign_permissions(socket, collection_id)
```

```heex
<%= if @permissions.can_edit do %>
  <.button>Edit</.button>
<% end %>

<%= if @permissions.can_delete do %>
  <.button phx-click="delete">Delete</.button>
<% end %>
```

## Permission Names

### Format
`resource.action`

### Collections
- `collections.create`
- `collections.read`
- `collections.update`
- `collections.delete`
- `collections.publish`
- `collections.archive`

### Items
- `items.create`
- `items.read`
- `items.update`
- `items.delete`
- `items.export`
- `items.import`

### Metadata
- `metadata.edit`
- `metadata.manage`

### Users
- `users.create`
- `users.read`
- `users.update`
- `users.delete`
- `users.manage_roles`

### Roles & System
- `roles.create`
- `roles.update`
- `roles.delete`
- `permissions.manage`
- `system.settings`
- `system.audit`
- `system.backup`

## Scopes

### Global (Default)
```elixir
Authorization.can?(user, "collections.create")
```

### Collection Scope
```elixir
Authorization.can?(user, "items.update", scope: {:collection, collection_id})
```

### Item Scope
```elixir
Authorization.can?(user, "items.delete", scope: {:item, item_id})
```

## Default Roles

| Role | Description | Use Case |
|------|-------------|----------|
| `super_admin` | Full access | System administrators |
| `admin` | Admin without system settings | Site administrators |
| `editor` | Manage collections/items | Content managers |
| `contributor` | Create/edit own content | Content creators |
| `viewer` | Read-only access | Public/guest users |

## Collection Permission Levels

| Level | Description | Maps To |
|-------|-------------|---------|
| `owner` | Full control | `collections.delete`, `items.delete` |
| `editor` | Can modify | `collections.update`, `items.update`, `items.create` |
| `viewer` | Read-only | `collections.read`, `items.read`, `items.export` |

## Useful Commands

### List All Permissions
```elixir
Voile.Repo.Seeds.AuthorizationSeeds.list_permissions()
```

### List All Roles
```elixir
Voile.Repo.Seeds.AuthorizationSeeds.list_roles()
```

### Get User's Permissions
```elixir
Authorization.get_user_permissions(user_id)
```

### Get User's Roles
```elixir
PermissionManager.list_user_roles(user_id)
```

### Create Custom Role
```elixir
{:ok, role} = PermissionManager.create_role(%{
  name: "custom_role",
  description: "Custom role description"
})

# Add permissions to role
perm = Repo.get_by(Permission, name: "collections.read")
PermissionManager.add_permission_to_role(role.id, perm.id)
```

## Import Helpers

### In Controller
```elixir
import VoileWeb.Auth.ControllerHelpers
```

### In LiveView
```elixir
import VoileWeb.Auth.LiveHelpers
```

### Direct Usage
```elixir
alias VoileWeb.Auth.Authorization
alias VoileWeb.Auth.PermissionManager
```
