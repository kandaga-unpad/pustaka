defmodule VoileWeb.Dashboard.Catalog.CollectionLive.Submitted do
  use VoileWeb, :live_view_dashboard

  alias Voile.Schema.Catalog

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_scope.user

    # Initialize page state
    page = 1
    per_page = 10
    search = ""

    {collections, total_pages, total_count} =
      Catalog.list_submitted_collections_paginated(current_user, page, per_page, search)

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

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, params) do
    page = String.to_integer(params["page"] || "1")
    search = params["search"] || ""

    current_user = socket.assigns.current_scope.user
    per_page = socket.assigns.per_page

    {collections, total_pages, total_count} =
      Catalog.list_submitted_collections_paginated(current_user, page, per_page, search)

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
  end

  @impl true
  def handle_event("paginate", %{"page" => page}, socket) do
    page = String.to_integer(page)
    current_user = socket.assigns.current_scope.user
    per_page = socket.assigns.per_page
    search = socket.assigns.search

    {collections, total_pages, total_count} =
      Catalog.list_submitted_collections_paginated(current_user, page, per_page, search)

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

    {collections, total_pages, total_count} =
      Catalog.list_submitted_collections_paginated(current_user, 1, per_page, search)

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

  # Helper function for status badge styling
  defp status_badge_class("pending"), do: "bg-yellow-100 text-yellow-800"
  defp status_badge_class("draft"), do: "bg-gray-100 text-gray-800"
  defp status_badge_class("published"), do: "bg-green-100 text-green-800"
  defp status_badge_class("archived"), do: "bg-red-100 text-red-800"
  defp status_badge_class("rejected"), do: "bg-red-100 text-red-800"
  defp status_badge_class(_), do: "bg-gray-100 text-gray-800"
end
