defmodule Voile.Repo.Migrations.CreateVoilePlugins do
  use Ecto.Migration

  def change do
    create table(:voile_plugins, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :plugin_id, :string, null: false
      add :module, :string, null: false
      add :name, :string, null: false
      add :version, :string, null: false
      add :author, :string
      add :description, :text
      add :license_type, :string, default: "free"
      add :license_key, :string
      add :status, :string, null: false, default: "installed"
      add :error_message, :text
      add :settings, :map, default: %{}
      add :installed_at, :utc_datetime
      add :activated_at, :utc_datetime
      add :deactivated_at, :utc_datetime

      timestamps()
    end

    create unique_index(:voile_plugins, [:plugin_id])
    create unique_index(:voile_plugins, [:module])
    create index(:voile_plugins, [:status])
  end
end
