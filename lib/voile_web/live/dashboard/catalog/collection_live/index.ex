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

  import Voile.Utils.ItemHelper,
    only: [generate_item_code: 5, generate_inventory_code: 4, generate_barcode_from_item_code: 1]

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
      # Limit to 100 most recent creators for dropdown (at database level for performance)
      {creator, _, _} = Master.list_mst_creator_paginated(1, 100)
      # All nodes (usually not many)
      node_location = System.list_nodes()

      time_identifier = DateTime.utc_now() |> DateTime.to_unix(:millisecond)

      # Get user's node for automatic filtering
      user_node_id = current_user.node_id

      # Count active filters (excluding auto-applied role-based filters for display)
      active_count = count_active_filters(filters)

      # Count pending collections for review badge (only for reviewers)
      pending_count =
        if can_review_collections?(current_user) do
          Catalog.count_pending_collections()
        else
          0
        end

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
        |> assign(:pending_count, pending_count)
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
        # Collection search assigns (modal)
        |> assign(:collection_search_query, "")
        |> assign(:collection_search_results, [])
        |> assign(:collection_search_performed, false)
        |> assign(:collection_search_loading, false)
        |> assign(:collection_search_timer, nil)
        # External book search assigns
        |> assign(:external_book_query, "")
        |> assign(:external_book_results, [])
        |> assign(:external_book_loading, false)
        |> assign(:external_book_performed, false)
        |> assign(:external_book, nil)

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

      # Load resource templates for selection
      resource_templates =
        Metadata.list_resource_template() |> Repo.preload([:resource_class, :owner])

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
      |> assign(:resource_templates, resource_templates)
      |> assign(:patch, ~p"/manage/catalog/collections")
    else
      socket
      |> put_flash(:error, "Access Denied: You don't have permission to edit this collection")
      |> push_navigate(to: ~p"/manage/catalog/collections")
    end
  end

  defp apply_action(socket, :search_collection, _params) do
    # Check create permission for searching/creating collections
    authorize!(socket, "collections.create")

    # Keep the current collection list visible while opening the search modal
    page = socket.assigns.page || 1
    per_page = 10
    search = socket.assigns.search || ""
    filters = socket.assigns.filters || %{}

    {collections, total_pages, _} =
      Catalog.list_collections_paginated(page, per_page, search, filters)

    socket
    |> stream(:collections, collections, reset: true)
    |> assign(:total_pages, total_pages)
    |> assign(:page_title, "Search Collection")
    |> assign(:collection_search_query, "")
    |> assign(:collection_search_results, [])
    |> assign(:collection_search_performed, false)
    |> assign(:collection_search_loading, false)
    # External book search assigns
    |> assign(:external_book_query, "")
    |> assign(:external_book_results, [])
    |> assign(:external_book_loading, false)
    |> assign(:external_book_performed, false)
    |> assign(:patch, ~p"/manage/catalog/collections")
  end

  defp apply_action(socket, :add_item_to_collection, %{"collection_id" => collection_id}) do
    # Check create permission for creating items
    authorize!(socket, "items.create")

    collection = Catalog.get_collection!(collection_id)
    current_user = socket.assigns.current_scope.user

    # Get node_id - use user's node_id or fallback to system default
    node_id =
      if is_nil(current_user.node_id) do
        # Get fallback node from system settings
        fallback_node_id = System.get_setting_value("default_node_id")

        case fallback_node_id do
          nil ->
            # No fallback configured, show error
            nil

          id when is_binary(id) ->
            # Try to parse as integer
            case Integer.parse(id) do
              {int_id, _} -> int_id
              :error -> nil
            end

          id when is_integer(id) ->
            id
        end
      else
        current_user.node_id
      end

    if is_nil(node_id) do
      socket
      |> put_flash(
        :error,
        "Cannot add item: Your user account is not assigned to any location/node and no default location is configured. Please contact an administrator."
      )
      |> push_navigate(to: ~p"/manage/catalog/collections/search")
    else
      # Get nodes and locations for the form
      nodes = System.list_nodes()
      node_options = Enum.map(nodes, fn n -> {"#{n.name} (#{n.abbr})", n.id} end)
      all_locations = Master.list_mst_locations()

      # Get unit and type data for code generation
      unit_data = System.get_node!(node_id)

      type_data =
        if collection.type_id,
          do: Metadata.get_resource_class!(collection.type_id),
          else: %{local_name: "UNK"}

      # Generate codes for the new item
      time_identifier = DateTime.utc_now() |> DateTime.to_unix(:millisecond)
      item_index = Catalog.count_items_by_collection(collection.id) + 1

      item_code =
        generate_item_code(
          unit_data.abbr,
          type_data.local_name,
          collection.id,
          time_identifier,
          to_string(item_index)
        )

      inventory_code =
        generate_inventory_code(
          unit_data.abbr,
          type_data.local_name,
          collection.id,
          to_string(item_index)
        )

      barcode = generate_barcode_from_item_code(item_code)

      # Create empty item with pre-filled data
      item = %Catalog.Item{
        collection_id: collection.id,
        unit_id: node_id,
        item_code: item_code,
        inventory_code: inventory_code,
        barcode: barcode,
        status: "active",
        condition: "good",
        availability: "in_processing"
      }

      # Maintain search-related assigns so we can return to search modal
      # and keep the collections stream populated for the main list view
      page = socket.assigns.page || 1
      per_page = 10
      search = socket.assigns.search || ""
      filters = socket.assigns.filters || %{}

      {collections, total_pages, _} =
        Catalog.list_collections_paginated(page, per_page, search, filters)

      # Check if user is super_admin to determine edit permissions
      is_super_admin = Catalog.is_user_admin?(current_user)

      socket
      |> stream(:collections, collections, reset: true)
      |> assign(:total_pages, total_pages)
      |> assign(:page_title, "Add Item to Collection")
      |> assign(:collection, collection)
      |> assign(:item, item)
      |> assign(:nodes, node_options)
      |> assign(:all_locations, all_locations)
      |> assign(:editable_identifiers, is_super_admin)
      |> assign(:lock_unit_id, !is_super_admin)
      |> assign(:current_user, current_user)
      |> assign(:patch, ~p"/manage/catalog/collections/search")
      # Maintain search modal state
      |> assign(:collection_search_query, socket.assigns[:collection_search_query] || "")
      |> assign(
        :collection_search_results,
        socket.assigns[:collection_search_results] || []
      )
      |> assign(
        :collection_search_performed,
        socket.assigns[:collection_search_performed] || false
      )
    end
  end

  defp apply_action(socket, :new, params) do
    # Check create permission for creating new collections
    authorize!(socket, "collections.create")

    # Check for external book prefill data
    external_book = extract_external_book(params)

    collection = %Collection{}

    # If we have external book data, prefill the collection
    {collection, external_collection_fields} =
      if external_book do
        # Build collection fields from external book metadata
        # ISBN property ID = 185 (from Perpustakaan Unpad schema)
        # Publisher property ID = 5 (standard Dublin Core)
        # Published Year property ID = 188 (from Perpustakaan Unpad schema)
        collection_fields =
          []
          |> maybe_add_collection_field(185, external_book.isbn)
          |> maybe_add_collection_field(5, external_book.publisher)
          |> maybe_add_collection_field(188, external_book.published_date)

        # Create collection with prefilled data from external book
        # type_id: 40 = Book resource class
        collection =
          collection
          |> Map.put(:title, external_book.title)
          |> Map.put(:description, external_book.description)
          |> Map.put(:thumbnail, external_book.thumbnail)
          |> Map.put(:type_id, 40)
          |> Repo.preload([
            :resource_class,
            :resource_template,
            :mst_creator,
            :node,
            :collection_fields,
            :items
          ])

        {collection, collection_fields}
      else
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

        {collection, []}
      end

    # Load collection_properties only when form opens
    collection_properties =
      if socket.assigns.collection_properties == [] do
        Metadata.list_metadata_properties_by_vocabulary()
      else
        socket.assigns.collection_properties
      end

    # Load resource templates for selection
    resource_templates =
      Metadata.list_resource_template() |> Repo.preload([:resource_class, :owner])

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
    |> assign(:resource_templates, resource_templates)
    |> assign(:external_book, external_book)
    |> assign(:external_collection_fields, external_collection_fields)
    |> assign(:patch, ~p"/manage/catalog/collections")
  end

  # Extract external book data from params
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
        {VoileWeb.Dashboard.Catalog.CollectionLive.FormComponent, {:saved, _collection}},
        socket
      ) do
    # Refresh tree collections when a collection is saved (limited)
    tree_collections = Catalog.list_collections_tree(50)

    # Refresh the main collections list to show current state
    page = socket.assigns.page || 1
    per_page = 10
    search = socket.assigns.search || ""
    filters = socket.assigns.filters || %{}

    {collections, total_pages, _} =
      Catalog.list_collections_paginated(page, per_page, search, filters)

    socket =
      socket
      |> stream(:collections, collections, reset: true)
      |> assign(:tree_collections, tree_collections)
      |> assign(:total_pages, total_pages)
      |> assign(:collections_count, length(collections))
      |> assign(:collections_empty?, collections == [])

    {:noreply, socket}
  end

  @impl true
  def handle_info(
        {VoileWeb.Dashboard.Catalog.ItemLive.FormComponent, {:saved, item}},
        socket
      ) do
    # After item is saved, redirect to the item show page
    {:noreply, push_navigate(socket, to: ~p"/manage/catalog/items/#{item.id}")}
  end

  @impl true
  def handle_info({:perform_search, trimmed_query}, socket) do
    # clear debounce timer reference since we are executing
    socket = assign(socket, :collection_search_timer, nil)

    # Perform searches asynchronously
    results = Catalog.search_collections_all_nodes(trimmed_query)
    external_results = Voile.ExternalBookSearch.search(trimmed_query, limit: 10)

    socket =
      socket
      |> assign(:collection_search_results, results)
      |> assign(:collection_search_performed, true)
      |> assign(:collection_search_loading, false)
      |> assign(:external_book_query, trimmed_query)
      |> assign(:external_book_results, external_results)
      |> assign(:external_book_performed, true)

    {:noreply, socket}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    # Check delete permission based on roles
    if not can_delete_collections?(socket.assigns.current_scope.user) do
      {:noreply,
       socket
       |> put_flash(:error, "Access Denied: You don't have permission to delete collections")}
    else
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
         |> put_flash(
           :error,
           "Access Denied: You don't have permission to delete this collection"
         )}
      end
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
    # Clear search but maintain filters
    page = 1
    per_page = 10
    filters = socket.assigns.filters
    search = ""

    {collections, total_pages, _} =
      Catalog.list_collections_paginated(page, per_page, search, filters)

    # Also refresh tree collections
    tree_collections = Catalog.list_collections_tree(50)

    # Build current query params for navigation links
    current_query_params = build_query_params(filters, search)

    # Count active filters
    active_count = count_active_filters(filters)

    socket =
      socket
      |> stream(:collections, collections, reset: true)
      |> assign(:tree_collections, tree_collections)
      |> assign(:collections_empty?, collections == [])
      |> assign(:collections_count, length(collections))
      |> assign(:total_pages, total_pages)
      |> assign(:page, page)
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

    {:noreply, socket}
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
    # Clear user-selected filters but maintain role-based filters, and clear search
    filters = %{}

    # Re-apply role-based filters
    current_user = socket.assigns.current_user
    filters = Catalog.apply_role_based_filters(current_user, filters)

    # Clear search
    search = ""

    # Build query params with cleared filters and search
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

  @impl true
  def handle_event("search_collections", %{"query" => query}, socket) do
    # cancel any pending debounce timer
    if timer = socket.assigns[:collection_search_timer] do
      Process.cancel_timer(timer)
    end

    # Trim and check if query is empty
    trimmed_query = String.trim(query)

    if trimmed_query == "" do
      # If empty, clear results
      socket =
        socket
        |> assign(:collection_search_query, "")
        |> assign(:collection_search_results, [])
        |> assign(:collection_search_performed, false)
        |> assign(:collection_search_loading, false)
        |> assign(:external_book_query, "")
        |> assign(:external_book_results, [])
        |> assign(:external_book_performed, false)
        |> assign(:collection_search_timer, nil)

      {:noreply, socket}
    else
      # Set loading state immediately, clear previous results
      socket =
        socket
        |> assign(:collection_search_query, trimmed_query)
        |> assign(:collection_search_loading, true)
        |> assign(:collection_search_performed, false)
        |> assign(:collection_search_results, [])
        |> assign(:external_book_performed, false)
        |> assign(:external_book_results, [])
        |> assign(:external_book_error, false)

      # perform search immediately on explicit submit
      send(self(), {:perform_search, trimmed_query})

      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("live_search_collections", %{"query" => query}, socket) do
    # Live search as user types (with server-side debounce)
    trimmed_query = String.trim(query)

    # cancel existing timer if any
    if timer = socket.assigns[:collection_search_timer] do
      Process.cancel_timer(timer)
    end

    if trimmed_query == "" do
      socket =
        socket
        |> assign(:collection_search_query, "")
        |> assign(:collection_search_results, [])
        |> assign(:collection_search_performed, false)
        |> assign(:collection_search_loading, false)
        |> assign(:external_book_query, "")
        |> assign(:external_book_results, [])
        |> assign(:external_book_performed, false)
        |> assign(:collection_search_timer, nil)

      {:noreply, socket}
    else
      # Set loading state immediately, clear previous results
      socket =
        socket
        |> assign(:collection_search_query, trimmed_query)
        |> assign(:collection_search_loading, true)
        |> assign(:collection_search_performed, false)
        |> assign(:collection_search_results, [])
        |> assign(:external_book_performed, false)
        |> assign(:external_book_results, [])

      # schedule real search only after user has been idle for 2s
      timer = Process.send_after(self(), {:perform_search, trimmed_query}, 2_000)
      {:noreply, assign(socket, :collection_search_timer, timer)}
    end
  end

  @impl true
  def handle_event("clear_collection_search", _params, socket) do
    # cancel any pending search timer
    if timer = socket.assigns[:collection_search_timer] do
      Process.cancel_timer(timer)
    end

    socket =
      socket
      |> assign(:collection_search_query, "")
      |> assign(:collection_search_results, [])
      |> assign(:collection_search_performed, false)
      |> assign(:collection_search_loading, false)
      |> assign(:external_book_query, "")
      |> assign(:external_book_results, [])
      |> assign(:external_book_performed, false)
      |> assign(:collection_search_timer, nil)

    {:noreply, socket}
  end

  @impl true
  def handle_event("search_external_books", %{"query" => query}, socket) do
    trimmed_query = String.trim(query)

    if trimmed_query == "" do
      socket =
        socket
        |> assign(:external_book_query, "")
        |> assign(:external_book_results, [])
        |> assign(:external_book_loading, false)
        |> assign(:external_book_performed, false)

      {:noreply, socket}
    else
      # Search external books
      results = Voile.ExternalBookSearch.search(trimmed_query, limit: 15)

      socket =
        socket
        |> assign(:external_book_query, trimmed_query)
        |> assign(:external_book_results, results)
        |> assign(:external_book_loading, false)
        |> assign(:external_book_performed, true)

      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("select_external_book", %{"book" => book_json}, socket) do
    # Parse the book data from JSON string
    case Jason.decode(book_json) do
      {:ok, book} ->
        # Navigate to new collection with prefill data
        # Encode book data as base64 to pass as param
        encoded_book = Base.encode64(Jason.encode!(book))

        {:noreply,
         push_navigate(socket,
           to: ~p"/manage/catalog/collections/new?external_book=#{encoded_book}"
         )}

      {:error, _} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to process selected book")}
    end
  end

  @impl true
  def handle_event("clear_external_book_search", _params, socket) do
    socket =
      socket
      |> assign(:external_book_query, "")
      |> assign(:external_book_results, [])
      |> assign(:external_book_performed, false)

    {:noreply, socket}
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

  # Helper function to check if user can review collections
  defp can_review_collections?(user) do
    user = Repo.preload(user, :roles)

    Enum.any?(user.roles, fn role ->
      role.name in ["super_admin", "admin"]
    end)
  end

  # Helper function to check if user can delete collections
  defp can_delete_collections?(user) do
    user = Repo.preload(user, :roles)

    Enum.any?(user.roles, fn role ->
      role.name in ["super_admin", "admin", "editor"]
    end)
  end

  # Helper function to build collection fields from external book metadata
  # Only adds field if value is present
  defp maybe_add_collection_field(fields, _property_id, nil), do: fields
  defp maybe_add_collection_field(fields, _property_id, ""), do: fields

  defp maybe_add_collection_field(fields, property_id, value) do
    # Get property info for name and label
    {name, label} = get_property_info(property_id)

    field = %{
      id: Ecto.UUID.generate(),
      metadata_property_id: property_id,
      property_id: property_id,
      name: name,
      label: label,
      value: to_string(value),
      information: nil,
      type_value: "text",
      value_lang: "en",
      sort_order: length(fields)
    }

    fields ++ [field]
  end

  # Property ID mappings for external book metadata fields
  # These should match the metadata properties in your database
  defp get_property_info(185), do: {"isbn", "ISBN"}
  defp get_property_info(5), do: {"publisher", "Publisher"}
  defp get_property_info(188), do: {"published_date", "Published Date"}
  # defp get_property_info(_), do: {"field", "Field"}

  defp extract_external_book(%{"external_book" => encoded_book}) when is_binary(encoded_book) do
    case Base.decode64(encoded_book) do
      {:ok, json} ->
        case Jason.decode(json) do
          {:ok, book} ->
            %Voile.ExternalBookSearch.Book{
              source: Map.get(book, "source", "unknown"),
              external_id: Map.get(book, "external_id"),
              open_library_id: Map.get(book, "open_library_id"),
              title: Map.get(book, "title"),
              authors: Map.get(book, "authors", []),
              publisher: Map.get(book, "publisher"),
              published_date: Map.get(book, "published_date"),
              description: Map.get(book, "description"),
              thumbnail: Map.get(book, "thumbnail"),
              isbn: Map.get(book, "isbn"),
              page_count: Map.get(book, "page_count")
            }

          _ ->
            nil
        end

      _ ->
        nil
    end
  end

  defp extract_external_book(_), do: nil
end
