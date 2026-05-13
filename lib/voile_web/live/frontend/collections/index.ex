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
    glam_type_options = ["all", "Gallery", "Library", "Archive", "Museum"]

    {:ok,
     socket
     |> assign(:page_title, gettext("Browse Collections"))
     |> assign(:collections, [])
     |> assign(:total_collections, total_collections)
     |> assign(:total_count_filtered, 0)
     |> assign(:loading, false)
     |> assign(:current_page, 1)
     |> assign(:total_pages, 1)
     |> assign(:search_query, "")
     |> assign(:filter_unit_id, "all")
     |> assign(:filter_status, "published")
     |> assign(:filter_glam_type, "all")
     |> assign(:filter_media_type, "all")
     |> assign(:filter_year_from, "")
     |> assign(:filter_year_to, "")
     |> assign(:has_active_filters, false)
     |> assign(:sidebar_open, false)
     |> assign(:glam_type_options, glam_type_options)
     |> assign(:nodes, nodes)
     |> stream_configure(:collections, dom_id: &"collection-#{&1.id}")}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    page = get_page_from_params(params)
    search_query = Map.get(params, "q", "")
    filter_unit_id = Map.get(params, "unit_id", "all")
    filter_status = Map.get(params, "status", "published")
    filter_glam_type = Map.get(params, "glam_type", "all")
    filter_media_type = Map.get(params, "media_type", "all")
    filter_year_from = Map.get(params, "year_from", "")
    filter_year_to = Map.get(params, "year_to", "")

    has_active_filters =
      filter_unit_id != "all" or
        filter_status != "published" or
        filter_glam_type != "all" or
        filter_media_type != "all" or
        filter_year_from != "" or
        filter_year_to != ""

    socket =
      socket
      |> assign(:current_page, page)
      |> assign(:search_query, search_query)
      |> assign(:filter_unit_id, filter_unit_id)
      |> assign(:filter_status, filter_status)
      |> assign(:filter_glam_type, filter_glam_type)
      |> assign(:filter_media_type, filter_media_type)
      |> assign(:filter_year_from, filter_year_from)
      |> assign(:filter_year_to, filter_year_to)
      |> assign(:has_active_filters, has_active_filters)
      |> assign(:loading, true)

    send(
      self(),
      {:load_collections, page, search_query, filter_unit_id, filter_status, filter_glam_type,
       filter_media_type, filter_year_from, filter_year_to}
    )

    {:noreply, socket}
  end

  @impl true
  def handle_info(
        {:load_collections, page, search_query, filter_unit_id, filter_status, filter_glam_type,
         filter_media_type, filter_year_from, filter_year_to},
        socket
      ) do
    {collections, total_pages, total_count_filtered} =
      Collection.load_collections(
        page,
        search_query,
        filter_unit_id,
        filter_status,
        filter_glam_type,
        filter_media_type,
        12,
        filter_year_from,
        filter_year_to
      )

    {:noreply,
     socket
     |> assign(:collections, collections)
     |> assign(:total_pages, total_pages)
     |> assign(:total_count_filtered, total_count_filtered)
     |> assign(:loading, false)
     |> stream(:collections, collections, reset: true)}
  end

  @impl true
  def handle_event("search", params_in, socket) do
    params =
      build_params(socket, %{
        "q" => Map.get(params_in, "q", ""),
        "page" => "1"
      })

    {:noreply, push_patch(socket, to: ~p"/collections?#{params}")}
  end

  @impl true
  def handle_event("filter_unit", %{"unit_id" => unit_id}, socket) do
    {:noreply,
     push_patch(socket, to: ~p"/collections?#{build_params(socket, %{"unit_id" => unit_id})}")}
  end

  @impl true
  def handle_event("filter_status", %{"status" => status}, socket) do
    {:noreply,
     push_patch(socket, to: ~p"/collections?#{build_params(socket, %{"status" => status})}")}
  end

  @impl true
  def handle_event("filter_glam_type", %{"glam_type" => glam_type}, socket) do
    {:noreply,
     push_patch(socket, to: ~p"/collections?#{build_params(socket, %{"glam_type" => glam_type})}")}
  end

  @impl true
  def handle_event("filter_media_type", %{"media_type" => media_type}, socket) do
    {:noreply,
     push_patch(socket,
       to: ~p"/collections?#{build_params(socket, %{"media_type" => media_type})}"
     )}
  end

  @impl true
  def handle_event("filter_year_range", params_in, socket) do
    params =
      build_params(socket, %{
        "year_from" => Map.get(params_in, "year_from", ""),
        "year_to" => Map.get(params_in, "year_to", ""),
        "page" => "1"
      })

    {:noreply, push_patch(socket, to: ~p"/collections?#{params}")}
  end

  @impl true
  def handle_event("clear_filters", _, socket) do
    params = %{"q" => socket.assigns.search_query, "page" => "1"}
    {:noreply, push_patch(socket, to: ~p"/collections?#{params}")}
  end

  @impl true
  def handle_event("toggle_sidebar", _, socket) do
    {:noreply, assign(socket, :sidebar_open, !socket.assigns.sidebar_open)}
  end

  defp build_params(socket, overrides) do
    %{
      "q" => socket.assigns.search_query,
      "unit_id" => socket.assigns.filter_unit_id,
      "status" => socket.assigns.filter_status,
      "glam_type" => socket.assigns.filter_glam_type,
      "media_type" => socket.assigns.filter_media_type,
      "year_from" => socket.assigns.filter_year_from,
      "year_to" => socket.assigns.filter_year_to,
      "page" => "1"
    }
    |> Map.merge(overrides)
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
        <%!-- Header with title and search bar --%>
        <div class="bg-white dark:bg-gray-800 shadow-sm border-b border-gray-200 dark:border-gray-700">
          <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-6">
            <%!-- Title row --%>
            <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4 mb-5">
              <div>
                <h1 class="text-2xl font-bold text-gray-900 dark:text-white">
                  {gettext("Browse Collections")}
                </h1>

                <p class="mt-1 text-sm text-gray-500 dark:text-gray-400">
                  {gettext("Explore")}
                  <span class="font-semibold text-gray-900 dark:text-white">
                    {@total_collections}
                  </span>
                  {gettext("collections from our GLAM institutions")}
                </p>
              </div>

              <.link
                navigate={~p"/search"}
                class="inline-flex items-center px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-md shadow-sm text-sm font-medium text-gray-700 dark:text-gray-200 bg-white dark:bg-gray-700 hover:bg-gray-50 dark:hover:bg-gray-600 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
              >
                <.icon name="hero-magnifying-glass-solid" class="w-4 h-4 mr-2" />
                {gettext("Advanced Search")}
              </.link>
            </div>
            <%!-- Search Input --%>
            <form phx-submit="search" phx-change="search" id="collections-search-form">
              <input type="hidden" name="unit_id" value={@filter_unit_id} />
              <input type="hidden" name="status" value={@filter_status} />
              <input type="hidden" name="glam_type" value={@filter_glam_type} />
              <input type="hidden" name="media_type" value={@filter_media_type} />
              <input type="hidden" name="year_from" value={@filter_year_from} />
              <input type="hidden" name="year_to" value={@filter_year_to} />

              <div class="relative">
                <div class="absolute inset-y-0 left-0 pl-4 flex items-center pointer-events-none">
                  <.icon name="hero-magnifying-glass-solid" class="h-5 w-5 text-gray-400" />
                </div>

                <input
                  type="text"
                  name="q"
                  value={@search_query}
                  placeholder={gettext("Search by title, description, or creator...")}
                  class="block w-full pl-12 pr-4 py-3 border border-gray-300 dark:border-gray-600 rounded-xl bg-white dark:bg-gray-700 text-gray-900 dark:text-white placeholder-gray-400 dark:placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent text-base"
                  phx-debounce="500"
                />
              </div>
            </form>
          </div>
        </div>
        <%!-- Main layout: Sidebar + Content --%>
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
          <%!-- Mobile filter toggle --%>
          <div class="lg:hidden mb-4">
            <button
              type="button"
              phx-click="toggle_sidebar"
              id="mobile-filter-toggle"
              class="inline-flex items-center gap-2 px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-md text-sm font-medium text-gray-700 dark:text-gray-200 bg-white dark:bg-gray-700 hover:bg-gray-50 dark:hover:bg-gray-600"
            >
              <.icon name="hero-adjustments-horizontal" class="w-4 h-4" />
              {gettext("Filters")}
              <%= if @has_active_filters do %>
                <span class="inline-flex items-center justify-center w-5 h-5 text-xs font-bold text-white bg-blue-600 rounded-full">
                  !
                </span>
              <% end %>
            </button>
          </div>

          <div class="flex gap-8 items-start">
            <%!-- Left Sidebar: Filters --%>
            <aside
              id="collections-sidebar"
              class={[
                "w-72 shrink-0",
                if(@sidebar_open, do: "block", else: "hidden"),
                "lg:block"
              ]}
            >
              <div class="bg-white dark:bg-gray-800 rounded-xl shadow-sm border border-gray-200 dark:border-gray-700 sticky top-6 overflow-hidden">
                <%!-- Sidebar header --%>
                <div class="px-4 py-3 border-b border-gray-200 dark:border-gray-700 flex items-center justify-between">
                  <h2 class="text-sm font-semibold text-gray-900 dark:text-white uppercase tracking-wide flex items-center gap-2">
                    <.icon name="hero-funnel" class="w-4 h-4" /> {gettext("Filters")}
                  </h2>

                  <%= if @has_active_filters do %>
                    <button
                      type="button"
                      phx-click="clear_filters"
                      id="clear-filters-btn"
                      class="text-xs text-blue-600 dark:text-blue-400 hover:text-blue-800 dark:hover:text-blue-200 font-medium"
                    >
                      {gettext("Clear all")}
                    </button>
                  <% end %>
                </div>
                <%!-- Location / Node Filter --%>
                <div class="px-4 py-4 border-b border-gray-100 dark:border-gray-700">
                  <h3 class="text-xs font-semibold text-gray-400 dark:text-gray-500 uppercase tracking-wider mb-3">
                    {gettext("Location")}
                  </h3>

                  <form phx-change="filter_unit" id="filter-unit-form">
                    <select
                      name="unit_id"
                      class="block w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg text-sm bg-white dark:bg-gray-700 text-gray-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                    >
                      <option value="all" selected={@filter_unit_id == "all"}>
                        {gettext("All Locations")}
                      </option>

                      <%= for node <- @nodes do %>
                        <option value={node.id} selected={@filter_unit_id == to_string(node.id)}>
                          {node.name} ({node.abbr})
                        </option>
                      <% end %>
                    </select>
                  </form>
                </div>
                <%!-- Availability / Status Filter --%>
                <div class="px-4 py-4 border-b border-gray-100 dark:border-gray-700">
                  <h3 class="text-xs font-semibold text-gray-400 dark:text-gray-500 uppercase tracking-wider mb-3">
                    {gettext("Availability")}
                  </h3>

                  <form phx-change="filter_status" id="filter-status-form">
                    <div class="space-y-2">
                      <label class="flex items-center gap-3 cursor-pointer group">
                        <input
                          type="radio"
                          name="status"
                          value="published"
                          checked={@filter_status == "published"}
                          class="text-blue-600 focus:ring-blue-500 border-gray-300 dark:border-gray-500"
                        />
                        <span class="text-sm text-gray-700 dark:text-gray-300 group-hover:text-gray-900 dark:group-hover:text-white">
                          {gettext("Available")}
                        </span>
                      </label>

                      <label class="flex items-center gap-3 cursor-pointer group">
                        <input
                          type="radio"
                          name="status"
                          value="all"
                          checked={@filter_status == "all"}
                          class="text-blue-600 focus:ring-blue-500 border-gray-300 dark:border-gray-500"
                        />
                        <span class="text-sm text-gray-700 dark:text-gray-300 group-hover:text-gray-900 dark:group-hover:text-white">
                          {gettext("All Status")}
                        </span>
                      </label>
                    </div>
                  </form>
                </div>
                <%!-- GLAM Type Filter --%>
                <div class="px-4 py-4 border-b border-gray-100 dark:border-gray-700">
                  <h3 class="text-xs font-semibold text-gray-400 dark:text-gray-500 uppercase tracking-wider mb-3">
                    {gettext("GLAM Type")}
                  </h3>

                  <form phx-change="filter_glam_type" id="filter-glam-type-form">
                    <div class="space-y-2">
                      <%= for opt <- @glam_type_options do %>
                        <label class="flex items-center gap-3 cursor-pointer group">
                          <input
                            type="radio"
                            name="glam_type"
                            value={opt}
                            checked={@filter_glam_type == opt}
                            class="text-blue-600 focus:ring-blue-500 border-gray-300 dark:border-gray-500"
                          />
                          <span class="text-sm text-gray-700 dark:text-gray-300 group-hover:text-gray-900 dark:group-hover:text-white">
                            {if(opt == "all", do: gettext("All Types"), else: opt)}
                          </span>
                        </label>
                      <% end %>
                    </div>
                  </form>
                </div>
                <%!-- Media Type Filter --%>
                <div class="px-4 py-4 border-b border-gray-100 dark:border-gray-700">
                  <h3 class="text-xs font-semibold text-gray-400 dark:text-gray-500 uppercase tracking-wider mb-3">
                    {gettext("Media Type")}
                  </h3>

                  <form phx-change="filter_media_type" id="filter-media-type-form">
                    <div class="space-y-2">
                      <label class="flex items-center gap-3 cursor-pointer group">
                        <input
                          type="radio"
                          name="media_type"
                          value="all"
                          checked={@filter_media_type == "all"}
                          class="text-blue-600 focus:ring-blue-500 border-gray-300 dark:border-gray-500"
                        />
                        <span class="text-sm text-gray-700 dark:text-gray-300 group-hover:text-gray-900 dark:group-hover:text-white">
                          {gettext("All Media")}
                        </span>
                      </label>

                      <label class="flex items-center gap-3 cursor-pointer group">
                        <input
                          type="radio"
                          name="media_type"
                          value="digital"
                          checked={@filter_media_type == "digital"}
                          class="text-blue-600 focus:ring-blue-500 border-gray-300 dark:border-gray-500"
                        />
                        <span class="text-sm text-gray-700 dark:text-gray-300 group-hover:text-gray-900 dark:group-hover:text-white">
                          {gettext("Digital Only")}
                        </span>
                      </label>

                      <label class="flex items-center gap-3 cursor-pointer group">
                        <input
                          type="radio"
                          name="media_type"
                          value="physical"
                          checked={@filter_media_type == "physical"}
                          class="text-blue-600 focus:ring-blue-500 border-gray-300 dark:border-gray-500"
                        />
                        <span class="text-sm text-gray-700 dark:text-gray-300 group-hover:text-gray-900 dark:group-hover:text-white">
                          {gettext("Physical Only")}
                        </span>
                      </label>
                    </div>
                  </form>
                </div>
                <%!-- Publication Year Range Filter --%>
                <div class="px-4 py-4">
                  <h3 class="text-xs font-semibold text-gray-400 dark:text-gray-500 uppercase tracking-wider mb-3">
                    {gettext("Publication Year")}
                  </h3>

                  <form phx-change="filter_year_range" id="year-range-form">
                    <div class="space-y-3">
                      <div>
                        <label class="block text-xs text-gray-500 dark:text-gray-400 mb-1">
                          {gettext("From")}
                        </label>

                        <input
                          type="number"
                          name="year_from"
                          value={@filter_year_from}
                          placeholder="e.g. 1990"
                          min="1000"
                          max="9999"
                          phx-debounce="800"
                          class="block w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg text-sm bg-white dark:bg-gray-700 text-gray-900 dark:text-white placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                        />
                      </div>

                      <div>
                        <label class="block text-xs text-gray-500 dark:text-gray-400 mb-1">
                          {gettext("To")}
                        </label>

                        <input
                          type="number"
                          name="year_to"
                          value={@filter_year_to}
                          placeholder="e.g. 2024"
                          min="1000"
                          max="9999"
                          phx-debounce="800"
                          class="block w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg text-sm bg-white dark:bg-gray-700 text-gray-900 dark:text-white placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                        />
                      </div>
                    </div>
                  </form>
                </div>
              </div>
            </aside>
            <%!-- Main Content --%>
            <div class="flex-1 min-w-0">
              <%= if @loading do %>
                <div class="flex justify-center items-center py-16">
                  <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
                  <span class="ml-3 text-gray-600 dark:text-gray-300">
                    {gettext("Loading collections...")}
                  </span>
                </div>
              <% else %>
                <%!-- Results header --%>
                <div class="mb-5 flex items-center justify-between">
                  <p class="text-sm text-gray-600 dark:text-gray-400">
                    {gettext("Showing")}
                    <span class="font-medium text-gray-900 dark:text-white">
                      {length(@collections)}
                    </span>
                    {gettext("collections")}
                    <%= if @search_query != "" do %>
                      {gettext("for")} &ldquo;<strong>{@search_query}</strong>&rdquo;
                    <% end %>
                    <%= if @total_count_filtered > 0 do %>
                      ·
                      <span class="font-medium text-gray-900 dark:text-white">
                        {@total_count_filtered}
                      </span>
                       {gettext("total")}
                    <% end %>
                  </p>

                  <%= if @has_active_filters do %>
                    <button
                      type="button"
                      phx-click="clear_filters"
                      class="lg:hidden text-xs text-blue-600 dark:text-blue-400 hover:text-blue-800 font-medium"
                    >
                      {gettext("Clear filters")}
                    </button>
                  <% end %>
                </div>
                <%!-- Collections Grid --%>
                <%= if length(@collections) > 0 do %>
                  <div
                    id="collections-grid"
                    class="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-3 gap-5 mb-8"
                  >
                    <div
                      :for={{id, collection} <- @streams.collections}
                      id={id}
                      class="bg-white dark:bg-gray-800 rounded-lg shadow-sm border border-gray-200 dark:border-gray-700 hover:shadow-md transition-shadow duration-200"
                    >
                      <.collection_card collection={collection} />
                    </div>
                  </div>
                  <%!-- Pagination --%>
                  <%= if @total_pages > 1 do %>
                    <.frontend_pagination
                      current_page={@current_page}
                      total_pages={@total_pages}
                      search_query={@search_query}
                      filter_unit_id={@filter_unit_id}
                      filter_status={@filter_status}
                      filter_glam_type={@filter_glam_type}
                      filter_media_type={@filter_media_type}
                      filter_year_from={@filter_year_from}
                      filter_year_to={@filter_year_to}
                    />
                  <% end %>
                <% else %>
                  <.empty_state
                    search_query={@search_query}
                    title={gettext("No collections found")}
                    message={gettext("There are no collections matching your current filters.")}
                  />
                <% end %>
              <% end %>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
