defmodule Voile.Repo.Migrations.AddUniqueIndexToSettings do
  use Ecto.Migration

  def change do
    create unique_index(:settings, [:setting_name])
  end
end
