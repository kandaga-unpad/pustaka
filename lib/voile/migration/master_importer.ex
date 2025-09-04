defmodule Voile.Migration.MasterImporter do
  @moduledoc """
  Imports master data including authors/creators and publishers from CSV files with optimized streaming and batch processing.

  Expected CSV structure:
  - scripts/csv_data/mst/mst_author_*.csv
  - scripts/csv_data/mst/mst_publisher_*.csv
  """

  import Ecto.Query
  import Voile.Migration.Common

  alias Voile.Repo
  alias Voile.Schema.Master.{Creator, Publishers}

  # Cache for frequently accessed data
  @type cache :: %{
          existing_creator_names: MapSet.t(),
          existing_publisher_names: MapSet.t()
        }

  def import_all(batch_size \\ 1000) do
    IO.puts("📋 Starting master data import...")

    # Initialize cache with existing data
    cache = initialize_cache()

    # Import creators (authors) with optimized processing
    creator_stats = import_creators_optimized(batch_size, cache)

    # Import publishers with optimized processing
    publisher_stats = import_publishers_optimized(batch_size, cache)

    total_stats = %{
      "Total Creators Inserted" => creator_stats.inserted,
      "Total Creators Skipped" => creator_stats.skipped,
      "Total Publishers Inserted" => publisher_stats.inserted,
      "Total Publishers Skipped" => publisher_stats.skipped
    }

    print_summary("MASTER DATA IMPORT", total_stats)

    {creator_stats, publisher_stats}
  end

  # Initialize cache with frequently accessed data
  defp initialize_cache do
    IO.puts("� Initializing master data cache...")

    # Cache existing creator names for deduplication
    existing_creator_names = get_existing_creator_names()

    # Cache existing publisher names for deduplication
    existing_publisher_names = get_existing_publisher_names()

    IO.puts("✅ Cache initialized:")
    IO.puts("  - Existing creators: #{MapSet.size(existing_creator_names)}")
    IO.puts("  - Existing publishers: #{MapSet.size(existing_publisher_names)}")

    %{
      existing_creator_names: existing_creator_names,
      existing_publisher_names: existing_publisher_names
    }
  end

  defp import_creators_optimized(batch_size, cache) do
    IO.puts("👤 Importing creators...")

    # Get all creator CSV files
    files = get_specific_files("mst", "mst_author*.csv")

    if Enum.empty?(files) do
      IO.puts("⚠️ No creator files found")
      %{inserted: 0, skipped: 0}
    else
      stats =
        files
        |> Stream.with_index(1)
        |> Enum.reduce(
          %{inserted: 0, skipped: 0, seen_names: cache.existing_creator_names},
          fn {file, index}, acc ->
            IO.puts("🔄 Processing creator file #{index}/#{length(files)}: #{Path.basename(file)}")

            file_stats = process_creator_file_optimized(file, batch_size, acc.seen_names)

            %{
              inserted: acc.inserted + file_stats.inserted,
              skipped: acc.skipped + file_stats.skipped,
              seen_names: MapSet.union(acc.seen_names, file_stats.seen_names)
            }
          end
        )

      IO.puts("✅ Creators import completed:")
      IO.puts("  - Inserted: #{stats.inserted}")
      IO.puts("  - Skipped: #{stats.skipped}")

      %{inserted: stats.inserted, skipped: stats.skipped}
    end
  end

  defp import_publishers_optimized(batch_size, cache) do
    IO.puts("🏢 Importing publishers...")

    # Get all publisher CSV files
    files = get_specific_files("mst", "mst_publisher*.csv")

    if Enum.empty?(files) do
      IO.puts("⚠️ No publisher files found")
      %{inserted: 0, skipped: 0}
    else
      stats =
        files
        |> Stream.with_index(1)
        |> Enum.reduce(
          %{inserted: 0, skipped: 0, seen_names: cache.existing_publisher_names},
          fn {file, index}, acc ->
            IO.puts(
              "🔄 Processing publisher file #{index}/#{length(files)}: #{Path.basename(file)}"
            )

            file_stats = process_publisher_file_optimized(file, batch_size, acc.seen_names)

            %{
              inserted: acc.inserted + file_stats.inserted,
              skipped: acc.skipped + file_stats.skipped,
              seen_names: MapSet.union(acc.seen_names, file_stats.seen_names)
            }
          end
        )

      IO.puts("✅ Publishers import completed:")
      IO.puts("  - Inserted: #{stats.inserted}")
      IO.puts("  - Skipped: #{stats.skipped}")

      %{inserted: stats.inserted, skipped: stats.skipped}
    end
  end

  # Optimized creator file processing using streams and batching
  defp process_creator_file_optimized(file_path, batch_size, existing_names) do
    IO.puts("📂 Processing creator file: #{Path.basename(file_path)}")

    now = DateTime.utc_now() |> DateTime.truncate(:second)

    stats_ref = :ets.new(:creator_import_stats, [:set, :public])
    :ets.insert(stats_ref, {:inserted, 0})
    :ets.insert(stats_ref, {:skipped, 0})
    :ets.insert(stats_ref, {:seen_names, existing_names})

    try do
      File.stream!(file_path)
      |> CSVParser.parse_stream()
      # Skip header
      |> Stream.drop(1)
      |> Stream.with_index(1)
      |> Stream.map(fn {row, line_num} ->
        {prepare_creator_data(row, now, stats_ref), line_num}
      end)
      |> Stream.filter(fn {{status, _}, _line_num} -> status == :ok end)
      |> Stream.map(fn {{:ok, creator_data}, line_num} -> {creator_data, line_num} end)
      |> Stream.chunk_every(batch_size)
      |> Stream.each(fn batch ->
        process_creator_batch(batch, stats_ref)
      end)
      |> Stream.run()

      # Return final stats
      [{:inserted, inserted}] = :ets.lookup(stats_ref, :inserted)
      [{:skipped, skipped}] = :ets.lookup(stats_ref, :skipped)
      [{:seen_names, seen_names}] = :ets.lookup(stats_ref, :seen_names)

      %{inserted: inserted, skipped: skipped, seen_names: seen_names}
    after
      :ets.delete(stats_ref)
    end
  end

  # Optimized publisher file processing using streams and batching
  defp process_publisher_file_optimized(file_path, batch_size, existing_names) do
    IO.puts("📂 Processing publisher file: #{Path.basename(file_path)}")

    now = DateTime.utc_now() |> DateTime.truncate(:second)

    stats_ref = :ets.new(:publisher_import_stats, [:set, :public])
    :ets.insert(stats_ref, {:inserted, 0})
    :ets.insert(stats_ref, {:skipped, 0})
    :ets.insert(stats_ref, {:seen_names, existing_names})

    try do
      File.stream!(file_path)
      |> CSVParser.parse_stream()
      # Skip header
      |> Stream.drop(1)
      |> Stream.with_index(1)
      |> Stream.map(fn {row, line_num} ->
        {prepare_publisher_data(row, now, stats_ref), line_num}
      end)
      |> Stream.filter(fn {{status, _}, _line_num} -> status == :ok end)
      |> Stream.map(fn {{:ok, publisher_data}, line_num} -> {publisher_data, line_num} end)
      |> Stream.chunk_every(batch_size)
      |> Stream.each(fn batch ->
        process_publisher_batch(batch, stats_ref)
      end)
      |> Stream.run()

      # Return final stats
      [{:inserted, inserted}] = :ets.lookup(stats_ref, :inserted)
      [{:skipped, skipped}] = :ets.lookup(stats_ref, :skipped)
      [{:seen_names, seen_names}] = :ets.lookup(stats_ref, :seen_names)

      %{inserted: inserted, skipped: skipped, seen_names: seen_names}
    after
      :ets.delete(stats_ref)
    end
  end

  # Process a batch of creators with single transaction
  defp process_creator_batch(batch, stats_ref) do
    creators_data =
      batch
      |> Enum.map(fn {creator_data, _line_num} -> creator_data end)

    if length(creators_data) > 0 do
      try do
        {count, _} =
          Repo.insert_all(Creator, creators_data, on_conflict: :nothing, returning: false)

        :ets.update_counter(stats_ref, :inserted, count)

        # Progress indicator
        if rem(count, 100) == 0 and count > 0 do
          IO.write(".")
        end
      rescue
        e ->
          IO.puts("\n⚠️ Creator batch insert error: #{inspect(e)}")
          :ets.update_counter(stats_ref, :skipped, length(creators_data))
      end
    end
  end

  # Process a batch of publishers with single transaction
  defp process_publisher_batch(batch, stats_ref) do
    publishers_data =
      batch
      |> Enum.map(fn {publisher_data, _line_num} -> publisher_data end)

    if length(publishers_data) > 0 do
      try do
        {count, _} =
          Repo.insert_all(Publishers, publishers_data, on_conflict: :nothing, returning: false)

        :ets.update_counter(stats_ref, :inserted, count)

        # Progress indicator
        if rem(count, 100) == 0 and count > 0 do
          IO.write(".")
        end
      rescue
        e ->
          IO.puts("\n⚠️ Publisher batch insert error: #{inspect(e)}")
          :ets.update_counter(stats_ref, :skipped, length(publishers_data))
      end
    end
  end

  # Prepare creator data using cached seen names
  defp prepare_creator_data(
         [_author_id, author_name, _author_year, authority_type | _rest],
         now,
         stats_ref
       ) do
    name = safe_string_trim(author_name)

    if name && name != "" do
      key = String.downcase(name)
      [{:seen_names, seen_names}] = :ets.lookup(stats_ref, :seen_names)

      if MapSet.member?(seen_names, key) do
        :ets.update_counter(stats_ref, :skipped, 1)
        {:skip, "duplicate name"}
      else
        # Update seen names
        updated_seen = MapSet.put(seen_names, key)
        :ets.insert(stats_ref, {:seen_names, updated_seen})

        creator_type = map_authority_to_type(authority_type)

        creator_data = %{
          creator_name: name,
          type: creator_type,
          creator_contact: nil,
          affiliation: nil,
          inserted_at: now,
          updated_at: now
        }

        {:ok, creator_data}
      end
    else
      :ets.update_counter(stats_ref, :skipped, 1)
      {:skip, "empty name"}
    end
  end

  defp prepare_creator_data(_invalid_row, _now, stats_ref) do
    :ets.update_counter(stats_ref, :skipped, 1)
    {:skip, "invalid row format"}
  end

  # Prepare publisher data using cached seen names
  defp prepare_publisher_data([_publisher_id, publisher_name | _rest], now, stats_ref) do
    name = safe_string_trim(publisher_name)

    if name && name != "" do
      key = String.downcase(name)
      [{:seen_names, seen_names}] = :ets.lookup(stats_ref, :seen_names)

      if MapSet.member?(seen_names, key) do
        :ets.update_counter(stats_ref, :skipped, 1)
        {:skip, "duplicate name"}
      else
        # Update seen names
        updated_seen = MapSet.put(seen_names, key)
        :ets.insert(stats_ref, {:seen_names, updated_seen})

        publisher_data = %{
          name: name,
          address: "",
          city: "",
          contact: "",
          inserted_at: now,
          updated_at: now
        }

        {:ok, publisher_data}
      end
    else
      :ets.update_counter(stats_ref, :skipped, 1)
      {:skip, "empty name"}
    end
  end

  defp prepare_publisher_data(_invalid_row, _now, stats_ref) do
    :ets.update_counter(stats_ref, :skipped, 1)
    {:skip, "invalid row format"}
  end

  defp get_existing_creator_names do
    from(c in Creator, select: c.creator_name)
    |> Repo.all()
    |> Enum.reject(&is_nil/1)
    |> Enum.map(&String.downcase/1)
    |> MapSet.new()
  end

  defp get_existing_publisher_names do
    from(p in Publishers, select: p.name)
    |> Repo.all()
    |> Enum.reject(&is_nil/1)
    |> Enum.map(&String.downcase/1)
    |> MapSet.new()
  end

  defp map_authority_to_type(type) when is_binary(type) do
    case String.downcase(String.trim(type)) do
      "p" -> "Person"
      "o" -> "Organization"
      "g" -> "Group"
      "c" -> "Conference"
      "e" -> "Event"
      "i" -> "Institution"
      "pr" -> "Project"
      _ -> "Person"
    end
  end

  defp map_authority_to_type(_), do: "Person"
end
