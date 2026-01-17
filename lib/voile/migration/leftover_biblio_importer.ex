defmodule Voile.Migration.LeftoverBiblioImporter do
  @moduledoc """
  Imports leftover bibliography/collection data for items that couldn't be imported.

  This script reads a CSV of missing item_codes, finds the corresponding biblio_ids from item CSVs,
  then imports the missing collections from biblio CSVs.

  Expected input: CSV file with one column: item_code (legacy item codes)
  """

  import Voile.Migration.Common
  import Ecto.Query

  alias Voile.Repo
  alias Voile.Schema.Catalog.{Collection, CollectionField}
  alias Voile.Schema.Master.Creator
  alias Voile.Schema.System.Node
  alias Voile.Schema.Metadata.ResourceClass

  # Property map from BiblioImporter
  @property_map %{
    "title" => %{id: 182, local_name: "title", label: "Title", type_value: "text"},
    "sor" => %{
      id: 183,
      local_name: "sor",
      label: "Statement of Responsibility",
      type_value: "textarea"
    },
    "edition" => %{id: 184, local_name: "edition", label: "Edition", type_value: "text"},
    "isbn_issn" => %{id: 185, local_name: "isbn", label: "ISBN/ISSN", type_value: "text"},
    "publisher_id" => %{id: 187, local_name: "publisher", label: "Publisher", type_value: "text"},
    "publish_year" => %{
      id: 188,
      local_name: "publishedYear",
      label: "Published Year",
      type_value: "number"
    },
    "collation" => %{id: 191, local_name: "collation", label: "Collation", type_value: "text"},
    "series_title" => %{
      id: 192,
      local_name: "seriesTitle",
      label: "Series Title",
      type_value: "text"
    },
    "call_number" => %{
      id: 193,
      local_name: "callNumber",
      label: "Call Number",
      type_value: "text"
    },
    "classification" => %{
      id: 196,
      local_name: "classification",
      label: "Classification",
      type_value: "text"
    },
    "notes" => %{id: 197, local_name: "notes", label: "Notes", type_value: "textarea"}
  }

  def import_from_item_codes_csv(csv_path, skip_images \\ false) do
    IO.puts("📚 Starting leftover biblio import from item_codes CSV: #{csv_path}...")

    # Check if CSV exists
    unless File.exists?(csv_path) do
      IO.puts("❌ CSV file not found: #{csv_path}")
      exit(1)
    end

    # Read item_codes from CSV
    item_codes = read_item_codes_from_csv(csv_path)
    IO.puts("📋 Found #{length(item_codes)} item_codes to process")

    if Enum.empty?(item_codes) do
      IO.puts("⚠️ No item_codes found in CSV")
      %{collections_inserted: 0, fields_inserted: 0, skipped: 0}
    else
      # Get all item and biblio CSV files
      item_files = get_csv_files("items")
      biblio_files = get_specific_files("biblio", "biblio_[0-9]*.csv")

      # Find unique biblio_ids from item_codes
      biblio_ids = find_biblio_ids_from_item_codes(item_codes, item_files)
      IO.puts("🔍 Found #{length(biblio_ids)} unique biblio_ids to import collections for")

      if Enum.empty?(biblio_ids) do
        IO.puts("⚠️ No biblio_ids found")
        %{collections_inserted: 0, fields_inserted: 0, skipped: 0}
      else
        # Initialize cache
        cache = initialize_cache()

        # Import collections for these biblio_ids
        import_collections_for_biblio_ids(biblio_ids, biblio_files, cache, skip_images)
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

  defp find_biblio_ids_from_item_codes(item_codes, item_files) do
    item_codes
    |> Enum.reduce(MapSet.new(), fn item_code, acc ->
      case find_biblio_id_for_item_code(item_code, item_files) do
        {:ok, biblio_id} -> MapSet.put(acc, biblio_id)
        :not_found -> acc
      end
    end)
    |> MapSet.to_list()
  end

  defp find_biblio_id_for_item_code(item_code, item_files) do
    Enum.find_value(item_files, :not_found, fn file_path ->
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
        nil ->
          nil

        row ->
          # biblio_id is the 2nd column (0-indexed: 1)
          if length(row) >= 2 do
            biblio_id = Enum.at(row, 1)

            case parse_int(biblio_id) do
              nil -> nil
              id -> {:ok, id}
            end
          else
            nil
          end
      end
    end)
  end

  defp import_collections_for_biblio_ids(biblio_ids, biblio_files, cache, skip_images) do
    stats = %{collections_inserted: 0, fields_inserted: 0, skipped: 0}

    biblio_ids
    |> Enum.reduce(stats, fn biblio_id, acc ->
      case find_and_import_collection(biblio_id, biblio_files, cache, skip_images) do
        {:inserted, fields_count} ->
          %{
            acc
            | collections_inserted: acc.collections_inserted + 1,
              fields_inserted: acc.fields_inserted + fields_count
          }

        :skipped ->
          %{acc | skipped: acc.skipped + 1}

        :not_found ->
          # Already counted as skipped in find_and_import_collection
          acc
      end
    end)
    |> then(fn final_stats ->
      print_summary("LEFTOVER BIBLIO IMPORT", %{
        "Collections Inserted" => final_stats.collections_inserted,
        "Fields Inserted" => final_stats.fields_inserted,
        "Collections Skipped" => final_stats.skipped
      })

      final_stats
    end)
  end

  defp find_and_import_collection(biblio_id, biblio_files, cache, skip_images) do
    # Search for the biblio_id in all biblio CSV files
    case find_biblio_row(biblio_id, biblio_files) do
      {:ok, {row, unit_id}} ->
        # Found the row, now try to import the collection
        case prepare_and_import_collection(row, unit_id, cache, skip_images) do
          {:inserted, fields_count} ->
            IO.puts("✅ Inserted collection for biblio_id: #{biblio_id}")
            {:inserted, fields_count}

          {:skipped, reason} ->
            IO.puts("⚠️ Skipped collection #{biblio_id}: #{reason}")
            :skipped
        end

      :not_found ->
        IO.puts("❓ Biblio row not found for biblio_id: #{biblio_id}")
        :not_found
    end
  end

  defp find_biblio_row(biblio_id, biblio_files) do
    Enum.find_value(biblio_files, :not_found, fn file_path ->
      unit_id = extract_unit_id_from_filename(file_path)

      result =
        File.stream!(file_path)
        |> CSVParser.parse_stream(skip_headers: false)
        # Skip header
        |> Stream.drop(1)
        |> Enum.find(fn row ->
          # biblio_id is the 1st column (0-indexed: 0)
          length(row) >= 1 && Enum.at(row, 0) == to_string(biblio_id)
        end)

      case result do
        nil -> nil
        row -> {:ok, {row, unit_id}}
      end
    end)
  end

  # Adapted from BiblioImporter.prepare_biblio_data
  defp prepare_and_import_collection(row, unit_id, cache, skip_images) do
    case row do
      [
        biblio_id,
        _gmd_id,
        title,
        _sor,
        _edition,
        _isbn_issn,
        publisher_id,
        _publish_year,
        _collation,
        _series_title,
        _call_number,
        _language_id,
        _source,
        _publish_place_id,
        _classification,
        notes,
        _image,
        _file_att,
        _opac_hide,
        _promoted,
        _labels,
        _frequency_id,
        _spec_detail_info,
        _content_type_id,
        _media_type_id,
        _carrier_type_id,
        _input_date,
        _last_update,
        _uid | _rest
      ]
      when length(row) >= 29 ->
        biblio_id_int = parse_int(biblio_id)

        # Check if already exists
        if MapSet.member?(cache.existing_collections, {unit_id, biblio_id_int}) do
          {:skipped, "Collection already exists"}
        else
          now = DateTime.utc_now() |> DateTime.truncate(:second)

          # Generate UUID for collection
          id = Ecto.UUID.generate()

          # Get primary creator
          creator_id =
            get_primary_creator_id_cached(
              biblio_id_int,
              cache.unit_author_data[unit_id] || %{},
              cache.author_mappings[unit_id] || %{},
              cache.creators
            ) || cache.default_creator_id

          # Get publisher name
          publisher_name =
            get_publisher_name_cached(publisher_id, cache.publisher_mappings[unit_id] || %{})

          # Handle image
          {thumbnail_path, _image_metadata} =
            if skip_images do
              {nil, nil}
            else
              # Simplified image handling
              {nil, nil}
            end

          # Get unit and resource class data
          unit_data = Map.get(cache.unit_map, unit_id, %{abbr: "UNK"})
          resource_type_id = cache.bibliographic_resource_type_id

          resource_class_data =
            Map.get(cache.resource_class_map, resource_type_id, %{local_name: "LIB"})

          # Generate collection code
          collection_code =
            generate_collection_code(unit_data.abbr, resource_class_data.local_name)

          # Build collection record
          collection = %{
            id: id,
            title: safe_string_trim(title),
            description: safe_string_trim(notes),
            thumbnail: thumbnail_path,
            status: "published",
            access_level: "public",
            old_biblio_id: biblio_id_int,
            creator_id: creator_id,
            collection_code: collection_code,
            type_id: resource_type_id,
            unit_id: unit_id,
            inserted_at: now,
            updated_at: now
          }

          # Build collection fields
          fields = build_collection_fields_optimized(id, row, publisher_name, now, biblio_id_int)

          # Insert collection
          try do
            {coll_count, _} =
              Repo.insert_all(Collection, [collection], on_conflict: :nothing, returning: false)

            if coll_count > 0 do
              # Insert fields
              {fields_count, _} =
                Repo.insert_all(CollectionField, fields, on_conflict: :nothing, returning: false)

              {:inserted, fields_count}
            else
              {:skipped, "Collection already exists (on_conflict)"}
            end
          rescue
            e ->
              {:skipped, "Insert error: #{inspect(e)}"}
          end
        end

      _ ->
        {:skipped, "Invalid row format"}
    end
  end

  # Helper functions from BiblioImporter
  defp initialize_cache do
    IO.puts("🔄 Initializing leftover biblio cache...")

    author_mappings = load_all_author_mappings()
    publisher_mappings = load_all_publisher_mappings()

    default_creator_id = ensure_default_creator()
    creators = Repo.all(Creator) |> Enum.into(%{}, fn c -> {c.creator_name, c.id} end)

    existing_collections =
      from(c in Collection,
        select: {c.unit_id, c.old_biblio_id},
        where: not is_nil(c.old_biblio_id)
      )
      |> Repo.all()
      |> MapSet.new()

    unit_map = build_unit_map()
    resource_class_map = build_resource_class_map()
    bibliographic_resource_type_id = get_bibliographic_resource_type_id()

    # Load unit author data for all units
    unit_author_data = load_all_unit_author_data()

    %{
      author_mappings: author_mappings,
      publisher_mappings: publisher_mappings,
      creators: creators,
      default_creator_id: default_creator_id,
      existing_collections: existing_collections,
      unit_map: unit_map,
      resource_class_map: resource_class_map,
      bibliographic_resource_type_id: bibliographic_resource_type_id,
      unit_author_data: unit_author_data
    }
  end

  # Include necessary helper functions from BiblioImporter
  defp load_all_author_mappings do
    unit_files = get_specific_files("mst", "mst_author_*.csv")

    if Enum.empty?(unit_files) do
      main_file = Path.join([csv_base_path(), "mst", "mst_author.csv"])

      if File.exists?(main_file) do
        authors = load_authors_from_file(main_file)
        %{0 => authors}
      else
        %{}
      end
    else
      unit_files
      |> Enum.reduce(%{}, fn file, acc ->
        unit_id = extract_unit_id_from_filename(file)
        authors = load_authors_from_file(file)
        Map.put(acc, unit_id, authors)
      end)
    end
  end

  defp load_all_publisher_mappings do
    unit_files = get_specific_files("mst", "mst_publisher_*.csv")

    if Enum.empty?(unit_files) do
      main_file = Path.join([csv_base_path(), "mst", "mst_publisher.csv"])

      if File.exists?(main_file) do
        publishers = load_publishers_from_file(main_file)
        %{0 => publishers}
      else
        %{}
      end
    else
      unit_files
      |> Enum.reduce(%{}, fn file, acc ->
        unit_id = extract_unit_id_from_filename(file)
        publishers = load_publishers_from_file(file)
        Map.put(acc, unit_id, publishers)
      end)
    end
  end

  defp load_all_unit_author_data do
    # Get all unit IDs from biblio files
    biblio_files = get_specific_files("biblio", "biblio_[0-9]*.csv")
    unit_ids = Enum.map(biblio_files, &extract_unit_id_from_filename/1) |> Enum.uniq()

    unit_ids
    |> Enum.reduce(%{}, fn unit_id, acc ->
      author_data = load_unit_author_data(unit_id)
      Map.put(acc, unit_id, author_data)
    end)
  end

  # Copy other necessary functions
  defp load_authors_from_file(file_path) do
    File.stream!(file_path)
    |> CSVParser.parse_stream()
    |> Stream.drop(1)
    |> Enum.reduce(%{}, fn [author_id, author_name | _rest], acc ->
      case parse_int(author_id) do
        nil -> acc
        id -> Map.put(acc, id, String.trim(author_name))
      end
    end)
  end

  defp load_publishers_from_file(file_path) do
    File.stream!(file_path)
    |> CSVParser.parse_stream()
    |> Stream.drop(1)
    |> Enum.reduce(%{}, fn [publisher_id, publisher_name | _rest], acc ->
      case parse_int(publisher_id) do
        nil -> acc
        id -> Map.put(acc, id, String.trim(publisher_name))
      end
    end)
  end

  defp load_unit_author_data(unit_id) do
    biblio_author_file = Path.join([csv_base_path(), "biblio", "biblio_author_#{unit_id}.csv"])

    if File.exists?(biblio_author_file) do
      load_biblio_author_relations(biblio_author_file)
    else
      biblio_author_file_mst = Path.join([csv_base_path(), "mst", "biblio_author_#{unit_id}.csv"])

      if File.exists?(biblio_author_file_mst) do
        load_biblio_author_relations(biblio_author_file_mst)
      else
        %{}
      end
    end
  end

  defp load_biblio_author_relations(file_path) do
    File.stream!(file_path)
    |> CSVParser.parse_stream()
    |> Stream.drop(1)
    |> Enum.reduce(%{}, fn row, acc ->
      case row do
        [biblio_id, author_id, level | _rest] ->
          biblio_id_int = parse_int(biblio_id)
          author_id_int = parse_int(author_id)
          level_int = parse_int(level)

          if biblio_id_int && author_id_int && level_int do
            authors = Map.get(acc, biblio_id_int, [])
            updated_authors = [{author_id_int, level_int} | authors] |> Enum.sort_by(&elem(&1, 1))
            Map.put(acc, biblio_id_int, updated_authors)
          else
            acc
          end

        _ ->
          acc
      end
    end)
  end

  defp get_primary_creator_id_cached(
         biblio_id,
         unit_author_data,
         unit_author_mappings,
         creators_cache
       ) do
    case get_primary_creator_name(biblio_id, unit_author_data, unit_author_mappings) do
      nil -> nil
      creator_name -> Map.get(creators_cache, creator_name)
    end
  end

  defp get_primary_creator_name(biblio_id, unit_author_data, unit_author_mappings) do
    case Map.get(unit_author_data, biblio_id) do
      nil ->
        nil

      authors when is_list(authors) ->
        case List.first(authors) do
          nil -> nil
          {author_id, _level} -> Map.get(unit_author_mappings, author_id)
        end

      author_id when is_integer(author_id) ->
        Map.get(unit_author_mappings, author_id)

      _ ->
        nil
    end
  end

  defp get_publisher_name_cached(publisher_id, unit_publisher_mappings) do
    case parse_int(publisher_id) do
      nil -> nil
      id -> Map.get(unit_publisher_mappings, id)
    end
  end

  defp ensure_default_creator do
    default_name = "Kandaga Universitas Padjadjaran"

    case Voile.Schema.Master.get_or_create_creator(%{
           creator_name: default_name,
           type: "Organization"
         }) do
      {:ok, creator} -> creator.id
      _ -> nil
    end
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

  defp get_bibliographic_resource_type_id do
    case Repo.one(from(rc in ResourceClass, where: rc.label == "Book", select: rc.id)) do
      id when is_integer(id) ->
        id

      _ ->
        case Repo.one(from(rc in ResourceClass, where: rc.local_name == "Book", select: rc.id)) do
          id when is_integer(id) -> id
          # fallback
          _ -> 40
        end
    end
  end

  defp generate_collection_code(unit, collection_type) do
    timestamp = :os.system_time(:second)
    random_suffix = :crypto.strong_rand_bytes(3) |> Base.encode16(case: :lower)
    "COLLECTION-#{unit}-#{collection_type}-#{timestamp}-#{random_suffix}"
  end

  # Copy from BiblioImporter
  defp build_collection_fields_optimized(collection_id, row, publisher_name, now, _old_biblio_id) do
    [
      _biblio_id,
      _gmd_id,
      title,
      sor,
      edition,
      isbn_issn,
      _publisher_id,
      publish_year,
      collation,
      series_title,
      call_number,
      _language_id,
      _source,
      _publish_place_id,
      classification,
      notes,
      _image | _rest
    ] = row

    field_values = %{
      "title" => title,
      "sor" => sor,
      "edition" => edition,
      "isbn_issn" => isbn_issn,
      "publisher_id" => publisher_name,
      "publish_year" => publish_year,
      "collation" => collation,
      "series_title" => series_title,
      "call_number" => call_number,
      "classification" => classification,
      "notes" => notes
    }

    @property_map
    |> Enum.with_index()
    |> Enum.reduce([], fn {{field_name, property}, index}, acc ->
      case Map.get(field_values, field_name) do
        value when not is_nil(value) ->
          trimmed_value = safe_string_trim(value)

          if not is_null_value?(trimmed_value) do
            field = %{
              id: Ecto.UUID.generate(),
              collection_id: collection_id,
              property_id: property.id,
              name: property.local_name,
              label: property.label,
              value: trimmed_value,
              value_lang: "id",
              type_value: property.type_value,
              sort_order: index,
              inserted_at: now,
              updated_at: now
            }

            [field | acc]
          else
            acc
          end

        _ ->
          acc
      end
    end)
  end

  defp is_null_value?(value) when value in [nil, ""], do: true

  defp is_null_value?(value) when is_binary(value) do
    trimmed = String.trim(value)

    trimmed == "" or trimmed == "\\N" or trimmed == "NULL" or trimmed == "null" or
      trimmed == "N/A" or trimmed == "n/a" or trimmed == "-" or String.match?(trimmed, ~r/^\s*$/)
  end

  defp is_null_value?(_), do: false
end
