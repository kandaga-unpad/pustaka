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

      timestamps(type: :utc_datetime)
    end

    create index(:lib_transactions, [:due_date])
    create index(:lib_transactions, [:is_overdue])
    create index(:lib_transactions, [:item_id])
    create index(:lib_transactions, [:member_id])
    create index(:lib_transactions, [:librarian_id])
    create index(:lib_transactions, [:status])
    create index(:lib_transactions, [:transaction_type])
    create index(:lib_transactions, [:transaction_date])
  end
end
