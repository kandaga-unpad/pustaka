defmodule Voile.Repo.Migrations.CreateMetadataVocabularies do
  use Ecto.Migration

  def change do
    create table(:metadata_vocabularies) do
      add :label, :string
      add :prefix, :string
      add :namespace_url, :string
      add :information, :text
      add :owner_id, references(:users, type: :binary_id, on_delete: :nothing)

      timestamps(type: :utc_datetime)
    end

    create index(:metadata_vocabularies, [:owner_id])
  end
end
