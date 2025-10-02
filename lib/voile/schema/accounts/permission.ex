defmodule Voile.Schema.Accounts.Permission do
  use Ecto.Schema
  import Ecto.Changeset

  schema "permissions" do
    field :name, :string
    field :resource, :string
    field :action, :string
    field :description, :string

    many_to_many :roles, Voile.Schema.Accounts.Role,
      join_through: "roles_permissions",
      on_replace: :delete

    has_many :user_permissions, Voile.Schema.Accounts.UserPermission

    timestamps()
  end

  @doc false
  def changeset(permission, attrs) do
    permission
    |> cast(attrs, [:name, :resource, :action, :description])
    |> validate_required([:name, :resource, :action])
    |> unique_constraint(:name)
    |> validate_format(:name, ~r/^[a-z_]+\.[a-z_]+$/,
      message: "must be in format resource.action (e.g., collections.create)"
    )
  end
end
