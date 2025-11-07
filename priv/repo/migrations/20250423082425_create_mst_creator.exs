defmodule Voile.Repo.Migrations.CreateMstCreator do
  use Ecto.Migration

  def change do
    create table(:mst_creator) do
      add :creator_name, :string
      add :creator_contact, :string
      add :affiliation, :string
      add :type, :string

      timestamps(type: :utc_datetime)
    end

    # Add unique index on creator_name to prevent duplicates
    create unique_index(:mst_creator, [:creator_name])

    # Add GIN trigram index for fast ILIKE pattern matching on creator_name
    execute "CREATE INDEX mst_creator_name_trgm_idx ON mst_creator USING gin (creator_name gin_trgm_ops)",
            "DROP INDEX IF EXISTS mst_creator_name_trgm_idx"
  end
end
