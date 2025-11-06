defmodule Voile.Repo.Migrations.CreateCollections do
  use Ecto.Migration

  def change do
    create table(:collections, primary_key: false) do
      add :id, :binary_id, primary_key: true, null: false
      add :collection_code, :text, null: false
      add :title, :text, null: false
      add :description, :text
      add :thumbnail, :string
      add :status, :string, null: false, default: "draft"
      add :access_level, :string, null: false, default: "private"
      add :old_biblio_id, :integer
      add :type_id, references(:resource_class, on_delete: :nilify_all), null: false
      add :template_id, references(:resource_template, on_delete: :nilify_all)
      add :creator_id, references(:mst_creator, on_delete: :nilify_all), null: false
      add :unit_id, references(:nodes, on_delete: :nilify_all), null: false
      add :created_by_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :updated_by_id, references(:users, type: :binary_id, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    # Basic indexes
    create index(:collections, [:title])
    create index(:collections, [:type_id])
    create index(:collections, [:template_id])
    create index(:collections, [:creator_id])
    create index(:collections, [:unit_id])
    create index(:collections, [:status])
    create index(:collections, [:access_level])
    create index(:collections, [:created_by_id])
    create unique_index(:collections, [:collection_code])

    # Composite indexes for common query patterns
    create index(:collections, [:unit_id, :status], name: :collections_unit_status_idx)
    create index(:collections, [:creator_id, :status], name: :collections_creator_status_idx)

    # Partial index for published collections (public catalog)
    create index(:collections, [:type_id, :unit_id],
             where: "status = 'published'",
             name: :collections_published_idx
           )

    # Ordered index for alphabetical listing (using raw SQL)
    execute "CREATE INDEX collections_title_asc_idx ON collections (title ASC)",
            "DROP INDEX IF EXISTS collections_title_asc_idx"

    # GIN trigram indexes for fast ILIKE pattern matching searches
    execute "CREATE INDEX collections_title_trgm_idx ON collections USING gin (title gin_trgm_ops)",
            "DROP INDEX IF EXISTS collections_title_trgm_idx"

    execute "CREATE INDEX collections_description_trgm_idx ON collections USING gin (description gin_trgm_ops)",
            "DROP INDEX IF EXISTS collections_description_trgm_idx"

    execute "CREATE INDEX collections_code_trgm_idx ON collections USING gin (collection_code gin_trgm_ops)",
            "DROP INDEX IF EXISTS collections_code_trgm_idx"

    # Hash indexes for exact match queries
    execute "CREATE INDEX collections_status_hash_idx ON collections USING hash (status)",
            "DROP INDEX IF EXISTS collections_status_hash_idx"

    execute "CREATE INDEX collections_access_level_hash_idx ON collections USING hash (access_level)",
            "DROP INDEX IF EXISTS collections_access_level_hash_idx"

    # Covering index for quick listings (includes title for index-only scans)
    execute """
            CREATE INDEX collections_listing_covering_idx
            ON collections (unit_id, status)
            INCLUDE (title, thumbnail, collection_code)
            WHERE status = 'published'
            """,
            "DROP INDEX IF EXISTS collections_listing_covering_idx"

    # Composite unique index to ensure old_biblio_id is unique per unit
    # This prevents collisions when the same biblio_id exists in different units
    create unique_index(:collections, [:unit_id, :old_biblio_id],
             name: :collections_unit_id_old_biblio_id_index,
             where: "old_biblio_id IS NOT NULL"
           )

    # Increase statistics target for better query planning
    execute "ALTER TABLE collections ALTER COLUMN title SET STATISTICS 1000",
            "ALTER TABLE collections ALTER COLUMN title SET STATISTICS -1"

    alter table(:collections) do
      add :parent_id, references(:collections, type: :binary_id, on_delete: :nilify_all)
      add :sort_order, :integer, default: 1
      add :collection_type, :string
    end

    create index(:collections, [:parent_id])
    create index(:collections, [:sort_order])
    create index(:collections, [:collection_type])

    # Add trigram index for collection_type after column is created
    execute "CREATE INDEX collections_type_trgm_idx ON collections USING gin (collection_type gin_trgm_ops)",
            "DROP INDEX IF EXISTS collections_type_trgm_idx"
  end
end
