defmodule Voile.Repo.Migrations.CreateMstMemberTypes do
  use Ecto.Migration

  def change do
    create table(:mst_member_types, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :slug, :string, null: false
      add :description, :text

      add :max_items, :integer, default: 0, null: false
      add :max_days, :integer, default: 0, null: false
      add :max_renewals, :integer, default: 0
      add :max_reserves, :integer, default: 0
      add :max_concurrent_loans, :integer, default: 0

      add :fine_per_day, :decimal, precision: 12, scale: 2, default: 0.0, null: false
      add :max_fine, :decimal, precision: 12, scale: 2
      add :membership_fee, :decimal, precision: 12, scale: 2, default: 0.0
      add :currency, :string, size: 3, default: "IDR"

      add :can_reserve, :boolean, default: true
      add :can_renew, :boolean, default: true
      add :digital_access, :boolean, default: false
      add :exhibition_preview_access, :boolean, default: false
      add :ticket_discount_percent, :integer, default: 0
      add :shop_discount_percent, :integer, default: 0
      add :max_event_bookings_per_year, :integer, default: 0

      add :membership_period_days, :integer
      add :auto_renew, :boolean, default: false

      add :recurrence_unit, :string
      add :recurrence_interval, :integer

      add :priority_level, :integer, default: 1
      add :is_active, :boolean, default: true
      add :publicly_listed, :boolean, default: true

      add :institutional, :boolean, default: false
      add :allowed_collections, :map
      add :metadata, :map

      timestamps(type: :utc_datetime)
    end

    alter table(:users) do
      add :user_type_id, references(:mst_member_types, on_delete: :nilify_all, type: :binary_id)
    end

    # Add performance indexes for the new foreign keys
    create index(:users, [:user_type_id])
    create index(:mst_member_types, [:is_active])
    create index(:mst_member_types, [:priority_level])
  end
end
