defmodule Voile.Repo.Migrations.CreateNodes do
  use Ecto.Migration

  def change do
    create table(:nodes) do
      add :name, :string
      add :abbr, :string
      add :description, :text
      add :image, :string

      timestamps(type: :naive_datetime)
    end

    create unique_index(:nodes, [:name])

    alter table(:users) do
      add :node_id, references(:nodes, on_delete: :nilify_all, type: :bigint)
    end

    create index(:users, [:node_id])
  end
end
