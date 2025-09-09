defmodule Voile.Repo.Migrations.CreateSystemLogs do
  use Ecto.Migration

  def change do
    create table(:system_logs, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :log_type, :string
      add :log_location, :string
      add :log_msg, :text
      add :log_date, :utc_datetime
      add :owner_id, references(:users, on_delete: :nothing, type: :binary_id)

      timestamps(type: :utc_datetime)
    end

    create index(:system_logs, [:owner_id])
  end
end
