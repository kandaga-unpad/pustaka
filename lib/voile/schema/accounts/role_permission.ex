defmodule Voile.Schema.Accounts.RolePermission do
  use Ecto.Schema
  import Ecto.Changeset

  schema "roles_permissions" do
    belongs_to :role, Voile.Schema.Accounts.Role
    belongs_to :permission, Voile.Schema.Accounts.Permission

    timestamps(updated_at: false)
  end

  @doc false
  def changeset(role_permission, attrs) do
    role_permission
    |> cast(attrs, [:role_id, :permission_id])
    |> validate_required([:role_id, :permission_id])
    |> unique_constraint([:role_id, :permission_id])
    |> foreign_key_constraint(:role_id)
    |> foreign_key_constraint(:permission_id)
  end
end
