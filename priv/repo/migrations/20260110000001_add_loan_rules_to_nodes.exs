defmodule Voile.Repo.Migrations.AddLoanRulesToNodes do
  use Ecto.Migration

  def change do
    alter table(:nodes) do
      # Override flag - when true, node rules take precedence over member type rules
      add :override_loan_rules, :boolean, default: false

      # Loan limits
      add :max_items, :integer
      add :max_days, :integer
      add :max_renewals, :integer
      add :max_reserves, :integer
      add :max_concurrent_loans, :integer

      # Fine rules
      add :fine_per_day, :decimal, precision: 15, scale: 2
      add :max_fine, :decimal, precision: 15, scale: 2
      add :currency, :string, default: "IDR"

      # Feature flags
      add :can_reserve, :boolean
      add :can_renew, :boolean
      add :digital_access_enabled, :boolean, default: true

      # Operating schedule (JSONB for flexibility)
      add :operating_hours, :map
      add :holiday_schedule, :map
      add :auto_close_on_holidays, :boolean, default: true

      # Node-specific policies
      add :require_deposit, :boolean, default: false
      add :deposit_amount, :decimal, precision: 15, scale: 2
      add :allow_external_returns, :boolean, default: true
      add :allow_inter_node_loans, :boolean, default: true

      # Custom rules storage
      add :custom_rules, :map, default: %{}
    end

    # Add index for performance on override check
    create index(:nodes, [:override_loan_rules])
  end
end
