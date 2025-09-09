defmodule Mix.Tasks.Voile.SeedHolidays do
  @moduledoc """
  Mix task to seed holidays into the database.

  This task helps populate the lib_holidays table with common holidays
  for Indonesia and library-specific holidays.

  Usage:
      mix voile.seed_holidays
      mix voile.seed_holidays --year 2025
      mix voile.seed_holidays --year 2024 --type indonesian
      mix voile.seed_holidays --year 2025 --type library
  """

  use Mix.Task
  alias Voile.Schema.System.LibHolidays

  @shortdoc "Seed holidays into the database"

  def run(args) do
    Mix.Task.run("app.start")

    {opts, _, _} =
      OptionParser.parse(args,
        switches: [year: :integer, type: :string],
        aliases: [y: :year, t: :type]
      )

    current_year = Date.utc_today().year
    year = Keyword.get(opts, :year, current_year)
    holiday_type = Keyword.get(opts, :type, "all")

    IO.puts("🎄 Seeding holidays for year #{year}")
    IO.puts("#{String.duplicate("=", 50)}")

    case holiday_type do
      "indonesian" ->
        seed_indonesian_holidays(year)

      "library" ->
        seed_library_holidays(year)

      "all" ->
        seed_indonesian_holidays(year)
        seed_library_holidays(year)
        seed_custom_examples()

      _ ->
        Mix.shell().error("Invalid holiday type. Use 'indonesian', 'library', or 'all'")
    end

    IO.puts("\n✅ Holiday seeding completed!")
    IO.puts("\n💡 You can manage holidays via the web interface at:")
    IO.puts("   /manage/settings/holidays")
  end

  defp seed_indonesian_holidays(year) do
    IO.puts("\n🇮🇩 Seeding Indonesian public holidays for #{year}...")

    {success, errors} = LibHolidays.import_indonesian_holidays(year)

    IO.puts("   ✅ Successfully imported: #{success}")
    IO.puts("   ⚠️ Skipped (already exist): #{errors}")

    # Add some additional Indonesian holidays that vary by year
    additional_holidays = get_additional_indonesian_holidays(year)

    {add_success, add_errors} =
      Enum.reduce(additional_holidays, {0, 0}, fn {date, name, desc}, {success, errors} ->
        case LibHolidays.create_holiday(%{
               name: name,
               holiday_date: date,
               holiday_type: "public",
               description: desc,
               is_active: true,
               is_recurring: false
             }) do
          {:ok, _} -> {success + 1, errors}
          {:error, _} -> {success, errors + 1}
        end
      end)

    IO.puts("   📅 Additional holidays imported: #{add_success}")
    IO.puts("   ⚠️ Additional holidays skipped: #{add_errors}")
  end

  defp seed_library_holidays(year) do
    IO.puts("\n📚 Seeding library-specific holidays for #{year}...")

    {success, errors} = LibHolidays.import_library_holidays(year)

    IO.puts("   ✅ Successfully imported: #{success}")
    IO.puts("   ⚠️ Skipped (already exist): #{errors}")

    # Add additional library holidays
    library_holidays = [
      # Semester breaks
      {Date.new!(year, 7, 1), "Mid-Year Library Maintenance", "Annual maintenance and inventory"},
      {Date.new!(year, 12, 20), "Year-End Inventory",
       "Annual stock taking and system maintenance"},

      # Staff training days
      {Date.new!(year, 3, 15), "Staff Training Day", "Library staff professional development"},
      {Date.new!(year, 9, 15), "System Upgrade Day", "Library system maintenance"}
    ]

    {add_success, add_errors} =
      Enum.reduce(library_holidays, {0, 0}, fn {date, name, desc}, {success, errors} ->
        case LibHolidays.create_holiday(%{
               name: name,
               holiday_date: date,
               holiday_type: "library",
               description: desc,
               is_active: true,
               is_recurring: true
             }) do
          {:ok, _} -> {success + 1, errors}
          {:error, _} -> {success, errors + 1}
        end
      end)

    IO.puts("   📅 Additional library holidays: #{add_success}")
    IO.puts("   ⚠️ Additional holidays skipped: #{add_errors}")
  end

  defp seed_custom_examples do
    IO.puts("\n⭐ Seeding custom holiday examples...")

    custom_holidays = [
      # Example institutional holidays
      {Date.utc_today() |> Date.add(30), "University Anniversary",
       "Annual university celebration"},
      {Date.utc_today() |> Date.add(60), "Graduation Day", "University graduation ceremony"}
    ]

    {success, errors} =
      Enum.reduce(custom_holidays, {0, 0}, fn {date, name, desc}, {success, errors} ->
        case LibHolidays.create_holiday(%{
               name: name,
               holiday_date: date,
               holiday_type: "custom",
               description: desc,
               is_active: true,
               is_recurring: false
             }) do
          {:ok, _} -> {success + 1, errors}
          {:error, _} -> {success, errors + 1}
        end
      end)

    IO.puts("   ✅ Custom examples imported: #{success}")
    IO.puts("   ⚠️ Custom examples skipped: #{errors}")
  end

  # Get variable Indonesian holidays (these would ideally come from a calendar API)
  defp get_additional_indonesian_holidays(year) do
    [
      # Note: These are approximate dates and should be updated yearly
      # In a real system, you might want to integrate with a holiday API
      {Date.new!(year, 4, 22), "Eid al-Fitr Day 1", "Islamic holiday (dates vary)"},
      {Date.new!(year, 4, 23), "Eid al-Fitr Day 2", "Islamic holiday (dates vary)"},
      {Date.new!(year, 6, 29), "Eid al-Adha", "Islamic holiday (dates vary)"},
      {Date.new!(year, 7, 19), "Islamic New Year", "Islamic holiday (dates vary)"},
      {Date.new!(year, 9, 27), "Prophet Muhammad's Birthday", "Islamic holiday (dates vary)"},
      {Date.new!(year, 3, 22), "Day of Silence (Nyepi)", "Hindu holiday (dates vary)"},
      {Date.new!(year, 5, 1), "Labor Day", "International Workers' Day"}
    ]
  rescue
    # Handle invalid dates gracefully
    _ -> []
  end
end
