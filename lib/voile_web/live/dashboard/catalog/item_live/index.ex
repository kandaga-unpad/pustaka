defmodule VoileWeb.Dashboard.Catalog.ItemLive.Index do
  use VoileWeb, :live_view_dashboard

  alias Voile.Schema.Catalog
  alias Voile.Schema.Catalog.Item

  @impl true
  def mount(_params, _session, socket) do
    # Check read permission for viewing items
    authorize!(socket, "items.read")

    page = 1
    per_page = 10
    search = ""

    # Get current user
    current_user = socket.assigns.current_scope.user

    # Initialize empty filters, then apply role-based filters
    filters = %{}
    filters = Catalog.apply_role_based_filters(current_user, filters)

    # Load the first page of items on initial mount with role-based filters applied
    {items, total_pages, _} = Catalog.list_items_paginated(page, per_page, search, filters)

    # Get user's node for automatic filtering
    user_node_id = current_user.node_id
    is_admin = Catalog.is_user_admin?(current_user)

    # Load nodes and master locations once in the LiveView so the component
    # does not need to make DB calls. We'll pass these assigns into the
    # form component when rendering the modal.
    nodes = Voile.Schema.System.list_nodes()
    node_options = Enum.map(nodes, fn n -> {"#{n.name} (#{n.abbr})", n.id} end)
    all_locations = Voile.Schema.Master.list_mst_locations()

    # For non-admin users, filter locations to only their node's locations
    available_locations =
      if is_admin do
        all_locations
      else
        Enum.filter(all_locations, &(&1.node_id == user_node_id))
      end

    # Load filter options from Item schema
    status_options = Item.status_options()
    condition_options = Item.condition_options()
    availability_options = Item.availability_options()

    # Initialize filtered_locations if node_id is already set in filters
    filtered_locations =
      if filters[:node_id] && filters[:node_id] != "" do
        node_id =
          if is_binary(filters[:node_id]),
            do: String.to_integer(filters[:node_id]),
            else: filters[:node_id]

        Enum.filter(available_locations, &(&1.node_id == node_id))
      else
        # For non-admin, show their node's locations by default
        if !is_admin && user_node_id do
          Enum.filter(available_locations, &(&1.node_id == user_node_id))
        else
          []
        end
      end

    # Extract individual filter values for template display
    filter_node_id = to_string(filters[:node_id] || "")
    active_filters_count = count_active_filters(filters)

    socket =
      socket
      |> stream(:items, items, reset: false)
      |> assign(:page_title, gettext("Listing Items"))
      |> assign(:page, page)
      |> assign(:search, search)
      |> assign(:total_pages, total_pages)
      |> assign(:items_empty?, items == [])
      |> assign(:items_count, length(items))
      |> assign(:filters, filters)
      |> assign(:user_node_id, user_node_id)
      |> assign(:current_user, current_user)
      |> assign(:is_admin, is_admin)
      |> assign(:nodes, node_options)
      |> assign(:all_locations, all_locations)
      |> assign(:available_locations, available_locations)
      |> assign(:status_options, status_options)
      |> assign(:condition_options, condition_options)
      |> assign(:availability_options, availability_options)
      |> assign(:filter_status, filters[:status] || "")
      |> assign(:filter_availability, filters[:availability] || "")
      |> assign(:filter_condition, filters[:condition] || "")
      |> assign(:filter_node_id, filter_node_id)
      |> assign(:filter_location_id, filters[:location_id] || "")
      |> assign(:active_filters_count, active_filters_count)
      |> assign(:filtered_locations, filtered_locations)

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    # Check update permission for editing items
    authorize!(socket, "items.update")

    item = Catalog.get_item!(id)
    current_user = socket.assigns.current_user

    # Verify user has access to this item's unit
    if Catalog.is_user_admin?(current_user) or item.unit_id == current_user.node_id do
      socket
      |> assign(:page_title, gettext("Edit Item"))
      |> assign(:item, item)
    else
      socket
      |> put_flash(:error, gettext("Access Denied: You don't have permission to edit this item"))
      |> push_navigate(to: ~p"/manage/catalog/items")
    end
  end

  defp apply_action(socket, :new, _params) do
    # Check create permission for creating new items
    authorize!(socket, "items.create")

    socket
    |> assign(:page_title, gettext("New Item"))
    |> assign(:item, %Item{})
  end

  defp apply_action(socket, :index, params) do
    # When returning to index (e.g., after closing modal), always refresh items
    # to ensure the stream is properly maintained
    page = params["page"] || socket.assigns.page || 1
    page = if is_binary(page), do: String.to_integer(page), else: page

    per_page = 10
    search = socket.assigns.search || ""
    filters = socket.assigns.filters || %{}

    {items, total_pages, _} = Catalog.list_items_paginated(page, per_page, search, filters)

    # Recalculate filtered_locations based on current filters
    filtered_locations =
      if filters[:node_id] && filters[:node_id] != "" do
        node_id =
          if is_binary(filters[:node_id]),
            do: String.to_integer(filters[:node_id]),
            else: filters[:node_id]

        Enum.filter(socket.assigns.available_locations, &(&1.node_id == node_id))
      else
        socket.assigns[:filtered_locations] || []
      end

    socket
    |> stream(:items, items, reset: true)
    |> assign(:page_title, gettext("Listing Items"))
    |> assign(:item, nil)
    |> assign(:page, page)
    |> assign(:total_pages, total_pages)
    |> assign(:items_empty?, items == [])
    |> assign(:items_count, length(items))
    |> assign(:filtered_locations, filtered_locations)
  end

  @impl true
  def handle_info({VoileWeb.Dashboard.Catalog.ItemLive.FormComponent, {:saved, item}}, socket) do
    # Always insert new items at the top
    socket = stream_insert(socket, :items, item, at: 0)
    items_count = (socket.assigns[:items_count] || 0) + 1
    {:noreply, assign(socket, %{items_empty?: false, items_count: items_count})}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    # Check delete permission before deleting
    authorize!(socket, "items.delete")

    item = Catalog.get_item!(id)
    current_user = socket.assigns.current_user

    # Verify user has access to this item's unit
    if Catalog.is_user_admin?(current_user) or item.unit_id == current_user.node_id do
      {:ok, _} = Catalog.delete_item(item)

      # Re-fetch the current page with filters
      search = socket.assigns[:search] || ""
      filters = socket.assigns[:filters] || %{}
      page = socket.assigns[:page] || 1
      per_page = 10

      {items, total_pages, _} = Catalog.list_items_paginated(page, per_page, search, filters)

      socket =
        socket
        |> stream(:items, items, reset: true)
        |> assign(:page, page)
        |> assign(:total_pages, total_pages)
        |> assign(:items_empty?, items == [])
        |> assign(:items_count, length(items))

      {:noreply, socket}
    else
      {:noreply,
       socket
       |> put_flash(
         :error,
         gettext("Access Denied: You don't have permission to delete this item")
       )}
    end
  end

  @impl true
  def handle_event("paginate", %{"page" => page}, socket) do
    page =
      case page do
        p when is_integer(p) -> p
        p when is_binary(p) -> String.to_integer(p)
        _ -> 1
      end

    per_page = 10
    search = socket.assigns[:search] || ""
    filters = socket.assigns[:filters] || %{}

    {items, total_pages, _} = Catalog.list_items_paginated(page, per_page, search, filters)

    socket =
      socket
      |> stream(:items, items, reset: true)
      |> assign(:page, page)
      |> assign(:total_pages, total_pages)
      |> assign(:items_empty?, items == [])
      |> assign(:items_count, length(items))

    {:noreply, socket}
  end

  @impl true
  def handle_event("search", %{"q" => q}, socket) do
    start_time = System.monotonic_time(:millisecond)

    page = 1
    per_page = 10
    filters = socket.assigns[:filters] || %{}

    # perform the search and show results with filters
    {items, total_pages, _} = Catalog.list_items_paginated(page, per_page, q, filters)

    query_time = System.monotonic_time(:millisecond) - start_time
    IO.puts("Search query took #{query_time}ms for search term: '#{q}'")

    socket =
      socket
      |> stream(:items, items, reset: true)
      |> assign(:page, page)
      |> assign(:total_pages, total_pages)
      |> assign(:search, q)
      |> assign(:items_empty?, items == [])
      |> assign(:items_count, length(items))

    {:noreply, socket}
  end

  @impl true
  def handle_event("clear_search", _params, socket) do
    # Clear search but maintain filters and filtered_locations
    page = 1
    per_page = 10
    filters = socket.assigns[:filters] || %{}

    {items, total_pages, _} = Catalog.list_items_paginated(page, per_page, "", filters)

    socket =
      socket
      |> stream(:items, items, reset: true)
      |> assign(:page, page)
      |> assign(:total_pages, total_pages)
      |> assign(:search, "")
      |> assign(:items_empty?, items == [])
      |> assign(:items_count, length(items))

    {:noreply, socket}
  end

  @impl true
  def handle_event("noop", _params, socket) do
    # The search form is phx-submit="noop" to avoid full page reload on Enter.
    # This event is intentionally a no-op to keep LiveView stable.
    {:noreply, socket}
  end

  @impl true
  def handle_event("filter_change", params, socket) do
    # Extract params - form uses as={:filter} but params come as nested map
    filter_params = params["filter"] || params
    target_field = get_target_field(filter_params)
    is_admin = socket.assigns.is_admin
    user_node_id = socket.assigns.user_node_id

    # Start with current filter state
    current_filters = %{
      status: socket.assigns.filter_status,
      availability: socket.assigns.filter_availability,
      condition: socket.assigns.filter_condition,
      node_id: socket.assigns.filter_node_id,
      location_id: socket.assigns.filter_location_id
    }

    # For non-admin users, force their node_id and prevent changes
    filter_params =
      if !is_admin && user_node_id do
        Map.put(filter_params, "node_id", to_string(user_node_id))
      else
        filter_params
      end

    # Check if this is a clear action (from phx-value buttons)
    filters =
      if target_field == nil && has_clear_value?(filter_params) do
        apply_clear_filter(current_filters, filter_params, is_admin, user_node_id)
      else
        merge_filters_smart(current_filters, filter_params, target_field, is_admin, user_node_id)
      end

    current_user = socket.assigns.current_user
    filters = Catalog.apply_role_based_filters(current_user, filters)

    active_count = count_active_filters(filters)

    # Load locations based on selected node
    filtered_locations =
      if filters[:node_id] && filters[:node_id] != "" do
        node_id =
          if is_binary(filters[:node_id]),
            do: String.to_integer(filters[:node_id]),
            else: filters[:node_id]

        Enum.filter(socket.assigns.available_locations, &(&1.node_id == node_id))
      else
        []
      end

    search = socket.assigns.search
    page = 1
    per_page = 10

    {items, total_pages, _} = Catalog.list_items_paginated(page, per_page, search, filters)

    # Convert filter values to strings for form display
    filter_node_id_str = to_string(filters[:node_id] || "")
    filter_location_id_str = to_string(filters[:location_id] || "")

    socket =
      socket
      |> stream(:items, items, reset: true)
      |> assign(:filters, filters)
      |> assign(:filter_status, to_string(filters[:status] || ""))
      |> assign(:filter_availability, to_string(filters[:availability] || ""))
      |> assign(:filter_condition, to_string(filters[:condition] || ""))
      |> assign(:filter_node_id, filter_node_id_str)
      |> assign(:filter_location_id, filter_location_id_str)
      |> assign(:filtered_locations, filtered_locations)
      |> assign(:active_filters_count, active_count)
      |> assign(:page, page)
      |> assign(:total_pages, total_pages)
      |> assign(:items_empty?, items == [])
      |> assign(:items_count, length(items))

    {:noreply, socket}
  end

  @impl true
  def handle_event("clear_filters", _params, socket) do
    filters = %{}

    current_user = socket.assigns.current_user
    filters = Catalog.apply_role_based_filters(current_user, filters)

    search = socket.assigns.search
    page = 1
    per_page = 10

    {items, total_pages, _} = Catalog.list_items_paginated(page, per_page, search, filters)

    socket =
      socket
      |> stream(:items, items, reset: true)
      |> assign(:filters, filters)
      |> assign(:filter_status, "")
      |> assign(:filter_availability, "")
      |> assign(:filter_condition, "")
      |> assign(:filter_node_id, "")
      |> assign(:filter_location_id, "")
      |> assign(:filtered_locations, [])
      |> assign(:active_filters_count, 0)
      |> assign(:page, page)
      |> assign(:total_pages, total_pages)
      |> assign(:items_empty?, items == [])
      |> assign(:items_count, length(items))

    {:noreply, socket}
  end

  defp get_target_field(params) do
    case params["_target"] do
      [field | _] -> String.to_atom(field)
      _ -> nil
    end
  end

  defp has_clear_value?(params) do
    # Check if any param is explicitly set to empty string (clear action)
    Enum.any?(["status", "availability", "condition", "node_id", "location_id"], fn key ->
      Map.has_key?(params, key) && params[key] == ""
    end)
  end

  defp apply_clear_filter(current_filters, params, is_admin, user_node_id) do
    # Apply clear to the specific field that was cleared
    cleared_filters =
      current_filters
      |> maybe_clear_filter(:status, params["status"])
      |> maybe_clear_filter(:availability, params["availability"])
      |> maybe_clear_filter(:condition, params["condition"])
      |> maybe_clear_filter(:node_id, params["node_id"], is_admin)
      |> maybe_clear_filter(:location_id, params["location_id"])

    # For non-admin users, force their node_id back
    cleared_filters =
      if !is_admin && user_node_id do
        Map.put(cleared_filters, :node_id, to_string(user_node_id))
      else
        cleared_filters
      end

    convert_to_filter_map(cleared_filters)
  end

  defp maybe_clear_filter(current_filters, key, value) when value == "" do
    # Clear this specific filter
    Map.put(current_filters, key, "")
  end

  defp maybe_clear_filter(current_filters, :node_id, value, is_admin)
       when value == "" and is_admin == false do
    # Non-admin users cannot clear their node_id
    current_filters
  end

  defp maybe_clear_filter(current_filters, :node_id, value, _is_admin) when value == "" do
    # Admin users can clear node_id
    Map.put(current_filters, :node_id, "")
  end

  defp convert_to_filter_map(current_filters) do
    # Convert back to a clean filter map
    %{}
    |> maybe_add_filter(:status, current_filters[:status])
    |> maybe_add_filter(:availability, current_filters[:availability])
    |> maybe_add_filter(:condition, current_filters[:condition])
    |> maybe_add_filter(:node_id, current_filters[:node_id])
    |> maybe_add_filter(:location_id, current_filters[:location_id])
  end

  defp merge_filters_smart(current_filters, new_params, target_field, is_admin, user_node_id) do
    # Filter out _unused_ fields that Phoenix sends when inputs aren't rendered
    actual_params =
      Map.reject(new_params, fn {key, _} -> String.starts_with?(key, "_unused_") end)

    # Only update the field that actually changed (plus handle dependencies)
    case target_field do
      :node_id ->
        # Node changed - update node and clear location (only if admin)
        if is_admin do
          %{}
          |> maybe_add_filter(:status, current_filters[:status])
          |> maybe_add_filter(:availability, current_filters[:availability])
          |> maybe_add_filter(:condition, current_filters[:condition])
          |> maybe_add_filter(:node_id, actual_params["node_id"])
          |> maybe_add_filter(:location_id, "")
        else
          # Non-admin: preserve their node_id, don't allow changes
          %{}
          |> maybe_add_filter(:status, current_filters[:status])
          |> maybe_add_filter(:availability, current_filters[:availability])
          |> maybe_add_filter(:condition, current_filters[:condition])
          |> maybe_add_filter(:node_id, to_string(user_node_id))
          |> maybe_add_filter(:location_id, current_filters[:location_id])
        end

      :location_id ->
        # Location changed - update location, keep everything else
        %{}
        |> maybe_add_filter(:status, current_filters[:status])
        |> maybe_add_filter(:availability, current_filters[:availability])
        |> maybe_add_filter(:condition, current_filters[:condition])
        |> maybe_add_filter(:node_id, current_filters[:node_id])
        |> maybe_add_filter(:location_id, actual_params["location_id"])

      :status ->
        # Status changed - update status, keep everything else
        %{}
        |> maybe_add_filter(:status, actual_params["status"])
        |> maybe_add_filter(:availability, current_filters[:availability])
        |> maybe_add_filter(:condition, current_filters[:condition])
        |> maybe_add_filter(:node_id, current_filters[:node_id])
        |> maybe_add_filter(:location_id, current_filters[:location_id])

      :availability ->
        # Availability changed - update availability, keep everything else
        %{}
        |> maybe_add_filter(:status, current_filters[:status])
        |> maybe_add_filter(:availability, actual_params["availability"])
        |> maybe_add_filter(:condition, current_filters[:condition])
        |> maybe_add_filter(:node_id, current_filters[:node_id])
        |> maybe_add_filter(:location_id, current_filters[:location_id])

      :condition ->
        # Condition changed - update condition, keep everything else
        %{}
        |> maybe_add_filter(:status, current_filters[:status])
        |> maybe_add_filter(:availability, current_filters[:availability])
        |> maybe_add_filter(:condition, actual_params["condition"])
        |> maybe_add_filter(:node_id, current_filters[:node_id])
        |> maybe_add_filter(:location_id, current_filters[:location_id])

      _ ->
        # Fallback - preserve current filters
        convert_to_filter_map(current_filters)
    end
  end

  defp maybe_add_filter(filters, _key, nil), do: filters
  defp maybe_add_filter(filters, _key, ""), do: filters
  defp maybe_add_filter(filters, key, value), do: Map.put(filters, key, value)

  defp count_active_filters(filters) do
    filters
    |> Map.values()
    |> Enum.reject(&(&1 == nil || &1 == ""))
    |> length()
  end
end
