Mix.Task.run("app.start")

NimbleCSV.define(
  CSVParser,
  separator: ",",
  escape: "\"",
  escape_pattern: ~r/\\./
)

alias Voile.Repo
alias Voile.Schema.Catalog.{Collection, CollectionField}

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
        unit_id \\ nil
      ) do
    raw_uuid = UUID.generate()
    {:ok, id} = UUID.dump(raw_uuid)

    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

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
      old_biblio_id: String.to_integer(biblio_id),
      type_id: nil,
      template_id: nil,
      creator_id: nil,
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
    iex > elixir import_biblio.exs --pattern "data/biblio_*.csv"
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
        # No arguments - look for biblio_*.csv pattern in scripts/ directory
        pattern = "scripts/biblio_*.csv"
        files = Path.wildcard(pattern) |> Enum.sort()

        if Enum.empty?(files) do
          IO.puts("📁 No biblio_*.csv files found, using default: scripts/biblio.csv")
          ["scripts/biblio.csv"]
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

    File.stream!(csv_path)
    |> CSVParser.parse_stream()
    |> Stream.map(&Mapper.to_maps(&1, property_map))
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
    case Regex.run(~r/biblio_(\d+)\.csv$/, csv_path) do
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

# Add this for concurrent file processing (be careful with DB connections)
# Task.async_stream(csv_files, fn csv_path ->
#  process_single_file(csv_path, property_map)
# end, max_concurrency: 3)
# |> Stream.run()

IO.puts("✅ Done!")
