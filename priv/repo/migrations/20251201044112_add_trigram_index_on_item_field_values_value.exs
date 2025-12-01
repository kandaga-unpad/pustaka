defmodule Voile.Repo.Migrations.AddTrigramIndexOnItemFieldValuesValue do
  use Ecto.Migration

  def change do
    # Add GIN trigram index for fast ILIKE pattern matching on item_field_values.value
    execute "CREATE INDEX item_field_values_value_trgm_idx ON item_field_values USING gin (value gin_trgm_ops)",
            "DROP INDEX IF EXISTS item_field_values_value_trgm_idx"
  end
end
