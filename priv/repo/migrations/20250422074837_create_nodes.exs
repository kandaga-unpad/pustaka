defmodule Voile.Repo.Migrations.CreateNodes do
  use Ecto.Migration

  def change do
    create table(:nodes) do
      add :name, :string
      add :abbr, :string
      add :description, :text
      add :image, :string

      timestamps(type: :utc_datetime)
    end

    create unique_index(:nodes, [:name])

    # Add GIN trigram index for fast ILIKE pattern matching on name
    execute "CREATE INDEX nodes_name_trgm_idx ON nodes USING gin (name gin_trgm_ops)",
            "DROP INDEX IF EXISTS nodes_name_trgm_idx"

    alter table(:users) do
      add :node_id, references(:nodes, on_delete: :nilify_all, type: :bigint)
    end

    create index(:users, [:node_id])
  end
end
