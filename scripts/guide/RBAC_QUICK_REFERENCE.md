# RBAC Quick Reference Card

## 🔐 Permission Checks

### In LiveView Code
```elixir
# Enforce permission (raises error if denied)
authorize!(socket, "resource.action")

# Check permission (returns true/false)
if can?(socket, "resource.action") do
  # ...
end
```

### In Templates
```heex
<%= if can?(@current_scope.user, "resource.action") do %>
  <!-- Show button/link -->
<% end %>
```

### In Controllers
```elixir
# Using plug
plug VoileWeb.Plugs.Authorization, 
  permission: "resource.action"

# In action
authorize!(conn, "resource.action")
```

---

## 📋 Available Permissions

### Collections
- `collections.read` - View collections
- `collections.create` - Create new
- `collections.update` - Edit existing
- `collections.delete` - Delete
- `collections.publish` - Publish
- `collections.archive` - Archive

### Items
- `items.read` - View items
- `items.create` - Create new
- `items.update` - Edit existing
- `items.delete` - Delete
- `items.export` - Export data
- `items.import` - Import data

### Users
- `users.read` - View users
- `users.create` - Create new
- `users.update` - Edit existing
- `users.delete` - Delete
- `users.manage_roles` - Assign roles

### Roles & Permissions
- `roles.create` - Create roles
- `roles.update` - Edit roles
- `roles.delete` - Delete roles
- `permissions.manage` - Manage all permissions

### Metadata & Master Data
- `metadata.edit` - Edit metadata fields
- `metadata.manage` - Manage schemas & master data

### System
- `system.settings` - System configuration
- `system.audit` - View audit logs
- `system.backup` - Perform backups

---

## 🎯 Implementation Pattern

### LiveView Module
```elixir
defmodule MyApp.MyLive.Index do
  use MyApp, :live_view
  
  # 1. Mount check
  def mount(_params, _session, socket) do
    authorize!(socket, "resource.read")
    {:ok, socket}
  end
  
  # 2. Action checks
  defp apply_action(socket, :new, _) do
    authorize!(socket, "resource.create")
    # ...
  end
  
  defp apply_action(socket, :edit, %{"id" => id}) do
    authorize!(socket, "resource.update")
    # ...
  end
  
  # 3. Event checks
  def handle_event("delete", %{"id" => id}, socket) do
    authorize!(socket, "resource.delete")
    # ...
  end
end
```

### Template
```heex
<!-- New button -->
<%= if can?(@current_scope.user, "resource.create") do %>
  <.link patch={~p"/resource/new"}>
    <.button>Create</.button>
  </.link>
<% end %>

<!-- Edit button -->
<%= if can?(@current_scope.user, "resource.update") do %>
  <.link patch={~p"/resource/#{item}/edit"}>
    <.icon name="hero-pencil" />
  </.link>
<% end %>

<!-- Delete button -->
<%= if can?(@current_scope.user, "resource.delete") do %>
  <.link phx-click="delete" phx-value-id={item.id}>
    <.icon name="hero-trash" />
  </.link>
<% end %>
```

---

## ✅ Modules with RBAC

| Module | Permission | Status |
|--------|-----------|--------|
| Collections | `collections.*` | ✅ Complete |
| Items | `items.*` | ✅ Complete |
| Users | `users.*` | ✅ Complete |
| Roles | `roles.*` | ✅ Complete |
| Permissions | `permissions.manage` | ✅ Complete |
| Settings | `system.settings` | ✅ Complete |
| Master Data (7 modules) | `metadata.manage` | ✅ Complete |

---

## 🧪 Testing Commands

```elixir
# In IEx
alias VoileWeb.Auth.Authorization

# Check permission
user = Voile.Repo.get_by(Voile.Schema.Accounts.User, email: "user@example.com")
Authorization.can?(user, "collections.create")
# => true or false

# Get user permissions
Authorization.get_user_permissions(user.id)

# Grant permission
perm = Voile.Repo.get_by(Voile.Schema.Accounts.Permission, name: "collections.create")
Authorization.grant_permission(user.id, perm.id)

# Deny permission
Authorization.deny_permission(user.id, perm.id)

# Assign role
role = Voile.Repo.get_by(Voile.Schema.Accounts.Role, name: "editor")
Authorization.assign_role(user.id, role.id)
```

---

## 🔧 Common Tasks

### Add New Permission
```elixir
# In migration or seeds
Voile.Repo.insert!(%Voile.Schema.Accounts.Permission{
  name: "module.action",
  resource: "module",
  action: "action",
  description: "Description of permission"
})
```

### Create Role with Permissions
```elixir
# Create role
{:ok, role} = Voile.Schema.Accounts.create_role(%{
  name: "content_manager",
  description: "Can manage collections and items",
  is_system_role: false
})

# Assign permissions to role
perms = ["collections.read", "collections.create", "collections.update",
         "items.read", "items.create", "items.update"]
         
for perm_name <- perms do
  perm = Voile.Repo.get_by(Voile.Schema.Accounts.Permission, name: perm_name)
  Voile.Schema.Accounts.add_permission_to_role(role.id, perm.id)
end
```

### Assign Role to User
```elixir
user = Voile.Repo.get_by(Voile.Schema.Accounts.User, email: "user@example.com")
role = Voile.Repo.get_by(Voile.Schema.Accounts.Role, name: "content_manager")
VoileWeb.Auth.Authorization.assign_role(user.id, role.id)
```

---

## 🎯 Permission Naming Convention

Format: `resource.action`

Examples:
- `collections.read` - View collections
- `collections.create` - Create collection
- `items.update` - Update item
- `users.delete` - Delete user
- `system.settings` - Access settings

---

## 📍 Important Files

- Authorization: `lib/voile_web/auth/authorization.ex`
- UserAuth: `lib/voile_web/auth/user_auth.ex`
- Authorization Plug: `lib/voile_web/plugs/authorization.ex`
- Schemas: `lib/voile/schema/accounts/*.ex`

---

## 💡 Tips

1. **Always check permissions** in both mount and actions
2. **Use authorize!** for enforcement (raises error)
3. **Use can?** for conditional logic (returns boolean)
4. **Super admin** role should have ALL permissions
5. **Explicit denials** override role permissions
6. **Test thoroughly** with different user roles

---

**Quick Help:**
- RBAC Guide: `scripts/guide/RBAC_GUIDE.md`
- Implementation: `RBAC_IMPLEMENTATION_COMPLETE.md`
- Permission List: Check database `permissions` table
