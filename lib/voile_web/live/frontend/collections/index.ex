defmodule VoileWeb.Frontend.Collections.Index do
  @moduledoc """
  Frontend LiveView for displaying collections to library members
  """

  use VoileWeb, :live_view
  import VoileWeb.VoileComponents

  alias Voile.Task.Catalog.Collection

  @impl true
  def mount(_params, _session, socket) do
    total_collections = Collection.count_collections()
    nodes = Collection.get_all_nodes()

    {:ok,
     socket
     |> assign(:page_title, "Browse Collections")
     |> assign(:collections, [])
     |> assign(:total_collections, total_collections)
     |> assign(:loading, false)
     |> assign(:current_page, 1)
     |> assign(:total_pages, 1)
     |> assign(:search_query, "")
     |> assign(:filter_unit_id, "all")
     |> assign(:filter_status, "published")
     |> assign(:nodes, nodes)
     |> stream_configure(:collections, dom_id: &"collection-#{&1.id}")}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    page = get_page_from_params(params)
    search_query = Map.get(params, "q", "")
    filter_unit_id = Map.get(params, "unit_id", "all")
    filter_status = Map.get(params, "status", "published")

    socket =
      socket
      |> assign(:current_page, page)
      |> assign(:search_query, search_query)
      |> assign(:filter_unit_id, filter_unit_id)
      |> assign(:filter_status, filter_status)
      |> assign(:loading, true)

    send(self(), {:load_collections, page, search_query, filter_unit_id, filter_status})

    {:noreply, socket}
  end

  @impl true
  def handle_info({:load_collections, page, search_query, filter_unit_id, filter_status}, socket) do
    {collections, total_pages, total_count_filtered} =
      Collection.load_collections(page, search_query, filter_unit_id, filter_status)

    {:noreply,
     socket
     |> assign(:collections, collections)
     |> assign(:total_pages, total_pages)
     |> assign(:total_count_filtered, total_count_filtered)
     |> assign(:loading, false)
     |> stream(:collections, collections, reset: true)}
  end

  @impl true
  def handle_event("search", %{"q" => query, "unit_id" => unit_id, "status" => status}, socket) do
    params = %{
      "q" => query,
      "unit_id" => unit_id,
      "status" => status,
      "page" => "1"
    }

    {:noreply, push_patch(socket, to: ~p"/collections?#{params}")}
  end

  @impl true
  def handle_event("search", %{"q" => query}, socket) do
    # Fallback for cases where hidden fields might not be present
    params = %{
      "q" => query,
      "unit_id" => socket.assigns.filter_unit_id,
      "status" => socket.assigns.filter_status,
      "page" => "1"
    }

    {:noreply, push_patch(socket, to: ~p"/collections?#{params}")}
  end

  @impl true
  def handle_event("filter_unit", %{"unit_id" => unit_id}, socket) do
    params = %{
      "q" => socket.assigns.search_query,
      "unit_id" => unit_id,
      "status" => socket.assigns.filter_status,
      "page" => "1"
    }

    {:noreply, push_patch(socket, to: ~p"/collections?#{params}")}
  end

  @impl true
  def handle_event("filter_status", %{"status" => status}, socket) do
    params = %{
      "q" => socket.assigns.search_query,
      "unit_id" => socket.assigns.filter_unit_id,
      "status" => status,
      "page" => "1"
    }

    {:noreply, push_patch(socket, to: ~p"/collections?#{params}")}
  end

  defp get_page_from_params(params) do
    case Map.get(params, "page") do
      nil ->
        1

      page_str ->
        case Integer.parse(page_str) do
          {page, _} when page > 0 -> page
          _ -> 1
        end
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="min-h-screen bg-gray-50 dark:bg-gray-900">
        <!-- Header -->
        <div class="bg-white dark:bg-gray-800 shadow-sm">
          <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-6">
            <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
              <div>
                <h1 class="text-2xl font-bold text-gray-900 dark:text-white">Browse Collections</h1>
                
                <p class="mt-1 text-sm text-gray-600 dark:text-gray-300">
                  Discover our curated collections
                </p>
              </div>
              
              <div class="flex items-center gap-4">
                <.link
                  navigate={~p"/search"}
                  class="inline-flex items-center px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-md shadow-sm text-sm font-medium text-gray-700 dark:text-gray-200 bg-white dark:bg-gray-700 hover:bg-gray-50 dark:hover:bg-gray-600 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
                >
                  <.icon name="hero-magnifying-glass-solid" class="w-4 h-4 mr-2" /> Advanced Search
                </.link>
              </div>
            </div>
          </div>
        </div>
        <!-- Filters -->
        <div class="bg-white dark:bg-gray-800 border-b border-gray-200 dark:border-gray-700">
          <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-4">
            <div class="flex flex-col sm:flex-row gap-4">
              <!-- Search -->
              <div class="flex-1">
                <form phx-submit="search" phx-change="search" class="relative">
                  <!-- Hidden fields to preserve current filter state -->
                  <input type="hidden" name="unit_id" value={@filter_unit_id} />
                  <input type="hidden" name="status" value={@filter_status} />
                  <input
                    type="text"
                    name="q"
                    value={@search_query}
                    placeholder="Search collections..."
                    class="block w-full pl-10 pr-4 py-2 border border-gray-300 dark:border-gray-600 rounded-md leading-5 bg-white dark:bg-gray-700 placeholder-gray-500 dark:placeholder-gray-400 text-gray-900 dark:text-white focus:outline-none focus:placeholder-gray-400 dark:focus:placeholder-gray-500 focus:ring-1 focus:ring-blue-500 focus:border-blue-500"
                    phx-debounce="500"
                  />
                  <div class="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
                    <.icon name="hero-magnifying-glass-solid" class="h-5 w-5 text-gray-400" />
                  </div>
                </form>
              </div>
              <!-- Unit Filter -->
              <div class="sm:w-48">
                <form phx-change="filter_unit">
                  <select
                    name="unit_id"
                    class="block w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-md shadow-sm bg-white dark:bg-gray-700 text-gray-900 dark:text-white focus:outline-none focus:ring-blue-500 focus:border-blue-500"
                  >
                    <option value="all" selected={@filter_unit_id == "all"}>All Location</option>
                    
                    <%= for node <- @nodes do %>
                      <option value={node.id} selected={@filter_unit_id == to_string(node.id)}>
                        {node.name} ({node.abbr})
                      </option>
                    <% end %>
                  </select>
                </form>
              </div>
              <!-- Status Filter -->
              <div class="sm:w-48">
                <form phx-change="filter_status">
                  <select
                    name="status"
                    class="block w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-md shadow-sm bg-white dark:bg-gray-700 text-gray-900 dark:text-white focus:outline-none focus:ring-blue-500 focus:border-blue-500"
                  >
                    <option value="published" selected={@filter_status == "published"}>
                      Available
                    </option>
                    
                    <option value="all" selected={@filter_status == "all"}>All Status</option>
                  </select>
                </form>
              </div>
            </div>
          </div>
        </div>
        <!-- Content -->
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
          <%= if @loading do %>
            <div class="flex justify-center items-center py-12">
              <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
               <span class="ml-2 text-gray-600 dark:text-gray-300">Loading collections...</span>
            </div>
          <% else %>
            <!-- Results Header -->
            <div class="mb-6">
              <p class="text-sm text-gray-700 dark:text-gray-300">
                Showing {length(@collections)} collections
                <%= if @search_query != "" do %>
                  for "<strong><%= @search_query %></strong>"
                <% end %>
                
                <span>
                  from
                  <%= if @search_query && @total_count_filtered do %>
                    <strong>{@total_count_filtered}</strong> filtered collections
                  <% else %>
                    <strong>0</strong> filtered collections
                  <% end %>
                </span>
              </p>
            </div>
            <!-- Collections Grid -->
            <%= if length(@collections) > 0 do %>
              <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-6 mb-8">
                <div
                  :for={{id, collection} <- @streams.collections}
                  id={id}
                  class="bg-white dark:bg-gray-800 rounded-lg shadow-sm border border-gray-200 dark:border-gray-700 hover:shadow-md transition-shadow duration-200"
                >
                  <.collection_card collection={collection} />
                </div>
              </div>
              <!-- Pagination -->
              <%= if @total_pages > 1 do %>
                <.frontend_pagination
                  current_page={@current_page}
                  total_pages={@total_pages}
                  search_query={@search_query}
                  filter_unit_id={@filter_unit_id}
                  filter_status={@filter_status}
                />
              <% end %>
            <% else %>
              <.empty_state
                search_query={@search_query}
                title="No collections found"
                message="There are no collections available at this time."
              />
            <% end %>
          <% end %>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
