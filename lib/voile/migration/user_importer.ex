defmodule Voile.Migration.UserImporter do
  @moduledoc """
  Imports user data from CSV files with optimized streaming and batch processing.

  Expected CSV structure:
  - scripts/csv_data/user/user.csv
  """

  import Ecto.Query
  import Voile.Migration.Common

  alias Voile.Repo
  alias Voile.Schema.Accounts.{User, UserRole}
  alias Voile.Schema.Master.MemberType
  alias Voile.Schema.System.Node

  # Import password hashing library
  alias Pbkdf2

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

  # Alternative method for non-batched processing (for comparison/fallback)
  def import_all_legacy(batch_size \\ 500) do
    IO.puts("👤 Starting user data import (legacy mode)...")

    # Setup default roles and member types if needed
    setup_default_data()

    # Get user files
    files = get_csv_files("user")

    if Enum.empty?(files) do
      IO.puts("⚠️ No user files found")
      %{inserted: 0, skipped: 0, errors: 0}
    else
      stats =
        files
        |> Enum.with_index(1)
        |> Enum.reduce(%{inserted: 0, skipped: 0, errors: 0}, fn {file, index}, acc ->
          IO.puts("\n🔄 Processing user file #{index}/#{length(files)}: #{Path.basename(file)}")

          file_stats = process_user_file_legacy(file, batch_size)

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
      Repo.all(UserRole)
      |> Enum.into(%{}, fn role -> {role.name, role} end)

    # Cache member type and node
    member_type = Repo.one(from(mt in MemberType, limit: 1))
    node = Repo.one(from(n in Node, limit: 1))

    # Cache existing user emails for faster duplicate checking
    existing_emails =
      Repo.all(from(u in User, select: u.email))
      |> MapSet.new()

    IO.puts(
      "✅ Cache initialized with #{map_size(roles)} roles and #{MapSet.size(existing_emails)} existing emails"
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
      |> Stream.chunk_every(batch_size)
      |> Stream.each(fn batch ->
        process_batch(batch, stats_ref, cache)
      end)
      |> Stream.run()

      # Return final stats
      [{:inserted, inserted}] = :ets.lookup(stats_ref, :inserted)
      [{:skipped, skipped}] = :ets.lookup(stats_ref, :skipped)
      [{:errors, errors}] = :ets.lookup(stats_ref, :errors)

      %{inserted: inserted, skipped: skipped, errors: errors}
    after
      :ets.delete(stats_ref)
    end
  end

  # Legacy file processing method (kept for comparison/fallback)
  defp process_user_file_legacy(file_path, _batch_size) do
    stats = %{inserted: 0, skipped: 0, errors: 0}

    File.stream!(file_path)
    |> CSVParser.parse_stream()
    |> Stream.with_index()
    |> Enum.reduce(stats, fn {row, index}, acc ->
      if index == 0 do
        # Skip header row
        acc
      else
        case process_user_row(row) do
          {:ok, _user} ->
            if rem(index, 100) == 0, do: IO.write(".")
            %{acc | inserted: acc.inserted + 1}

          {:skip, _reason} ->
            %{acc | skipped: acc.skipped + 1}

          {:error, reason} ->
            if rem(index, 1000) == 0 do
              IO.puts("\n⚠️ Error on line #{index + 1}: #{reason}")
            end

            %{acc | errors: acc.errors + 1}
        end
      end
    end)
  end

  # Process a batch of users with a single transaction
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
      # Batch insert valid users - skip changeset creation for performance
      try do
        # Use Repo.insert_all for better performance
        now = DateTime.utc_now() |> DateTime.truncate(:second)

        insert_data =
          valid_users
          |> Enum.map(fn {attrs, _index} ->
            attrs
            |> Map.put(:inserted_at, attrs[:inserted_at] || now)
            |> Map.put(:updated_at, attrs[:updated_at] || now)
            |> Map.put(:confirmed_at, attrs[:confirmed_at] || DateTime.utc_now())
            |> hash_password_for_insert()
          end)

        {insert_count, _} = Repo.insert_all(User, insert_data)
        :ets.update_counter(stats_ref, :inserted, insert_count)

        # Progress indicator
        if rem(insert_count, 100) == 0 do
          IO.write(".")
        end
      rescue
        e ->
          IO.puts("\n⚠️ Batch insert error: #{inspect(e)}")
          :ets.update_counter(stats_ref, :errors, length(valid_users))
      end
    end
  end

  # Hash password for batch insert
  defp hash_password_for_insert(attrs) do
    case Map.get(attrs, :password) do
      nil ->
        attrs

      password ->
        Map.put(attrs, :hashed_password, Pbkdf2.hash_pwd_salt(password))
        |> Map.delete(:password)
    end
  end

  # Prepare user data from CSV row using cached data
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

        attrs = %{
          username: clean_username,
          identifier: parse_int(user_id),
          email: clean_email,
          fullname: safe_string_trim(realname) || clean_username,
          user_role_id: user_role && user_role.id,
          user_type_id: cache.member_type && cache.member_type.id,
          # Set a default password - users will need to reset it
          password: generate_temp_password(clean_username),
          user_image: safe_string_trim(user_image),
          social_media: parse_social_media(social_media),
          groups: parse_groups(groups),
          last_login: parse_datetime(last_login),
          last_login_ip: safe_string_trim(last_login_ip) || "",
          node_id: cache.node && cache.node.id,
          # Auto-confirm imported users
          confirmed_at: DateTime.utc_now(),
          inserted_at: parse_datetime(input_date) || DateTime.utc_now(),
          updated_at: parse_datetime(last_update) || DateTime.utc_now()
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

  # Legacy function kept for backward compatibility but not used in optimized version
  defp process_user_row([
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
       ]) do
    # Check if user already exists
    clean_email = safe_string_trim(email)
    clean_username = safe_string_trim(username)

    if clean_email && clean_username do
      existing_user = Repo.get_by(User, email: clean_email)

      if existing_user do
        {:skip, "User with email #{clean_email} already exists"}
      else
        user_role = map_user_type_to_role(user_type)
        member_type = get_default_member_type()
        node = get_default_node()

        attrs = %{
          username: clean_username,
          identifier: parse_int(user_id),
          email: clean_email,
          fullname: safe_string_trim(realname) || clean_username,
          user_role_id: user_role && user_role.id,
          user_type_id: member_type && member_type.id,
          # Set a default password - users will need to reset it
          password: generate_temp_password(clean_username),
          user_image: safe_string_trim(user_image),
          social_media: parse_social_media(social_media),
          groups: parse_groups(groups),
          last_login: parse_datetime(last_login),
          last_login_ip: safe_string_trim(last_login_ip) || "",
          node_id: node && node.id,
          # Auto-confirm imported users
          confirmed_at: DateTime.utc_now(),
          inserted_at: parse_datetime(input_date) || DateTime.utc_now(),
          updated_at: parse_datetime(last_update) || DateTime.utc_now()
        }

        changeset =
          User.changeset(%User{}, attrs,
            hash_password: true,
            validate_email: false,
            validate_username: false
          )

        case Repo.insert(changeset) do
          {:ok, user} -> {:ok, user}
          {:error, changeset} -> {:error, "Changeset error: #{inspect(changeset.errors)}"}
        end
      end
    else
      {:skip, "Missing required email or username"}
    end
  end

  defp process_user_row(_invalid_row) do
    {:error, "Invalid row format"}
  end

  defp setup_default_data do
    ensure_default_user_roles()
    ensure_default_member_type()
    ensure_default_node()
  end

  defp ensure_default_user_roles do
    # Create Member role if it doesn't exist
    unless Repo.get_by(UserRole, name: "Member") do
      %UserRole{}
      |> UserRole.changeset(%{
        name: "Member",
        description: "Default member role",
        permissions: %{
          "catalog" => %{"read" => true},
          "profile" => %{"read" => true, "update" => true}
        }
      })
      |> Repo.insert!()
    end

    # Create Admin role if it doesn't exist
    unless Repo.get_by(UserRole, name: "Admin") do
      %UserRole{}
      |> UserRole.changeset(%{
        name: "Admin",
        description: "Administrator role",
        permissions: %{
          "users" => %{"create" => true, "read" => true, "update" => true, "delete" => true},
          "catalog" => %{"create" => true, "read" => true, "update" => true, "delete" => true},
          "library" => %{"create" => true, "read" => true, "update" => true, "delete" => true}
        }
      })
      |> Repo.insert!()
    end
  end

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
      "1" -> roles_cache["Admin"]
      # Librarian (also admin-like)
      "2" -> roles_cache["Admin"]
      # Member
      "3" -> roles_cache["Member"]
      _ -> roles_cache["Member"]
    end
  end

  # Legacy function for backward compatibility
  defp map_user_type_to_role(user_type) do
    case user_type do
      # Admin
      "1" -> get_role_by_name("Admin")
      # Librarian (also admin-like)
      "2" -> get_role_by_name("Admin")
      # Member
      "3" -> get_role_by_name("Member")
      _ -> get_role_by_name("Member")
    end
  end

  defp get_role_by_name(name) do
    Repo.get_by(UserRole, name: name)
  end

  defp get_default_member_type do
    Repo.one(from(mt in MemberType, limit: 1))
  end

  defp get_default_node do
    Repo.one(from(n in Node, limit: 1))
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

  defp generate_temp_password(username) do
    "temp_" <> String.slice(username, 0..7)
  end
end
