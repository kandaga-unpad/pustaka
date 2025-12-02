defmodule Voile.Repo.Migrations.AddTrigramIndexesOnMetadataProperties do
  use Ecto.Migration

  def change do
    # Add GIN trigram indexes for fast ILIKE pattern matching on metadata_properties
    execute "CREATE INDEX metadata_properties_label_trgm_idx ON metadata_properties USING gin (label gin_trgm_ops)",
            "DROP INDEX IF EXISTS metadata_properties_label_trgm_idx"

    execute "CREATE INDEX metadata_properties_local_name_trgm_idx ON metadata_properties USING gin (local_name gin_trgm_ops)",
            "DROP INDEX IF EXISTS metadata_properties_local_name_trgm_idx"
  end
end
