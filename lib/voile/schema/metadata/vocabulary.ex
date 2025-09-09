defmodule Voile.Schema.Metadata.Vocabulary do
  use Ecto.Schema
  import Ecto.Changeset

  alias Voile.Schema.Accounts.User

  schema "metadata_vocabularies" do
    field :label, :string
    field :prefix, :string
    field :namespace_url, :string
    field :information, :string
    belongs_to :owner, User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(vocabulary, attrs) do
    vocabulary
    |> cast(attrs, [:label, :prefix, :namespace_url, :information])
    |> validate_required([:label, :prefix, :namespace_url, :information])
  end
end
