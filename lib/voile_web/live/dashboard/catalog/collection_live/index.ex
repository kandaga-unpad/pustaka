defmodule VoileWeb.Dashboard.Catalog.CollectionLive.Index do
  use VoileWeb, :live_view_dashboard

  alias Voile.Repo
  alias Voile.Schema.Catalog
  alias Voile.Schema.Catalog.Collection
  alias Voile.Schema.Master
  alias Voile.Schema.Metadata
  alias Voile.Schema.System
  alias VoileWeb.Auth.Authorization

  import VoileWeb.Dashboard.Catalog.CollectionLive.TreeComponents
  import VoileWeb.Utils.StringHelper, only: [trim_text: 2]

  @impl true
  def mount(_params, _session, socket) do
    # Check read permission for viewing collections
    unless Authorization.can?(socket, "collections.read") do
      socket =
        socket
        |> put_flash(:error, "You don't have permission to access collections")
        |> push_navigate(to: ~p"/manage")

      {:ok, socket}
    else
      page = 1

      # Get current user
      current_user = socket.assigns.current_scope.user

      # Initialize empty filters, then apply role-based filters
      # Note: URL params will be applied in handle_params/apply_action
      filters = %{}
      filters = Catalog.apply_role_based_filters(current_user, filters)

      # Don't load collections here - let handle_params/apply_action do it
      # This prevents loading collections without URL params, then reloading with URL params
      # which causes duplicate items in the stream

      # Limit tree collections to prevent performance issues
      tree_collections = Catalog.list_collections_tree(50)

      # Get dropdown options (limit for performance)
      collection_type = Metadata.list_resource_class()
      # Limit to 100 most recent creators for dropdown
      creator = Master.list_mst_creator() |> Enum.take(100)
      # All nodes (usually not many)
      node_location = System.list_nodes()

      time_identifier = DateTime.utc_now() |> DateTime.to_unix(:millisecond)

      # Get user's node for automatic filtering
      user_node_id = current_user.node_id

      # Count active filters (excluding auto-applied role-based filters for display)
      active_count = count_active_filters(filters)

      socket =
        socket
        # Initialize empty stream to prevent errors when modal opens
        |> stream(:collections, [])
        # Don't stream collections here - will be done in apply_action
        |> assign(:tree_collections, tree_collections)
        # "list" or "tree"
        |> assign(:view_mode, "list")
        # track whether creator search UI is active (used by form_component)
        |> assign(:creator_searching, false)
        |> assign(:collection_type, collection_type)
        # Don't load collection_properties on mount - load only when form opens
        |> assign(:collection_properties, [])
        |> assign(:creator, creator)
        |> assign(:node_location, node_location)
        |> assign(:page, page)
        |> assign(:total_pages, 0)
        |> assign(:search, "")
        |> assign(:collections_count, 0)
        |> assign(:collections_empty?, true)
        |> assign(:step, 1)
        |> assign(:show_add_collection_field, true)
        |> assign(:time_identifier, time_identifier)
        # Filter-related assigns (set from applied role-based filters)
        |> assign(:filters, filters)
        |> assign(:user_node_id, user_node_id)
        |> assign(:filter_status, filters[:status] || "")
        |> assign(:filter_access_level, filters[:access_level] || "")
        |> assign(:filter_glam_type, filters[:glam_type] || "")
        |> assign(
          :filter_node_id,
          if(filters[:node_id], do: to_string(filters[:node_id]), else: "")
        )
        |> assign(:active_filters_count, active_count)
        |> assign(:is_staff, !Catalog.is_user_admin?(current_user))
        |> assign(:current_user, current_user)
        # Track current query params for navigation
        |> assign(:current_query_params, %{})

      {:ok, socket}
    end
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    # Check update permission for editing collections
    authorize!(socket, "collections.update")

    collection = Catalog.get_collection!(id)
    current_user = socket.assigns.current_user

    # Verify user has access to this collection's unit
    if Catalog.is_user_admin?(current_user) or collection.unit_id == current_user.node_id do
      # Load collection_properties only when form opens
      collection_properties =
        if socket.assigns.collection_properties == [] do
          Metadata.list_metadata_properties_by_vocabulary()
        else
          socket.assigns.collection_properties
        end

      # Ensure the current list view remains populated when opening the modal
      page = socket.assigns.page || 1
      per_page = 10
      search = socket.assigns.search || ""
      filters = socket.assigns.filters || %{}

      {collections, total_pages, _} =
        Catalog.list_collections_paginated(page, per_page, search, filters)

      socket
      |> stream(:collections, collections, reset: true)
      |> assign(:total_pages, total_pages)
      |> assign(:page_title, "Edit Collection")
      |> assign(:collection, collection)
      |> assign(:collection_properties, collection_properties)
      |> assign(:patch, ~p"/manage/catalog/collections")
    else
      socket
      |> put_flash(:error, "Access Denied: You don't have permission to edit this collection")
      |> push_navigate(to: ~p"/manage/catalog/collections")
    end
  end

  defp apply_action(socket, :new, _params) do
    # Check create permission for creating new collections
    authorize!(socket, "collections.create")

    collection = %Collection{}

    collection =
      collection
      |> Repo.preload([
        :resource_class,
        :resource_template,
        :mst_creator,
        :node,
        :collection_fields,
        :items
      ])

    # Load collection_properties only when form opens
    collection_properties =
      if socket.assigns.collection_properties == [] do
        Metadata.list_metadata_properties_by_vocabulary()
      else
        socket.assigns.collection_properties
      end

    # Keep the current collection list visible while opening the new collection modal
    page = socket.assigns.page || 1
    per_page = 10
    search = socket.assigns.search || ""
    filters = socket.assigns.filters || %{}

    {collections, total_pages, _} =
      Catalog.list_collections_paginated(page, per_page, search, filters)

    socket
    |> stream(:collections, collections, reset: true)
    |> assign(:total_pages, total_pages)
    |> assign(:page_title, "New Collection")
    |> assign(:collection, collection)
    |> assign(:collection_properties, collection_properties)
    |> assign(:patch, ~p"/manage/catalog/collections")
  end

  defp apply_action(socket, :index, params) do
    # When returning to index (e.g., after closing modal), always refresh collections
    # to ensure the stream is properly maintained
    page = socket.assigns.page
    per_page = 10
    # Get search from URL params if present, otherwise use current search
    search = params["q"] || socket.assigns.search
    current_user = socket.assigns.current_user

    # Build filters from URL params
    filters = build_filters_from_params(params)

    # Re-apply role-based filters to ensure they're not overridden
    filters = Catalog.apply_role_based_filters(current_user, filters)

    # Count active filters
    active_count = count_active_filters(filters)

    {collections, total_pages, _} =
      Catalog.list_collections_paginated(page, per_page, search, filters)

    # Also refresh tree collections
    tree_collections = Catalog.list_collections_tree(50)

    # Build current query params for navigation links
    current_query_params = build_query_params(filters, search)

    socket
    |> stream(:collections, collections, reset: true)
    |> assign(:tree_collections, tree_collections)
    |> assign(:collections_empty?, collections == [])
    |> assign(:collections_count, length(collections))
    |> assign(:total_pages, total_pages)
    |> assign(:page_title, "Listing Collections")
    |> assign(:collection, nil)
    |> assign(:search, search)
    |> assign(:filters, filters)
    |> assign(:filter_status, filters[:status] || "")
    |> assign(:filter_access_level, filters[:access_level] || "")
    |> assign(:filter_glam_type, filters[:glam_type] || "")
    |> assign(
      :filter_node_id,
      if(filters[:node_id], do: to_string(filters[:node_id]), else: "")
    )
    |> assign(:active_filters_count, active_count)
    |> assign(:current_query_params, current_query_params)
  end

  @impl true
  def handle_info(
        {VoileWeb.Dashboard.Catalog.CollectionLive.FormComponent, {:saved, collection}},
        socket
      ) do
    # Refresh tree collections when a new collection is saved (limited)
    tree_collections = Catalog.list_collections_tree(50)

    socket =
      socket
      |> stream_insert(:collections, collection, at: 0)
      |> assign(:tree_collections, tree_collections)

    # update count
    socket = assign(socket, :collections_count, (socket.assigns[:collections_count] || 0) + 1)

    {:noreply, socket}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    # Check delete permission before deleting
    authorize!(socket, "collections.delete")

    collection = Catalog.get_collection!(id)
    current_user = socket.assigns.current_user

    # Verify user has access to this collection's unit
    if Catalog.is_user_admin?(current_user) or collection.unit_id == current_user.node_id do
      {:ok, _} = Catalog.delete_collection(collection)

      # Refresh both views with limited tree collections
      tree_collections = Catalog.list_collections_tree(50)

      # If a search or filters are active, re-fetch current page with the filters, otherwise just delete from stream
      search = socket.assigns[:search] || ""
      filters = socket.assigns.filters
      has_active_filters = search != "" || map_size(filters) > 0

      socket =
        socket
        |> assign(:tree_collections, tree_collections)

      if has_active_filters do
        page = socket.assigns[:page] || 1
        per_page = 10

        {collections, total_pages, _} =
          Catalog.list_collections_paginated(page, per_page, search, filters)

        socket =
          socket
          |> stream(:collections, collections, reset: true)
          |> assign(:page, page)
          |> assign(:total_pages, total_pages)
          |> assign(:collections_empty?, collections == [])
          |> assign(:collections_count, length(collections))

        {:noreply, socket}
      else
        socket =
          socket
          |> stream_delete(:collections, collection)
          |> assign(:collections_count, max((socket.assigns[:collections_count] || 1) - 1, 0))

        {:noreply, socket}
      end
    else
      {:noreply,
       socket
       |> put_flash(:error, "Access Denied: You don't have permission to delete this collection")}
    end
  end

  @impl true
  def handle_event("toggle_view_mode", _params, socket) do
    new_mode = if socket.assigns.view_mode == "list", do: "tree", else: "list"

    socket =
      if new_mode == "tree" do
        # When switching to tree mode, reload limited tree collections
        tree_collections = Catalog.list_collections_tree(50)
        assign(socket, :tree_collections, tree_collections)
      else
        # When switching back to list mode, reload collections with current filters and search
        page = socket.assigns.page
        per_page = 10
        search = socket.assigns.search
        filters = socket.assigns.filters

        {collections, total_pages, _} =
          Catalog.list_collections_paginated(page, per_page, search, filters)

        socket
        |> stream(:collections, collections, reset: true)
        |> assign(:collections_empty?, collections == [])
        |> assign(:collections_count, length(collections))
        |> assign(:total_pages, total_pages)
      end

    {:noreply, assign(socket, :view_mode, new_mode)}
  end

  @impl true
  def handle_event("paginate", %{"page" => page}, socket) do
    page = String.to_integer(page)
    per_page = 10

    search = socket.assigns[:search] || ""
    filters = socket.assigns.filters

    {collections, total_pages, _} =
      Catalog.list_collections_paginated(page, per_page, search, filters)

    socket =
      socket
      |> stream(:collections, collections, reset: true)
      |> assign(:page, page)
      |> assign(:total_pages, total_pages)
      |> assign(:collections_empty?, collections == [])
      |> assign(:collections_count, length(collections))

    {:noreply, socket}
  end

  @impl true
  def handle_event("search", %{"q" => q}, socket) do
    # Build query params with search query
    query_params = build_query_params(socket.assigns.filters, q)

    # Push patch to update URL with search query
    {:noreply, push_patch(socket, to: ~p"/manage/catalog/collections?#{query_params}")}
  end

  @impl true
  def handle_event("clear_search", _params, socket) do
    # Build query params without search query
    query_params = build_query_params(socket.assigns.filters, "")

    # Push patch to update URL without search query
    {:noreply, push_patch(socket, to: ~p"/manage/catalog/collections?#{query_params}")}
  end

  @impl true
  def handle_event("filter_change", params, socket) do
    # Build filters map from params
    filters = build_filters_from_params(params)

    # Apply role-based filters on top of user-selected filters
    current_user = socket.assigns.current_user
    filters = Catalog.apply_role_based_filters(current_user, filters)

    # Keep current search query
    search = socket.assigns.search

    # Build query params with both filters and search
    query_params = build_query_params(filters, search)

    # Push patch to update URL with new filters
    {:noreply, push_patch(socket, to: ~p"/manage/catalog/collections?#{query_params}")}
  end

  @impl true
  def handle_event("clear_filters", _params, socket) do
    # Clear user-selected filters but maintain role-based filters and search
    filters = %{}

    # Re-apply role-based filters
    current_user = socket.assigns.current_user
    filters = Catalog.apply_role_based_filters(current_user, filters)

    # Keep current search query
    search = socket.assigns.search

    # Build query params with cleared filters but keep search
    query_params = build_query_params(filters, search)

    # Push patch to update URL
    {:noreply, push_patch(socket, to: ~p"/manage/catalog/collections?#{query_params}")}
  end

  @impl true
  def handle_event("filter_by_my_node", _params, socket) do
    user_node_id = socket.assigns.user_node_id

    if user_node_id do
      filters = Map.put(socket.assigns.filters, :node_id, user_node_id)
      search = socket.assigns.search

      # Build query params with node filter
      query_params = build_query_params(filters, search)

      {:noreply, push_patch(socket, to: ~p"/manage/catalog/collections?#{query_params}")}
    else
      {:noreply, socket}
    end
  end

  # Helper functions
  defp build_filters_from_params(params) do
    %{}
    |> maybe_add_filter(:status, params["status"])
    |> maybe_add_filter(:access_level, params["access_level"])
    |> maybe_add_filter(:glam_type, params["glam_type"])
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

  defp build_query_params(filters, search) do
    params = %{}

    # Add search query if present
    params =
      if search && search != "" do
        Map.put(params, :q, search)
      else
        params
      end

    # Add filters
    params =
      if filters[:status] && filters[:status] != "" do
        Map.put(params, :status, filters[:status])
      else
        params
      end

    params =
      if filters[:access_level] && filters[:access_level] != "" do
        Map.put(params, :access_level, filters[:access_level])
      else
        params
      end

    params =
      if filters[:glam_type] && filters[:glam_type] != "" do
        Map.put(params, :glam_type, filters[:glam_type])
      else
        params
      end

    params =
      if filters[:node_id] && filters[:node_id] != "" do
        Map.put(params, :node_id, filters[:node_id])
      else
        params
      end

    params
  end
end
