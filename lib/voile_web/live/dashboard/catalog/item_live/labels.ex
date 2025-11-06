defmodule VoileWeb.Dashboard.Catalog.ItemLive.Labels do
  use VoileWeb, :live_view_dashboard

  alias Voile.Schema.Catalog
  import VoileWeb.Components.LabelComponents

  @impl true
  def mount(_params, _session, socket) do
    # Check read permission for viewing items
    authorize!(socket, "items.read")

    {:ok,
     socket
     |> assign(:page_title, "Print Item Labels")
     |> assign(:selected_items, [])
     |> assign(:selected_item_data, %{})
     |> assign(:search, "")
     |> assign(:items, [])
     |> assign(:collections, [])
     |> assign(:group_by_collection, false)
     |> assign(:label_size, "medium")
     |> assign(:labels_per_row, 2)
     |> assign(:include_barcode, true)
     |> assign(:include_location, true)
     |> assign(:include_call_number, true)
     |> assign(:font_size, "base")
     |> stream(:items, [])
     |> stream(:collections, [])}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("search", %{"search" => %{"q" => query}}, socket) do
    group_by_collection = socket.assigns.group_by_collection

    if group_by_collection do
      # Search for collections
      collections =
        if query != "" do
          Catalog.search_collections(query)
        else
          []
        end

      {:noreply,
       socket
       |> assign(:search, query)
       |> assign(:collections, collections)
       |> stream(:collections, collections, reset: true)}
    else
      # Search for items
      items =
        if query != "" do
          Catalog.search_items(query)
        else
          []
        end

      {:noreply,
       socket
       |> assign(:search, query)
       |> assign(:items, items)
       |> stream(:items, items, reset: true)}
    end
  end

  @impl true
  def handle_event("toggle_group_by_collection", %{"value" => value}, socket) do
    group_by_collection = value == "on"

    {:noreply,
     socket
     |> assign(:group_by_collection, group_by_collection)
     |> assign(:search, "")
     |> assign(:items, [])
     |> assign(:collections, [])
     |> stream(:items, [], reset: true)
     |> stream(:collections, [], reset: true)}
  end

  @impl true
  def handle_event("select_collection", %{"collection-id" => collection_id}, socket) do
    # Fetch all items for this collection
    items = Catalog.get_items_by_collection(collection_id)

    # Add all items to selection
    selected = socket.assigns.selected_items
    selected_data = socket.assigns.selected_item_data

    new_items = Enum.reject(items, fn item -> to_string(item.id) in selected end)
    new_ids = Enum.map(new_items, fn item -> to_string(item.id) end)
    new_data = Map.new(new_items, fn item -> {to_string(item.id), item} end)

    {:noreply,
     socket
     |> assign(:selected_items, selected ++ new_ids)
     |> assign(:selected_item_data, Map.merge(selected_data, new_data))}
  end

  @impl true
  def handle_event("toggle_item", %{"item-id" => item_id}, socket) do
    selected = socket.assigns.selected_items
    selected_data = socket.assigns.selected_item_data

    {new_selected, new_data} =
      if item_id in selected do
        # Remove from selection
        {List.delete(selected, item_id), Map.delete(selected_data, item_id)}
      else
        # Add to selection - find the full item data
        item = Enum.find(socket.assigns.items, fn i -> to_string(i.id) == to_string(item_id) end)

        if item do
          {[item_id | selected], Map.put(selected_data, item_id, item)}
        else
          {selected, selected_data}
        end
      end

    {:noreply,
     socket
     |> assign(:selected_items, new_selected)
     |> assign(:selected_item_data, new_data)}
  end

  @impl true
  def handle_event("select_all", _params, socket) do
    items = socket.assigns.items
    all_ids = Enum.map(items, & &1.id)
    all_data = Map.new(items, fn item -> {to_string(item.id), item} end)

    {:noreply,
     socket
     |> assign(:selected_items, all_ids)
     |> assign(:selected_item_data, all_data)}
  end

  @impl true
  def handle_event("deselect_all", _params, socket) do
    {:noreply,
     socket
     |> assign(:selected_items, [])
     |> assign(:selected_item_data, %{})}
  end

  @impl true
  def handle_event("update_label_config", params, socket) do
    socket =
      socket
      |> assign(:label_size, params["label_size"] || socket.assigns.label_size)
      |> assign(
        :labels_per_row,
        String.to_integer(params["labels_per_row"] || "#{socket.assigns.labels_per_row}")
      )
      |> assign(
        :include_barcode,
        params["include_barcode"] == "true"
      )
      |> assign(
        :include_location,
        params["include_location"] == "true"
      )
      |> assign(
        :include_call_number,
        params["include_call_number"] == "true"
      )
      |> assign(:font_size, params["font_size"] || socket.assigns.font_size)

    {:noreply, socket}
  end

  @impl true
  def handle_event("print_labels", _params, socket) do
    # JavaScript will handle the actual printing
    {:noreply, socket}
  end
end
