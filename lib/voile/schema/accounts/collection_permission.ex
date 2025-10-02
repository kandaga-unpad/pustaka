defmodule Voile.Schema.Accounts.CollectionPermission do
  use Ecto.Schema
  import Ecto.Changeset

  schema "collection_permissions" do
    belongs_to :collection, Voile.Schema.Catalog.Collection, type: :binary_id
    belongs_to :user, Voile.Schema.Accounts.User, type: :binary_id
    belongs_to :role, Voile.Schema.Accounts.Role

    field :permission_level, :string

    timestamps()
  end

  @valid_levels ~w(owner editor viewer)

  @doc false
  def changeset(collection_permission, attrs) do
    collection_permission
    |> cast(attrs, [:collection_id, :user_id, :role_id, :permission_level])
    |> validate_required([:collection_id, :permission_level])
    |> validate_inclusion(:permission_level, @valid_levels)
    |> validate_user_or_role()
    |> foreign_key_constraint(:collection_id)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:role_id)
  end

  defp validate_user_or_role(changeset) do
    user_id = get_field(changeset, :user_id)
    role_id = get_field(changeset, :role_id)

    cond do
      user_id == nil and role_id == nil ->
        add_error(changeset, :user_id, "either user_id or role_id must be present")

      user_id != nil and role_id != nil ->
        add_error(changeset, :user_id, "cannot set both user_id and role_id")

      true ->
        changeset
    end
  end
end
