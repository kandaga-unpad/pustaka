# Admin User Setup - Quick Reference

## Default Admin User

After running `mix ecto.reset`, you'll have a default admin user:

### Login Credentials
- **Email**: `admin@voile.id`
- **Username**: `admin`
- **Password**: `super_long_password`

### Assigned Permissions
- **Role**: `super_admin` (27 permissions)
- **Member Type**: `Administrator`

## ⚠️ Security Warning

**CHANGE THE PASSWORD IMMEDIATELY** after first login!

The default password is for development purposes only and should NEVER be used in production.

## What Happens During Seeding

1. **Permissions Created** (27 total)
   - Collections, Items, Metadata, Users, Roles, System

2. **Roles Created** (5 total)
   - super_admin, admin, editor, contributor, viewer

3. **Member Types Created** (6 total)
   - Administrator, Staff, Member (Org), Member (Verified), Member (Affirmation), Guest

4. **Admin User Created**
   - Email: admin@voile.id
   - Automatically assigned super_admin role
   - Member type: Administrator

## Verify Setup

After seeding, verify in IEx:

```elixir
# Start IEx
iex -S mix

# Check admin user exists
alias Voile.Repo
alias Voile.Schema.Accounts.User
alias VoileWeb.Auth.Authorization

user = Repo.get_by(User, email: "admin@voile.id")
user = Repo.preload(user, [:user_role_assignments, :roles])

# Should show super_admin role
IO.inspect(user.roles, label: "Admin Roles")

# Check permissions
Authorization.can?(user, "system.settings")
# => true

Authorization.can?(user, "collections.delete")
# => true
```

## Troubleshooting

### Admin user created but no role assigned

If you see this message:
```
⚠️  super_admin role not found. Please run authorization seeds first.
```

**Solution**: The authorization seeds must run BEFORE master.exs. This is already configured in seeds.exs.

### Role already assigned

If you see:
```
ℹ️  Admin user already has super_admin role
```

This is normal when running seeds multiple times. The seeds are idempotent.

## Adding More Admins

To create additional admin users with super_admin role:

```elixir
# In IEx
alias Voile.Repo
alias Voile.Schema.Accounts.{User, Role}
alias VoileWeb.Auth.Authorization

# Create new user
{:ok, new_admin} = %User{}
|> User.registration_changeset(%{
  email: "newadmin@example.com",
  username: "newadmin",
  fullname: "New Admin",
  password: "another_super_long_password",
  user_type_id: admin_member_type_id,
  node_id: 20
}, hash_password: true)
|> Repo.insert()

# Assign super_admin role
super_admin = Repo.get_by(Role, name: "super_admin")
{:ok, _} = Authorization.assign_role(new_admin.id, super_admin.id)
```

## Related Files

- Main seeds: `priv/repo/seeds/seeds.exs`
- Master seeds: `priv/repo/seeds/master.exs`
- Authorization seeds: `priv/repo/seeds/authorization_seeds.ex`
- Full documentation: `scripts/guide/SEEDS_SETUP.md`
