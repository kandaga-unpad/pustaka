defmodule Voile.Repo.Migrations.AddFileKeyAndUnitIdToAttachments do
  use Ecto.Migration

  def change do
    alter table(:attachments) do
      # file_key: The storage key/path used by Client.Storage module
      # Extracted from file_path/file_url for efficient lookups and deletions
      add :file_key, :string

      # unit_id: Reference to system_node for organizational hierarchy
      # Allows filtering attachments by organizational unit
      add :unit_id, :integer
    end

    # Add indexes for better query performance
    create index(:attachments, [:file_key])
    create index(:attachments, [:unit_id])

    # Add foreign key constraint for unit_id
    alter table(:attachments) do
      modify :unit_id, references(:nodes, type: :integer, on_delete: :nilify_all)
    end
  end
end
