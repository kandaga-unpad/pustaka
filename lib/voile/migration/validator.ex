defmodule Voile.Migration.Validator do
  @moduledoc """
  Validation script to check the migration results and data integrity.
  """

  import Ecto.Query

  alias Voile.Repo
  alias Voile.Schema.Accounts.{User, UserRole, UserProfile}
  alias Voile.Schema.Master.{MemberType, Creator, Publishers}
  alias Voile.Schema.System.Node
  alias Voile.Schema.Catalog.{Collection, Item}

  def run_all_checks do
    IO.puts("=" |> String.duplicate(60))
    IO.puts("VOILE DATA MIGRATION VALIDATION REPORT")
    IO.puts("=" |> String.duplicate(60))

    check_master_data()
    check_catalog_data()
    check_user_counts()
    check_data_integrity()
    check_profiles()
    check_sample_data()

    IO.puts(("\n" <> "=") |> String.duplicate(60))
    IO.puts("VALIDATION COMPLETED")
    IO.puts("=" |> String.duplicate(60))
  end

  defp check_master_data do
    IO.puts("\n1. MASTER DATA CHECK")
    IO.puts("-" |> String.duplicate(40))

    # User Roles
    roles = Repo.all(UserRole)
    IO.puts("User Roles: #{length(roles)}")

    Enum.each(roles, fn role ->
      IO.puts("  - #{role.name}: #{role.description}")
    end)

    # Member Types
    member_types = Repo.all(MemberType)
    IO.puts("\nMember Types: #{length(member_types)}")

    Enum.each(member_types, fn type ->
      IO.puts("  - #{type.name}: max_items=#{type.max_items}, max_days=#{type.max_days}")
    end)

    # Nodes
    nodes = Repo.all(Node)
    IO.puts("\nNodes: #{length(nodes)}")

    Enum.each(nodes, fn node ->
      IO.puts("  - #{node.name} (#{node.abbr || "N/A"})")
    end)

    # Creators
    creator_count = Repo.aggregate(Creator, :count, :id)
    IO.puts("\nCreators: #{creator_count}")

    # Publishers
    publisher_count = Repo.aggregate(Publishers, :count, :id)
    IO.puts("Publishers: #{publisher_count}")
  end

  defp check_catalog_data do
    IO.puts("\n2. CATALOG DATA CHECK")
    IO.puts("-" |> String.duplicate(40))

    # Collections
    collection_count = Repo.aggregate(Collection, :count, :id)
    IO.puts("Total Collections: #{collection_count}")

    # Collections with thumbnails
    collections_with_thumbnails =
      from(c in Collection, where: not is_nil(c.thumbnail), select: count(c.id))
      |> Repo.one()

    IO.puts("Collections with thumbnails: #{collections_with_thumbnails}")

    # Collections by status
    status_counts =
      from(c in Collection,
        group_by: c.status,
        select: {c.status, count(c.id)}
      )
      |> Repo.all()

    IO.puts("\nCollections by status:")

    Enum.each(status_counts, fn {status, count} ->
      IO.puts("  - #{status || "null"}: #{count}")
    end)

    # Items
    item_count = Repo.aggregate(Item, :count, :id)
    IO.puts("\nTotal Items: #{item_count}")

    # Items by status
    item_status_counts =
      from(i in Item,
        group_by: i.status,
        select: {i.status, count(i.id)}
      )
      |> Repo.all()

    IO.puts("Items by status:")

    Enum.each(item_status_counts, fn {status, count} ->
      IO.puts("  - #{status || "null"}: #{count}")
    end)

    # Collections without items
    collections_without_items =
      from(c in Collection,
        left_join: i in assoc(c, :items),
        where: is_nil(i.id),
        select: count(c.id)
      )
      |> Repo.one()

    if collections_without_items > 0 do
      IO.puts("⚠️  Collections without items: #{collections_without_items}")
    else
      IO.puts("✅ All collections have items")
    end
  end

  defp check_user_counts do
    IO.puts("\n3. USER COUNT SUMMARY")
    IO.puts("-" |> String.duplicate(40))

    total_users = Repo.aggregate(User, :count, :id)
    IO.puts("Total Users: #{total_users}")

    # Users by role
    role_counts =
      from(u in User,
        join: ur in assoc(u, :user_role),
        group_by: ur.name,
        select: {ur.name, count(u.id)}
      )
      |> Repo.all()

    IO.puts("\nUsers by Role:")

    Enum.each(role_counts, fn {role_name, count} ->
      IO.puts("  - #{role_name}: #{count}")
    end)

    # Users by member type
    type_counts =
      from(u in User,
        join: mt in assoc(u, :user_type),
        group_by: mt.name,
        select: {mt.name, count(u.id)}
      )
      |> Repo.all()

    IO.puts("\nUsers by Member Type:")

    Enum.each(type_counts, fn {type_name, count} ->
      IO.puts("  - #{type_name}: #{count}")
    end)

    # Users with profiles
    profile_count = Repo.aggregate(UserProfile, :count, :id)
    IO.puts("\nUser Profiles: #{profile_count}")

    members_without_profiles =
      from(u in User,
        join: ur in assoc(u, :user_role),
        left_join: up in assoc(u, :user_profile),
        where: ur.name == "Member" and is_nil(up.id),
        select: count(u.id)
      )
      |> Repo.one()

    if members_without_profiles > 0 do
      IO.puts("⚠️  Members without profiles: #{members_without_profiles}")
    else
      IO.puts("✅ All members have profiles")
    end
  end

  defp check_data_integrity do
    IO.puts("\n4. DATA INTEGRITY CHECK")
    IO.puts("-" |> String.duplicate(40))

    # Check for duplicate emails
    duplicate_emails =
      from(u in User,
        group_by: u.email,
        having: count(u.id) > 1,
        select: {u.email, count(u.id)}
      )
      |> Repo.all()

    if length(duplicate_emails) > 0 do
      IO.puts("⚠️  Duplicate emails found:")

      Enum.each(duplicate_emails, fn {email, count} ->
        IO.puts("  - #{email}: #{count} users")
      end)
    else
      IO.puts("✅ No duplicate emails")
    end

    # Check for duplicate usernames
    duplicate_usernames =
      from(u in User,
        group_by: u.username,
        having: count(u.id) > 1,
        select: {u.username, count(u.id)}
      )
      |> Repo.all()

    if length(duplicate_usernames) > 0 do
      IO.puts("⚠️  Duplicate usernames found:")

      Enum.each(duplicate_usernames, fn {username, count} ->
        IO.puts("  - #{username}: #{count} users")
      end)
    else
      IO.puts("✅ No duplicate usernames")
    end

    # Check for users without required fields
    users_without_email =
      from(u in User,
        where: is_nil(u.email) or u.email == "",
        select: count(u.id)
      )
      |> Repo.one()

    if users_without_email > 0 do
      IO.puts("⚠️  Users without email: #{users_without_email}")
    else
      IO.puts("✅ All users have emails")
    end

    # Check for users without member types
    users_without_type =
      from(u in User,
        where: is_nil(u.user_type_id),
        select: count(u.id)
      )
      |> Repo.one()

    if users_without_type > 0 do
      IO.puts("⚠️  Users without member type: #{users_without_type}")
    else
      IO.puts("✅ All users have member types")
    end

    # Check confirmed status
    unconfirmed_users =
      from(u in User,
        where: is_nil(u.confirmed_at),
        select: count(u.id)
      )
      |> Repo.one()

    IO.puts("Unconfirmed users: #{unconfirmed_users}")

    if unconfirmed_users == 0 do
      IO.puts("✅ All users are confirmed")
    end

    # Check for orphaned items (items without collections)
    orphaned_items =
      from(i in Item,
        left_join: c in assoc(i, :collection),
        where: is_nil(c.id),
        select: count(i.id)
      )
      |> Repo.one()

    if orphaned_items > 0 do
      IO.puts("⚠️  Orphaned items (without collections): #{orphaned_items}")
    else
      IO.puts("✅ All items are linked to collections")
    end
  end

  defp check_profiles do
    IO.puts("\n5. PROFILE DATA CHECK")
    IO.puts("-" |> String.duplicate(40))

    # Gender distribution
    gender_dist =
      from(up in UserProfile,
        group_by: up.gender,
        select: {up.gender, count(up.id)}
      )
      |> Repo.all()

    IO.puts("Gender distribution:")

    Enum.each(gender_dist, fn {gender, count} ->
      gender_label =
        case gender do
          "male" -> "Male"
          "female" -> "Female"
          nil -> "Not specified"
          _ -> gender
        end

      IO.puts("  - #{gender_label}: #{count}")
    end)

    # Profiles with birth dates
    profiles_with_birth_date =
      from(up in UserProfile,
        where: not is_nil(up.birth_date),
        select: count(up.id)
      )
      |> Repo.one()

    total_profiles = Repo.aggregate(UserProfile, :count, :id)
    IO.puts("\nProfiles with birth date: #{profiles_with_birth_date}/#{total_profiles}")

    # Profiles with phone numbers
    profiles_with_phone =
      from(up in UserProfile,
        where: not is_nil(up.phone_number) and up.phone_number != "",
        select: count(up.id)
      )
      |> Repo.one()

    IO.puts("Profiles with phone: #{profiles_with_phone}/#{total_profiles}")

    # Profiles with addresses
    profiles_with_address =
      from(up in UserProfile,
        where: not is_nil(up.address) and up.address != "",
        select: count(up.id)
      )
      |> Repo.one()

    IO.puts("Profiles with address: #{profiles_with_address}/#{total_profiles}")
  end

  defp check_sample_data do
    IO.puts("\n6. SAMPLE DATA")
    IO.puts("-" |> String.duplicate(40))

    # Show sample staff users
    staff_users =
      from(u in User,
        join: ur in assoc(u, :user_role),
        where: ur.name != "Member",
        limit: 5,
        select: {u.username, u.email, ur.name, u.last_login}
      )
      |> Repo.all()

    if length(staff_users) > 0 do
      IO.puts("Sample Staff Users:")

      Enum.each(staff_users, fn {username, email, role, last_login} ->
        last_login_str =
          case last_login do
            nil -> "Never"
            dt -> DateTime.to_string(dt)
          end

        IO.puts("  - #{username} (#{email}) - #{role} - Last login: #{last_login_str}")
      end)
    end

    # Show sample members with profiles
    members_with_profiles =
      from(u in User,
        join: ur in assoc(u, :user_role),
        join: mt in assoc(u, :user_type),
        join: up in assoc(u, :user_profile),
        where: ur.name == "Member",
        limit: 5,
        select: {u.username, u.email, mt.name, up.phone_number, up.organization}
      )
      |> Repo.all()

    if length(members_with_profiles) > 0 do
      IO.puts("\nSample Members with Profiles:")

      Enum.each(members_with_profiles, fn {username, email, member_type, phone, org} ->
        IO.puts("  - #{username} (#{email}) - #{member_type}")
        IO.puts("    Phone: #{phone || "N/A"}, Organization: #{org || "N/A"}")
      end)
    end

    # Show sample collections with items
    collections_with_items =
      from(c in Collection,
        join: i in assoc(c, :items),
        group_by: [c.id, c.title],
        having: count(i.id) > 0,
        limit: 5,
        select: {c.title, count(i.id)}
      )
      |> Repo.all()

    if length(collections_with_items) > 0 do
      IO.puts("\nSample Collections with Item Counts:")

      Enum.each(collections_with_items, fn {title, item_count} ->
        title_display =
          if String.length(title) > 50 do
            String.slice(title, 0..47) <> "..."
          else
            title
          end

        IO.puts("  - #{title_display} (#{item_count} items)")
      end)
    end
  end
end
