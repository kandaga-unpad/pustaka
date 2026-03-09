defmodule Voile.Repo.Migrations.FixCollectionsListingCoveringIdx do
  use Ecto.Migration

  def up do
    # The covering index with INCLUDE (title, thumbnail, collection_code) causes
    # Postgrex.Error ERROR 54000 (program_limit_exceeded) when a collection with
    # a very long title/thumbnail/collection_code is approved (status → "published"),
    # because the combined size of the INCLUDE column values exceeds PostgreSQL's
    # 8191 byte maximum index row size.
    #
    # Fix: drop and recreate the index without INCLUDE columns. The index still
    # serves its purpose for query planning; the INCLUDE optimization was only
    # needed for index-only scans, which can fall back to a heap fetch instead.
    execute "DROP INDEX IF EXISTS collections_listing_covering_idx"

    execute """
    CREATE INDEX collections_listing_covering_idx
    ON collections (unit_id, status)
    WHERE status = 'published'
    """
  end

  def down do
    execute "DROP INDEX IF EXISTS collections_listing_covering_idx"

    execute """
    CREATE INDEX collections_listing_covering_idx
    ON collections (unit_id, status)
    INCLUDE (title, thumbnail, collection_code)
    WHERE status = 'published'
    """
  end
end
