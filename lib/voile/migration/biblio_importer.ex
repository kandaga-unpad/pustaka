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
  alias Voile.Schema.System.Node
  alias Voile.Schema.Metadata.ResourceClass

  # Cache for frequently accessed data
  @type cache :: %{
          author_mappings: map(),
          publisher_mappings: map(),
          creators: map(),
          existing_collections: MapSet.t(),
          unit_map: map(),
          resource_class_map: map()
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

    # Get bibliography files - ONLY biblio_*.csv, NOT biblio_author_*.csv
    files = get_specific_files("biblio", "biblio_[0-9]*.csv")

    if Enum.empty?(files) do
      IO.puts("⚠️ No bibliography files found")
      %{inserted: 0, skipped: 0, errors: 0}
    else
      # Track problematic units
      problematic_units = []

      {stats, problematic_units} =
        files
        |> Stream.with_index(1)
        |> Enum.reduce({%{inserted: 0, skipped: 0, errors: 0}, problematic_units}, fn {file,
                                                                                       index},
                                                                                      {acc,
                                                                                       prob_units} ->
          IO.puts(
            "\n🔄 Processing bibliography file #{index}/#{length(files)}: #{Path.basename(file)}"
          )

          file_stats = process_biblio_file_optimized(file, batch_size, skip_images, cache)

          new_acc = %{
            inserted: acc.inserted + file_stats.inserted,
            skipped: acc.skipped + file_stats.skipped,
            errors: acc.errors + file_stats.errors
          }

          # Track units with high skip rates
          new_prob_units =
            if file_stats.skipped > 100 do
              [{file_stats.unit_id, file_stats.skipped, Path.basename(file)} | prob_units]
            else
              prob_units
            end

          {new_acc, new_prob_units}
        end)

      print_summary("BIBLIOGRAPHY IMPORT", %{
        "Total Collections Inserted" => stats.inserted,
        "Total Collections Skipped" => stats.skipped,
        "Total Errors" => stats.errors
      })

      # Show problematic units
      if length(problematic_units) > 0 do
        IO.puts("\n⚠️ Units with high skip rates:")

        problematic_units
        |> Enum.reverse()
        |> Enum.each(fn {unit_id, skip_count, filename} ->
          IO.puts("  - Unit #{unit_id} (#{filename}): #{skip_count} rows skipped")
        end)
      end

      stats
    end
  end

  # Legacy method for backward compatibility
  def import_all_legacy(batch_size \\ 500, skip_images \\ false) do
    IO.puts("📚 Starting bibliography data import (legacy mode)...")

    # Ensure upload directory exists
    ensure_upload_dir()

    # Get bibliography files - ONLY biblio_*.csv, NOT biblio_author_*.csv
    files = get_specific_files("biblio", "biblio_[0-9]*.csv")

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

    # Cache existing collections to avoid duplicates - use composite key (unit_id, old_biblio_id)
    existing_collections =
      from(c in Collection,
        select: {c.unit_id, c.old_biblio_id},
        where: not is_nil(c.old_biblio_id)
      )
      |> Repo.all()
      |> MapSet.new()

    # Cache units for collection code generation
    unit_map = build_unit_map()

    # Cache resource classes for collection code generation
    resource_class_map = build_resource_class_map()

    # Cache the Bibliographic Resource type ID
    bibliographic_resource_type_id = get_bibliographic_resource_type_id()
    thesis_resource_type_id = get_thesis_resource_type_id()

    IO.puts("✅ Cache initialized:")
    IO.puts("  - Author mappings: #{map_size(author_mappings)} units")
    IO.puts("  - Publisher mappings: #{map_size(publisher_mappings)} units")
    IO.puts("  - Creators: #{map_size(creators)}")
    IO.puts("  - Existing collections: #{MapSet.size(existing_collections)}")
    IO.puts("  - Units: #{map_size(unit_map)}")
    IO.puts("  - Resource classes: #{map_size(resource_class_map)}")
    IO.puts("  - Bibliographic Resource type ID: #{bibliographic_resource_type_id}")
    IO.puts("  - Thesis Resource type ID: #{thesis_resource_type_id}")

    %{
      author_mappings: author_mappings,
      publisher_mappings: publisher_mappings,
      creators: creators,
      existing_collections: existing_collections,
      unit_map: unit_map,
      resource_class_map: resource_class_map,
      bibliographic_resource_type_id: bibliographic_resource_type_id,
      thesis_resource_type_id: thesis_resource_type_id
    }
  end

  # Get the default bibliographic resource type ID (Book)
  # Note: Thesis records are detected separately based on title keywords
  defp get_bibliographic_resource_type_id do
    # Prefer the ResourceClass representing an actual Book label if available.
    # Lookup order:
    # 1) label == "Book"
    # 2) local_name == "Book"
    # 3) glam_type == "Library"
    # 4) fallback to 40

    case Repo.one(from(rc in ResourceClass, where: rc.label == "Book", select: rc.id)) do
      id when is_integer(id) ->
        IO.puts("✅ Using ResourceClass (label='Book') id=#{id} for bibliographic resources")
        id

      _ ->
        case Repo.one(from(rc in ResourceClass, where: rc.local_name == "Book", select: rc.id)) do
          id when is_integer(id) ->
            IO.puts(
              "✅ Using ResourceClass (local_name='Book') id=#{id} for bibliographic resources"
            )

            id

          _ ->
            case Repo.one(
                   from(rc in ResourceClass, where: rc.glam_type == "Library", select: rc.id)
                 ) do
              id when is_integer(id) ->
                IO.puts(
                  "⚠️ Using ResourceClass with glam_type='Library' id=#{id} for bibliographic resources (label 'Book' not found)"
                )

                id

              _ ->
                IO.puts(
                  "⚠️ Could not find ResourceClass for 'Book' or glam_type='Library'; falling back to id 40"
                )

                40
            end
        end
    end
  end

  # Get Thesis resource type ID
  defp get_thesis_resource_type_id do
    # Lookup order:
    # 1) label == "Thesis"
    # 2) local_name == "Thesis"
    # 3) fallback to nil (will use book type as fallback)

    case Repo.one(from(rc in ResourceClass, where: rc.label == "Thesis", select: rc.id)) do
      id when is_integer(id) ->
        IO.puts("✅ Using ResourceClass (label='Thesis') id=#{id} for thesis records")
        id

      _ ->
        case Repo.one(from(rc in ResourceClass, where: rc.local_name == "Thesis", select: rc.id)) do
          id when is_integer(id) ->
            IO.puts("✅ Using ResourceClass (local_name='Thesis') id=#{id} for thesis records")

            id

          _ ->
            IO.puts("⚠️ Could not find ResourceClass for 'Thesis'; will use Book type as fallback")

            nil
        end
    end
  end

  # Detect if a title indicates a thesis based on keywords
  # Handles variations like: SKRIPSI, [SKRIPSI], [ TESIS ], etc.
  defp is_thesis_title?(title) when is_binary(title) do
    # Remove common delimiters and extra spaces, then check for keywords
    cleaned_title =
      title
      |> String.upcase()
      # Replace brackets with spaces
      |> String.replace(~r/[\[\]\(\)\{\}]/, " ")
      # Normalize multiple spaces
      |> String.replace(~r/\s+/, " ")
      |> String.trim()

    # Check if any thesis keyword appears as a word (not just substring)
    String.match?(cleaned_title, ~r/\b(SKRIPSI|TESIS|DISERTASI)\b/)
  end

  defp is_thesis_title?(_), do: false

  # Optimized file processing using streams and batching
  defp process_biblio_file_optimized(file_path, batch_size, skip_images, cache) do
    unit_id = extract_unit_id_from_filename(file_path)
    filename = Path.basename(file_path)
    IO.puts("📋 Processing unit ID: #{unit_id || "unknown"} (#{filename})")

    # Load specific author data for this unit from cache
    unit_author_mappings = Map.get(cache.author_mappings, unit_id, %{})
    unit_publisher_mappings = Map.get(cache.publisher_mappings, unit_id, %{})
    unit_author_data = load_unit_author_data(unit_id)

    stats_ref = :ets.new(:biblio_import_stats, [:set, :public])
    :ets.insert(stats_ref, {:collections_inserted, 0})
    :ets.insert(stats_ref, {:fields_inserted, 0})
    :ets.insert(stats_ref, {:errors, 0})
    :ets.insert(stats_ref, {:skipped, 0})

    # Track first few skipped rows for debugging
    :ets.insert(stats_ref, {:sample_skipped, []})

    try do
      File.stream!(file_path)
      |> CSVParser.parse_stream(skip_headers: false)
      |> Stream.drop(1)
      |> Stream.with_index(1)
      |> Stream.map(fn {row, line_num} ->
        case prepare_biblio_data(
               row,
               unit_id,
               skip_images,
               unit_author_mappings,
               unit_publisher_mappings,
               unit_author_data,
               cache
             ) do
          {:ok, {collection, fields}} ->
            {{:ok, {collection, fields}}, line_num}

          {:skip, reason} ->
            # Only print first 10 skipped rows to avoid spam
            skip_count = :ets.update_counter(stats_ref, :skipped, 1)

            if skip_count <= 10 do
              IO.puts(
                "⚠️ [Unit #{unit_id}] Skipping line #{line_num}: #{inspect(reason)} | Row columns: #{length(row)}"
              )

              # Store sample for summary
              [{:sample_skipped, samples}] = :ets.lookup(stats_ref, :sample_skipped)

              :ets.insert(
                stats_ref,
                {:sample_skipped, [{line_num, reason, length(row)} | samples]}
              )
            else
              # After 10, only log every 1000th skip for monitoring
              if rem(skip_count, 1000) == 0 do
                IO.puts("⚠️ [Unit #{unit_id}] #{skip_count} rows skipped so far...")
              end
            end

            {{:skip, reason}, line_num}

          {:error, reason} ->
            IO.puts("❌ [Unit #{unit_id}] Error on line #{line_num}: #{inspect(reason)}")
            :ets.update_counter(stats_ref, :errors, 1)
            {{:error, reason}, line_num}
        end
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
      [{:sample_skipped, sample_skipped}] = :ets.lookup(stats_ref, :sample_skipped)

      IO.puts("\n✅ File processed: #{filename}")
      IO.puts("  - Unit ID: #{unit_id}")
      IO.puts("  - Collections: #{collections_inserted}")
      IO.puts("  - Fields: #{fields_inserted}")
      IO.puts("  - Skipped: #{skipped}")
      IO.puts("  - Errors: #{errors}")

      if skipped > 10 and length(sample_skipped) > 0 do
        IO.puts("\n📊 Sample of skipped rows (first 10):")

        sample_skipped
        |> Enum.reverse()
        |> Enum.each(fn {line, reason, col_count} ->
          IO.puts("  Line #{line}: #{inspect(reason)} (#{col_count} columns)")
        end)
      end

      %{inserted: collections_inserted, skipped: skipped, errors: errors, unit_id: unit_id}
    after
      :ets.delete(stats_ref)
    end
  end

  # Process a batch of bibliography data with single transaction
  defp process_biblio_batch(batch, stats_ref) do
    {collections, all_fields, line_nums} =
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
            sample_old_ids = collections |> Enum.take(5) |> Enum.map(& &1.old_biblio_id)
            sample_lines = Enum.take(line_nums, 5)
            IO.puts("\n⚠️ Collection batch insert error: #{inspect(e)}")
            IO.puts("  - Sample old_biblio_ids: #{inspect(sample_old_ids)}")
            IO.puts("  - Sample lines: #{inspect(sample_lines)}")
            :ets.update_counter(stats_ref, :errors, length(collections))
            0
        end
      else
        0
      end

    # Batch insert fields: remap temporary collection ids (source_old_biblio_id) to actual DB ids
    if length(all_fields) > 0 do
      # Collect all unique old_biblio_ids referenced by fields (available to rescue block)
      old_ids =
        all_fields
        |> Enum.map(& &1.source_old_biblio_id)
        |> Enum.uniq()
        |> Enum.filter(& &1)

      try do
        # Query DB for collections inserted (or existing) with those old_biblio_ids
        mapping_query =
          from(c in Collection,
            where: c.old_biblio_id in ^old_ids,
            select: {c.old_biblio_id, c.id}
          )

        db_mappings = Repo.all(mapping_query) |> Enum.into(%{})

        # Remap fields' collection_id from the temporary marker to the real DB id
        remapped_fields =
          Enum.reduce(all_fields, [], fn field, acc ->
            case Map.get(field, :source_old_biblio_id) || Map.get(field, "source_old_biblio_id") do
              nil ->
                [field | acc]

              old_biblio ->
                case Map.get(db_mappings, old_biblio) do
                  nil ->
                    # If we couldn't find the collection in DB, skip the field and count as error
                    prop = Map.get(field, :property_id) || Map.get(field, "property_id")
                    name = Map.get(field, :name) || Map.get(field, "name")

                    IO.puts(
                      "\n⚠️ Skipping field for missing collection old_biblio_id=#{inspect(old_biblio)} - property_id=#{inspect(prop)} name=#{inspect(name)}"
                    )

                    :ets.update_counter(stats_ref, :errors, 1)
                    acc

                  real_id ->
                    # Replace collection_id and remove temporary marker
                    cleaned_field =
                      field
                      |> Map.put(:collection_id, real_id)
                      |> Map.delete(:source_old_biblio_id)

                    [cleaned_field | acc]
                end
            end
          end)

        remapped_fields = Enum.reverse(remapped_fields)

        if length(remapped_fields) > 0 and (collections_inserted > 0 or length(old_ids) > 0) do
          {fields_count, _} =
            Repo.insert_all(CollectionField, remapped_fields,
              on_conflict: :nothing,
              returning: false
            )

          :ets.update_counter(stats_ref, :fields_inserted, fields_count)
        end
      rescue
        e ->
          sample_old_ids = Enum.take(old_ids, 5)

          sample_props =
            all_fields
            |> Enum.take(5)
            |> Enum.map(fn f ->
              {Map.get(f, :property_id) || Map.get(f, "property_id"),
               Map.get(f, :name) || Map.get(f, "name")}
            end)

          IO.puts("\n⚠️ Fields batch insert error: #{inspect(e)}")

          IO.puts(
            "  - All_fields: #{length(all_fields)}; sample_old_biblio_ids: #{inspect(sample_old_ids)}; sample_props: #{inspect(sample_props)}"
          )

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

        # Check if already exists using cache with composite key (unit_id, old_biblio_id)
        if MapSet.member?(cache.existing_collections, {unit_id, biblio_id_int}) do
          {:skip, "Collection with unit_id #{unit_id}, biblio_id #{biblio_id_int} already exists"}
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

          # Get unit and resource class data for collection code generation
          unit_data = Map.get(cache.unit_map, unit_id, %{abbr: "UNK"})

          # Determine resource type based on title
          resource_type_id =
            if is_thesis_title?(title) and cache.thesis_resource_type_id do
              cache.thesis_resource_type_id
            else
              cache.bibliographic_resource_type_id
            end

          resource_class_data =
            Map.get(cache.resource_class_map, resource_type_id, %{
              glam_type: "Library"
            })

          # Generate collection code using similar logic as FormCollectionHelper
          collection_code =
            generate_collection_code(
              unit_data.abbr,
              String.slice(resource_class_data.glam_type, 0, 3) |> String.upcase()
            )

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
            # Use the determined resource type ID (Book or Thesis)
            type_id: resource_type_id,
            unit_id: unit_id,
            inserted_at: now,
            updated_at: now
          }

          # Build collection fields (include original biblio id for later remapping)
          fields = build_collection_fields_optimized(id, row, publisher_name, now, biblio_id_int)

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
  defp build_collection_fields_optimized(collection_id, row, publisher_name, now, old_biblio_id) do
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
              # temporary marker to remap to actual DB id after collection insert
              source_old_biblio_id: old_biblio_id,
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

    # Remap legacy fields to actual DB collection ids using old_biblio_id
    fields_inserted =
      if length(final_fields) > 0 do
        old_ids =
          final_fields |> Enum.map(& &1.source_old_biblio_id) |> Enum.uniq() |> Enum.filter(& &1)

        db_mappings =
          if length(old_ids) > 0 do
            from(c in Collection,
              where: c.old_biblio_id in ^old_ids,
              select: {c.old_biblio_id, c.id}
            )
            |> Repo.all()
            |> Enum.into(%{})
          else
            %{}
          end

        remapped_fields =
          Enum.reduce(final_fields, [], fn field, acc ->
            case Map.get(field, :source_old_biblio_id) || Map.get(field, "source_old_biblio_id") do
              nil ->
                [field | acc]

              old_biblio ->
                case Map.get(db_mappings, old_biblio) do
                  nil ->
                    prop = Map.get(field, :property_id) || Map.get(field, "property_id")
                    name = Map.get(field, :name) || Map.get(field, "name")

                    IO.puts(
                      "⚠️ Skipping legacy field for missing collection old_biblio_id=#{inspect(old_biblio)} - property_id=#{inspect(prop)} name=#{inspect(name)}"
                    )

                    acc

                  real_id ->
                    cleaned_field =
                      field
                      |> Map.put(:collection_id, real_id)
                      |> Map.delete(:source_old_biblio_id)

                    [cleaned_field | acc]
                end
            end
          end)

        remapped_fields = Enum.reverse(remapped_fields)

        if length(remapped_fields) > 0 do
          batch_insert(Repo, CollectionField, remapped_fields, batch_size, on_conflict: :nothing)
        else
          0
        end
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
          collection_code: generate_collection_code("UNK", "LIB"),
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
    |> Enum.reduce(%{}, fn row, acc ->
      # Accept rows with at least three columns; ignore extra columns
      case row do
        [biblio_id, author_id, level | _rest] ->
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
            # Skip malformed numeric fields
            acc
          end

        # If the row doesn't have at least 3 columns, skip and log minimal info
        other ->
          IO.puts("⚠️ Skipping malformed biblio-author row: #{inspect(other)}")
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
    # No longer needed - Storage module handles directory creation
    :ok
  end

  defp download_image(image_path, _unit_id) when image_path in [nil, "", "\"\""], do: {:ok, nil}

  defp download_image(image_path, unit_id) do
    # Clean up the image path
    cleaned_path = String.trim(image_path)

    if cleaned_path == "" do
      {:ok, nil}
    else
      try do
        # Determine file extension
        file_extension = Path.extname(cleaned_path) |> String.downcase()
        file_extension = if file_extension == "", do: ".jpg", else: file_extension

        # Extract original filename for better organization
        original_filename = Path.basename(cleaned_path, Path.extname(cleaned_path))

        # Download to temporary file first
        case download_to_temp_file(cleaned_path, original_filename, file_extension) do
          {:ok, temp_path, content_type} ->
            # Create filename for the upload (Storage will generate unique name)
            temp_filename = "#{original_filename}#{file_extension}"

            # Create Plug.Upload struct
            upload = %Plug.Upload{
              path: temp_path,
              filename: temp_filename,
              content_type: content_type
            }

            # Upload using Storage module with old_thumbnail folder
            case Client.Storage.upload(upload,
                   folder: "old_thumbnail",
                   unit_id: unit_id,
                   generate_filename: true,
                   preserve_extension: true
                 ) do
              {:ok, file_url} ->
                # Clean up temp file
                File.rm(temp_path)
                {:ok, file_url}

              {:error, reason} ->
                # Clean up temp file
                File.rm(temp_path)
                IO.puts("⚠️ Failed to upload image from #{cleaned_path}: #{reason}")
                {:ok, nil}
            end

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

  # Download image to temporary file and return path with content type
  defp download_to_temp_file(url_or_path, _original_filename, file_extension) do
    # Create temporary file
    temp_dir = System.tmp_dir!()
    temp_filename = "biblio_import_#{System.unique_integer([:positive])}#{file_extension}"
    temp_path = Path.join(temp_dir, temp_filename)

    cond do
      # Handle HTTP/HTTPS URLs
      String.starts_with?(url_or_path, "http://") or String.starts_with?(url_or_path, "https://") ->
        case download_from_http(url_or_path, temp_path) do
          {:ok, content_type} -> {:ok, temp_path, content_type}
          {:error, reason} -> {:error, reason}
        end

      # Handle local file paths (relative to some base directory)
      File.exists?(url_or_path) ->
        case File.cp(url_or_path, temp_path) do
          :ok ->
            content_type = get_content_type_from_extension(file_extension)
            {:ok, temp_path, content_type}

          {:error, reason} ->
            {:error, "Failed to copy local file: #{reason}"}
        end

      # Try to resolve relative paths (common in SLiMS) - construct full URL
      true ->
        # Construct the full URL for UNPAD library images
        base_url = "https://lib.unpad.ac.id/images/docs/"
        full_url = base_url <> url_or_path

        IO.puts("📁 Trying to download from: #{full_url}")

        case download_from_http(full_url, temp_path) do
          {:ok, content_type} -> {:ok, temp_path, content_type}
          {:error, reason} -> {:error, reason}
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
            {:error, "Failed to write file: #{reason}"}
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
        "image/jpeg"
    end
  end

  # Get content type from file extension
  defp get_content_type_from_extension(extension) do
    case String.downcase(extension) do
      ".jpg" -> "image/jpeg"
      ".jpeg" -> "image/jpeg"
      ".png" -> "image/png"
      ".gif" -> "image/gif"
      ".webp" -> "image/webp"
      ".bmp" -> "image/bmp"
      _ -> "image/jpeg"
    end
  end

  # Build unit mappings for collection code generation
  defp build_unit_map do
    from(n in Node, select: {n.id, %{abbr: n.abbr, name: n.name}})
    |> Repo.all()
    |> Enum.into(%{})
  end

  # Build resource class mappings for collection code generation
  defp build_resource_class_map do
    from(rc in ResourceClass,
      select: {rc.id, %{local_name: rc.local_name, glam_type: rc.glam_type}}
    )
    |> Repo.all()
    |> Enum.into(%{})
  end

  # Generate collection code similar to FormCollectionHelper
  defp generate_collection_code(unit, collection_type) do
    timestamp = :os.system_time(:second)
    random_suffix = :crypto.strong_rand_bytes(3) |> Base.encode16(case: :lower)

    "COLLECTION-#{unit}-#{collection_type}-#{timestamp}-#{random_suffix}"
  end
end
