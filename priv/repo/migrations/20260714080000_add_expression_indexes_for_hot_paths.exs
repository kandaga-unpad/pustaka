defmodule Voile.Repo.Migrations.AddExpressionIndexesForHotPaths do
  use Ecto.Migration

  def up do
    # Expression index for DATE(event_date) filters used in circulation history queries.
    # Without this, every DATE() fragment does a full table scan.
    execute "CREATE INDEX IF NOT EXISTS lib_circulation_history_date_idx ON lib_circulation_history ((DATE(event_date)))",
            "DROP INDEX IF EXISTS lib_circulation_history_date_idx"

    # Expression index for COALESCE(read_at, inserted_at) used in read-on-spot queries.
    execute "CREATE INDEX IF NOT EXISTS lib_read_on_spots_coalesce_idx ON lib_read_on_spots ((COALESCE(read_at, inserted_at)))",
            "DROP INDEX IF EXISTS lib_read_on_spots_coalesce_idx"

    # Trigram index on COALESCE(fullname, '') for ilike member search queries.
    # The COALESCE wrapper defeats plain indexes, so we need an expression-based GIN index.
    execute "CREATE INDEX IF NOT EXISTS users_fullname_coalesce_trgm_idx ON users USING gin ((COALESCE(fullname, '')) gin_trgm_ops)",
            "DROP INDEX IF EXISTS users_fullname_coalesce_trgm_idx"

    # Expression index for DATE(check_in_time) used in visitor stats grouping/filtering.
    execute "CREATE INDEX IF NOT EXISTS visitor_logs_check_in_date_idx ON visitor_logs ((DATE(check_in_time)))",
            "DROP INDEX IF EXISTS visitor_logs_check_in_date_idx"
  end

  def down do
    execute "DROP INDEX IF EXISTS lib_circulation_history_date_idx"
    execute "DROP INDEX IF EXISTS lib_read_on_spots_coalesce_idx"
    execute "DROP INDEX IF EXISTS users_fullname_coalesce_trgm_idx"
    execute "DROP INDEX IF EXISTS visitor_logs_check_in_date_idx"
  end
end
