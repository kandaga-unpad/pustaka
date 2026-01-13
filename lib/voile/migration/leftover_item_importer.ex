defmodule Voile.Migration.LeftoverItemImporter do
  @moduledoc """
  Imports leftover item data from a CSV list of item_codes that were not imported initially.

  This script searches the original item CSV files to find the full rows for the given item_codes,
  then attempts to import them using the same logic as ItemImporter.

  Expected input: CSV file with one column: item_code (legacy item codes)
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

  def import_from_csv(csv_path, _batch_size \\ 100) do
    IO.puts("📦 Starting leftover item import from #{csv_path}...")

    # Check if CSV exists
    unless File.exists?(csv_path) do
      IO.puts("❌ CSV file not found: #{csv_path}")
      exit(1)
    end

    # Initialize cache
    cache = initialize_cache()
    IO.puts("🔗 Built biblio_id → collection_id map (#{map_size(cache.biblio_map)} entries)")

    # Read item_codes from CSV
    item_codes = read_item_codes_from_csv(csv_path)
    IO.puts("📋 Found #{length(item_codes)} item_codes to process")

    if Enum.empty?(item_codes) do
      IO.puts("⚠️ No item_codes found in CSV")
      %{inserted: 0, skipped: 0, not_found: 0}
    else
      # Get all item CSV files
      item_files = get_csv_files("items")

      # Process each item_code
      stats =
        item_codes
        |> Enum.reduce(%{inserted: 0, skipped: 0, not_found: 0}, fn item_code, acc ->
          case find_and_import_item(item_code, item_files, cache) do
            :inserted -> %{acc | inserted: acc.inserted + 1}
            :skipped -> %{acc | skipped: acc.skipped + 1}
            :not_found -> %{acc | not_found: acc.not_found + 1}
          end
        end)

      print_summary("LEFTOVER ITEM IMPORT", %{
        "Items Inserted" => stats.inserted,
        "Items Skipped" => stats.skipped,
        "Items Not Found in CSVs" => stats.not_found
      })

      stats
    end
  end

  defp read_item_codes_from_csv(csv_path) do
    File.stream!(csv_path)
    |> CSVParser.parse_stream()
    # Skip header
    |> Stream.drop(1)
    |> Enum.map(fn [item_code | _] -> String.trim(item_code) end)
    # Remove empty lines
    |> Enum.reject(&(&1 == ""))
  end

  defp find_and_import_item(item_code, item_files, cache) do
    # Search for the item_code in all item CSV files
    case find_row_by_item_code(item_code, item_files) do
      {:ok, {row, unit_id}} ->
        # Found the row, now try to import it
        case prepare_item_data_for_leftover(row, cache, unit_id) do
          {:ok, item_data} ->
            # Insert the item
            try do
              {count, _} =
                Repo.insert_all(Item, [item_data], on_conflict: :nothing, returning: false)

              if count > 0 do
                IO.puts("✅ Inserted item: #{item_code}")
                :inserted
              else
                IO.puts("⚠️ Skipped (already exists): #{item_code}")
                :skipped
              end
            rescue
              e ->
                IO.puts("❌ Insert error for #{item_code}: #{inspect(e)}")
                :skipped
            end

          {:error, reason} ->
            IO.puts("⚠️ Skipped #{item_code}: #{inspect(reason)}")
            :skipped
        end

      :not_found ->
        IO.puts("❓ Not found in CSVs: #{item_code}")
        :not_found
    end
  end

  defp find_row_by_item_code(item_code, item_files) do
    Enum.find_value(item_files, :not_found, fn file_path ->
      unit_id = extract_unit_id_from_filename(file_path)

      result =
        File.stream!(file_path)
        |> CSVParser.parse_stream()
        # Skip header
        |> Stream.drop(1)
        |> Enum.find(fn row ->
          # Assuming item_code is the 5th column (0-indexed: 4)
          length(row) >= 5 && Enum.at(row, 4) == item_code
        end)

      case result do
        nil -> nil
        row -> {:ok, {row, unit_id}}
      end
    end)
  end

  # Adapted from ItemImporter.prepare_item_data, but simplified for single item
  defp prepare_item_data_for_leftover(
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
         unit_id
       )
       when length(row) >= 21 do
    id = Ecto.UUID.generate()
    biblio_id_int = parse_int(biblio_id)

    # Use composite key (unit_id, old_biblio_id) to lookup collection
    case Map.fetch(biblio_map, {unit_id, biblio_id_int}) do
      {:ok, coll_id} ->
        collection_id = coll_id

        # For leftovers, we need to determine the index properly
        # This is tricky because we don't have the state_ref
        # We'll use a simple approach: count existing items for this collection
        existing_count =
          from(i in Item, where: i.collection_id == ^collection_id, select: count(i.id))
          |> Repo.one()

        index = existing_count + 1

        # Use current time for time_identifier
        time_identifier = System.system_time(:second)

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

        # Generate barcode from final_item_code
        barcode = ItemHelper.generate_barcode_from_item_code(final_item_code)

        {:ok,
         %{
           id: id,
           collection_id: collection_id,
           item_code: final_item_code,
           legacy_item_code: item_code,
           inventory_code: final_inventory_code,
           barcode: barcode,
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

  defp prepare_item_data_for_leftover(row, _cache, _unit_id) do
    {:error, {:invalid_row, "Expected at least 21 columns, got #{length(row)}"}}
  end

  # Reuse the cache building functions from ItemImporter
  defp initialize_cache do
    IO.puts("🔄 Initializing leftover cache...")

    biblio_map = build_biblio_map()
    unit_map = build_unit_map()
    resource_class_map = build_resource_class_map()
    collection_map = build_collection_map()

    IO.puts("✅ Cache initialized:")
    IO.puts("  - Biblio mappings: #{map_size(biblio_map)}")
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

  defp build_biblio_map do
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
