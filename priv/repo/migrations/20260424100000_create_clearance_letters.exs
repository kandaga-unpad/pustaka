defmodule Voile.Repo.Migrations.CreateClearanceLetters do
  use Ecto.Migration

  def change do
    create table(:clearance_letters, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :letter_number, :string, null: false
      add :sequence_number, :integer, null: false
      add :member_id, references(:users, type: :binary_id, on_delete: :restrict), null: false
      add :member_snapshot, :map, null: false
      add :generated_at, :utc_datetime, null: false
      add :is_revoked, :boolean, default: false, null: false
      add :revoked_at, :utc_datetime
      add :revoked_by_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :revoke_reason, :string

      timestamps(type: :utc_datetime)
    end

    create unique_index(:clearance_letters, [:letter_number])
    create unique_index(:clearance_letters, [:sequence_number])
    create index(:clearance_letters, [:member_id])
    create index(:clearance_letters, [:is_revoked])
  end
end
