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

  def import_from_csv(csv_path, unit_id \\ nil, opts \\ []) do
    IO.puts(
      "📦 Starting leftover item import from #{csv_path}#{if unit_id, do: " (unit: #{unit_id})", else: ""}..."
    )

    # Check if CSV exists
    unless File.exists?(csv_path) do
      IO.puts("❌ CSV file not found: #{csv_path}")
      exit(1)
    end

    # Initialize cache (filtered by unit_id if provided)
    cache = initialize_cache(unit_id)
    IO.puts("🔗 Built biblio_id → collection_id map (#{map_size(cache.biblio_map)} entries)")

    # Read item_codes from CSV
    item_codes = read_item_codes_from_csv(csv_path)
    IO.puts("📋 Found #{length(item_codes)} item_codes to process")

    if Enum.empty?(item_codes) do
      IO.puts("⚠️ No item_codes found in CSV")
      %{inserted: 0, skipped: 0, not_found: 0}
    else
      # Get item CSV files (filtered by unit_id if provided)
      item_files = get_item_files_for_unit(unit_id)

      # Process each item_code
      {stats, inserted_item_ids} =
        item_codes
        |> Enum.reduce({%{inserted: 0, skipped: 0, not_found: 0}, []}, fn item_code, {acc, ids} ->
          case find_and_import_item(item_code, item_files, cache) do
            {:inserted, item_id} -> {%{acc | inserted: acc.inserted + 1}, [item_id | ids]}
            :skipped -> {%{acc | skipped: acc.skipped + 1}, ids}
            :not_found -> {%{acc | not_found: acc.not_found + 1}, ids}
          end
        end)

      print_summary("LEFTOVER ITEM IMPORT", %{
        "Items Inserted" => stats.inserted,
        "Items Skipped" => stats.skipped,
        "Items Not Found in CSVs" => stats.not_found
      })

      # Optionally add to stock opname session
      if session_id = opts[:add_to_session] do
        user = opts[:user] || get_default_user()

        IO.puts(
          "🔄 Adding #{length(inserted_item_ids)} inserted items to stock opname session #{session_id}..."
        )

        {:ok, added_count} =
          Voile.Schema.StockOpname.add_leftover_items_to_session(
            session_id,
            inserted_item_ids,
            user
          )

        IO.puts("✅ Added #{added_count} leftover items to stock opname session #{session_id}")
        Map.put(stats, :added_to_session, added_count)
      else
        stats
      end
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
            # Check if item already exists by legacy_item_code
            legacy_code = item_data[:legacy_item_code]

            if Repo.exists?(from i in Item, where: i.legacy_item_code == ^legacy_code) do
              IO.puts("⚠️ Skipped (already exists): #{item_code}")
              :skipped
            else
              # Insert the item
              try do
                {count, [inserted_item]} =
                  Repo.insert_all(Item, [item_data], on_conflict: :nothing, returning: [:id])

                if count > 0 do
                  IO.puts("✅ Inserted item: #{item_code}")
                  {:inserted, inserted_item.id}
                else
                  IO.puts("⚠️ Skipped (already exists): #{item_code}")
                  :skipped
                end
              rescue
                e ->
                  IO.puts("❌ Insert error for #{item_code}: #{inspect(e)}")
                  :skipped
              end
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
  defp initialize_cache(unit_id) do
    IO.puts("🔄 Initializing leftover cache#{if unit_id, do: " for unit #{unit_id}", else: ""}...")

    biblio_map = build_biblio_map(unit_id)
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

  defp build_biblio_map(unit_id) do
    query = from(c in Collection, select: {c.unit_id, c.old_biblio_id, c.id})

    query =
      if unit_id do
        from(c in query, where: c.unit_id == ^unit_id)
      else
        query
      end

    query
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

  defp get_default_user do
    # Try to find a system admin user for the operation
    case Repo.one(
           from(u in Voile.Schema.Accounts.User,
             join: ura in Voile.Schema.Accounts.UserRoleAssignment,
             on: ura.user_id == u.id,
             join: r in Voile.Schema.Accounts.Role,
             on: ura.role_id == r.id,
             where: r.name == "super_admin" and u.manually_suspended == false,
             select: u,
             limit: 1
           )
         ) do
      nil ->
        # Fallback to first active user
        case Repo.one(
               from(u in Voile.Schema.Accounts.User,
                 where: u.manually_suspended == false,
                 select: u,
                 limit: 1
               )
             ) do
          nil -> raise "No active users found in system"
          user -> user
        end

      user ->
        user
    end
  end

  # Helper to get item files filtered by unit_id
  defp get_item_files_for_unit(unit_id) do
    if unit_id do
      item_file = Path.join([csv_base_path(), "items", "item_#{unit_id}.csv"])
      if File.exists?(item_file), do: [item_file], else: []
    else
      get_csv_files("items")
    end
  end
end
