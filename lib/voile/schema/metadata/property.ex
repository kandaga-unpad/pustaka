defmodule Voile.Schema.Metadata.Property do
  use Ecto.Schema
  import Ecto.Changeset

  alias Voile.Schema.Accounts.User
  alias Voile.Schema.Metadata.Vocabulary

  @input_types ~w(
  text number email password date datetime-local month search tel time url week
  checkbox radio file hidden color range textarea select
)

  schema "metadata_properties" do
    field :label, :string
    field :local_name, :string
    field :information, :string

    field :type_value, :string

    belongs_to :owner, User
    belongs_to :vocabulary, Vocabulary

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(property, attrs) do
    property
    |> cast(attrs, [:label, :local_name, :information, :type_value, :vocabulary_id, :owner_id])
    |> validate_required([:label, :local_name, :type_value, :vocabulary_id, :owner_id])
    |> validate_inclusion(:type_value, @input_types)
  end
end
