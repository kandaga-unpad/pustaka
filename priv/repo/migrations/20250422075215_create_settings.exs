defmodule Voile.Repo.Migrations.CreateSettings do
  use Ecto.Migration

  def change do
    create table(:settings) do
      add :setting_name, :string
      add :setting_value, :string

      timestamps(type: :naive_datetime)
    end
  end
end
