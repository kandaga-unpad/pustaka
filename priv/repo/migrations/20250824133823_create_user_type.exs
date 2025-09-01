defmodule Voile.Repo.Migrations.CreateUserType do
  use Ecto.Migration

  def change do
    alter table(:users) do
      remove :user_type
      add :user_type_id, references(:mst_member_types, on_delete: :nilify_all, type: :binary_id)
    end

    # Add performance indexes for the new foreign keys
    create index(:users, [:user_type_id])
  end
end
