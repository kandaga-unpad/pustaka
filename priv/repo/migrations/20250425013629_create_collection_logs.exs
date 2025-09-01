defmodule Voile.Repo.Migrations.CreateCollectionLogs do
  use Ecto.Migration

  def change do
    create table(:collection_logs, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :title, :string
      add :message, :text
      add :action, :string
      add :ip_address, :string
      add :user_agent, :text
      add :session_id, :string
      add :request_id, :string

      # Store before/after values
      add :old_values, :map
      add :new_values, :map

      # Categorize actions better
      # create, update, delete, publish, archive, etc.
      add :action_type, :string
      add :entity_type, :string, default: "collection"
      # info, warning, error
      add :severity, :string, default: "info"

      # Add metadata
      add :metadata, :map
      # How long the operation took
      add :duration_ms, :integer
      add :success, :boolean, default: true
      add :collection_id, references(:collections, on_delete: :nothing, type: :binary_id)
      add :user_id, references(:users, on_delete: :nothing, type: :binary_id)

      timestamps(type: :utc_datetime)
    end

    create index(:collection_logs, [:action_type])
    create index(:collection_logs, [:entity_type])
    create index(:collection_logs, [:severity])
    create index(:collection_logs, [:success])
    create index(:collection_logs, [:inserted_at])
    create index(:collection_logs, [:session_id])

    # Composite indexes for common queries
    create index(:collection_logs, [:collection_id, :action_type, :inserted_at])
    create index(:collection_logs, [:user_id, :action_type, :inserted_at])
  end
end
