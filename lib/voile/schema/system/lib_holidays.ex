defmodule Voile.Schema.System.LibHolidays do
  @moduledoc """
  Context module for managing library holidays and weekly schedules for business day calculations.

  This module provides functions to:
  - Manage holidays (specific dates like Christmas, Independence Day)
  - Configure weekly schedules (which days of the week are business days)
  - Calculate business days excluding configured non-business days and holidays
  - Import common holidays
  - Validate holiday and schedule configurations

  The system supports two types of entries:
  - `schedule_type: "holiday"` - Specific holiday dates
  - `schedule_type: "schedule"` - Weekly recurring schedule patterns

  This unified approach allows flexible customization of:
  - Which days of the week are business days (not just Mon-Fri)
  - Specific holiday dates that override normal schedule
  - Different types of holidays (public, library, custom)
  """

  import Ecto.Query
  alias Voile.Repo
  alias Voile.Schema.System.LibHoliday

  ## Holiday CRUD Operations

  @doc """
  Returns the list of all holidays.
  """
  def list_holidays do
    LibHoliday
    |> where([h], h.schedule_type == "holiday")
    |> order_by([h], desc: h.holiday_date)
    |> Repo.all()
  end

  @doc """
  Returns the list of holidays with pagination.
  """
  def list_holidays_paginated(page \\ 1, per_page \\ 20) do
    offset = (page - 1) * per_page

    query =
      from h in LibHoliday,
        where: h.schedule_type == "holiday",
        order_by: [desc: h.holiday_date],
        offset: ^offset,
        limit: ^per_page

    holidays = Repo.all(query)

    total_count =
      from(h in LibHoliday, where: h.schedule_type == "holiday")
      |> Repo.aggregate(:count, :id)

    total_pages = div(total_count + per_page - 1, per_page)

    {holidays, total_pages}
  end

  @doc """
  Gets a single holiday.
  """
  def get_holiday!(id), do: Repo.get!(LibHoliday, id)

  @doc """
  Creates a holiday.
  """
  def create_holiday(attrs \\ %{}) do
    # Ensure schedule_type defaults to "holiday"
    attrs = Map.put_new(attrs, :schedule_type, "holiday")

    %LibHoliday{}
    |> LibHoliday.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a holiday.
  """
  def update_holiday(%LibHoliday{} = holiday, attrs) do
    holiday
    |> LibHoliday.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a holiday.
  """
  def delete_holiday(%LibHoliday{} = holiday) do
    Repo.delete(holiday)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking holiday changes.
  """
  def change_holiday(%LibHoliday{} = holiday, attrs \\ %{}) do
    LibHoliday.changeset(holiday, attrs)
  end

  ## Business Day Calculations

  @doc """
  Calculate business days between two dates, excluding weekends and holidays.
  """
  def business_days_between(start_date, end_date, unit_id \\ nil) do
    LibHoliday.business_days_between(start_date, end_date, unit_id)
  end

  @doc """
  Check if a given date is a holiday (weekend or custom holiday).
  """
  def is_holiday?(date, unit_id \\ nil) do
    LibHoliday.is_holiday?(date, unit_id)
  end

  @doc """
  Check if a given date is a weekend.
  """
  def is_weekend?(date) do
    LibHoliday.is_weekend?(date)
  end

  @doc """
  Get all holidays within a date range.
  """
  def get_holidays_in_range(start_date, end_date) do
    LibHoliday.get_holidays_in_range(start_date, end_date)
  end

  @doc """
  Get upcoming holidays for the next N days.
  """
  def get_upcoming_holidays(days \\ 30) do
    start_date = Date.utc_today()
    end_date = Date.add(start_date, days)
    get_holidays_in_range(start_date, end_date)
  end

  ## Holiday Import Functions

  @doc """
  Import common Indonesian public holidays for a given year.
  """
  def import_indonesian_holidays(year) do
    holidays = [
      # Fixed annual holidays
      {Date.new!(year, 1, 1), "New Year's Day", "public"},
      {Date.new!(year, 8, 17), "Indonesian Independence Day", "public"},
      {Date.new!(year, 12, 25), "Christmas Day", "public"}

      # Note: Religious holidays vary by year and should be added manually
      # or imported from a reliable calendar API
    ]

    Enum.reduce(holidays, {0, 0}, fn {date, name, type}, {success, errors} ->
      case create_holiday(%{
             name: name,
             holiday_date: date,
             holiday_type: type,
             description: "Indonesian public holiday",
             is_active: true,
             is_recurring: true
           }) do
        {:ok, _} -> {success + 1, errors}
        {:error, _} -> {success, errors + 1}
      end
    end)
  end

  @doc """
  Import common library holidays (e.g., inventory days, maintenance days).
  """
  def import_library_holidays(year) do
    holidays = [
      # Library inventory days (usually at year end)
      {Date.new!(year, 12, 31), "Library Inventory Day", "library"}
      # Add more library-specific holidays as needed
    ]

    Enum.reduce(holidays, {0, 0}, fn {date, name, type}, {success, errors} ->
      case create_holiday(%{
             name: name,
             holiday_date: date,
             holiday_type: type,
             description: "Library operational holiday",
             is_active: true,
             is_recurring: true
           }) do
        {:ok, _} -> {success + 1, errors}
        {:error, _} -> {success, errors + 1}
      end
    end)
  end

  ## Utility Functions

  @doc """
  Calculate the next business day from a given date.
  """
  def next_business_day(%Date{} = date) do
    next_day = Date.add(date, 1)

    if is_holiday?(next_day) do
      next_business_day(next_day)
    else
      next_day
    end
  end

  def next_business_day(%DateTime{} = datetime) do
    datetime
    |> DateTime.to_date()
    |> next_business_day()
  end

  @doc """
  Add business days to a date, skipping weekends and holidays.
  """
  def add_business_days(%Date{} = date, days) when days >= 0 do
    if days == 0 do
      date
    else
      next_day = Date.add(date, 1)

      if is_holiday?(next_day) do
        add_business_days(next_day, days)
      else
        add_business_days(next_day, days - 1)
      end
    end
  end

  def add_business_days(%DateTime{} = datetime, days) do
    result_date =
      datetime
      |> DateTime.to_date()
      |> add_business_days(days)

    %{datetime | year: result_date.year, month: result_date.month, day: result_date.day}
  end

  @doc """
  Get holiday statistics for reporting.
  """
  def get_holiday_stats do
    current_year = Date.utc_today().year

    query =
      from h in LibHoliday,
        where:
          fragment("EXTRACT(year FROM ?)", h.holiday_date) == ^current_year and
            h.schedule_type == "holiday",
        group_by: h.holiday_type,
        select: {h.holiday_type, count(h.id)}

    type_counts = Repo.all(query) |> Enum.into(%{})

    %{
      total_holidays: Map.values(type_counts) |> Enum.sum(),
      public_holidays: Map.get(type_counts, "public", 0),
      library_holidays: Map.get(type_counts, "library", 0),
      custom_holidays: Map.get(type_counts, "custom", 0),
      current_year: current_year
    }
  end

  ## Weekly Schedule Management

  @doc """
  Get the current weekly schedule configuration.
  """
  def get_weekly_schedule(unit_id \\ nil) do
    LibHoliday.get_weekly_schedule(unit_id)
  end

  @doc """
  Set up default weekly schedule (Monday-Friday business, Saturday-Sunday non-business).
  """
  def setup_default_weekly_schedule(unit_id \\ nil) do
    LibHoliday.setup_default_weekly_schedule(unit_id)
  end

  @doc """
  Update a specific day's business status in the weekly schedule.
  """
  def update_day_schedule(day_of_week, is_business_day, description \\ nil, unit_id \\ nil) do
    LibHoliday.update_day_schedule(day_of_week, is_business_day, description, unit_id)
  end

  @doc """
  Get business days for the current week.
  """
  def get_business_days do
    LibHoliday.get_business_days()
  end

  @doc """
  Get non-business days for the current week.
  """
  def get_non_business_days do
    LibHoliday.get_non_business_days()
  end

  @doc """
  Returns the list of weekly schedule configurations.
  """
  def list_schedule_configurations do
    LibHoliday
    |> where([h], h.schedule_type == "schedule")
    |> order_by([h], asc: h.day_of_week)
    |> Repo.all()
  end

  @doc """
  Creates a new schedule configuration.
  """
  def create_schedule(attrs \\ %{}) do
    # Ensure schedule_type is set to "schedule"
    attrs = Map.put_new(attrs, :schedule_type, "schedule")

    %LibHoliday{}
    |> LibHoliday.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a schedule configuration.
  """
  def update_schedule(%LibHoliday{schedule_type: "schedule"} = schedule, attrs) do
    schedule
    |> LibHoliday.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a schedule configuration.
  """
  def delete_schedule(%LibHoliday{schedule_type: "schedule"} = schedule) do
    Repo.delete(schedule)
  end

  @doc """
  Get schedule configuration for a specific day of week.
  """
  def get_day_schedule(day_of_week) when day_of_week in 1..7 do
    LibHoliday
    |> where([h], h.schedule_type == "schedule" and h.day_of_week == ^day_of_week)
    |> Repo.one()
  end

  @doc """
  Check if library operates on a specific day of week based on schedule.
  """
  def is_business_day?(day_of_week) when day_of_week in 1..7 do
    case get_day_schedule(day_of_week) do
      nil ->
        # Default: Monday-Friday business, Saturday-Sunday non-business
        day_of_week in [1, 2, 3, 4, 5]

      schedule ->
        schedule.holiday_type == "business" and schedule.is_active
    end
  end
end
