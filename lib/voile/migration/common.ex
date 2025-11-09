defmodule Voile.Migration.Common do
  @moduledoc """
  Common utilities and helpers for data migration.
  """

  # Get the CSV base path, preferring absolute path for containerized environments
  def csv_base_path do
    cond do
      File.dir?("/app/scripts/csv_data") -> "/app/scripts/csv_data"
      File.dir?("scripts/csv_data") -> "scripts/csv_data"
      # fallback
      true -> "scripts/csv_data"
    end
  end

  # Define CSV parser
  NimbleCSV.define(
    CSVParser,
    separator: ",",
    escape: "\"",
    escape_pattern: ~r/\\./
  )

  def get_csv_files(data_type) do
    base_path = Path.join(csv_base_path(), data_type)

    if File.exists?(base_path) do
      pattern = Path.join(base_path, "*.csv")
      files = Path.wildcard(pattern) |> sort_csv_files_by_priority()

      if Enum.empty?(files) do
        IO.puts("âš ï¸ No CSV files found in #{base_path}")
        []
      else
        IO.puts("ðŸ“ Found #{length(files)} CSV files in #{base_path} (sorted by priority):")
        Enum.each(files, &IO.puts("  - #{Path.basename(&1)}"))
        files
      end
    else
      IO.puts("âš ï¸ Directory not found: #{base_path}")
      []
    end
  end

  def get_specific_files(data_type, pattern) do
    base_path = Path.join(csv_base_path(), data_type)
    full_pattern = Path.join(base_path, pattern)

    files = Path.wildcard(full_pattern) |> Enum.sort()

    if Enum.empty?(files) do
      IO.puts("âš ï¸ No files found matching pattern: #{full_pattern}")
      []
    else
      IO.puts("ðŸ“ Found #{length(files)} files matching pattern:")
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

  def parse_int(val) do
    try do
      String.to_integer(val)
    rescue
      ArgumentError -> nil
    end
  end

  def parse_date(val) when val in [nil, "", "0000-00-00"], do: nil

  def parse_date(val) do
    val = safe_string_trim(val)

    case val do
      nil ->
        nil

      "" ->
        nil

      "0000-00-00" ->
        nil

      _ ->
        # Try different date formats
        try_parse_date_formats(val)
    end
  end

  defp try_parse_date_formats(val) do
    # Try ISO format first (YYYY-MM-DD)
    case Date.from_iso8601(val) do
      {:ok, date} ->
        date

      {:error, _} ->
        # Try other common formats
        try_other_date_formats(val)
    end
  end

  defp try_other_date_formats(val) do
    # Try DD/MM/YYYY format
    case Regex.run(~r/^(\d{1,2})\/(\d{1,2})\/(\d{4})$/, val) do
      [_, day, month, year] ->
        try do
          Date.new!(String.to_integer(year), String.to_integer(month), String.to_integer(day))
        rescue
          _ -> try_yyyy_mm_dd_format(val)
        end

      nil ->
        try_yyyy_mm_dd_format(val)
    end
  end

  defp try_yyyy_mm_dd_format(val) do
    # Try YYYY-MM-DD with different separators
    case Regex.run(~r/^(\d{4})[-\/](\d{1,2})[-\/](\d{1,2})$/, val) do
      [_, year, month, day] ->
        try do
          Date.new!(String.to_integer(year), String.to_integer(month), String.to_integer(day))
        rescue
          _ -> nil
        end

      nil ->
        nil
    end
  end

  def parse_datetime(val) when val in [nil, "", "0000-00-00 00:00:00", "0000-00-00"], do: nil

  def parse_datetime(val) do
    val = safe_string_trim(val)

    case val do
      nil ->
        nil

      "" ->
        nil

      "0000-00-00" ->
        nil

      "0000-00-00 00:00:00" ->
        nil

      _ ->
        try_parse_datetime_formats(val)
    end
  end

  defp try_parse_datetime_formats(val) do
    case String.contains?(val, " ") do
      true ->
        [date_part, time_part] = String.split(val, " ", parts: 2)
        parse_datetime_parts(date_part, time_part)

      false ->
        parse_datetime_parts(val, "00:00:00")
    end
  end

  defp parse_datetime_parts(date, time) do
    # First, try to parse the date part using our improved parse_date function
    case try_parse_date_formats(date) do
      nil ->
        nil

      parsed_date ->
        # Convert to datetime with the time part
        {hour, minute, second} = parse_time_part(time)

        try do
          {:ok, naive_dt} = NaiveDateTime.new(parsed_date, Time.new!(hour, minute, second))
          DateTime.from_naive!(naive_dt, "Etc/UTC") |> DateTime.truncate(:second)
        rescue
          _ -> nil
        end
    end
  end

  defp parse_time_part(time_str) do
    case Regex.run(~r/^(\d{1,2}):(\d{1,2}):(\d{1,2})$/, time_str) do
      [_, hour, minute, second] ->
        try do
          {String.to_integer(hour), String.to_integer(minute), String.to_integer(second)}
        rescue
          _ -> {0, 0, 0}
        end

      nil ->
        case Regex.run(~r/^(\d{1,2}):(\d{1,2})$/, time_str) do
          [_, hour, minute] ->
            try do
              {String.to_integer(hour), String.to_integer(minute), 0}
            rescue
              _ -> {0, 0, 0}
            end

          nil ->
            {0, 0, 0}
        end
    end
  end

  def safe_string_trim(val) when val in [nil, ""], do: nil
  def safe_string_trim(val), do: String.trim(val)

  def utc_now_truncated do
    DateTime.utc_now() |> DateTime.truncate(:second)
  end

  @doc """
  Optimized batch insert that minimizes connection idle time.
  Uses transactions and proper timeouts for better performance.
  """
  def batch_insert_optimized(repo, schema, records, opts \\ []) do
    if Enum.empty?(records) do
      {0, []}
    else
      timeout = Keyword.get(opts, :timeout, :infinity)
      on_conflict = Keyword.get(opts, :on_conflict, :nothing)
      returning = Keyword.get(opts, :returning, [])

      repo.transaction(
        fn ->
          repo.insert_all(schema, records,
            on_conflict: on_conflict,
            returning: returning,
            timeout: timeout
          )
        end,
        timeout: timeout
      )
      |> case do
        {:ok, result} ->
          result

        {:error, reason} ->
          IO.puts("âš ï¸ Batch insert transaction failed: #{inspect(reason)}")
          {0, []}
      end
    end
  end

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

    IO.puts("â±ï¸  #{operation} completed in #{duration}ms")
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
        IO.puts("âš ï¸ Skipping duplicate #{field_value}#{line_info}")
        {acc_records, acc_seen, dup_count + 1}
      else
        {[record | acc_records], MapSet.put(acc_seen, field_value), dup_count}
      end
    end)
  end
end
