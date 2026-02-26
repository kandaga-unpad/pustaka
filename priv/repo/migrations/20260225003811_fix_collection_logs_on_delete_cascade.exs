defmodule Voile.Repo.Migrations.FixCollectionLogsOnDeleteCascade do
  use Ecto.Migration

  def up do
    execute """
    ALTER TABLE collection_logs
      DROP CONSTRAINT IF EXISTS collection_logs_collection_id_fkey,
      ADD CONSTRAINT collection_logs_collection_id_fkey
        FOREIGN KEY (collection_id)
        REFERENCES collections(id)
        ON DELETE CASCADE
    """
  end

  def down do
    execute """
    ALTER TABLE collection_logs
      DROP CONSTRAINT IF EXISTS collection_logs_collection_id_fkey,
      ADD CONSTRAINT collection_logs_collection_id_fkey
        FOREIGN KEY (collection_id)
        REFERENCES collections(id)
        ON DELETE NO ACTION
    """
  end
end
