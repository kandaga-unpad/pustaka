alias Voile.Repo
alias Voile.Schema.Accounts
alias Voile.Schema.System
alias VoileWeb.Auth.Authorization

import Ecto.Query, warn: false

# Create test accounts for each role in each node for dashboard testing

# Fetch nodes from DB
nodes = System.list_nodes()

if nodes == [] do
  IO.puts("⚠️  No nodes found. Run master seeds to create nodes first.")
else
  IO.puts("Creating role-based test accounts for #{length(nodes)} nodes...")

  # >= 12 chars
  pw = "TestAccount2025!"

  # Get all roles from database
  roles_map =
    Repo.all(Accounts.Role)
    |> Enum.map(&{&1.name, &1})
    |> Map.new()

  # ============================================================================
  # STEP 1: Create ONE Super Admin account (oversees all nodes)
  # ============================================================================
  IO.puts("\n👑 Creating Super Admin (Global Overseer)...")

  super_admin_email = "super_admin@unpad.ac.id"
  super_admin_username = "super_admin"
  super_admin_fullname = "Super Admin - Global Overseer"

  confirmed_at = DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.to_naive()

  super_admin_attrs = %{
    email: super_admin_email,
    fullname: super_admin_fullname,
    username: super_admin_username,
    password: pw,
    node_id: nil,
    confirmed_at: confirmed_at
  }

  # Create or update super admin
  super_admin_user =
    case Repo.get_by(Accounts.User, email: super_admin_email) do
      nil ->
        {:ok, user} =
          %Accounts.User{}
          |> Accounts.User.registration_changeset(super_admin_attrs)
          |> Repo.insert()

        IO.puts("   ✅ Created #{super_admin_email} (Global)")
        user

      existing ->
        # Update existing super admin (ensure node_id is nil)
        {:ok, user} =
          existing
          |> Accounts.User.changeset(%{node_id: nil})
          |> Repo.update()

        IO.puts("   🔁 Updated #{super_admin_email} (Global)")
        user
    end

  # Assign super_admin role
  case Map.get(roles_map, "super_admin") do
    nil ->
      IO.puts("   ⚠️  Role 'super_admin' not found in database")

    role ->
      existing_assignment =
        Repo.get_by(Accounts.UserRoleAssignment,
          user_id: super_admin_user.id,
          role_id: role.id,
          scope_type: "global"
        )

      if is_nil(existing_assignment) do
        case Authorization.assign_role(super_admin_user.id, role.id) do
          {:ok, _assignment} ->
            IO.puts("   ✓ Assigned role: super_admin (global scope)")

          {:error, changeset} ->
            IO.puts("   ⚠️  Failed to assign role: #{inspect(changeset.errors)}")
        end
      else
        IO.puts("   ✓ Role already assigned: super_admin")
      end
  end

  # ============================================================================
  # STEP 2: Create node-specific accounts for other roles
  # ============================================================================
  IO.puts("\n📍 Creating node-specific role accounts...\n")

  # Define node-specific roles (excluding super_admin)
  # Format: {role_name, display_name, glam_type (optional)}
  node_roles_config = [
    {"admin", "Admin", nil},
    {"editor", "Editor", nil},
    {"contributor", "Contributor", nil},
    {"viewer", "Viewer", nil},
    {"librarian", "Librarian", "Library"},
    {"archivist", "Archivist", "Archive"},
    {"gallery_curator", "Gallery Curator", "Gallery"},
    {"museum_curator", "Museum Curator", "Museum"}
  ]

  # Create accounts for each node and role combination
  nodes
  |> Enum.each(fn node ->
    node_abbr = (node.abbr || "node") |> String.downcase()

    IO.puts("📍 Node: #{node.name} (#{node_abbr})")

    node_roles_config
    |> Enum.each(fn {role_name, display_name, glam_type} ->
      # Email format: {role}_{node_abbr}@unpad.ac.id
      email = "#{role_name}_#{node_abbr}@unpad.ac.id"
      username = String.slice(email |> String.split("@") |> hd, 0, 30)
      fullname = "#{display_name} - #{node.name}"

      confirmed_at = DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.to_naive()

      attrs = %{
        email: email,
        fullname: fullname,
        username: username,
        password: pw,
        node_id: node.id,
        confirmed_at: confirmed_at
      }

      # Create or update user
      user =
        case Repo.get_by(Accounts.User, email: email) do
          nil ->
            {:ok, user} =
              %Accounts.User{}
              |> Accounts.User.registration_changeset(attrs)
              |> Repo.insert()

            IO.puts("   ✅ Created #{email}")
            user

          existing ->
            # Update existing user
            {:ok, user} =
              existing
              |> Accounts.User.changeset(%{node_id: node.id})
              |> Repo.update()

            IO.puts("   🔁 Updated #{email}")
            user
        end

      # Assign role to user if role exists in database
      case Map.get(roles_map, role_name) do
        nil ->
          IO.puts("   ⚠️  Role '#{role_name}' not found in database, skipping role assignment")

        role ->
          # Check if user already has this role assignment
          existing_assignment =
            Repo.get_by(Accounts.UserRoleAssignment,
              user_id: user.id,
              role_id: role.id,
              scope_type: "global"
            )

          if is_nil(existing_assignment) do
            # Assign role with GLAM type if applicable
            opts =
              if glam_type do
                [glam_type: glam_type]
              else
                []
              end

            case Authorization.assign_role(user.id, role.id, opts) do
              {:ok, _assignment} ->
                glam_info = if glam_type, do: " (#{glam_type})", else: ""
                IO.puts("   ✓ Assigned role: #{role_name}#{glam_info}")

              {:error, changeset} ->
                IO.puts("   ⚠️  Failed to assign role #{role_name}: #{inspect(changeset.errors)}")
            end
          else
            # Update GLAM type if needed
            if glam_type && existing_assignment.glam_type != glam_type do
              existing_assignment
              |> Accounts.UserRoleAssignment.changeset(%{glam_type: glam_type})
              |> Repo.update()

              IO.puts("   ✓ Updated GLAM type for #{role_name}: #{glam_type}")
            else
              IO.puts("   ✓ Role already assigned: #{role_name}")
            end
          end
      end
    end)

    IO.puts("")
  end)

  IO.puts("\n" <> String.duplicate("=", 80))
  IO.puts("✅ Role-based test accounts creation completed!")
  IO.puts(String.duplicate("=", 80))

  # Print summary
  total_node_accounts = length(nodes) * length(node_roles_config)
  # +1 for super admin
  total_accounts = total_node_accounts + 1

  IO.puts("\n📊 Summary:")
  IO.puts("   • Nodes: #{length(nodes)}")
  IO.puts("   • Super Admin: 1 (global overseer)")
  IO.puts("   • Node-specific roles per node: #{length(node_roles_config)}")
  IO.puts("   • Total node-specific accounts: #{total_node_accounts}")
  IO.puts("   • Total accounts: #{total_accounts}")
  IO.puts("\n🔐 Login credentials:")
  IO.puts("   • Password for all accounts: #{pw}")
  IO.puts("\n📧 Account naming patterns:")
  IO.puts("   • Super Admin (global): super_admin@unpad.ac.id")
  IO.puts("   • Node-specific: {role}_{node_abbr}@unpad.ac.id")
  IO.puts("   • Example: admin_fib@unpad.ac.id, librarian_fkip@unpad.ac.id")
  IO.puts("\n🎭 Available roles:")
  IO.puts("   • super_admin: Super Admin (1 account, oversees all nodes)")

  node_roles_config
  |> Enum.each(fn {role_name, display_name, glam_type} ->
    glam_info = if glam_type, do: " (#{glam_type} only)", else: ""
    IO.puts("   • #{role_name}: #{display_name}#{glam_info} (per node)")
  end)

  IO.puts("\n" <> String.duplicate("=", 80))
end
