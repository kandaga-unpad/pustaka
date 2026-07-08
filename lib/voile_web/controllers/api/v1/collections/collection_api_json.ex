defmodule VoileWeb.API.V1.Collections.CollectionApiJSON do
  alias Voile.Schema.Catalog.Collection

  @doc """
  Render a list of collections.

  The list view intentionally returns counts instead of full :items and
  :attachments arrays to keep the payload small. Use the show endpoint for
  the full item/attachment data.
  """
  def index(%{collections: collections, pagination: pagination}) do
    %{
      data: for(collection <- collections, do: list_data(collection)),
      pagination: %{
        page_number: pagination.page_number,
        page_size: pagination.page_size,
        total_pages: pagination.total_pages,
        total_count: pagination.total_count
      }
    }
  end

  @doc """
  Render a single collection with full associations (items, attachments, metadata).
  """

  def show(%{collection: collection}) do
    %{data: data(collection)}
  end

  # Compact shape for list views — items/attachments are counts only and
  # metadata is omitted (use the show endpoint for full details).
  defp list_data(%Collection{} = collection) do
    base_data(collection)
    |> Map.put(:items_count, collection.items_count || 0)
    |> Map.put(:attachments_count, collection.attachments_count || 0)
  end

  # Full shape for the show view — includes complete items and attachments.
  defp data(%Collection{} = collection) do
    base_data(collection)
    |> Map.put(:metadata, render_collection_fields(collection.collection_fields))
    |> Map.put(:items, render_items(collection.items))
    |> Map.put(:attachments, render_attachments(collection.attachments))
  end

  # Fields common to both list and show views.
  defp base_data(%Collection{} = collection) do
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
      type: render_resource_class(collection.resource_class),
      creator: render_creator(collection.mst_creator),
      unit: render_node(collection.node),
      inserted_at: collection.inserted_at,
      updated_at: collection.updated_at
    }
  end

  # Association renderers
  defp render_resource_class(nil), do: nil
  defp render_resource_class(%Ecto.Association.NotLoaded{}), do: nil

  defp render_resource_class(resource_class) do
    %{
      id: resource_class.id,
      label: resource_class.label,
      local_name: resource_class.local_name,
      information: resource_class.information,
      glam_type: resource_class.glam_type
    }
  end

  defp render_creator(nil), do: nil
  defp render_creator(%Ecto.Association.NotLoaded{}), do: nil

  defp render_creator(creator) do
    %{
      id: creator.id,
      type: creator.type,
      creator_name: creator.creator_name,
      affiliation: creator.affiliation
    }
  end

  defp render_node(nil), do: nil
  defp render_node(%Ecto.Association.NotLoaded{}), do: nil

  defp render_node(node) do
    %{
      id: node.id,
      name: node.name,
      abbr: node.abbr,
      description: node.description
    }
  end

  defp render_collection_fields(nil), do: []
  defp render_collection_fields(%Ecto.Association.NotLoaded{}), do: []

  defp render_collection_fields(fields) when is_list(fields) do
    Enum.map(fields, &render_collection_field/1)
  end

  defp render_collection_field(field) do
    %{
      id: field.id,
      name: field.name,
      label: field.label,
      value: field.value,
      value_lang: field.value_lang,
      type_value: field.type_value,
      sort_order: field.sort_order,
      property: render_property(field.metadata_properties)
    }
  end

  defp render_property(nil), do: nil
  defp render_property(%Ecto.Association.NotLoaded{}), do: nil

  defp render_property(property) do
    %{
      id: property.id,
      label: property.label,
      local_name: property.local_name,
      information: property.information,
      type_value: property.type_value
    }
  end

  defp render_items(nil), do: []
  defp render_items(%Ecto.Association.NotLoaded{}), do: []

  defp render_items(items) when is_list(items) do
    Enum.map(items, fn item ->
      %{
        id: item.id,
        item_code: item.item_code,
        inventory_code: item.inventory_code,
        barcode: item.barcode,
        location: item.location,
        availability: item.availability,
        collection_id: item.collection_id
      }
    end)
  end

  defp render_attachments(nil), do: []
  defp render_attachments(%Ecto.Association.NotLoaded{}), do: []

  defp render_attachments(attachments) when is_list(attachments) do
    Enum.map(attachments, fn attachment ->
      %{
        id: attachment.id,
        file_name: attachment.file_name,
        file_path: attachment.file_path,
        file_type: attachment.file_type,
        file_size: attachment.file_size,
        is_primary: attachment.is_primary
      }
    end)
  end
end
