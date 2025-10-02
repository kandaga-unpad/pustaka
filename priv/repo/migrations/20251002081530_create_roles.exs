defmodule Voile.Repo.Migrations.CreateRoles do
  use Ecto.Migration

  def change do
    create table(:roles) do
      add :name, :string, null: false
      add :description, :text
      add :is_system_role, :boolean, default: false, null: false

      timestamps()
    end

    create unique_index(:roles, [:name])
  end
end
