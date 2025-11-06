defmodule Voile.Repo.Migrations.CreateUserMetadataOnCollection do
  use Ecto.Migration

  def change do
    # Note: created_by_id and updated_by_id already exist in collections table
    # (added in create_collections migration)

    # Add audit fields to items table
    alter table(:items) do
      add :created_by_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :updated_by_id, references(:users, type: :binary_id, on_delete: :nilify_all)
    end

    # Add indexes for items audit fields
    create index(:items, [:created_by_id])
    create index(:items, [:updated_by_id])
  end
end
