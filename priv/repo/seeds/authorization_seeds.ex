defmodule Voile.Repo.Seeds.AuthorizationSeeds do
  @moduledoc """
  Seeds for the authorization system.
  Run this to populate default permissions and roles.

  ## Usage

  In IEx or seeds.exs:

      Voile.Repo.Seeds.AuthorizationSeeds.run()

  Or run specific functions:

      Voile.Repo.Seeds.AuthorizationSeeds.seed_permissions()
      Voile.Repo.Seeds.AuthorizationSeeds.seed_roles()
  """

  alias VoileWeb.Auth.PermissionManager

  @doc """
  Run all authorization seeds.
  """
  def run do
    IO.puts("\n🔐 Seeding authorization system...")
    IO.puts("=" |> String.duplicate(50))

    seed_permissions()
    seed_roles()

    IO.puts("=" |> String.duplicate(50))
    IO.puts("✅ Authorization system seeded successfully!\n")
  end

  @doc """
  Seed default permissions only.
  """
  def seed_permissions do
    IO.puts("  📋 Creating permissions...")

    # Use the PermissionManager to create all default permissions
    PermissionManager.seed_default_permissions()

    count = PermissionManager.list_permissions() |> length()
    IO.puts("  ✓ #{count} permissions created/verified")
  end

  @doc """
  Seed default roles only.
  """
  def seed_roles do
    IO.puts("  👥 Creating roles with permissions...")

    # Use the PermissionManager to create all default roles with their permissions
    PermissionManager.seed_default_roles()

    # Display summary
    roles = PermissionManager.list_roles()
    IO.puts("  ✓ #{length(roles)} roles created/verified:")

    Enum.each(roles, fn role ->
      full_role = PermissionManager.get_role(role.id)
      perm_count = length(full_role.permissions)
      IO.puts("    • #{full_role.name}: #{perm_count} permissions")
    end)
  end

  @doc """
  Assign super_admin role to a user by email.
  """
  def assign_super_admin(email) do
    alias Voile.Repo
    alias Voile.Schema.Accounts.{User, Role}
    alias VoileWeb.Auth.Authorization

    with %User{} = user <- Repo.get_by(User, email: email),
         %Role{} = role <- Repo.get_by(Role, name: "super_admin"),
         {:ok, _assignment} <- Authorization.assign_role(user.id, role.id) do
      IO.puts("✅ Assigned super_admin role to #{email}")
      :ok
    else
      nil ->
        IO.puts("❌ User with email #{email} not found or super_admin role doesn't exist")
        {:error, :not_found}

      {:error, reason} ->
        IO.puts("❌ Failed to assign role: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Display all permissions grouped by category.
  """
  def list_permissions do
    permissions = PermissionManager.list_permissions()

    grouped =
      permissions
      |> Enum.group_by(fn perm ->
        perm.name |> String.split(".") |> List.first()
      end)

    IO.puts("\n📋 Available Permissions:\n")

    grouped
    |> Enum.sort_by(fn {category, _} -> category end)
    |> Enum.each(fn {category, perms} ->
      IO.puts("  #{String.upcase(category)}:")

      perms
      |> Enum.sort_by(& &1.name)
      |> Enum.each(fn perm ->
        IO.puts("    • #{perm.name} - #{perm.description}")
      end)

      IO.puts("")
    end)
  end

  @doc """
  Display all roles with their permissions.
  """
  def list_roles do
    roles = PermissionManager.list_roles()

    IO.puts("\n👥 Available Roles:\n")

    roles
    |> Enum.sort_by(& &1.name)
    |> Enum.each(fn role ->
      full_role = PermissionManager.get_role(role.id)
      perm_count = length(full_role.permissions)

      IO.puts("  #{full_role.name} (#{perm_count} permissions)")
      IO.puts("    #{full_role.description}")

      if perm_count > 0 do
        IO.puts("    Permissions:")

        full_role.permissions
        |> Enum.sort_by(& &1.name)
        |> Enum.each(fn perm ->
          IO.puts("      • #{perm.name}")
        end)
      end

      IO.puts("")
    end)
  end
end
