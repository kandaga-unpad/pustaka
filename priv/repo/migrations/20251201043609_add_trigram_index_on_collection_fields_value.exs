defmodule Voile.Repo.Migrations.AddTrigramIndexOnCollectionFieldsValue do
  use Ecto.Migration

  def change do
    # Add GIN trigram index for fast ILIKE pattern matching on collection_fields.value
    execute "CREATE INDEX collection_fields_value_trgm_idx ON collection_fields USING gin (value gin_trgm_ops)",
            "DROP INDEX IF EXISTS collection_fields_value_trgm_idx"
  end
end
