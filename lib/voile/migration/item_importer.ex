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
  alias Voile.Schema.System.Node
  alias Voile.Schema.Metadata.ResourceClass
  alias Voile.Utils.ItemHelper

  # Cache for frequently accessed data
  @type cache :: %{
          biblio_map: map(),
          unit_map: map(),
          resource_class_map: map(),
          collection_map: map()
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

    # Build (unit_id, biblio_id) to collection_id mapping - composite key to handle duplicates across units
    biblio_map = build_biblio_map()

    # Build unit_id to unit data mapping
    unit_map = build_unit_map()

    # Build type_id to resource class data mapping
    resource_class_map = build_resource_class_map()

    # Build collection_id to collection data mapping
    collection_map = build_collection_map()

    IO.puts("✅ Cache initialized:")
    IO.puts("  - Biblio mappings (composite key): #{map_size(biblio_map)}")
    IO.puts("  - Unit mappings: #{map_size(unit_map)}")
    IO.puts("  - Resource class mappings: #{map_size(resource_class_map)}")
    IO.puts("  - Collection mappings: #{map_size(collection_map)}")

    %{
      biblio_map: biblio_map,
      unit_map: unit_map,
      resource_class_map: resource_class_map,
      collection_map: collection_map
    }
  end

  # Optimized file processing using streams and batching
  defp process_item_file_optimized(file_path, batch_size, cache) do
    unit_id = extract_unit_id_from_filename(file_path)
    filename = Path.basename(file_path)
    IO.puts("📋 Processing unit ID: #{unit_id || "unknown"} (#{filename})")

    file_size = File.stat!(file_path).size
    IO.puts("📊 File size: #{Float.round(file_size / 1024 / 1024, 2)} MB")

    start_time = System.monotonic_time(:millisecond)

    stats_ref = :ets.new(:item_import_stats, [:set, :public])
    :ets.insert(stats_ref, {:inserted, 0})
    :ets.insert(stats_ref, {:skipped, 0})
    :ets.insert(stats_ref, {:skipped_biblio_ids, []})
    :ets.insert(stats_ref, {:sample_errors, []})

    # Create state tracking ETS table for biblio indices and times
    state_ref = :ets.new(:item_state, [:set, :public])

    try do
      File.stream!(file_path)
      |> CSVParser.parse_stream()
      |> Stream.drop(1)
      |> Stream.with_index(1)
      |> Stream.map(fn {row, line_num} ->
        result = prepare_item_data(row, cache, state_ref, unit_id)

        # Log first 10 errors for debugging
        case result do
          {:error, reason} ->
            skipped_count = :ets.update_counter(stats_ref, :skipped, {2, 0})

            if skipped_count < 10 do
              IO.puts(
                "⚠️ [Unit #{unit_id}] Skipping line #{line_num}: #{inspect(reason)} | Row columns: #{length(row)}"
              )

              [{:sample_errors, samples}] = :ets.lookup(stats_ref, :sample_errors)

              :ets.insert(
                stats_ref,
                {:sample_errors, [{line_num, reason, length(row)} | samples]}
              )
            end

          _ ->
            :ok
        end

        {result, line_num}
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
      [{:sample_errors, sample_errors}] = :ets.lookup(stats_ref, :sample_errors)

      end_time = System.monotonic_time(:millisecond)
      duration = end_time - start_time

      IO.puts("\n✅ File processed: #{filename} in #{duration}ms")
      IO.puts("  - Unit ID: #{unit_id}")
      IO.puts("📦 File stats - Inserted: #{inserted}, Skipped: #{skipped}")

      if skipped > 10 and length(sample_errors) > 0 do
        IO.puts("\n📊 Sample of skipped rows (first 10):")

        sample_errors
        |> Enum.reverse()
        |> Enum.each(fn {line, reason, col_count} ->
          IO.puts("  Line #{line}: #{inspect(reason)} (#{col_count} columns)")
        end)
      end

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
        |> Enum.map(fn
          {{:error, {:missing_biblio_id, {unit_id, biblio_id}}}, _line_num} ->
            "unit_#{unit_id}_biblio_#{biblio_id}"

          {{:error, {:invalid_row, _reason}}, _line_num} ->
            nil

          _other ->
            nil
        end)
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
           _inventory_code,
           _received_date,
           _supplier_id,
           _order_no,
           _location_id,
           _order_date,
           _item_status_id,
           _site,
           _source,
           _invoice,
           _price,
           _price_currency,
           _invoice_date,
           input_date,
           last_update,
           _uid
         ] = row,
         %{
           biblio_map: biblio_map,
           unit_map: unit_map,
           resource_class_map: resource_class_map,
           collection_map: collection_map
         } = _cache,
         state_ref,
         unit_id
       )
       when length(row) >= 21 do
    id = Ecto.UUID.generate()
    biblio_id_int = parse_int(biblio_id)

    # Use composite key (unit_id, old_biblio_id) to lookup collection
    case Map.fetch(biblio_map, {unit_id, biblio_id_int}) do
      {:ok, coll_id} ->
        # coll_id should already be binary
        collection_id = coll_id

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

        now = DateTime.utc_now() |> DateTime.truncate(:second)

        # Get collection and unit data for code generation
        collection_data = Map.get(collection_map, collection_id, %{})
        unit_data = Map.get(unit_map, unit_id, %{abbr: "UNK"})

        resource_class_data =
          Map.get(resource_class_map, collection_data[:type_id], %{local_name: "UNK"})

        # Generate codes using ItemHelper format
        final_item_code =
          ItemHelper.generate_item_code(
            unit_data.abbr,
            resource_class_data.local_name,
            collection_id,
            time_identifier,
            to_string(index)
          )

        final_inventory_code =
          ItemHelper.generate_inventory_code(
            unit_data.abbr,
            resource_class_data.local_name,
            collection_id,
            index
          )

        {:ok,
         %{
           id: id,
           collection_id: collection_id,
           item_code: final_item_code,
           legacy_item_code: item_code,
           inventory_code: final_inventory_code,
           location: unit_data.name,
           status: "active",
           condition: "good",
           availability: "available",
           unit_id: unit_id,
           inserted_at: parse_datetime(input_date) || now,
           updated_at: parse_datetime(last_update) || now
         }}

      :error ->
        {:error, {:missing_biblio_id, {unit_id, biblio_id_int}}}
    end
  end

  defp prepare_item_data(row, _cache, _state_ref, _unit_id) do
    {:error, {:invalid_row, "Expected at least 21 columns, got #{length(row)}"}}
  end

  defp build_biblio_map do
    # Use composite key (unit_id, old_biblio_id) to handle same biblio_id across different units
    from(c in Collection, select: {c.unit_id, c.old_biblio_id, c.id})
    |> Repo.all()
    |> Enum.reduce(%{}, fn {unit_id, old_biblio_id, id}, acc ->
      case old_biblio_id do
        nil ->
          acc

        val ->
          biblio_int = parse_int(to_string(val))

          if biblio_int && unit_id do
            Map.put(acc, {unit_id, biblio_int}, id)
          else
            acc
          end
      end
    end)
  end

  defp build_unit_map do
    from(n in Node, select: {n.id, %{abbr: n.abbr, name: n.name}})
    |> Repo.all()
    |> Enum.into(%{})
  end

  defp build_resource_class_map do
    from(rc in ResourceClass,
      select: {rc.id, %{local_name: rc.local_name, glam_type: rc.glam_type}}
    )
    |> Repo.all()
    |> Enum.into(%{})
  end

  defp build_collection_map do
    from(c in Collection, select: {c.id, %{title: c.title, type_id: c.type_id}})
    |> Repo.all()
    |> Enum.into(%{})
  end
end
