defmodule Voile.Repo.Migrations.CreateItems do
  use Ecto.Migration

  def change do
    create table(:items, primary_key: false) do
      add :id, :binary_id, primary_key: true, null: false
      add :item_code, :text, null: false
      add :barcode, :text
      add :inventory_code, :text, null: false
      add :location, :text, null: false
      add :status, :string, null: false, default: "active"
      add :condition, :string, null: false, default: "good"
      add :availability, :string, null: false, default: "available"
      add :price, :decimal, precision: 10, scale: 2
      add :acquisition_date, :date
      add :last_inventory_date, :date
      add :last_circulated, :utc_datetime
      add :rfid_tag, :string
      add :legacy_item_code, :text
      add :unit_id, references(:nodes, on_delete: :nilify_all), null: false

      add :collection_id, references(:collections, on_delete: :delete_all, type: :binary_id),
        null: false

      add :item_location_id, references(:mst_locations, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    # Unique indexes
    create unique_index(:items, [:item_code])
    create unique_index(:items, [:inventory_code])
    create unique_index(:items, [:rfid_tag], where: "rfid_tag IS NOT NULL")
    create unique_index(:items, [:barcode], where: "barcode IS NOT NULL")

    # Basic indexes
    create index(:items, [:collection_id])
    create index(:items, [:unit_id])
    create index(:items, [:location])
    create index(:items, [:legacy_item_code])
    create index(:items, [:status])
    create index(:items, [:availability])

    # Composite indexes for common query patterns
    create index(:items, [:collection_id, :status, :availability],
             name: :items_collection_status_availability_idx
           )

    # Partial index for available items (most searched)
    create index(:items, [:collection_id],
             where: "status = 'active' AND availability = 'available'",
             name: :items_available_idx
           )

    # GIN trigram indexes for fast ILIKE pattern matching searches
    execute "CREATE INDEX items_item_code_trgm_idx ON items USING gin (item_code gin_trgm_ops)",
            "DROP INDEX IF EXISTS items_item_code_trgm_idx"

    execute "CREATE INDEX items_inventory_code_trgm_idx ON items USING gin (inventory_code gin_trgm_ops)",
            "DROP INDEX IF EXISTS items_inventory_code_trgm_idx"

    execute "CREATE INDEX items_location_trgm_idx ON items USING gin (location gin_trgm_ops)",
            "DROP INDEX IF EXISTS items_location_trgm_idx"

    execute "CREATE INDEX items_barcode_trgm_idx ON items USING gin (barcode gin_trgm_ops)",
            "DROP INDEX IF EXISTS items_barcode_trgm_idx"

    # Hash indexes for exact match queries (faster than btree for equality)
    execute "CREATE INDEX items_status_hash_idx ON items USING hash (status)",
            "DROP INDEX IF EXISTS items_status_hash_idx"

    # Covering index for catalog listing (includes item details for index-only scans)
    execute """
            CREATE INDEX items_catalog_covering_idx
            ON items (collection_id, status, availability)
            INCLUDE (item_code, barcode, location)
            WHERE status = 'active'
            """,
            "DROP INDEX IF EXISTS items_catalog_covering_idx"

    # Check constraints for data integrity
    execute """
            ALTER TABLE items ADD CONSTRAINT items_barcode_length_check
            CHECK (barcode IS NULL OR length(barcode) BETWEEN 10 AND 20)
            """,
            "ALTER TABLE items DROP CONSTRAINT IF EXISTS items_barcode_length_check"

    # Increase statistics target for better query planning
    execute "ALTER TABLE items ALTER COLUMN item_code SET STATISTICS 1000",
            "ALTER TABLE items ALTER COLUMN item_code SET STATISTICS -1"

    execute "ALTER TABLE items ALTER COLUMN barcode SET STATISTICS 1000",
            "ALTER TABLE items ALTER COLUMN barcode SET STATISTICS -1"

    # Add comments for documentation
    execute "COMMENT ON INDEX items_barcode_trgm_idx IS 'Trigram index for fuzzy barcode search'",
            "COMMENT ON INDEX items_barcode_trgm_idx IS NULL"

    execute "COMMENT ON INDEX items_catalog_covering_idx IS 'Covering index for catalog queries - includes item details'",
            "COMMENT ON INDEX items_catalog_covering_idx IS NULL"

    execute "COMMENT ON CONSTRAINT items_barcode_length_check ON items IS 'Ensures barcode is between 10-20 characters'",
            "COMMENT ON CONSTRAINT items_barcode_length_check ON items IS NULL"
  end
end
