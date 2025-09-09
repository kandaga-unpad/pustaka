defmodule Voile.Schema.Accounts.UserRole do
  use Ecto.Schema
  import Ecto.Changeset

  schema "user_roles" do
    field :name, :string
    field :permissions, :map, default: %{}
    field :description, :string

    timestamps(type: :utc_datetime)
  end

  def changeset(user_role, attrs) do
    user_role
    |> cast(attrs, [:name, :permissions, :description])
    |> validate_required([:name])
    |> validate_length(:name, min: 2, max: 100)
    |> validate_permissions()
    |> unique_constraint(:name)
  end

  defp validate_permissions(changeset) do
    case get_change(changeset, :permissions) do
      nil ->
        changeset

      permissions when is_map(permissions) ->
        if valid_permissions_structure?(permissions) do
          changeset
        else
          add_error(changeset, :permissions, "has invalid structure")
        end

      _ ->
        add_error(changeset, :permissions, "must be a map")
    end
  end

  defp valid_permissions_structure?(permissions) when is_map(permissions) do
    Enum.all?(permissions, fn {_resource, actions} ->
      is_map(actions) and
        Enum.all?(actions, fn {action, value} ->
          action in ["create", "read", "update", "delete"] and is_boolean(value)
        end)
    end)
  end
end
