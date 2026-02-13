defmodule Voile.Utils.DateHelper do
  @moduledoc """
  Helper functions for date and time formatting and conversion across the application.
  Enhanced with Indonesian localization and country-specific formatting.
  """

  @doc """
  Converts a UTC datetime to local time and formats it for display.

  ## Parameters

    * `utc_datetime` - The UTC datetime to convert (%DateTime{} or %NaiveDateTime{})
    * `timezone` - The target timezone (default: "Asia/Jakarta")
    * `format` - The format type:
      - String (strftime format) - e.g., "%d/%m/%Y %H:%M %Z"
      - :indonesian - "Senin, 6 Oktober 2025 12:22"
      - :indonesian_short - "Sen, 6 Okt 2025 12:22"
      - :indonesian_date - "Senin, 6 Oktober 2025"
      - Country code (e.g., "US", "JP") - Country-specific format

  ## Examples

      iex> utc_time = ~U[2023-03-15 14:30:00Z]
      iex> Voile.Utils.DateHelper.to_local_time(utc_time)
      "15/03/2023 21:30 WIB"

      iex> Voile.Utils.DateHelper.to_local_time(utc_time, "Asia/Jakarta", :indonesian)
      "Rabu, 15 Maret 2023 21:30"

      iex> Voile.Utils.DateHelper.to_local_time(utc_time, "America/New_York", "US")
      "03/15/2023 10:30:00 AM"
  """
  def to_local_time(utc_datetime, timezone \\ "Asia/Jakarta", format \\ "%d/%m/%Y %H:%M %Z")

  def to_local_time(%DateTime{} = utc_datetime, timezone, format) do
    case DateTime.shift_zone(utc_datetime, timezone) do
      {:ok, local_dt} -> apply_format(local_dt, format)
      {:error, _} -> format_fallback(utc_datetime)
    end
  rescue
    _ -> format_fallback(utc_datetime)
  end

  def to_local_time(%NaiveDateTime{} = naive_datetime, timezone, format) do
    case DateTime.from_naive(naive_datetime, "Etc/UTC") do
      {:ok, dt} -> to_local_time(dt, timezone, format)
      _ -> format_fallback(naive_datetime)
    end
  end

  def to_local_time(%Date{} = date, _timezone, format) do
    # Date doesn't have timezone info, just format it
    apply_date_format(date, format)
  end

  def to_local_time(nil, _timezone, _format), do: ""

  @doc """
  Converts a UTC datetime to local date only (no time).

  ## Examples

      iex> utc_time = ~U[2023-03-15 14:30:00Z]
      iex> Voile.Utils.DateHelper.to_local_date(utc_time)
      "15/03/2023"
  """
  def to_local_date(utc_datetime, timezone \\ "Asia/Jakarta") do
    to_local_time(utc_datetime, timezone, "%d/%m/%Y")
  end

  @doc """
  Converts a UTC datetime to a human-readable relative time.
  Supports both English and Indonesian.

  ## Examples

      iex> now = DateTime.utc_now()
      iex> past = DateTime.add(now, -3600, :second)
      iex> Voile.Utils.DateHelper.time_ago(past)
      "1 hour ago"

      iex> Voile.Utils.DateHelper.time_ago(past, :indonesian)
      "1 jam yang lalu"
  """
  def time_ago(utc_datetime, language \\ :english)

  def time_ago(%DateTime{} = datetime, language) do
    do_time_ago(datetime, language)
  rescue
    _ -> ""
  end

  def time_ago(%NaiveDateTime{} = naive_dt, language) do
    case DateTime.from_naive(naive_dt, "Etc/UTC") do
      {:ok, dt} -> do_time_ago(dt, language)
      _ -> ""
    end
  end

  def time_ago(nil, _language), do: ""

  @doc """
  Formats datetime for display with both local time and relative time.

  ## Examples

      iex> utc_time = ~U[2023-03-15 14:30:00Z]
      iex> Voile.Utils.DateHelper.display_datetime(utc_time)
      "15/03/2023 21:30 WIB (2 days ago)"

      iex> Voile.Utils.DateHelper.display_datetime(utc_time, format: :indonesian)
      "Rabu, 15 Maret 2023 21:30 (2 hari yang lalu)"
  """
  def display_datetime(utc_datetime, opts \\ []) do
    timezone = opts[:timezone] || "Asia/Jakarta"
    format = opts[:format] || "%d/%m/%Y %H:%M %Z"

    language =
      if format in [:indonesian, :indonesian_short, :indonesian_date],
        do: :indonesian,
        else: :english

    local_time = to_local_time(utc_datetime, timezone, format)
    relative_time = time_ago(utc_datetime, language)

    case {local_time, relative_time} do
      {"", ""} -> ""
      {local, ""} -> local
      {"", relative} -> relative
      {local, relative} -> "#{local} (#{relative})"
    end
  end

  @doc """
  Converts local datetime input to UTC for database storage.

  ## Examples

      iex> local_time = ~N[2023-03-15 21:30:00]
      iex> Voile.Utils.DateHelper.to_utc(local_time, "Asia/Jakarta")
      ~U[2023-03-15 14:30:00Z]
  """
  def to_utc(datetime, timezone \\ "Asia/Jakarta")

  def to_utc(%DateTime{} = datetime, _timezone) do
    DateTime.shift_zone!(datetime, "Etc/UTC")
  rescue
    _ -> nil
  end

  def to_utc(%NaiveDateTime{} = naive_datetime, timezone) do
    case DateTime.from_naive(naive_datetime, timezone) do
      {:ok, dt} -> DateTime.shift_zone!(dt, "Etc/UTC")
      _ -> nil
    end
  rescue
    _ -> nil
  end

  def to_utc(nil, _timezone), do: nil

  @doc """
  Parses an ISO 8601 datetime string and returns a DateTime struct.

  ## Examples

      iex> Voile.Utils.DateHelper.parse("2025-10-06T05:22:32Z")
      {:ok, ~U[2025-10-06 05:22:32Z]}
  """
  def parse(datetime_string) when is_binary(datetime_string) do
    case DateTime.from_iso8601(datetime_string) do
      {:ok, dt, _offset} -> {:ok, dt}
      {:error, _} -> {:error, :invalid_datetime_format}
    end
  end

  def parse(nil), do: {:error, :nil_datetime}

  @doc """
  Returns a list of supported country codes with their timezones.
  """
  def supported_countries do
    [
      %{code: "US", name: "United States", timezone: "America/New_York"},
      %{code: "GB", name: "United Kingdom", timezone: "Europe/London"},
      %{code: "DE", name: "Germany", timezone: "Europe/Berlin"},
      %{code: "FR", name: "France", timezone: "Europe/Paris"},
      %{code: "JP", name: "Japan", timezone: "Asia/Tokyo"},
      %{code: "CN", name: "China", timezone: "Asia/Shanghai"},
      %{code: "KR", name: "South Korea", timezone: "Asia/Seoul"},
      %{code: "ID", name: "Indonesia", timezone: "Asia/Jakarta"},
      %{code: "BR", name: "Brazil", timezone: "America/Sao_Paulo"},
      %{code: "AU", name: "Australia", timezone: "Australia/Sydney"},
      %{code: "CA", name: "Canada", timezone: "America/Toronto"},
      %{code: "IN", name: "India", timezone: "Asia/Kolkata"}
    ]
  end

  # Private helper functions

  defp apply_format(dt, format) when is_binary(format) do
    Calendar.strftime(dt, format)
  end

  defp apply_format(dt, :indonesian) do
    day_name = get_indonesian_day_name(dt)
    month_name = get_indonesian_month_name(dt)
    "#{day_name}, #{dt.day} #{month_name} #{dt.year} #{pad(dt.hour)}:#{pad(dt.minute)}"
  end

  defp apply_format(dt, :indonesian_short) do
    day_name = get_indonesian_day_name(dt, :short)
    month_name = get_indonesian_month_name(dt, :short)
    "#{day_name}, #{dt.day} #{month_name} #{dt.year} #{pad(dt.hour)}:#{pad(dt.minute)}"
  end

  defp apply_format(dt, :indonesian_date) do
    day_name = get_indonesian_day_name(dt)
    month_name = get_indonesian_month_name(dt)
    "#{day_name}, #{dt.day} #{month_name} #{dt.year}"
  end

  defp apply_format(dt, country_code) when is_atom(country_code) do
    apply_format(dt, Atom.to_string(country_code))
  end

  defp apply_format(dt, country_code) do
    case String.upcase(country_code) do
      "US" -> format_us(dt)
      "GB" -> format_gb(dt)
      "DE" -> format_de(dt)
      "FR" -> format_fr(dt)
      "JP" -> format_jp(dt)
      "CN" -> format_cn(dt)
      "KR" -> format_kr(dt)
      "ID" -> format_id(dt)
      "BR" -> format_br(dt)
      "AU" -> format_au(dt)
      "CA" -> format_ca(dt)
      "IN" -> format_in(dt)
      _ -> DateTime.to_iso8601(dt)
    end
  end

  # Apply format specifically for Date structs (no time component)
  defp apply_date_format(date, format) when is_binary(format) do
    Calendar.strftime(date, format)
  end

  defp apply_date_format(date, :indonesian) do
    day_name = get_indonesian_day_name_from_date(date)
    month_name = get_indonesian_month_name_from_date(date)
    "#{day_name}, #{date.day} #{month_name} #{date.year}"
  end

  defp apply_date_format(date, :indonesian_short) do
    day_name = get_indonesian_day_name_from_date(date, :short)
    month_name = get_indonesian_month_name_from_date(date, :short)
    "#{day_name}, #{date.day} #{month_name} #{date.year}"
  end

  defp apply_date_format(date, :indonesian_date) do
    day_name = get_indonesian_day_name_from_date(date)
    month_name = get_indonesian_month_name_from_date(date)
    "#{day_name}, #{date.day} #{month_name} #{date.year}"
  end

  defp apply_date_format(date, country_code) when is_atom(country_code) do
    apply_date_format(date, Atom.to_string(country_code))
  end

  defp apply_date_format(date, country_code) do
    case String.upcase(country_code) do
      "US" -> Calendar.strftime(date, "%m/%d/%Y")
      "GB" -> Calendar.strftime(date, "%d/%m/%Y")
      "DE" -> Calendar.strftime(date, "%d.%m.%Y")
      "FR" -> Calendar.strftime(date, "%d/%m/%Y")
      "JP" -> Calendar.strftime(date, "%Y/%m/%d")
      "CN" -> Calendar.strftime(date, "%Y年%m月%d日")
      "KR" -> Calendar.strftime(date, "%Y-%m-%d")
      "ID" -> Calendar.strftime(date, "%d/%m/%Y")
      "BR" -> Calendar.strftime(date, "%d/%m/%Y")
      "AU" -> Calendar.strftime(date, "%d/%m/%Y")
      "CA" -> Calendar.strftime(date, "%Y-%m-%d")
      "IN" -> Calendar.strftime(date, "%d-%m-%Y")
      _ -> Date.to_iso8601(date)
    end
  end

  defp get_indonesian_day_name(dt, format \\ :full) do
    day_of_week = Date.day_of_week(DateTime.to_date(dt))

    case {day_of_week, format} do
      {1, :full} -> "Senin"
      {2, :full} -> "Selasa"
      {3, :full} -> "Rabu"
      {4, :full} -> "Kamis"
      {5, :full} -> "Jumat"
      {6, :full} -> "Sabtu"
      {7, :full} -> "Minggu"
      {1, :short} -> "Sen"
      {2, :short} -> "Sel"
      {3, :short} -> "Rab"
      {4, :short} -> "Kam"
      {5, :short} -> "Jum"
      {6, :short} -> "Sab"
      {7, :short} -> "Min"
    end
  end

  defp get_indonesian_month_name(dt, format \\ :full) do
    case {dt.month, format} do
      {1, :full} -> "Januari"
      {2, :full} -> "Februari"
      {3, :full} -> "Maret"
      {4, :full} -> "April"
      {5, :full} -> "Mei"
      {6, :full} -> "Juni"
      {7, :full} -> "Juli"
      {8, :full} -> "Agustus"
      {9, :full} -> "September"
      {10, :full} -> "Oktober"
      {11, :full} -> "November"
      {12, :full} -> "Desember"
      {1, :short} -> "Jan"
      {2, :short} -> "Feb"
      {3, :short} -> "Mar"
      {4, :short} -> "Apr"
      {5, :short} -> "Mei"
      {6, :short} -> "Jun"
      {7, :short} -> "Jul"
      {8, :short} -> "Agu"
      {9, :short} -> "Sep"
      {10, :short} -> "Okt"
      {11, :short} -> "Nov"
      {12, :short} -> "Des"
    end
  end

  # Helper functions for Date structs
  defp get_indonesian_day_name_from_date(date, format \\ :full) do
    day_of_week = Date.day_of_week(date)

    case {day_of_week, format} do
      {1, :full} -> "Senin"
      {2, :full} -> "Selasa"
      {3, :full} -> "Rabu"
      {4, :full} -> "Kamis"
      {5, :full} -> "Jumat"
      {6, :full} -> "Sabtu"
      {7, :full} -> "Minggu"
      {1, :short} -> "Sen"
      {2, :short} -> "Sel"
      {3, :short} -> "Rab"
      {4, :short} -> "Kam"
      {5, :short} -> "Jum"
      {6, :short} -> "Sab"
      {7, :short} -> "Min"
    end
  end

  defp get_indonesian_month_name_from_date(date, format \\ :full) do
    case {date.month, format} do
      {1, :full} -> "Januari"
      {2, :full} -> "Februari"
      {3, :full} -> "Maret"
      {4, :full} -> "April"
      {5, :full} -> "Mei"
      {6, :full} -> "Juni"
      {7, :full} -> "Juli"
      {8, :full} -> "Agustus"
      {9, :full} -> "September"
      {10, :full} -> "Oktober"
      {11, :full} -> "November"
      {12, :full} -> "Desember"
      {1, :short} -> "Jan"
      {2, :short} -> "Feb"
      {3, :short} -> "Mar"
      {4, :short} -> "Apr"
      {5, :short} -> "Mei"
      {6, :short} -> "Jun"
      {7, :short} -> "Jul"
      {8, :short} -> "Agu"
      {9, :short} -> "Sep"
      {10, :short} -> "Okt"
      {11, :short} -> "Nov"
      {12, :short} -> "Des"
    end
  end

  defp format_us(dt) do
    hour_12 = rem(dt.hour, 12)
    hour_12 = if hour_12 == 0, do: 12, else: hour_12
    am_pm = if dt.hour < 12, do: "AM", else: "PM"

    "#{pad(dt.month)}/#{pad(dt.day)}/#{dt.year} #{pad(hour_12)}:#{pad(dt.minute)}:#{pad(dt.second)} #{am_pm}"
  end

  defp format_gb(dt) do
    "#{pad(dt.day)}/#{pad(dt.month)}/#{dt.year} #{pad(dt.hour)}:#{pad(dt.minute)}:#{pad(dt.second)}"
  end

  defp format_de(dt) do
    "#{pad(dt.day)}.#{pad(dt.month)}.#{dt.year} #{pad(dt.hour)}:#{pad(dt.minute)}:#{pad(dt.second)}"
  end

  defp format_fr(dt) do
    "#{pad(dt.day)}/#{pad(dt.month)}/#{dt.year} #{pad(dt.hour)}:#{pad(dt.minute)}:#{pad(dt.second)}"
  end

  defp format_jp(dt) do
    "#{dt.year}年#{pad(dt.month)}月#{pad(dt.day)}日 #{pad(dt.hour)}:#{pad(dt.minute)}:#{pad(dt.second)}"
  end

  defp format_cn(dt) do
    "#{dt.year}年#{pad(dt.month)}月#{pad(dt.day)}日 #{pad(dt.hour)}:#{pad(dt.minute)}:#{pad(dt.second)}"
  end

  defp format_kr(dt) do
    "#{dt.year}년 #{pad(dt.month)}월 #{pad(dt.day)}일 #{pad(dt.hour)}:#{pad(dt.minute)}:#{pad(dt.second)}"
  end

  defp format_id(dt) do
    "#{pad(dt.day)}-#{pad(dt.month)}-#{dt.year} #{pad(dt.hour)}:#{pad(dt.minute)}:#{pad(dt.second)}"
  end

  defp format_br(dt) do
    "#{pad(dt.day)}/#{pad(dt.month)}/#{dt.year} #{pad(dt.hour)}:#{pad(dt.minute)}:#{pad(dt.second)}"
  end

  defp format_au(dt) do
    "#{pad(dt.day)}/#{pad(dt.month)}/#{dt.year} #{pad(dt.hour)}:#{pad(dt.minute)}:#{pad(dt.second)}"
  end

  defp format_ca(dt) do
    "#{dt.year}-#{pad(dt.month)}-#{pad(dt.day)} #{pad(dt.hour)}:#{pad(dt.minute)}:#{pad(dt.second)}"
  end

  defp format_in(dt) do
    "#{pad(dt.day)}-#{pad(dt.month)}-#{dt.year} #{pad(dt.hour)}:#{pad(dt.minute)}:#{pad(dt.second)}"
  end

  defp do_time_ago(datetime, :english) do
    now = DateTime.utc_now()
    diff = DateTime.diff(now, datetime, :second)

    cond do
      diff < 60 -> "just now"
      diff < 3600 -> pluralize(div(diff, 60), "minute")
      diff < 86400 -> pluralize(div(diff, 3600), "hour")
      diff < 2_592_000 -> pluralize(div(diff, 86400), "day")
      diff < 31_536_000 -> pluralize(div(diff, 2_592_000), "month")
      true -> pluralize(div(diff, 31_536_000), "year")
    end
  end

  defp do_time_ago(datetime, :indonesian) do
    now = DateTime.utc_now()
    diff = DateTime.diff(now, datetime, :second)

    cond do
      diff < 60 -> "baru saja"
      diff < 3600 -> "#{div(diff, 60)} menit yang lalu"
      diff < 86400 -> "#{div(diff, 3600)} jam yang lalu"
      diff < 2_592_000 -> "#{div(diff, 86400)} hari yang lalu"
      diff < 31_536_000 -> "#{div(diff, 2_592_000)} bulan yang lalu"
      true -> "#{div(diff, 31_536_000)} tahun yang lalu"
    end
  end

  defp pluralize(1, unit), do: "1 #{unit} ago"
  defp pluralize(n, unit), do: "#{n} #{unit}s ago"

  defp pad(number) when number < 10, do: "0#{number}"
  defp pad(number), do: "#{number}"

  defp format_fallback(%DateTime{} = dt) do
    Calendar.strftime(dt, "%d/%m/%Y %H:%M UTC")
  end

  defp format_fallback(%NaiveDateTime{} = dt) do
    Calendar.strftime(dt, "%d/%m/%Y %H:%M")
  end
end
