defmodule Voile.Repo.Migrations.CreateItems do
  use Ecto.Migration

  def change do
    # Enable pg_trgm extension for faster ILIKE searches with trigram indexes
    execute "CREATE EXTENSION IF NOT EXISTS pg_trgm", "DROP EXTENSION IF EXISTS pg_trgm"

    create table(:items, primary_key: false) do
      add :id, :binary_id, primary_key: true, null: false
      add :item_code, :text
      add :inventory_code, :text
      add :location, :text
      add :status, :string
      add :condition, :string
      add :availability, :string
      add :price, :decimal, precision: 10, scale: 2
      add :acquisition_date, :date
      add :last_inventory_date, :date
      add :last_circulated, :utc_datetime
      add :rfid_tag, :string
      add :legacy_item_code, :text
      add :unit_id, references(:nodes, on_delete: :nilify_all)
      add :collection_id, references(:collections, on_delete: :delete_all, type: :binary_id)
      add :item_location_id, references(:mst_locations, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create unique_index(:items, [:item_code])
    create unique_index(:items, [:inventory_code])
    create unique_index(:items, [:rfid_tag])
    create index(:items, [:collection_id])
    create index(:items, [:location])
    create index(:items, [:legacy_item_code])

    # Add GIN trigram indexes for fast ILIKE pattern matching searches
    execute "CREATE INDEX items_item_code_trgm_idx ON items USING gin (item_code gin_trgm_ops)",
            "DROP INDEX IF EXISTS items_item_code_trgm_idx"

    execute "CREATE INDEX items_inventory_code_trgm_idx ON items USING gin (inventory_code gin_trgm_ops)",
            "DROP INDEX IF EXISTS items_inventory_code_trgm_idx"

    execute "CREATE INDEX items_location_trgm_idx ON items USING gin (location gin_trgm_ops)",
            "DROP INDEX IF EXISTS items_location_trgm_idx"
  end
end
