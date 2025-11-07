# Attachment Access Control - Quick Reference

## Common Use Cases

### 1. Public Document (Default)
**Scenario**: A public catalog item with downloadable brochure  
**Setup**: No special configuration needed
```elixir
attachment = create_attachment(%{
  access_level: "public",  # default
  # ... other fields
})
```

### 2. Staff-Only Document
**Scenario**: Internal documentation only for staff members  
**Setup**:
```elixir
# Create attachment
attachment = create_attachment(%{access_level: "limited"})

# Grant access to staff role
staff_role = Repo.get_by!(Role, name: "staff")
AttachmentAccess.grant_role_access(attachment.id, staff_role.id)
```

### 3. Research Paper with Embargo
**Scenario**: Academic paper that should be public after publication date  
**Setup**:
```elixir
publication_date = ~U[2025-12-01 00:00:00Z]

AttachmentAccess.update_access_control(
  attachment,
  %{
    access_level: "public",
    embargo_start_date: publication_date
  },
  admin_user
)
```

### 4. Time-Limited Access
**Scenario**: Conference materials only available during the event  
**Setup**:
```elixir
conference_start = ~U[2025-11-15 00:00:00Z]
conference_end = ~U[2025-11-17 23:59:59Z]

AttachmentAccess.update_access_control(
  attachment,
  %{
    access_level: "public",
    embargo_start_date: conference_start,
    embargo_end_date: conference_end
  },
  admin_user
)
```

### 5. Restricted Administrative Document
**Scenario**: Sensitive documents only for super administrators  
**Setup**:
```elixir
AttachmentAccess.update_access_control(
  attachment,
  %{access_level: "restricted"},
  admin_user
)
```

### 6. Multi-Role Access
**Scenario**: Document accessible to staff and researchers  
**Setup**:
```elixir
attachment = create_attachment(%{access_level: "limited"})

staff_role = Repo.get_by!(Role, name: "staff")
researcher_role = Repo.get_by!(Role, name: "researcher")

AttachmentAccess.grant_role_access(attachment.id, staff_role.id)
AttachmentAccess.grant_role_access(attachment.id, researcher_role.id)
```

### 7. Guest Access
**Scenario**: Grant temporary access to specific external users  
**Setup**:
```elixir
attachment = create_attachment(%{access_level: "limited"})

# Grant to specific users
guest_users = [user1_id, user2_id, user3_id]
admin_id = current_user.id

Enum.each(guest_users, fn user_id ->
  AttachmentAccess.grant_user_access(attachment.id, user_id, admin_id)
end)
```

### 8. Bulk Operations
**Scenario**: Apply same access rules to multiple collection attachments  
**Setup**:
```elixir
collection_attachments = 
  Attachment
  |> Attachment.for_entity(collection_id, "collection")
  |> Repo.all()

attachment_ids = Enum.map(collection_attachments, & &1.id)
curator_role_id = Repo.get_by!(Role, name: "curator").id

AttachmentAccess.bulk_grant_role_access(attachment_ids, curator_role_id)
```

## Checking Access in LiveView

```elixir
defmodule MyAppWeb.CollectionLive.Show do
  use MyAppWeb, :live_view
  alias Voile.Catalog.AttachmentAccess

  def mount(%{"id" => id}, _session, socket) do
    collection = load_collection(id)
    current_user = socket.assigns.current_scope.user
    
    # Filter attachments by access
    accessible_attachments = 
      Attachment
      |> Attachment.for_entity(collection.id, "collection")
      |> AttachmentAccess.accessible_by(current_user)
      |> Repo.all()

    {:ok, assign(socket, 
      collection: collection,
      attachments: accessible_attachments
    )}
  end
end
```

## Template Example

```heex
<div id="attachments" class="space-y-4">
  <div :for={attachment <- @attachments} class="border rounded p-4">
    <div class="flex items-center justify-between">
      <div>
        <h3 class="font-semibold">{attachment.original_name}</h3>
        <p class="text-sm text-gray-600">{format_file_size(attachment.file_size)}</p>
      </div>
      
      <%= if AttachmentAccess.can_access?(attachment, @current_scope.user) do %>
        <.link 
          href={~p"/attachments/#{attachment.id}/download"}
          class="btn btn-primary"
        >
          Download
        </.link>
      <% else %>
        <span class="text-sm text-gray-500">Access Restricted</span>
      <% end %>
    </div>

    <%!-- Show embargo info if applicable --%>
    <%= if not is_nil(attachment.embargo_start_date) do %>
      <p class="text-sm text-amber-600 mt-2">
        Available from: {Calendar.strftime(attachment.embargo_start_date, "%B %d, %Y")}
      </p>
    <% end %>
  </div>
</div>
```

## Controller Download Action

```elixir
defmodule MyAppWeb.AttachmentController do
  use MyAppWeb, :controller
  alias Voile.Catalog.AttachmentAccess

  def download(conn, %{"id" => id}) do
    attachment = 
      Attachment
      |> Repo.get!(id)
      |> Repo.preload([:allowed_roles, :allowed_users])
    
    current_user = conn.assigns.current_scope[:user]

    if AttachmentAccess.can_access?(attachment, current_user) do
      conn
      |> put_resp_header("content-disposition", 
           ~s(attachment; filename="#{attachment.original_name}"))
      |> send_file(200, attachment.file_path)
    else
      conn
      |> put_flash(:error, "You don't have permission to download this file")
      |> redirect(to: ~p"/")
    end
  end
end
```

## Admin Panel - Access Control Form

```heex
<.form 
  for={@form} 
  id="access-control-form"
  phx-submit="update_access"
>
  <div class="space-y-4">
    <.input 
      field={@form[:access_level]} 
      type="select"
      label="Access Level"
      options={[
        {"Public - Anyone can view", "public"},
        {"Limited - Specific roles/users", "limited"},
        {"Restricted - Super Admin only", "restricted"}
      ]}
    />

    <%= if @form[:access_level].value == "limited" do %>
      <div class="border rounded p-4 space-y-4">
        <h4 class="font-semibold">Allowed Roles</h4>
        <div :for={role <- @all_roles} class="flex items-center gap-2">
          <input 
            type="checkbox" 
            name="allowed_role_ids[]" 
            value={role.id}
            checked={role.id in @attachment.allowed_role_ids}
          />
          <label>{role.name}</label>
        </div>

        <h4 class="font-semibold mt-4">Allowed Users</h4>
        <%!-- User selection component --%>
      </div>
    <% end %>

    <.input 
      field={@form[:embargo_start_date]} 
      type="datetime-local"
      label="Available From (optional)"
    />

    <.input 
      field={@form[:embargo_end_date]} 
      type="datetime-local"
      label="Available Until (optional)"
    />

    <div class="flex gap-2">
      <.button type="submit">Update Access Settings</.button>
      <.button type="button" phx-click="cancel">Cancel</.button>
    </div>
  </div>
</.form>
```

## Typical Workflow

1. **Create attachment** → defaults to public
2. **Staff decision** → determine if special access needed
3. **Update access level** → public/limited/restricted
4. **Grant specific access** (if limited) → roles and/or users
5. **Set embargo** (optional) → start/end dates
6. **Track changes** → automatic audit trail

## Access Matrix

| User Type | Public | Limited (w/ access) | Limited (no access) | Restricted | Under Embargo |
|-----------|--------|---------------------|---------------------|------------|---------------|
| Anonymous | ✓ | ✗ | ✗ | ✗ | ✗ |
| Regular User | ✓ | ✓ | ✗ | ✗ | ✗ |
| Staff (w/ role) | ✓ | ✓ | ✗ | ✗ | ✗ |
| Super Admin | ✓ | ✓ | ✓ | ✓ | ✓ |

## Tips

- **Start simple**: Use public for most content
- **Role over user**: Prefer role-based for scalability
- **Plan embargos**: Consider timezone implications
- **Test access**: Always verify from user perspective
- **Document decisions**: Use description field to note why access is restricted
- **Monitor usage**: Track who accesses what via audit logs
