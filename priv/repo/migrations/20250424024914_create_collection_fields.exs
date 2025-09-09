defmodule Voile.Repo.Migrations.CreateCollectionFields do
  use Ecto.Migration

  def change do
    create table(:collection_fields, primary_key: false) do
      add :id, :binary_id, primary_key: true, null: false
      add :name, :string
      add :label, :string
      add :value, :text
      add :value_lang, :string
      add :type_value, :string
      add :sort_order, :integer
      add :collection_id, references(:collections, on_delete: :nilify_all, type: :binary_id)
      add :property_id, references(:metadata_properties, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create index(:collection_fields, [:collection_id])
  end
end
