defmodule VoileWeb.Frontend.Items.Index do
  @moduledoc """
  Frontend LiveView for displaying items to library members
  """

  use VoileWeb, :live_view
  import VoileWeb.VoileComponents

  alias Voile.Task.Catalog.Items

  @impl true
  def mount(_params, _session, socket) do
    filter_options = Items.get_filter_options()

    {:ok,
     socket
     |> assign(:page_title, gettext("Browse Items"))
     |> assign(:items, [])
     |> assign(:loading, false)
     |> assign(:current_page, 1)
     |> assign(:total_pages, 1)
     |> assign(:search_query, "")
     |> assign(:filter_availability, "all")
     |> assign(:filter_condition, "all")
     |> assign(:filter_location, "all")
     |> assign(:sort_by, "item_code")
     |> assign(:sort_order, "asc")
     |> assign(:availability_options, filter_options.availability)
     |> assign(:condition_options, filter_options.condition)
     |> assign(:location_options, filter_options.location)
     |> stream_configure(:items, dom_id: &"item-#{&1.id}")}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    page = get_page_from_params(params)
    search_query = Map.get(params, "q", "")
    filter_availability = Map.get(params, "availability", "all")
    filter_condition = Map.get(params, "condition", "all")
    filter_location = Map.get(params, "location", "all")
    sort_by = Map.get(params, "sort", "item_code")
    sort_order = Map.get(params, "order", "asc")

    socket =
      socket
      |> assign(:current_page, page)
      |> assign(:search_query, search_query)
      |> assign(:filter_availability, filter_availability)
      |> assign(:filter_condition, filter_condition)
      |> assign(:filter_location, filter_location)
      |> assign(:sort_by, sort_by)
      |> assign(:sort_order, sort_order)
      |> assign(:loading, true)

    send(
      self(),
      {:load_items, page, search_query,
       %{
         availability: filter_availability,
         condition: filter_condition,
         location: filter_location
       }, sort_by, sort_order}
    )

    {:noreply, socket}
  end

  @impl true
  def handle_info({:load_items, page, search_query, filters, sort_by, sort_order}, socket) do
    {items, total_pages} = Items.load_items(page, search_query, filters, sort_by, sort_order)

    {:noreply,
     socket
     |> assign(:items, items)
     |> assign(:total_pages, total_pages)
     |> assign(:loading, false)
     |> stream(:items, items, reset: true)}
  end

  @impl true
  def handle_event("search", %{"q" => query}, socket) do
    params = build_params(socket, %{"q" => query, "page" => "1"})
    {:noreply, push_patch(socket, to: ~p"/items?#{params}")}
  end

  @impl true
  def handle_event("filter", params, socket) do
    params = build_params(socket, Map.merge(params, %{"page" => "1"}))
    {:noreply, push_patch(socket, to: ~p"/items?#{params}")}
  end

  @impl true
  def handle_event("sort", %{"sort" => sort_by, "order" => sort_order}, socket) do
    params = build_params(socket, %{"sort" => sort_by, "order" => sort_order, "page" => "1"})
    {:noreply, push_patch(socket, to: ~p"/items?#{params}")}
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
                <h1 class="text-2xl font-bold text-gray-900 dark:text-white">
                  {gettext("Browse Items")}
                </h1>

                <p class="mt-1 text-sm text-gray-600 dark:text-gray-300">
                  {gettext("Browse individual items in our library collection")}
                </p>
              </div>

              <div class="flex items-center gap-4">
                <.link
                  navigate={~p"/collections"}
                  class="inline-flex items-center px-4 py-2 border border-voile-muted dark:border-voile-dark rounded-md shadow-sm text-sm font-medium text-gray-700 dark:text-gray-200 bg-white dark:bg-gray-700 hover:bg-voile-surface dark:hover:bg-voile-neutral-dark focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
                >
                  <.icon name="hero-rectangle-stack-solid" class="w-4 h-4 mr-2" /> {gettext(
                    "Browse Collections"
                  )}
                </.link>
                <.link
                  navigate={~p"/search"}
                  class="inline-flex items-center px-4 py-2 border border-voile-muted dark:border-voile-dark rounded-md shadow-sm text-sm font-medium text-gray-700 dark:text-gray-200 bg-white dark:bg-gray-700 hover:bg-voile-surface dark:hover:bg-voile-neutral-dark focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
                >
                  <.icon name="hero-magnifying-glass-solid" class="w-4 h-4 mr-2" /> {gettext(
                    "Advanced Search"
                  )}
                </.link>
              </div>
            </div>
          </div>
        </div>
        <!-- Filters and Search -->
        <div class="bg-white dark:bg-gray-800 border-b border-voile-light dark:border-voile-dark">
          <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-4">
            <!-- Search Bar -->
            <div class="mb-4">
              <form phx-submit="search" phx-change="search" class="relative">
                <input
                  type="text"
                  name="q"
                  value={@search_query}
                  placeholder={gettext("Search items by code, location, or collection...")}
                  class="block w-full pl-10 pr-4 py-2 border border-voile-muted dark:border-voile-dark rounded-md leading-5 bg-white dark:bg-voile-neutral-dark placeholder-gray-500 dark:placeholder-gray-400 text-gray-900 dark:text-white focus:outline-none focus:placeholder-gray-400 dark:focus:placeholder-gray-500 focus:ring-1 focus:ring-blue-500 focus:border-blue-500"
                  phx-debounce="500"
                />
                <div class="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
                  <.icon name="hero-magnifying-glass-solid" class="h-5 w-5 text-gray-400" />
                </div>
              </form>
            </div>
            <!-- Filters Row -->
            <form phx-change="filter">
              <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-5 gap-4">
                <!-- Availability Filter -->
                <div>
                  <label class="block text-xs font-medium text-gray-700 dark:text-gray-300 mb-1">
                    {gettext("Availability")}
                  </label>
                  <select
                    name="availability"
                    class="block w-full px-3 py-2 border border-voile-muted dark:border-voile-dark rounded-md shadow-sm bg-white dark:bg-gray-700 text-gray-900 dark:text-white focus:outline-none focus:ring-blue-500 focus:border-blue-500 text-sm"
                  >
                    <option value="all" selected={@filter_availability == "all"}>
                      {gettext("All")}
                    </option>

                    <%= for value <- @availability_options do %>
                      <option value={value} selected={@filter_availability == value}>
                        {String.capitalize(value)}
                      </option>
                    <% end %>
                  </select>
                </div>
                <!-- Condition Filter -->
                <div>
                  <label class="block text-xs font-medium text-gray-700 dark:text-gray-300 mb-1">
                    {gettext("Condition")}
                  </label>
                  <select
                    name="condition"
                    class="block w-full px-3 py-2 border border-voile-muted dark:border-voile-dark rounded-md shadow-sm bg-white dark:bg-gray-700 text-gray-900 dark:text-white focus:outline-none focus:ring-blue-500 focus:border-blue-500 text-sm"
                  >
                    <option value="all" selected={@filter_condition == "all"}>
                      {gettext("All Conditions")}
                    </option>

                    <%= for value <- @condition_options do %>
                      <option value={value} selected={@filter_condition == value}>
                        {String.capitalize(value)}
                      </option>
                    <% end %>
                  </select>
                </div>
                <!-- Location Filter -->
                <div>
                  <label class="block text-xs font-medium text-gray-700 dark:text-gray-300 mb-1">
                    {gettext("Location")}
                  </label>
                  <select
                    name="location"
                    class="block w-full px-3 py-2 border border-voile-muted dark:border-voile-dark rounded-md shadow-sm bg-white dark:bg-gray-700 text-gray-900 dark:text-white focus:outline-none focus:ring-blue-500 focus:border-blue-500 text-sm"
                  >
                    <option value="all" selected={@filter_location == "all"}>
                      {gettext("All Locations")}
                    </option>

                    <%= for value <- @location_options do %>
                      <option value={value} selected={@filter_location == value}>{value}</option>
                    <% end %>
                  </select>
                </div>
                <!-- Sort By -->
                <div>
                  <label class="block text-xs font-medium text-gray-700 dark:text-gray-300 mb-1">
                    {gettext("Sort By")}
                  </label>
                  <select
                    name="sort"
                    class="block w-full px-3 py-2 border border-voile-muted dark:border-voile-dark rounded-md shadow-sm bg-white dark:bg-gray-700 text-gray-900 dark:text-white focus:outline-none focus:ring-blue-500 focus:border-blue-500 text-sm"
                  >
                    <option value="item_code" selected={@sort_by == "item_code"}>
                      {gettext("Item Code")}
                    </option>

                    <option value="location" selected={@sort_by == "location"}>
                      {gettext("Location")}
                    </option>

                    <option value="availability" selected={@sort_by == "availability"}>
                      {gettext("Availability")}
                    </option>

                    <option value="condition" selected={@sort_by == "condition"}>
                      {gettext("Condition")}
                    </option>

                    <option value="collection" selected={@sort_by == "collection"}>
                      {gettext("Collection")}
                    </option>

                    <option value="date_added" selected={@sort_by == "date_added"}>
                      {gettext("Date Added")}
                    </option>
                  </select>
                </div>
                <!-- Sort Order -->
                <div>
                  <label class="block text-xs font-medium text-gray-700 dark:text-gray-300 mb-1">
                    {gettext("Order")}
                  </label>
                  <select
                    name="order"
                    class="block w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-md shadow-sm bg-white dark:bg-gray-700 text-gray-900 dark:text-white focus:outline-none focus:ring-blue-500 focus:border-blue-500 text-sm"
                  >
                    <option value="asc" selected={@sort_order == "asc"}>
                      {gettext("Ascending")}
                    </option>

                    <option value="desc" selected={@sort_order == "desc"}>
                      {gettext("Descending")}
                    </option>
                  </select>
                </div>
              </div>
            </form>
          </div>
        </div>
        <!-- Content -->
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
          <%= if @loading do %>
            <div class="flex justify-center items-center py-12">
              <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-voile-primary"></div>
              <span class="ml-2 text-gray-600 dark:text-gray-300">{gettext("Loading items...")}</span>
            </div>
          <% else %>
            <!-- Results Header -->
            <div class="mb-6">
              <p class="text-sm text-gray-700 dark:text-gray-300">
                {gettext("Showing")} {length(@items)} {gettext("items")}
                <%= if @search_query != "" do %>
                  {gettext("for")} "<strong><%= @search_query %></strong>"
                <% end %>
              </p>
            </div>
            <!-- Items List/Grid -->
            <%= if length(@items) > 0 do %>
              <div class="bg-white dark:bg-gray-800 shadow-sm border border-voile-light dark:border-voile-dark rounded-lg divide-y divide-voile-light dark:divide-voile-dark mb-8">
                <div
                  :for={{id, item} <- @streams.items}
                  id={id}
                  class="p-6 hover:bg-gray-50 dark:hover:bg-gray-700"
                >
                  <.item_row item={item} />
                </div>
              </div>
              <!-- Pagination -->
              <%= if @total_pages > 1 do %>
                <.frontend_pagination
                  current_page={@current_page}
                  total_pages={@total_pages}
                  search_query={@search_query}
                  filter_unit_id=""
                  filter_status="published"
                  socket={@socket}
                  type_page="items"
                />
              <% end %>
            <% else %>
              <.empty_state
                search_query={@search_query}
                title={gettext("No items found")}
                message={gettext("There are no items available at this time.")}
                icon_name="hero-document"
              />
            <% end %>
          <% end %>
        </div>
      </div>
    </Layouts.app>
    """
  end

  # Helper functions that are still needed
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

  defp build_params(socket, overrides) do
    base = %{
      "q" => socket.assigns.search_query,
      "availability" => socket.assigns.filter_availability,
      "condition" => socket.assigns.filter_condition,
      "location" => socket.assigns.filter_location,
      "sort" => socket.assigns.sort_by,
      "order" => socket.assigns.sort_order,
      "page" => socket.assigns.current_page
    }

    Map.merge(base, overrides)
    |> Enum.reject(fn {_k, v} -> v == "" or v == "all" end)
    |> Enum.into(%{})
  end
end
