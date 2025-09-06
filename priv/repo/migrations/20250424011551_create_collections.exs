defmodule Voile.Repo.Migrations.CreateCollections do
  use Ecto.Migration

  def change do
    create table(:collections, primary_key: false) do
      add :id, :binary_id, primary_key: true, null: false
      add :collection_code, :string
      add :title, :text
      add :description, :text
      add :thumbnail, :string
      add :status, :string
      add :access_level, :string
      add :old_biblio_id, :integer
      add :type_id, references(:resource_class, on_delete: :nilify_all)
      add :template_id, references(:resource_template, on_delete: :nilify_all)
      add :creator_id, references(:mst_creator, on_delete: :nilify_all)
      add :unit_id, references(:nodes, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create index(:collections, [:title])
    create index(:collections, [:type_id])
    create index(:collections, [:template_id])
    create index(:collections, [:creator_id])
    create index(:collections, [:unit_id])
    create unique_index(:collections, [:collection_code])

    alter table(:collections) do
      add :parent_id, references(:collections, type: :binary_id, on_delete: :nilify_all)
      add :sort_order, :integer
      add :collection_type, :string
    end

    create index(:collections, [:parent_id])
    create index(:collections, [:sort_order])
    create index(:collections, [:collection_type])
  end
end
