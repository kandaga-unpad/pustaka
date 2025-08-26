defmodule Voile.Repo.Migrations.CreateLibCirculationHistory do
  use Ecto.Migration

  def change do
    execute "CREATE TYPE circulation_event_type AS ENUM ('loan', 'return', 'renewal', 'reserve', 'cancel_reserve', 'fine_paid', 'fine_waived', 'member_created', 'member_updated', 'item_status_change');"

    create table(:lib_circulation_history, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :event_type, :circulation_event_type, null: false
      add :event_date, :utc_datetime, null: false
      add :description, :text
      add :old_value, :map
      add :new_value, :map
      add :ip_address, :string
      add :user_agent, :text

      add :member_id, references(:members, type: :binary_id)
      add :item_id, references(:items, type: :binary_id)
      add :transaction_id, references(:lib_transactions, type: :binary_id)
      add :reservation_id, references(:lib_reservations, type: :binary_id)
      add :fine_id, references(:lib_fines, type: :binary_id)
      add :processed_by_id, references(:users, type: :binary_id), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:lib_circulation_history, [:event_type])
    create index(:lib_circulation_history, [:event_date])
    create index(:lib_circulation_history, [:member_id])
    create index(:lib_circulation_history, [:item_id])
    create index(:lib_circulation_history, [:processed_by_id])
  end
end
