# Role Management Quick Reference

## Quick Start

### Access Role Management
```
/manage/settings/roles
```

### Required Permissions
- `roles.create` - Create roles
- `roles.update` - Edit roles, manage users
- `roles.delete` - Delete roles
- `permissions.manage` - Manage permissions

## Common Tasks

### Create a New Role
1. Go to `/manage/settings/roles`
2. Click "New Role"
3. Fill in name and description
4. Select permissions
5. Click "Save Role"

### Edit Role Information
- **Via Modal**: Role detail page → "Edit Role"
- **Via Page**: Role detail page → "Edit" in table

### Add Permissions to Role
1. Go to role detail page
2. Click "Manage Permissions"
3. Toggle permissions on/off
4. Click "Done"

### Assign User to Role
1. Go to role detail page
2. Click "Add User"
3. Search for user
4. Click "Add"

### Remove User from Role
1. Go to role detail page
2. Find user in list
3. Click "Remove"
4. Confirm

### Delete a Role
1. From role list, click "Delete"
2. Confirm deletion
3. Note: Cannot delete system roles or roles with users

## Module Reference

```elixir
# List all roles
VoileWeb.Auth.PermissionManager.list_roles()

# Get role with permissions
VoileWeb.Auth.PermissionManager.get_role(id)

# Create role
VoileWeb.Auth.PermissionManager.create_role(%{
  name: "Content Manager",
  description: "Can manage content"
})

# Update role
VoileWeb.Auth.PermissionManager.update_role(role, attrs)

# Delete role
VoileWeb.Auth.PermissionManager.delete_role(role)

# Add permission to role
VoileWeb.Auth.PermissionManager.add_permission_to_role(role_id, permission_id)

# Remove permission from role
VoileWeb.Auth.PermissionManager.remove_permission_from_role(role_id, permission_id)

# Assign user to role
VoileWeb.Auth.Authorization.assign_role(user_id, role_id, 
  assigned_by_id: admin_id
)

# Remove user from role
VoileWeb.Auth.Authorization.revoke_role(user_id, role_id)

# List users with role
VoileWeb.Auth.PermissionManager.list_users_with_role(role_id)
```

## LiveView Components

### Main Index
```elixir
VoileWeb.Users.Role.ManageLive
# Path: /manage/settings/roles
# Purpose: List and manage roles
```

### Role Detail
```elixir
VoileWeb.Users.Role.ManageLive.Show
# Path: /manage/settings/roles/:id
# Purpose: View role details, manage users and permissions
```

### Role Form
```elixir
VoileWeb.Users.Role.ManageLive.FormComponent
# Used in modals for creating and editing roles
```

### Edit Page
```elixir
VoileWeb.Users.Role.ManageLive.Edit
# Path: /manage/settings/roles/:id/edit
# Purpose: Full-page role editing
```

## Template Helpers

### Check Permission in Template
```heex
<%= if can?(@socket, "roles.create") do %>
  <.button>New Role</.button>
<% end %>
```

### Authorize in LiveView
```elixir
def mount(_params, _session, socket) do
  authorize!(socket, "roles.create")
  {:ok, socket}
end
```

## Routes

```elixir
# In router.ex under scope "/settings"
scope "/roles" do
  live "/", Users.Role.ManageLive, :index
  live "/new", Users.Role.ManageLive, :new
  live "/:id", Users.Role.ManageLive.Show, :show
  live "/:id/show/edit", Users.Role.ManageLive.Show, :edit
  live "/:id/show/permissions", Users.Role.ManageLive.Show, :manage_permissions
  live "/:id/edit", Users.Role.ManageLive.Edit, :edit
end
```

## Database Schema

```elixir
# roles table
schema "roles" do
  field :name, :string              # Unique role name
  field :description, :string       # Role description
  field :is_system_role, :boolean   # Protected system role?
  
  many_to_many :permissions         # Associated permissions
  has_many :user_role_assignments   # User assignments
  
  timestamps()
end

# user_role_assignments table
schema "user_role_assignments" do
  belongs_to :user
  belongs_to :role
  field :scope_type, :string        # global, collection, item
  field :scope_id, :string          # Resource ID if scoped
  field :assigned_by_id, :string    # Who assigned it
  field :expires_at, :utc_datetime  # Optional expiration
  
  timestamps()
end
```

## Common Patterns

### Check if User Can Delete Role
```elixir
defp can_delete_role?(role) do
  cond do
    role.is_system_role ->
      {:error, "Cannot delete system roles"}
    count_users_with_role(role.id) > 0 ->
      {:error, "Cannot delete role with assigned users"}
    true ->
      {:ok, role}
  end
end
```

### Search Users Not in Role
```elixir
# Get users not already assigned to role
assigned_user_ids = 
  UserRoleAssignment
  |> where([ura], ura.role_id == ^role_id)
  |> select([ura], ura.user_id)
  |> Repo.all()

User
|> where([u], u.id not in ^assigned_user_ids)
|> where([u], ilike(u.fullname, ^"%#{query}%"))
|> Repo.all()
```

### Load Role with Users
```elixir
def load_role_users(socket) do
  users =
    PermissionManager.list_users_with_role(socket.assigns.role.id)
    |> Enum.map(& &1.user)
  
  assign(socket, role_users: users)
end
```

## Validation Rules

### Role Name
- Must be unique
- Minimum 3 characters
- Maximum 50 characters

### Deletion Restrictions
- Cannot delete system roles
- Cannot delete roles with users
- Must have `roles.delete` permission

### Permission Management
- Requires `permissions.manage` permission
- Changes apply immediately to all users
- Cannot remove all permissions (allowed but not recommended)

## Error Messages

```elixir
# Common error scenarios
"Cannot delete system roles"
"Cannot delete role with assigned users"
"Failed to assign user to role"
"Failed to remove user from role"
"Failed to update permission"
"Role deleted successfully"
"User assigned to role successfully"
"User removed from role successfully"
"Permission updated successfully"
```

## Styling Notes

- Uses Tailwind CSS classes
- Supports dark mode (bg-gray-700, dark:bg-gray-900)
- Responsive design (grid-cols-1 md:grid-cols-2 lg:grid-cols-3)
- Loading states with spin animation
- Badge components for system roles
- Toggle switches for permissions

## Testing Checklist

- [ ] Create a new role
- [ ] Edit role name and description
- [ ] Add permissions to role
- [ ] Remove permissions from role
- [ ] Assign user to role
- [ ] Remove user from role
- [ ] Search for roles
- [ ] Search for users
- [ ] Delete role (should fail if has users)
- [ ] Try to delete system role (should fail)
- [ ] Check permission-based UI visibility
- [ ] Test without proper permissions (should deny access)
- [ ] Verify dark mode works
- [ ] Test on mobile device

## Related Documentation

- [RBAC System Guide](./RBAC_GUIDE.md) - Complete RBAC documentation
- [Authorization System](./AUTH_SYSTEM.md) - Core authorization architecture
- [RBAC Summary](./RBAC_SUMMARY.md) - Implementation summary
