defmodule Voile.Repo.Migrations.CreateLibHolidays do
  use Ecto.Migration

  def change do
    create table(:lib_holidays, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      # Nullable for schedule entries
      add :holiday_date, :date, null: true
      add :holiday_type, :string, null: false
      add :is_recurring, :boolean, default: false, null: false
      add :description, :text
      add :is_active, :boolean, default: true, null: false

      # Unit/Branch reference - nullable for system-wide holidays
      add :unit_id, references(:nodes, on_delete: :delete_all), null: true

      # New fields for weekly schedule support
      add :day_of_week, :integer,
        null: true,
        comment: "Day of week (1=Monday, 7=Sunday) for recurring schedules"

      add :schedule_type, :string,
        null: false,
        default: "holiday",
        comment: "Type: holiday, schedule"

      timestamps(type: :naive_datetime)
    end

    # Indexes for holidays
    create index(:lib_holidays, [:holiday_date])
    create index(:lib_holidays, [:holiday_type])
    create index(:lib_holidays, [:is_active])
    create index(:lib_holidays, [:holiday_date, :is_active])
    create index(:lib_holidays, [:unit_id])
    create index(:lib_holidays, [:unit_id, :schedule_type])
    create index(:lib_holidays, [:unit_id, :is_active])

    # Indexes for schedules
    create index(:lib_holidays, [:day_of_week])
    create index(:lib_holidays, [:schedule_type])
    create index(:lib_holidays, [:schedule_type, :day_of_week])
    create index(:lib_holidays, [:schedule_type, :is_active])
    create index(:lib_holidays, [:unit_id, :schedule_type, :day_of_week])

    # Unique constraints - modified to include unit_id scope
    create unique_index(:lib_holidays, [:holiday_date, :holiday_type, :unit_id],
             where: "schedule_type = 'holiday'",
             name: :lib_holidays_date_type_unit_unique_index
           )

    create unique_index(:lib_holidays, [:day_of_week, :holiday_type, :unit_id],
             where: "schedule_type = 'schedule'",
             name: :lib_holidays_dow_type_unit_unique_index
           )

    # Check constraints for data integrity
    create constraint(:lib_holidays, :valid_day_of_week,
             check: "day_of_week IS NULL OR day_of_week BETWEEN 1 AND 7"
           )

    create constraint(:lib_holidays, :valid_schedule_type,
             check: "schedule_type IN ('holiday', 'schedule')"
           )

    # Ensure schedule entries have day_of_week and holiday entries have holiday_date
    create constraint(:lib_holidays, :schedule_requires_day_of_week,
             check:
               "(schedule_type = 'schedule' AND day_of_week IS NOT NULL) OR schedule_type != 'schedule'"
           )

    create constraint(:lib_holidays, :holiday_requires_date,
             check:
               "(schedule_type = 'holiday' AND holiday_date IS NOT NULL) OR schedule_type != 'holiday'"
           )
  end
end
