defmodule Voile.Repo.Migrations.CreateVisitorRooms do
  use Ecto.Migration

  def change do
    create table(:visitor_rooms) do
      add :room_name, :string, null: false
      add :description, :text
      add :is_active, :boolean, default: true, null: false
      add :display_order, :integer, default: 0
      add :node_id, references(:nodes, on_delete: :restrict), null: false
      add :location_id, references(:mst_locations, on_delete: :restrict)

      timestamps(type: :utc_datetime)
    end

    create index(:visitor_rooms, [:node_id])
    create index(:visitor_rooms, [:location_id])
    create index(:visitor_rooms, [:is_active])
    create unique_index(:visitor_rooms, [:node_id, :room_name])
  end
end
