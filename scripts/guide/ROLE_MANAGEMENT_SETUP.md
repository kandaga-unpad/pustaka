# Role Management Setup Checklist

Use this checklist to ensure your role management system is properly configured.

## ✅ Files Created

Verify these files exist:

- [ ] `lib/voile_web/live/users/role/role_manage_live.ex`
- [ ] `lib/voile_web/live/users/role/role_manage_show_live.ex`
- [ ] `lib/voile_web/live/users/role/role_manage_form_component.ex`
- [ ] `lib/voile_web/live/users/role/role_manage_edit_live.ex`

## ✅ Files Modified

Verify these files were updated:

- [ ] `lib/voile_web/router.ex` (added `/roles` routes)
- [ ] `lib/voile_web/components/voile_dashboard_components.ex` (added sidebar link)
- [ ] `lib/voile_web.ex` (updated authorization imports)

## ✅ Database Setup

Make sure your database has these tables with data:

### Check Tables Exist
Run in IEx:
```elixir
# Start IEx
iex -S mix

# Check tables
Voile.Repo.all(Voile.Schema.Accounts.Role) |> length()
Voile.Repo.all(Voile.Schema.Accounts.Permission) |> length()
```

Expected:
- Roles: At least 5 (super_admin, admin, editor, contributor, viewer)
- Permissions: At least 20+

### Seed Default Data (if needed)
```elixir
# If you don't have roles and permissions, seed them:
alias VoileWeb.Auth.PermissionManager

PermissionManager.seed_default_permissions()
PermissionManager.seed_default_roles()
```

Or run the seed file:
```bash
mix run priv/repo/seeds/authorization_seeds.ex
```

## ✅ Permissions Setup

Ensure your admin user has the required permissions:

```elixir
# In IEx
alias VoileWeb.Auth.Authorization
alias VoileWeb.Auth.PermissionManager

# Get your admin user
user = Voile.Repo.get_by(Voile.Schema.Accounts.User, email: "your-admin@email.com")

# Check if user has super_admin role
Authorization.can?(user, "roles.create")
Authorization.can?(user, "roles.update")
Authorization.can?(user, "roles.delete")
Authorization.can?(user, "permissions.manage")
```

### Grant Permissions (if needed)
```elixir
# Get the super_admin role
super_admin = Voile.Repo.get_by(Voile.Schema.Accounts.Role, name: "super_admin")

# Assign to your user
Authorization.assign_role(user.id, super_admin.id)
```

## ✅ Compilation Check

Verify the code compiles without errors:

```bash
mix compile --force
```

Expected output: No errors or warnings

## ✅ Route Verification

Check that routes are registered:

```bash
mix phx.routes | grep roles
```

Expected output:
```
GET     /manage/settings/roles
GET     /manage/settings/roles/new
GET     /manage/settings/roles/:id
GET     /manage/settings/roles/:id/show/edit
GET     /manage/settings/roles/:id/show/permissions
GET     /manage/settings/roles/:id/edit
```

## ✅ Start Application

Start your Phoenix server:

```bash
mix phx.server
```

Expected: Server starts without errors on port 4000

## ✅ Access Tests

With the application running, verify access:

### 1. Check Settings Page
- [ ] Navigate to `/manage/settings`
- [ ] Verify "Role Management" link appears in sidebar

### 2. Check Role List
- [ ] Navigate to `/manage/settings/roles`
- [ ] See list of roles
- [ ] Search functionality works
- [ ] "New Role" button appears (if you have permission)

### 3. Test Role Creation
- [ ] Click "New Role"
- [ ] Modal opens with form
- [ ] Can enter name and description
- [ ] Can select permissions
- [ ] Form validates (try empty name)
- [ ] "Save Role" creates the role

### 4. Test Role Details
- [ ] Click on a role from the list
- [ ] Role details page loads
- [ ] Permissions are displayed
- [ ] User list is shown
- [ ] "Edit Role" button works
- [ ] "Manage Permissions" button works

### 5. Test Permission Management
- [ ] On role detail page, click "Manage Permissions"
- [ ] Permission modal opens
- [ ] All permissions listed with toggle switches
- [ ] Toggle a permission (should save immediately)
- [ ] Close modal and verify permission changed

### 6. Test User Assignment
- [ ] On role detail page, click "Add User"
- [ ] User search form appears
- [ ] Type a user's name (at least 2 characters)
- [ ] User appears in search results
- [ ] Click "Add" button
- [ ] User added to role successfully
- [ ] User appears in assigned users list
- [ ] Click "Remove" to unassign user

### 7. Test Role Editing
- [ ] Click "Edit Role" on role detail page
- [ ] Modal opens with current values
- [ ] Change name or description
- [ ] Save changes
- [ ] Modal closes and changes persist

### 8. Test Role Deletion
- [ ] Try to delete a system role (should fail)
- [ ] Try to delete a role with users (should fail)
- [ ] Create a new role without users
- [ ] Delete it (should succeed)

### 9. Test Search
- [ ] On role list page, type in search
- [ ] Results filter in real-time
- [ ] Loading spinner appears briefly
- [ ] Clear search shows all roles

### 10. Test Permissions
- [ ] Log in as a user without role permissions
- [ ] Try to access `/manage/settings/roles`
- [ ] Should be denied or redirected

## ✅ Visual Verification

Check UI elements:

- [ ] Dark mode works correctly
- [ ] Badges show for system roles
- [ ] Permission counts display
- [ ] User counts display
- [ ] Icons render properly (Heroicons)
- [ ] Loading spinners work
- [ ] Flash messages appear
- [ ] Modals open and close smoothly
- [ ] Forms are responsive
- [ ] Mobile view works

## ✅ Error Handling

Test error scenarios:

- [ ] Try to create role with duplicate name (should fail)
- [ ] Try to create role with empty name (should fail)
- [ ] Try to delete system role (should show error)
- [ ] Try to delete role with users (should show error)
- [ ] Try to access without permission (should deny)

## 🔧 Common Issues and Fixes

### Issue: Routes not found
**Fix:** Restart the Phoenix server after adding routes

### Issue: "Function can?/2 is undefined"
**Fix:** Check that `lib/voile_web.ex` was updated with new imports

### Issue: Sidebar link doesn't appear
**Fix:** Verify `voile_dashboard_components.ex` was updated

### Issue: "Permission denied" everywhere
**Fix:** Make sure your user has the required permissions (see Permissions Setup above)

### Issue: No roles or permissions in database
**Fix:** Run the seed commands to populate default data

### Issue: Can't assign users to roles
**Fix:** Verify the `user_role_assignments` table exists

### Issue: Permissions not saving
**Fix:** Check that the `role_permissions` table exists and has no conflicts

### Issue: Search not working
**Fix:** Ensure JavaScript is enabled and check browser console for errors

## 📊 Success Criteria

Your role management system is working correctly if:

✅ You can view the list of roles  
✅ You can create a new role with permissions  
✅ You can edit an existing role  
✅ You can add and remove permissions from a role  
✅ You can assign users to a role  
✅ You can remove users from a role  
✅ System roles are protected from deletion  
✅ Roles with users cannot be deleted  
✅ Search filters roles correctly  
✅ All UI elements render properly  
✅ Permission checks work (access denied when appropriate)  

## 📝 Notes

- The module naming follows: `VoileWeb.Users.Role.ManageLive.*`
- All routes are under `/manage/settings/roles`
- The sidebar link is in the Settings section
- Dark mode is fully supported
- All operations require appropriate permissions

## 🎯 Next Actions

After verification:

1. **Create some test roles** to familiarize yourself with the system
2. **Assign roles to test users** to verify permission inheritance works
3. **Test permission changes** to see immediate effect on users
4. **Review the documentation** in `scripts/guide/` for advanced usage
5. **Consider customizations** based on your specific needs

## 📚 Documentation References

- `ROLE_MANAGEMENT_GUIDE.md` - Complete feature documentation
- `ROLE_MANAGEMENT_QUICK_REF.md` - Quick reference guide
- `ROLE_MANAGEMENT_IMPLEMENTATION.md` - Implementation summary
- `RBAC_GUIDE.md` - RBAC system documentation
- `AUTH_SYSTEM.md` - Authorization system overview

---

**Last Updated:** October 6, 2025  
**Status:** Ready for testing
