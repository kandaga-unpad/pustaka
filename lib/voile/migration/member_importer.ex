defmodule Voile.Migration.MemberImporter do
  @moduledoc """
  Imports member data from CSV files with optimized streaming and batch processing.

  Expected CSV structure:
  - scripts/csv_data/member/member_*.csv
  """

  import Ecto.Query
  import Voile.Migration.Common

  alias Voile.Repo
  alias Voile.Schema.Accounts.{User, Role, UserRoleAssignment}
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

  def import_all(batch_size \\ 1000, skip_images \\ false) do
    IO.puts("👥 Starting member data import...")

    # Setup default data
    setup_default_data()

    # Ensure upload directory exists
    ensure_upload_dir()

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
        |> Enum.reduce(
          %{
            inserted: 0,
            skipped: 0,
            errors: 0,
            verified_students: 0,
            organizations: 0,
            general_members: 0
          },
          fn {file, index}, acc ->
            IO.puts(
              "\n🔄 Processing member file #{index}/#{length(files)}: #{Path.basename(file)}"
            )

            # Extract node info from filename for member_N.csv files
            node_id = extract_node_from_filename(file)

            file_stats =
              process_member_file_optimized(file, batch_size, node_id, skip_images, cache)

            %{
              inserted: acc.inserted + file_stats.inserted,
              skipped: acc.skipped + file_stats.skipped,
              errors: acc.errors + file_stats.errors,
              verified_students: acc.verified_students + file_stats.verified_students,
              organizations: acc.organizations + file_stats.organizations,
              general_members: acc.general_members + file_stats.general_members
            }
          end
        )

      print_summary("MEMBER IMPORT", %{
        "Total Members Inserted" => stats.inserted,
        "Total Members Skipped" => stats.skipped,
        "Total Errors" => stats.errors,
        "└─ Member (Verified) - 12 digits" => stats.verified_students,
        "└─ Member (Organization) - >12 digits" => stats.organizations,
        "└─ Member (Affirmation) - fallback" => stats.general_members
      })

      stats
    end
  end

  # Initialize cache with frequently accessed data to avoid repeated DB queries
  defp initialize_cache do
    IO.puts("🔄 Initializing member cache...")

    # Cache member role
    member_role = Repo.get_by(Role, name: "viewer")

    # Cache all member types
    member_types =
      Repo.all(MemberType)
      |> Enum.into(%{}, fn mt -> {mt.id, mt} end)

    # Cache specific member types by slug for identifier-based assignment
    verified_student_type = Repo.get_by(MemberType, slug: "member_verified")
    organization_type = Repo.get_by(MemberType, slug: "member_organization")
    general_type = Repo.get_by(MemberType, slug: "member_affirmation")

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

    if verified_student_type do
      IO.puts("  - Verified Student type: ✓ (ID: #{verified_student_type.id})")
    else
      IO.puts("  - Verified Student type: ✗")
    end

    if organization_type do
      IO.puts("  - Organization type: ✓ (ID: #{organization_type.id})")
    else
      IO.puts("  - Organization type: ✗")
    end

    if general_type do
      IO.puts("  - General type: ✓ (ID: #{general_type.id})")
    else
      IO.puts("  - General type: ✗")
    end

    IO.puts("  - Nodes: #{map_size(nodes)}")
    IO.puts("  - Existing emails: #{MapSet.size(existing_emails)}")
    IO.puts("  - Existing usernames: #{MapSet.size(existing_usernames)}")
    IO.puts("  - Existing identifiers: #{MapSet.size(existing_identifiers)}")

    %{
      member_role: member_role,
      member_types: member_types,
      verified_student_type: verified_student_type,
      organization_type: organization_type,
      general_type: general_type,
      nodes: nodes,
      existing_emails: existing_emails,
      existing_usernames: existing_usernames,
      existing_identifiers: existing_identifiers
    }
  end

  # Optimized file processing using streams and batching
  defp process_member_file_optimized(file_path, batch_size, node_id, skip_images, cache) do
    IO.puts("📋 Processing for node: #{get_node_name(node_id)}")

    if skip_images do
      IO.puts("⚠️ Skipping image downloads (--skip-images flag enabled)")
    end

    stats_ref = :ets.new(:member_import_stats, [:set, :public])
    :ets.insert(stats_ref, {:inserted, 0})
    :ets.insert(stats_ref, {:skipped, 0})
    :ets.insert(stats_ref, {:errors, 0})
    :ets.insert(stats_ref, {:verified_students, 0})
    :ets.insert(stats_ref, {:organizations, 0})
    :ets.insert(stats_ref, {:general_members, 0})
    # Store member_role for use in batch processing
    :ets.insert(stats_ref, {:member_role, cache.member_role})

    # Store member type slugs for stats tracking
    if cache.verified_student_type do
      :ets.insert(
        stats_ref,
        {{:member_type_slug, cache.verified_student_type.id}, "member_verified"}
      )
    end

    if cache.organization_type do
      :ets.insert(
        stats_ref,
        {{:member_type_slug, cache.organization_type.id}, "member_organization"}
      )
    end

    if cache.general_type do
      :ets.insert(stats_ref, {{:member_type_slug, cache.general_type.id}, "member_affirmation"})
    end

    try do
      File.stream!(file_path)
      |> CSVParser.parse_stream()
      # Skip header
      |> Stream.drop(1)
      |> Stream.with_index(1)
      |> Stream.map(fn {row, line_num} ->
        try do
          {prepare_member_data(row, node_id, skip_images, cache), line_num}
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
      [{:verified_students, verified_students}] = :ets.lookup(stats_ref, :verified_students)
      [{:organizations, organizations}] = :ets.lookup(stats_ref, :organizations)
      [{:general_members, general_members}] = :ets.lookup(stats_ref, :general_members)

      %{
        inserted: inserted,
        skipped: skipped,
        errors: errors,
        verified_students: verified_students,
        organizations: organizations,
        general_members: general_members
      }
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

    # Get cached member role from stats_ref
    [{:member_role, member_role}] = :ets.lookup(stats_ref, :member_role)

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

          # Pre-count member types before insertion for stats tracking
          {verified_student_count, organization_count, general_count} =
            Enum.reduce(to_insert_users, {0, 0, 0}, fn user, {vs, org, gen} ->
              # Look up the member type in cache
              case :ets.lookup(stats_ref, {:member_type_slug, user.user_type_id}) do
                [{_, "member_verified"}] -> {vs + 1, org, gen}
                [{_, "member_organization"}] -> {vs, org + 1, gen}
                _ -> {vs, org, gen + 1}
              end
            end)

          Repo.transaction(
            fn ->
              # Insert new users
              {count, inserted_users} =
                if to_insert_users != [] do
                  Repo.insert_all(User, to_insert_users,
                    on_conflict: :nothing,
                    returning: [:id],
                    timeout: :infinity
                  )
                else
                  {0, []}
                end

              # Track member type categorization after successful insert
              if count > 0 do
                :ets.update_counter(stats_ref, :verified_students, verified_student_count)
                :ets.update_counter(stats_ref, :organizations, organization_count)
                :ets.update_counter(stats_ref, :general_members, general_count)
              end

              # Create role assignments for newly inserted users with "Member" role
              if count > 0 and member_role do
                now = DateTime.utc_now() |> DateTime.truncate(:second)

                role_assignments =
                  inserted_users
                  |> Enum.map(fn user ->
                    %{
                      user_id: user.id,
                      role_id: member_role.id,
                      scope_type: "global",
                      scope_id: nil,
                      glam_type: nil,
                      assigned_at: now,
                      expires_at: nil,
                      assigned_by_id: nil
                    }
                  end)

                Repo.insert_all(UserRoleAssignment, role_assignments,
                  on_conflict: :nothing,
                  timeout: :infinity
                )
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

  # Keep default password hash for migrated users
  defp remove_password_field(user_attrs) do
    user_attrs
    # Remove any plain text password if present
    |> Map.delete(:password)
    # Keep hashed_password as it contains our default hash
    # Mark as not confirmed since they need to confirm via email
    |> Map.put(:confirmed_at, nil)
  end

  # Determine member type based on identifier digit count
  # 12 digits = verified student
  # >12 digits = organization
  # Otherwise = general
  defp determine_member_type_by_identifier(identifier, cache) when is_binary(identifier) do
    # Count only digits in the identifier
    digit_count =
      identifier
      |> String.graphemes()
      |> Enum.count(&(&1 in ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"]))

    cond do
      digit_count == 12 and cache.verified_student_type ->
        cache.verified_student_type.id

      digit_count > 12 and cache.organization_type ->
        cache.organization_type.id

      cache.general_type ->
        cache.general_type.id

      true ->
        # Fallback to first available member type
        case Map.values(cache.member_types) |> List.first() do
          nil -> nil
          mt -> mt.id
        end
    end
  end

  defp determine_member_type_by_identifier(_identifier, cache) do
    # No valid identifier, use general type
    if cache.general_type do
      cache.general_type.id
    else
      case Map.values(cache.member_types) |> List.first() do
        nil -> nil
        mt -> mt.id
      end
    end
  end

  # Prepare member data using cached data (optimized version)
  defp prepare_member_data(row, node_id, skip_images, cache) when length(row) >= 20 do
    [
      member_id,
      member_name,
      gender,
      birth_date,
      _member_type_id,
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

        # Determine member type based on identifier digit count
        # This overrides the CSV member_type_id with our categorization logic
        user_type_id = determine_member_type_by_identifier(member_id, cache)
        node = get_node_cached(node_id, cache.nodes)

        now = DateTime.utc_now() |> DateTime.truncate(:second)

        # Safely parse datetime values with fallbacks
        parsed_register_date = safe_parse_datetime(register_date)
        parsed_birth_date = safe_parse_date(birth_date)
        parsed_member_since = safe_parse_date(member_since_date)
        parsed_expires_at = safe_parse_date(expire_date)

        # Handle image download
        user_image_path =
          if skip_images do
            nil
          else
            case download_member_image(member_image, node_id) do
              {:ok, path} -> path
            end
          end

        # Create user record data with profile fields included
        user_attrs = %{
          id: Ecto.UUID.generate(),
          username: safe_truncate(username, 255),
          identifier: parse_int(member_id),
          email: safe_truncate(final_email, 255),
          fullname: safe_truncate(clean_name, 255),
          user_type_id: user_type_id,
          user_image: user_image_path,
          node_id: node && node.id,
          # Default password: "changeme123"
          hashed_password:
            "$pbkdf2-sha512$160000$OmHm5yQ2UOQ2oZFJt9JQZhVqJQa2wC9.XqBZQv1.2qHZqJQa2wC9.XqBZQv1.2qHZqJQa2wC9.XqBZQv1.2qHZqJQa2wC9.X",
          # Not confirmed - users need to confirm via email or SSO
          confirmed_at: nil,
          # Profile fields (moved from separate profile table)
          gender: safe_truncate(map_gender(gender), 255),
          birth_date: parsed_birth_date,
          phone_number: safe_truncate(safe_string_trim(member_phone), 255),
          address: combine_addresses(member_address, member_mail_address),
          organization: safe_truncate(safe_string_trim(inst_name), 255),
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

  defp prepare_member_data(_invalid_row, _node_id, _skip_images, _cache) do
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
    ensure_default_member_types()
    ensure_default_nodes()
  end

  defp ensure_default_member_types do
    # Verify required member types exist (from database seeds)
    # Uses: member_verified, member_organization, member_affirmation

    IO.puts("🔄 Checking for required member types...")

    verified = Repo.get_by(MemberType, slug: "member_verified")
    organization = Repo.get_by(MemberType, slug: "member_organization")
    affirmation = Repo.get_by(MemberType, slug: "member_affirmation")

    cond do
      is_nil(verified) ->
        IO.puts("❌ ERROR: 'member_verified' type not found. Please run database seeds.")
        raise "Missing required member type: member_verified"

      is_nil(organization) ->
        IO.puts("❌ ERROR: 'member_organization' type not found. Please run database seeds.")
        raise "Missing required member type: member_organization"

      is_nil(affirmation) ->
        IO.puts("❌ ERROR: 'member_affirmation' type not found. Please run database seeds.")
        raise "Missing required member type: member_affirmation"

      true ->
        IO.puts("✅ Member types ready:")
        IO.puts("  - member_verified: #{verified.name} (12-digit identifiers)")
        IO.puts("  - member_organization: #{organization.name} (>12-digit identifiers)")
        IO.puts("  - member_affirmation: #{affirmation.name} (fallback)")
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

  defp ensure_upload_dir do
    # Ensure the base user_media directory exists
    base_dir = Path.join(["priv", "static", "uploads", "user_media"])
    File.mkdir_p!(base_dir)
    :ok
  end

  defp download_member_image(image_name, _node_id)
       when image_name in [nil, "", "square-image.png", "person.png"],
       do: {:ok, nil}

  defp download_member_image(image_name, node_id) do
    # Clean up the image name
    cleaned_name = String.trim(image_name)

    if cleaned_name == "" do
      {:ok, nil}
    else
      try do
        # Construct the full URL for UNPAD library member images
        base_url =
          "https://lib.unpad.ac.id/lib/minigalnano/createthumb.php?filename=../../images/persons/"

        full_url = base_url <> cleaned_name <> "&width=200"

        # Determine file extension from the image name
        file_extension = Path.extname(cleaned_name) |> String.downcase()
        file_extension = if file_extension == "", do: ".png", else: file_extension

        # Create node-specific directory
        node_dir = Path.join(["priv", "static", "uploads", "user_media", to_string(node_id)])
        File.mkdir_p!(node_dir)

        # Generate filename - keep original filename for better organization
        original_filename = Path.basename(cleaned_name, Path.extname(cleaned_name))
        final_filename = "#{original_filename}#{file_extension}"
        destination = Path.join(node_dir, final_filename)

        # Download the image
        case download_from_http(full_url, destination) do
          {:ok, _content_type} ->
            # Return the relative path that will be stored in the database
            relative_path =
              Path.join(["uploads", "user_media", to_string(node_id), final_filename])

            {:ok, relative_path}

          {:error, reason} ->
            IO.puts("⚠️ Failed to download member image '#{cleaned_name}': #{inspect(reason)}")
            {:ok, nil}
        end
      rescue
        e ->
          IO.puts(
            "⚠️ Exception downloading member image '#{cleaned_name}': #{Exception.message(e)}"
          )

          {:ok, nil}
      end
    end
  end

  # Download image from HTTP URL and return content type
  defp download_from_http(url, destination) do
    # Use Req for HTTP downloads
    case Req.get(url, connect_options: [timeout: 30_000], receive_timeout: 30_000) do
      {:ok, %Req.Response{status: 200, body: body, headers: headers}} ->
        case File.write(destination, body) do
          :ok ->
            content_type = get_content_type_from_headers(headers)
            {:ok, content_type}

          {:error, reason} ->
            {:error, "Failed to write file: #{inspect(reason)}"}
        end

      {:ok, %Req.Response{status: status_code}} ->
        {:error, "HTTP #{status_code}"}

      {:error, reason} ->
        {:error, "HTTP request failed: #{inspect(reason)}"}
    end
  rescue
    e ->
      {:error, "Exception during HTTP download: #{Exception.message(e)}"}
  end

  # Extract content type from response headers
  defp get_content_type_from_headers(headers) do
    headers
    |> Enum.find(fn {key, _value} -> String.downcase(key) == "content-type" end)
    |> case do
      {_key, content_type} when is_binary(content_type) ->
        String.split(content_type, ";") |> hd() |> String.trim()

      _ ->
        "image/png"
    end
  end

  # Safely truncate string to max length (PostgreSQL VARCHAR default is 255)
  defp safe_truncate(nil, _max_length), do: nil
  defp safe_truncate("", _max_length), do: ""

  defp safe_truncate(value, max_length) when is_binary(value) do
    trimmed = String.trim(value)

    if String.length(trimmed) > max_length do
      truncated = String.slice(trimmed, 0, max_length)
      IO.puts("⚠️ Truncated value from #{String.length(trimmed)} to #{max_length} chars")
      truncated
    else
      trimmed
    end
  end

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
