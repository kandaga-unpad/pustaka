defmodule VoileWeb.Dashboard.Catalog.CollectionLive.Submitted do
  use VoileWeb, :live_view_dashboard

  alias Voile.Repo
  alias Voile.Schema.Catalog
  alias Voile.Schema.Metadata
  alias Voile.Schema.Master
  alias Voile.Schema.System

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_scope.user

    # Initialize page state
    page = 1
    per_page = 10
    search = ""
    status_filter = "all"

    {collections, total_pages, total_count} =
      Catalog.list_submitted_collections_paginated(
        current_user,
        page,
        per_page,
        search,
        status_filter
      )

    # Get status counts for filter tabs
    status_counts = Catalog.get_submitted_collections_status_counts(current_user)

    # Load additional data for form component
    creator = Master.list_mst_creator()
    collection_type = Metadata.list_resource_class()
    node_location = System.list_nodes()
    time_identifier = NaiveDateTime.utc_now()

    # Add review notes to each collection
    collections_with_notes =
      Enum.map(collections, fn collection ->
        review_notes = Catalog.get_collection_review_notes(collection.id)
        Map.put(collection, :review_notes, review_notes)
      end)

    # Create a map of collection_id => review_notes for template access
    review_notes_map =
      Map.new(collections, fn collection ->
        {collection.id, Catalog.get_collection_review_notes(collection.id)}
      end)

    socket =
      socket
      |> stream(:collections, collections_with_notes)
      |> assign(:review_notes_map, review_notes_map)
      |> assign(:page, page)
      |> assign(:total_pages, total_pages)
      |> assign(:total_count, total_count)
      |> assign(:collections_empty?, collections == [])
      |> assign(:search, search)
      |> assign(:per_page, per_page)
      |> assign(:status_filter, status_filter)
      |> assign(:status_counts, status_counts)
      |> assign(:collection, nil)
      |> assign(:collection_properties, [])
      |> assign(:resource_templates, [])
      |> assign(:patch, ~p"/manage/catalog/collections/submitted")
      |> assign(:creator, creator)
      |> assign(:collection_type, collection_type)
      |> assign(:node_location, node_location)
      |> assign(:step, 1)
      |> assign(:show_add_collection_field, true)
      |> assign(:time_identifier, time_identifier)
      |> assign(:creator_searching, false)

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, params) do
    page = String.to_integer(params["page"] || "1")
    search = params["search"] || ""
    status_filter = params["status"] || "all"

    current_user = socket.assigns.current_scope.user
    per_page = socket.assigns.per_page

    {collections, total_pages, total_count} =
      Catalog.list_submitted_collections_paginated(
        current_user,
        page,
        per_page,
        search,
        status_filter
      )

    # Get status counts for filter tabs
    status_counts = Catalog.get_submitted_collections_status_counts(current_user)

    # Add review notes to each collection
    collections_with_notes =
      Enum.map(collections, fn collection ->
        review_notes = Catalog.get_collection_review_notes(collection.id)
        Map.put(collection, :review_notes, review_notes)
      end)

    # Create a map of collection_id => review_notes for template access
    review_notes_map =
      Map.new(collections, fn collection ->
        {collection.id, Catalog.get_collection_review_notes(collection.id)}
      end)

    socket
    |> assign(:page_title, "My Submitted Collections")
    |> stream(:collections, collections_with_notes, reset: true)
    |> assign(:review_notes_map, review_notes_map)
    |> assign(:page, page)
    |> assign(:total_pages, total_pages)
    |> assign(:total_count, total_count)
    |> assign(:collections_empty?, collections == [])
    |> assign(:search, search)
    |> assign(:status_filter, status_filter)
    |> assign(:status_counts, status_counts)
    |> assign(:collection, nil)
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    collection = Catalog.get_collection!(id)
    current_user = socket.assigns.current_scope.user

    # Only allow editing collections in draft status that belong to the user
    if collection.status == "draft" and collection.created_by_id == current_user.id do
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

      socket
      |> assign(:page_title, "Edit Collection")
      |> assign(:collection, collection)
      |> assign(:collection_properties, collection_properties)
      |> assign(:resource_templates, resource_templates)
      |> assign(:patch, ~p"/manage/catalog/collections/submitted")
    else
      socket
      |> put_flash(:error, "You can only edit collections in draft status")
      |> push_navigate(to: ~p"/manage/catalog/collections/submitted")
    end
  end

  @impl true
  def handle_event("paginate", %{"page" => page}, socket) do
    page = String.to_integer(page)
    current_user = socket.assigns.current_scope.user
    per_page = socket.assigns.per_page
    search = socket.assigns.search
    status_filter = socket.assigns.status_filter

    {collections, total_pages, total_count} =
      Catalog.list_submitted_collections_paginated(
        current_user,
        page,
        per_page,
        search,
        status_filter
      )

    # Add review notes to each collection
    collections_with_notes =
      Enum.map(collections, fn collection ->
        review_notes = Catalog.get_collection_review_notes(collection.id)
        Map.put(collection, :review_notes, review_notes)
      end)

    # Create a map of collection_id => review_notes for template access
    review_notes_map =
      Map.new(collections, fn collection ->
        {collection.id, Catalog.get_collection_review_notes(collection.id)}
      end)

    socket =
      socket
      |> stream(:collections, collections_with_notes, reset: true)
      |> assign(:review_notes_map, review_notes_map)
      |> assign(:page, page)
      |> assign(:total_pages, total_pages)
      |> assign(:total_count, total_count)
      |> assign(:collections_empty?, collections == [])

    {:noreply, socket}
  end

  @impl true
  def handle_event("search", %{"search" => search}, socket) do
    current_user = socket.assigns.current_scope.user
    per_page = socket.assigns.per_page
    status_filter = socket.assigns.status_filter

    {collections, total_pages, total_count} =
      Catalog.list_submitted_collections_paginated(
        current_user,
        1,
        per_page,
        search,
        status_filter
      )

    # Add review notes to each collection
    collections_with_notes =
      Enum.map(collections, fn collection ->
        review_notes = Catalog.get_collection_review_notes(collection.id)
        Map.put(collection, :review_notes, review_notes)
      end)

    # Create a map of collection_id => review_notes for template access
    review_notes_map =
      Map.new(collections, fn collection ->
        {collection.id, Catalog.get_collection_review_notes(collection.id)}
      end)

    socket =
      socket
      |> stream(:collections, collections_with_notes, reset: true)
      |> assign(:review_notes_map, review_notes_map)
      |> assign(:page, 1)
      |> assign(:total_pages, total_pages)
      |> assign(:total_count, total_count)
      |> assign(:collections_empty?, collections == [])
      |> assign(:search, search)

    {:noreply, socket}
  end

  @impl true
  def handle_event("filter_status", %{"status" => status}, socket) do
    current_user = socket.assigns.current_scope.user
    per_page = socket.assigns.per_page
    search = socket.assigns.search

    {collections, total_pages, total_count} =
      Catalog.list_submitted_collections_paginated(current_user, 1, per_page, search, status)

    # Get status counts for filter tabs
    status_counts = Catalog.get_submitted_collections_status_counts(current_user)

    # Add review notes to each collection
    collections_with_notes =
      Enum.map(collections, fn collection ->
        review_notes = Catalog.get_collection_review_notes(collection.id)
        Map.put(collection, :review_notes, review_notes)
      end)

    # Create a map of collection_id => review_notes for template access
    review_notes_map =
      Map.new(collections, fn collection ->
        {collection.id, Catalog.get_collection_review_notes(collection.id)}
      end)

    socket =
      socket
      |> stream(:collections, collections_with_notes, reset: true)
      |> assign(:review_notes_map, review_notes_map)
      |> assign(:page, 1)
      |> assign(:total_pages, total_pages)
      |> assign(:total_count, total_count)
      |> assign(:collections_empty?, collections == [])
      |> assign(:status_filter, status)
      |> assign(:status_counts, status_counts)

    {:noreply, socket}
  end

  @impl true
  def handle_event("save_collection", _params, socket) do
    # Delegate to form component or handle save here
    {:noreply, socket}
  end

  @impl true
  def handle_info({:collection_updated, _collection}, socket) do
    # Refresh the list after successful update
    current_user = socket.assigns.current_scope.user
    per_page = socket.assigns.per_page
    search = socket.assigns.search
    status_filter = socket.assigns.status_filter
    page = socket.assigns.page

    {collections, total_pages, total_count} =
      Catalog.list_submitted_collections_paginated(
        current_user,
        page,
        per_page,
        search,
        status_filter
      )

    # Get status counts for filter tabs
    status_counts = Catalog.get_submitted_collections_status_counts(current_user)

    # Add review notes to each collection
    collections_with_notes =
      Enum.map(collections, fn collection ->
        review_notes = Catalog.get_collection_review_notes(collection.id)
        Map.put(collection, :review_notes, review_notes)
      end)

    # Create a map of collection_id => review_notes for template access
    review_notes_map =
      Map.new(collections, fn collection ->
        {collection.id, Catalog.get_collection_review_notes(collection.id)}
      end)

    socket =
      socket
      |> put_flash(:info, "Collection updated successfully")
      |> stream(:collections, collections_with_notes, reset: true)
      |> assign(:review_notes_map, review_notes_map)
      |> assign(:total_pages, total_pages)
      |> assign(:total_count, total_count)
      |> assign(:collections_empty?, collections == [])
      |> assign(:status_counts, status_counts)
      |> push_patch(to: ~p"/manage/catalog/collections/submitted")

    {:noreply, socket}
  end

  # Helper function for status badge styling
  defp status_badge_class("pending"), do: "bg-yellow-100 text-yellow-800"
  defp status_badge_class("draft"), do: "bg-gray-100 text-gray-800"
  defp status_badge_class("published"), do: "bg-green-100 text-green-800"
  defp status_badge_class("archived"), do: "bg-red-100 text-red-800"
  defp status_badge_class("rejected"), do: "bg-red-100 text-red-800"
  defp status_badge_class(_), do: "bg-gray-100 text-gray-800"
end
