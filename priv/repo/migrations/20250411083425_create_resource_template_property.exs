defmodule Voile.Repo.Migrations.CreateResourceTemplateProperty do
  use Ecto.Migration

  def change do
    create table(:resource_template_properties, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :position, :integer, null: false
      add :override_label, :string
      add :template_id, references(:resource_template, on_delete: :nothing)
      add :property_id, references(:metadata_properties, on_delete: :nothing)

      timestamps(type: :utc_datetime)
    end

    create unique_index(:resource_template_properties, [:template_id, :property_id],
             name: :template_property_unique
           )

    create index(:resource_template_properties, [:template_id])
    create index(:resource_template_properties, [:property_id])
  end
end
