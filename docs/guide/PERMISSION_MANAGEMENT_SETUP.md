# Permission Management Setup Checklist

## ✅ Files Created

Verify these files exist:

- [x] `lib/voile_web/live/users/permission/permission_manage_live.ex`
- [x] `lib/voile_web/live/users/permission/permission_manage_show_live.ex`
- [x] `lib/voile_web/live/users/permission/permission_manage_form_component.ex`
- [x] `lib/voile_web/live/users/permission/permission_manage_edit_live.ex`

## ✅ Files Modified

Verify these files were updated:

- [x] `lib/voile_web/router.ex` (added `/permissions` routes)
- [x] `lib/voile_web/components/voile_dashboard_components.ex` (added sidebar link)
- [x] `lib/voile_web/auth/permission_manager.ex` (added `get_permission/1`)

## ✅ Documentation Created

- [x] `scripts/guide/PERMISSION_MANAGEMENT_IMPLEMENTATION.md`
- [x] `scripts/guide/PERMISSION_MANAGEMENT_QUICK_REF.md`

## 🧪 Testing Steps

### 1. Access the Permission Management Page

```
Navigate to: http://localhost:4000/manage/settings/permissions
```

Expected: You see a list of all permissions

### 2. Test Search Functionality

```
1. Type in the search box
2. Wait for results to filter
```

Expected: Permissions are filtered based on your query

### 3. Create a New Permission

```
1. Click "New Permission" button
2. Fill in:
   - Name: test.feature
   - Resource: test
   - Action: feature
   - Description: Test permission for new feature
3. Click "Create Permission"
```

Expected: Permission is created and appears in the list

### 4. View Permission Details

```
1. Click on any permission row
```

Expected: You see permission details and roles that have it

### 5. Edit a Permission

```
1. From the details page, click "Edit Permission"
   OR
2. From the list page, click "Edit" in the actions column
3. Modify the description
4. Click "Update Permission"
```

Expected: Permission is updated successfully

### 6. Try to Delete a Permission in Use

```
1. Go to permission list
2. Click "Delete" on a permission used by roles (e.g., collections.create)
3. Confirm deletion
```

Expected: Error message "Cannot delete permission that is assigned to N role(s)"

### 7. Delete an Unused Permission

```
1. Delete the test.feature permission you created
2. Confirm deletion
```

Expected: Permission is deleted successfully

### 8. Check Dark Mode

```
1. Toggle dark mode in the UI
2. Navigate through permission pages
```

Expected: All pages display correctly in dark mode

## 🔐 Permission Requirements

To access permission management, users need:

```elixir
"permissions.manage"
```

### Grant Permission to a Role

```elixir
# In IEx or seeds
alias VoileWeb.Auth.PermissionManager

permission = PermissionManager.get_permission_by_name("permissions.manage")
role = PermissionManager.get_role(your_role_id)

PermissionManager.add_permission_to_role(role.id, permission.id)
```

### Or assign to super_admin role

The super_admin role should already have this permission. Ensure your user has the super_admin role.

## 🗄️ Database Verification

Verify permissions exist in the database:

```elixir
# In IEx
alias Voile.Repo
alias Voile.Schema.Accounts.Permission

# Count permissions
Repo.aggregate(Permission, :count, :id)

# List all permissions
Repo.all(Permission) |> Enum.map(& &1.name)
```

If no permissions exist, seed them:

```bash
mix run priv/repo/seeds/authorization_seeds.ex
```

## 🎨 Visual Verification Checklist

- [ ] Permission list displays in a table
- [ ] Resource badges are blue
- [ ] Action badges are green
- [ ] Search box is visible and functional
- [ ] "New Permission" button appears (if you have permissions.manage)
- [ ] Edit and Delete links appear in action columns
- [ ] Detail page shows all permission information
- [ ] Roles with permission are listed and linkable
- [ ] Edit page has the form and shows related roles
- [ ] Dark mode colors look correct
- [ ] Sidebar shows "Permission Management" link
- [ ] Icons display correctly (key icon for permissions)

## 🚨 Troubleshooting

### "Unauthorized" Error

**Problem:** User doesn't have `permissions.manage` permission

**Solution:**

```elixir
# Grant permission to your user through a role
# 1. Find your user's role
# 2. Add permissions.manage to that role
# OR log in with super_admin account
```

### No Permissions Showing

**Problem:** Database has no permissions seeded

**Solution:**

```bash
mix run priv/repo/seeds/authorization_seeds.ex
```

### Compilation Errors

**Problem:** Module not found or undefined function

**Solution:**

```bash
# Recompile
mix compile --force

# Or restart server
mix phx.server
```

### Routes Not Found

**Problem:** Routes not loaded

**Solution:**

```bash
# Restart Phoenix server
# Press Ctrl+C twice, then:
mix phx.server
```

### Styles Not Applying

**Problem:** Tailwind not compiled

**Solution:**

```bash
# Compile assets
mix assets.deploy

# Or restart with asset watching
mix phx.server
```

## 📊 Success Criteria

Your permission management system is fully functional if:

✅ You can access `/manage/settings/permissions`  
✅ Permissions are listed in the table  
✅ You can search and filter permissions  
✅ You can create new permissions  
✅ You can view permission details  
✅ You can edit permissions  
✅ You can delete unused permissions  
✅ Deleting used permissions shows an error  
✅ Roles are shown on permission detail page  
✅ Links to roles work correctly  
✅ Dark mode displays properly  
✅ Sidebar link is visible and works  
✅ Permission checks prevent unauthorized access

## 🎯 Quick Start Commands

```bash
# Start the server
mix phx.server

# Navigate to permissions
# http://localhost:4000/manage/settings/permissions

# If you get unauthorized:
# 1. Log in with super_admin account
# 2. Or grant permissions.manage to your role
```

## 📝 Notes

- Permission format must be `resource.action` (lowercase, underscore allowed)
- Permissions in use cannot be deleted
- All operations require `permissions.manage` permission
- Changes are immediate (no restart needed)
- Search is debounced for better performance
- Module naming: `VoileWeb.Users.Permission.ManageLive.*`

## 🔄 Integration Points

The permission management integrates with:

1. **Role Management** - View which roles have permissions
2. **User Management** - Users get permissions through roles
3. **Authorization System** - These permissions control access
4. **Settings Sidebar** - Listed in settings navigation

## 📚 Additional Documentation

- `PERMISSION_MANAGEMENT_IMPLEMENTATION.md` - Detailed implementation guide
- `PERMISSION_MANAGEMENT_QUICK_REF.md` - Quick reference for developers
- `RBAC_GUIDE.md` - RBAC system documentation
- `ROLE_MANAGEMENT_GUIDE.md` - Related role management documentation

---

**Status:** ✅ Permission Management System Complete and Ready to Use
