defmodule Voile.Repo.Migrations.UpdateItemsBarcodeLengthCheck do
  use Ecto.Migration

  def up do
    # Drop old constraint
    execute """
              ALTER TABLE items DROP CONSTRAINT IF EXISTS items_barcode_length_check
            """,
            ""

    # Add new constraint - allow 10-30 characters for new barcode format
    # New format: timestamp(13) + collection_uuid_last12(12) + index(3) = 28 chars
    # Old format: uuid_last_block(12) + sequence(3) = 15 chars
    execute """
              ALTER TABLE items ADD CONSTRAINT items_barcode_length_check
              CHECK (barcode IS NULL OR length(barcode) BETWEEN 10 AND 30)
            """,
            ""

    execute "COMMENT ON CONSTRAINT items_barcode_length_check ON items IS 'Ensures barcode is between 10-30 characters (new format supports timestamp-based 28-char barcodes)'",
            "COMMENT ON CONSTRAINT items_barcode_length_check ON items IS NULL"
  end

  def down do
    # Drop new constraint
    execute """
              ALTER TABLE items DROP CONSTRAINT IF EXISTS items_barcode_length_check
            """,
            ""

    # Restore old constraint
    execute """
              ALTER TABLE items ADD CONSTRAINT items_barcode_length_check
              CHECK (barcode IS NULL OR length(barcode) BETWEEN 10 AND 20)
            """,
            ""

    execute "COMMENT ON CONSTRAINT items_barcode_length_check ON items IS 'Ensures barcode is between 10-20 characters'",
            "COMMENT ON CONSTRAINT items_barcode_length_check ON items IS NULL"
  end
end
