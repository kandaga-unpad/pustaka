defmodule Voile.Repo.Migrations.CreateTransferRequests do
  use Ecto.Migration

  def change do
    create table(:transfer_requests, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :item_id, references(:items, type: :binary_id, on_delete: :delete_all), null: false
      add :from_node_id, references(:nodes, on_delete: :restrict)
      add :to_node_id, references(:nodes, on_delete: :restrict), null: false
      add :from_location, :string
      add :to_location, :string, null: false
      add :status, :string, null: false, default: "pending"
      add :reason, :text
      add :notes, :text

      add :requested_by_id, references(:users, type: :binary_id, on_delete: :restrict),
        null: false

      add :reviewed_by_id, references(:users, type: :binary_id, on_delete: :restrict)
      add :reviewed_at, :utc_datetime
      add :completed_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:transfer_requests, [:item_id])
    create index(:transfer_requests, [:from_node_id])
    create index(:transfer_requests, [:to_node_id])
    create index(:transfer_requests, [:status])
    create index(:transfer_requests, [:requested_by_id])
    create index(:transfer_requests, [:reviewed_by_id])
  end
end
