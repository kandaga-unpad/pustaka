defmodule VoileWeb.Utils.FormatIndonesiaTime do
  @days_of_week ["Minggu", "Senin", "Selasa", "Rabu", "Kamis", "Jumat", "Sabtu"]
  @months [
    "Januari",
    "Februari",
    "Maret",
    "April",
    "Mei",
    "Juni",
    "Juli",
    "Agustus",
    "September",
    "Oktober",
    "November",
    "Desember"
  ]

  def format_utc_to_jakarta(datetime) do
    case DateTime.shift_zone(datetime, "Asia/Jakarta") do
      {:ok, jakarta_datetime} ->
        format_full_indonesian_date(jakarta_datetime)

      {:error, reason} ->
        raise "Failed to convert to Jakarta time: #{inspect(reason)}"
    end
  end

  # Safe version that returns {:ok, formatted_string} or {:error, reason}
  def safe_format_utc_to_jakarta(datetime) do
    case DateTime.shift_zone(datetime, "Asia/Jakarta") do
      {:ok, jakarta_datetime} ->
        {:ok, format_full_indonesian_date(jakarta_datetime)}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def format_indonesian_date(%DateTime{} = datetime) do
    day_of_week = get_day_of_week(datetime)
    month = get_month(datetime)

    "#{day_of_week}, #{datetime.day} #{month} #{datetime.year}"
  end

  # Handle NaiveDateTime as well
  def format_indonesian_date(%NaiveDateTime{} = naive_datetime) do
    # Convert NaiveDateTime to DateTime first
    datetime = DateTime.from_naive!(naive_datetime, "Asia/Jakarta")
    format_indonesian_date(datetime)
  end

  def format_full_indonesian_date(%DateTime{} = datetime) do
    day_of_week = get_day_of_week(datetime)
    month = get_month(datetime)

    "#{day_of_week}, #{datetime.day} #{month} #{datetime.year} #{pad_zero(datetime.hour)}:#{pad_zero(datetime.minute)}"
  end

  def format_full_indonesian_date(%NaiveDateTime{} = naive_datetime) do
    # Convert NaiveDateTime to DateTime first
    datetime = DateTime.from_naive!(naive_datetime, "Asia/Jakarta")
    format_full_indonesian_date(datetime)
  end

  defp get_day_of_week(%DateTime{} = datetime) do
    day_index = Date.day_of_week(DateTime.to_date(datetime))
    # Convert from ISO day (1=Monday) to our array index (0=Sunday)
    adjusted_index = if day_index == 7, do: 0, else: day_index
    Enum.at(@days_of_week, adjusted_index)
  end

  defp get_month(%DateTime{} = datetime) do
    Enum.at(@months, datetime.month - 1)
  end

  defp pad_zero(value) when value < 10 do
    "0#{value}"
  end

  defp pad_zero(value), do: "#{value}"
end
