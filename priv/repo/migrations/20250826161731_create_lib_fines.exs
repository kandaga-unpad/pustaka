defmodule Voile.Repo.Migrations.CreateLibFines do
  use Ecto.Migration

  def change do
    execute "CREATE TYPE fine_type AS ENUM ('overdue', 'lost_item', 'damaged_item', 'processing');"
    execute "CREATE TYPE fine_status AS ENUM ('pending', 'partial_paid', 'paid', 'waived');"

    execute "CREATE TYPE payment_method AS ENUM ('cash', 'credit_card', 'debit_card', 'bank_transfer', 'online');"

    create table(:lib_fines, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :fine_type, :fine_type
      add :amount, :decimal, precision: 10, scale: 2, null: false
      add :paid_amount, :decimal, precision: 10, scale: 2, default: 0.0
      add :balance, :decimal, precision: 10, scale: 2
      add :fine_date, :utc_datetime, null: false
      add :payment_date, :utc_datetime
      add :fine_status, :fine_status, null: false
      add :description, :text
      add :waived, :boolean, default: false
      add :waived_date, :utc_datetime
      add :waived_reason, :text
      add :payment_method, :payment_method
      add :receipt_number, :string

      add :member_id, references(:users, on_delete: :nilify_all, type: :binary_id), null: false
      add :item_id, references(:items, on_delete: :nilify_all, type: :binary_id), null: false
      add :transaction_id, references(:lib_transactions, on_delete: :nilify_all, type: :binary_id)
      add :processed_by_id, references(:users, on_delete: :nilify_all, type: :binary_id)
      add :waived_by_id, references(:users, on_delete: :nilify_all, type: :binary_id)

      timestamps(type: :utc_datetime)
    end

    create index(:lib_fines, [:member_id])
    create index(:lib_fines, [:item_id])
    create index(:lib_fines, [:transaction_id])
    create index(:lib_fines, [:processed_by_id])
    create index(:lib_fines, [:fine_type])
    create index(:lib_fines, [:fine_status])
    create index(:lib_fines, [:fine_date])
    create index(:lib_fines, [:payment_date])
    create index(:lib_fines, [:waived])
  end
end
