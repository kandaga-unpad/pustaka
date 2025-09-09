defmodule Voile.Repo.Migrations.CreateItems do
  use Ecto.Migration

  def change do
    create table(:items, primary_key: false) do
      add :id, :binary_id, primary_key: true, null: false
      add :item_code, :string
      add :inventory_code, :string
      add :location, :string
      add :status, :string
      add :condition, :string
      add :availability, :string
      add :price, :decimal, precision: 10, scale: 2
      add :acquisition_date, :date
      add :last_inventory_date, :date
      add :last_circulated, :naive_datetime
      add :rfid_tag, :string
      add :unit_id, references(:nodes, on_delete: :nilify_all)
      add :collection_id, references(:collections, on_delete: :delete_all, type: :binary_id)

      timestamps(type: :naive_datetime)
    end

    create unique_index(:items, [:item_code])
    create unique_index(:items, [:inventory_code])
    create unique_index(:items, [:rfid_tag])
    create index(:items, [:collection_id])
    create index(:items, [:location])
  end
end
