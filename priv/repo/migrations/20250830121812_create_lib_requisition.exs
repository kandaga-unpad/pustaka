defmodule Voile.Repo.Migrations.CreateLibRequisition do
  use Ecto.Migration

  def change do
    execute "CREATE TYPE patron_request_type AS ENUM ('purchase_request', 'interlibrary_loan', 'digitization_request', 'reference_question');"

    execute "CREATE TYPE patron_request_status AS ENUM ('submitted', 'reviewing', 'approved', 'rejected', 'fulfilled', 'cancelled');"

    create table(:lib_requisitions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :request_date, :utc_datetime, null: false
      add :request_type, :patron_request_type, null: false
      add :status, :patron_request_status, null: false, default: "submitted"
      add :title, :text, null: false
      add :author, :string
      add :publisher, :string
      add :isbn, :string
      add :publication_year, :integer
      add :description, :text
      add :justification, :text
      add :priority, :string, default: "normal"
      add :estimated_cost, :decimal, precision: 10, scale: 2
      add :notes, :text
      add :staff_notes, :text
      add :due_date, :date
      add :fulfilled_date, :utc_datetime

      add :requested_by_id, references(:users, on_delete: :nilify_all, type: :binary_id),
        null: false

      add :assigned_to_id, references(:users, on_delete: :nilify_all, type: :binary_id)
      add :unit_id, references(:nodes, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create index(:lib_requisitions, [:request_type])
    create index(:lib_requisitions, [:request_date])
    create index(:lib_requisitions, [:requested_by_id])
    create index(:lib_requisitions, [:assigned_to_id])
    create index(:lib_requisitions, [:unit_id])
    create index(:lib_requisitions, [:status])
    create index(:lib_requisitions, [:priority])
    create index(:lib_requisitions, [:due_date])
  end
end
