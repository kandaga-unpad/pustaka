defmodule Voile.Migration.UserImporter do
  @moduledoc """
  Imports user data from CSV files with optimized streaming and batch processing.

  Expected CSV structure:
  - scripts/csv_data/user/user.csv
  """

  import Ecto.Query
  import Voile.Migration.Common

  alias Voile.Repo
  alias Voile.Schema.Accounts.{User, Role}
  alias Voile.Schema.Master.MemberType
  alias Voile.Schema.System.Node

  # Cache for frequently accessed data
  @type cache :: %{
          roles: map(),
          member_type: struct() | nil,
          node: struct() | nil,
          existing_emails: MapSet.t()
        }

  def import_all(batch_size \\ 1000) do
    IO.puts("👤 Starting user data import...")

    # Setup default roles and member types if needed
    setup_default_data()

    # Initialize cache with frequently accessed data
    cache = initialize_cache()

    # Get user files
    files = get_csv_files("user")

    if Enum.empty?(files) do
      IO.puts("⚠️ No user files found")
      %{inserted: 0, skipped: 0, errors: 0}
    else
      stats =
        files
        |> Stream.with_index(1)
        |> Enum.reduce(%{inserted: 0, skipped: 0, errors: 0}, fn {file, index}, acc ->
          IO.puts("\n🔄 Processing user file #{index}/#{length(files)}: #{Path.basename(file)}")

          file_stats = process_user_file_optimized(file, batch_size, cache)

          %{
            inserted: acc.inserted + file_stats.inserted,
            skipped: acc.skipped + file_stats.skipped,
            errors: acc.errors + file_stats.errors
          }
        end)

      print_summary("USER IMPORT", %{
        "Total Users Inserted" => stats.inserted,
        "Total Users Skipped" => stats.skipped,
        "Total Errors" => stats.errors
      })

      stats
    end
  end

  # Initialize cache with frequently accessed data to avoid repeated DB queries
  defp initialize_cache do
    IO.puts("🔄 Initializing cache...")

    # Cache all roles
    roles =
      Repo.all(Role)
      |> Enum.into(%{}, fn role -> {role.name, role} end)

    # Cache Staff member type specifically for user imports
    member_type = Repo.get_by(MemberType, slug: "staff")
    node = Repo.one(from(n in Node, limit: 1))

    # Cache existing user emails for faster duplicate checking
    existing_emails =
      Repo.all(from(u in User, select: u.email))
      |> MapSet.new()

    IO.puts(
      "✅ Cache initialized with #{map_size(roles)} roles, Staff member type, and #{MapSet.size(existing_emails)} existing emails"
    )

    %{
      roles: roles,
      member_type: member_type,
      node: node,
      existing_emails: existing_emails
    }
  end

  # Optimized file processing using streams and batching
  defp process_user_file_optimized(file_path, batch_size, cache) do
    stats_ref = :ets.new(:import_stats, [:set, :public])
    :ets.insert(stats_ref, {:inserted, 0})
    :ets.insert(stats_ref, {:skipped, 0})
    :ets.insert(stats_ref, {:errors, 0})

    try do
      File.stream!(file_path)
      |> CSVParser.parse_stream()
      # Skip header
      |> Stream.drop(1)
      |> Stream.with_index(1)
      |> Stream.map(fn {row, index} ->
        {prepare_user_data(row, cache), index}
      end)
      |> Stream.filter(fn {{status, _}, _index} -> status == :ok end)
      |> Stream.map(fn {{:ok, user_data}, index} -> {user_data, index} end)
      |> Enum.chunk_every(batch_size)
      |> Enum.each(fn batch ->
        process_batch(batch, stats_ref, cache)
      end)

      # Return final stats
      [{:inserted, inserted}] = :ets.lookup(stats_ref, :inserted)
      [{:skipped, skipped}] = :ets.lookup(stats_ref, :skipped)
      [{:errors, errors}] = :ets.lookup(stats_ref, :errors)

      %{inserted: inserted, skipped: skipped, errors: errors}
    after
      :ets.delete(stats_ref)
    end
  end

  # Process a batch of users with a single transaction for optimal connection usage
  defp process_batch(batch, stats_ref, _cache) do
    {user_attrs, indexes} = Enum.unzip(batch)

    # Filter out users that already exist (batch check)
    emails = Enum.map(user_attrs, & &1.email)

    existing_in_batch =
      Repo.all(from(u in User, where: u.email in ^emails, select: u.email))
      |> MapSet.new()

    {valid_users, _skipped_count} =
      user_attrs
      |> Enum.zip(indexes)
      |> Enum.split_with(fn {attrs, _index} ->
        not MapSet.member?(existing_in_batch, attrs.email)
      end)

    # Update skipped count
    :ets.update_counter(stats_ref, :skipped, length(batch) - length(valid_users))

    if length(valid_users) > 0 do
      # Use transaction for better connection management
      try do
        Repo.transaction(
          fn ->
            now = DateTime.utc_now() |> DateTime.truncate(:second)

            # Extract role_ids and prepare insert data
            {insert_data, role_mappings} =
              valid_users
              |> Enum.map(fn {attrs, _index} ->
                role_id = attrs[:role_id]

                user_data =
                  attrs
                  |> Map.put(:inserted_at, attrs[:inserted_at] || now)
                  |> Map.put(:updated_at, attrs[:updated_at] || now)
                  # Users will onboard later
                  |> Map.put(:confirmed_at, nil)
                  # No password during migration
                  |> Map.delete(:password)
                  |> Map.delete(:hashed_password)
                  # Remove role_id as it's not a direct field
                  |> Map.delete(:role_id)

                {user_data, %{email: attrs.email, role_id: role_id}}
              end)
              |> Enum.unzip()

            # Insert users
            {insert_count, inserted_users} =
              Repo.insert_all(User, insert_data, returning: [:id, :email], timeout: :infinity)

            # Create role assignments for inserted users
            if insert_count > 0 do
              role_assignments =
                inserted_users
                |> Enum.map(fn user ->
                  role_mapping = Enum.find(role_mappings, fn rm -> rm.email == user.email end)

                  if role_mapping && role_mapping.role_id do
                    %{
                      user_id: user.id,
                      role_id: role_mapping.role_id,
                      inserted_at: now,
                      updated_at: now
                    }
                  end
                end)
                |> Enum.reject(&is_nil/1)

              # Insert role assignments if any
              if length(role_assignments) > 0 do
                alias Voile.Schema.Accounts.UserRoleAssignment

                Repo.insert_all(UserRoleAssignment, role_assignments,
                  on_conflict: :nothing,
                  timeout: :infinity
                )
              end
            end

            insert_count
          end,
          timeout: :infinity
        )
        |> case do
          {:ok, insert_count} ->
            :ets.update_counter(stats_ref, :inserted, insert_count)

            # Progress indicator
            if rem(insert_count, 100) == 0 do
              IO.write(".")
            end

          {:error, reason} ->
            IO.puts("\n⚠️ User batch transaction error: #{inspect(reason)}")
            :ets.update_counter(stats_ref, :errors, length(valid_users))
        end
      rescue
        e ->
          IO.puts("\n⚠️ Batch insert error: #{inspect(e)}")
          :ets.update_counter(stats_ref, :errors, length(valid_users))
      end
    end
  end

  # Prepare user data from CSV row using cached data - NO PASSWORD FIELD
  defp prepare_user_data(
         [
           user_id,
           username,
           realname,
           _passwd,
           email,
           user_type,
           user_image,
           social_media,
           last_login,
           last_login_ip,
           groups,
           _node_id,
           input_date,
           last_update,
           _show_on_profile | _rest
         ],
         cache
       ) do
    clean_email = safe_string_trim(email)
    clean_username = safe_string_trim(username)

    if clean_email && clean_username do
      # Check cache for existing email
      if MapSet.member?(cache.existing_emails, clean_email) do
        {:skip, "User with email #{clean_email} already exists"}
      else
        user_role = map_user_type_to_role_cached(user_type, cache.roles)
        now = DateTime.utc_now() |> DateTime.truncate(:second)

        attrs = %{
          username: clean_username,
          identifier: parse_int(user_id),
          email: clean_email,
          fullname: safe_string_trim(realname) || clean_username,
          # Store role_id for later assignment via user_role_assignments
          role_id: user_role && user_role.id,
          user_type_id: cache.member_type && cache.member_type.id,
          user_image: safe_string_trim(user_image),
          social_media: parse_social_media(social_media),
          groups: parse_groups(groups),
          last_login: parse_datetime(last_login),
          last_login_ip: safe_string_trim(last_login_ip) || "",
          node_id: cache.node && cache.node.id,
          # Default password: "changeme123"
          hashed_password:
            "$pbkdf2-sha512$160000$OmHm5yQ4w.ZGpn7fvUcGzg$uBPzZQ2UOQ2oZFJt9JQZhVqJQa2wC9.XqBZQv1.2qHZqJQa2wC9.XqBZQv1.2qHZqJQa2wC9.XqBZQv1.2qHZqJQa2wC9.X",
          # Not confirmed - will be handled by SSO or email confirmation
          confirmed_at: nil,
          inserted_at: parse_datetime(input_date) || now,
          updated_at: parse_datetime(last_update) || now
        }

        {:ok, attrs}
      end
    else
      {:skip, "Missing required email or username"}
    end
  end

  defp prepare_user_data(_invalid_row, _cache) do
    {:error, "Invalid row format"}
  end

  defp setup_default_data do
    # ensure_default_user_roles()
    ensure_default_member_type()
    ensure_default_node()
  end

  # defp ensure_default_user_roles do
  #   # Create Member role if it doesn't exist
  #   unless Repo.get_by(UserRole, name: "Member") do
  #     %UserRole{}
  #     |> UserRole.changeset(%{
  #       name: "Member",
  #       description: "Default member role",
  #       permissions: %{
  #         "catalog" => %{"read" => true},
  #         "profile" => %{"read" => true, "update" => true}
  #       }
  #     })
  #     |> Repo.insert!()
  #   end

  #   # Create Admin role if it doesn't exist
  #   unless Repo.get_by(UserRole, name: "Admin") do
  #     %UserRole{}
  #     |> UserRole.changeset(%{
  #       name: "Admin",
  #       description: "Administrator role",
  #       permissions: %{
  #         "users" => %{"create" => true, "read" => true, "update" => true, "delete" => true},
  #         "catalog" => %{"create" => true, "read" => true, "update" => true, "delete" => true},
  #         "library" => %{"create" => true, "read" => true, "update" => true, "delete" => true}
  #       }
  #     })
  #     |> Repo.insert!()
  #   end
  # end

  defp ensure_default_member_type do
    unless Repo.one(from(mt in MemberType, limit: 1)) do
      IO.puts("⚠️ No member types found. Please ensure master data is imported first.")
    end
  end

  defp ensure_default_node do
    unless Repo.one(from(n in Node, limit: 1)) do
      IO.puts("Creating default node...")

      %Node{}
      |> Node.changeset(%{
        name: "Main Library",
        abbr: "MAIN",
        description: "Default node for imported users"
      })
      |> Repo.insert!()
    end
  end

  defp map_user_type_to_role_cached(user_type, roles_cache) do
    case user_type do
      # Admin
      "1" -> roles_cache["admin"]
      # Librarian
      "2" -> roles_cache["librarian"]
      # Editor
      "3" -> roles_cache["editor"]
      _ -> roles_cache["member"]
    end
  end

  defp parse_social_media(social_str) when social_str in [nil, ""], do: %{}

  defp parse_social_media(social_str) do
    # Handle PHP serialized social media - simplified parser
    %{}
    |> maybe_add_social("fb", extract_social_value(social_str, "fb"))
    |> maybe_add_social("tw", extract_social_value(social_str, "tw"))
    |> maybe_add_social("li", extract_social_value(social_str, "li"))
    |> maybe_add_social("gp", extract_social_value(social_str, "gp"))
  end

  defp extract_social_value(social_str, key) do
    case Regex.run(~r/s:2:"#{key}";s:\d+:"([^"]+)"/, social_str) do
      [_, value] -> value
      _ -> nil
    end
  end

  defp maybe_add_social(map, _key, nil), do: map
  defp maybe_add_social(map, key, value), do: Map.put(map, key, value)

  defp parse_groups(groups_str) when groups_str in [nil, ""], do: []

  defp parse_groups(groups_str) do
    # Handle PHP serialized arrays - extract values between quotes
    Regex.scan(~r/s:\d+:"([^"]+)"/, groups_str, capture: :all_but_first)
    |> Enum.map(fn [group] -> group end)
    # Filter out -1 values
    |> Enum.filter(fn group -> group != "-1" end)
  end
end
