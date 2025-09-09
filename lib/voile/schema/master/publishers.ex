defmodule Voile.Schema.Master.Publishers do
  use Ecto.Schema
  import Ecto.Changeset

  schema "mst_publishers" do
    field :name, :string
    field :address, :string
    field :city, :string
    field :contact, :string

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(publishers, attrs) do
    publishers
    |> cast(attrs, [:name, :city, :address, :contact])
    |> validate_required([:name, :city, :address, :contact])
  end
end
