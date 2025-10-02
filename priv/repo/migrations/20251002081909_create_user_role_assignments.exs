defmodule Voile.Repo.Migrations.CreateUserRoleAssignments do
  use Ecto.Migration

  def change do
    create table(:user_role_assignments) do
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :role_id, references(:roles, on_delete: :delete_all), null: false
      add :scope_type, :string, null: false, default: "global"
      add :scope_id, :binary_id
      add :assigned_by_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :assigned_at, :utc_datetime, null: false
      add :expires_at, :utc_datetime
    end

    create index(:user_role_assignments, [:user_id])
    create index(:user_role_assignments, [:role_id])
    create index(:user_role_assignments, [:scope_type, :scope_id])
    create index(:user_role_assignments, [:user_id, :scope_type, :scope_id])

    # Prevent duplicate role assignments for same user/role/scope
    create unique_index(:user_role_assignments, [:user_id, :role_id, :scope_type, :scope_id],
             name: :user_role_scope_unique_index
           )
  end
end
