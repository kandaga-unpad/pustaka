defmodule Voile.Repo.Migrations.AddRbacToAttachments do
  use Ecto.Migration

  def change do
    alter table(:attachments) do
      # Access control level
      add :access_level, :string, default: "public", null: false

      # Embargo dates
      add :embargo_start_date, :utc_datetime
      add :embargo_end_date, :utc_datetime

      # Audit fields
      add :access_settings_updated_by_id,
          references(:users, type: :binary_id, on_delete: :nilify_all)

      add :access_settings_updated_at, :utc_datetime
    end

    # Create table for role-based access
    create table(:attachment_role_access, primary_key: false) do
      add :id, :binary_id, primary_key: true, null: false

      add :attachment_id, references(:attachments, type: :binary_id, on_delete: :delete_all),
        null: false

      add :role_id, references(:roles, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    # Create table for user-specific access
    create table(:attachment_user_access, primary_key: false) do
      add :id, :binary_id, primary_key: true, null: false

      add :attachment_id, references(:attachments, type: :binary_id, on_delete: :delete_all),
        null: false

      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :granted_by_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :granted_at, :utc_datetime, null: false

      timestamps(type: :utc_datetime)
    end

    # Indexes
    create index(:attachments, [:access_level])
    create index(:attachments, [:embargo_start_date])
    create index(:attachments, [:embargo_end_date])
    create index(:attachments, [:access_settings_updated_by_id])

    create index(:attachment_role_access, [:attachment_id])
    create index(:attachment_role_access, [:role_id])

    create unique_index(:attachment_role_access, [:attachment_id, :role_id],
             name: :attachment_role_access_unique
           )

    create index(:attachment_user_access, [:attachment_id])
    create index(:attachment_user_access, [:user_id])
    create index(:attachment_user_access, [:granted_by_id])

    create unique_index(:attachment_user_access, [:attachment_id, :user_id],
             name: :attachment_user_access_unique
           )

    # Add check constraint for access_level
    create constraint(:attachments, :access_level_must_be_valid,
             check: "access_level IN ('public', 'limited', 'restricted')"
           )

    # Add check constraint for embargo dates
    create constraint(:attachments, :embargo_dates_must_be_valid,
             check:
               "embargo_start_date IS NULL OR embargo_end_date IS NULL OR embargo_start_date < embargo_end_date"
           )
  end
end
