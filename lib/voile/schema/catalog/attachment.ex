defmodule Voile.Schema.Catalog.Attachment do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

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

  @file_types ~w(document image video audio software archive other)
  @attachable_types ~w(collection item)

  @doc false
  def changeset(attachment, attrs) do
    attachment
    |> cast(attrs, [
      :file_name,
      :original_name,
      :file_path,
      :file_size,
      :mime_type,
      :file_type,
      :description,
      :sort_order,
      :is_primary,
      :metadata,
      :attachable_id,
      :attachable_type
    ])
    |> validate_required([
      :file_name,
      :original_name,
      :file_path,
      :file_size,
      :mime_type,
      :file_type,
      :attachable_id,
      :attachable_type
    ])
    |> validate_inclusion(:file_type, @file_types)
    |> validate_inclusion(:attachable_type, @attachable_types)
    |> validate_number(:file_size, greater_than: 0)
    |> validate_number(:sort_order, greater_than_or_equal_to: 0)
    |> unique_constraint([:attachable_id, :attachable_type, :file_name],
      name: :attachments_unique_file_per_entity
    )
  end

  @doc """
  Determines file type based on mime type
  """
  def determine_file_type(mime_type) do
    case mime_type do
      "image/" <> _ -> "image"
      "video/" <> _ -> "video"
      "audio/" <> _ -> "audio"
      "application/pdf" -> "document"
      "application/msword" -> "document"
      "application/vnd.openxmlformats-officedocument.wordprocessingml.document" -> "document"
      "application/vnd.ms-excel" -> "document"
      "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" -> "document"
      "application/zip" -> "archive"
      "application/x-rar-compressed" -> "archive"
      "application/x-7z-compressed" -> "archive"
      "application/octet-stream" -> "software"
      "application/x-executable" -> "software"
      "application/x-msdownload" -> "software"
      _ -> "other"
    end
  end

  @doc """
  Get attachments for a specific entity
  """
  def for_entity(query, entity_id, entity_type) do
    from a in query,
      where: a.attachable_id == ^entity_id and a.attachable_type == ^entity_type,
      order_by: [asc: a.sort_order, asc: a.inserted_at]
  end

  @doc """
  Get primary attachment for an entity
  """
  def primary_for_entity(query, entity_id, entity_type) do
    from a in query,
      where:
        a.attachable_id == ^entity_id and a.attachable_type == ^entity_type and
          a.is_primary == true,
      limit: 1
  end

  @doc """
  Get attachments by file type
  """
  def by_file_type(query, file_type) do
    from a in query, where: a.file_type == ^file_type
  end
end
