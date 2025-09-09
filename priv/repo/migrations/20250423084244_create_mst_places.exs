defmodule Voile.Repo.Migrations.CreateMstPlaces do
  use Ecto.Migration

  def change do
    create table(:mst_places) do
      add :name, :string

      timestamps(type: :utc_datetime)
    end
  end
end
