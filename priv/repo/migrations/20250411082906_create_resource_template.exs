defmodule Voile.Repo.Migrations.CreateResourceTemplate do
  use Ecto.Migration

  def change do
    create table(:resource_template) do
      add :label, :string
      add :description, :text
      add :owner_id, references(:users, on_delete: :nilify_all, type: :binary_id), null: false

      add :resource_class_id,
          references(:resource_class, on_delete: :nilify_all),
          null: false

      timestamps(type: :utc_datetime)
    end

    create index(:resource_template, [:owner_id])
    create index(:resource_template, [:resource_class_id])
  end
end
