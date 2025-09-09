defmodule Voile.Utils.DateHelper do
  @moduledoc """
  Helper functions for date and time formatting and conversion across the application
  """

  @doc """
  Converts a UTC datetime to local time and formats it for display.

  ## Parameters

    * `utc_datetime` - The UTC datetime to convert (%DateTime{} or %DateTime{})
    * `timezone` - The target timezone (default: "Asia/Jakarta")
    * `format` - The format string (default: "%d/%m/%Y %H:%M %Z")

  ## Examples

      iex> utc_time = ~U[2023-03-15 14:30:00Z]
      iex> Voile.Utils.DateHelper.to_local_time(utc_time)
      "15/03/2023 21:30 WIB"

      iex> utc_time = ~U[2023-03-15 14:30:00Z]
      iex> Voile.Utils.DateHelper.to_local_time(utc_time, "America/Los_Angeles")
      "15/03/2023 07:30 PDT"

  """
  def to_local_time(utc_datetime, timezone \\ "Asia/Jakarta", format \\ "%d/%m/%Y %H:%M %Z")

  def to_local_time(%DateTime{} = utc_datetime, timezone, format) do
    utc_datetime
    |> DateTime.shift_zone!(timezone)
    |> Calendar.strftime(format)
  rescue
    _ -> format_fallback(utc_datetime)
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

  ## Examples

      iex> now = DateTime.utc_now()
      iex> past = DateTime.add(now, -3600, :second)  # 1 hour ago
      iex> Voile.Utils.DateHelper.time_ago(past)
      "1 hour ago"

  """
  def time_ago(utc_datetime) do
    case utc_datetime do
      %DateTime{} = dt ->
        do_time_ago(dt)

      nil ->
        ""
    end
  rescue
    _ -> format_fallback(utc_datetime)
  end

  @doc """
  Formats datetime for display with both local time and relative time.

  ## Examples

      iex> utc_time = ~U[2023-03-15 14:30:00Z]
      iex> Voile.Utils.DateHelper.display_datetime(utc_time)
      "15/03/2023 21:30 WIB (2 days ago)"

  """
  def display_datetime(utc_datetime, timezone \\ "Asia/Jakarta") do
    local_time = to_local_time(utc_datetime, timezone)
    relative_time = time_ago(utc_datetime)

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

  def to_utc(nil, _timezone), do: nil

  # Private helper functions

  defp do_time_ago(datetime) do
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

  defp pluralize(1, unit), do: "1 #{unit} ago"
  defp pluralize(n, unit), do: "#{n} #{unit}s ago"

  defp format_fallback(%DateTime{} = dt) do
    Calendar.strftime(dt, "%d/%m/%Y %H:%M UTC")
  end

  defp format_fallback(_), do: ""
end
