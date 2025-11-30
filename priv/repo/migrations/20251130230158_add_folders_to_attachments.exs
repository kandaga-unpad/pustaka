defmodule Voile.Repo.Migrations.AddFoldersToAttachments do
  use Ecto.Migration

  def change do
    # Add parent_id column for folder hierarchy
    alter table(:attachments) do
      add :parent_id, :binary_id
    end

    # Add foreign key constraint for parent_id
    alter table(:attachments) do
      modify :attachable_id, :binary_id, null: true
      modify :attachable_type, :string, null: true
    end

    # Create foreign key constraint
    create constraint(:attachments, :parent_id_fk, check: "parent_id IS NULL OR parent_id != id")

    # Update the attachable_type constraint to include 'folder' and 'asset_vault'
    drop constraint(:attachments, :attachable_type_must_be_valid)

    create constraint(:attachments, :attachable_type_must_be_valid,
             check:
               "attachable_type IS NULL OR attachable_type IN ('collection', 'item', 'asset_vault', 'folder')"
           )

    # Add indexes
    create index(:attachments, [:parent_id])

    # Add foreign key references
    alter table(:attachments) do
      modify :parent_id, references(:attachments, type: :binary_id, on_delete: :nilify_all)
    end
  end
end
