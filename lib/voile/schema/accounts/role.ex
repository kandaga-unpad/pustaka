defmodule Voile.Schema.Accounts.Role do
  use Ecto.Schema
  import Ecto.Changeset

  schema "roles" do
    field :name, :string
    field :description, :string
    field :is_system_role, :boolean, default: false

    many_to_many :permissions, Voile.Schema.Accounts.Permission,
      join_through: "role_permissions",
      on_replace: :delete

    has_many :user_role_assignments, Voile.Schema.Accounts.UserRoleAssignment
    has_many :users, through: [:user_role_assignments, :user]

    timestamps()
  end

  @doc false
  def changeset(role, attrs) do
    role
    |> cast(attrs, [:name, :description, :is_system_role])
    |> validate_required([:name])
    |> unique_constraint(:name)
    |> validate_length(:name, min: 3, max: 50)
  end
end
