# RBAC Implementation Summary

## Date: October 14, 2025

## Overview
This document summarizes the implementation of Role-Based Access Control (RBAC) across the Voile application modules.

## Permissions Available

Based on the permissions table, here are all available permissions:

### Collections Module (6 permissions)
- `collections.create` - Create new collections
- `collections.read` - View collections
- `collections.update` - Edit collections
- `collections.delete` - Delete collections
- `collections.publish` - Publish collections
- `collections.archive` - Archive collections

### Items Module (6 permissions)
- `items.create` - Create new items
- `items.read` - View items
- `items.update` - Edit items
- `items.delete` - Delete items
- `items.export` - Export items
- `items.import` - Import items

### Metadata Module (2 permissions)
- `metadata.edit` - Edit metadata fields
- `metadata.manage` - Manage metadata schemas

### Users Module (5 permissions)
- `users.create` - Create new users
- `users.read` - View users
- `users.update` - Edit users
- `users.delete` - Delete users
- `users.manage_roles` - Manage user roles

### Roles Module (3 permissions)
- `roles.create` - Create new roles
- `roles.update` - Edit roles
- `roles.delete` - Delete roles

### Permissions Module (1 permission)
- `permissions.manage` - Manage permissions

### System Module (3 permissions)
- `system.settings` - Manage system settings
- `system.audit` - View audit logs
- `system.backup` - Perform system backups

## Implementation Status

### ✅ Completed Modules

#### 1. Users Management Module
**Location:** `/manage/settings/users`
**Files Updated:**
- `lib/voile_web/live/users/manage/user_manage_live.ex`
- `lib/voile_web/live/users/manage/user_manage_show_live.ex`
- `lib/voile_web/live/users/manage/user_manage_form_component.ex`

**Permissions Implemented:**
- ✅ `users.create` - New user button, create action
- ✅ `users.read` - View users list, user details
- ✅ `users.update` - Edit button, update form
- ✅ `users.delete` - Delete button, delete action

**Implementation Details:**
- Mount checks permission in `user_manage_live.ex` and `user_manage_show_live.ex`
- UI buttons conditionally rendered based on `can?/2` checks
- Form fields disabled based on permissions

---

#### 2. Roles Management Module
**Location:** `/manage/settings/roles`
**Files Updated:**
- `lib/voile_web/live/users/role/role_manage_live.ex`
- `lib/voile_web/live/users/role/role_manage_show_live.ex`
- `lib/voile_web/live/users/role/role_manage_edit_live.ex`

**Permissions Implemented:**
- ✅ `roles.create` - New role button, create action
- ✅ `roles.update` - Edit button, update actions, user assignments
- ✅ `roles.delete` - Delete button (respects system roles)
- ✅ `permissions.manage` - Permission toggles, manage permissions modal

**Implementation Details:**
- Authorization checks in mount and event handlers
- Conditional UI rendering for all action buttons
- Special protection for system roles
- Permission management integrated with `permissions.manage` check

---

#### 3. Permissions Management Module
**Location:** `/manage/settings/permissions`
**Files Updated:**
- `lib/voile_web/live/users/permission/permission_manage_live.ex`
- `lib/voile_web/live/users/permission/permission_manage_show_live.ex`
- `lib/voile_web/live/users/permission/permission_manage_edit_live.ex`

**Permissions Implemented:**
- ✅ `permissions.manage` - All permission management operations

**Implementation Details:**
- Single permission controls entire module
- Create, read, update, delete all checked with `permissions.manage`
- Displays which roles have each permission

---

#### 4. Collections Module
**Location:** `/manage/catalog/collections`
**Files Updated:**
- ✅ `lib/voile_web/live/dashboard/catalog/collection_live/index.ex`
- ✅ `lib/voile_web/live/dashboard/catalog/collection_live/index.html.heex`
- ✅ `lib/voile_web/live/dashboard/catalog/collection_live/show.ex`

**Permissions Implemented:**
- ✅ `collections.read` - Mount check, view collections list
- ✅ `collections.create` - New collection button, :new action
- ✅ `collections.update` - Edit button, :edit action
- ✅ `collections.delete` - Delete button, delete event

**Implementation Details:**
```elixir
# In mount/3
authorize!(socket, "collections.read")

# In apply_action/3
defp apply_action(socket, :new, _params) do
  authorize!(socket, "collections.create")
  # ...
end

defp apply_action(socket, :edit, %{"id" => id}) do
  authorize!(socket, "collections.update")
  # ...
end

# In handle_event/3
def handle_event("delete", %{"id" => id}, socket) do
  authorize!(socket, "collections.delete")
  # ...
end
```

**Template Updates:**
```heex
<%= if can?(@current_scope.user, "collections.create") do %>
  <.link patch={~p"/manage/catalog/collections/new"}>
    <.button>New Collection</.button>
  </.link>
<% end %>

<%= if can?(@current_scope.user, "collections.update") do %>
  <.link patch={~p"/manage/catalog/collections/#{collection}/edit"}>Edit</.link>
<% end %>

<%= if can?(@current_scope.user, "collections.delete") do %>
  <.link phx-click="delete">Delete</.link>
<% end %>
```

---

#### 5. Items Module
**Location:** `/manage/catalog/items`
**Files Updated:**
- ✅ `lib/voile_web/live/dashboard/catalog/item_live/index.ex`
- ✅ `lib/voile_web/live/dashboard/catalog/item_live/index.html.heex`

**Permissions Implemented:**
- ✅ `items.read` - Mount check, view items list
- ✅ `items.create` - New item button, :new action
- ✅ `items.update` - Edit button, :edit action
- ✅ `items.delete` - Delete button, delete event

**Implementation Details:**
Same pattern as Collections module - mount checks, apply_action checks, event handler checks, and conditional UI rendering.

---

#### 6. Settings Module
**Location:** `/manage/settings`
**Files Updated:**
- ✅ `lib/voile_web/live/dashboard/settings/setting_live.ex`
- ✅ `lib/voile_web/live/dashboard/settings/holiday_live.ex`

**Permissions Implemented:**
- ✅ `system.settings` - Access to all settings pages

**Implementation Details:**
- Mount check with `authorize!(socket, "system.settings")`
- Controls access to holidays, system configuration

---

#### 7. Master Data - Creator Module (Example)
**Location:** `/manage/master/creators`
**Files Updated:**
- ✅ `lib/voile_web/live/dashboard/master/creator_live/index.ex`

**Permissions Implemented:**
- ✅ `metadata.manage` - Manage creators (master data)

**Implementation Details:**
- Using `metadata.manage` for all master data management
- Same pattern can be applied to other master modules

---

### ⚠️ Remaining Modules to Implement

#### 1. Item Show/Detail Page
**File:** `lib/voile_web/live/dashboard/catalog/item_live/show.ex`
**Permission:** `items.read`
**Action:** Add `authorize!(socket, "items.read")` in mount

#### 2. Collection Attachments Page
**File:** `lib/voile_web/live/dashboard/catalog/collection_live/attachments.ex`
**Permission:** `collections.update` (or `collections.read` for viewing)
**Action:** Add authorization checks

#### 3. Remaining Master Data Modules
**Files:**
- `lib/voile_web/live/dashboard/master/publisher_live/index.ex`
- `lib/voile_web/live/dashboard/master/member_type_live/index.ex`
- `lib/voile_web/live/dashboard/master/frequency_live/index.ex`
- `lib/voile_web/live/dashboard/master/locations_live/index.ex`
- `lib/voile_web/live/dashboard/master/places_live/index.ex`
- `lib/voile_web/live/dashboard/master/topic_live/index.ex`

**Permission:** `metadata.manage` for all
**Action:** Add `authorize!(socket, "metadata.manage")` in mount for each

#### 4. Metadata/Resource Management Controllers
**Files:**
- `lib/voile_web/controllers/vocabulary_controller.ex`
- `lib/voile_web/controllers/property_controller.ex`
- `lib/voile_web/controllers/resource_class_controller.ex`
- `lib/voile_web/controllers/resource_template_controller.ex`

**Permissions:** 
- `metadata.manage` for schema management
- `metadata.edit` for editing fields

**Action:** Add authorization plug or checks in controller actions

#### 5. Metadata Resource Live Pages
**File:** `lib/voile_web/live/dashboard/metaresource/metaresource_live.ex`
**Permission:** `metadata.manage`
**Action:** Add authorization in mount

#### 6. GLAM Module Pages
**Files:**
- `lib/voile_web/live/dashboard/glam/gallery/index.ex`
- `lib/voile_web/live/dashboard/glam/archive/index.ex`
- `lib/voile_web/live/dashboard/glam/museum/index.ex`
- `lib/voile_web/live/dashboard/glam/library/index.ex`

**Permissions:** Use GLAM-specific authorization or map to collections/items permissions
**Action:** Review existing GLAM authorization and integrate

#### 7. Library Circulation Modules (Complete)
**Locations:** `/manage/glam/library/circulation/*`
**Files:**
- Transaction modules (reservations, requisitions, fines, history)

**Status:** Partially implemented with custom circulation permissions
**Action:** Review and complete implementation

---

## Implementation Pattern

### Standard Pattern for LiveView Modules

```elixir
defmodule MyApp.MyLive.Index do
  use MyApp, :live_view
  
  @impl true
  def mount(_params, _session, socket) do
    # 1. Check base permission for viewing
    authorize!(socket, "resource.read")
    
    # ... rest of mount logic
    {:ok, socket}
  end
  
  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end
  
  # 2. Check permission for each action
  defp apply_action(socket, :new, _params) do
    authorize!(socket, "resource.create")
    # ... create logic
  end
  
  defp apply_action(socket, :edit, %{"id" => id}) do
    authorize!(socket, "resource.update")
    # ... edit logic
  end
  
  defp apply_action(socket, :index, _params) do
    # No additional check needed - covered by mount
    # ... index logic
  end
  
  # 3. Check permission in event handlers
  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    authorize!(socket, "resource.delete")
    # ... delete logic
  end
end
```

### Template Pattern

```heex
<!-- Conditional UI rendering -->
<%= if can?(@current_scope.user, "resource.create") do %>
  <.link patch={~p"/resource/new"}>
    <.button>Create New</.button>
  </.link>
<% end %>

<!-- Action buttons -->
<%= if can?(@current_scope.user, "resource.update") do %>
  <.link patch={~p"/resource/#{item}/edit"}>Edit</.link>
<% end %>

<%= if can?(@current_scope.user, "resource.delete") do %>
  <.link phx-click="delete" phx-value-id={item.id}>Delete</.link>
<% end %>
```

---

## Testing Recommendations

### Test User Setup

Create test users with different permission sets:

```elixir
# In seeds or IEx
alias Voile.Schema.Accounts
alias VoileWeb.Auth.Authorization

# 1. Super Admin - Has all permissions
super_admin = Accounts.get_user_by_email("admin@example.com")
super_admin_role = Accounts.get_role_by_name("super_admin")
Authorization.assign_role(super_admin.id, super_admin_role.id)

# 2. Editor - Can create/read/update but not delete
editor = Accounts.get_user_by_email("editor@example.com")
editor_role = Accounts.get_role_by_name("editor")
Authorization.assign_role(editor.id, editor_role.id)

# 3. Viewer - Can only read
viewer = Accounts.get_user_by_email("viewer@example.com")
viewer_role = Accounts.get_role_by_name("viewer")
Authorization.assign_role(viewer.id, viewer_role.id)

# 4. Librarian - Library-specific permissions
librarian = Accounts.get_user_by_email("librarian@example.com")
librarian_role = Accounts.get_role_by_name("librarian")
Authorization.assign_role(librarian.id, librarian_role.id, glam_type: "Library")
```

### Test Checklist for Each Module

- [ ] **Route Protection**: User without permission gets redirected
- [ ] **Mount Authorization**: Permission checked on page load
- [ ] **Action Authorization**: Create/Edit/Delete actions check permissions
- [ ] **UI Rendering**: Buttons show/hide based on permissions
- [ ] **Error Messages**: Clear feedback when access denied
- [ ] **Super Admin**: Can access everything
- [ ] **Role-based**: Different roles have appropriate access
- [ ] **Denied Permissions**: Explicit denials override role permissions

### Manual Testing Script

```bash
# 1. Login as super_admin
# - Should see all buttons and actions
# - Can create, edit, delete everything

# 2. Login as editor
# - Should see create, edit buttons
# - Should NOT see delete buttons
# - Delete actions should fail with permission error

# 3. Login as viewer
# - Should only see list/detail views
# - Should NOT see any action buttons
# - Any modify attempt should redirect with error

# 4. Test permission denial
# - Give user a role with permission
# - Explicitly deny that permission
# - User should NOT have access despite role
```

---

## Quick Implementation Guide for Remaining Modules

### For LiveView Modules:

1. **Add mount authorization:**
   ```elixir
   def mount(_params, _session, socket) do
     authorize!(socket, "appropriate.permission")
     # ... rest of mount
   end
   ```

2. **Add action authorization:**
   ```elixir
   defp apply_action(socket, :new, _params) do
     authorize!(socket, "resource.create")
     # ...
   end
   
   defp apply_action(socket, :edit, _) do
     authorize!(socket, "resource.update")
     # ...
   end
   ```

3. **Add event handler authorization:**
   ```elixir
   def handle_event("delete", %{"id" => id}, socket) do
     authorize!(socket, "resource.delete")
     # ...
   end
   ```

4. **Update templates:**
   - Wrap action buttons with `<%= if can?(@current_scope.user, "permission") do %>`

### For Controller Modules:

1. **Add authorization plug:**
   ```elixir
   plug VoileWeb.Plugs.Authorization, 
     permission: "resource.read"
     
   plug VoileWeb.Plugs.Authorization,
     permission: "resource.update"
     when action in [:edit, :update]
   ```

2. **Or check in actions:**
   ```elixir
   def create(conn, params) do
     authorize!(conn, "resource.create")
     # ... rest of action
   end
   ```

---

## Additional Permissions Recommendations

Consider adding these permissions to support all features:

### Master Data Permissions (Alternative to metadata.manage)
```sql
INSERT INTO permissions (name, resource, action, description) VALUES
('master.create', 'master', 'create', 'Create master data'),
('master.read', 'master', 'read', 'View master data'),
('master.update', 'master', 'update', 'Edit master data'),
('master.delete', 'master', 'delete', 'Delete master data');
```

### Circulation Permissions (for Library module)
```sql
INSERT INTO permissions (name, resource, action, description) VALUES
('circulation.checkout', 'circulation', 'checkout', 'Checkout items'),
('circulation.return', 'circulation', 'return', 'Return items'),
('circulation.renew', 'circulation', 'renew', 'Renew items'),
('reservations.create', 'reservations', 'create', 'Create reservations'),
('reservations.read', 'reservations', 'read', 'View reservations'),
('reservations.cancel', 'reservations', 'cancel', 'Cancel reservations'),
('fines.read', 'fines', 'read', 'View fines'),
('fines.waive', 'fines', 'waive', 'Waive fines');
```

---

## Notes

- All super_admin role should have all permissions assigned
- Permission checks are cached per request for performance
- Use `authorize!/2` to enforce (raises error if denied)
- Use `can?/2` to check conditionally (returns boolean)
- Explicit denials always override role permissions
- Document any new permissions added to the system

---

## Next Steps

1. ✅ Complete remaining LiveView modules (Master data, GLAM modules)
2. ✅ Add authorization to controller actions
3. ✅ Update all templates with conditional rendering
4. ⚠️ Add additional permissions if needed
5. ⚠️ Create test users with different permission sets
6. ⚠️ Perform thorough testing of all modules
7. ⚠️ Document permission requirements for users
8. ⚠️ Consider adding audit logging for permission checks

---

**Last Updated:** October 14, 2025
**Status:** In Progress - Core modules completed, remaining modules need implementation
