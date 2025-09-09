defmodule Voile.Repo.Migrations.CreateResourceClass do
  use Ecto.Migration

  def change do
    execute "CREATE TYPE glam_type AS ENUM ('Gallery', 'Library', 'Archive', 'Museum');"

    create table(:resource_class) do
      add :label, :string
      add :local_name, :string
      add :information, :text
      add :glam_type, :glam_type
      add :owner_id, references(:users, type: :binary_id, on_delete: :nothing)
      add :vocabulary_id, references(:metadata_vocabularies, on_delete: :nothing)

      timestamps(type: :utc_datetime)
    end

    create index(:resource_class, [:owner_id])
    create index(:resource_class, [:vocabulary_id])
  end
end
