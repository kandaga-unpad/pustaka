Mix.Task.run("app.start")

NimbleCSV.define(
  CSVParser,
  separator: ",",
  escape: "\"",
  escape_pattern: ~r/\\./
)

import Ecto.Query
alias Voile.Repo
alias Voile.Schema.Catalog.{Collection, CollectionField}
alias Voile.Schema.Master.Creator

property_map = %{
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
  "call_number" => %{id: 193, local_name: "callNumber", label: "Call Number", type_value: "text"},
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

defmodule ImageDownloader do
  @base_url "https://lib.unpad.ac.id/images/docs"
  @old_upload_dir Path.join([
                    :code.priv_dir(:voile),
                    "static",
                    "uploads",
                    "old_thumbnail"
                  ])

  def ensure_upload_dir do
    File.mkdir_p!(@old_upload_dir)
  end

  def download_and_save_image(image_path) when is_binary(image_path) and image_path != "" do
    if image_path in ["", "\"\"", nil] do
      {:ok, nil}
    else
      clean_path = String.trim(image_path, "\"")

      image_url = "#{@base_url}/#{clean_path}"

      ext = Path.extname(clean_path)
      file_name = "#{System.system_time(:second)}-old-thumbnail-#{Ecto.UUID.generate()}#{ext}"
      dest_path = Path.join(@old_upload_dir, file_name)

      case Req.get(image_url, receive_timeout: 30_000, connect_options: [timeout: 30_000]) do
        {:ok, %Req.Response{status: 200, body: body}} ->
          case File.write(dest_path, body) do
            :ok ->
              relative_path = "/uploads/old_thumbnail/#{file_name}"
              IO.puts("✅ Image downloaded and saved: #{image_url} -> #{relative_path}")
              {:ok, relative_path}

            {:error, reason} ->
              IO.puts("❌ Failed to save image: #{image_url} - Reason: #{inspect(reason)}")
              {:ok, nil}
          end

        {:ok, %Req.Response{status: status}} ->
          IO.puts("❌ Failed to download image: #{image_url} - HTTP Status: #{status}")
          {:ok, nil}

        {:error, reason} ->
          IO.puts("❌ Error downloading image: #{image_url} - Reason: #{inspect(reason)}")
          {:ok, nil}
      end
    end
  end

  def download_and_save_image(_), do: {:ok, nil}
end

defmodule AuthorLoader do
  @moduledoc """
  Module for loading and processing author data from CSV files.
  """

  def load_authors_for_unit(unit_id) do
    # Try different possible paths
    possible_paths = [
      "scripts/",
      "",
      "./"
    ]

    {mst_author_file, biblio_author_file} =
      possible_paths
      |> Enum.find_value(fn path ->
        mst_file = Path.join(path, "mst_author_#{unit_id}.csv")
        biblio_file = Path.join(path, "biblio_author_#{unit_id}.csv")

        if File.exists?(mst_file) and File.exists?(biblio_file) do
          {mst_file, biblio_file}
        end
      end) || {"mst_author_#{unit_id}.csv", "biblio_author_#{unit_id}.csv"}

    IO.puts("🔍 Looking for author files:")
    IO.puts("  - #{mst_author_file} (exists: #{File.exists?(mst_author_file)})")
    IO.puts("  - #{biblio_author_file} (exists: #{File.exists?(biblio_author_file)})")

    case {File.exists?(mst_author_file), File.exists?(biblio_author_file)} do
      {true, true} ->
        IO.puts("📚 Loading author data for unit #{unit_id}...")

        # Load master authors
        authors = load_master_authors(mst_author_file)
        IO.puts("📖 Loaded #{map_size(authors)} master authors")

        # Load biblio-author relations
        biblio_authors = load_biblio_authors(biblio_author_file)
        IO.puts("🔗 Loaded #{map_size(biblio_authors)} biblio-author relations")

        # Insert creators and get mapping
        creator_mapping = insert_creators(authors)
        IO.puts("🗂️ Created mapping for #{map_size(creator_mapping)} authors to creators")

        {:ok, {authors, biblio_authors, creator_mapping}}

      {false, false} ->
        IO.puts("⚠️ No author files found for unit #{unit_id}")
        {:ok, {%{}, %{}, %{}}}

      {true, false} ->
        IO.puts("⚠️ Missing biblio_author file for unit #{unit_id}")
        {:ok, {%{}, %{}, %{}}}

      {false, true} ->
        IO.puts("⚠️ Missing mst_author file for unit #{unit_id}")
        {:ok, {%{}, %{}, %{}}}
    end
  end

  defp load_master_authors(file_path) do
    IO.puts("📂 Reading master authors from: #{file_path}")

    authors =
      File.stream!(file_path)
      |> CSVParser.parse_stream()
      |> Enum.with_index(1)
      |> Enum.reduce(%{}, fn {[
                                author_id,
                                author_name,
                                author_year,
                                authority_type,
                                _auth_list,
                                _input_date,
                                _last_update
                              ], line_num},
                             acc ->
        author_id_int = String.to_integer(author_id)

        # Determine creator type based on authority_type and name patterns
        creator_type = determine_creator_type(author_name, authority_type)

        if line_num <= 3 do
          IO.puts(
            "  📋 Line #{line_num}: ID=#{author_id_int}, Name=#{author_name}, Type=#{creator_type}"
          )
        end

        Map.put(acc, author_id_int, %{
          name: String.trim(author_name, "\""),
          year: author_year,
          authority_type: authority_type,
          type: creator_type
        })
      end)

    IO.puts("📊 Total authors loaded: #{map_size(authors)}")
    authors
  end

  defp load_biblio_authors(file_path) do
    IO.puts("📂 Reading biblio-author relations from: #{file_path}")

    biblio_authors =
      File.stream!(file_path)
      |> CSVParser.parse_stream()
      |> Enum.with_index(1)
      |> Enum.reduce(%{}, fn {[biblio_id, author_id, level], line_num}, acc ->
        biblio_id_int = String.to_integer(biblio_id)
        author_id_int = String.to_integer(author_id)
        level_int = String.to_integer(level)

        if line_num <= 3 do
          IO.puts(
            "  📋 Line #{line_num}: Biblio=#{biblio_id_int}, Author=#{author_id_int}, Level=#{level_int}"
          )
        end

        # Group authors by biblio_id, sorted by level (primary author first)
        current_authors = Map.get(acc, biblio_id_int, [])

        updated_authors =
          [{author_id_int, level_int} | current_authors]
          # Sort by level
          |> Enum.sort_by(&elem(&1, 1))

        Map.put(acc, biblio_id_int, updated_authors)
      end)

    IO.puts("📊 Total biblio-author relations loaded: #{map_size(biblio_authors)}")
    biblio_authors
  end

  defp determine_creator_type(name, authority_type) do
    cond do
      # Check for organizational keywords
      Regex.match?(
        ~r/(department|universitas|institut|sekolah|dinas|kementerian|direktorat|badan|lembaga|yayasan|foundation|corp|inc|ltd|company)/i,
        name
      ) ->
        "Organization"

      # Check for conference/event keywords
      Regex.match?(~r/(conference|symposium|seminar|workshop|congress|meeting)/i, name) ->
        "Conference"

      # Check for group keywords
      Regex.match?(~r/(team|group|committee|board|panel)/i, name) ->
        "Group"

      # If authority_type indicates organization
      authority_type in ["c", "o", "org"] ->
        "Organization"

      # Default to Person
      true ->
        "Person"
    end
  end

  defp insert_creators(authors) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    creators_data =
      authors
      |> Enum.map(fn {_author_id, author_data} ->
        %{
          creator_name: author_data.name,
          type: author_data.type,
          creator_contact: nil,
          affiliation: nil,
          inserted_at: now,
          updated_at: now
        }
      end)
      # Remove duplicates by name
      |> Enum.uniq_by(& &1.creator_name)

    # Insert creators and get their IDs
    case creators_data do
      [] ->
        %{}

      _ ->
        IO.puts("👤 Inserting #{length(creators_data)} unique creators in batches...")

        # Insert in batches to avoid PostgreSQL parameter limit
        # Each record has ~6 fields, so batch size of 5000 = ~30,000 parameters (well under 65,535 limit)
        batch_size = 5000

        all_inserted_creators =
          creators_data
          |> Enum.chunk_every(batch_size)
          |> Enum.with_index(1)
          |> Enum.flat_map(fn {batch, batch_num} ->
            IO.puts("  📦 Batch #{batch_num}: Inserting #{length(batch)} creators...")

            {count, inserted_creators} =
              Repo.insert_all(
                Creator.__schema__(:source),
                batch,
                on_conflict: :nothing,
                returning: [:id, :creator_name]
              )

            IO.puts("  ✅ Batch #{batch_num}: Inserted #{count} new creators")
            inserted_creators
          end)

        IO.puts("👤 Total creators processed: #{length(all_inserted_creators)}")

        # Create mapping from creator name to ID
        name_to_creator_id =
          all_inserted_creators
          |> Enum.into(%{}, fn creator -> {creator.creator_name, creator.id} end)

        # Get existing creators that weren't inserted due to conflict
        total_expected = length(creators_data)
        total_inserted = length(all_inserted_creators)

        if total_inserted < total_expected do
          IO.puts("🔍 Looking up #{total_expected - total_inserted} existing creators...")

          existing_names =
            Enum.map(creators_data, & &1.creator_name) -- Map.keys(name_to_creator_id)

          # Also batch the lookup for existing creators
          existing_creators =
            existing_names
            # Smaller batches for WHERE IN queries
            |> Enum.chunk_every(1000)
            |> Enum.flat_map(fn name_batch ->
              from(c in Creator,
                where: c.creator_name in ^name_batch,
                select: [:id, :creator_name]
              )
              |> Repo.all()
            end)

          existing_mapping =
            existing_creators
            |> Enum.into(%{}, fn creator -> {creator.creator_name, creator.id} end)

          name_to_creator_id = Map.merge(name_to_creator_id, existing_mapping)
          IO.puts("📋 Found #{length(existing_creators)} existing creators")
        end

        # Convert from author_id -> creator_id mapping
        authors
        |> Enum.into(%{}, fn {author_id, author_data} ->
          creator_id = Map.get(name_to_creator_id, author_data.name)
          {author_id, creator_id}
        end)
    end
  end
end

defmodule Mapper do
  alias Ecto.UUID

  def to_maps(
        [
          biblio_id,
          _gmd_id,
          title,
          sor,
          edition,
          isbn_issn,
          publisher_id,
          publish_year,
          collation,
          series_title,
          call_number,
          _lang,
          _src,
          _place,
          classification,
          notes,
          image,
          _fa,
          _hide,
          _prom,
          _labels,
          frequency_id,
          spec_detail_info,
          _ct,
          _mt,
          _car,
          _input_date,
          _last_update,
          _uid
        ],
        property_map,
        unit_id,
        {_authors, biblio_authors, creator_mapping}
      ) do
    raw_uuid = UUID.generate()
    {:ok, id} = UUID.dump(raw_uuid)

    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
    biblio_id_int = String.to_integer(biblio_id)

    # Get primary creator for this biblio
    creator_id = get_primary_creator(biblio_id_int, biblio_authors, creator_mapping)

    thumbnail_path =
      case ImageDownloader.download_and_save_image(image) do
        {:ok, path} -> path
        # Fallback for any unexpected cases
        _ -> nil
      end

    # collection row
    coll = %{
      id: id,
      title: title,
      description: notes || nil,
      thumbnail: thumbnail_path,
      status: "published",
      access_level: "public",
      old_biblio_id: biblio_id_int,
      type_id: 40,
      template_id: nil,
      # Now properly set from author data
      creator_id: creator_id,
      unit_id: unit_id,
      inserted_at: now,
      updated_at: now
    }

    # collect only the properties that actually have data
    values = %{
      "sor" => sor,
      "edition" => edition,
      "isbn_issn" => isbn_issn,
      "publisher_id" => publisher_id,
      "publish_year" => publish_year,
      "collation" => collation,
      "series_title" => series_title,
      "call_number" => call_number,
      "classification" => classification,
      "notes" => notes,
      "frequency_id" => frequency_id,
      "spec_detail_info" => spec_detail_info
    }

    # build many collection_fields rows
    fields =
      values
      |> Enum.filter(fn {_col_name, value} ->
        value not in [nil, "", "\"\""]
      end)
      |> Enum.with_index(1)
      |> Enum.flat_map(fn {{col_name, value}, index} ->
        case Map.get(property_map, col_name) do
          nil ->
            []

          prop ->
            gen_uid = UUID.generate()
            {:ok, col_field_id} = UUID.dump(gen_uid)

            [
              %{
                id: col_field_id,
                name: prop.local_name,
                label: prop.label,
                value: to_string(value),
                value_lang: "id",
                type_value: prop.type_value,
                sort_order: index,
                collection_id: id,
                property_id: prop.id,
                inserted_at: now,
                updated_at: now
              }
            ]
        end
      end)

    {coll, fields}
  end

  defp get_primary_creator(biblio_id, biblio_authors, creator_mapping) do
    case Map.get(biblio_authors, biblio_id) do
      nil ->
        IO.puts("🔍 No authors found for biblio_id #{biblio_id}")
        nil

      [] ->
        IO.puts("🔍 Empty authors list for biblio_id #{biblio_id}")
        nil

      [{author_id, _level} | _rest] ->
        # Get the primary author (first in sorted list by level)
        creator_id = Map.get(creator_mapping, author_id)
        IO.puts("🔍 Biblio #{biblio_id} -> Author #{author_id} -> Creator #{creator_id || "nil"}")
        creator_id
    end
  end
end

# Ensure the upload directory exists
ImageDownloader.ensure_upload_dir()

# Function to get all CSV files to process
defmodule CSVProcessor do
  @moduledoc """
  A module for processing CSV files.

  1. Auto-detect pattern (default)
    iex > elixir import_biblio.exs
  2. Single file
    iex > elixir import_biblio.exs --file scripts/biblio_1.csv
  3. Custom pattern
    iex > elixir import_biblio.exs --pattern "scripts/biblio_*_*.csv"
    iex > elixir import_biblio.exs --pattern "/path/to/exports/biblio_[1-9].csv"
  4. Directory processing
    iex > elixir import_biblio.exs --dir data/exports/
    # Processes all CSV files in the directory
  5. Multiple specific files
    iex > elixir import_biblio.exs scripts/biblio_1.csv scripts/biblio_2.csv
  """
  def get_csv_files do
    case System.argv() do
      [] ->
        # No arguments - look for biblio_*_*.csv pattern in scripts/ directory
        pattern = "scripts/biblio_*_*.csv"
        files = Path.wildcard(pattern) |> Enum.sort()

        if Enum.empty?(files) do
          # Fallback to old pattern
          pattern = "scripts/biblio_*.csv"
          files = Path.wildcard(pattern) |> Enum.sort()

          if Enum.empty?(files) do
            IO.puts("📁 No biblio CSV files found, using default: scripts/biblio.csv")
            ["scripts/biblio.csv"]
          else
            IO.puts("📁 Found #{length(files)} CSV files:")
            Enum.each(files, &IO.puts("  - #{&1}"))
            files
          end
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

      ["--file", single_file] ->
        # Single file provided with --file flag
        if File.exists?(single_file) do
          IO.puts("📁 Using single CSV file: #{single_file}")
          [single_file]
        else
          IO.puts("❌ File not found: #{single_file}")
          exit(:file_not_found)
        end

      ["--pattern", pattern] ->
        # Pattern provided (e.g. --pattern "data/biblio_*.csv")
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
        pattern = Path.join(directory, "*.csv")
        files = Path.wildcard(pattern) |> Enum.sort()

        if Enum.empty?(files) do
          IO.puts("❌ No CSV files found in directory: #{directory}")
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

  def process_csv_files(csv_files, property_map) do
    total_files = length(csv_files)

    csv_files
    |> Enum.with_index(1)
    |> Enum.each(fn {csv_path, file_index} ->
      IO.puts("\n🔄 Processing file #{file_index}/#{total_files}: #{csv_path}")
      file_size = File.stat!(csv_path).size
      IO.puts("📊 File size: #{Float.round(file_size / 1024 / 1024, 2)} MB")

      start_time = System.monotonic_time(:millisecond)

      # Process single file with streaming
      process_single_file(csv_path, property_map)

      end_time = System.monotonic_time(:millisecond)
      duration = end_time - start_time
      IO.puts("✅ Completed #{csv_path} in #{duration}ms")
    end)
  end

  defp process_single_file(csv_path, property_map) do
    unit_id = extract_unit_id_from_filename(csv_path)
    IO.puts("📋 Using unit_id: #{unit_id || "nil"} for file: #{csv_path}")

    # Load author data for this unit
    {:ok, author_data} = AuthorLoader.load_authors_for_unit(unit_id)

    File.stream!(csv_path)
    |> CSVParser.parse_stream()
    |> Stream.map(&Mapper.to_maps(&1, property_map, unit_id, author_data))
    # Smaller chunks for better memory management
    |> Stream.chunk_every(100)
    |> Stream.with_index(1)
    |> Enum.each(fn {batch, chunk_index} ->
      # separate the two lists
      colls = Enum.map(batch, &elem(&1, 0))
      fields = batch |> Enum.flat_map(&elem(&1, 1))

      if length(colls) > 0 do
        Repo.insert_all(Collection.__schema__(:source), colls, on_conflict: :nothing)
      end

      if length(fields) > 0 do
        try do
          Repo.insert_all(CollectionField.__schema__(:source), fields, on_conflict: :nothing)
        rescue
          e in Postgrex.Error ->
            IO.puts(
              "❌ Insertion failed at chunk #{chunk_index} with error: #{Exception.message(e)}"
            )

            IO.inspect(fields, label: "🔍 Problematic fields batch")

            Enum.each(fields, fn row ->
              Enum.each(row, fn {key, value} ->
                if is_binary(value) and String.length(value) > 255 do
                  IO.puts(
                    "⚠️ Field too long: #{key} => #{String.slice(value, 0..80)}... (#{String.length(value)} chars)"
                  )
                end
              end)
            end)

            reraise e, __STACKTRACE__
        end
      end

      # Progress indicator
      if rem(chunk_index, 10) == 0 do
        IO.write(".")
      end

      # Optional: Add small delay to prevent overwhelming the database
      Process.sleep(10)
    end)

    # New line after progress dots
    IO.puts("#{csv_path} - ✅ Done!")
  end

  defp extract_unit_id_from_filename(csv_path) do
    # Updated regex to match both patterns: biblio_20.csv and biblio_something_20.csv
    case Regex.run(~r/biblio_.*?(\d+)\.csv$/, csv_path) do
      [_full_match, number_str] ->
        case Integer.parse(number_str) do
          {number, ""} -> number
          _ -> nil
        end

      nil ->
        nil
    end
  end
end

# Normal Processing
csv_files = CSVProcessor.get_csv_files()
CSVProcessor.process_csv_files(csv_files, property_map)

IO.puts("✅ Done!")
