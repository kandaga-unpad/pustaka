defmodule Voile.Repo.Migrations.TestUtcDatetimeConfig do
  use Ecto.Migration

  def change do
    create table(:test_utc_table) do
      add :name, :string
      add :test_datetime, :utc_datetime

      timestamps()
    end
  end
end
