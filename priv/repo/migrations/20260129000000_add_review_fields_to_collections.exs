defmodule Voile.Repo.Migrations.AddReviewFieldsToCollections do
  use Ecto.Migration

  def change do
    alter table(:collections) do
      add :reviewed_at, :utc_datetime
      add :reviewed_by_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :review_notes, :text
    end

    create index(:collections, [:reviewed_by_id])
    create index(:collections, [:reviewed_at])
  end
end
