defmodule Voile.Schema.System.LibHoliday do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  # ETS cache for holiday lookups
  @cache_table :lib_holiday_cache
  # 1 hour in seconds
  @cache_ttl 3600

  schema "lib_holidays" do
    field :name, :string
    field :holiday_date, :date
    field :holiday_type, :string
    field :is_recurring, :boolean, default: false
    field :description, :string
    field :is_active, :boolean, default: true

    # New fields for weekly schedule support
    # 1=Monday, 7=Sunday (ISO 8601)
    field :day_of_week, :integer
    # "holiday", "schedule"
    field :schedule_type, :string

    # Unit/Branch reference for multi-unit libraries
    # Node primary keys are integer/bigint; override module-level @foreign_key_type
    belongs_to :unit, Voile.Schema.System.Node, foreign_key: :unit_id, type: :integer

    timestamps(type: :utc_datetime)
  end

  # Initialize ETS cache table if it doesn't exist
  defp ensure_cache_table do
    unless :ets.whereis(@cache_table) != :undefined do
      :ets.new(@cache_table, [:set, :public, :named_table, read_concurrency: true])
    end
  end

  # Get from cache or compute and cache
  defp cached_lookup(key, compute_fn) do
    ensure_cache_table()

    case :ets.lookup(@cache_table, key) do
      [{^key, value, timestamp}] ->
        # Check if cache is still valid
        if :os.system_time(:second) - timestamp < @cache_ttl do
          value
        else
          # Cache expired, recompute
          value = compute_fn.()
          :ets.insert(@cache_table, {key, value, :os.system_time(:second)})
          value
        end

      [] ->
        # Not in cache, compute and store
        value = compute_fn.()
        :ets.insert(@cache_table, {key, value, :os.system_time(:second)})
        value
    end
  end

  # Clear cache (useful after updating holidays)
  def clear_cache do
    if :ets.whereis(@cache_table) != :undefined do
      :ets.delete_all_objects(@cache_table)
    end
  end

  @doc """
  Holiday and schedule changeset for creating and updating entries.

  Schedule Types:
  - "holiday" - Specific date holidays (uses holiday_date field)
  - "schedule" - Weekly recurring schedule (uses day_of_week field)

  Holiday Types (for schedule_type: "holiday"):
  - "public" - Public holidays (national/local government holidays)
  - "library" - Library-specific holidays (closure days, maintenance days)
  - "custom" - Custom holidays defined by the library

  Holiday Types (for schedule_type: "schedule"):
  - "non_business" - Regular non-business days (e.g., weekends)
  - "business" - Regular business days (for reference/override)
  """
  def changeset(lib_holiday, attrs) do
    lib_holiday
    |> cast(attrs, [
      :name,
      :holiday_date,
      :holiday_type,
      :is_recurring,
      :description,
      :is_active,
      :day_of_week,
      :schedule_type,
      :unit_id
    ])
    |> validate_required([:name, :holiday_type, :schedule_type])
    |> validate_inclusion(:schedule_type, ["holiday", "schedule"])
    |> validate_holiday_fields()
    |> validate_schedule_fields()
    |> validate_inclusion(:holiday_type, [
      "public",
      "library",
      "custom",
      "non_business",
      "business"
    ])
    |> validate_length(:name, min: 2, max: 100)
    |> validate_length(:description, max: 255)
    |> foreign_key_constraint(:unit_id)
    |> unique_constraint([:holiday_date, :holiday_type, :unit_id],
      name: :lib_holidays_date_type_unit_unique_index,
      message: "Holiday already exists for this date, type, and unit"
    )
    |> unique_constraint([:day_of_week, :holiday_type, :unit_id],
      name: :lib_holidays_dow_type_unit_unique_index,
      message: "Schedule already exists for this day, type, and unit"
    )
  end

  # Validate fields specific to holiday entries
  defp validate_holiday_fields(changeset) do
    schedule_type = get_field(changeset, :schedule_type)

    if schedule_type == "holiday" do
      changeset
      |> validate_required([:holiday_date])
      # Clear day_of_week for holidays
      |> put_change(:day_of_week, nil)
    else
      changeset
    end
  end

  # Validate fields specific to schedule entries
  defp validate_schedule_fields(changeset) do
    schedule_type = get_field(changeset, :schedule_type)

    if schedule_type == "schedule" do
      changeset
      |> validate_required([:day_of_week])
      |> validate_inclusion(:day_of_week, 1..7,
        message: "Day of week must be 1-7 (Monday-Sunday)"
      )
      # Clear holiday_date for schedules
      |> put_change(:holiday_date, nil)
      # Schedules are always recurring
      |> put_change(:is_recurring, true)
    else
      changeset
    end
  end

  @doc """
  Checks if a given date is a holiday or non-business day.
  This includes both specific holidays and weekly schedule non-business days.
  Considers both unit-specific and system-wide rules.
  Uses ETS caching to avoid repeated database queries.
  """
  def is_holiday?(date, unit_id \\ nil)

  def is_holiday?(%Date{} = date, unit_id) do
    cache_key = {:is_holiday, date, unit_id}

    cached_lookup(cache_key, fn ->
      # Check weekly schedule first (more efficient)
      is_non_business_day_by_schedule?(date, unit_id) or is_specific_holiday?(date, unit_id)
    end)
  end

  def is_holiday?(%DateTime{} = datetime, unit_id) do
    datetime |> DateTime.to_date() |> is_holiday?(unit_id)
  end

  def is_holiday?(_, _), do: false

  @doc """
  Checks if a date is a non-business day according to the weekly schedule.
  This replaces the old hardcoded weekend check.
  Checks both unit-specific and system-wide schedules.
  Uses caching to avoid repeated queries for the same day of week.
  """
  def is_non_business_day_by_schedule?(date, unit_id \\ nil)

  def is_non_business_day_by_schedule?(%Date{} = date, unit_id) do
    day_of_week = Date.day_of_week(date)
    cache_key = {:schedule, day_of_week, unit_id}

    cached_lookup(cache_key, fn ->
      import Ecto.Query
      alias Voile.Repo

      is_nil_unit = is_nil(unit_id)

      if is_nil_unit do
        query =
          from h in __MODULE__,
            where:
              h.schedule_type == "schedule" and
                h.day_of_week == ^day_of_week and
                h.holiday_type == "non_business" and
                h.is_active == true and
                is_nil(h.unit_id)

        Repo.exists?(query)
      else
        # Check unit-specific schedule first; if none, fall back to system-wide
        unit_query =
          from h in __MODULE__,
            where:
              h.schedule_type == "schedule" and
                h.day_of_week == ^day_of_week and
                h.holiday_type == "non_business" and
                h.is_active == true and
                h.unit_id == type(^unit_id, :integer)

        if Repo.exists?(unit_query) do
          true
        else
          system_query =
            from h in __MODULE__,
              where:
                h.schedule_type == "schedule" and
                  h.day_of_week == ^day_of_week and
                  h.holiday_type == "non_business" and
                  h.is_active == true and
                  is_nil(h.unit_id)

          Repo.exists?(system_query)
        end
      end
    end)
  end

  def is_non_business_day_by_schedule?(%DateTime{} = datetime, unit_id) do
    datetime |> DateTime.to_date() |> is_non_business_day_by_schedule?(unit_id)
  end

  def is_non_business_day_by_schedule?(_, _), do: false

  @doc """
  Checks if a date is a specific holiday from the database.
  Checks both unit-specific and system-wide holidays.
  Uses caching to avoid repeated queries for the same date.
  """
  def is_specific_holiday?(date, unit_id \\ nil)

  def is_specific_holiday?(%Date{} = date, unit_id) do
    cache_key = {:specific_holiday, date, unit_id}

    cached_lookup(cache_key, fn ->
      import Ecto.Query
      alias Voile.Repo

      is_nil_unit = is_nil(unit_id)

      if is_nil_unit do
        query =
          from h in __MODULE__,
            where:
              h.schedule_type == "holiday" and
                h.holiday_date == ^date and
                h.is_active == true and
                is_nil(h.unit_id)

        Repo.exists?(query)
      else
        # Check unit-specific holiday first, then fall back to system-wide
        unit_query =
          from h in __MODULE__,
            where:
              h.schedule_type == "holiday" and
                h.holiday_date == ^date and
                h.is_active == true and
                h.unit_id == type(^unit_id, :integer)

        if Repo.exists?(unit_query) do
          true
        else
          system_query =
            from h in __MODULE__,
              where:
                h.schedule_type == "holiday" and
                  h.holiday_date == ^date and
                  h.is_active == true and
                  is_nil(h.unit_id)

          Repo.exists?(system_query)
        end
      end
    end)
  end

  def is_specific_holiday?(%DateTime{} = datetime, unit_id) do
    datetime |> DateTime.to_date() |> is_specific_holiday?(unit_id)
  end

  def is_specific_holiday?(_, _), do: false

  @doc """
  Legacy function - checks if a date is a weekend (Saturday or Sunday).
  Now uses the weekly schedule system, but falls back to hardcoded if no schedule exists.
  """
  def is_weekend?(%Date{} = date) do
    # First check if there are any weekly schedules configured
    if has_weekly_schedule?() do
      is_non_business_day_by_schedule?(date)
    else
      # Fallback to hardcoded Saturday/Sunday for backward compatibility
      day_of_week = Date.day_of_week(date)
      # Saturday = 6, Sunday = 7
      day_of_week == 6 or day_of_week == 7
    end
  end

  def is_weekend?(%DateTime{} = datetime) do
    datetime |> DateTime.to_date() |> is_weekend?()
  end

  def is_weekend?(_), do: false

  @doc """
  Check if weekly schedule has been configured.
  """
  def has_weekly_schedule? do
    import Ecto.Query
    alias Voile.Repo

    query =
      from h in __MODULE__,
        where: h.schedule_type == "schedule",
        limit: 1

    Repo.exists?(query)
  end

  @doc """
  Checks if a date is a custom holiday from the database.
  @deprecated Use is_specific_holiday?/1 instead
  """
  def is_custom_holiday?(date) do
    is_specific_holiday?(date)
  end

  @doc """
  Get all active holidays within a date range.
  """
  def get_holidays_in_range(start_date, end_date) do
    import Ecto.Query
    alias Voile.Repo

    from(h in __MODULE__,
      where:
        h.holiday_date >= ^start_date and
          h.holiday_date <= ^end_date and
          h.is_active == true,
      order_by: [asc: h.holiday_date]
    )
    |> Repo.all()
  end

  @doc """
  Calculate business days between two dates, excluding weekends and holidays.
  This is the core function used for fine calculation.
  """
  def business_days_between(start_date, end_date, unit_id \\ nil)

  def business_days_between(%Date{} = start_date, %Date{} = end_date, unit_id) do
    if Date.compare(start_date, end_date) == :gt do
      0
    else
      start_date
      |> Date.range(end_date)
      |> Enum.count(fn date -> not is_holiday?(date, unit_id) end)
    end
  end

  def business_days_between(%DateTime{} = start_datetime, %DateTime{} = end_datetime, unit_id) do
    start_date = DateTime.to_date(start_datetime)
    end_date = DateTime.to_date(end_datetime)
    business_days_between(start_date, end_date, unit_id)
  end

  def business_days_between(_, _, _), do: 0

  ## Weekly Schedule Management Functions

  @doc """
  Get the current weekly schedule configuration.
  Returns a map with day names as keys and business status as values.
  """
  def get_weekly_schedule(unit_id \\ nil) do
    import Ecto.Query
    alias Voile.Repo
    # Load system-wide schedule as base
    system_schedules =
      from(h in __MODULE__,
        where: h.schedule_type == "schedule" and h.is_active == true and is_nil(h.unit_id),
        select: {h.day_of_week, h.holiday_type}
      )
      |> Repo.all()
      |> Enum.into(%{})

    schedules =
      if is_nil(unit_id) do
        system_schedules
      else
        # Load unit-specific schedule and overlay on top of system-wide schedule
        unit_schedules =
          from(h in __MODULE__,
            where:
              h.schedule_type == "schedule" and h.is_active == true and
                h.unit_id == type(^unit_id, :integer),
            select: {h.day_of_week, h.holiday_type}
          )
          |> Repo.all()
          |> Enum.into(%{})

        Map.merge(system_schedules, unit_schedules)
      end

    # Create full week schedule with defaults
    day_names = [
      {1, "Monday"},
      {2, "Tuesday"},
      {3, "Wednesday"},
      {4, "Thursday"},
      {5, "Friday"},
      {6, "Saturday"},
      {7, "Sunday"}
    ]

    Enum.map(day_names, fn {day_num, day_name} ->
      # Default to business day
      status = Map.get(schedules, day_num, "business")

      %{
        day_of_week: day_num,
        day_name: day_name,
        is_business_day: status == "business",
        status: status
      }
    end)
  end

  @doc """
  Set up default weekly schedule (Monday-Friday business, Saturday-Sunday non-business).
  """
  def setup_default_weekly_schedule(unit_id \\ nil) do
    import Ecto.Query
    alias Voile.Repo

    # Clear existing schedule for this unit
    if is_nil(unit_id) do
      from(h in __MODULE__, where: h.schedule_type == "schedule" and is_nil(h.unit_id))
      |> Repo.delete_all()
    else
      from(h in __MODULE__,
        where: h.schedule_type == "schedule" and h.unit_id == type(^unit_id, :integer)
      )
      |> Repo.delete_all()
    end

    # Create default schedule
    default_schedule = [
      {1, "Monday", "business"},
      {2, "Tuesday", "business"},
      {3, "Wednesday", "business"},
      {4, "Thursday", "business"},
      {5, "Friday", "business"},
      {6, "Saturday", "non_business"},
      {7, "Sunday", "non_business"}
    ]

    unit_suffix = if unit_id, do: " (Specific for Unit : #{unit_id})", else: " (System Wide)"

    Enum.each(default_schedule, fn {day_num, day_name, status} ->
      %__MODULE__{
        name: "#{day_name} Schedule#{unit_suffix}",
        day_of_week: day_num,
        schedule_type: "schedule",
        holiday_type: status,
        description: "Weekly recurring #{status} day",
        is_active: true,
        is_recurring: true,
        unit_id: unit_id
      }
      |> Repo.insert!(on_conflict: :nothing)
    end)
  end

  @doc """
  Update a specific day's business status in the weekly schedule.
  """
  def update_day_schedule(day_of_week, is_business_day, description \\ nil, unit_id \\ nil)
      when is_integer(day_of_week) and day_of_week >= 1 and day_of_week <= 7 do
    import Ecto.Query
    alias Voile.Repo

    day_names = %{
      1 => "Monday",
      2 => "Tuesday",
      3 => "Wednesday",
      4 => "Thursday",
      5 => "Friday",
      6 => "Saturday",
      7 => "Sunday"
    }

    day_name = Map.get(day_names, day_of_week)
    holiday_type = if is_business_day, do: "business", else: "non_business"
    unit_suffix = if unit_id, do: " (Specific to Unit : #{unit_id})", else: " (System Wide)"

    # Try to find existing schedule entry
    existing =
      if is_nil(unit_id) do
        from(h in __MODULE__,
          where:
            h.schedule_type == "schedule" and h.day_of_week == ^day_of_week and is_nil(h.unit_id)
        )
        |> Repo.one()
      else
        from(h in __MODULE__,
          where:
            h.schedule_type == "schedule" and h.day_of_week == ^day_of_week and
              h.unit_id == type(^unit_id, :integer)
        )
        |> Repo.one()
      end

    attrs = %{
      name: "#{day_name} Schedule#{unit_suffix}",
      day_of_week: day_of_week,
      schedule_type: "schedule",
      holiday_type: holiday_type,
      description: description || "Weekly recurring #{holiday_type} day",
      is_active: true,
      is_recurring: true,
      unit_id: unit_id
    }

    case existing do
      nil ->
        # Create new schedule entry
        %__MODULE__{}
        |> changeset(attrs)
        |> Repo.insert()

      schedule ->
        # Update existing schedule entry
        schedule
        |> changeset(attrs)
        |> Repo.update()
    end
  end

  @doc """
  Get business days for the current week.
  Returns list of day numbers that are business days.
  """
  def get_business_days do
    get_weekly_schedule()
    |> Enum.filter(fn day -> day.is_business_day end)
    |> Enum.map(fn day -> day.day_of_week end)
  end

  @doc """
  Get non-business days for the current week.
  Returns list of day numbers that are non-business days.
  """
  def get_non_business_days do
    get_weekly_schedule()
    |> Enum.filter(fn day -> not day.is_business_day end)
    |> Enum.map(fn day -> day.day_of_week end)
  end
end
