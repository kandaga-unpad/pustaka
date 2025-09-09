defmodule Voile.Repo.Migrations.CreateMstPlaces do
  use Ecto.Migration

  def change do
    create table(:mst_places) do
      add :name, :string

      timestamps(type: :naive_datetime)
    end
  end
end
