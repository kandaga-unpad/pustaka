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

    # Load nodes and master locations once in the LiveView so the component
    # does not need to make DB calls. We'll pass these assigns into the
    # form component when rendering the modal.
    nodes = Voile.Schema.System.list_nodes()
    node_options = Enum.map(nodes, fn n -> {"#{n.name} (#{n.abbr})", n.id} end)
    all_locations = Voile.Schema.Master.list_mst_locations()

    # Load filter options from Item schema
    status_options = Item.status_options()
    condition_options = Item.condition_options()
    availability_options = Item.availability_options()

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
      |> assign(:nodes, node_options)
      |> assign(:all_locations, all_locations)
      |> assign(:status_options, status_options)
      |> assign(:condition_options, condition_options)
      |> assign(:availability_options, availability_options)
      |> assign(:filter_status, "")
      |> assign(:filter_availability, "")
      |> assign(:filter_condition, "")
      |> assign(:filter_node_id, "")
      |> assign(:active_filters_count, 0)

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

    socket
    |> stream(:items, items, reset: true)
    |> assign(:page_title, gettext("Listing Items"))
    |> assign(:item, nil)
    |> assign(:page, page)
    |> assign(:total_pages, total_pages)
    |> assign(:items_empty?, items == [])
    |> assign(:items_count, length(items))
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
    # Clear search but maintain filters
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
  def handle_event("filter_change", params, socket) do
    filters = build_filters_from_params(params)

    current_user = socket.assigns.current_user
    filters = Catalog.apply_role_based_filters(current_user, filters)

    active_count = count_active_filters(filters)

    search = socket.assigns.search
    page = 1
    per_page = 10

    {items, total_pages, _} = Catalog.list_items_paginated(page, per_page, search, filters)

    socket =
      socket
      |> stream(:items, items, reset: true)
      |> assign(:filters, filters)
      |> assign(:filter_status, filters[:status] || "")
      |> assign(:filter_availability, filters[:availability] || "")
      |> assign(:filter_condition, filters[:condition] || "")
      |> assign(:filter_node_id, filters[:node_id] || "")
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
      |> assign(:active_filters_count, 0)
      |> assign(:page, page)
      |> assign(:total_pages, total_pages)
      |> assign(:items_empty?, items == [])
      |> assign(:items_count, length(items))

    {:noreply, socket}
  end

  defp build_filters_from_params(params) do
    %{}
    |> maybe_add_filter(:status, params["status"])
    |> maybe_add_filter(:availability, params["availability"])
    |> maybe_add_filter(:condition, params["condition"])
    |> maybe_add_filter(:node_id, params["node_id"])
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
