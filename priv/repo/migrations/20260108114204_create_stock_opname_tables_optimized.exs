defmodule Voile.Repo.Migrations.CreateStockOpnameTablesOptimized do
  use Ecto.Migration

  def change do
    # Stock Opname Sessions table
    create table(:stock_opname_sessions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :session_code, :string, null: false
      add :title, :string, null: false
      add :description, :text

      # Scope configuration
      add :node_ids, {:array, :integer}, null: false
      add :collection_types, {:array, :string}, null: false
      add :scope_type, :string, null: false
      add :scope_id, :string

      # Status tracking
      add :status, :string, null: false, default: "draft"

      # Timestamps for workflow
      add :started_at, :utc_datetime
      add :completed_at, :utc_datetime
      add :reviewed_at, :utc_datetime
      add :approved_at, :utc_datetime

      # Counters
      add :total_items, :integer, default: 0
      add :checked_items, :integer, default: 0
      add :missing_items, :integer, default: 0
      add :items_with_changes, :integer, default: 0

      # Notes & Review
      add :notes, :text
      add :review_notes, :text
      add :rejection_reason, :text

      # User tracking
      add :created_by_id, references(:users, type: :binary_id, on_delete: :nilify_all),
        null: false

      add :updated_by_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :reviewed_by_id, references(:users, type: :binary_id, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create unique_index(:stock_opname_sessions, [:session_code])
    create index(:stock_opname_sessions, [:status])
    create index(:stock_opname_sessions, [:created_by_id])
    create index(:stock_opname_sessions, [:inserted_at])

    # Librarian Assignment table
    create table(:stock_opname_librarian_assignments, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :session_id,
          references(:stock_opname_sessions, type: :binary_id, on_delete: :delete_all),
          null: false

      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :work_status, :string, null: false, default: "pending"
      add :items_checked, :integer, default: 0
      add :started_at, :utc_datetime
      add :completed_at, :utc_datetime
      add :notes, :text

      timestamps(type: :utc_datetime)
    end

    create index(:stock_opname_librarian_assignments, [:session_id])
    create index(:stock_opname_librarian_assignments, [:user_id])
    create index(:stock_opname_librarian_assignments, [:work_status])
    create unique_index(:stock_opname_librarian_assignments, [:session_id, :user_id])

    # Stock Opname Items table - OPTIMIZED with JSONB
    create table(:stock_opname_items, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :session_id,
          references(:stock_opname_sessions, type: :binary_id, on_delete: :delete_all),
          null: false

      add :item_id, references(:items, type: :binary_id, on_delete: :delete_all), null: false
      add :collection_id, references(:collections, type: :binary_id, on_delete: :delete_all)

      # Changes recorded by librarian (JSONB - only stores differences)
      # Example: {"status": "damaged", "condition": "poor", "location": "Storage Room"}
      add :changes, :jsonb

      # Audit trail
      add :scanned_barcode, :string

      # Check result
      add :check_status, :string, null: false, default: "pending"
      add :has_changes, :boolean, default: false
      add :notes, :text
      add :scanned_at, :utc_datetime
      add :checked_by_id, references(:users, type: :binary_id, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create index(:stock_opname_items, [:session_id])
    create index(:stock_opname_items, [:item_id])
    create index(:stock_opname_items, [:check_status])
    create index(:stock_opname_items, [:checked_by_id])
    create unique_index(:stock_opname_items, [:session_id, :item_id])

    # GIN index for JSONB queries on changes column
    create index(:stock_opname_items, [:changes], using: :gin)
  end
end
