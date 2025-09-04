defmodule Voile.Migration.ItemImporter do
  @moduledoc """
  Imports item data from CSV files with optimized streaming and batch processing.

  Expected CSV structure:
  - scripts/csv_data/items/item_*.csv
  """

  import Ecto.Query
  import Voile.Migration.Common

  alias Voile.Repo
  alias Voile.Schema.Catalog.{Collection, Item}

  # Cache for frequently accessed data
  @type cache :: %{
          biblio_map: map()
        }

  def import_all(batch_size \\ 1000) do
    IO.puts("📦 Starting item data import...")

    # Initialize cache with biblio mapping and tracking data
    cache = initialize_cache()
    IO.puts("🔗 Built biblio_id → collection_id map (#{map_size(cache.biblio_map)} entries)")

    # Get item files
    files = get_csv_files("items")

    if Enum.empty?(files) do
      IO.puts("⚠️ No item files found")
      %{inserted: 0, skipped: 0, skipped_biblio_ids: []}
    else
      stats =
        files
        |> Stream.with_index(1)
        |> Enum.reduce(%{inserted: 0, skipped: 0, skipped_biblio_ids: []}, fn {file, index},
                                                                              acc ->
          IO.puts("\n🔄 Processing item file #{index}/#{length(files)}: #{Path.basename(file)}")

          file_stats = process_item_file_optimized(file, batch_size, cache)

          %{
            inserted: acc.inserted + file_stats.inserted,
            skipped: acc.skipped + file_stats.skipped,
            skipped_biblio_ids: acc.skipped_biblio_ids ++ file_stats.skipped_biblio_ids
          }
        end)

      print_summary("ITEM IMPORT", %{
        "Total Items Inserted" => stats.inserted,
        "Total Items Skipped" => stats.skipped,
        "Unique Skipped Biblio IDs" => length(Enum.uniq(stats.skipped_biblio_ids))
      })

      if length(stats.skipped_biblio_ids) > 0 do
        unique_skipped = Enum.uniq(stats.skipped_biblio_ids)
        IO.puts("\nSample skipped biblio_ids:")
        unique_skipped |> Enum.take(20) |> Enum.each(&IO.puts("  - #{&1}"))

        if length(unique_skipped) > 20 do
          IO.puts("  ... and #{length(unique_skipped) - 20} more")
        end
      end

      stats
    end
  end

  # Initialize cache with frequently accessed data
  defp initialize_cache do
    IO.puts("🔄 Initializing item cache...")

    # Build biblio_id to collection_id mapping
    biblio_map = build_biblio_map()

    IO.puts("✅ Cache initialized:")
    IO.puts("  - Biblio mappings: #{map_size(biblio_map)}")

    %{
      biblio_map: biblio_map
    }
  end

  # Optimized file processing using streams and batching
  defp process_item_file_optimized(file_path, batch_size, cache) do
    file_size = File.stat!(file_path).size
    IO.puts("📊 File size: #{Float.round(file_size / 1024 / 1024, 2)} MB")

    start_time = System.monotonic_time(:millisecond)

    stats_ref = :ets.new(:item_import_stats, [:set, :public])
    :ets.insert(stats_ref, {:inserted, 0})
    :ets.insert(stats_ref, {:skipped, 0})
    :ets.insert(stats_ref, {:skipped_biblio_ids, []})

    # Create state tracking ETS table for biblio indices and times
    state_ref = :ets.new(:item_state, [:set, :public])

    try do
      File.stream!(file_path)
      |> CSVParser.parse_stream()
      |> Stream.with_index(1)
      |> Stream.map(fn {row, line_num} ->
        {prepare_item_data(row, cache.biblio_map, state_ref), line_num}
      end)
      |> Stream.filter(fn {{status, _}, _line_num} -> status in [:ok, :error] end)
      |> Stream.chunk_every(batch_size)
      |> Stream.each(fn batch ->
        process_item_batch(batch, stats_ref)
      end)
      |> Stream.run()

      # Return final stats
      [{:inserted, inserted}] = :ets.lookup(stats_ref, :inserted)
      [{:skipped, skipped}] = :ets.lookup(stats_ref, :skipped)
      [{:skipped_biblio_ids, skipped_biblio_ids}] = :ets.lookup(stats_ref, :skipped_biblio_ids)

      end_time = System.monotonic_time(:millisecond)
      duration = end_time - start_time

      IO.puts("\n✅ File processed in #{duration}ms")
      IO.puts("📦 File stats - Inserted: #{inserted}, Skipped: #{skipped}")

      %{
        inserted: inserted,
        skipped: skipped,
        skipped_biblio_ids: skipped_biblio_ids
      }
    after
      :ets.delete(stats_ref)
      :ets.delete(state_ref)
    end
  end

  # Process a batch of items with single transaction
  defp process_item_batch(batch, stats_ref) do
    {valid_items, error_items} =
      batch
      |> Enum.split_with(fn {{status, _}, _line_num} -> status == :ok end)

    # Handle valid items
    if length(valid_items) > 0 do
      items_data =
        valid_items
        |> Enum.map(fn {{:ok, item_data}, _line_num} -> item_data end)

      try do
        {count, _} = Repo.insert_all(Item, items_data, on_conflict: :nothing, returning: false)

        :ets.update_counter(stats_ref, :inserted, count)

        # Progress indicator
        if rem(count, 100) == 0 and count > 0 do
          IO.write(".")
        end
      rescue
        e ->
          IO.puts("\n⚠️ Item batch insert error: #{inspect(e)}")
          :ets.update_counter(stats_ref, :skipped, length(items_data))
      end
    end

    # Handle errors
    if length(error_items) > 0 do
      error_biblio_ids =
        error_items
        |> Enum.map(fn {{:error, {:missing_biblio_id, biblio_id}}, _line_num} -> biblio_id end)
        |> Enum.reject(&is_nil/1)

      :ets.update_counter(stats_ref, :skipped, length(error_items))

      # Update skipped biblio IDs
      [{:skipped_biblio_ids, existing_ids}] = :ets.lookup(stats_ref, :skipped_biblio_ids)
      :ets.insert(stats_ref, {:skipped_biblio_ids, existing_ids ++ error_biblio_ids})
    end
  end

  # Prepare item data using cached biblio mapping (optimized version)
  defp prepare_item_data(
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
         state_ref
       ) do
    id = Ecto.UUID.generate()

    case Map.fetch(biblio_map, parse_int(biblio_id)) do
      {:ok, coll_id} ->
        # coll_id should already be binary
        collection_id = coll_id
        biblio_id_int = parse_int(biblio_id)

        # Get and increment index for this biblio_id using ETS
        index =
          case :ets.lookup(state_ref, {:biblio_index, biblio_id_int}) do
            [{_key, current_index}] ->
              new_index = current_index + 1
              :ets.insert(state_ref, {{:biblio_index, biblio_id_int}, new_index})
              new_index

            [] ->
              :ets.insert(state_ref, {{:biblio_index, biblio_id_int}, 1})
              1
          end

        # Get or create time_identifier for this biblio_id using ETS
        time_identifier =
          case :ets.lookup(state_ref, {:biblio_time, biblio_id_int}) do
            [{_key, existing_time}] ->
              existing_time

            [] ->
              new_time = System.system_time(:second)
              :ets.insert(state_ref, {{:biblio_time, biblio_id_int}, new_time})
              new_time
          end

        {:ok,
         %{
           id: id,
           collection_id: collection_id,
           item_code:
             safe_string_trim(item_code) ||
               generate_item_code(biblio_id_int, index, time_identifier),
           inventory_code: safe_string_trim(inventory_code),
           site: safe_string_trim(site),
           status: "available",
           condition: "good",
           inserted_at: parse_datetime(input_date) || DateTime.utc_now(),
           updated_at: parse_datetime(last_update) || DateTime.utc_now()
         }}

      :error ->
        {:error, {:missing_biblio_id, biblio_id}}
    end
  end

  defp prepare_item_data(_invalid_row, _biblio_map, _state_ref) do
    {:error, {:invalid_row, "insufficient columns"}}
  end

  defp build_biblio_map do
    from(c in Collection, select: {c.old_biblio_id, c.id})
    |> Repo.all()
    |> Enum.into(%{}, fn {old_biblio_id, id} ->
      case old_biblio_id do
        nil -> {nil, id}
        val -> {parse_int(to_string(val)), id}
      end
    end)
    |> Map.reject(fn {k, _v} -> k == nil end)
  end

  defp generate_item_code(biblio_id, index, time_identifier) do
    # Generate a unique item code based on biblio_id, index, and time
    "B#{biblio_id}-#{index}-#{time_identifier}"
  end
end
