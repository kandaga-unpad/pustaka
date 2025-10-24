defmodule Voile.Repo.Migrations.CreateLibPayments do
  use Ecto.Migration

  def change do
    create table(:lib_payments, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :fine_id, references(:lib_fines, type: :binary_id, on_delete: :nilify_all)
      add :member_id, references(:users, type: :binary_id, on_delete: :nilify_all), null: false

      # Payment gateway information
      add :payment_gateway, :string, null: false, default: "xendit"
      add :payment_link_id, :string
      add :external_id, :string, null: false
      add :payment_url, :string

      # Payment details
      add :amount, :decimal, precision: 15, scale: 2, null: false
      add :paid_amount, :decimal, precision: 15, scale: 2, default: 0
      add :currency, :string, default: "IDR"
      add :payment_method, :string
      add :payment_channel, :string

      # Status tracking
      add :status, :string, null: false, default: "pending"
      # pending, paid, failed, expired, cancelled
      add :payment_date, :utc_datetime
      add :expired_at, :utc_datetime
      add :failure_reason, :string

      # Additional metadata
      add :description, :text
      add :callback_data, :map
      add :metadata, :map

      # Tracking
      add :processed_by_id, references(:users, type: :binary_id, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create index(:lib_payments, [:fine_id])
    create index(:lib_payments, [:member_id])
    create index(:lib_payments, [:external_id])
    create index(:lib_payments, [:payment_link_id])
    create index(:lib_payments, [:status])
    create index(:lib_payments, [:payment_gateway])
  end
end
