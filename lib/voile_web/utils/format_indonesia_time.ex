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

  @doc """
  Shifts a UTC DateTime to Asia/Jakarta (WIB, UTC+7).
  Returns the shifted DateTime, or the original if conversion fails.
  """
  def shift_to_jakarta(%DateTime{} = datetime) do
    case DateTime.shift_zone(datetime, "Asia/Jakarta") do
      {:ok, jakarta_datetime} -> jakarta_datetime
      {:error, _} -> datetime
    end
  end

  def format_indonesian_date(%DateTime{} = datetime) do
    day_of_week = get_day_of_week(datetime)
    month = get_month(datetime)

    "#{day_of_week}, #{datetime.day} #{month} #{datetime.year}"
  end

  def format_full_indonesian_date(%NaiveDateTime{} = naive_datetime) do
    naive_datetime
    |> DateTime.from_naive!("Etc/UTC")
    |> format_full_indonesian_date()
  end

  def format_full_indonesian_date(%Date{} = date) do
    day_of_week = get_day_of_week(date)
    month = get_month(date)

    "#{day_of_week}, #{date.day} #{month} #{date.year}"
  end

  def format_full_indonesian_date(%DateTime{} = datetime) do
    datetime = shift_to_jakarta(datetime)
    day_of_week = get_day_of_week(datetime)
    month = get_month(datetime)

    "#{day_of_week}, #{datetime.day} #{month} #{datetime.year} #{pad_zero(datetime.hour)}:#{pad_zero(datetime.minute)}"
  end

  defp get_day_of_week(%Date{} = date) do
    day_index = Date.day_of_week(date)
    adjusted_index = if day_index == 7, do: 0, else: day_index
    Enum.at(@days_of_week, adjusted_index)
  end

  defp get_day_of_week(%DateTime{} = datetime) do
    day_index = Date.day_of_week(DateTime.to_date(datetime))
    adjusted_index = if day_index == 7, do: 0, else: day_index
    Enum.at(@days_of_week, adjusted_index)
  end

  defp get_month(%Date{} = date) do
    Enum.at(@months, date.month - 1)
  end

  defp get_month(%DateTime{} = datetime) do
    Enum.at(@months, datetime.month - 1)
  end

  defp pad_zero(value) when value < 10 do
    "0#{value}"
  end

  defp pad_zero(value), do: "#{value}"
end
