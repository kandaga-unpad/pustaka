defmodule Voile.Migration.MemberImporter do
  @moduledoc """
  Imports member data from CSV files with optimized streaming and batch processing.

  Expected CSV structure:
  - scripts/csv_data/member/member_*.csv
  """

  import Ecto.Query
  import Voile.Migration.Common

  alias Voile.Repo
  alias Voile.Schema.Accounts.{User, UserRole, UserProfile}
  alias Voile.Schema.Master.MemberType
  alias Voile.Schema.System.Node

  # Cache for frequently accessed data
  @type cache :: %{
          member_role: struct() | nil,
          member_types: map(),
          nodes: map(),
          existing_emails: MapSet.t(),
          existing_usernames: MapSet.t()
        }

  def import_all(batch_size \\ 1000) do
    IO.puts("👥 Starting member data import...")

    # Setup default data
    setup_default_data()

    # Initialize cache with frequently accessed data
    cache = initialize_cache()

    # Get member files
    files = get_csv_files("member")

    if Enum.empty?(files) do
      IO.puts("⚠️ No member files found")
      %{inserted: 0, skipped: 0, errors: 0}
    else
      stats =
        files
        |> Stream.with_index(1)
        |> Enum.reduce(%{inserted: 0, skipped: 0, errors: 0}, fn {file, index}, acc ->
          IO.puts("\n🔄 Processing member file #{index}/#{length(files)}: #{Path.basename(file)}")

          # Extract node info from filename for member_N.csv files
          node_id = extract_node_from_filename(file)

          file_stats = process_member_file_optimized(file, batch_size, node_id, cache)

          %{
            inserted: acc.inserted + file_stats.inserted,
            skipped: acc.skipped + file_stats.skipped,
            errors: acc.errors + file_stats.errors
          }
        end)

      print_summary("MEMBER IMPORT", %{
        "Total Members Inserted" => stats.inserted,
        "Total Members Skipped" => stats.skipped,
        "Total Errors" => stats.errors
      })

      stats
    end
  end

  # Initialize cache with frequently accessed data to avoid repeated DB queries
  defp initialize_cache do
    IO.puts("🔄 Initializing member cache...")

    # Cache member role
    member_role = Repo.get_by(UserRole, name: "Member")

    # Cache all member types
    member_types =
      Repo.all(MemberType)
      |> Enum.into(%{}, fn mt -> {mt.id, mt} end)

    # Cache all nodes
    nodes =
      Repo.all(Node)
      |> Enum.into(%{}, fn node -> {node.id, node} end)

    # Cache existing emails and usernames
    existing_emails =
      from(u in User, select: u.email)
      |> Repo.all()
      |> MapSet.new()

    existing_usernames =
      from(u in User, select: u.username)
      |> Repo.all()
      |> MapSet.new()

    IO.puts("✅ Cache initialized:")
    IO.puts("  - Member role: #{if member_role, do: "✓", else: "✗"}")
    IO.puts("  - Member types: #{map_size(member_types)}")
    IO.puts("  - Nodes: #{map_size(nodes)}")
    IO.puts("  - Existing emails: #{MapSet.size(existing_emails)}")
    IO.puts("  - Existing usernames: #{MapSet.size(existing_usernames)}")

    %{
      member_role: member_role,
      member_types: member_types,
      nodes: nodes,
      existing_emails: existing_emails,
      existing_usernames: existing_usernames
    }
  end

  # Optimized file processing using streams and batching
  defp process_member_file_optimized(file_path, batch_size, node_id, cache) do
    IO.puts("📋 Processing for node: #{get_node_name(node_id)}")

    stats_ref = :ets.new(:member_import_stats, [:set, :public])
    :ets.insert(stats_ref, {:inserted, 0})
    :ets.insert(stats_ref, {:skipped, 0})
    :ets.insert(stats_ref, {:errors, 0})

    try do
      File.stream!(file_path)
      |> CSVParser.parse_stream()
      # Skip header
      |> Stream.drop(1)
      |> Stream.with_index(1)
      |> Stream.map(fn {row, line_num} ->
        {prepare_member_data(row, node_id, cache), line_num}
      end)
      |> Stream.filter(fn {{status, _}, _line_num} -> status == :ok end)
      |> Stream.map(fn {{:ok, {user_data, profile_data}}, line_num} ->
        {user_data, profile_data, line_num}
      end)
      |> Stream.chunk_every(batch_size)
      |> Stream.each(fn batch ->
        process_member_batch(batch, stats_ref)
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

  # Process a batch of members with single transaction
  defp process_member_batch(batch, stats_ref) do
    {users_data, profiles_data, _line_nums} =
      batch
      |> Enum.reduce({[], [], []}, fn {user_data, profile_data, line_num},
                                      {users, profiles, lines} ->
        {[user_data | users], [profile_data | profiles], [line_num | lines]}
      end)

    # Batch insert users first
    users_inserted =
      if length(users_data) > 0 do
        try do
          # Hash passwords for batch insert
          users_with_hashed_passwords =
            users_data
            |> Enum.map(&hash_password_for_insert/1)

          {count, inserted_users} =
            Repo.insert_all(User, Enum.reverse(users_with_hashed_passwords),
              on_conflict: :nothing,
              returning: [:id]
            )

          # Update user profiles with correct user_ids
          if count > 0 and length(profiles_data) > 0 do
            profiles_with_user_ids =
              inserted_users
              |> Enum.zip(Enum.reverse(profiles_data))
              |> Enum.map(fn {user, profile_data} ->
                Map.put(profile_data, :user_id, user.id)
              end)

            # Batch insert profiles
            {_profile_count, _} =
              Repo.insert_all(UserProfile, profiles_with_user_ids,
                on_conflict: :nothing,
                returning: false
              )
          end

          :ets.update_counter(stats_ref, :inserted, count)
          count
        rescue
          e ->
            IO.puts("\n⚠️ Member batch insert error: #{inspect(e)}")
            :ets.update_counter(stats_ref, :errors, length(users_data))
            0
        end
      else
        0
      end

    # Progress indicator
    if rem(users_inserted, 100) == 0 and users_inserted > 0 do
      IO.write(".")
    end
  end

  # Hash password for batch insert
  defp hash_password_for_insert(user_attrs) do
    case Map.get(user_attrs, :password) do
      nil ->
        user_attrs

      password ->
        Map.put(user_attrs, :hashed_password, Pbkdf2.hash_pwd_salt(password))
        |> Map.delete(:password)
    end
  end

  # Prepare member data using cached data (optimized version)
  defp prepare_member_data(row, node_id, cache) when length(row) >= 20 do
    [
      member_id,
      member_name,
      gender,
      birth_date,
      member_type_id,
      member_address,
      member_mail_address,
      member_email,
      postal_code,
      inst_name,
      _is_new,
      member_image,
      _pin,
      member_phone,
      member_fax,
      member_since_date,
      register_date,
      expire_date,
      member_notes,
      is_pending | _rest
    ] = row

    # Basic validation
    clean_name = safe_string_trim(member_name)
    clean_email = safe_string_trim(member_email)

    cond do
      is_nil(clean_name) or clean_name == "" ->
        {:skip, "Missing member name"}

      true ->
        username = generate_username_cached(clean_name, member_id, cache.existing_usernames)
        final_email = ensure_unique_email_cached(clean_email, member_id, cache.existing_emails)

        member_type = get_member_type_cached(member_type_id, cache.member_types)
        node = get_node_cached(node_id, cache.nodes)

        now = DateTime.utc_now() |> DateTime.truncate(:second)

        # Create user record data
        user_attrs = %{
          username: username,
          identifier: parse_int(member_id),
          email: final_email,
          fullname: clean_name,
          user_role_id: cache.member_role && cache.member_role.id,
          user_type_id: member_type && member_type.id,
          password: generate_temp_password(member_id || username),
          user_image: clean_image_name(member_image),
          node_id: node && node.id,
          confirmed_at: DateTime.utc_now(),
          inserted_at: parse_datetime(register_date) || now,
          updated_at: now
        }

        # Create user profile record data (user_id will be set later)
        profile_attrs = %{
          # Will be set after user insert
          user_id: nil,
          gender: map_gender(gender),
          birth_date: parse_date(birth_date),
          phone_number: safe_string_trim(member_phone),
          fax_number: safe_string_trim(member_fax),
          address: combine_addresses(member_address, member_mail_address),
          postal_code: safe_string_trim(postal_code),
          organization: safe_string_trim(inst_name),
          notes: safe_string_trim(member_notes),
          member_since: parse_date(member_since_date),
          expires_at: parse_date(expire_date),
          is_active: parse_is_active(is_pending),
          inserted_at: now,
          updated_at: now
        }

        {:ok, {user_attrs, profile_attrs}}
    end
  rescue
    e ->
      {:error, "Exception: #{Exception.message(e)}"}
  end

  defp prepare_member_data(_invalid_row, _node_id, _cache) do
    {:skip, "Invalid row format - insufficient columns"}
  end

  # Cached helper functions for better performance
  defp generate_username_cached(clean_name, member_id, existing_usernames) do
    base_username = generate_username_base(clean_name, member_id)
    ensure_unique_username_cached(base_username, existing_usernames)
  end

  defp generate_username_base(member_name, member_id) do
    # Generate username from name, fallback to member_id
    base_username =
      member_name
      |> String.downcase()
      |> String.replace(~r/[^a-z0-9]/, "")
      |> String.slice(0..10)

    if String.length(base_username) < 3 do
      "member_" <> String.slice(to_string(member_id), -6..-1//1)
    else
      base_username
    end
  end

  defp ensure_unique_username_cached(username, existing_usernames, counter \\ 0) do
    test_username = if counter == 0, do: username, else: "#{username}#{counter}"

    if MapSet.member?(existing_usernames, test_username) do
      ensure_unique_username_cached(username, existing_usernames, counter + 1)
    else
      test_username
    end
  end

  defp ensure_unique_email_cached(email, member_id, existing_emails) do
    base_email =
      if email in [nil, ""], do: "member_#{member_id}@library.local", else: String.trim(email)

    ensure_unique_email_in_cache(base_email, existing_emails)
  end

  defp ensure_unique_email_in_cache(email, existing_emails, counter \\ 0) do
    test_email = if counter == 0, do: email, else: add_counter_to_email(email, counter)

    if MapSet.member?(existing_emails, test_email) do
      ensure_unique_email_in_cache(email, existing_emails, counter + 1)
    else
      test_email
    end
  end

  defp add_counter_to_email(email, counter) do
    case String.split(email, "@") do
      [local, domain] -> "#{local}#{counter}@#{domain}"
      _ -> "#{email}#{counter}"
    end
  end

  defp get_member_type_cached(member_type_id, member_types_cache) do
    case parse_int(member_type_id) do
      nil -> nil
      id -> Map.get(member_types_cache, id)
    end
  end

  defp get_node_cached(node_id, nodes_cache) do
    case to_string(node_id) |> Integer.parse() do
      {id, ""} -> Map.get(nodes_cache, id)
      _ -> nil
    end
  end

  defp extract_node_from_filename(file_path) do
    basename = Path.basename(file_path)

    case Regex.run(~r/member_(\d+)\.csv$/, basename) do
      [_full_match, number_str] ->
        case Integer.parse(number_str) do
          {number, ""} -> number
          # Default to 20 (main library)
          _ -> "20"
        end

      nil ->
        # Default for member.csv
        "20"
    end
  end

  defp get_node_name(node_id) do
    case to_string(node_id) do
      "1" -> "Fakultas Hukum"
      "2" -> "Fakultas Ekonomi dan Bisnis"
      "3" -> "Fakultas Kedokteran"
      "4" -> "Fakultas MIPA"
      "5" -> "Fakultas Pertanian"
      "6" -> "Fakultas Kedokteran Hewan"
      "7" -> "Fakultas Ilmu Sosial dan Ilmu Politik"
      "8" -> "Fakultas Ilmu Budaya"
      "9" -> "Fakultas Psikologi"
      "10" -> "Fakultas Peternakan"
      "11" -> "Fakultas Komunikasi"
      "12" -> "Fakultas Keperawatan"
      "13" -> "Fakultas Farmasi"
      "14" -> "Fakultas Teknik Geologi"
      "15" -> "Fakultas Perikanan dan Ilmu Kelautan"
      "16" -> "Fakultas Teknologi Industri Pertanian"
      "17" -> "Fakultas Kedokteran Gigi"
      "18" -> "Sekolah Pascasarjana"
      "19" -> "DRPM"
      "20" -> "Perpustakaan Pusat"
      "21" -> "Other"
      _ -> "Unknown (#{node_id})"
    end
  end

  defp setup_default_data do
    ensure_member_role()
    ensure_default_member_types()
    ensure_default_nodes()
  end

  defp ensure_member_role do
    unless Repo.get_by(UserRole, name: "Member") do
      %UserRole{}
      |> UserRole.changeset(%{
        name: "Member",
        description: "Library member role",
        permissions: %{
          "catalog" => %{"read" => true},
          "profile" => %{"read" => true, "update" => true}
        }
      })
      |> Repo.insert!()
    end
  end

  defp ensure_default_member_types do
    # Create default member type if none exist
    unless Repo.one(from(mt in MemberType, limit: 1)) do
      IO.puts("Creating default member type...")

      %MemberType{}
      |> MemberType.changeset(%{
        name: "General",
        loan_limit: 5,
        loan_period: 14,
        fine_per_day: 1000,
        description: "General library member"
      })
      |> Repo.insert!()
    end
  end

  defp ensure_default_nodes do
    # Ensure all nodes exist
    nodes = [
      {1, "Fakultas Hukum", "FH"},
      {2, "Fakultas Ekonomi dan Bisnis", "FEB"},
      {3, "Fakultas Kedokteran", "FK"},
      {4, "Fakultas MIPA", "FMIPA"},
      {5, "Fakultas Pertanian", "FP"},
      {6, "Fakultas Kedokteran Hewan", "FKH"},
      {7, "Fakultas Ilmu Sosial dan Ilmu Politik", "FISIP"},
      {8, "Fakultas Ilmu Budaya", "FIB"},
      {9, "Fakultas Psikologi", "FPSI"},
      {10, "Fakultas Peternakan", "FAPET"},
      {11, "Fakultas Komunikasi", "FKOM"},
      {12, "Fakultas Keperawatan", "FIKEP"},
      {13, "Fakultas Farmasi", "FFAR"},
      {14, "Fakultas Teknik Geologi", "FTG"},
      {15, "Fakultas Perikanan dan Ilmu Kelautan", "FPIK"},
      {16, "Fakultas Teknologi Industri Pertanian", "FTIP"},
      {17, "Fakultas Kedokteran Gigi", "FKG"},
      {18, "Sekolah Pascasarjana", "SPS"},
      {19, "DRPM", "DRPM"},
      {20, "Perpustakaan Pusat", "PUSAT"},
      {21, "Other", "OTHER"}
    ]

    Enum.each(nodes, fn {id, name, abbr} ->
      unless Repo.get_by(Node, id: id) do
        %Node{}
        |> Node.changeset(%{id: id, name: name, abbr: abbr, description: name})
        |> Repo.insert()
      end
    end)
  end

  defp map_gender("0"), do: "female"
  defp map_gender("1"), do: "male"
  defp map_gender(_), do: nil

  defp combine_addresses(addr1, addr2) do
    addrs =
      [addr1, addr2]
      |> Enum.map(&safe_string_trim/1)
      |> Enum.reject(&(&1 == "" or &1 == nil))

    case addrs do
      [] -> nil
      [single] -> single
      multiple -> Enum.join(multiple, "\n")
    end
  end

  defp clean_image_name(image) when image in [nil, "", "square-image.png", "person.png"], do: nil
  defp clean_image_name(image), do: safe_string_trim(image)

  # Not pending = active
  defp parse_is_active("0"), do: true
  # Pending = not active
  defp parse_is_active("1"), do: false
  # Default to active
  defp parse_is_active(_), do: true

  defp generate_temp_password(identifier) do
    "temp_" <> String.slice(to_string(identifier), -8..-1//1)
  end
end
