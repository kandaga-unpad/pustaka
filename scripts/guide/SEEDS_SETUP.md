# Authorization Seeds Setup

## Summary

I've integrated the authorization system seeds into your existing database seeding process. Now every time you run `mix ecto.reset` or `mix ecto.setup`, the roles and permissions will be automatically populated.

## What Was Changed

### 1. **priv/repo/seeds.exs** (NEW)
- Created a simple entry point that Mix will find
- Delegates to your actual seeds file in `priv/repo/seeds/seeds.exs`

### 2. **priv/repo/seeds/seeds.exs** (UPDATED)
- Added authorization seeds loading at the end of the file:
```elixir
# Load Authorization System (Roles and Permissions)
IO.puts("\n🔐 Loading Authorization System...")
Code.require_file("priv/repo/seeds/authorization_seeds.ex")
Voile.Repo.Seeds.AuthorizationSeeds.run()
```

### 3. **priv/repo/seeds/authorization_seeds.ex** (IMPROVED)
- Enhanced output formatting for better visibility
- Added detailed summary showing each role and its permission count
- Seeds are idempotent (safe to run multiple times)

### 4. **priv/repo/seeds/master.exs** (UPDATED)
- Creates member types (Administrator, Staff, Members, Guest)
- Creates admin user (admin@voile.id)
- Automatically assigns super_admin role to admin user

## What Gets Seeded

### Permissions (27 total)
- **Collections**: create, read, update, delete, publish, archive
- **Items**: create, read, update, delete, export, import
- **Metadata**: edit, manage
- **Users**: create, read, update, delete, manage_roles
- **Roles**: create, update, delete
- **Permissions**: manage
- **System**: settings, audit, backup

### Roles (5 total)
1. **super_admin** - Full system access (27 permissions)
2. **admin** - Administrative access without system settings (16 permissions)
3. **editor** - Can manage collections and items (11 permissions)
4. **contributor** - Can create and edit own content (5 permissions)
5. **viewer** - Read-only access (3 permissions)

### Member Types (6 total)
1. **Administrator** - System administrator with unlimited access
2. **Staff** - Library staff with extended borrowing privileges
3. **Member (Organization)** - Institutional membership
4. **Member (Verified)** - Verified individual member
5. **Member (Affirmation)** - Self-declared member
6. **Guest** - Temporary guest access

### Default Admin User
- **Email**: admin@voile.id
- **Username**: admin
- **Password**: super_long_password (⚠️ Change this immediately in production!)
- **Role**: super_admin
- **Member Type**: Administrator

## Usage

### Running Seeds

```bash
# Reset database and run all seeds (includes authorization)
mix ecto.reset

# Or manually run seeds
mix run priv/repo/seeds.exs

# Or run just authorization seeds
mix run priv/repo/seeds/authorization_seeds.ex

# Or run just master seeds (member types and admin user)
mix run priv/repo/seeds/master.exs
```

### Login as Admin

After seeding, you can login with:
- **Email**: admin@voile.id
- **Password**: super_long_password

⚠️ **IMPORTANT**: Change this password immediately after first login!

### Assign Roles to Users

After seeding, you can assign roles to users in IEx:

```elixir
# Start IEx
iex -S mix

# Assign super_admin to a user by email
alias VoileWeb.Auth.Authorization
alias Voile.Repo
alias Voile.Schema.Accounts.{User, Role}

# Get user and role
user = Repo.get_by(User, email: "admin@example.com")
role = Repo.get_by(Role, name: "super_admin")

# Assign role
{:ok, assignment} = Authorization.assign_role(user.id, role.id)
```

Or use the helper function from the seeds file:

```elixir
# In IEx
Code.require_file("priv/repo/seeds/authorization_seeds.ex")
Voile.Repo.Seeds.AuthorizationSeeds.assign_super_admin("admin@example.com")
```

### View Current Permissions and Roles

```elixir
# In IEx
Code.require_file("priv/repo/seeds/authorization_seeds.ex")

# List all permissions grouped by category
Voile.Repo.Seeds.AuthorizationSeeds.list_permissions()

# List all roles with their permissions
Voile.Repo.Seeds.AuthorizationSeeds.list_roles()
```

## Example Output

When you run `mix ecto.reset`, you'll see:

```
🔐 Seeding authorization system...
==================================================
  📋 Creating permissions...
  ✓ 27 permissions created/verified
  👥 Creating roles with permissions...
  ✓ 5 roles created/verified:
    • super_admin: 27 permissions
    • admin: 16 permissions
    • editor: 11 permissions
    • contributor: 5 permissions
    • viewer: 3 permissions
==================================================
✅ Authorization system seeded successfully!

👥 Loading Member Types and Admin User...
✅ Assigned super_admin role to admin@voile.id
```

## Important Notes

1. **Idempotent**: Seeds can be run multiple times safely. Existing permissions and roles will be updated, not duplicated.

2. **Permission Updates**: If you modify the permissions list in `PermissionManager.seed_default_roles()`, running the seeds again will update existing roles with the new permissions.

3. **User Assignments**: User role assignments are NOT reset when you run seeds. Only the roles and permissions themselves are created/updated.

4. **Custom Roles**: If you create custom roles in production, they will NOT be affected by running seeds. Only the 5 default roles are managed.

## Next Steps

1. Run `mix ecto.reset` to test the complete setup
2. Login with admin@voile.id / super_long_password
3. **CHANGE THE ADMIN PASSWORD** immediately!
4. Create additional users as needed
5. Assign appropriate roles to users
6. Test the authorization system in your application

## Reference

- Authorization Guide: `scripts/guide/AUTH_SYSTEM.md`
- RBAC Guide: `scripts/guide/RBAC_GUIDE.md`
- Implementation Summary: `scripts/guide/IMPLEMENTATION_SUMMARY.md`
