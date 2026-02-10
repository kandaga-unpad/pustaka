defmodule Voile.Repo.Migrations.AddOaiPmhIndexes do
  use Ecto.Migration

  def change do
    # Index for date-based selective harvesting
    # Used in: from/until date filters in ListIdentifiers and ListRecords
    create_if_not_exists index(:items, [:updated_at])

    # Index for filtering published collections
    # Used in: filtering collections by status = 'published'
    create_if_not_exists index(:collections, [:status])

    # Index for set-based filtering
    # Used in: set parameter filtering (collection:CODE)
    create_if_not_exists index(:collections, [:collection_code])

    # Composite index for efficient OAI-PMH queries
    # Used in: combined filters (status + collection_code)
    create_if_not_exists index(:collections, [:status, :collection_code])

    # Index for items by collection (improves join performance)
    # Used in: joining items with collections in ListRecords
    create_if_not_exists index(:items, [:collection_id])
  end
end
