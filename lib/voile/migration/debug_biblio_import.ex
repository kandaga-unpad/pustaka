defmodule Voile.Migration.DebugBiblioImport do
  @moduledoc """
  Debug script to check which biblio records from CSV are missing from database
  """

  import Ecto.Query
  import Voile.Migration.Common

  alias Voile.Repo
  alias Voile.Schema.Catalog.Collection

  def check_missing_biblio(file_path \\ "scripts/csv_data/biblio/biblio_20.csv") do
    IO.puts("🔍 Checking missing biblio records in #{file_path}...")

    # Get unit_id from filename
    unit_id = extract_unit_id_from_filename(file_path)
    IO.puts("📋 Unit ID: #{unit_id}")

    # Load existing collections for this unit
    existing_biblio_ids =
      from(c in Collection,
        select: c.old_biblio_id,
        where: c.unit_id == ^unit_id and not is_nil(c.old_biblio_id)
      )
      |> Repo.all()
      |> MapSet.new()

    IO.puts(
      "📊 Found #{MapSet.size(existing_biblio_ids)} existing collections for unit #{unit_id}"
    )

    # Read CSV and check each row
    {total_rows, missing_rows, sample_missing} =
      File.stream!(file_path)
      |> CSVParser.parse_stream(skip_headers: false)
      # Skip header
      |> Stream.drop(1)
      |> Enum.reduce({0, [], []}, fn row, {total, missing, samples} ->
        total = total + 1
        col_count = length(row)

        case row do
          [biblio_id_str | _rest] ->
            case parse_int(biblio_id_str) do
              nil ->
                IO.puts("⚠️ Invalid biblio_id: #{biblio_id_str} (#{col_count} columns)")
                {total, missing, samples}

              biblio_id ->
                if MapSet.member?(existing_biblio_ids, biblio_id) do
                  {total, missing, samples}
                else
                  new_missing = [{biblio_id, col_count} | missing]

                  new_samples =
                    if length(samples) < 10 do
                      [{biblio_id, col_count} | samples]
                    else
                      samples
                    end

                  {total, new_missing, new_samples}
                end
            end

          _ ->
            IO.puts("⚠️ Malformed row: #{inspect(row)} (#{col_count} columns)")
            {total, missing, samples}
        end
      end)

    missing_count = length(missing_rows)

    IO.puts("\n📊 Results:")
    IO.puts("  Total rows in CSV: #{total_rows}")
    IO.puts("  Existing in DB: #{total_rows - missing_count}")
    IO.puts("  Missing from DB: #{missing_count}")

    # Check column distribution
    col_counts = missing_rows |> Enum.map(&elem(&1, 1)) |> Enum.frequencies()
    IO.puts("\n📊 Column count distribution for missing rows:")

    col_counts
    |> Enum.sort_by(&elem(&1, 1), :desc)
    |> Enum.each(fn {count, freq} ->
      IO.puts("  #{count} columns: #{freq} rows")
    end)

    if missing_count > 0 do
      IO.puts("\n📋 Sample missing biblio_ids (first 10):")

      sample_missing
      |> Enum.reverse()
      |> Enum.each(fn {biblio_id, col_count} ->
        IO.puts("  - biblio_id: #{biblio_id} (#{col_count} columns)")
      end)
    end

    %{total: total_rows, existing: total_rows - missing_count, missing: missing_count}
  end

  def check_row_processing(
        file_path \\ "scripts/csv_data/biblio/biblio_20.csv",
        biblio_id_to_check \\ 506
      ) do
    IO.puts("🔍 Checking row processing for #{file_path}, biblio_id: #{biblio_id_to_check}...")

    unit_id = extract_unit_id_from_filename(file_path)

    # Load minimal cache for testing
    cache = %{
      # Empty for testing
      existing_collections: MapSet.new(),
      unit_map: %{unit_id => %{abbr: "UNK", name: "Unknown"}},
      resource_class_map: %{40 => %{local_name: "LIB", glam_type: "Library"}},
      bibliographic_resource_type_id: 40,
      author_mappings: %{},
      publisher_mappings: %{},
      creators: %{},
      unit_author_data: %{},
      default_creator_id: nil
    }

    # Find the specific row
    row = find_row_by_biblio_id(file_path, biblio_id_to_check)

    case row do
      nil ->
        IO.puts("❌ Row not found for biblio_id: #{biblio_id_to_check}")

      row ->
        IO.puts("✅ Found row with #{length(row)} columns")
        IO.puts("  First 5 columns: #{inspect(Enum.take(row, 5))}")

        # Test the prepare_biblio_data function
        result = prepare_biblio_data_test(row, unit_id, cache)
        IO.puts("  Result: #{inspect(result)}")
    end
  end

  defp find_row_by_biblio_id(file_path, biblio_id) do
    File.stream!(file_path)
    |> CSVParser.parse_stream(skip_headers: false)
    # Skip header
    |> Stream.drop(1)
    |> Enum.find(fn row ->
      case row do
        [biblio_id_str | _] -> parse_int(biblio_id_str) == biblio_id
        _ -> false
      end
    end)
  end

  # Test version of prepare_biblio_data without DB operations
  defp prepare_biblio_data_test(
         row,
         _unit_id,
         _cache
       ) do
    case row do
      [
        biblio_id,
        _gmd_id,
        title,
        _sor,
        _edition,
        _isbn_issn,
        _publisher_id,
        _publish_year,
        _collation,
        _series_title,
        _call_number,
        _language_id,
        _source,
        _publish_place_id,
        _classification,
        _notes,
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

        if biblio_id_int do
          IO.puts(
            "  ✅ Valid row format, biblio_id: #{biblio_id_int}, title: #{String.slice(title, 0, 50)}"
          )

          {:ok, "Would process"}
        else
          {:error, "Invalid biblio_id: #{biblio_id}"}
        end

      _ ->
        {:skip, "Invalid row format, columns: #{length(row)}"}
    end
  rescue
    e ->
      {:error, "Exception: #{Exception.message(e)}"}
  end
end
