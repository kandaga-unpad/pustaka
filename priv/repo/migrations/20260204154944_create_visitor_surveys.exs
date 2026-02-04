defmodule Voile.Repo.Migrations.CreateVisitorSurveys do
  use Ecto.Migration

  def change do
    create table(:visitor_surveys) do
      add :rating, :integer, null: false
      add :comment, :text
      add :survey_type, :string, default: "general"
      add :ip_address, :string
      add :user_agent, :text
      add :additional_data, :map, default: %{}
      add :visitor_log_id, references(:visitor_logs, on_delete: :nilify_all)
      add :visitor_room_id, references(:visitor_rooms, on_delete: :restrict), null: false
      add :node_id, references(:nodes, on_delete: :restrict), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:visitor_surveys, [:visitor_room_id])
    create index(:visitor_surveys, [:node_id])
    create index(:visitor_surveys, [:visitor_log_id])
    create index(:visitor_surveys, [:rating])
    create index(:visitor_surveys, [:inserted_at])
    create index(:visitor_surveys, [:survey_type])
  end
end
