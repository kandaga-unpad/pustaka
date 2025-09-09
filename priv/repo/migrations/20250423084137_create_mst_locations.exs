defmodule Voile.Repo.Migrations.CreateMstLocations do
  use Ecto.Migration

  def change do
    create table(:mst_locations) do
      add :location_code, :string
      add :location_name, :string
      add :location_place, :string

      timestamps(type: :utc_datetime)
    end
  end
end
