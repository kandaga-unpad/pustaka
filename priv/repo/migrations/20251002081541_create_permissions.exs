defmodule Voile.Repo.Migrations.CreatePermissions do
  use Ecto.Migration

  def change do
    create table(:permissions) do
      add :name, :string, null: false
      add :resource, :string, null: false
      add :action, :string, null: false
      add :description, :text

      timestamps()
    end

    create unique_index(:permissions, [:name])
    create index(:permissions, [:resource])
    create index(:permissions, [:action])
  end
end
