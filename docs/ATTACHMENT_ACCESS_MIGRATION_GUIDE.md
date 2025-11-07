# Attachment RBAC Migration Guide

## Pre-Migration Checklist

Before running the migration, ensure:

- [ ] Database backup completed
- [ ] Application is in maintenance mode (if needed)
- [ ] All developers are aware of the changes
- [ ] Phoenix and Ecto dependencies are up to date

## Migration Steps

### Step 1: Run the Database Migration

```bash
mix ecto.migrate
```

This will:
- Add new columns to the `attachments` table
- Create `attachment_role_access` table
- Create `attachment_user_access` table
- Add appropriate indexes and constraints

### Step 2: Verify Migration

```bash
mix ecto.migrations
```

Expected output should show the migration as "up":
```
Status    Migration ID    Migration Name
--------------------------------------------------
up        20250819090900  create_attachments_
up        20250819090901  add_rbac_to_attachments
```

### Step 3: Check Database Schema

Connect to your database and verify:

```sql
-- Check new columns exist
SELECT column_name, data_type, column_default 
FROM information_schema.columns 
WHERE table_name = 'attachments' 
AND column_name IN ('access_level', 'embargo_start_date', 'embargo_end_date');

-- Check new tables exist
SELECT table_name 
FROM information_schema.tables 
WHERE table_name IN ('attachment_role_access', 'attachment_user_access');
```

## Default Values

All existing attachments will have:
- `access_level` = `'public'` (default)
- `embargo_start_date` = `NULL` (no embargo)
- `embargo_end_date` = `NULL` (no embargo)
- `access_settings_updated_by_id` = `NULL` (not set)
- `access_settings_updated_at` = `NULL` (not set)

**This means all existing attachments remain publicly accessible - no breaking changes!**

## Post-Migration Configuration

### Option 1: Keep Everything Public (No Action Needed)
If you want all existing attachments to remain public, no further action is required.

### Option 2: Restrict Specific Attachments
If you need to restrict access to certain attachments, use the admin interface or run scripts:

```elixir
# Example: Make all attachments for a specific collection limited to staff
alias Voile.Catalog.AttachmentAccess
alias Voile.Schema.Catalog.Attachment
alias Voile.Repo

# Get the staff role
staff_role = Repo.get_by!(Role, name: "staff")

# Get attachments for a specific collection
collection_id = "your-collection-uuid"
attachments = 
  Attachment
  |> Attachment.for_entity(collection_id, "collection")
  |> Repo.all()

# Update each attachment
Enum.each(attachments, fn attachment ->
  # Change to limited access
  {:ok, updated} = AttachmentAccess.update_access_control(
    attachment,
    %{access_level: "limited"},
    admin_user
  )
  
  # Grant access to staff role
  AttachmentAccess.grant_role_access(updated.id, staff_role.id)
end)
```

### Option 3: Bulk Migration Script
For large-scale changes, create a migration script:

```elixir
# priv/repo/scripts/configure_attachment_access.exs

alias Voile.Catalog.AttachmentAccess
alias Voile.Schema.Catalog.Attachment
alias Voile.Schema.Accounts.{Role, User}
alias Voile.Repo
import Ecto.Query

# Configuration
config = %{
  # Make research collection limited to researchers
  research_collection_id: "uuid-here",
  researcher_role_name: "researcher",
  
  # Make admin docs restricted
  admin_collection_id: "uuid-here",
  
  # Set embargo for upcoming publication
  publication_collection_id: "uuid-here",
  publication_date: ~U[2025-12-01 00:00:00Z]
}

# Get admin user for audit trail
admin_user = Repo.get_by!(User, email: "admin@example.com")

# Configure research collection
IO.puts("Configuring research collection...")
researcher_role = Repo.get_by!(Role, name: config.researcher_role_name)
research_attachments = 
  Attachment
  |> Attachment.for_entity(config.research_collection_id, "collection")
  |> Repo.all()

Enum.each(research_attachments, fn att ->
  {:ok, updated} = AttachmentAccess.update_access_control(
    att,
    %{access_level: "limited"},
    admin_user
  )
  AttachmentAccess.grant_role_access(updated.id, researcher_role.id)
  IO.puts("  ✓ #{att.original_name}")
end)

# Configure admin collection
IO.puts("\nConfiguring admin collection...")
admin_attachments = 
  Attachment
  |> Attachment.for_entity(config.admin_collection_id, "collection")
  |> Repo.all()

Enum.each(admin_attachments, fn att ->
  {:ok, _} = AttachmentAccess.update_access_control(
    att,
    %{access_level: "restricted"},
    admin_user
  )
  IO.puts("  ✓ #{att.original_name}")
end)

# Configure publication embargo
IO.puts("\nConfiguring publication embargo...")
publication_attachments = 
  Attachment
  |> Attachment.for_entity(config.publication_collection_id, "collection")
  |> Repo.all()

Enum.each(publication_attachments, fn att ->
  {:ok, _} = AttachmentAccess.update_access_control(
    att,
    %{embargo_start_date: config.publication_date},
    admin_user
  )
  IO.puts("  ✓ #{att.original_name}")
end)

IO.puts("\n✓ Configuration complete!")
```

Run the script:
```bash
mix run priv/repo/scripts/configure_attachment_access.exs
```

## Rollback Plan

If you need to rollback the migration:

```bash
mix ecto.rollback
```

This will:
- Drop `attachment_role_access` table
- Drop `attachment_user_access` table  
- Remove new columns from `attachments` table
- Restore previous schema

**Note**: If you've added access grants, they will be lost on rollback.

## Application Code Updates

### Update Attachment Queries
Wherever you query attachments that should respect access control:

**Before:**
```elixir
attachments = 
  Attachment
  |> Attachment.for_entity(entity_id, entity_type)
  |> Repo.all()
```

**After:**
```elixir
attachments = 
  Attachment
  |> Attachment.for_entity(entity_id, entity_type)
  |> AttachmentAccess.accessible_by(current_user)  # Add this line
  |> Repo.all()
```

### Update Download/View Actions
Add access checks before serving files:

**Before:**
```elixir
def download(conn, %{"id" => id}) do
  attachment = Repo.get!(Attachment, id)
  send_file(conn, 200, attachment.file_path)
end
```

**After:**
```elixir
def download(conn, %{"id" => id}) do
  attachment = Repo.get!(Attachment, id)
  current_user = conn.assigns.current_scope[:user]
  
  if AttachmentAccess.can_access?(attachment, current_user) do
    send_file(conn, 200, attachment.file_path)
  else
    conn
    |> put_flash(:error, "Access denied")
    |> redirect(to: ~p"/")
  end
end
```

### Update Admin Interfaces
Add forms to manage access control settings (see Quick Reference guide).

## Testing After Migration

### Test 1: Verify Public Access Still Works
```bash
# As anonymous user, access a public attachment
curl http://localhost:4000/attachments/{id}/download
# Should succeed
```

### Test 2: Verify Limited Access Works
```elixir
# In IEx
attachment = Repo.get!(Attachment, "some-id")
AttachmentAccess.update_access_control(attachment, %{access_level: "limited"}, admin_user)

# Try accessing without role
AttachmentAccess.can_access?(attachment, regular_user)
# Should return false

# Grant access
AttachmentAccess.grant_role_access(attachment.id, role.id)

# Try accessing with role
AttachmentAccess.can_access?(attachment, user_with_role)
# Should return true
```

### Test 3: Verify Embargo Works
```elixir
future = DateTime.utc_now() |> DateTime.add(7, :day)
AttachmentAccess.update_access_control(
  attachment, 
  %{embargo_start_date: future}, 
  admin_user
)

AttachmentAccess.can_access?(attachment, user)
# Should return false (under embargo)
```

## Monitoring

After deployment, monitor:

1. **Error Logs**: Look for access denied errors
2. **User Reports**: Users reporting unexpected access issues
3. **Performance**: Check query performance with new joins
4. **Database Size**: Monitor growth of access tables

## Common Issues and Solutions

### Issue: Users can't access previously public attachments
**Solution**: Check if access_level was accidentally changed. Reset to public:
```elixir
attachment
|> Ecto.Changeset.change(access_level: "public")
|> Repo.update!()
```

### Issue: Performance degradation on attachment queries
**Solution**: Ensure indexes are created properly:
```sql
-- Verify indexes exist
SELECT indexname, indexdef 
FROM pg_indexes 
WHERE tablename IN ('attachments', 'attachment_role_access', 'attachment_user_access');
```

### Issue: Access grants not working
**Solution**: Verify role/user relationships are preloaded:
```elixir
# Always preload when checking access for multiple attachments
user = Repo.preload(user, :roles)
```

## Documentation Updates Needed

- [ ] Update API documentation
- [ ] Update user manual
- [ ] Create admin guide for managing access
- [ ] Update developer onboarding docs

## Support Contacts

For issues with the migration:
1. Check documentation in `docs/` folder
2. Review test examples in `test/voile/catalog/attachment_access_test.exs`
3. Contact development team

## Timeline Recommendation

- **Week 1**: Deploy migration to staging
- **Week 2**: Test thoroughly in staging
- **Week 3**: Train staff on new features
- **Week 4**: Deploy to production
- **Week 5**: Monitor and adjust

## Conclusion

The migration is designed to be **non-breaking**:
- All existing attachments default to public
- No immediate action required
- Access control can be configured gradually
- Full backward compatibility maintained

Take your time configuring access levels based on your organization's needs.
