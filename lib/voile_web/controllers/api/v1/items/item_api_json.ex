defmodule VoileWeb.API.V1.Items.ItemApiJSON do
  alias Voile.Schema.Catalog.Item

  @doc """
  Render a list of items.
  """
  def index(%{items: items, pagination: pagination}) do
    %{
      data: for(item <- items, do: data(item)),
      pagination: %{
        page_number: pagination.page_number,
        page_size: pagination.page_size,
        total_pages: pagination.total_pages
      }
    }
  end

  @doc """
  Render a single item.
  """
  def show(%{item: item}) do
    %{data: data(item)}
  end

  defp data(%Item{} = item) do
    %{
      id: item.id,
      item_code: item.item_code,
      inventory_code: item.inventory_code,
      barcode: item.barcode,
      location: item.location,
      status: item.status,
      condition: item.condition,
      availability: item.availability,
      price: item.price,
      acquisition_date: item.acquisition_date,
      last_inventory_date: item.last_inventory_date,
      last_circulated: item.last_circulated,
      rfid_tag: item.rfid_tag,
      legacy_item_code: item.legacy_item_code,
      collection: render_collection(item.collection),
      unit: render_node(item.node),
      item_location: render_item_location(item.item_location),
      created_by: render_user(item.created_by),
      updated_by: render_user(item.updated_by),
      attachments: render_attachments(item.attachments),
      inserted_at: item.inserted_at,
      updated_at: item.updated_at
    }
  end

  # Association renderers
  defp render_collection(nil), do: nil
  defp render_collection(%Ecto.Association.NotLoaded{}), do: nil

  defp render_collection(collection) do
    %{
      id: collection.id,
      collection_code: collection.collection_code,
      title: collection.title,
      description: collection.description
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

  defp render_item_location(nil), do: nil
  defp render_item_location(%Ecto.Association.NotLoaded{}), do: nil

  defp render_item_location(location) do
    %{
      id: location.id,
      name: location.name,
      description: location.description
    }
  end

  defp render_user(nil), do: nil
  defp render_user(%Ecto.Association.NotLoaded{}), do: nil

  defp render_user(user) do
    %{
      id: user.id,
      email: user.email,
      first_name: user.first_name,
      last_name: user.last_name
    }
  end

  defp render_attachments(nil), do: []
  defp render_attachments(%Ecto.Association.NotLoaded{}), do: []

  defp render_attachments(attachments) when is_list(attachments) do
    Enum.map(attachments, fn attachment ->
      %{
        id: attachment.id,
        filename: attachment.file_name,
        original_name: attachment.original_name,
        file_path: attachment.file_path,
        file_size: attachment.file_size,
        mime_type: attachment.mime_type,
        file_type: attachment.file_type,
        description: attachment.description,
        is_primary: attachment.is_primary,
        sort_order: attachment.sort_order
      }
    end)
  end
end
