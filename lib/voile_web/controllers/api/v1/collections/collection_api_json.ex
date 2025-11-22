defmodule VoileWeb.API.V1.Collections.CollectionApiJSON do
  alias Voile.Schema.Catalog.Collection

  @doc """
  Render a list of collections.
  """
  def index(%{collections: collections, pagination: pagination}) do
    %{
      data: for(collection <- collections, do: data(collection)),
      pagination: %{
        page_number: pagination.page_number,
        page_size: pagination.page_size,
        total_pages: pagination.total_pages
      }
    }
  end

  @doc """
  Render a single collection.
  """

  def show(%{collection: collection}) do
    %{data: data(collection)}
  end

  defp data(%Collection{} = collection) do
    %{
      id: collection.id,
      collection_code: collection.collection_code,
      status: collection.status,
      description: collection.description,
      title: collection.title,
      thumbnail: collection.thumbnail,
      access_level: collection.access_level,
      collection_type: collection.collection_type,
      sort_order: collection.sort_order,
      parent_id: collection.parent_id,
      type: collection.resource_class,
      template: collection.resource_template,
      creator: collection.mst_creator,
      unit: collection.node,
      metadata: collection.collection_fields,
      items: collection.items,
      attachments: collection.attachments,
      collection_permissions: collection.collection_permissions,
      created_by_id: collection.created_by_id,
      updated_by_id: collection.updated_by_id,
      inserted_at: collection.inserted_at,
      updated_at: collection.updated_at
    }
  end
end
