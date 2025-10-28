alias Voile.Repo
alias Voile.Schema.Accounts
alias Voile.Schema.System
alias Voile.Schema.Master.MemberType
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

  # Get all member types from database
  member_types_map =
    Repo.all(MemberType)
    |> Enum.map(&{&1.slug, &1})
    |> Map.new()

  # Get default member types for role assignments
  staff_member_type = Map.get(member_types_map, "staff")
  admin_member_type = Map.get(member_types_map, "administrator")

  # Fallback to first available member type if specific ones not found
  default_member_type =
    admin_member_type || staff_member_type ||
      member_types_map |> Map.values() |> List.first()

  if is_nil(default_member_type) do
    IO.puts("⚠️  No member types found. Run master seeds to create member types first.")
    System.halt(1)
  end

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
    user_type_id: admin_member_type.id,
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
        # Update existing super admin (ensure node_id is nil and user_type_id is set)
        existing
        |> Ecto.Changeset.change(%{node_id: nil, user_type_id: admin_member_type.id})
        |> Repo.update!()

        IO.puts("   🔁 Updated #{super_admin_email} (Global)")
        existing
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
  # Format: {role_name, display_name, glam_type (optional), member_type_slug}
  node_roles_config = [
    {"admin", "Admin", nil, "administrator"},
    {"editor", "Editor", nil, "staff"},
    {"contributor", "Contributor", nil, "staff"},
    {"viewer", "Viewer", nil, "member_verified"},
    {"librarian", "Librarian", "Library", "staff"},
    {"archivist", "Archivist", "Archive", "staff"},
    {"gallery_curator", "Gallery Curator", "Gallery", "staff"},
    {"museum_curator", "Museum Curator", "Museum", "staff"}
  ]

  # Create accounts for each node and role combination
  nodes
  |> Enum.each(fn node ->
    node_abbr = (node.abbr || "node") |> String.downcase()

    IO.puts("📍 Node: #{node.name} (#{node_abbr})")

    node_roles_config
    |> Enum.each(fn {role_name, display_name, glam_type, member_type_slug} ->
      # Email format: {role}_{node_abbr}@unpad.ac.id
      email = "#{role_name}_#{node_abbr}@unpad.ac.id"
      username = String.slice(email |> String.split("@") |> hd, 0, 30)
      fullname = "#{display_name} - #{node.name}"

      confirmed_at = DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.to_naive()

      # Get member type for this role, fallback to default
      role_member_type = Map.get(member_types_map, member_type_slug, default_member_type)

      attrs = %{
        email: email,
        fullname: fullname,
        username: username,
        password: pw,
        node_id: node.id,
        user_type_id: role_member_type.id,
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
            existing
            |> Ecto.Changeset.change(%{node_id: node.id, user_type_id: role_member_type.id})
            |> Repo.update!()

            IO.puts("   🔁 Updated #{email}")
            existing
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
  |> Enum.each(fn {role_name, display_name, glam_type, _member_type_slug} ->
    glam_info = if glam_type, do: " (#{glam_type} only)", else: ""
    IO.puts("   • #{role_name}: #{display_name}#{glam_info} (per node)")
  end)

  IO.puts("\n👥 Member Type Assignments:")
  IO.puts("   • super_admin → Administrator")
  IO.puts("   • admin → Administrator")

  IO.puts(
    "   • editor, contributor, librarian, archivist, gallery_curator, museum_curator → Staff"
  )

  IO.puts("   • viewer → Member (Verified)")

  IO.puts("\n" <> String.duplicate("=", 80))
end
