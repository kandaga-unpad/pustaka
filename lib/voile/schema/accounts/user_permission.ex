defmodule Voile.Schema.Accounts.UserPermission do
  use Ecto.Schema
  import Ecto.Changeset

  schema "user_permissions" do
    belongs_to :user, Voile.Schema.Accounts.User, type: :binary_id
    belongs_to :permission, Voile.Schema.Accounts.Permission

    field :scope_type, :string
    field :scope_id, :binary_id

    field :granted, :boolean, default: true

    belongs_to :assigned_by, Voile.Schema.Accounts.User, type: :binary_id
    field :assigned_at, :utc_datetime
    field :expires_at, :utc_datetime
  end

  @valid_scope_types ~w(global collection item)

  @doc false
  def changeset(user_permission, attrs) do
    user_permission
    |> cast(attrs, [
      :user_id,
      :permission_id,
      :scope_type,
      :scope_id,
      :granted,
      :assigned_by_id,
      :assigned_at,
      :expires_at
    ])
    |> validate_required([:user_id, :permission_id, :scope_type, :granted])
    |> validate_inclusion(:scope_type, @valid_scope_types)
    |> put_assigned_at()
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:permission_id)
    |> foreign_key_constraint(:assigned_by_id)
  end

  defp put_assigned_at(changeset) do
    if get_field(changeset, :assigned_at) == nil do
      put_change(changeset, :assigned_at, DateTime.utc_now() |> DateTime.truncate(:second))
    else
      changeset
    end
  end
end
