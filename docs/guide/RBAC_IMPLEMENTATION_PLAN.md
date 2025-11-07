# RBAC Implementation Plan

## Overview
This document outlines the implementation of Role-Based Access Control (RBAC) across all pages and modules in the Voile application.

## Permission Matrix

Based on the permissions table provided, here's the complete permission mapping:

### Collections Module
| Permission | Resource | Action | Description | Required For |
|-----------|----------|--------|-------------|--------------|
| collections.create | collections | create | Create new collections | New collection form, create actions |
| collections.read | collections | read | View collections | Collection list, view details |
| collections.update | collections | update | Edit collections | Edit form, update actions |
| collections.delete | collections | delete | Delete collections | Delete buttons, delete actions |
| collections.publish | collections | publish | Publish collections | Publish buttons/actions |
| collections.archive | collections | archive | Archive collections | Archive buttons/actions |

### Items Module
| Permission | Resource | Action | Description | Required For |
|-----------|----------|--------|-------------|--------------|
| items.create | items | create | Create new items | New item form, create actions |
| items.read | items | read | View items | Item list, view details |
| items.update | items | update | Edit items | Edit form, update actions |
| items.delete | items | delete | Delete items | Delete buttons, delete actions |
| items.export | items | export | Export items | Export functionality |
| items.import | items | import | Import items | Import functionality |

### Metadata Module
| Permission | Resource | Action | Description | Required For |
|-----------|----------|--------|-------------|--------------|
| metadata.edit | metadata | edit | Edit metadata fields | Metadata editing |
| metadata.manage | metadata | manage | Manage metadata schemas | Schema management |

### Users Module
| Permission | Resource | Action | Description | Required For |
|-----------|----------|--------|-------------|--------------|
| users.create | users | create | Create new users | New user form ✅ |
| users.read | users | read | View users | User list, view details ✅ |
| users.update | users | update | Edit users | Edit form, update actions ✅ |
| users.delete | users | delete | Delete users | Delete buttons ✅ |
| users.manage_roles | users | manage_roles | Manage user roles | Role assignment UI |

### Roles Module
| Permission | Resource | Action | Description | Required For |
|-----------|----------|--------|-------------|--------------|
| roles.create | roles | create | Create new roles | New role form ✅ |
| roles.update | roles | update | Edit roles | Edit form, manage permissions ✅ |
| roles.delete | roles | delete | Delete roles | Delete buttons ✅ |

### Permissions Module
| Permission | Resource | Action | Description | Required For |
|-----------|----------|--------|-------------|--------------|
| permissions.manage | permissions | manage | Manage permissions | All permission management ✅ |

### System Module
| Permission | Resource | Action | Description | Required For |
|-----------|----------|--------|-------------|--------------|
| system.settings | system | settings | Manage system settings | Settings pages |
| system.audit | system | audit | View audit logs | Audit log viewer |
| system.backup | system | backup | Perform system backups | Backup functionality |

## Implementation Status

### ✅ Already Implemented
1. **Users Management** (`/manage/settings/users`)
   - users.create, users.read, users.update, users.delete
   
2. **Roles Management** (`/manage/settings/roles`)
   - roles.create, roles.update, roles.delete
   
3. **Permissions Management** (`/manage/settings/permissions`)
   - permissions.manage
   
4. **Library Circulation** (Partial)
   - circulation.checkout, circulation.return, members.lookup

### ⚠️ Needs Implementation

#### 1. Collections Module (`/manage/catalog/collections`)
**Routes:**
- `/manage/catalog/collections` - Index (list)
- `/manage/catalog/collections/new` - New form
- `/manage/catalog/collections/:id` - Show details
- `/manage/catalog/collections/:id/edit` - Edit form
- `/manage/catalog/collections/:id/attachments` - Attachments

**Required Permissions:**
- `collections.read` - View collections list and details
- `collections.create` - Create new collections
- `collections.update` - Edit collections
- `collections.delete` - Delete collections
- `collections.publish` - Publish collections (if applicable)
- `collections.archive` - Archive collections (if applicable)

**Files to Update:**
- `lib/voile_web/live/dashboard/catalog/collection_live/index.ex`
- `lib/voile_web/live/dashboard/catalog/collection_live/show.ex`
- `lib/voile_web/live/dashboard/catalog/collection_live/form_component.ex`
- `lib/voile_web/live/dashboard/catalog/collection_live/attachments.ex`

#### 2. Items Module (`/manage/catalog/items`)
**Routes:**
- `/manage/catalog/items` - Index (list)
- `/manage/catalog/items/new` - New form
- `/manage/catalog/items/:id` - Show details
- `/manage/catalog/items/:id/edit` - Edit form

**Required Permissions:**
- `items.read` - View items list and details
- `items.create` - Create new items
- `items.update` - Edit items
- `items.delete` - Delete items
- `items.export` - Export items (if functionality exists)
- `items.import` - Import items (if functionality exists)

**Files to Update:**
- `lib/voile_web/live/dashboard/catalog/item_live/index.ex`
- `lib/voile_web/live/dashboard/catalog/item_live/show.ex`
- `lib/voile_web/live/dashboard/catalog/item_live/form_component.ex`

#### 3. Master Data Modules (`/manage/master/*`)
**Modules:**
- Creators (`/manage/master/creators`)
- Publishers (`/manage/master/publishers`)
- Member Types (`/manage/master/member_types`)
- Frequencies (`/manage/master/frequencies`)
- Locations (`/manage/master/locations`)
- Places (`/manage/master/places`)
- Topics (`/manage/master/topics`)

**Suggested Permissions:**
Since these are not in the original permission list, we should use:
- `metadata.manage` for all master data management
- OR create new permissions: `master.create`, `master.read`, `master.update`, `master.delete`

**Files to Update:**
- `lib/voile_web/live/dashboard/master/*`

#### 4. Metadata/Resource Management (`/manage/metaresource`)
**Routes:**
- `/manage/metaresource` - Main page
- `/manage/metaresource/metadata_vocabularies` - Vocabularies
- `/manage/metaresource/metadata_properties` - Properties
- `/manage/metaresource/resource_class` - Resource classes
- `/manage/metaresource/resource_template` - Templates

**Required Permissions:**
- `metadata.edit` - Edit metadata fields
- `metadata.manage` - Manage metadata schemas

**Files to Update:**
- `lib/voile_web/live/dashboard/metaresource/metaresource_live.ex`
- `lib/voile_web/controllers/vocabulary_controller.ex`
- `lib/voile_web/controllers/property_controller.ex`
- `lib/voile_web/controllers/resource_class_controller.ex`
- `lib/voile_web/controllers/resource_template_controller.ex`

#### 5. Settings Pages (`/manage/settings`)
**Routes:**
- `/manage/settings` - Settings index
- `/manage/settings/user_dashboard` - User dashboard
- `/manage/settings/holidays` - Holiday management

**Required Permissions:**
- `system.settings` - Manage system settings

**Files to Update:**
- `lib/voile_web/live/dashboard/settings/setting_live.ex`
- `lib/voile_web/live/dashboard/settings/holiday_live.ex`
- `lib/voile_web/live/users/manage/dashboard.ex`

#### 6. GLAM Modules
**Gallery** (`/manage/glam/gallery`)
**Archive** (`/manage/glam/archive`)
**Museum** (`/manage/glam/museum`)
**Library** (`/manage/glam/library`)

**Suggested Permissions:**
Use existing GLAM-specific role system or map to:
- `collections.read`, `collections.create`, `collections.update`, `collections.delete`
- `items.read`, `items.create`, `items.update`, `items.delete`

#### 7. Library Circulation (Complete Implementation)
**Routes:**
- `/manage/glam/library/circulation/transactions`
- `/manage/glam/library/circulation/reservations`
- `/manage/glam/library/circulation/requisitions`
- `/manage/glam/library/circulation/fines`
- `/manage/glam/library/circulation/circulation_history`

**Suggested New Permissions:**
- `circulation.transactions.create` - Checkout items
- `circulation.transactions.read` - View transactions
- `circulation.transactions.update` - Renew items
- `circulation.transactions.return` - Return items
- `circulation.reservations.create` - Create reservations
- `circulation.reservations.read` - View reservations
- `circulation.reservations.update` - Update reservations
- `circulation.requisitions.create` - Create requisitions
- `circulation.requisitions.read` - View requisitions
- `circulation.fines.read` - View fines
- `circulation.fines.update` - Waive or adjust fines

## Implementation Approach

### Step 1: Route-Level Protection (on_mount)
Protect entire route groups with permission checks:

```elixir
live_session :catalog_read,
  on_mount: [
    {VoileWeb.UserAuth, :require_authenticated_and_verified_staff_user},
    {VoileWeb.UserAuth, {:require_permission, "collections.read"}}
  ] do
  # Collection routes
end
```

### Step 2: LiveView mount/3 Checks
Add authorization in mount functions:

```elixir
def mount(_params, _session, socket) do
  authorize!(socket, "collections.read")
  # ... rest of mount logic
end
```

### Step 3: Action-Level Checks
Check permissions for specific actions:

```elixir
defp apply_action(socket, :new, _params) do
  authorize!(socket, "collections.create")
  # ... action logic
end

defp apply_action(socket, :edit, %{"id" => id}) do
  authorize!(socket, "collections.update")
  # ... action logic
end
```

### Step 4: Event Handler Checks
Protect event handlers:

```elixir
def handle_event("delete", %{"id" => id}, socket) do
  authorize!(socket, "collections.delete")
  # ... delete logic
end
```

### Step 5: Conditional UI Rendering
Show/hide UI elements based on permissions:

```heex
<%= if can?(@current_scope.user, "collections.create") do %>
  <.button phx-click="new">Create Collection</.button>
<% end %>

<%= if can?(@current_scope.user, "collections.delete") do %>
  <.button phx-click="delete" phx-value-id={@collection.id}>Delete</.button>
<% end %>
```

## Implementation Priority

### Phase 1: Critical Modules (High Priority)
1. ✅ Users Management - **DONE**
2. ✅ Roles Management - **DONE**
3. ✅ Permissions Management - **DONE**
4. **Collections Module** - Core functionality
5. **Items Module** - Core functionality

### Phase 2: Important Modules (Medium Priority)
6. **Metadata Management** - Schema and field management
7. **Master Data** - Supporting data
8. **Settings** - System configuration

### Phase 3: GLAM-Specific (Medium Priority)
9. **GLAM Modules** - Gallery, Archive, Museum, Library
10. **Circulation** - Complete library circulation system

### Phase 4: Additional Features (Low Priority)
11. **Audit Logging** - system.audit permission
12. **Backup** - system.backup permission
13. **Export/Import** - items.export, items.import

## Testing Checklist

For each module, verify:
- [ ] Route protection works (redirects unauthorized users)
- [ ] Mount checks prevent unauthorized access
- [ ] Action checks (new, edit, delete) work correctly
- [ ] Event handlers are protected
- [ ] UI elements show/hide based on permissions
- [ ] Error messages are user-friendly
- [ ] Permission denials are logged (if audit system exists)

## Notes

1. **Backward Compatibility**: Ensure super_admin role has all permissions
2. **Performance**: Permission checks are cached per request
3. **User Experience**: Show appropriate error messages
4. **Documentation**: Update user guides with permission requirements
5. **Testing**: Create test users with different permission sets

## Additional Permissions Needed

Consider adding these permissions to the database:
- `master.create`, `master.read`, `master.update`, `master.delete` - For master data
- `circulation.checkout`, `circulation.return`, `circulation.renew` - For library circulation
- `reservations.create`, `reservations.read`, `reservations.update`, `reservations.cancel`
- `requisitions.create`, `requisitions.read`, `requisitions.update`, `requisitions.approve`
- `fines.read`, `fines.update`, `fines.waive`
- `circulation_history.read` - For viewing circulation history
