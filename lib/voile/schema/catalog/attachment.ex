defmodule Voile.Schema.Catalog.Attachment do
  use Ecto.Schema
  import Ecto.Changeset

  alias Voile.Schema.Catalog.Collection
  alias Voile.Schema.Catalog.Item

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "attachments" do
    field :file_name, :string
    field :original_name, :string
    field :file_path, :string
    field :file_size, :integer
    field :mime_type, :string
    field :file_type, :string
    field :description, :string
    field :sort_order, :integer, default: 0
    field :is_primary, :boolean, default: false
    field :metadata, :map, default: %{}

    # Polymorphic associations
    field :attachable_id, :binary_id
    field :attachable_type, :string

    # Virtual field for file upload
    field :file, :any, virtual: true

    timestamps(type: :utc_datetime)
  end
end
