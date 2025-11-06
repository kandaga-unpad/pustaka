defmodule Voile.Repo.Migrations.CreateAuditLogs do
  use Ecto.Migration

  def change do
    create table(:audit_logs) do
      add :user_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :action, :string, null: false
      add :resource_type, :string
      add :resource_id, :binary_id
      add :ip_address, :string
      add :user_agent, :text
      add :metadata, :map

      timestamps(updated_at: false)
    end

    create index(:audit_logs, [:user_id])
    create index(:audit_logs, [:action])
    create index(:audit_logs, [:resource_type, :resource_id])
    create index(:audit_logs, [:inserted_at])

    # Ordered index for recent activity (newest first, using raw SQL)
    execute "CREATE INDEX audit_logs_timestamp_desc_idx ON audit_logs (inserted_at DESC)",
            "DROP INDEX IF EXISTS audit_logs_timestamp_desc_idx"

    # JSONB GIN index for fast metadata queries
    execute "CREATE INDEX audit_logs_metadata_gin_idx ON audit_logs USING gin (metadata)",
            "DROP INDEX IF EXISTS audit_logs_metadata_gin_idx"
  end
end
