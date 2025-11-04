defmodule Voile.Repo.Migrations.AddManualSuspensionToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :manually_suspended, :boolean, default: false, null: false
      add :suspension_reason, :text
      add :suspended_at, :utc_datetime
      add :suspended_by_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :suspension_ends_at, :utc_datetime
    end

    create index(:users, [:manually_suspended])
    create index(:users, [:suspended_by_id])
  end
end
