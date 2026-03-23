defmodule Voile.Utils.DateHelperTest do
  use ExUnit.Case, async: true

  alias Voile.Utils.DateHelper

  # Time constants for readability
  @seconds_per_minute 60
  @seconds_per_hour 3_600
  @seconds_per_day 86_400
  @seconds_per_month 2_592_000
  @seconds_per_year 31_536_000

  describe "to_local_time/3" do
    test "formats a UTC datetime with default format (WIB/Asia/Jakarta)" do
      # 2023-03-15 14:30:00 UTC = 2023-03-15 21:30:00 WIB (UTC+7)
      utc_time = ~U[2023-03-15 14:30:00Z]
      result = DateHelper.to_local_time(utc_time)

      assert result =~ "15/03/2023"
      assert result =~ "21:30"
      assert result =~ "WIB"
    end

    test "formats with :indonesian format" do
      utc_time = ~U[2023-03-15 14:30:00Z]
      result = DateHelper.to_local_time(utc_time, "Asia/Jakarta", :indonesian)

      assert result =~ "Rabu"
      assert result =~ "15"
      assert result =~ "Maret"
      assert result =~ "2023"
      assert result =~ "21:30"
    end

    test "formats with :indonesian_short format" do
      utc_time = ~U[2023-03-15 14:30:00Z]
      result = DateHelper.to_local_time(utc_time, "Asia/Jakarta", :indonesian_short)

      assert result =~ "Rab"
      assert result =~ "15"
      assert result =~ "Mar"
      assert result =~ "2023"
      assert result =~ "21:30"
    end

    test "formats with :indonesian_date format" do
      utc_time = ~U[2023-03-15 14:30:00Z]
      result = DateHelper.to_local_time(utc_time, "Asia/Jakarta", :indonesian_date)

      assert result =~ "Rabu"
      assert result =~ "15"
      assert result =~ "Maret"
      assert result =~ "2023"
      # No time portion for date-only format
      refute result =~ ":"
    end

    test "formats with NaiveDateTime input" do
      naive_dt = ~N[2023-03-15 14:30:00]
      result = DateHelper.to_local_time(naive_dt, "Asia/Jakarta", "%d/%m/%Y %H:%M %Z")

      assert result =~ "15/03/2023"
      assert result =~ "21:30"
    end

    test "formats a Date struct" do
      date = ~D[2023-03-15]
      result = DateHelper.to_local_time(date, "Asia/Jakarta", "%d/%m/%Y")

      assert result == "15/03/2023"
    end

    test "returns empty string for nil input" do
      assert DateHelper.to_local_time(nil) == ""
    end

    test "formats with US country code" do
      utc_time = ~U[2023-03-15 14:30:00Z]
      # Convert to Eastern time (UTC-4 or UTC-5), check it has AM/PM
      result = DateHelper.to_local_time(utc_time, "America/New_York", "US")

      assert result =~ "AM" or result =~ "PM"
      assert result =~ "2023"
    end

    test "formats with JP country code" do
      utc_time = ~U[2023-03-15 14:30:00Z]
      result = DateHelper.to_local_time(utc_time, "Asia/Tokyo", "JP")

      # Japanese format: YYYY年MM月DD日 ...
      assert result =~ "年"
      assert result =~ "月"
      assert result =~ "日"
    end

    test "formats with CN country code" do
      utc_time = ~U[2023-03-15 14:30:00Z]
      result = DateHelper.to_local_time(utc_time, "Asia/Shanghai", "CN")

      assert result =~ "年"
      assert result =~ "月"
      assert result =~ "日"
    end

    test "formats with KR country code" do
      utc_time = ~U[2023-03-15 14:30:00Z]
      result = DateHelper.to_local_time(utc_time, "Asia/Seoul", "KR")

      assert result =~ "년"
      assert result =~ "월"
      assert result =~ "일"
    end

    test "formats with GB country code" do
      utc_time = ~U[2023-03-15 14:30:00Z]
      result = DateHelper.to_local_time(utc_time, "Europe/London", "GB")

      # DD/MM/YYYY HH:MM:SS format
      assert result =~ "/"
      assert result =~ "2023"
    end

    test "formats with DE country code" do
      utc_time = ~U[2023-03-15 14:30:00Z]
      result = DateHelper.to_local_time(utc_time, "Europe/Berlin", "DE")

      # DD.MM.YYYY HH:MM:SS format
      assert result =~ "."
      assert result =~ "2023"
    end

    test "formats with ID country code" do
      utc_time = ~U[2023-03-15 14:30:00Z]
      result = DateHelper.to_local_time(utc_time, "Asia/Jakarta", "ID")

      # DD-MM-YYYY HH:MM:SS format
      assert result =~ "-"
      assert result =~ "2023"
    end

    test "formats with unknown country code falls back to ISO 8601" do
      utc_time = ~U[2023-03-15 14:30:00Z]
      result = DateHelper.to_local_time(utc_time, "Asia/Jakarta", "XX")

      assert result =~ "2023"
    end
  end

  describe "to_local_date/2" do
    test "returns date-only string in default format" do
      utc_time = ~U[2023-03-15 14:30:00Z]
      result = DateHelper.to_local_date(utc_time)

      # 14:30 UTC = 21:30 WIB, same day
      assert result == "15/03/2023"
    end

    test "returns empty string for nil input" do
      assert DateHelper.to_local_date(nil) == ""
    end
  end

  describe "time_ago/2" do
    test "returns 'just now' for recent times in English" do
      recent = DateTime.utc_now() |> DateTime.add(-10, :second)
      assert DateHelper.time_ago(recent) == "just now"
    end

    test "returns minute(s) ago in English" do
      two_minutes_ago = DateTime.utc_now() |> DateTime.add(-2 * @seconds_per_minute, :second)
      result = DateHelper.time_ago(two_minutes_ago)
      assert result == "2 minutes ago"
    end

    test "returns '1 minute ago' for singular in English" do
      one_minute_ago = DateTime.utc_now() |> DateTime.add(-@seconds_per_minute - 30, :second)
      result = DateHelper.time_ago(one_minute_ago)
      assert result == "1 minute ago"
    end

    test "returns hour(s) ago in English" do
      two_hours_ago = DateTime.utc_now() |> DateTime.add(-2 * @seconds_per_hour, :second)
      result = DateHelper.time_ago(two_hours_ago)
      assert result == "2 hours ago"
    end

    test "returns '1 hour ago' for singular in English" do
      one_hour_ago = DateTime.utc_now() |> DateTime.add(-@seconds_per_hour - 1, :second)
      result = DateHelper.time_ago(one_hour_ago)
      assert result == "1 hour ago"
    end

    test "returns day(s) ago in English" do
      three_days_ago = DateTime.utc_now() |> DateTime.add(-3 * @seconds_per_day, :second)
      result = DateHelper.time_ago(three_days_ago)
      assert result == "3 days ago"
    end

    test "returns month(s) ago in English" do
      two_months_ago = DateTime.utc_now() |> DateTime.add(-2 * @seconds_per_month, :second)
      result = DateHelper.time_ago(two_months_ago)
      assert result == "2 months ago"
    end

    test "returns year(s) ago in English" do
      two_years_ago = DateTime.utc_now() |> DateTime.add(-2 * @seconds_per_year, :second)
      result = DateHelper.time_ago(two_years_ago)
      assert result == "2 years ago"
    end

    test "returns 'baru saja' for recent times in Indonesian" do
      recent = DateTime.utc_now() |> DateTime.add(-10, :second)
      assert DateHelper.time_ago(recent, :indonesian) == "baru saja"
    end

    test "returns 'N menit yang lalu' for minutes in Indonesian" do
      five_minutes_ago = DateTime.utc_now() |> DateTime.add(-5 * @seconds_per_minute, :second)
      assert DateHelper.time_ago(five_minutes_ago, :indonesian) == "5 menit yang lalu"
    end

    test "returns 'N jam yang lalu' for hours in Indonesian" do
      three_hours_ago = DateTime.utc_now() |> DateTime.add(-3 * @seconds_per_hour, :second)
      assert DateHelper.time_ago(three_hours_ago, :indonesian) == "3 jam yang lalu"
    end

    test "returns 'N hari yang lalu' for days in Indonesian" do
      two_days_ago = DateTime.utc_now() |> DateTime.add(-2 * @seconds_per_day, :second)
      assert DateHelper.time_ago(two_days_ago, :indonesian) == "2 hari yang lalu"
    end

    test "returns 'N bulan yang lalu' for months in Indonesian" do
      two_months_ago = DateTime.utc_now() |> DateTime.add(-2 * @seconds_per_month, :second)
      assert DateHelper.time_ago(two_months_ago, :indonesian) == "2 bulan yang lalu"
    end

    test "returns 'N tahun yang lalu' for years in Indonesian" do
      two_years_ago = DateTime.utc_now() |> DateTime.add(-2 * @seconds_per_year, :second)
      assert DateHelper.time_ago(two_years_ago, :indonesian) == "2 tahun yang lalu"
    end

    test "returns empty string for nil input" do
      assert DateHelper.time_ago(nil) == ""
      assert DateHelper.time_ago(nil, :indonesian) == ""
    end

    test "handles NaiveDateTime input" do
      naive_dt = NaiveDateTime.utc_now() |> NaiveDateTime.add(-60, :second)
      result = DateHelper.time_ago(naive_dt)
      assert result == "1 minute ago"
    end
  end

  describe "display_datetime/2" do
    test "returns empty string for nil input" do
      assert DateHelper.display_datetime(nil) == ""
    end

    test "combines local time and relative time for a datetime" do
      # Use a fixed datetime 24 hours ago so we can predict relative time
      utc_time = DateTime.utc_now() |> DateTime.add(-@seconds_per_day, :second)
      result = DateHelper.display_datetime(utc_time)

      assert result =~ "("
      assert result =~ ")"
      assert result =~ "ago" or result =~ "day"
    end

    test "uses Indonesian language when format is :indonesian" do
      utc_time = DateTime.utc_now() |> DateTime.add(-2 * @seconds_per_day, :second)
      result = DateHelper.display_datetime(utc_time, format: :indonesian)

      assert result =~ "yang lalu"
    end
  end

  describe "to_utc/2" do
    test "converts NaiveDateTime from local timezone to UTC" do
      local_dt = ~N[2023-03-15 21:30:00]
      result = DateHelper.to_utc(local_dt, "Asia/Jakarta")

      # Asia/Jakarta is UTC+7, so 21:30 local = 14:30 UTC
      assert result == ~U[2023-03-15 14:30:00Z]
    end

    test "returns a DateTime unchanged when already UTC" do
      utc_dt = ~U[2023-03-15 14:30:00Z]
      result = DateHelper.to_utc(utc_dt)

      assert result == ~U[2023-03-15 14:30:00Z]
    end

    test "returns nil for nil input" do
      assert DateHelper.to_utc(nil) == nil
    end
  end

  describe "parse/1" do
    test "parses a valid ISO 8601 datetime string" do
      assert {:ok, ~U[2025-10-06 05:22:32Z]} = DateHelper.parse("2025-10-06T05:22:32Z")
    end

    test "returns error for invalid datetime string" do
      assert {:error, :invalid_datetime_format} = DateHelper.parse("not-a-date")
    end

    test "returns error for nil input" do
      assert {:error, :nil_datetime} = DateHelper.parse(nil)
    end

    test "parses datetime with offset" do
      assert {:ok, dt} = DateHelper.parse("2025-10-06T12:22:32+07:00")
      assert dt.year == 2025
      assert dt.month == 10
      assert dt.day == 6
    end
  end

  describe "supported_countries/0" do
    test "returns a list of country maps with required keys" do
      countries = DateHelper.supported_countries()

      assert is_list(countries)
      assert length(countries) > 0

      Enum.each(countries, fn country ->
        assert Map.has_key?(country, :code)
        assert Map.has_key?(country, :name)
        assert Map.has_key?(country, :timezone)
      end)
    end

    test "includes Indonesia" do
      countries = DateHelper.supported_countries()
      codes = Enum.map(countries, & &1.code)
      assert "ID" in codes
    end

    test "includes expected major country codes" do
      countries = DateHelper.supported_countries()
      codes = Enum.map(countries, & &1.code)

      assert "US" in codes
      assert "GB" in codes
      assert "JP" in codes
    end
  end
end
