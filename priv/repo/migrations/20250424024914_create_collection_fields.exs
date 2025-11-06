defmodule Voile.Repo.Migrations.CreateCollectionFields do
  use Ecto.Migration

  def change do
    create table(:collection_fields, primary_key: false) do
      add :id, :binary_id, primary_key: true, null: false
      add :name, :string, null: false
      add :label, :string, null: false
      add :value, :text
      add :value_lang, :string, default: "en"
      add :type_value, :string, null: false
      add :sort_order, :integer, default: 1

      add :collection_id, references(:collections, on_delete: :delete_all, type: :binary_id),
        null: false

      add :property_id, references(:metadata_properties, on_delete: :nilify_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:collection_fields, [:collection_id])
    create index(:collection_fields, [:property_id])
    create index(:collection_fields, [:name])
    create index(:collection_fields, [:sort_order])

    # Composite index for metadata display (query by collection and property)
    create index(:collection_fields, [:collection_id, :property_id],
             name: :collection_fields_collection_property_idx
           )
  end
end
