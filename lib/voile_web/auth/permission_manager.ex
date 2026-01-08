defmodule VoileWeb.Auth.PermissionManager do
  @moduledoc """
  Module for managing permissions and roles in the system.
  Provides functions to create, update, and query permissions and roles.
  """

  import Ecto.Query
  alias Voile.Repo

  alias Voile.Schema.Accounts.{
    Role,
    Permission,
    UserRoleAssignment,
    UserPermission,
    RolePermission
  }

  @doc """
  List all available permissions.
  """
  def list_permissions do
    Repo.all(Permission)
  end

  @doc """
  List permissions with pagination.
  Returns a tuple of {permissions, total_pages}.
  """
  def list_permissions_paginated(page \\ 1, per_page \\ 10) do
    offset = (page - 1) * per_page

    query =
      from p in Permission,
        order_by: [asc: p.name],
        limit: ^per_page,
        offset: ^offset

    permissions = Repo.all(query)

    total_count = Repo.aggregate(Permission, :count, :id)
    total_pages = div(total_count + per_page - 1, per_page)
    {permissions, total_pages, total_count}
  end

  @doc """
  List all roles.
  """
  def list_roles do
    Repo.all(Role)
  end

  @doc """
  List roles with pagination.
  Returns a tuple of {roles, total_pages}.
  """
  def list_roles_paginated(page \\ 1, per_page \\ 10) do
    offset = (page - 1) * per_page

    query =
      from r in Role,
        preload: [:permissions],
        order_by: [asc: r.name],
        limit: ^per_page,
        offset: ^offset

    roles = Repo.all(query)

    total_count = Repo.aggregate(Role, :count, :id)
    total_pages = div(total_count + per_page - 1, per_page)
    {roles, total_pages, total_count}
  end

  @doc """
  Get a role by ID with preloaded permissions.
  """
  def get_role(id) do
    Role
    |> Repo.get(id)
    |> Repo.preload(permissions: from(p in Permission, order_by: p.name))
  end

  @doc """
  Get a permission by ID.
  """
  def get_permission(id) do
    Repo.get(Permission, id)
  end

  @doc """
  Get a permission by name.
  """
  def get_permission_by_name(name) do
    Repo.get_by(Permission, name: name)
  end

  @doc """
  Create a new role.
  """
  def create_role(attrs) do
    %Role{}
    |> Role.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Update a role.
  """
  def update_role(role, attrs) do
    role
    |> Role.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Delete a role.
  """
  def delete_role(role) do
    Repo.delete(role)
  end

  @doc """
  Create a new permission.
  """
  def create_permission(attrs) do
    %Permission{}
    |> Permission.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Update a permission.
  """
  def update_permission(permission, attrs) do
    permission
    |> Permission.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Delete a permission.
  """
  def delete_permission(permission) do
    Repo.delete(permission)
  end

  @doc """
  Add a permission to a role.
  """
  def add_permission_to_role(role_id, permission_id) do
    %RolePermission{}
    |> RolePermission.changeset(%{role_id: role_id, permission_id: permission_id})
    |> Repo.insert()
  end

  @doc """
  Remove a permission from a role.
  """
  def remove_permission_from_role(role_id, permission_id) do
    query =
      from rp in RolePermission,
        where: rp.role_id == ^role_id and rp.permission_id == ^permission_id

    Repo.delete_all(query)
  end

  @doc """
  Set all permissions for a role, replacing existing ones.
  """
  def set_role_permissions(role_id, permission_ids) do
    Repo.transaction(fn ->
      # Remove existing permissions
      from(rp in RolePermission, where: rp.role_id == ^role_id)
      |> Repo.delete_all()

      # Add new permissions
      Enum.each(permission_ids, fn permission_id ->
        %RolePermission{}
        |> RolePermission.changeset(%{role_id: role_id, permission_id: permission_id})
        |> Repo.insert!()
      end)

      get_role(role_id)
    end)
  end

  @doc """
  Get all users assigned to a role.
  """
  def list_users_with_role(role_id, opts \\ []) do
    scope_type = Keyword.get(opts, :scope_type)
    scope_id = Keyword.get(opts, :scope_id)

    query =
      from ura in UserRoleAssignment,
        join: u in assoc(ura, :user),
        where: ura.role_id == ^role_id,
        where: is_nil(ura.expires_at) or ura.expires_at > ^DateTime.utc_now(),
        preload: [user: u],
        select: ura

    query =
      if scope_type do
        from ura in query, where: ura.scope_type == ^scope_type
      else
        query
      end

    query =
      if scope_id do
        from ura in query, where: ura.scope_id == ^scope_id
      else
        query
      end

    Repo.all(query)
  end

  @doc """
  Lists all users assigned to a specific role by role name.
  Returns a list of User structs (not UserRoleAssignments).

  ## Examples

      iex> list_users_with_role_by_name("librarian")
      [%User{}, ...]

  """
  def list_users_with_role_by_name(role_name) when is_binary(role_name) do
    from(u in Voile.Schema.Accounts.User,
      join: ura in UserRoleAssignment,
      on: ura.user_id == u.id,
      join: r in Role,
      on: r.id == ura.role_id,
      where: r.name == ^role_name,
      where: is_nil(ura.expires_at) or ura.expires_at > ^DateTime.utc_now(),
      order_by: [asc: u.fullname, asc: u.email],
      distinct: u.id
    )
    |> Repo.all()
  end

  @doc """
  Get all roles assigned to a user.
  """
  def list_user_roles(user_id, opts \\ []) do
    scope_type = Keyword.get(opts, :scope_type)
    scope_id = Keyword.get(opts, :scope_id)

    query =
      from ura in UserRoleAssignment,
        join: r in assoc(ura, :role),
        where: ura.user_id == ^user_id,
        where: is_nil(ura.expires_at) or ura.expires_at > ^DateTime.utc_now(),
        preload: [role: r],
        select: ura

    query =
      if scope_type do
        from ura in query, where: ura.scope_type == ^scope_type
      else
        query
      end

    query =
      if scope_id do
        from ura in query, where: ura.scope_id == ^scope_id
      else
        query
      end

    Repo.all(query)
  end

  @doc """
  Get all direct permissions for a user.
  """
  def list_user_direct_permissions(user_id, opts \\ []) do
    scope_type = Keyword.get(opts, :scope_type)
    scope_id = Keyword.get(opts, :scope_id)

    query =
      from up in UserPermission,
        join: p in assoc(up, :permission),
        where: up.user_id == ^user_id,
        where: is_nil(up.expires_at) or up.expires_at > ^DateTime.utc_now(),
        preload: [permission: p],
        select: up,
        order_by: [desc: up.granted, asc: p.name]

    query =
      if scope_type do
        from up in query, where: up.scope_type == ^scope_type
      else
        query
      end

    query =
      if scope_id do
        from up in query, where: up.scope_id == ^scope_id
      else
        query
      end

    Repo.all(query)
  end

  @doc """
  Seed default permissions for the system.
  """
  def seed_default_permissions do
    permissions = [
      # Collection permissions
      %{
        name: "collections.create",
        resource: "collections",
        action: "create",
        description: "Create new collections"
      },
      %{
        name: "collections.read",
        resource: "collections",
        action: "read",
        description: "View collections"
      },
      %{
        name: "collections.update",
        resource: "collections",
        action: "update",
        description: "Edit collections"
      },
      %{
        name: "collections.delete",
        resource: "collections",
        action: "delete",
        description: "Delete collections"
      },
      %{
        name: "collections.publish",
        resource: "collections",
        action: "publish",
        description: "Publish collections"
      },
      %{
        name: "collections.archive",
        resource: "collections",
        action: "archive",
        description: "Archive collections"
      },
      # Transfer Requests
      %{
        name: "transfer_requests.create",
        resource: "transfer_requests",
        action: "create",
        description: "Create transfer requests"
      },
      %{
        name: "transfer_requests.read",
        resource: "transfer_requests",
        action: "read",
        description: "View transfer requests"
      },
      %{
        name: "transfer_requests.update",
        resource: "transfer_requests",
        action: "update",
        description: "Update transfer requests"
      },
      %{
        name: "transfer_requests.delete",
        resource: "transfer_requests",
        action: "delete",
        description: "Delete transfer requests"
      },
      %{
        name: "transfer_requests.review",
        resource: "transfer_requests",
        action: "review",
        description: "Review and approve/deny transfer requests"
      },
      # Items
      # Item permissions
      %{
        name: "items.create",
        resource: "items",
        action: "create",
        description: "Create new items"
      },
      %{name: "items.read", resource: "items", action: "read", description: "View items"},
      %{name: "items.update", resource: "items", action: "update", description: "Edit items"},
      %{name: "items.delete", resource: "items", action: "delete", description: "Delete items"},
      %{name: "items.export", resource: "items", action: "export", description: "Export items"},
      %{name: "items.import", resource: "items", action: "import", description: "Import items"},

      # Metadata permissions
      %{
        name: "metadata.edit",
        resource: "metadata",
        action: "edit",
        description: "Edit metadata fields"
      },
      %{
        name: "metadata.manage",
        resource: "metadata",
        action: "manage",
        description: "Manage metadata schemas"
      },

      # User management permissions
      %{
        name: "users.create",
        resource: "users",
        action: "create",
        description: "Create new users"
      },
      %{name: "users.read", resource: "users", action: "read", description: "View users"},
      %{name: "users.update", resource: "users", action: "update", description: "Edit users"},
      %{name: "users.delete", resource: "users", action: "delete", description: "Delete users"},
      %{
        name: "users.manage_roles",
        resource: "users",
        action: "manage_roles",
        description: "Manage user roles"
      },

      # Role and permission management
      %{
        name: "roles.create",
        resource: "roles",
        action: "create",
        description: "Create new roles"
      },
      %{name: "roles.update", resource: "roles", action: "update", description: "Edit roles"},
      %{name: "roles.delete", resource: "roles", action: "delete", description: "Delete roles"},
      %{
        name: "permissions.manage",
        resource: "permissions",
        action: "manage",
        description: "Manage permissions"
      },

      # System permissions
      %{
        name: "system.settings",
        resource: "system",
        action: "settings",
        description: "Manage system settings"
      },
      %{
        name: "system.audit",
        resource: "system",
        action: "audit",
        description: "View audit logs"
      },
      %{
        name: "system.backup",
        resource: "system",
        action: "backup",
        description: "Perform system backups"
      },

      # Circulation permissions (Library-specific)
      %{
        name: "circulation.checkout",
        resource: "circulation",
        action: "checkout",
        description: "Check out items to members"
      },
      %{
        name: "circulation.return",
        resource: "circulation",
        action: "return",
        description: "Process item returns"
      },
      %{
        name: "circulation.renew",
        resource: "circulation",
        action: "renew",
        description: "Renew item transactions"
      },
      %{
        name: "circulation.view_transactions",
        resource: "circulation",
        action: "view_transactions",
        description: "View circulation transactions"
      },
      %{
        name: "circulation.manage_reservations",
        resource: "circulation",
        action: "manage_reservations",
        description: "Manage item reservations"
      },
      %{
        name: "circulation.manage_fines",
        resource: "circulation",
        action: "manage_fines",
        description: "Manage fines and payments"
      },
      %{
        name: "circulation.view_history",
        resource: "circulation",
        action: "view_history",
        description: "View circulation history"
      },
      %{
        name: "members.lookup",
        resource: "members",
        action: "lookup",
        description: "Search and view member information"
      }
    ]

    Enum.each(permissions, fn attrs ->
      case Repo.get_by(Permission, name: attrs.name) do
        nil ->
          case %Permission{}
               |> Permission.changeset(attrs)
               |> Repo.insert() do
            {:ok, _permission} ->
              :ok

            {:error, changeset} ->
              IO.puts("Failed to insert permission #{attrs.name}: #{inspect(changeset.errors)}")
          end

        _existing ->
          :ok
      end
    end)
  end

  @doc """
  Seed default roles for the system.
  """
  def seed_default_roles do
    roles = [
      %{
        name: "super_admin",
        description: "Full system access with all permissions",
        permissions: [
          "collections.create",
          "collections.read",
          "collections.update",
          "collections.delete",
          "collections.publish",
          "collections.archive",
          "transfer_requests.create",
          "transfer_requests.read",
          "transfer_requests.update",
          "transfer_requests.delete",
          "transfer_requests.review",
          "items.create",
          "items.read",
          "items.update",
          "items.delete",
          "items.export",
          "items.import",
          "metadata.edit",
          "metadata.manage",
          "metadata.delete",
          "users.create",
          "users.read",
          "users.update",
          "users.delete",
          "users.manage_roles",
          "roles.create",
          "roles.read",
          "roles.update",
          "roles.delete",
          "permissions.manage",
          "system.settings",
          "system.audit",
          "system.backup",
          "circulation.checkout",
          "circulation.return",
          "circulation.renew",
          "circulation.view_transactions",
          "circulation.manage_reservations",
          "circulation.manage_fines",
          "circulation.view_history",
          "members.lookup"
        ],
        is_system_role: true
      },
      %{
        name: "admin",
        description: "Administrative access without system settings",
        permissions: [
          "collections.create",
          "collections.read",
          "collections.update",
          "collections.delete",
          "collections.publish",
          "collections.archive",
          "items.create",
          "items.read",
          "items.update",
          "items.delete",
          "items.export",
          "items.import",
          "metadata.edit",
          "users.create",
          "users.read",
          "users.update",
          "users.manage_roles"
        ],
        is_system_role: false
      },
      %{
        name: "editor",
        description: "Can manage collections and items",
        permissions: [
          "collections.create",
          "collections.read",
          "collections.update",
          "items.create",
          "items.read",
          "items.update",
          "items.delete",
          "items.export",
          "items.import",
          "metadata.edit"
        ],
        is_system_role: false
      },
      %{
        name: "contributor",
        description: "Can create and edit own content",
        permissions: [
          "collections.read",
          "items.create",
          "items.read",
          "items.update",
          "items.export"
        ],
        is_system_role: false
      },
      %{
        name: "viewer",
        description: "Read-only access to collections and items",
        permissions: [
          "collections.read",
          "items.read",
          "items.export"
        ],
        is_system_role: false
      },
      # GLAM-specific curator roles
      %{
        name: "librarian",
        description: "Library curator - can manage library collections and items",
        permissions: [
          "collections.create",
          "collections.read",
          "collections.update",
          "collections.delete",
          "collections.publish",
          "collections.archive",
          "transfer_requests.create",
          "transfer_requests.read",
          "transfer_requests.update",
          "transfer_requests.delete",
          "transfer_requests.review",
          "items.create",
          "items.read",
          "items.update",
          "items.delete",
          "items.export",
          "items.import",
          "metadata.edit",
          "circulation.checkout",
          "circulation.return",
          "circulation.renew",
          "circulation.view_transactions",
          "circulation.manage_reservations",
          "circulation.manage_fines",
          "circulation.view_history",
          "members.lookup"
        ],
        is_system_role: false
      },
      %{
        name: "archivist",
        description: "Archive curator - can manage archive collections and items",
        permissions: [
          "collections.create",
          "collections.read",
          "collections.update",
          "collections.delete",
          "collections.publish",
          "collections.archive",
          "items.create",
          "items.read",
          "items.update",
          "items.delete",
          "items.export",
          "items.import",
          "metadata.edit"
        ],
        is_system_role: false
      },
      %{
        name: "gallery_curator",
        description: "Gallery curator - can manage gallery collections and items",
        permissions: [
          "collections.create",
          "collections.read",
          "collections.update",
          "collections.delete",
          "collections.publish",
          "collections.archive",
          "items.create",
          "items.read",
          "items.update",
          "items.delete",
          "items.export",
          "items.import",
          "metadata.edit"
        ],
        is_system_role: false
      },
      %{
        name: "museum_curator",
        description: "Museum curator - can manage museum collections and items",
        permissions: [
          "collections.create",
          "collections.read",
          "collections.update",
          "collections.delete",
          "collections.publish",
          "collections.archive",
          "items.create",
          "items.read",
          "items.update",
          "items.delete",
          "items.export",
          "items.import",
          "metadata.edit"
        ],
        is_system_role: false
      }
    ]

    Enum.each(roles, fn %{permissions: permission_names} = role_attrs ->
      case Repo.get_by(Role, name: role_attrs.name) do
        nil ->
          # Create role
          {:ok, role} =
            %Role{}
            |> Role.changeset(Map.delete(role_attrs, :permissions))
            |> Repo.insert()

          # Add permissions to role
          Enum.each(permission_names, fn perm_name ->
            if permission = Repo.get_by(Permission, name: perm_name) do
              add_permission_to_role(role.id, permission.id)
            end
          end)

        existing_role ->
          # Update permissions for existing role
          permission_ids =
            permission_names
            |> Enum.map(&Repo.get_by(Permission, name: &1))
            |> Enum.reject(&is_nil/1)
            |> Enum.map(& &1.id)

          set_role_permissions(existing_role.id, permission_ids)
      end
    end)
  end
end
