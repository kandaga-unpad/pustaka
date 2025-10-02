defmodule Voile.Migration.MemberImporter do
  @moduledoc """
  Imports member data from CSV files with optimized streaming and batch processing.

  Expected CSV structure:
  - scripts/csv_data/member/member_*.csv
  """

  import Ecto.Query
  import Voile.Migration.Common

  alias Voile.Repo
  alias Voile.Schema.Accounts.{User, UserRole}
  alias Voile.Schema.Master.MemberType
  alias Voile.Schema.System.Node

  # Cache for frequently accessed data
  @type cache :: %{
          member_role: struct() | nil,
          member_types: map(),
          nodes: map(),
          existing_emails: MapSet.t(),
          existing_usernames: MapSet.t(),
          existing_identifiers: MapSet.t()
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

    # Cache existing identifiers
    existing_identifiers =
      from(u in User, select: u.identifier, where: not is_nil(u.identifier))
      |> Repo.all()
      |> MapSet.new()

    IO.puts("✅ Cache initialized:")
    IO.puts("  - Member role: #{if member_role, do: "✓", else: "✗"}")
    IO.puts("  - Member types: #{map_size(member_types)}")
    IO.puts("  - Nodes: #{map_size(nodes)}")
    IO.puts("  - Existing emails: #{MapSet.size(existing_emails)}")
    IO.puts("  - Existing usernames: #{MapSet.size(existing_usernames)}")
    IO.puts("  - Existing identifiers: #{MapSet.size(existing_identifiers)}")

    %{
      member_role: member_role,
      member_types: member_types,
      nodes: nodes,
      existing_emails: existing_emails,
      existing_usernames: existing_usernames,
      existing_identifiers: existing_identifiers
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
        try do
          {prepare_member_data(row, node_id, cache), line_num}
        rescue
          e ->
            IO.puts("\n⚠️ Error processing line #{line_num}: #{Exception.message(e)}")
            # Show first 5 columns for debugging
            IO.puts("   Row data: #{inspect(Enum.take(row, 5))}...")
            {{:error, "Line #{line_num}: #{Exception.message(e)}"}, line_num}
        end
      end)
      |> Stream.filter(fn {{status, _}, _line_num} -> status == :ok end)
      |> Stream.map(fn {{:ok, user_data}, line_num} ->
        {user_data, line_num}
      end)
      |> Stream.chunk_every(batch_size)
      # Process chunks immediately without delay
      |> Task.async_stream(
        fn batch ->
          process_member_batch(batch, stats_ref)
        end,
        max_concurrency: 1,
        timeout: :infinity
      )
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

  # Process a batch of members with single transaction for optimal connection usage
  defp process_member_batch(batch, stats_ref) do
    {users_data, _line_nums} =
      batch
      |> Enum.reduce({[], []}, fn {user_data, line_num}, {users, lines} ->
        {[user_data | users], [line_num | lines]}
      end)

    # Use single transaction to minimize connection idle time
    users_inserted =
      if length(users_data) > 0 do
        try do
          # Restore original input order
          users_in_order = Enum.reverse(users_data)

          # Clean users (remove plain password) before any DB work
          users_clean = Enum.map(users_in_order, &remove_password_field/1)

          # Collect batch emails/identifiers to detect existing users
          emails = users_clean |> Enum.map(& &1.email) |> Enum.reject(&is_nil/1) |> Enum.uniq()

          idents =
            users_clean |> Enum.map(& &1.identifier) |> Enum.reject(&is_nil/1) |> Enum.uniq()

          existing_users =
            cond do
              emails != [] and idents != [] ->
                from(u in User,
                  where: u.email in ^emails or u.identifier in ^idents,
                  select: {u.email, u.identifier, u.id}
                )
                |> Repo.all()

              emails != [] ->
                from(u in User,
                  where: u.email in ^emails,
                  select: {u.email, u.identifier, u.id}
                )
                |> Repo.all()

              idents != [] ->
                from(u in User,
                  where: u.identifier in ^idents,
                  select: {u.email, u.identifier, u.id}
                )
                |> Repo.all()

              true ->
                []
            end

          existing_by_email =
            existing_users
            |> Enum.reduce(%{}, fn {email, _ident, id}, acc ->
              if email, do: Map.put(acc, email, id), else: acc
            end)

          existing_by_ident =
            existing_users
            |> Enum.reduce(%{}, fn {_email, ident, id}, acc ->
              if ident, do: Map.put(acc, ident, id), else: acc
            end)

          # Filter out users that already exist
          to_insert_users =
            users_clean
            |> Enum.reject(fn u ->
              (u.email && Map.has_key?(existing_by_email, u.email)) ||
                (u.identifier && Map.has_key?(existing_by_ident, u.identifier))
            end)

          Repo.transaction(
            fn ->
              # Insert new users
              count =
                if to_insert_users != [] do
                  {count, _inserted_rows} =
                    Repo.insert_all(User, to_insert_users,
                      on_conflict: :nothing,
                      returning: [:id],
                      timeout: :infinity
                    )

                  count
                else
                  0
                end

              count
            end,
            timeout: :infinity
          )
          |> case do
            {:ok, count} ->
              :ets.update_counter(stats_ref, :inserted, count)
              count

            {:error, reason} ->
              IO.puts("\n⚠️ Transaction error: #{inspect(reason)}")
              :ets.update_counter(stats_ref, :errors, length(users_data))
              0
          end
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

  # Keep default password hash but mark as unconfirmed for onboarding
  defp remove_password_field(user_attrs) do
    user_attrs
    # Remove any plain text password if present
    |> Map.delete(:password)
    # Keep hashed_password as it contains our default hash
    # Mark as not confirmed since they need to complete onboarding
    |> Map.put(:confirmed_at, nil)
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
      _postal_code,
      inst_name,
      _is_new,
      member_image,
      _pin,
      member_phone,
      _member_fax,
      member_since_date,
      register_date,
      expire_date,
      _member_notes,
      _is_pending | _rest
    ] = row

    # Basic validation
    clean_name = safe_string_trim(member_name)
    clean_email = safe_string_trim(member_email)

    cond do
      is_nil(clean_name) or clean_name == "" ->
        {:skip, "Missing member name"}

      is_nil(clean_email) or clean_email == "" ->
        {:skip, "Missing member email"}

      # Check for existing email in database - SKIP if found
      MapSet.member?(cache.existing_emails, clean_email) ->
        {:skip, "User with email #{clean_email} already exists"}

      # Check for existing identifier - SKIP if found
      parse_int(member_id) != nil and
          MapSet.member?(cache.existing_identifiers, parse_int(member_id)) ->
        {:skip, "User with identifier #{member_id} already exists"}

      true ->
        # Generate username from name (no need for uniqueness check since we skip duplicates)
        username = generate_simple_username(clean_name, member_id)
        # Use original email (no need for uniqueness since we skip duplicates)
        final_email = clean_email

        member_type = get_member_type_cached(member_type_id, cache.member_types)
        node = get_node_cached(node_id, cache.nodes)

        now = DateTime.utc_now() |> DateTime.truncate(:second)

        # Safely parse datetime values with fallbacks
        parsed_register_date = safe_parse_datetime(register_date)
        parsed_birth_date = safe_parse_date(birth_date)
        parsed_member_since = safe_parse_date(member_since_date)
        parsed_expires_at = safe_parse_date(expire_date)

        # Create user record data with profile fields included
        user_attrs = %{
          username: username,
          identifier: parse_int(member_id),
          email: final_email,
          fullname: clean_name,
          user_role_id: cache.member_role && cache.member_role.id,
          user_type_id: member_type && member_type.id,
          user_image: clean_image_name(member_image),
          node_id: node && node.id,
          # Default password: "changeme123"
          hashed_password:
            "$pbkdf2-sha512$160000$OmHm5yQ4w.ZGpn7fvUcGzg$uBPzZQ2UOQ2oZFJt9JQZhVqJQa2wC9.XqBZQv1.2qHZqJQa2wC9.XqBZQv1.2qHZqJQa2wC9.XqBZQv1.2qHZqJQa2wC9.X",
          # Will be set during onboarding
          confirmed_at: nil,
          # Profile fields (moved from separate profile table)
          gender: map_gender(gender),
          birth_date: parsed_birth_date,
          phone_number: safe_string_trim(member_phone),
          address: combine_addresses(member_address, member_mail_address),
          organization: safe_string_trim(inst_name),
          registration_date: parsed_member_since,
          expiry_date: parsed_expires_at,
          inserted_at: parsed_register_date || now,
          updated_at: now
        }

        {:ok, user_attrs}
    end
  rescue
    e ->
      IO.puts("\n🔍 Data preparation error for member: #{inspect(Enum.take(row, 3))}")
      IO.puts("   Error: #{Exception.message(e)}")
      IO.puts("   Stack trace: #{Exception.format_stacktrace(__STACKTRACE__)}")
      {:error, "Exception: #{Exception.message(e)}"}
  end

  defp prepare_member_data(_invalid_row, _node_id, _cache) do
    {:skip, "Invalid row format - insufficient columns"}
  end

  # Cached helper functions for better performance
  # Generate simple username without uniqueness checking (duplicates are skipped)
  defp generate_simple_username(clean_name, member_id) do
    generate_username_base(clean_name, member_id)
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
    # ensure_member_role()
    ensure_default_member_types()
    ensure_default_nodes()
  end

  # defp ensure_member_role do
  #   unless Repo.get_by(UserRole, name: "Member") do
  #     %UserRole{}
  #     |> UserRole.changeset(%{
  #       name: "Member",
  #       description: "Library member role",
  #       permissions: %{
  #         "catalog" => %{"read" => true},
  #         "profile" => %{"read" => true, "update" => true}
  #       }
  #     })
  #     |> Repo.insert!()
  #   end
  # end

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

  # Safe parsing functions with error handling and logging
  defp safe_parse_datetime(val) do
    try do
      parse_datetime(val)
    rescue
      e ->
        IO.puts("⚠️ DateTime parse error for value '#{inspect(val)}': #{Exception.message(e)}")
        nil
    end
  end

  defp safe_parse_date(val) do
    try do
      parse_date(val)
    rescue
      e ->
        IO.puts("⚠️ Date parse error for value '#{inspect(val)}': #{Exception.message(e)}")
        nil
    end
  end
end
