defmodule Voile.Schema.Master.Creator do
  use Ecto.Schema
  import Ecto.Changeset

  schema "mst_creator" do
    field :type, :string
    field :creator_name, :string
    field :creator_contact, :string
    field :affiliation, :string

    timestamps(type: :utc_datetime)
  end

  @types ~w(Person Organization Group Conference Event Project Institution)

  @doc false
  def changeset(creator, attrs) do
    creator
    |> cast(attrs, [:creator_name, :creator_contact, :affiliation, :type])
    |> validate_required([:creator_name])
    |> unique_constraint(:creator_name)
    |> validate_inclusion(:type, @types)
  end
end
