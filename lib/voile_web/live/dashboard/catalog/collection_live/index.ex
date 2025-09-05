defmodule VoileWeb.Dashboard.Catalog.CollectionLive.Index do
  use VoileWeb, :live_view_dashboard

  alias Voile.Repo
  alias Voile.Schema.Catalog
  alias Voile.Schema.Catalog.Collection
  alias Voile.Schema.Master
  alias Voile.Schema.Metadata
  alias Voile.Schema.System

  @impl true
  def mount(_params, _session, socket) do
    page = 1
    per_page = 10
    {collections, total_pages} = Catalog.list_collections_paginated(page, per_page)
    tree_collections = Catalog.list_collections_tree()
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
      |> assign(:collection_type, collection_type)
      |> assign(:collection_properties, collection_properties)
      |> assign(:creator, creator)
      |> assign(:node_location, node_location)
      |> assign(:page, page)
      |> assign(:total_pages, total_pages)
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
    # Refresh tree collections when a new collection is saved
    tree_collections = Catalog.list_collections_tree()

    socket =
      socket
      |> stream_insert(:collections, collection, at: 0)
      |> assign(:tree_collections, tree_collections)

    {:noreply, socket}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    collection = Catalog.get_collection!(id)
    {:ok, _} = Catalog.delete_collection(collection)

    # Refresh both views
    tree_collections = Catalog.list_collections_tree()

    socket =
      socket
      |> stream_delete(:collections, collection)
      |> assign(:tree_collections, tree_collections)

    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle_view_mode", _params, socket) do
    new_mode = if socket.assigns.view_mode == "list", do: "tree", else: "list"
    {:noreply, assign(socket, :view_mode, new_mode)}
  end

  @impl true
  def handle_event("paginate", %{"page" => page}, socket) do
    page = String.to_integer(page)
    per_page = 10

    {collections, total_pages} = Catalog.list_collections_paginated(page, per_page)

    socket =
      socket
      |> stream(:collections, collections, reset: true)
      |> assign(:page, page)
      |> assign(:total_pages, total_pages)

    {:noreply, socket}
  end

  # Tree component for rendering hierarchical collections
  defp collection_tree_item(assigns) do
    ~H"""
    <div class="ml-0 border-l-2 border-gray-200 pl-4 mb-4">
      <div class="bg-white dark:bg-gray-800 rounded-lg shadow-sm border border-gray-200 p-4 hover:shadow-md transition-shadow">
        <div class="flex items-center justify-between">
          <div class="flex items-center space-x-4">
            <%= if @collection.thumbnail do %>
              <img src={@collection.thumbnail} class="w-12 h-12 object-cover rounded" alt="Thumbnail" />
            <% else %>
              <img src="/images/v.png" class="w-12 h-12 object-cover rounded" alt="No Thumbnail" />
            <% end %>
            
            <div>
              <div class="flex items-center space-x-2">
                <h3 class="font-semibold text-lg">{@collection.title}</h3>
                
                <%= if @collection.collection_type do %>
                  <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-blue-100 text-blue-800 capitalize">
                    {@collection.collection_type}
                  </span>
                <% end %>
                
                <%= if @collection.sort_order do %>
                  <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-gray-100 text-gray-800">
                    #{@collection.sort_order}
                  </span>
                <% end %>
              </div>
              
              <div class="text-sm text-gray-600">
                <span>
                  by {(@collection.mst_creator && @collection.mst_creator.creator_name) || "Unknown"}
                </span> <span class="mx-2">•</span>
                <span class="capitalize">{@collection.status}</span> <span class="mx-2">•</span>
                <span class="capitalize">{@collection.access_level}</span>
              </div>
            </div>
          </div>
          
          <div class="flex items-center space-x-2">
            <.link
              navigate={~p"/manage/catalog/collections/#{@collection.id}"}
              class="text-blue-600 hover:text-blue-800"
            >
              <.icon name="hero-eye" class="w-5 h-5" />
            </.link>
            <.link
              patch={~p"/manage/catalog/collections/#{@collection.id}/edit"}
              class="text-green-600 hover:text-green-800"
            >
              <.icon name="hero-pencil" class="w-5 h-5" />
            </.link>
            <.link
              phx-click={JS.push("delete", value: %{id: @collection.id})}
              data-confirm="Are you sure?"
              class="text-red-600 hover:text-red-800"
            >
              <.icon name="hero-trash" class="w-5 h-5" />
            </.link>
          </div>
        </div>
      </div>
      
      <%= if @collection.children && !Enum.empty?(@collection.children) do %>
        <div class="ml-8 mt-2">
          <%= for child <- @collection.children do %>
            <.collection_tree_item collection={child} />
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end
end
