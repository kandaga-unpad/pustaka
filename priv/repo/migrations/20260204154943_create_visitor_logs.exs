defmodule Voile.Repo.Migrations.CreateVisitorLogs do
  use Ecto.Migration

  def change do
    create table(:visitor_logs) do
      add :visitor_identifier, :string, null: false
      add :visitor_name, :string
      add :visitor_origin, :string
      add :check_in_time, :utc_datetime, null: false
      add :check_out_time, :utc_datetime
      add :ip_address, :string
      add :user_agent, :text
      add :additional_data, :map, default: %{}
      add :location_id, references(:mst_locations, on_delete: :restrict), null: false
      add :node_id, references(:nodes, on_delete: :restrict), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:visitor_logs, [:location_id])
    create index(:visitor_logs, [:node_id])
    create index(:visitor_logs, [:check_in_time])
    create index(:visitor_logs, [:visitor_identifier])
    create index(:visitor_logs, [:inserted_at])
  end
end
