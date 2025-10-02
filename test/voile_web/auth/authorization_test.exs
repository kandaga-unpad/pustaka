defmodule VoileWeb.Auth.AuthorizationTest do
  use Voile.DataCase, async: true

  alias VoileWeb.Auth.Authorization
  alias Voile.Schema.Accounts.{User, Role, Permission, UserRoleAssignment, UserPermission}

  describe "can?/3" do
    setup do
      # Create test user
      user = insert_user()

      # Create permissions
      read_permission = insert_permission("collections.read")
      create_permission = insert_permission("collections.create")
      delete_permission = insert_permission("collections.delete")

      {:ok,
       user: user,
       read_permission: read_permission,
       create_permission: create_permission,
       delete_permission: delete_permission}
    end

    test "returns false when user has no permissions", %{user: user} do
      refute Authorization.can?(user, "collections.read")
    end

    test "returns true when user has direct permission", %{
      user: user,
      read_permission: read_permission
    } do
      grant_direct_permission(user.id, read_permission.id)

      assert Authorization.can?(user, "collections.read")
    end

    test "returns false when permission is explicitly denied", %{
      user: user,
      delete_permission: delete_permission
    } do
      deny_direct_permission(user.id, delete_permission.id)

      refute Authorization.can?(user, "collections.delete")
    end

    test "returns true when user has permission through role", %{
      user: user,
      create_permission: create_permission
    } do
      role = insert_role("editor")
      assign_permission_to_role(role.id, create_permission.id)
      assign_role_to_user(user.id, role.id)

      assert Authorization.can?(user, "collections.create")
    end

    test "checks scoped permissions correctly", %{
      user: user,
      read_permission: read_permission
    } do
      collection_id = Ecto.UUID.generate()

      grant_direct_permission(user.id, read_permission.id,
        scope_type: "collection",
        scope_id: collection_id
      )

      assert Authorization.can?(user, "collections.read", scope: {:collection, collection_id})

      refute Authorization.can?(user, "collections.read",
               scope: {:collection, Ecto.UUID.generate()}
             )
    end

    test "global permissions work for any scope", %{
      user: user,
      read_permission: read_permission
    } do
      grant_direct_permission(user.id, read_permission.id, scope_type: "global")

      assert Authorization.can?(user, "collections.read")

      assert Authorization.can?(user, "collections.read",
               scope: {:collection, Ecto.UUID.generate()}
             )
    end

    test "expired permissions are not granted", %{
      user: user,
      read_permission: read_permission
    } do
      yesterday = DateTime.utc_now() |> DateTime.add(-1, :day)

      grant_direct_permission(user.id, read_permission.id, expires_at: yesterday)

      refute Authorization.can?(user, "collections.read")
    end
  end

  describe "authorize!/3" do
    setup do
      user = insert_user()
      permission = insert_permission("collections.delete")

      {:ok, user: user, permission: permission}
    end

    test "returns :ok when user has permission", %{user: user, permission: permission} do
      grant_direct_permission(user.id, permission.id)

      assert :ok = Authorization.authorize!(user, "collections.delete")
    end

    test "raises UnauthorizedError when user lacks permission", %{user: user} do
      assert_raise Authorization.UnauthorizedError, fn ->
        Authorization.authorize!(user, "collections.delete")
      end
    end
  end

  describe "get_user_permissions/2" do
    setup do
      user = insert_user()
      perm1 = insert_permission("collections.read")
      perm2 = insert_permission("collections.create")
      perm3 = insert_permission("items.update")

      {:ok, user: user, perm1: perm1, perm2: perm2, perm3: perm3}
    end

    test "returns all permissions for user", %{
      user: user,
      perm1: perm1,
      perm2: perm2,
      perm3: perm3
    } do
      grant_direct_permission(user.id, perm1.id)

      role = insert_role("editor")
      assign_permission_to_role(role.id, perm2.id)
      assign_permission_to_role(role.id, perm3.id)
      assign_role_to_user(user.id, role.id)

      permissions = Authorization.get_user_permissions(user.id)

      assert length(permissions) == 3
      assert Enum.any?(permissions, &(&1.name == "collections.read"))
      assert Enum.any?(permissions, &(&1.name == "collections.create"))
      assert Enum.any?(permissions, &(&1.name == "items.update"))
    end

    test "deduplicates permissions", %{user: user, perm1: perm1} do
      grant_direct_permission(user.id, perm1.id)

      role = insert_role("viewer")
      assign_permission_to_role(role.id, perm1.id)
      assign_role_to_user(user.id, role.id)

      permissions = Authorization.get_user_permissions(user.id)

      # Should only have one instance even though it's assigned via both direct and role
      assert length(permissions) == 1
    end
  end

  describe "assign_role/3" do
    setup do
      user = insert_user()
      role = insert_role("admin")

      {:ok, user: user, role: role}
    end

    test "assigns role to user", %{user: user, role: role} do
      {:ok, assignment} = Authorization.assign_role(user.id, role.id)

      assert assignment.user_id == user.id
      assert assignment.role_id == role.id
      assert assignment.scope_type == "global"
    end

    test "assigns scoped role", %{user: user, role: role} do
      collection_id = Ecto.UUID.generate()

      {:ok, assignment} =
        Authorization.assign_role(user.id, role.id,
          scope_type: "collection",
          scope_id: collection_id
        )

      assert assignment.scope_type == "collection"
      assert assignment.scope_id == collection_id
    end
  end

  describe "grant_permission/3" do
    setup do
      user = insert_user()
      permission = insert_permission("metadata.edit")

      {:ok, user: user, permission: permission}
    end

    test "grants permission to user", %{user: user, permission: permission} do
      {:ok, user_perm} = Authorization.grant_permission(user.id, permission.id)

      assert user_perm.user_id == user.id
      assert user_perm.permission_id == permission.id
      assert user_perm.granted == true
    end
  end

  describe "deny_permission/3" do
    setup do
      user = insert_user()
      permission = insert_permission("collections.delete")

      {:ok, user: user, permission: permission}
    end

    test "explicitly denies permission", %{user: user, permission: permission} do
      {:ok, user_perm} = Authorization.deny_permission(user.id, permission.id)

      assert user_perm.user_id == user.id
      assert user_perm.permission_id == permission.id
      assert user_perm.granted == false
    end

    test "deny overrides role permissions", %{user: user, permission: permission} do
      # Give user permission through role
      role = insert_role("admin")
      assign_permission_to_role(role.id, permission.id)
      assign_role_to_user(user.id, role.id)

      # Explicitly deny the permission
      Authorization.deny_permission(user.id, permission.id)

      # Should not have permission despite role
      refute Authorization.can?(user, "collections.delete")
    end
  end

  describe "revoke_role/3" do
    setup do
      user = insert_user()
      role = insert_role("editor")

      {:ok, user: user, role: role}
    end

    test "removes role assignment", %{user: user, role: role} do
      {:ok, _assignment} = Authorization.assign_role(user.id, role.id)

      {count, _} = Authorization.revoke_role(user.id, role.id)

      assert count == 1
    end
  end

  # Helper functions

  defp insert_user do
    Repo.insert!(%User{
      email: "test#{System.unique_integer()}@example.com",
      username: "user#{System.unique_integer()}",
      hashed_password: Bcrypt.hash_pwd_salt("password123"),
      confirmed_at: DateTime.utc_now()
    })
  end

  defp insert_permission(name) do
    Repo.insert!(%Permission{
      name: name,
      description: "Test permission: #{name}"
    })
  end

  defp insert_role(name) do
    Repo.insert!(%Role{
      name: name,
      description: "Test role: #{name}"
    })
  end

  defp grant_direct_permission(user_id, permission_id, opts \\ []) do
    scope_type = Keyword.get(opts, :scope_type, "global")
    scope_id = Keyword.get(opts, :scope_id)
    expires_at = Keyword.get(opts, :expires_at)

    Repo.insert!(%UserPermission{
      user_id: user_id,
      permission_id: permission_id,
      scope_type: scope_type,
      scope_id: scope_id,
      granted: true,
      expires_at: expires_at
    })
  end

  defp deny_direct_permission(user_id, permission_id, opts \\ []) do
    scope_type = Keyword.get(opts, :scope_type, "global")
    scope_id = Keyword.get(opts, :scope_id)

    Repo.insert!(%UserPermission{
      user_id: user_id,
      permission_id: permission_id,
      scope_type: scope_type,
      scope_id: scope_id,
      granted: false
    })
  end

  defp assign_permission_to_role(role_id, permission_id) do
    Repo.insert!(%Voile.Schema.Accounts.RolePermission{
      role_id: role_id,
      permission_id: permission_id
    })
  end

  defp assign_role_to_user(user_id, role_id, opts \\ []) do
    scope_type = Keyword.get(opts, :scope_type, "global")
    scope_id = Keyword.get(opts, :scope_id)

    Repo.insert!(%UserRoleAssignment{
      user_id: user_id,
      role_id: role_id,
      scope_type: scope_type,
      scope_id: scope_id
    })
  end
end
