defmodule Voile.Repo.Migrations.CreateUserPermissions do
  use Ecto.Migration

  def change do
    create table(:user_permissions) do
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :permission_id, references(:permissions, on_delete: :delete_all), null: false
      add :scope_type, :string, null: false, default: "global"
      add :scope_id, :binary_id
      add :granted, :boolean, default: true, null: false
      add :assigned_by_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :assigned_at, :utc_datetime, null: false
      add :expires_at, :utc_datetime
    end

    create index(:user_permissions, [:user_id])
    create index(:user_permissions, [:permission_id])
    create index(:user_permissions, [:scope_type, :scope_id])
    create index(:user_permissions, [:user_id, :permission_id, :scope_type, :scope_id])

    # Prevent duplicate permission assignments
    create unique_index(:user_permissions, [:user_id, :permission_id, :scope_type, :scope_id],
             name: :user_permission_scope_unique_index
           )
  end
end
