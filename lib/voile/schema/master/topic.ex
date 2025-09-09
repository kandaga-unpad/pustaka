defmodule Voile.Schema.Master.Topic do
  use Ecto.Schema
  import Ecto.Changeset

  schema "mst_topics" do
    field :name, :string
    field :type, :string
    field :description, :string

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(topic, attrs) do
    topic
    |> cast(attrs, [:name, :type, :description])
    |> validate_required([:name, :type, :description])
  end
end
