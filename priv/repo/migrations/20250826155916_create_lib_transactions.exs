defmodule Voile.Repo.Migrations.CreateLibTransactions do
  use Ecto.Migration

  def change do
    execute "CREATE TYPE transaction_type AS ENUM ('loan', 'return', 'renewal', 'lost_item', 'damaged_item', 'cancel');"

    execute "CREATE TYPE transaction_status AS ENUM ('active', 'returned', 'overdue', 'lost', 'damaged', 'canceled');"

    create table(:lib_transactions, primary_key: false) do
      add :id, :binary_id, primary_key: true, null: false
      add :transaction_type, :transaction_type, null: false
      add :transaction_date, :utc_datetime
      add :due_date, :utc_datetime
      add :return_date, :utc_datetime
      add :renewal_count, :integer, default: 0
      add :notes, :text
      add :status, :transaction_status, null: false
      add :fine_amount, :decimal, precision: 10, scale: 2, default: 0.0
      add :is_overdue, :boolean, default: false

      add :item_id, references(:items, on_delete: :nilify_all, type: :binary_id), null: false
      add :member_id, references(:users, on_delete: :nilify_all, type: :binary_id), null: false

      add :librarian_id, references(:users, on_delete: :nilify_all, type: :binary_id), null: false
      add :unit_id, references(:nodes, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    # Basic indexes
    create index(:lib_transactions, [:due_date])
    create index(:lib_transactions, [:is_overdue])
    create index(:lib_transactions, [:item_id])
    create index(:lib_transactions, [:member_id])
    create index(:lib_transactions, [:librarian_id])
    create index(:lib_transactions, [:status])
    create index(:lib_transactions, [:transaction_type])
    create index(:lib_transactions, [:transaction_date])

    # Composite indexes for common query patterns
    create index(:lib_transactions, [:member_id, :status, :due_date],
             name: :lib_transactions_member_status_due_idx
           )

    # Partial index for active loans (most common library query)
    create index(:lib_transactions, [:member_id, :status, :transaction_type],
             where: "status = 'active'",
             name: :lib_transactions_active_loans_idx
           )

    # Partial index for overdue items (daily background job)
    create index(:lib_transactions, [:due_date, :status],
             where: "is_overdue = true AND status = 'active'",
             name: :lib_transactions_overdue_idx
           )

    # Ordered index for transaction history (newest first, using raw SQL)
    execute "CREATE INDEX lib_transactions_date_desc_idx ON lib_transactions (transaction_date DESC)",
            "DROP INDEX IF EXISTS lib_transactions_date_desc_idx"

    # Check constraints for data integrity
    execute """
            ALTER TABLE lib_transactions ADD CONSTRAINT transactions_due_date_check
            CHECK (due_date IS NULL OR due_date >= transaction_date)
            """,
            "ALTER TABLE lib_transactions DROP CONSTRAINT IF EXISTS transactions_due_date_check"

    execute """
            ALTER TABLE lib_transactions ADD CONSTRAINT transactions_return_date_check
            CHECK (return_date IS NULL OR return_date >= transaction_date)
            """,
            "ALTER TABLE lib_transactions DROP CONSTRAINT IF EXISTS transactions_return_date_check"

    # Increase statistics target for better query planning
    execute "ALTER TABLE lib_transactions ALTER COLUMN due_date SET STATISTICS 500",
            "ALTER TABLE lib_transactions ALTER COLUMN due_date SET STATISTICS -1"
  end
end
