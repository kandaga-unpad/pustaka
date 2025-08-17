Mix.Task.run("app.start")

NimbleCSV.define(
  CSVParser,
  separator: ",",
  escape: "\"",
  escape_pattern: ~r/\\./
)

import Ecto.Query
import Voile.Utils.ItemHelper
alias Ecto.UUID
alias Voile.Repo
alias Voile.Schema.Catalog.Collection
alias Voile.Schema.Catalog.Item

# Helpers
defmodule ItemImportHelpers do
  def parse_int(val) when val in [nil, ""], do: nil
  def parse_int(val), do: String.to_integer(val)

  def parse_date(val) when val in [nil, "", "0000-00-00 00:00:00"] do
    NaiveDateTime.utc_now()
  end

  def parse_date(val) do
    [date, time] = String.split(val, " ")
    NaiveDateTime.from_iso8601!(date <> "T" <> time)
  end

  def build_biblio_map do
    from(c in Collection, select: {c.old_biblio_id, c.id})
    |> Repo.all()
    |> Enum.into(%{}, fn {old_biblio_id, id} ->
      {parse_int(to_string(old_biblio_id)), id}
    end)
  end
end

defmodule ItemCSVProcessor do
  import ItemImportHelpers

  def get_csv_files do
    case System.argv() do
      [] ->
        # No arguments - look for item_*.csv pattern in scripts/ directory
        pattern = "scripts/item*.csv"
        files = Path.wildcard(pattern) |> Enum.sort()

        if Enum.empty?(files) do
          IO.puts("📁 No item*.csv files found, using default: scripts/item.csv")
          ["scripts/item.csv"]
        else
          IO.puts("📁 Found #{length(files)} CSV files:")
          Enum.each(files, &IO.puts("  - #{&1}"))
          files
        end

      [single_file] ->
        # Single file provided
        if File.exists?(single_file) do
          IO.puts("📁 Using single CSV file: #{single_file}")
          [single_file]
        else
          IO.puts("❌ File not found: #{single_file}")
          exit(:file_not_found)
        end

      ["--pattern", pattern] ->
        # Pattern provided (e.g. --pattern "data/item_*.csv")
        files = Path.wildcard(pattern) |> Enum.sort()

        if Enum.empty?(files) do
          IO.puts("❌ No files found matching pattern: #{pattern}")
          exit(:no_files_found)
        else
          IO.puts("📁 Found #{length(files)} files matching pattern '#{pattern}':")
          Enum.each(files, &IO.puts("  - #{&1}"))
          files
        end

      ["--dir", directory] ->
        # Directory provided - find all CSV files
        pattern = Path.join(directory, "item*.csv")
        files = Path.wildcard(pattern) |> Enum.sort()

        if Enum.empty?(files) do
          IO.puts("❌ No item CSV files found in directory: #{directory}")
          exit(:no_files_found)
        else
          IO.puts("📁 Found #{length(files)} CSV files in '#{directory}':")
          Enum.each(files, &IO.puts("  - #{&1}"))
          files
        end

      files when is_list(files) ->
        # Multiple files provided
        existing_files = Enum.filter(files, &File.exists?/1)
        missing_files = files -- existing_files

        if not Enum.empty?(missing_files) do
          IO.puts("⚠️ Warning: Some files not found:")
          Enum.each(missing_files, &IO.puts("  - #{&1}"))
        end

        if Enum.empty?(existing_files) do
          IO.puts("❌ No valid files found")
          exit(:no_valid_files)
        else
          IO.puts("📁 Processing #{length(existing_files)} files:")
          Enum.each(existing_files, &IO.puts("  - #{&1}"))
          existing_files
        end
    end
  end

  def process_csv_files(csv_files, biblio_map) do
    total_files = length(csv_files)

    # Initialize global agents for tracking across all files
    {:ok, global_biblio_index_agent} = Agent.start_link(fn -> %{} end)
    {:ok, global_biblio_time_agent} = Agent.start_link(fn -> %{} end)

    # Track global statistics
    global_stats = %{
      total_inserted: 0,
      total_skipped: 0,
      skipped_ids: []
    }

    final_stats =
      csv_files
      |> Enum.with_index(1)
      |> Enum.reduce(global_stats, fn {csv_path, file_index}, acc_stats ->
        IO.puts("\n🔄 Processing file #{file_index}/#{total_files}: #{csv_path}")
        file_size = File.stat!(csv_path).size
        IO.puts("📊 File size: #{Float.round(file_size / 1024 / 1024, 2)} MB")

        start_time = System.monotonic_time(:millisecond)

        # Process single file
        file_stats =
          process_single_file(
            csv_path,
            biblio_map,
            global_biblio_index_agent,
            global_biblio_time_agent
          )

        end_time = System.monotonic_time(:millisecond)
        duration = end_time - start_time

        IO.puts("✅ Completed #{csv_path} in #{duration}ms")
        IO.puts("📦 File stats - Inserted: #{file_stats.inserted}, Skipped: #{file_stats.skipped}")

        # Accumulate stats
        %{
          total_inserted: acc_stats.total_inserted + file_stats.inserted,
          total_skipped: acc_stats.total_skipped + file_stats.skipped,
          skipped_ids: acc_stats.skipped_ids ++ file_stats.skipped_ids
        }
      end)

    # Clean up agents
    Agent.stop(global_biblio_index_agent)
    Agent.stop(global_biblio_time_agent)

    # Print final summary
    print_final_summary(final_stats)
  end

  defp process_single_file(csv_path, biblio_map, biblio_index_agent, biblio_time_agent) do
    stream = create_item_stream(csv_path, biblio_map, biblio_index_agent, biblio_time_agent)

    # Process with batching and progress tracking
    {total_inserted, total_skipped, skipped_ids, pending_batch} =
      stream
      # Process in larger chunks for progress
      |> Stream.chunk_every(1000)
      |> Enum.with_index(1)
      |> Enum.reduce({0, 0, [], []}, fn {chunk, chunk_index} ->
        # Process chunk
        result = process_chunk(chunk)

        # Progress indicator
        if rem(chunk_index, 5) == 0 do
          IO.write(".")
        end

        result
      end)

    # Insert remaining batch
    final_inserted =
      if pending_batch != [] do
        Repo.insert_all(Item.__schema__(:source), Enum.reverse(pending_batch),
          on_conflict: :nothing
        )

        total_inserted + length(pending_batch)
      else
        total_inserted
      end

    # New line after progress dots
    IO.puts()

    %{
      inserted: final_inserted,
      skipped: total_skipped,
      skipped_ids: skipped_ids
    }
  end

  defp create_item_stream(csv_path, biblio_map, biblio_index_agent, biblio_time_agent) do
    File.stream!(csv_path)
    |> CSVParser.parse_stream()
    |> Stream.map(fn row ->
      process_row(row, biblio_map, biblio_index_agent, biblio_time_agent)
    end)
  end

  defp process_row(
         [
           _item_id,
           biblio_id,
           _call_number,
           _coll_type_id,
           item_code,
           inventory_code,
           _received_date,
           _supplier_id,
           _order_no,
           _location_id,
           _order_date,
           _item_status_id,
           site,
           _source,
           _invoice,
           _price,
           _price_currency,
           _invoice_date,
           input_date,
           last_update,
           _uid
         ],
         biblio_map,
         biblio_index_agent,
         biblio_time_agent
       ) do
    raw_uuid = UUID.generate()
    {:ok, id} = UUID.dump(raw_uuid)

    case Map.fetch(biblio_map, parse_int(biblio_id)) do
      {:ok, coll_id} ->
        {:ok, collection_id} = UUID.dump(coll_id)
        biblio_id_int = parse_int(biblio_id)

        # Get and increment index for this biblio_id
        index =
          Agent.get_and_update(biblio_index_agent, fn state ->
            current_index = Map.get(state, biblio_id_int, 0) + 1
            {current_index, Map.put(state, biblio_id_int, current_index)}
          end)

        # Get or create time_identifier for this biblio_id
        time_identifier =
          Agent.get_and_update(biblio_time_agent, fn state ->
            case Map.get(state, biblio_id_int) do
              nil ->
                new_time_identifier = DateTime.utc_now() |> DateTime.to_unix(:millisecond)
                {new_time_identifier, Map.put(state, biblio_id_int, new_time_identifier)}

              existing_time_identifier ->
                {existing_time_identifier, state}
            end
          end)

        {:ok,
         %{
           id: id,
           collection_id: collection_id,
           unit_id: 20,
           item_code:
             if(item_code == "",
               do: generate_item_code("Kandaga", "Book", collection_id, time_identifier, index),
               else: item_code
             ),
           inventory_code: if(inventory_code == "", do: nil, else: inventory_code),
           location: if(site == "", do: nil, else: site),
           status: "active",
           condition: "good",
           availability: "available",
           inserted_at: parse_date(input_date),
           updated_at: parse_date(last_update)
         }}

      :error ->
        {:error, {:missing_biblio_id, biblio_id}}
    end
  end

  defp process_chunk(chunk) do
    Enum.reduce(chunk, {0, 0, [], []}, fn
      {:ok, item}, {inserted, skipped, skipped_ids, batch} when length(batch) < 499 ->
        {inserted, skipped, skipped_ids, [item | batch]}

      {:ok, item}, {inserted, skipped, skipped_ids, batch} ->
        Repo.insert_all(Item.__schema__(:source), Enum.reverse([item | batch]),
          on_conflict: :nothing
        )

        {inserted + length(batch) + 1, skipped, skipped_ids, []}

      {:error, {:missing_biblio_id, biblio_id}}, {inserted, skipped, skipped_ids, batch} ->
        {inserted, skipped + 1, [biblio_id | skipped_ids], batch}
    end)
  end

  defp print_final_summary(stats) do
    IO.puts("\n" <> String.duplicate("=", 50))
    IO.puts("✅ All done migrating items across all files.")
    IO.puts("📦 Total inserted: #{stats.total_inserted}")
    IO.puts("❌ Total skipped: #{stats.total_skipped}")

    if stats.skipped_ids != [] do
      unique_skipped = stats.skipped_ids |> Enum.uniq()
      IO.puts("⚠️ Unique skipped biblio_ids (#{length(unique_skipped)}):")

      unique_skipped
      # Show first 20 to avoid overwhelming output
      |> Enum.take(20)
      |> Enum.each(&IO.puts("- #{&1}"))

      if length(unique_skipped) > 20 do
        IO.puts("... and #{length(unique_skipped) - 20} more")
      end
    end

    IO.puts(String.duplicate("=", 50))
  end
end

# Main execution
IO.puts("🔗 Building biblio_id → collection_id map...")
biblio_map = ItemImportHelpers.build_biblio_map()
IO.puts("🔗 Built biblio_id → collection_id map (#{map_size(biblio_map)} entries)")

csv_files = ItemCSVProcessor.get_csv_files()
ItemCSVProcessor.process_csv_files(csv_files, biblio_map)
