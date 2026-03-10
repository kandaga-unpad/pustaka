defmodule VoileWeb.Dashboard.Catalog.ItemLive.Labels do
  use VoileWeb, :live_view_dashboard

  alias Voile.Schema.Catalog
  require Logger
  import VoileWeb.Components.LabelComponents

  # Converts a logo URL to an inline base64 data URI so it renders correctly
  # inside the hidden print container (browsers skip loading images in
  # display:none elements, so a plain src URL would show nothing when printing).
  defp logo_to_data_uri(nil), do: nil

  defp logo_to_data_uri(url) when is_binary(url) do
    cond do
      # Local file: URL starts with /uploads, map to priv/static on disk
      String.starts_with?(url, "/") ->
        path = Path.join([:code.priv_dir(:voile), "static", url])

        case File.read(path) do
          {:ok, data} ->
            mime = mime_from_path(url)
            "data:#{mime};base64,#{Base.encode64(data)}"

          {:error, _} ->
            url
        end

      # Remote URL: fetch via Req
      String.starts_with?(url, "http://") or String.starts_with?(url, "https://") ->
        case Req.get(url, receive_timeout: 5_000) do
          {:ok, %{status: 200, body: data}} when is_binary(data) ->
            mime = mime_from_path(url)
            "data:#{mime};base64,#{Base.encode64(data)}"

          _ ->
            url
        end

      true ->
        url
    end
  end

  defp mime_from_path(url) do
    cond do
      String.ends_with?(url, ".png") -> "image/png"
      String.ends_with?(url, ".jpg") or String.ends_with?(url, ".jpeg") -> "image/jpeg"
      String.ends_with?(url, ".webp") -> "image/webp"
      String.ends_with?(url, ".svg") -> "image/svg+xml"
      String.ends_with?(url, ".gif") -> "image/gif"
      true -> "image/png"
    end
  end

  @impl true
  def mount(_params, _session, socket) do
    # Check read permission for viewing items
    authorize!(socket, "items.read")

    raw_logo_url = Voile.Schema.System.get_setting_value("app_logo_url", nil)
    app_logo_url = logo_to_data_uri(raw_logo_url)

    {:ok,
     socket
     |> assign(:page_title, gettext("Print Item Labels"))
     |> assign(:app_logo_url, app_logo_url)
     |> assign(:selected_items, [])
     |> assign(:selected_item_data, %{})
     |> assign(:search, "")
     |> assign(:items, [])
     |> assign(:collections, [])
     |> assign(:group_by_collection, false)
     |> assign(:label_size, "medium")
     |> assign(:labels_per_row, 2)
     |> assign(:paper_size, "default")
     |> assign(:include_barcode, true)
     |> assign(:include_location, true)
     |> assign(:include_call_number, true)
     |> assign(:include_border, true)
     |> assign(:saved_concept, nil)
     |> stream(:items, [])
     |> stream(:collections, [])}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("search", %{"search" => %{"q" => query}}, socket) do
    current_user = socket.assigns.current_scope.user
    group_by_collection = socket.assigns.group_by_collection

    if group_by_collection do
      # Search for collections with item counts
      collections =
        if query != "" do
          Catalog.search_collections(query, current_user)
          |> Enum.map(fn collection ->
            item_count = Catalog.count_items_by_collection(collection.id)
            Map.put(collection, :item_count, item_count)
          end)
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
          Catalog.search_items(query, current_user)
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
    current_user = socket.assigns.current_scope.user
    # Fetch all items for this collection
    items = Catalog.get_items_by_collection(collection_id, current_user)

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

    # Normalize id to string for consistent storage
    item_id_str = to_string(item_id)

    {new_selected, new_data} =
      if item_id_str in selected do
        # Remove from selection
        {List.delete(selected, item_id_str), Map.delete(selected_data, item_id_str)}
      else
        # Add to selection - try to find the full item data from assigns first,
        # fall back to DB fetch if it's not present (prevents list clearing).
        item =
          Enum.find(socket.assigns.items, fn i -> to_string(i.id) == item_id_str end) ||
            try do
              Catalog.get_item!(String.to_integer(item_id_str))
            rescue
              _ -> nil
            end

        if item do
          {[item_id_str | selected], Map.put(selected_data, item_id_str, item)}
        else
          {selected, selected_data}
        end
      end

    # Debugging info to help trace why the items stream might disappear
    Logger.debug(
      "toggle_item: selected_count=#{length(new_selected || [])} items_len=#{length(socket.assigns.items || [])} streams=#{inspect(Map.keys(socket.assigns.streams || %{}))}"
    )

    {:noreply,
     socket
     |> assign(:selected_items, new_selected)
     |> assign(:selected_item_data, new_data)}
  end

  @impl true
  def handle_event("select_all", _params, socket) do
    items = socket.assigns.items
    # Use string IDs consistently
    all_ids = Enum.map(items, &to_string(&1.id))
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
      |> assign(:labels_per_row, 2)
      |> assign(:paper_size, params["paper_size"] || socket.assigns.paper_size)
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
      |> assign(
        :include_border,
        params["include_border"] == "true"
      )

    {:noreply, socket}
  end

  @impl true
  def handle_event("save_concept", _params, socket) do
    concept = %{
      selected_items: socket.assigns.selected_items,
      selected_item_data: socket.assigns.selected_item_data
    }

    {:noreply, assign(socket, :saved_concept, concept)}
  end

  @impl true
  def handle_event("delete_concept", _params, socket) do
    {:noreply,
     socket
     |> assign(:saved_concept, nil)
     |> assign(:selected_items, [])
     |> assign(:selected_item_data, %{})}
  end

  @impl true
  def handle_event("restore_concept", _params, socket) do
    case socket.assigns.saved_concept do
      nil ->
        {:noreply, socket}

      concept ->
        {:noreply,
         socket
         |> assign(:selected_items, concept.selected_items)
         |> assign(:selected_item_data, concept.selected_item_data)}
    end
  end

  @impl true
  def handle_event("print_labels", _params, socket) do
    # JavaScript will handle the actual printing
    {:noreply, socket}
  end
end
