defmodule Voile.Repo.Migrations.AddReadOnSpotInLibraryModule do
  use Ecto.Migration

  def change do
    create table(:lib_read_on_spots, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :read_at, :utc_datetime
      add :notes, :string

      add :item_id, references(:items, type: :binary_id, on_delete: :nilify_all)
      add :node_id, references(:nodes, on_delete: :nilify_all)
      add :location_id, references(:mst_locations, on_delete: :nilify_all)
      add :recorded_by_id, references(:users, type: :binary_id, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create index(:lib_read_on_spots, [:item_id])
    create index(:lib_read_on_spots, [:node_id])
    create index(:lib_read_on_spots, [:location_id])
    create index(:lib_read_on_spots, [:recorded_by_id])
    create index(:lib_read_on_spots, [:read_at])
  end
end
