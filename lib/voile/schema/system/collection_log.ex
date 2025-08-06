defmodule Voile.Schema.System.CollectionLog do
  use Ecto.Schema
  import Ecto.Changeset

  alias Voile.Schema.Catalog.Collection
  alias Voile.Schema.Accounts.User

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "collection_logs" do
    field :message, :string
    field :title, :string
    field :action, :string
    belongs_to :collection, Collection
    belongs_to :user, User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(collection_log, attrs) do
    collection_log
    |> cast(attrs, [:title, :message, :action])
    |> validate_required([:title, :message, :action])
  end
end
