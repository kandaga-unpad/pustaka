defmodule Voile.Repo.Migrations.CreateUserMetadataOnCollection do
  use Ecto.Migration

  def change do
    alter table(:collections) do
      add :created_by_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :updated_by_id, references(:users, type: :binary_id, on_delete: :nilify_all)
    end

    alter table(:items) do
      add :created_by_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :updated_by_id, references(:users, type: :binary_id, on_delete: :nilify_all)
    end

    create index(:collections, [:created_by_id])
    create index(:collections, [:updated_by_id])
    create index(:items, [:created_by_id])
    create index(:items, [:updated_by_id])
  end
end
