defmodule Voile.Repo.Migrations.CreateItemFieldValues do
  use Ecto.Migration

  def change do
    create table(:item_field_values, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :value, :string
      add :locale, :string
      add :item_id, references(:items, on_delete: :nothing, type: :binary_id)

      add :collection_field_id,
          references(:collection_fields, on_delete: :nothing, type: :binary_id)

      timestamps(type: :utc_datetime)
    end

    create index(:item_field_values, [:item_id])
    create index(:item_field_values, [:collection_field_id])
  end
end
