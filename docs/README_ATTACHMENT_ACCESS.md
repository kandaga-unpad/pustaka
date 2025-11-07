# Attachment Access Control - Complete Package

This package implements comprehensive Role-Based Access Control (RBAC) and embargo functionality for attachments in the Voile application.

## 🎯 Features

- ✅ **Three Access Levels**: Public, Limited, Restricted
- ✅ **Embargo System**: Time-based access control with start/end dates
- ✅ **Role-Based Access**: Grant access to entire roles
- ✅ **User-Specific Access**: Grant access to individual users
- ✅ **Audit Trail**: Track who modified access settings and when
- ✅ **Super Admin Override**: Admins bypass all restrictions
- ✅ **Bulk Operations**: Efficiently manage access for multiple attachments
- ✅ **Query Helpers**: Filter attachments by accessibility
- ✅ **Comprehensive Tests**: Full test coverage included

## 📦 What's Included

### Database Schema
- Migration file with new tables and fields
- Proper indexes and constraints
- Foreign key relationships

### Application Code
- `Attachment` schema with access control fields
- `AttachmentRoleAccess` schema for role-based permissions
- `AttachmentUserAccess` schema for user-specific permissions
- `AttachmentAccess` context with comprehensive access control logic

### Documentation
- **Implementation Summary**: Overview of the system
- **Access Control Guide**: Comprehensive usage documentation
- **Quick Reference**: Common use cases and code snippets
- **Flow Diagrams**: Visual representation of access control logic
- **Migration Guide**: Step-by-step migration instructions

### Tests
- Complete test suite covering all features
- Examples of usage patterns
- Test helpers for your own tests

## 🚀 Quick Start

### 1. Run Migration
```bash
mix ecto.migrate
```

### 2. Check Access in Your Code
```elixir
if AttachmentAccess.can_access?(attachment, current_user) do
  # Serve file
else
  # Show access denied
end
```

### 3. Filter Queries
```elixir
attachments = 
  Attachment
  |> Attachment.for_entity(collection_id, "collection")
  |> AttachmentAccess.accessible_by(current_user)
  |> Repo.all()
```

## 📚 Documentation Files

| File | Purpose |
|------|---------|
| `ATTACHMENT_RBAC_IMPLEMENTATION_SUMMARY.md` | Complete overview of implementation |
| `ATTACHMENT_ACCESS_CONTROL.md` | Comprehensive usage guide |
| `ATTACHMENT_ACCESS_QUICK_REFERENCE.md` | Common patterns and code snippets |
| `ATTACHMENT_ACCESS_FLOW_DIAGRAMS.md` | Visual flow charts and diagrams |
| `ATTACHMENT_ACCESS_MIGRATION_GUIDE.md` | Migration and deployment guide |
| `README_ATTACHMENT_ACCESS.md` | This file |

## 🔑 Access Levels Explained

### Public (Default)
- Anyone can view
- No authentication required
- Respects embargo dates

```elixir
# Default - no configuration needed
attachment = create_attachment(%{...})
```

### Limited
- Requires authentication
- Access granted by role OR user
- Respects embargo dates

```elixir
attachment = create_attachment(%{access_level: "limited"})
AttachmentAccess.grant_role_access(attachment.id, staff_role.id)
```

### Restricted
- Only super_admin can view
- Highest security level
- Respects embargo dates (except for super_admin)

```elixir
AttachmentAccess.update_access_control(
  attachment,
  %{access_level: "restricted"},
  admin_user
)
```

## 📅 Embargo Patterns

### Available After Date
```elixir
AttachmentAccess.update_access_control(
  attachment,
  %{embargo_start_date: ~U[2025-12-01 00:00:00Z]},
  admin_user
)
```

### Available Until Date
```elixir
AttachmentAccess.update_access_control(
  attachment,
  %{embargo_end_date: ~U[2025-12-31 23:59:59Z]},
  admin_user
)
```

### Available During Window
```elixir
AttachmentAccess.update_access_control(
  attachment,
  %{
    embargo_start_date: ~U[2025-11-01 00:00:00Z],
    embargo_end_date: ~U[2025-11-30 23:59:59Z]
  },
  admin_user
)
```

## 🔐 Security Features

1. **Database-Level Constraints**: Invalid values rejected at DB level
2. **Automatic Audit Trail**: Changes tracked with user and timestamp
3. **Cascade Deletes**: Access grants removed when attachment deleted
4. **No Direct Access**: All access through controlled functions
5. **Super Admin Override**: Emergency access always available
6. **Embargo Validation**: Start date must be before end date

## 🧪 Testing

Run the comprehensive test suite:
```bash
mix test test/voile/catalog/attachment_access_test.exs
```

Example tests included for:
- Public, limited, and restricted access
- Role-based permissions
- User-specific permissions  
- Embargo functionality
- Super admin override
- Bulk operations
- Query filtering

## 📊 Access Control Matrix

| User Type | Public | Limited (w/ access) | Limited (no access) | Restricted | Under Embargo |
|-----------|--------|---------------------|---------------------|------------|---------------|
| Anonymous | ✓ | ✗ | ✗ | ✗ | ✗ |
| Regular User | ✓ | ✓ | ✗ | ✗ | ✗ |
| Staff (w/ role) | ✓ | ✓ | ✗ | ✗ | ✗ |
| Super Admin | ✓ | ✓ | ✓ | ✓ | ✓ |

## 🎓 Common Use Cases

### 1. Public Documents
**Use Case**: General catalog items, brochures, public resources  
**Configuration**: Default (no action needed)

### 2. Staff-Only Documents
**Use Case**: Internal procedures, staff manuals  
**Configuration**: 
```elixir
attachment = create_attachment(%{access_level: "limited"})
AttachmentAccess.grant_role_access(attachment.id, staff_role.id)
```

### 3. Research Papers with Embargo
**Use Case**: Academic publications before release date  
**Configuration**:
```elixir
AttachmentAccess.update_access_control(
  attachment,
  %{
    access_level: "public",
    embargo_start_date: publication_date
  },
  admin_user
)
```

### 4. Conference Materials
**Use Case**: Event materials only during event  
**Configuration**:
```elixir
AttachmentAccess.update_access_control(
  attachment,
  %{
    embargo_start_date: event_start,
    embargo_end_date: event_end
  },
  admin_user
)
```

### 5. Restricted Admin Documents
**Use Case**: Sensitive system documentation  
**Configuration**:
```elixir
AttachmentAccess.update_access_control(
  attachment,
  %{access_level: "restricted"},
  admin_user
)
```

### 6. Guest Access
**Use Case**: External reviewers, temporary collaborators  
**Configuration**:
```elixir
AttachmentAccess.grant_user_access(
  attachment.id,
  guest_user.id,
  admin_user.id
)
```

## 🔧 Integration Examples

### LiveView
```elixir
def mount(%{"id" => id}, _session, socket) do
  attachments = 
    Attachment
    |> Attachment.for_entity(id, "collection")
    |> AttachmentAccess.accessible_by(socket.assigns.current_scope.user)
    |> Repo.all()
  
  {:ok, assign(socket, attachments: attachments)}
end
```

### Controller
```elixir
def download(conn, %{"id" => id}) do
  attachment = Repo.get!(Attachment, id)
  
  if AttachmentAccess.can_access?(attachment, conn.assigns.current_scope.user) do
    send_file(conn, 200, attachment.file_path)
  else
    conn
    |> put_flash(:error, "Access denied")
    |> redirect(to: ~p"/")
  end
end
```

### Template
```heex
<div :for={attachment <- @attachments}>
  <%= if AttachmentAccess.can_access?(attachment, @current_scope.user) do %>
    <.link href={~p"/attachments/#{attachment.id}/download"}>
      Download {attachment.original_name}
    </.link>
  <% else %>
    <span class="text-gray-500">Access Restricted</span>
  <% end %>
</div>
```

## 📈 API Reference

### Core Functions

```elixir
# Check if user can access attachment
AttachmentAccess.can_access?(attachment, user)
# => true | false

# Update access control settings
AttachmentAccess.update_access_control(attachment, attrs, admin_user)
# => {:ok, attachment} | {:error, changeset}

# Grant role-based access
AttachmentAccess.grant_role_access(attachment_id, role_id)
# => {:ok, struct} | {:error, changeset}

# Grant user-specific access
AttachmentAccess.grant_user_access(attachment_id, user_id, granted_by_id)
# => {:ok, struct} | {:error, changeset}

# Revoke access
AttachmentAccess.revoke_role_access(attachment_id, role_id)
AttachmentAccess.revoke_user_access(attachment_id, user_id)
# => {count, nil}

# Bulk operations
AttachmentAccess.bulk_grant_role_access(attachment_ids, role_id)
AttachmentAccess.bulk_grant_user_access(attachment_ids, user_id, granted_by_id)
# => {count, nil}

# Query filtering
Attachment |> AttachmentAccess.accessible_by(user) |> Repo.all()

# Get access summary
AttachmentAccess.get_access_summary(attachment)
# => %{access_level: ..., allowed_roles: ..., ...}
```

## 🎯 Best Practices

1. **Default to Public**: Keep most content open unless there's a reason to restrict
2. **Use Roles Over Users**: Role-based access scales better
3. **Document Decisions**: Use the description field to note why access is restricted
4. **Test Access Control**: Always verify from different user perspectives
5. **Monitor Changes**: Use the audit trail to track access modifications
6. **Plan Embargos**: Consider timezone implications for embargo dates
7. **Preload Associations**: Avoid N+1 queries when checking multiple attachments

## 🐛 Troubleshooting

### Users Can't Access Previously Public Attachments
- Check if `access_level` was changed
- Reset to public if needed

### Performance Issues with Queries
- Verify indexes are created properly
- Use `accessible_by/2` efficiently

### Access Grants Not Working
- Ensure roles are preloaded when needed
- Check unique constraints haven't been violated

## 📞 Support

- Check documentation in the `docs/` folder
- Review test examples for usage patterns
- Contact development team for assistance

## 🎉 Summary

This implementation provides:
- ✅ **Zero Breaking Changes**: All existing attachments remain public
- ✅ **Gradual Adoption**: Configure access control at your own pace
- ✅ **Full Featured**: Comprehensive RBAC and embargo system
- ✅ **Well Documented**: Multiple guides and examples
- ✅ **Fully Tested**: Complete test coverage
- ✅ **Production Ready**: Database constraints and proper indexes

Ready to deploy! 🚀

---

**Version**: 1.0.0  
**Date**: November 7, 2025  
**Author**: AI Assistant  
**License**: Same as Voile project
