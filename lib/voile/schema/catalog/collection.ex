defmodule Voile.Schema.Catalog.Collection do
  use Ecto.Schema
  import Ecto.Changeset

  alias Voile.Schema.Metadata.ResourceClass
  alias Voile.Schema.Metadata.ResourceTemplate
  alias Voile.Schema.Master.Creator
  alias Voile.Schema.System.Node
  alias Voile.Schema.Catalog.CollectionField
  alias Voile.Schema.Catalog.Item
  alias Voile.Schema.Catalog.Attachment

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "collections" do
    field :collection_code, :string
    field :status, :string
    field :description, :string
    field :title, :string
    field :thumbnail, :string
    field :access_level, :string
    field :old_biblio_id, :integer
    field :collection_type, :string
    field :sort_order, :integer

    belongs_to :parent, __MODULE__, type: :binary_id
    belongs_to :resource_class, ResourceClass, foreign_key: :type_id, type: :integer
    belongs_to :resource_template, ResourceTemplate, foreign_key: :template_id, type: :integer
    belongs_to :mst_creator, Creator, foreign_key: :creator_id, type: :integer
    belongs_to :node, Node, foreign_key: :unit_id, type: :integer

    has_many :children, __MODULE__, foreign_key: :parent_id
    has_many :collection_fields, CollectionField, on_replace: :delete

    has_many :items, Item,
      on_delete: :delete_all,
      on_replace: :delete,
      foreign_key: :collection_id

    has_many :attachments, Attachment,
      where: [attachable_type: "collection"],
      foreign_key: :attachable_id,
      on_delete: :delete_all

    timestamps(type: :utc_datetime)
  end

  @statuses ~w(draft pending published archived)
  @access_levels ~w(public private restricted)

  @doc false
  def changeset(collection, attrs) do
    collection
    |> cast(attrs, [
      :id,
      :title,
      :description,
      :thumbnail,
      :status,
      :access_level,
      :type_id,
      :template_id,
      :creator_id,
      :unit_id,
      :parent_id,
      :sort_order,
      :collection_type
    ])
    |> cast_assoc(:collection_fields, with: &CollectionField.changeset/2, required: false)
    |> cast_assoc(:items, with: &Item.changeset/2, required: false)
    |> cast_assoc(:attachments, with: &Attachment.changeset/2, required: false)
    |> validate_required([:title, :description, :status, :access_level, :thumbnail, :creator_id],
      message: "This field is required"
    )
    |> validate_inclusion(:status, @statuses, message: "Status tidak valid")
    |> validate_inclusion(:access_level, @access_levels, message: "Access level tidak valid")
    |> validate_parent_not_self()
    |> validate_no_circular_reference()
  end

  defp validate_parent_not_self(changeset) do
    parent_id = get_change(changeset, :parent_id)
    collection_id = get_field(changeset, :id)

    if parent_id && collection_id && parent_id == collection_id do
      add_error(changeset, :parent_id, "cannot be the same as the collection itself")
    else
      changeset
    end
  end

  defp validate_no_circular_reference(changeset) do
    # This is a basic check - for full circular reference detection,
    # you might want to implement a more complex tree traversal
    changeset
  end

  def remove_thumbnail_changeset(collection) do
    collection
    |> cast(%{thumbnail: nil}, [:thumbnail])
  end

  @doc """
  Get attachments for this collection filtered by file type
  """
  def attachments_by_type(collection, file_type) do
    collection.attachments
    |> Enum.filter(&(&1.file_type == file_type))
  end

  @doc """
  Get primary attachment for this collection
  """
  def primary_attachment(collection) do
    collection.attachments
    |> Enum.find(&(&1.is_primary == true))
  end

  @doc """
  Check if collection is a root collection (no parent)
  """
  def root_collection?(collection) do
    is_nil(collection.parent_id)
  end

  @doc """
  Check if collection is a child collection (has parent)
  """
  def child_collection?(collection) do
    not is_nil(collection.parent_id)
  end

  @doc """
  Get collection types for dropdown
  """
  def collection_type_options do
    [
      {"Series", "series"},
      {"Book", "book"},
      {"Movie", "movie"},
      {"Album", "album"},
      {"Course", "course"},
      {"Other", "other"}
    ]
  end
end
