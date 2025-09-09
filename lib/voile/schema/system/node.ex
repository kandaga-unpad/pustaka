defmodule Voile.Schema.System.Node do
  use Ecto.Schema
  import Ecto.Changeset

  schema "nodes" do
    field :name, :string
    field :image, :string
    field :abbr, :string
    field :description, :string

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(node, attrs) do
    node
    |> cast(attrs, [:name, :abbr, :image])
    |> validate_required([:name, :abbr])
  end
end
