defmodule VoileWeb.Dashboard.Catalog.CollectionLive.Index do
  use VoileWeb, :live_view_dashboard

  alias Voile.Repo
  alias Voile.Schema.Catalog
  alias Voile.Schema.Catalog.Collection
  alias Voile.Schema.Master
  alias Voile.Schema.Metadata
  alias Voile.Schema.System

  import VoileWeb.Dashboard.Catalog.CollectionLive.TreeComponents
  import VoileWeb.Utils.StringHelper, only: [trim_text: 2]

  @impl true
  def mount(_params, _session, socket) do
    page = 1
    per_page = 10
    {collections, total_pages} = Catalog.list_collections_paginated(page, per_page)
    # Limit tree collections to prevent performance issues
    tree_collections = Catalog.list_collections_tree(50)
    collection_type = Metadata.list_resource_class()
    collection_properties = Metadata.list_metadata_properties_by_vocabulary()
    creator = Master.list_mst_creator()
    node_location = System.list_nodes()

    time_identifier = DateTime.utc_now() |> DateTime.to_unix(:millisecond)

    socket =
      socket
      |> stream(:collections, collections)
      |> assign(:tree_collections, tree_collections)
      # "list" or "tree"
      |> assign(:view_mode, "list")
      # track whether creator search UI is active (used by form_component)
      |> assign(:creator_searching, false)
      |> assign(:collection_type, collection_type)
      |> assign(:collection_properties, collection_properties)
      |> assign(:creator, creator)
      |> assign(:node_location, node_location)
      |> assign(:page, page)
      |> assign(:total_pages, total_pages)
      |> assign(:search, "")
      |> assign(:collections_count, length(collections))
      |> assign(:collections_empty?, collections == [])
      |> assign(:step, 1)
      |> assign(:show_add_collection_field, true)
      |> assign(:time_identifier, time_identifier)

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit Collection")
    |> assign(:collection, Catalog.get_collection!(id))
  end

  defp apply_action(socket, :new, _params) do
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

    socket
    |> assign(:page_title, "New Collection")
    |> assign(:collection, collection)
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Listing Collections")
    |> assign(:collection, nil)
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
    collection = Catalog.get_collection!(id)
    {:ok, _} = Catalog.delete_collection(collection)

    # Refresh both views with limited tree collections
    tree_collections = Catalog.list_collections_tree(50)

    # If a search is active, re-fetch current page with the search filter, otherwise just delete from stream
    search = socket.assigns[:search] || ""

    socket =
      socket
      |> assign(:tree_collections, tree_collections)

    if search != "" do
      page = socket.assigns[:page] || 1
      per_page = 10
      {collections, total_pages} = Catalog.list_collections_paginated(page, per_page, search)

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
  end

  @impl true
  def handle_event("toggle_view_mode", _params, socket) do
    new_mode = if socket.assigns.view_mode == "list", do: "tree", else: "list"

    # When switching to tree mode, reload limited tree collections
    socket =
      if new_mode == "tree" do
        tree_collections = Catalog.list_collections_tree(50)
        assign(socket, :tree_collections, tree_collections)
      else
        socket
      end

    {:noreply, assign(socket, :view_mode, new_mode)}
  end

  @impl true
  def handle_event("paginate", %{"page" => page}, socket) do
    page = String.to_integer(page)
    per_page = 10

    search = socket.assigns[:search] || ""

    {collections, total_pages} = Catalog.list_collections_paginated(page, per_page, search)

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
    page = 1
    per_page = 10

    {collections, total_pages} = Catalog.list_collections_paginated(page, per_page, q)

    socket =
      socket
      |> stream(:collections, collections, reset: true)
      |> assign(:page, page)
      |> assign(:total_pages, total_pages)
      |> assign(:search, q)
      |> assign(:collections_empty?, collections == [])
      |> assign(:collections_count, length(collections))

    {:noreply, socket}
  end

  @impl true
  def handle_event("clear_search", _params, socket) do
    # Clear filter and show initial unfiltered list
    page = 1
    per_page = 10
    {collections, total_pages} = Catalog.list_collections_paginated(page, per_page)

    socket =
      socket
      |> stream(:collections, collections, reset: true)
      |> assign(:page, page)
      |> assign(:total_pages, total_pages)
      |> assign(:search, "")
      |> assign(:collections_empty?, collections == [])
      |> assign(:collections_count, length(collections))

    {:noreply, socket}
  end
end
