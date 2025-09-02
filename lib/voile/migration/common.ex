defmodule Voile.Migration.Common do
  @moduledoc """
  Common utilities and helpers for data migration.
  """

  @csv_base_path "scripts/csv_data"

  # Define CSV parser
  NimbleCSV.define(
    CSVParser,
    separator: ",",
    escape: "\"",
    escape_pattern: ~r/\\./
  )

  def get_csv_files(data_type) do
    base_path = Path.join(@csv_base_path, data_type)

    if File.exists?(base_path) do
      pattern = Path.join(base_path, "*.csv")
      files = Path.wildcard(pattern) |> sort_csv_files_by_priority()

      if Enum.empty?(files) do
        IO.puts("⚠️ No CSV files found in #{base_path}")
        []
      else
        IO.puts("📁 Found #{length(files)} CSV files in #{base_path} (sorted by priority):")
        Enum.each(files, &IO.puts("  - #{Path.basename(&1)}"))
        files
      end
    else
      IO.puts("⚠️ Directory not found: #{base_path}")
      []
    end
  end

  def get_specific_files(data_type, pattern) do
    base_path = Path.join(@csv_base_path, data_type)
    full_pattern = Path.join(base_path, pattern)

    files = Path.wildcard(full_pattern) |> Enum.sort()

    if Enum.empty?(files) do
      IO.puts("⚠️ No files found matching pattern: #{full_pattern}")
      []
    else
      IO.puts("📁 Found #{length(files)} files matching pattern:")
      Enum.each(files, &IO.puts("  - #{Path.basename(&1)}"))
      files
    end
  end

  def extract_unit_id_from_filename(filename) do
    basename = Path.basename(filename)

    # Try to extract number from various patterns
    patterns = [
      # file_123.csv
      ~r/_(\d+)\.csv$/,
      # 123.csv
      ~r/(\d+)\.csv$/,
      # file_123_something
      ~r/_(\d+)_/
    ]

    Enum.find_value(patterns, fn pattern ->
      case Regex.run(pattern, basename) do
        [_full_match, number_str] ->
          case Integer.parse(number_str) do
            {number, ""} -> number
            _ -> nil
          end

        nil ->
          nil
      end
    end)
  end

  def parse_int(val) when val in [nil, ""], do: nil
  def parse_int(val), do: String.to_integer(val)

  def parse_date(val) when val in [nil, "", "0000-00-00"], do: nil

  def parse_date(val) do
    case Date.from_iso8601(val) do
      {:ok, date} -> date
      {:error, _} -> nil
    end
  end

  def parse_datetime(val) when val in [nil, "", "0000-00-00 00:00:00", "0000-00-00"], do: nil

  def parse_datetime(val) do
    case String.contains?(val, " ") do
      true ->
        [date, time] = String.split(val, " ", parts: 2)
        parse_datetime_parts(date, time)

      false ->
        parse_datetime_parts(val, "00:00:00")
    end
  end

  defp parse_datetime_parts(date, time) do
    case DateTime.from_iso8601(date <> "T" <> time <> "Z") do
      {:ok, dt, _} -> DateTime.truncate(dt, :second)
      {:error, _} -> nil
    end
  end

  def safe_string_trim(val) when val in [nil, ""], do: nil
  def safe_string_trim(val), do: String.trim(val)

  def batch_insert(repo, schema, records, batch_size, opts \\ []) do
    if Enum.empty?(records) do
      0
    else
      total_inserted =
        records
        |> Enum.chunk_every(batch_size)
        |> Enum.reduce(0, fn batch, acc ->
          result = repo.insert_all(schema, batch, opts)
          acc + elem(result, 0)
        end)

      total_inserted
    end
  end

  def print_summary(operation, stats) do
    IO.puts("\n" <> String.duplicate("=", 50))
    IO.puts("#{operation} SUMMARY")
    IO.puts(String.duplicate("=", 50))

    Enum.each(stats, fn {key, value} ->
      IO.puts("#{key}: #{value}")
    end)

    IO.puts(String.duplicate("=", 50))
  end

  def measure_time(operation, func) do
    start_time = System.monotonic_time(:millisecond)
    result = func.()
    end_time = System.monotonic_time(:millisecond)
    duration = end_time - start_time

    IO.puts("⏱️  #{operation} completed in #{duration}ms")
    result
  end

  # Custom sorting for CSV files with priority:
  # 1. _master files first
  # 2. _1, _2, _3, ... files in numerical order
  # 3. Regular files (alphabetical)
  defp sort_csv_files_by_priority(files) do
    files
    |> Enum.sort_by(&get_file_priority/1)
  end

  defp get_file_priority(file_path) do
    basename = Path.basename(file_path)

    cond do
      # _master files have highest priority (0)
      String.contains?(basename, "_master") ->
        {0, basename}

      # _N files have priority based on number (1, N)
      Regex.match?(~r/_(\d+)\.csv$/, basename) ->
        case Regex.run(~r/_(\d+)\.csv$/, basename) do
          [_, number_str] ->
            case Integer.parse(number_str) do
              {number, ""} -> {1, number}
              _ -> {2, basename}
            end

          _ ->
            {2, basename}
        end

      # Regular files have lowest priority (2)
      true ->
        {2, basename}
    end
  end

  @doc """
  Filter out duplicate records based on a specified field.
  Returns {filtered_records, seen_set, duplicate_count}
  """
  def filter_duplicates(records, seen_set, field_getter, line_getter \\ nil) do
    records
    |> Enum.reduce({[], seen_set, 0}, fn record, {acc_records, acc_seen, dup_count} ->
      field_value = field_getter.(record)

      if MapSet.member?(acc_seen, field_value) do
        line_info = if line_getter, do: " at line #{line_getter.(record)}", else: ""
        IO.puts("⚠️ Skipping duplicate #{field_value}#{line_info}")
        {acc_records, acc_seen, dup_count + 1}
      else
        {[record | acc_records], MapSet.put(acc_seen, field_value), dup_count}
      end
    end)
  end
end
