defmodule Voile.Repo.Migrations.CreateCollectionPermissions do
  use Ecto.Migration

  def change do
    create table(:collection_permissions) do
      add :collection_id, references(:collections, type: :binary_id, on_delete: :delete_all),
        null: false

      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all)
      add :role_id, references(:roles, on_delete: :delete_all)
      add :permission_level, :string, null: false

      timestamps()
    end

    create index(:collection_permissions, [:collection_id])
    create index(:collection_permissions, [:user_id])
    create index(:collection_permissions, [:role_id])

    # Ensure either user_id or role_id is set, but not both
    create constraint(:collection_permissions, :user_or_role_required,
             check:
               "(user_id IS NOT NULL AND role_id IS NULL) OR (user_id IS NULL AND role_id IS NOT NULL)"
           )
  end
end
