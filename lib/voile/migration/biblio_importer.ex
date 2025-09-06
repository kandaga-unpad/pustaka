defmodule Voile.Migration.BiblioImporter do
  @moduledoc """
  Imports bibliography/collection data from CSV files with optimized streaming and batch processing.

  Expected CSV structure:
  - scripts/csv_data/biblio/biblio_*.csv
  - scripts/csv_data/mst/mst_author_*.csv (for author mapping)
  - scripts/csv_data/mst/mst_publisher_*.csv (for publisher mapping)
  """

  import Voile.Migration.Common
  import Ecto.Query

  alias Voile.Repo
  alias Voile.Schema.Catalog.{Collection, CollectionField}
  alias Voile.Schema.Master.Creator

  # Cache for frequently accessed data
  @type cache :: %{
          author_mappings: map(),
          publisher_mappings: map(),
          creators: map(),
          existing_collections: MapSet.t()
        }

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
    "notes" => %{id: 197, local_name: "notes", label: "Notes", type_value: "textarea"},
    "frequency_id" => %{id: 198, local_name: "frequency", label: "Frequency", type_value: "text"},
    "spec_detail_info" => %{
      id: 199,
      local_name: "specDetailInfo",
      label: "Special Detail Information",
      type_value: "textarea"
    }
  }

  def import_all(batch_size \\ 1000, skip_images \\ false) do
    IO.puts("📚 Starting bibliography data import...")

    # Ensure upload directory exists
    ensure_upload_dir()

    # Initialize cache with frequently accessed data
    cache = initialize_cache()

    # Get bibliography files
    files = get_csv_files("biblio")

    if Enum.empty?(files) do
      IO.puts("⚠️ No bibliography files found")
      %{inserted: 0, skipped: 0, errors: 0}
    else
      stats =
        files
        |> Stream.with_index(1)
        |> Enum.reduce(%{inserted: 0, skipped: 0, errors: 0}, fn {file, index}, acc ->
          IO.puts(
            "\n🔄 Processing bibliography file #{index}/#{length(files)}: #{Path.basename(file)}"
          )

          file_stats = process_biblio_file_optimized(file, batch_size, skip_images, cache)

          %{
            inserted: acc.inserted + file_stats.inserted,
            skipped: acc.skipped + file_stats.skipped,
            errors: acc.errors + file_stats.errors
          }
        end)

      print_summary("BIBLIOGRAPHY IMPORT", %{
        "Total Collections Inserted" => stats.inserted,
        "Total Collections Skipped" => stats.skipped,
        "Total Errors" => stats.errors
      })

      stats
    end
  end

  # Legacy method for backward compatibility
  def import_all_legacy(batch_size \\ 500, skip_images \\ false) do
    IO.puts("📚 Starting bibliography data import (legacy mode)...")

    # Ensure upload directory exists
    ensure_upload_dir()

    # Get bibliography files
    files = get_csv_files("biblio")

    if Enum.empty?(files) do
      IO.puts("⚠️ No bibliography files found")
      %{inserted: 0, skipped: 0, errors: 0}
    else
      # Load master data mappings
      author_mappings = load_all_author_mappings()
      publisher_mappings = load_all_publisher_mappings()

      stats =
        files
        |> Enum.with_index(1)
        |> Enum.reduce(%{inserted: 0, skipped: 0, errors: 0}, fn {file, index}, acc ->
          IO.puts(
            "\n🔄 Processing bibliography file #{index}/#{length(files)}: #{Path.basename(file)}"
          )

          file_stats =
            process_biblio_file_legacy(
              file,
              batch_size,
              skip_images,
              author_mappings,
              publisher_mappings
            )

          %{
            inserted: acc.inserted + file_stats.inserted,
            skipped: acc.skipped + file_stats.skipped,
            errors: acc.errors + file_stats.errors
          }
        end)

      print_summary("BIBLIOGRAPHY IMPORT", %{
        "Total Collections Inserted" => stats.inserted,
        "Total Collections Skipped" => stats.skipped,
        "Total Errors" => stats.errors
      })

      stats
    end
  end

  # Initialize cache with frequently accessed data to avoid repeated DB queries
  defp initialize_cache do
    IO.puts("🔄 Initializing bibliography cache...")

    # Load all author and publisher mappings upfront
    author_mappings = load_all_author_mappings()
    publisher_mappings = load_all_publisher_mappings()

    # Cache existing creators for faster lookups
    creators =
      Repo.all(Creator)
      |> Enum.into(%{}, fn creator -> {creator.creator_name, creator.id} end)

    # Cache existing collections to avoid duplicates
    existing_collections =
      from(c in Collection, select: c.old_biblio_id, where: not is_nil(c.old_biblio_id))
      |> Repo.all()
      |> MapSet.new()

    # Cache the Bibliographic Resource type ID
    bibliographic_resource_type_id = get_bibliographic_resource_type_id()

    IO.puts("✅ Cache initialized:")
    IO.puts("  - Author mappings: #{map_size(author_mappings)} units")
    IO.puts("  - Publisher mappings: #{map_size(publisher_mappings)} units")
    IO.puts("  - Creators: #{map_size(creators)}")
    IO.puts("  - Existing collections: #{MapSet.size(existing_collections)}")

    IO.puts("  - Bibliographic Resource type ID: #{bibliographic_resource_type_id}")

    %{
      author_mappings: author_mappings,
      publisher_mappings: publisher_mappings,
      creators: creators,
      existing_collections: existing_collections,
      bibliographic_resource_type_id: bibliographic_resource_type_id
    }
  end

  # All biblio records are books (type_id: 40)
  defp get_bibliographic_resource_type_id do
    40
  end

  # Optimized file processing using streams and batching
  defp process_biblio_file_optimized(file_path, batch_size, skip_images, cache) do
    unit_id = extract_unit_id_from_filename(file_path)
    IO.puts("📋 Processing unit ID: #{unit_id || "unknown"}")

    # Load specific author data for this unit from cache
    unit_author_mappings = Map.get(cache.author_mappings, unit_id, %{})
    unit_publisher_mappings = Map.get(cache.publisher_mappings, unit_id, %{})
    unit_author_data = load_unit_author_data(unit_id)

    stats_ref = :ets.new(:biblio_import_stats, [:set, :public])
    :ets.insert(stats_ref, {:collections_inserted, 0})
    :ets.insert(stats_ref, {:fields_inserted, 0})
    :ets.insert(stats_ref, {:errors, 0})
    :ets.insert(stats_ref, {:skipped, 0})

    try do
      File.stream!(file_path)
      |> CSVParser.parse_stream(skip_headers: false)
      |> Stream.drop(1)
      |> Stream.with_index(1)
      |> Stream.map(fn {row, line_num} ->
        {prepare_biblio_data(
           row,
           unit_id,
           skip_images,
           unit_author_mappings,
           unit_publisher_mappings,
           unit_author_data,
           cache
         ), line_num}
      end)
      |> Stream.filter(fn {{status, _}, _line_num} -> status == :ok end)
      |> Stream.map(fn {{:ok, {collection, fields}}, line_num} ->
        {collection, fields, line_num}
      end)
      |> Stream.chunk_every(batch_size)
      |> Stream.each(fn batch ->
        process_biblio_batch(batch, stats_ref)
      end)
      |> Stream.run()

      # Return final stats
      [{:collections_inserted, collections_inserted}] =
        :ets.lookup(stats_ref, :collections_inserted)

      [{:fields_inserted, fields_inserted}] = :ets.lookup(stats_ref, :fields_inserted)
      [{:errors, errors}] = :ets.lookup(stats_ref, :errors)
      [{:skipped, skipped}] = :ets.lookup(stats_ref, :skipped)

      IO.puts("✅ File processed:")
      IO.puts("  - Collections: #{collections_inserted}")
      IO.puts("  - Fields: #{fields_inserted}")
      IO.puts("  - Skipped: #{skipped}")
      IO.puts("  - Errors: #{errors}")

      %{inserted: collections_inserted, skipped: skipped, errors: errors}
    after
      :ets.delete(stats_ref)
    end
  end

  # Process a batch of bibliography data with single transaction
  defp process_biblio_batch(batch, stats_ref) do
    {collections, all_fields, _line_nums} =
      batch
      |> Enum.reduce({[], [], []}, fn {collection, fields, line_num}, {colls, all_flds, lines} ->
        {[collection | colls], all_flds ++ fields, [line_num | lines]}
      end)

    # Batch insert collections
    collections_inserted =
      if length(collections) > 0 do
        try do
          {count, _} =
            Repo.insert_all(Collection, Enum.reverse(collections),
              on_conflict: :nothing,
              returning: false
            )

          :ets.update_counter(stats_ref, :collections_inserted, count)
          count
        rescue
          e ->
            IO.puts("\n⚠️ Collection batch insert error: #{inspect(e)}")
            :ets.update_counter(stats_ref, :errors, length(collections))
            0
        end
      else
        0
      end

    # Batch insert fields
    if length(all_fields) > 0 and collections_inserted > 0 do
      try do
        {fields_count, _} =
          Repo.insert_all(CollectionField, all_fields, on_conflict: :nothing, returning: false)

        :ets.update_counter(stats_ref, :fields_inserted, fields_count)
      rescue
        e ->
          IO.puts("\n⚠️ Fields batch insert error: #{inspect(e)}")
          :ets.update_counter(stats_ref, :errors, length(all_fields))
      end
    end

    # Progress indicator
    if rem(collections_inserted, 100) == 0 and collections_inserted > 0 do
      IO.write(".")
    end
  end

  # Prepare bibliography data using cached mappings (optimized version)
  defp prepare_biblio_data(
         row,
         unit_id,
         skip_images,
         unit_author_mappings,
         unit_publisher_mappings,
         unit_author_data,
         cache
       ) do
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
        image,
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

        # Check if already exists using cache
        if MapSet.member?(cache.existing_collections, biblio_id_int) do
          {:skip, "Collection with biblio_id #{biblio_id_int} already exists"}
        else
          now = DateTime.utc_now() |> DateTime.truncate(:second)

          # Generate UUID for collection
          id = Ecto.UUID.generate()

          # Get primary creator using cached data
          creator_id =
            get_primary_creator_id_cached(
              biblio_id_int,
              unit_author_data,
              unit_author_mappings,
              cache.creators
            )

          # Get publisher name using cached mappings
          publisher_name = get_publisher_name_cached(publisher_id, unit_publisher_mappings)

          # Defer image processing for better performance
          thumbnail_path =
            if skip_images do
              nil
            else
              # Debug: Print what we got in the image column
              if image && String.trim(image) != "" do
                IO.puts("🖼️ Processing image: '#{image}' for biblio_id: #{biblio_id}")
              end

              # Store image URL for batch processing later, or process immediately for small batches
              case download_image_optimized(image, unit_id) do
                {:ok, path} -> path
                _ -> nil
              end
            end

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
            # Use the cached Bibliographic Resource type ID
            type_id: cache.bibliographic_resource_type_id,
            unit_id: unit_id,
            inserted_at: now,
            updated_at: now
          }

          # Build collection fields
          fields = build_collection_fields_optimized(id, row, publisher_name, now)

          {:ok, {collection, fields}}
        end

      _ ->
        {:skip, "Invalid row format"}
    end
  rescue
    e ->
      {:error, "Exception: #{Exception.message(e)}"}
  end

  # Optimized field building - same logic but cleaner
  defp build_collection_fields_optimized(collection_id, row, publisher_name, now) do
    [
      _biblio_id,
      _gmd_id,
      title,
      sor,
      edition,
      isbn_issn,
      # We use resolved publisher_name
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
        value when value != nil and value != "" ->
          trimmed_value = String.trim(value)

          if trimmed_value != "" do
            field = %{
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

  # Cached version of creator lookup
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

  # Cached version of publisher name lookup
  defp get_publisher_name_cached(publisher_id, unit_publisher_mappings) do
    case parse_int(publisher_id) do
      nil -> nil
      id -> Map.get(unit_publisher_mappings, id)
    end
  end

  # Optimized image download with better error handling
  defp download_image_optimized(image_url, _unit_id) when image_url in [nil, ""],
    do: {:error, "No image URL"}

  defp download_image_optimized(image_url, unit_id) do
    # For now, defer to original implementation but could be optimized further
    # with connection pooling, parallel downloads, etc.
    download_image(image_url, unit_id)
  end

  # Helper function to get primary creator name from cached data
  defp get_primary_creator_name(biblio_id, unit_author_data, unit_author_mappings) do
    case Map.get(unit_author_data, biblio_id) do
      nil ->
        nil

      authors when is_list(authors) ->
        # Authors is a list of {author_id, level} tuples sorted by level
        case List.first(authors) do
          nil -> nil
          {author_id, _level} -> Map.get(unit_author_mappings, author_id)
        end

      # Handle case where it's a single author_id (shouldn't happen with current data structure)
      author_id when is_integer(author_id) ->
        Map.get(unit_author_mappings, author_id)

      # Handle any other format
      _ ->
        nil
    end
  end

  # Legacy file processing method (kept for comparison/fallback)
  defp process_biblio_file_legacy(
         file_path,
         batch_size,
         skip_images,
         author_mappings,
         publisher_mappings
       ) do
    unit_id = extract_unit_id_from_filename(file_path)
    IO.puts("📋 Processing unit ID: #{unit_id || "unknown"}")

    # Load specific author data for this unit
    unit_author_data = load_unit_author_data(unit_id)

    collections = []
    fields = []
    errors = 0

    {final_collections, final_fields, final_errors} =
      File.stream!(file_path)
      |> CSVParser.parse_stream(skip_headers: false)
      |> Stream.drop(1)
      |> Stream.with_index(1)
      |> Enum.reduce({collections, fields, errors}, fn {row, line_num}, {colls, flds, errs} ->
        case process_biblio_row(
               row,
               unit_id,
               skip_images,
               author_mappings,
               publisher_mappings,
               unit_author_data
             ) do
          {:ok, {coll, coll_fields}} ->
            {[coll | colls], flds ++ coll_fields, errs}

          {:error, reason} ->
            if rem(line_num, 1000) == 0 do
              IO.puts("⚠️ Error on line #{line_num}: #{reason}")
            end

            {colls, flds, errs + 1}

          :skip ->
            {colls, flds, errs}
        end
      end)

    # Insert in batches
    collections_inserted =
      if length(final_collections) > 0 do
        batch_insert(Repo, Collection, Enum.reverse(final_collections), batch_size,
          on_conflict: :nothing
        )
      else
        0
      end

    fields_inserted =
      if length(final_fields) > 0 do
        batch_insert(Repo, CollectionField, final_fields, batch_size, on_conflict: :nothing)
      else
        0
      end

    IO.puts("✅ File processed:")
    IO.puts("  - Collections: #{collections_inserted}")
    IO.puts("  - Fields: #{fields_inserted}")
    IO.puts("  - Errors: #{final_errors}")

    %{inserted: collections_inserted, skipped: 0, errors: final_errors}
  end

  defp process_biblio_row(
         row,
         unit_id,
         skip_images,
         author_mappings,
         publisher_mappings,
         unit_author_data
       ) do
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
        image,
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
        now = DateTime.utc_now() |> DateTime.truncate(:second)
        biblio_id_int = parse_int(biblio_id)

        # Generate UUID for collection
        id = Ecto.UUID.generate()

        # Get primary creator
        creator_id = get_primary_creator_id(biblio_id_int, unit_author_data, author_mappings)

        # Get publisher name
        publisher_name = get_publisher_name(publisher_id, publisher_mappings)

        # Handle image download
        thumbnail_path =
          if skip_images do
            nil
          else
            # Debug: Print what we got in the image column
            if image && String.trim(image) != "" do
              IO.puts("🖼️ Processing image: '#{image}' for biblio_id: #{biblio_id}")
            end

            case download_image(image, unit_id) do
              {:ok, path} -> path
            end
          end

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
          # All biblio records are books (type_id: 40)
          type_id: 40,
          unit_id: unit_id,
          inserted_at: now,
          updated_at: now
        }

        # Build collection fields
        fields = build_collection_fields(id, row, publisher_name, now)

        {:ok, {collection, fields}}

      _ ->
        # Skip malformed rows
        :skip
    end
  rescue
    e ->
      {:error, "Exception: #{Exception.message(e)}"}
  end

  defp build_collection_fields(collection_id, row, publisher_name, now) do
    [
      _biblio_id,
      _gmd_id,
      title,
      sor,
      edition,
      isbn_issn,
      # We use resolved publisher_name
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

    Enum.with_index(@property_map)
    |> Enum.reduce([], fn {{field_name, property}, index}, acc ->
      value = Map.get(field_values, field_name)

      if value && String.trim(value) != "" do
        field = %{
          collection_id: collection_id,
          property_id: property.id,
          name: property.local_name,
          label: property.label,
          value: String.trim(value),
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
    end)
  end

  defp load_all_author_mappings do
    IO.puts("📋 Loading author mappings...")

    files = get_specific_files("mst", "mst_author_*.csv")

    files
    |> Enum.reduce(%{}, fn file, acc ->
      unit_id = extract_unit_id_from_filename(file)
      authors = load_authors_from_file(file)
      Map.put(acc, unit_id, authors)
    end)
  end

  defp load_all_publisher_mappings do
    IO.puts("🏢 Loading publisher mappings...")

    files = get_specific_files("mst", "mst_publisher_*.csv")

    files
    |> Enum.reduce(%{}, fn file, acc ->
      unit_id = extract_unit_id_from_filename(file)
      publishers = load_publishers_from_file(file)
      Map.put(acc, unit_id, publishers)
    end)
  end

  defp load_unit_author_data(unit_id) do
    # Load biblio-author relations for specific unit
    # First try the biblio directory (primary location)
    biblio_author_file = Path.join("scripts/csv_data/biblio", "biblio_author_#{unit_id}.csv")

    if File.exists?(biblio_author_file) do
      load_biblio_author_relations(biblio_author_file)
    else
      # Fallback to mst directory (legacy location)
      biblio_author_file_mst = Path.join("scripts/csv_data/mst", "biblio_author_#{unit_id}.csv")

      if File.exists?(biblio_author_file_mst) do
        load_biblio_author_relations(biblio_author_file_mst)
      else
        IO.puts("⚠️ No biblio-author file found for unit #{unit_id}")
        %{}
      end
    end
  end

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

  defp load_biblio_author_relations(file_path) do
    File.stream!(file_path)
    |> CSVParser.parse_stream()
    |> Stream.drop(1)
    |> Enum.reduce(%{}, fn [biblio_id, author_id, level], acc ->
      biblio_id_int = parse_int(biblio_id)
      author_id_int = parse_int(author_id)
      level_int = parse_int(level)

      if biblio_id_int && author_id_int && level_int do
        current_authors = Map.get(acc, biblio_id_int, [])

        updated_authors =
          [{author_id_int, level_int} | current_authors]
          # Sort by level
          |> Enum.sort_by(&elem(&1, 1))

        Map.put(acc, biblio_id_int, updated_authors)
      else
        acc
      end
    end)
  end

  defp get_primary_creator_id(biblio_id, unit_author_data, author_mappings) do
    case Map.get(unit_author_data, biblio_id) do
      [{author_id, _level} | _rest] ->
        # Get the author name from the author mapping
        author_name = get_author_name_by_id(author_id, author_mappings)

        if author_name do
          # Find creator in database by name
          case Repo.get_by(Creator, creator_name: author_name) do
            nil -> nil
            creator -> creator.id
          end
        else
          nil
        end

      _ ->
        nil
    end
  end

  defp get_author_name_by_id(author_id, author_mappings) do
    author_mappings
    |> Enum.find_value(fn {_unit_id, authors} ->
      Map.get(authors, author_id)
    end)
  end

  defp get_publisher_name(publisher_id, _publisher_mappings) when publisher_id in [nil, ""],
    do: nil

  defp get_publisher_name(publisher_id, publisher_mappings) do
    publisher_id_int = parse_int(publisher_id)

    if publisher_id_int do
      publisher_mappings
      |> Enum.find_value(fn {_unit_id, publishers} ->
        Map.get(publishers, publisher_id_int)
      end)
    else
      nil
    end
  end

  defp ensure_upload_dir do
    upload_dir = Path.join([:code.priv_dir(:voile), "static", "uploads", "old_thumbnail"])
    File.mkdir_p!(upload_dir)
  end

  defp download_image(image_path, _unit_id) when image_path in [nil, "", "\"\""], do: {:ok, nil}

  defp download_image(image_path, unit_id) do
    # Clean up the image path
    cleaned_path = String.trim(image_path)

    if cleaned_path == "" do
      {:ok, nil}
    else
      try do
        # Generate unique filename using biblio_id-based approach for better organization
        file_extension = Path.extname(cleaned_path) |> String.downcase()

        # Default to .jpg if no extension
        file_extension = if file_extension == "", do: ".jpg", else: file_extension

        # Extract original filename for better organization (remove directory path)
        original_filename = Path.basename(cleaned_path, Path.extname(cleaned_path))

        # Create hash-based filename for uniqueness and collision avoidance
        content_hash =
          :crypto.hash(:sha256, cleaned_path) |> Base.encode16() |> String.slice(0, 16)

        filename = "#{original_filename}_#{content_hash}#{file_extension}"

        # Create unit-based directory structure instead of hash-based
        upload_base_dir =
          Path.join([:code.priv_dir(:voile), "static", "uploads", "old_thumbnail"])

        upload_dir =
          if unit_id do
            Path.join(upload_base_dir, to_string(unit_id))
          else
            # Fallback to hash-based if no unit_id
            shard = String.slice(content_hash, 0, 2)
            Path.join(upload_base_dir, shard)
          end

        # Ensure the unit directory exists
        File.mkdir_p!(upload_dir)

        file_path = Path.join(upload_dir, filename)

        # Try to download the image
        case download_from_url(cleaned_path, file_path) do
          :ok ->
            # Return absolute path for storage in database (includes unit_id directory)
            absolute_path =
              if unit_id do
                "/" <> Path.join(["uploads", "old_thumbnail", to_string(unit_id), filename])
              else
                shard = String.slice(content_hash, 0, 2)
                "/" <> Path.join(["uploads", "old_thumbnail", shard, filename])
              end

            {:ok, absolute_path}

          {:error, reason} ->
            IO.puts("⚠️ Failed to download image from #{cleaned_path}: #{reason}")
            {:ok, nil}
        end
      rescue
        e ->
          IO.puts("⚠️ Exception downloading image from #{cleaned_path}: #{Exception.message(e)}")
          {:ok, nil}
      end
    end
  end

  # Download image from URL or copy from local path
  defp download_from_url(url_or_path, destination) do
    cond do
      # Handle HTTP/HTTPS URLs
      String.starts_with?(url_or_path, "http://") or String.starts_with?(url_or_path, "https://") ->
        download_from_http(url_or_path, destination)

      # Handle local file paths (relative to some base directory)
      File.exists?(url_or_path) ->
        case File.cp(url_or_path, destination) do
          :ok -> :ok
          {:error, reason} -> {:error, "Failed to copy local file: #{reason}"}
        end

      # Try to resolve relative paths (common in SLiMS) - construct full URL
      true ->
        # Construct the full URL for UNPAD library images
        base_url = "https://lib.unpad.ac.id/images/docs/"
        full_url = base_url <> url_or_path

        IO.puts("📁 Trying to download from: #{full_url}")
        download_from_http(full_url, destination)
    end
  end

  # Download image from HTTP URL
  defp download_from_http(url, destination) do
    # Use Req for HTTP downloads
    case Req.get(url, connect_options: [timeout: 30_000], receive_timeout: 30_000) do
      {:ok, %Req.Response{status: 200, body: body}} ->
        case File.write(destination, body) do
          :ok -> :ok
          {:error, reason} -> {:error, "Failed to write file: #{reason}"}
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
end
