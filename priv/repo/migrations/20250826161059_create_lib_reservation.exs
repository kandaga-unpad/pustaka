defmodule Voile.Repo.Migrations.CreateLibReservations do
  use Ecto.Migration

  def change do
    create table(:lib_reservations, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :reservation_date, :utc_datetime, null: false
      add :expiry_date, :utc_datetime
      add :notification_sent, :boolean, default: false
      add :status, :reservation_status, null: false
      add :priority, :integer, default: 1
      add :notes, :text
      add :pickup_date, :utc_datetime
      add :cancelled_date, :utc_datetime
      add :cancellation_reason, :text

      add :item_id, references(:items, on_delete: :nilify_all, type: :binary_id), null: false
      add :member_id, references(:users, on_delete: :nilify_all, type: :binary_id)
      add :collection_id, references(:collections, on_delete: :nilify_all, type: :binary_id)
      add :processed_by_id, references(:users, on_delete: :nilify_all, type: :binary_id)

      timestamps(type: :utc_datetime)
    end

    create index(:lib_reservations, [:item_id])
    create index(:lib_reservations, [:collection_id])
    create index(:lib_reservations, [:member_id])
    create index(:lib_reservations, [:status])
    create index(:lib_reservations, [:reservation_date])
    create index(:lib_reservations, [:expiry_date])
    create index(:lib_reservations, [:priority])

    create constraint(:lib_reservations, :item_or_collection_check,
             check: "item_id IS NOT NULL OR collection_id IS NOT NULL"
           )
  end
end
