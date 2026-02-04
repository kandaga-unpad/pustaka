defmodule Voile.Repo.Migrations.RefactorVisitorToUseLocations do
  use Ecto.Migration

  def up do
    # Drop foreign key constraints first
    drop constraint(:visitor_surveys, "visitor_surveys_visitor_room_id_fkey")
    drop constraint(:visitor_logs, "visitor_logs_visitor_room_id_fkey")

    # Drop indexes
    drop index(:visitor_surveys, [:visitor_room_id])
    drop index(:visitor_logs, [:visitor_room_id])

    # Rename columns to point to mst_locations
    rename table(:visitor_logs), :visitor_room_id, to: :location_id
    rename table(:visitor_surveys), :visitor_room_id, to: :location_id

    # Add foreign key constraints to mst_locations
    alter table(:visitor_logs) do
      modify :location_id, references(:mst_locations, on_delete: :restrict), null: false
    end

    alter table(:visitor_surveys) do
      modify :location_id, references(:mst_locations, on_delete: :restrict), null: false
    end

    # Recreate indexes with new column name
    create index(:visitor_logs, [:location_id])
    create index(:visitor_surveys, [:location_id])

    # Drop visitor_rooms table as it's no longer needed
    drop table(:visitor_rooms)
  end

  def down do
    # Recreate visitor_rooms table
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

    # Drop foreign key constraints to mst_locations
    drop constraint(:visitor_surveys, "visitor_surveys_location_id_fkey")
    drop constraint(:visitor_logs, "visitor_logs_location_id_fkey")

    # Drop indexes
    drop index(:visitor_surveys, [:location_id])
    drop index(:visitor_logs, [:location_id])

    # Rename columns back to visitor_room_id
    rename table(:visitor_logs), :location_id, to: :visitor_room_id
    rename table(:visitor_surveys), :location_id, to: :visitor_room_id

    # Add foreign key constraints back to visitor_rooms
    alter table(:visitor_logs) do
      modify :visitor_room_id, references(:visitor_rooms, on_delete: :restrict), null: false
    end

    alter table(:visitor_surveys) do
      modify :visitor_room_id, references(:visitor_rooms, on_delete: :restrict), null: false
    end

    # Recreate indexes
    create index(:visitor_logs, [:visitor_room_id])
    create index(:visitor_surveys, [:visitor_room_id])
  end
end
