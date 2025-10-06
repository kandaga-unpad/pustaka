# Role Management System

## Overview

A comprehensive role management interface for administrators to manage roles, permissions, and user assignments through the dashboard.

## Features

- **Role CRUD Operations**: Create, read, update, and delete roles
- **Permission Management**: Assign and remove permissions from roles
- **User Assignment**: Add and remove users from roles
- **Search Functionality**: Search for roles and users
- **Visual Permission Toggle**: Easy-to-use UI for managing role permissions
- **System Role Protection**: Prevents modification of critical system roles
- **Real-time Updates**: LiveView provides instant feedback

## Access Control

All role management features require appropriate permissions:
- `roles.create` - Create new roles
- `roles.update` - Edit roles and manage user assignments
- `roles.delete` - Delete roles
- `permissions.manage` - Manage role permissions

## Routes

The role management system is accessible at `/manage/settings/roles` with the following routes:

- `/manage/settings/roles` - List all roles (index)
- `/manage/settings/roles/new` - Create a new role
- `/manage/settings/roles/:id` - View role details
- `/manage/settings/roles/:id/show/edit` - Edit role (modal)
- `/manage/settings/roles/:id/show/permissions` - Manage permissions (modal)
- `/manage/settings/roles/:id/edit` - Edit role (dedicated page)

## LiveView Modules

### VoileWeb.Users.Role.ManageLive

The main index page that displays all roles in a searchable table.

**Features:**
- Lists all roles with their permissions count and assigned users count
- Search functionality to filter roles by name or description
- Quick actions to edit or delete roles
- Highlights system roles with a badge
- Protects system roles from deletion

**Events:**
- `search` - Filter roles based on search query
- `delete` - Delete a role (with validation)

**Assigns:**
- `@streams.roles` - Stream of all roles
- `@searching` - Boolean indicating if search is in progress
- `@role` - Currently selected role (for modal actions)

### VoileWeb.Users.Role.ManageLive.Show

The detailed role view page showing role information, permissions, and assigned users.

**Features:**
- Display role name, description, and system role status
- List all permissions assigned to the role
- Manage users assigned to the role
- Search and add new users to the role
- Remove users from the role
- Link to edit role or manage permissions

**Events:**
- `toggle_add_user` - Show/hide user search interface
- `search_users` - Search for users to add to the role
- `add_user_to_role` - Assign a user to the role
- `remove_user_from_role` - Remove a user from the role
- `toggle_permission` - Add or remove a permission from the role

**Assigns:**
- `@role` - The current role being viewed
- `@role_users` - List of users assigned to this role
- `@searching_users` - Boolean for user search state
- `@search_results` - Users matching the search query
- `@showing_add_user` - Boolean to show/hide add user form
- `@all_permissions` - All available permissions (for permission management)

### VoileWeb.Users.Role.ManageLive.FormComponent

A live component for creating and editing roles.

**Features:**
- Create new roles with name and description
- Select permissions when creating a role
- Edit existing role information
- Validates role name uniqueness
- Prevents editing system roles

**Events:**
- `validate` - Validate form inputs
- `save` - Save the role (create or update)

**Assigns:**
- `@form` - The form changeset
- `@role` - The role being created or edited
- `@action` - `:new` or `:edit`
- `@all_permissions` - All available permissions (for new roles)

### VoileWeb.Users.Role.ManageLive.Edit

A dedicated edit page for roles (alternative to modal editing).

**Features:**
- Full-page edit interface
- Uses the same FormComponent
- Redirects to role detail page after save
- Prevents editing system roles

## Usage Examples

### Accessing Role Management

1. Navigate to the dashboard settings
2. Click on "Role Management" in the sidebar
3. You'll see a list of all roles

### Creating a New Role

1. Click the "New Role" button
2. Enter a role name (e.g., "Content Manager")
3. Add a description explaining the role's purpose
4. Select the permissions this role should have
5. Click "Save Role"

### Editing a Role

1. From the role list, click on a role to view details
2. Click "Edit Role" to update name and description
3. Or click "Manage Permissions" to add/remove permissions

### Assigning Users to a Role

1. Navigate to a role's detail page
2. Click "Add User" button
3. Search for users by name or email
4. Click "Add" next to the user you want to assign
5. The user will immediately have this role's permissions

### Removing Users from a Role

1. On the role detail page, find the user in the assigned users list
2. Click "Remove" next to the user
3. Confirm the action
4. The user will lose this role's permissions

### Managing Permissions

1. On the role detail page, click "Manage Permissions"
2. Toggle permissions on/off using the switches
3. Permissions are saved immediately
4. Click "Done" when finished

### Deleting a Role

1. From the role list, click "Delete" on the role you want to remove
2. Confirm the deletion
3. Note: System roles and roles with assigned users cannot be deleted

## Business Logic

### Role Creation
- Role names must be unique
- Roles can be created with or without initial permissions
- New roles are not marked as system roles by default

### Role Deletion
- Cannot delete system roles (marked with `is_system_role: true`)
- Cannot delete roles that have users assigned to them
- Must first remove all user assignments before deletion

### Permission Assignment
- Permissions can be added or removed from roles at any time
- Changes to role permissions immediately affect all users with that role
- System roles' permissions should be carefully managed

### User Assignment
- Users can have multiple roles
- Role assignments can be global or scoped to specific resources
- Removing a user from a role immediately revokes the role's permissions
- Users that already have a role won't appear in the search results

## Database Queries

The system uses optimized queries to:
- Count users per role efficiently
- Search users excluding already assigned users
- Filter expired role assignments
- Preload permissions with roles for efficient display

## Security Considerations

1. **Permission Checks**: All actions require appropriate permissions
2. **System Role Protection**: System roles cannot be modified or deleted
3. **Validation**: Role names are validated for uniqueness and format
4. **Confirmation**: Destructive actions require user confirmation
5. **Assignment Tracking**: Records who assigned roles/permissions and when

## UI/UX Features

- **Responsive Design**: Works on desktop and mobile devices
- **Dark Mode Support**: Fully supports light and dark themes
- **Loading States**: Shows spinners during search operations
- **Error Handling**: Displays clear error messages for failed operations
- **Success Feedback**: Flash messages confirm successful actions
- **Badges**: Visual indicators for system roles and permission counts
- **Icons**: Heroicons for intuitive action buttons
- **Modal Dialogs**: Non-disruptive editing and permission management

## Integration with RBAC System

The role management UI integrates with the existing RBAC system:

- Uses `VoileWeb.Auth.PermissionManager` for role CRUD operations
- Uses `VoileWeb.Auth.Authorization` for permission checks and user assignments
- Respects the permission hierarchy (denials > grants > roles)
- Works with scoped permissions and global permissions
- Supports time-based role assignments (though not exposed in UI yet)

## Future Enhancements

Potential improvements for the role management system:

1. **Bulk User Assignment**: Assign multiple users to a role at once
2. **Role Templates**: Create roles from pre-defined templates
3. **Permission Categories**: Group permissions by resource type
4. **Audit Log**: Track all changes to roles and assignments
5. **Role Hierarchy**: Support parent-child role relationships
6. **Expiring Assignments**: UI for setting expiration dates on role assignments
7. **Role Comparison**: Compare permissions between roles
8. **Import/Export**: Backup and restore role configurations
9. **Activity Dashboard**: Visualize role usage and permission distribution
10. **Notifications**: Alert users when their role changes

## Troubleshooting

### Role Deletion Fails
- Check if users are assigned to the role
- Verify the role is not a system role
- Ensure you have `roles.delete` permission

### Cannot Add User to Role
- Confirm the user exists
- Check that the user doesn't already have this role
- Verify you have `roles.update` permission

### Permissions Not Updating
- Clear the browser cache
- Check that you have `permissions.manage` permission
- Verify the role was successfully updated in the database

### Search Not Working
- Ensure the search query is at least 2 characters
- Check database connection
- Look for JavaScript errors in browser console

## Developer Notes

### Testing
Create test cases for:
- Role CRUD operations
- Permission assignments
- User assignments
- Search functionality
- Authorization checks
- System role protection

### Performance
- Role list uses streaming for efficient rendering
- User search is limited to 10 results
- Permissions are preloaded to minimize database queries
- Counts are calculated using aggregate queries

### Customization
To customize the role management system:
- Modify the component templates in the render functions
- Add custom validations in the Role schema
- Extend the PermissionManager with additional functions
- Create custom authorization rules in the Authorization module
