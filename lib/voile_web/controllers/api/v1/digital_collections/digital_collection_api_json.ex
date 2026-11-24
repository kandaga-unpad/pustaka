defmodule VoileWeb.API.V1.DigitalCollections.DigitalCollectionApiJSON do
  @moduledoc """
  Renders digital collections (published collections that carry digital
  attachments) for the DigitalCollections API.

  File access is intentionally exposed only through ACL-respecting relative
  paths (`reader_url` / `download_url`); raw storage URLs are never returned.
  """

  alias Voile.Schema.Catalog.Collection

  @doc """
  Render a list of digital collections.

  The list view carries a `primary_attachment` (the collection's primary
  digital file) instead of the full attachment array to keep the payload
  small. Use the show endpoint for all attachments and metadata.
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
  Render a single digital collection with full attachments and metadata.
  """
  def show(%{collection: collection}) do
    %{data: data(collection)}
  end

  # Compact shape for list views.
  defp list_data(%Collection{} = collection) do
    attachments = digital_attachments(collection)

    base_data(collection)
    |> Map.put(:attachments_count, length(attachments))
    |> Map.put(:primary_attachment, attachments |> List.first() |> render_attachment())
  end

  # Full shape for the show view.
  defp data(%Collection{} = collection) do
    attachments = digital_attachments(collection)

    base_data(collection)
    |> Map.put(:metadata, render_collection_fields(collection.collection_fields))
    |> Map.put(:attachments_count, length(attachments))
    |> Map.put(:primary_attachment, attachments |> List.first() |> render_attachment())
    |> Map.put(:attachments, Enum.map(attachments, &render_attachment/1))
  end

  defp base_data(%Collection{} = collection) do
    %{
      id: collection.id,
      collection_code: collection.collection_code,
      title: collection.title,
      description: collection.description,
      thumbnail: collection.thumbnail,
      status: collection.status,
      access_level: collection.access_level,
      collection_url: "/collections/#{collection.id}",
      type: render_resource_class(collection.resource_class),
      creator: render_creator(collection.mst_creator),
      unit: render_node(collection.node),
      updated_at: collection.updated_at
    }
  end

  defp digital_attachments(%Collection{} = collection) do
    case collection.digital_attachments do
      attachments when is_list(attachments) -> attachments
      _ -> []
    end
  end

  defp render_attachment(nil), do: nil

  defp render_attachment(attachment) do
    %{
      id: attachment.id,
      file_name: attachment.file_name,
      mime_type: attachment.mime_type,
      file_type: attachment.file_type,
      file_size: attachment.file_size,
      access_level: attachment.access_level,
      is_primary: attachment.is_primary,
      # Both paths are relative to the voile origin and enforce login/access
      # control on voile before serving any bytes.
      reader_url: "/ebooks/view?id=#{attachment.id}",
      download_url: "/attachments/#{attachment.id}/download"
    }
  end

  defp render_resource_class(nil), do: nil
  defp render_resource_class(%Ecto.Association.NotLoaded{}), do: nil

  defp render_resource_class(resource_class) do
    %{
      id: resource_class.id,
      label: resource_class.label,
      local_name: resource_class.local_name,
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
end
