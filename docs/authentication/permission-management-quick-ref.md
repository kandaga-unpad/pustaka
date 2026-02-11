# Permission Management Quick Reference

## Routes

```elixir
# In router.ex under scope "/settings"
scope "/permissions" do
  live "/", Users.Permission.ManageLive, :index
  live "/new", Users.Permission.ManageLive, :new
  live "/:id", Users.Permission.ManageLive.Show, :show
  live "/:id/edit", Users.Permission.ManageLive.Edit, :edit
end
```

## LiveView Components

### Main Index

```elixir
VoileWeb.Users.Permission.ManageLive
# Path: /manage/settings/permissions
# Purpose: List and manage permissions
```

### Permission Detail

```elixir
VoileWeb.Users.Permission.ManageLive.Show
# Path: /manage/settings/permissions/:id
# Purpose: View permission details and roles that have it
```

### Permission Form

```elixir
VoileWeb.Users.Permission.ManageLive.FormComponent
# Used in modals for creating and editing permissions
```

### Edit Page

```elixir
VoileWeb.Users.Permission.ManageLive.Edit
# Path: /manage/settings/permissions/:id/edit
# Purpose: Full-page permission editing
```

## Permission Manager Functions

### List all permissions

```elixir
PermissionManager.list_permissions()
```

### Get a permission

```elixir
PermissionManager.get_permission(id)
```

### Create a permission

```elixir
PermissionManager.create_permission(%{
  name: "collections.create",
  resource: "collections",
  action: "create",
  description: "Create new collections"
})
```

### Update a permission

```elixir
PermissionManager.update_permission(permission, %{
  description: "Updated description"
})
```

### Delete a permission

```elixir
PermissionManager.delete_permission(permission)
```

## Template Helpers

### Check Permission in Template

```heex
<%= if can?(@current_scope.user, "permissions.manage") do %>
  <.button>New Permission</.button>
<% end %>
```

### Authorize in LiveView

```elixir
def mount(_params, _session, socket) do
  authorize!(socket, "permissions.manage")
  {:ok, socket}
end
```

## Permission Format

Permissions follow the format: `resource.action`

### Examples

```
collections.create
collections.read
collections.update
collections.delete
users.create
users.read
users.update
users.delete
roles.create
permissions.manage
system.settings
```

## Common Operations

### Search permissions

```elixir
# In the LiveView, search is automatic via phx-change
# Searches: name, resource, action, description
```

### Get roles with a permission

```elixir
import Ecto.Query

roles =
  Voile.Schema.Accounts.Role
  |> join(:inner, [r], rp in RolePermission, on: r.id == rp.role_id)
  |> where([r, rp], rp.permission_id == ^permission_id)
  |> Repo.all()
```

### Count roles with a permission

```elixir
import Ecto.Query

count =
  RolePermission
  |> where([rp], rp.permission_id == ^permission_id)
  |> Repo.aggregate(:count, :id)
```

## Access Control

All permission management requires:

```elixir
"permissions.manage"
```

## UI Elements

### Resource Badge (Blue)

```heex
<span class="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-blue-100 text-blue-800 dark:bg-blue-900 dark:text-blue-200">
  {permission.resource}
</span>
```

### Action Badge (Green)

```heex
<span class="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-200">
  {permission.action}
</span>
```

### System Role Badge (Purple)

```heex
<span class="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-purple-100 text-purple-800 dark:bg-purple-900 dark:text-purple-200">
  System
</span>
```

## Events

### Index LiveView

- `search` - Filter permissions by query
- `delete` - Delete a permission

### Form Component

- `validate` - Validate form inputs
- `save` - Save the permission (create or update)

## Assigns

### Index LiveView

- `@streams.permissions` - Stream of all permissions
- `@searching` - Boolean indicating if search is in progress
- `@permission` - Currently selected permission (for modal actions)

### Show LiveView

- `@permission` - The permission being viewed
- `@roles` - Roles that have this permission

### Form Component

- `@form` - The form changeset
- `@permission` - The permission being created or edited
- `@action` - `:new` or `:edit`

### Edit LiveView

- `@permission` - The permission being edited
- `@roles` - Roles that have this permission

## Validation Rules

### Permission Name

- Format: `resource.action`
- Must match regex: `^[a-z_]+\.[a-z_]+$`
- Must be unique
- Examples: `collections.create`, `users_manage.roles`

### Required Fields

- `name` - Permission name
- `resource` - Resource type
- `action` - Action type

### Optional Fields

- `description` - Human-readable description

## Error Handling

### Cannot delete permission in use

```elixir
{:error, "Cannot delete permission that is assigned to N role(s)"}
```

### Invalid permission format

```elixir
# Changeset error
%{name: ["must be in format resource.action (e.g., collections.create)"]}
```

## Success Criteria

Your permission management system is working correctly if:

✅ You can view the list of permissions  
✅ You can create a new permission  
✅ You can edit an existing permission  
✅ You can delete an unused permission  
✅ Deleting a permission in use shows an error  
✅ You can view permission details  
✅ You can see which roles have a permission  
✅ Search filters permissions correctly  
✅ All UI elements render properly  
✅ Dark mode works correctly  
✅ Permission checks work (access denied when appropriate)

## Notes

- Module naming: `VoileWeb.Users.Permission.ManageLive.*`
- All routes under: `/manage/settings/permissions`
- Sidebar link is in the Settings section
- Dark mode is fully supported
- Uses LiveView streams for performance
- Search is debounced (300ms)
