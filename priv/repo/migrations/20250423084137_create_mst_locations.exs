defmodule Voile.Repo.Migrations.CreateMstLocations do
  use Ecto.Migration

  def change do
    create table(:mst_locations) do
      add :location_code, :string
      add :location_name, :string
      add :location_place, :string
      add :location_type, :string
      add :description, :text
      add :notes, :text
      add :is_active, :boolean, default: true, null: false
      add :node_id, references(:nodes, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create unique_index(:mst_locations, [:location_code])
    create index(:mst_locations, [:location_type])
    create index(:mst_locations, [:is_active])
  end
end
