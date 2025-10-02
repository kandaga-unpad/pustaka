defmodule Voile.Schema.Accounts.UserRoleAssignment do
  use Ecto.Schema
  import Ecto.Changeset

  schema "user_role_assignments" do
    belongs_to :user, Voile.Schema.Accounts.User, type: :binary_id
    belongs_to :role, Voile.Schema.Accounts.Role

    field :scope_type, :string
    field :scope_id, :binary_id

    belongs_to :assigned_by, Voile.Schema.Accounts.User, type: :binary_id
    field :assigned_at, :utc_datetime
    field :expires_at, :utc_datetime
  end

  @valid_scope_types ~w(global collection item)

  @doc false
  def changeset(assignment, attrs) do
    assignment
    |> cast(attrs, [
      :user_id,
      :role_id,
      :scope_type,
      :scope_id,
      :assigned_by_id,
      :assigned_at,
      :expires_at
    ])
    |> validate_required([:user_id, :role_id, :scope_type])
    |> validate_inclusion(:scope_type, @valid_scope_types)
    |> validate_scope_id()
    |> put_assigned_at()
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:role_id)
    |> foreign_key_constraint(:assigned_by_id)
  end

  defp validate_scope_id(changeset) do
    scope_type = get_field(changeset, :scope_type)
    scope_id = get_field(changeset, :scope_id)

    cond do
      scope_type == "global" and scope_id != nil ->
        add_error(changeset, :scope_id, "must be nil for global scope")

      scope_type in ["collection", "item"] and scope_id == nil ->
        add_error(changeset, :scope_id, "is required for #{scope_type} scope")

      true ->
        changeset
    end
  end

  defp put_assigned_at(changeset) do
    if get_field(changeset, :assigned_at) == nil do
      put_change(changeset, :assigned_at, DateTime.utc_now() |> DateTime.truncate(:second))
    else
      changeset
    end
  end
end
