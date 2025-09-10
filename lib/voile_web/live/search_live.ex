defmodule VoileWeb.SearchLive do
  @moduledoc """
  LiveView component for real-time search functionality
  """

  use VoileWeb, :live_view

  alias Voile.Schema.Search

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:search_query, "")
     |> assign(:search_type, "universal")
     |> assign(:results, %{})
     |> assign(:loading, false)
     |> assign(:show_results, false)
     |> assign(:user_role, get_user_role(socket))}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    query = Map.get(params, "q", "")
    search_type = Map.get(params, "type", "universal")
    page = Map.get(params, "page", "1") |> String.to_integer()

    socket =
      socket
      |> assign(:search_query, query)
      |> assign(:search_type, search_type)
      |> assign(:page, page)

    if String.trim(query) != "" do
      send(self(), {:perform_search, query, search_type, page})
      {:noreply, assign(socket, :loading, true)}
    else
      {:noreply, assign(socket, :show_results, false)}
    end
  end

  @impl true
  def handle_event("search", %{"query" => query, "type" => search_type}, socket) do
    trimmed_query = String.trim(query)

    socket =
      socket
      |> assign(:search_query, query)
      |> assign(:search_type, search_type)

    if String.length(trimmed_query) >= 2 do
      send(self(), {:perform_search, trimmed_query, search_type, 1})

      socket =
        socket
        |> assign(:loading, true)

      {:noreply, socket}
    else
      socket =
        socket
        |> assign(:loading, false)
        |> assign(:results, %{})
        |> assign(:show_results, false)

      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("clear_search", _params, socket) do
    {:noreply,
     socket
     |> assign(:search_query, "")
     |> assign(:results, %{})
     |> assign(:show_results, false)
     |> push_patch(to: ~p"/search")}
  end

  @impl true
  def handle_event("change_type", %{"type" => new_type}, socket) do
    socket = assign(socket, :search_type, new_type)

    if String.trim(socket.assigns.search_query) != "" do
      send(self(), {:perform_search, socket.assigns.search_query, new_type, 1})
      {:noreply, assign(socket, :loading, true)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:perform_search, query, search_type, page}, socket) do
    user_role = socket.assigns.user_role

    results =
      case search_type do
        "collections" ->
          Search.search_collections(query, user_role, %{page: page})

        "items" ->
          Search.search_items(query, user_role, %{page: page})

        "universal" ->
          Search.universal_search(query, user_role, %{page: page})
      end

    {:noreply,
     socket
     |> assign(:results, results)
     |> assign(:loading, false)
     |> assign(:show_results, true)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-6xl mx-auto p-6">
      <!-- Search Header -->
      <div class="bg-white rounded-lg shadow-sm p-6 mb-6">
        <div class="flex flex-col md:flex-row gap-4 items-start md:items-center justify-between">
          <div>
            <h1 class="text-2xl font-bold text-gray-900">Search Library Catalog</h1>

            <p class="text-gray-600 mt-1">Find books, collections, and resources</p>
          </div>

          <div class="flex gap-2">
            <.link
              patch={~p"/search/advanced"}
              class="px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 transition-colors"
            >
              Advanced Search
            </.link>
          </div>
        </div>
      </div>
      <!-- Search Form -->
      <div class="bg-white rounded-lg shadow-sm p-6 mb-6">
        <form phx-change="search" phx-submit="search" class="space-y-4">
          <div class="flex gap-2">
            <div class="flex-1 relative">
              <input
                type="text"
                name="query"
                value={@search_query}
                placeholder="Search for books, authors, subjects..."
                class="w-full px-4 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                autocomplete="off"
                phx-debounce="500"
              />
              <%= if @loading do %>
                <div class="absolute right-3 top-2.5">
                  <svg
                    class="animate-spin h-5 w-5 text-blue-600"
                    xmlns="http://www.w3.org/2000/svg"
                    fill="none"
                    viewBox="0 0 24 24"
                  >
                    <circle
                      class="opacity-25"
                      cx="12"
                      cy="12"
                      r="10"
                      stroke="currentColor"
                      stroke-width="4"
                    >
                    </circle>

                    <path
                      class="opacity-75"
                      fill="currentColor"
                      d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
                    >
                    </path>
                  </svg>
                </div>
              <% end %>
            </div>

            <select
              name="type"
              phx-change="change_type"
              class="px-4 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-transparent"
            >
              <option value="universal" selected={@search_type == "universal"}>All</option>

              <option value="collections" selected={@search_type == "collections"}>
                Collections
              </option>

              <option value="items" selected={@search_type == "items"}>Items</option>
            </select>
            <%= if @search_query != "" do %>
              <button
                type="button"
                phx-click="clear_search"
                class="px-4 py-2 bg-gray-100 text-gray-600 rounded-md hover:bg-gray-200 transition-colors"
              >
                Clear
              </button>
            <% end %>
          </div>
        </form>
      </div>
      <!-- Search Results -->
      <%= if @show_results and not @loading do %>
        <div class="space-y-6">
          <!-- Results Summary -->
          <div class="bg-gray-50 rounded-lg p-4">
            <%= if @search_type == "universal" do %>
              <p class="text-gray-700">
                Found <strong>{@results.total_results}</strong>
                results for "<strong><%= @search_query %></strong>"
                ({@results.collections.total} collections, {@results.items.total} items)
              </p>
            <% else %>
              <p class="text-gray-700">
                Found
                <strong>{@results.total}</strong> {if @search_type == "collections",
                  do: "collections",
                  else: "items"} for "<strong><%= @search_query %></strong>"
              </p>
            <% end %>
          </div>
          <!-- Universal Search Results -->
          <%= if @search_type == "universal" do %>
            <!-- Collections Section -->
            <%= if length(@results.collections.results) > 0 do %>
              <.search_results_section
                title="Collections"
                results={@results.collections.results}
                total={@results.collections.total}
                type="collections"
                search_query={@search_query}
              />
            <% end %>
            <!-- Items Section -->
            <%= if length(@results.items.results) > 0 do %>
              <.search_results_section
                title="Items"
                results={@results.items.results}
                total={@results.items.total}
                type="items"
                search_query={@search_query}
              />
            <% end %>
          <% else %>
            <!-- Single Type Results -->
            <.search_results_section
              title={String.capitalize(@search_type)}
              results={@results.results}
              total={@results.total}
              type={@search_type}
              search_query={@search_query}
              show_pagination={true}
              pagination={@results}
            />
          <% end %>
          <!-- No Results -->
          <%= if (@search_type == "universal" and @results.total_results == 0) or
                  (@search_type != "universal" and @results.total == 0) do %>
            <.no_results_message query={@search_query} />
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  # Components

  defp search_results_section(assigns) do
    assigns = assign_new(assigns, :show_pagination, fn -> false end)
    assigns = assign_new(assigns, :pagination, fn -> %{} end)

    ~H"""
    <div class="bg-white rounded-lg shadow-sm">
      <div class="p-4 border-b border-gray-200">
        <h2 class="text-lg font-semibold text-gray-900 flex items-center">
          <%= if @type == "collections" do %>
            <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10"
              >
              </path>
            </svg>
          <% else %>
            <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M12 6.253v13m0-13C10.832 5.477 9.246 5 7.5 5S4.168 5.477 3 6.253v13C4.168 18.477 5.754 18 7.5 18s3.332.477 4.5 1.253m0-13C13.168 5.477 14.754 5 16.5 5c1.746 0 3.332.477 4.5 1.253v13C19.832 18.477 18.246 18 16.5 18c-1.746 0-3.332.477-4.5 1.253"
              >
              </path>
            </svg>
          <% end %>
          {@title} ({@total})
        </h2>
      </div>

      <div class="divide-y divide-gray-200">
        <%= if @type == "collections" do %>
          <%= for collection <- @results do %>
            <.collection_result_item collection={collection} search_query={@search_query} />
          <% end %>
        <% else %>
          <%= for item <- @results do %>
            <.item_result_item item={item} search_query={@search_query} />
          <% end %>
        <% end %>
      </div>

      <%= if not @show_pagination and @total > length(@results) do %>
        <div class="p-4 bg-gray-50 text-center">
          <.link
            patch={~p"/search?q=#{@search_query}&type=#{@type}"}
            class="text-blue-600 hover:text-blue-800 font-medium"
          >
            View all {@total} {@type} →
          </.link>
        </div>
      <% end %>

      <%= if @show_pagination and @pagination.total_pages > 1 do %>
        <.search_pagination pagination={@pagination} search_query={@search_query} type={@type} />
      <% end %>
    </div>
    """
  end

  defp collection_result_item(assigns) do
    ~H"""
    <div class="p-4 hover:bg-gray-50">
      <div class="flex justify-between items-start">
        <div class="flex-1">
          <h3 class="font-medium text-gray-900">
            <.link patch={~p"/collections/#{@collection.id}"} class="hover:text-blue-600">
              {Phoenix.HTML.raw(
                VoileWeb.SearchHTML.highlight_search_term(@collection.title, @search_query)
              )}
            </.link>
          </h3>

          <%= if @collection.description do %>
            <p class="text-gray-600 mt-1 line-clamp-2">
              {Phoenix.HTML.raw(
                VoileWeb.SearchHTML.highlight_search_term(
                  VoileWeb.SearchHTML.truncate_text(@collection.description),
                  @search_query
                )
              )}
            </p>
          <% end %>

          <div class="flex items-center gap-4 mt-2 text-sm text-gray-500">
            <%= if @collection.mst_creator do %>
              <span>By: {@collection.mst_creator.name}</span>
            <% end %>
            <span>Type: {String.capitalize(@collection.collection_type || "Unknown")}</span>
            <span>Items: {length(@collection.items || [])}</span>
          </div>
        </div>

        <div class="ml-4">
          <span class={"px-2 py-1 text-xs rounded-full #{VoileWeb.SearchHTML.status_class(@collection.status)}"}>
            {String.capitalize(@collection.status || "unknown")}
          </span>
        </div>
      </div>
    </div>
    """
  end

  defp item_result_item(assigns) do
    ~H"""
    <div class="p-4 hover:bg-gray-50">
      <div class="flex justify-between items-start">
        <div class="flex-1">
          <h3 class="font-medium text-gray-900">
            <.link patch={~p"/items/#{@item.id}"} class="hover:text-blue-600">
              {Phoenix.HTML.raw(
                VoileWeb.SearchHTML.highlight_search_term(@item.collection.title, @search_query)
              )}
            </.link>
          </h3>

          <div class="flex items-center gap-4 mt-1 text-sm text-gray-600">
            <span>Code: {@item.item_code}</span>
            <%= if @item.inventory_code do %>
              <span>Inventory: {@item.inventory_code}</span>
            <% end %>
            <span>Location: {@item.location}</span>
          </div>
        </div>

        <div class="ml-4 text-right">
          <span class={"px-2 py-1 text-xs rounded-full #{VoileWeb.SearchHTML.availability_class(@item.availability)}"}>
            {String.capitalize(@item.availability || "unknown")}
          </span>
          <div class="text-xs text-gray-500 mt-1">
            {String.capitalize(@item.condition || "unknown")}
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp search_pagination(assigns) do
    ~H"""
    <div class="p-4 border-t border-gray-200 flex items-center justify-between">
      <div class="text-sm text-gray-700">
        Showing page {@pagination.page} of {@pagination.total_pages} ({@pagination.total} total results)
      </div>

      <div class="flex gap-2">
        <%= if @pagination.has_prev do %>
          <.link
            patch={~p"/search?q=#{@search_query}&type=#{@type}&page=#{@pagination.page - 1}"}
            class="px-3 py-2 text-sm border border-gray-300 rounded-md hover:bg-gray-50"
          >
            Previous
          </.link>
        <% end %>

        <%= if @pagination.has_next do %>
          <.link
            patch={~p"/search?q=#{@search_query}&type=#{@type}&page=#{@pagination.page + 1}"}
            class="px-3 py-2 text-sm bg-blue-600 text-white rounded-md hover:bg-blue-700"
          >
            Next
          </.link>
        <% end %>
      </div>
    </div>
    """
  end

  defp no_results_message(assigns) do
    ~H"""
    <div class="bg-white rounded-lg shadow-sm p-8 text-center">
      <svg
        class="w-16 h-16 mx-auto text-gray-400 mb-4"
        fill="none"
        stroke="currentColor"
        viewBox="0 0 24 24"
      >
        <path
          stroke-linecap="round"
          stroke-linejoin="round"
          stroke-width="2"
          d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"
        >
        </path>
      </svg>
      <h3 class="text-lg font-medium text-gray-900 mb-2">No results found</h3>

      <p class="text-gray-600 mb-4">
        We couldn't find anything matching "<strong><%= @query %></strong>".
      </p>

      <div class="text-sm text-gray-500">
        <p>Try:</p>

        <ul class="list-disc list-inside mt-2 space-y-1">
          <li>Checking your spelling</li>

          <li>Using different keywords</li>

          <li>Using more general terms</li>

          <li>Using the advanced search for more specific criteria</li>
        </ul>
      </div>
    </div>
    """
  end

  # Helper functions

  defp get_user_role(socket) do
    current_user = socket.assigns[:current_user]

    cond do
      is_nil(current_user) ->
        "patron"

      current_user.user_role && current_user.user_role.name == "librarian" ->
        "librarian"

      current_user.user_role && current_user.user_role.name in ["admin", "superadmin"] ->
        "librarian"

      true ->
        "patron"
    end
  end
end
