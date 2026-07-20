defmodule VoileWeb.SearchLive do
  @moduledoc """
  Public catalog search LiveView.
  """

  use VoileWeb, :live_view

  alias Voile.Schema.Search
  alias Voile.Schema.Accounts
  alias Voile.Analytics.SearchAnalytics

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:search_query, "")
     |> assign(:search_type, "universal")
     |> assign(:results, %{})
     |> assign(:loading, false)
     |> assign(:show_results, false)
     |> assign(:page, 1)
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
    trimmed = String.trim(query)
    socket = socket |> assign(:search_query, query) |> assign(:search_type, search_type)

    if String.length(trimmed) >= 2 do
      send(self(), {:perform_search, trimmed, search_type, 1})
      {:noreply, assign(socket, :loading, true)}
    else
      {:noreply,
       socket
       |> assign(:loading, false)
       |> assign(:results, %{})
       |> assign(:show_results, false)}
    end
  end

  @impl true
  def handle_event("clear_search", _params, socket) do
    {:noreply,
     socket
     |> assign(:search_query, "")
     |> assign(:results, %{})
     |> assign(:show_results, false)
     |> push_patch(to: ~p"/search/live")}
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
    # Record search for analytics
    user_id =
      socket.assigns[:current_scope] && socket.assigns.current_scope.user &&
        socket.assigns.current_scope.user.id

    SearchAnalytics.record_search(query, user_id, %{type: search_type, source: "search_live"})

    results =
      case search_type do
        "collections" -> Search.search_collections(query, %{page: page})
        "items" -> Search.search_items(query, %{page: page})
        _ -> Search.universal_search(query, %{page: page})
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
    <Layouts.app flash={@flash} current_scope={assigns[:current_scope]}>
      <%!-- ══════════════════════════════════════════════════════════
           SEARCH HERO
      ══════════════════════════════════════════════════════════ --%>
      <section class="voile-gradient py-12 px-4">
        <div class="max-w-3xl mx-auto text-center">
          <h1 class="text-3xl md:text-4xl font-bold text-white mb-2 drop-shadow">
            Search the Catalog
          </h1>
          <p class="text-white/80 mb-8 text-sm md:text-base">
            Find collections, books, articles, and physical copies across all branches
          </p>

          <%!-- Search bar --%>
          <form phx-change="search" phx-submit="search" class="w-full">
            <div class="relative flex items-center bg-white dark:bg-gray-800 rounded-2xl shadow-2xl overflow-hidden">
              <div class="absolute left-4 top-1/2 -translate-y-1/2 pointer-events-none">
                <%= if @loading do %>
                  <svg
                    class="animate-spin h-5 w-5 text-voile-primary"
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
                <% else %>
                  <.icon name="hero-magnifying-glass" class="w-5 h-5 text-gray-400" />
                <% end %>
              </div>
              <input
                type="text"
                name="query"
                value={@search_query}
                placeholder="Title, author, call number, ISBN, keyword…"
                class="flex-1 pl-12 pr-4 py-4 text-base text-gray-900 dark:text-white bg-transparent border-none outline-none placeholder-gray-400"
                autocomplete="off"
                phx-debounce="400"
              />
              <%= if @search_query != "" do %>
                <button
                  type="button"
                  phx-click="clear_search"
                  class="px-3 py-4 text-gray-400 hover:text-gray-600 dark:hover:text-gray-300 transition-colors"
                >
                  <.icon name="hero-x-mark" class="w-5 h-5" />
                </button>
              <% end %>
              <button
                type="submit"
                class="voile-gradient text-white font-semibold px-6 py-4 hover:opacity-90 transition-opacity shrink-0"
              >
                Search
              </button>
            </div>

            <%!-- Type pills --%>
            <div class="flex justify-center gap-2 mt-4 flex-wrap">
              <%= for {label, value, icon} <- [
                {"All", "universal", "hero-squares-2x2"},
                {"Collections", "collections", "hero-rectangle-stack"},
                {"Items & Copies", "items", "hero-book-open"}
              ] do %>
                <button
                  type="button"
                  phx-click="change_type"
                  phx-value-type={value}
                  class={[
                    "flex items-center gap-1.5 px-4 py-1.5 rounded-full text-sm font-medium transition-all",
                    if(@search_type == value,
                      do: "bg-white text-voile-primary shadow-md",
                      else: "bg-white/20 text-white hover:bg-white/30"
                    )
                  ]}
                >
                  <.icon name={icon} class="w-3.5 h-3.5" />
                  {label}
                </button>
              <% end %>
            </div>
            <input type="hidden" name="type" value={@search_type} />
          </form>

          <div class="mt-4 text-white/60 text-xs">
            <.link patch={~p"/search/advanced"} class="hover:text-white underline transition-colors">
              Advanced Search →
            </.link>
          </div>
        </div>
      </section>

      <%!-- ══════════════════════════════════════════════════════════
           RESULTS AREA
      ══════════════════════════════════════════════════════════ --%>
      <section class="max-w-4xl mx-auto px-4 py-8">
        <%!-- Loading skeletons --%>
        <%= if @loading do %>
          <div class="space-y-4">
            <%= for _ <- 1..5 do %>
              <div class="bg-white dark:bg-gray-800 rounded-2xl shadow-sm p-5 animate-pulse flex gap-4">
                <div class="w-12 h-16 bg-gray-200 dark:bg-gray-700 rounded-lg shrink-0"></div>
                <div class="flex-1 space-y-3">
                  <div class="h-4 bg-gray-200 dark:bg-gray-700 rounded w-3/4"></div>
                  <div class="h-3 bg-gray-200 dark:bg-gray-700 rounded w-1/2"></div>
                  <div class="flex gap-2">
                    <div class="h-5 bg-gray-200 dark:bg-gray-700 rounded-full w-16"></div>
                    <div class="h-5 bg-gray-200 dark:bg-gray-700 rounded-full w-20"></div>
                    <div class="h-5 bg-gray-200 dark:bg-gray-700 rounded-full w-14"></div>
                  </div>
                </div>
              </div>
            <% end %>
          </div>
        <% end %>

        <%!-- Results --%>
        <%= if @show_results and not @loading do %>
          <%!-- Summary bar --%>
          <div class="flex items-center justify-between mb-6">
            <div class="flex items-center gap-3">
              <span class="text-sm font-medium text-gray-700 dark:text-gray-300">
                <%= cond do %>
                  <% @search_type == "universal" -> %>
                    <span class="text-lg font-bold text-gray-900 dark:text-white">
                      {@results.total_results}
                    </span>
                    results for
                    <span class="font-semibold text-voile-primary">"{@search_query}"</span>
                  <% @search_type == "collections" -> %>
                    <span class="text-lg font-bold text-gray-900 dark:text-white">
                      {@results.total}
                    </span>
                    collections for
                    <span class="font-semibold text-voile-primary">"{@search_query}"</span>
                  <% true -> %>
                    <span class="text-lg font-bold text-gray-900 dark:text-white">
                      {@results.total}
                    </span>
                    items for <span class="font-semibold text-voile-primary">"{@search_query}"</span>
                <% end %>
              </span>
              <%= if @search_type == "universal" do %>
                <span class="hidden sm:flex items-center gap-1 text-xs text-gray-400">
                  <span class="w-2 h-2 rounded-full bg-blue-500 inline-block"></span>{@results.collections.total} collections <span class="w-2 h-2 rounded-full bg-green-500 inline-block ml-2"></span>{@results.items.total} items
                </span>
              <% end %>
            </div>
          </div>

          <%= cond do %>
            <%!-- Universal --%>
            <% @search_type == "universal" -> %>
              <div class="space-y-8">
                <%= if length(@results.collections.results) > 0 do %>
                  <.result_group
                    title="Collections"
                    icon="hero-rectangle-stack"
                    color="blue"
                    total={@results.collections.total}
                    search_query={@search_query}
                    type="collections"
                  >
                    <%= for c <- @results.collections.results do %>
                      <.collection_card collection={c} query={@search_query} />
                    <% end %>
                  </.result_group>
                <% end %>
                <%= if length(@results.items.results) > 0 do %>
                  <.result_group
                    title="Items & Copies"
                    icon="hero-book-open"
                    color="green"
                    total={@results.items.total}
                    search_query={@search_query}
                    type="items"
                  >
                    <%= for i <- @results.items.results do %>
                      <.item_card item={i} query={@search_query} />
                    <% end %>
                  </.result_group>
                <% end %>
                <%= if @results.total_results == 0 do %>
                  <.no_results query={@search_query} />
                <% end %>
              </div>

              <%!-- Collections only --%>
            <% @search_type == "collections" -> %>
              <div class="space-y-3">
                <%= for c <- @results.results do %>
                  <.collection_card collection={c} query={@search_query} />
                <% end %>
                <%= if @results.total == 0 do %>
                  <.no_results query={@search_query} />
                <% end %>
                <.pager
                  :if={@results.total_pages > 1}
                  p={@results}
                  q={@search_query}
                  type={@search_type}
                />
              </div>

              <%!-- Items only --%>
            <% true -> %>
              <div class="space-y-3">
                <%= for i <- @results.results do %>
                  <.item_card item={i} query={@search_query} />
                <% end %>
                <%= if @results.total == 0 do %>
                  <.no_results query={@search_query} />
                <% end %>
                <.pager
                  :if={@results.total_pages > 1}
                  p={@results}
                  q={@search_query}
                  type={@search_type}
                />
              </div>
          <% end %>
        <% end %>

        <%!-- Landing hint --%>
        <%= if not @show_results and not @loading do %>
          <div class="text-center py-20">
            <div class="w-20 h-20 mx-auto mb-6 rounded-full bg-voile-primary/10 flex items-center justify-center">
              <.icon name="hero-magnifying-glass-circle" class="w-10 h-10 text-voile-primary" />
            </div>
            <h3 class="text-xl font-semibold text-gray-700 dark:text-gray-300 mb-2">
              What are you looking for?
            </h3>
            <p class="text-sm text-gray-400 dark:text-gray-500 max-w-xs mx-auto">
              Search by title, author, call number, item code, or any keyword
            </p>
          </div>
        <% end %>
      </section>
    </Layouts.app>
    """
  end

  # ── Section group wrapper ────────────────────────────────────────────────

  attr :title, :string, required: true
  attr :icon, :string, required: true
  attr :color, :string, required: true
  attr :total, :integer, required: true
  attr :search_query, :string, required: true
  attr :type, :string, required: true
  slot :inner_block, required: true

  defp result_group(assigns) do
    ~H"""
    <div>
      <div class="flex items-center justify-between mb-3">
        <h2 class={[
          "flex items-center gap-2 font-bold text-base",
          if(@color == "blue",
            do: "text-blue-700 dark:text-blue-300",
            else: "text-green-700 dark:text-green-300"
          )
        ]}>
          <span class={[
            "w-7 h-7 rounded-lg flex items-center justify-center",
            if(@color == "blue",
              do: "bg-blue-100 dark:bg-blue-900/40",
              else: "bg-green-100 dark:bg-green-900/40"
            )
          ]}>
            <.icon name={@icon} class="w-4 h-4" />
          </span>
          {@title}
          <span class="text-xs font-normal text-gray-400">({@total})</span>
        </h2>
        <%= if @total > 5 do %>
          <.link
            patch={~p"/search/live?q=#{@search_query}&type=#{@type}"}
            class="text-xs text-voile-primary hover:underline font-medium"
          >
            View all {@total} →
          </.link>
        <% end %>
      </div>
      <div class="space-y-3">
        {render_slot(@inner_block)}
      </div>
    </div>
    """
  end

  # ── Collection card ──────────────────────────────────────────────────────

  attr :collection, :map, required: true
  attr :query, :string, required: true

  defp collection_card(assigns) do
    ~H"""
    <div class="group relative bg-white dark:bg-gray-800 rounded-2xl shadow-sm hover:shadow-lg border border-gray-100 dark:border-gray-700 hover:border-blue-200 dark:hover:border-blue-700 transition-all duration-200 overflow-hidden flex gap-0">
      <%!-- Left accent bar --%>
      <div class="w-1 shrink-0 bg-gradient-to-b from-blue-400 to-indigo-500 rounded-l-2xl"></div>

      <div class="flex gap-4 p-4 flex-1 min-w-0">
        <%!-- Cover / icon --%>
        <div class="shrink-0">
          <%= if @collection.thumbnail do %>
            <img
              src={@collection.thumbnail}
              alt=""
              class="w-12 h-16 object-cover rounded-lg shadow-sm"
              loading="lazy"
            />
          <% else %>
            <div class="w-12 h-16 rounded-lg bg-gradient-to-br from-blue-100 to-indigo-100 dark:from-blue-900/40 dark:to-indigo-900/40 flex items-center justify-center shadow-sm">
              <.icon name="hero-rectangle-stack" class="w-6 h-6 text-blue-500 dark:text-blue-400" />
            </div>
          <% end %>
        </div>

        <%!-- Body --%>
        <div class="flex-1 min-w-0">
          <div class="flex items-start justify-between gap-2 mb-1">
            <h3 class="font-semibold text-gray-900 dark:text-white leading-snug line-clamp-2 group-hover:text-blue-600 dark:group-hover:text-blue-400 transition-colors">
              <.link patch={~p"/collections/#{@collection.id}"}>
                {Phoenix.HTML.raw(
                  VoileWeb.SearchHTML.highlight_search_term(@collection.title, @query)
                )}
              </.link>
            </h3>
            <.coll_status_badge status={@collection.status} />
          </div>

          <%!-- Creator + call no + branch --%>
          <div class="flex flex-wrap items-center gap-x-3 gap-y-0.5 text-sm text-gray-500 dark:text-gray-400 mb-2">
            <%= if @collection.mst_creator do %>
              <span class="flex items-center gap-1">
                <.icon name="hero-user" class="w-3.5 h-3.5 shrink-0" />
                {@collection.mst_creator.creator_name}
              </span>
            <% end %>
            <%= if @collection.collection_code && @collection.collection_code != "" do %>
              <span class="flex items-center gap-1 font-mono text-xs font-semibold text-blue-600 dark:text-blue-400 bg-blue-50 dark:bg-blue-900/30 px-2 py-0.5 rounded">
                {@collection.collection_code}
              </span>
            <% end %>
            <%= if @collection.node do %>
              <span class="flex items-center gap-1 text-xs">
                <.icon name="hero-building-library" class="w-3.5 h-3.5 shrink-0" />
                {@collection.node.name}
              </span>
            <% end %>
          </div>

          <%!-- Tags row --%>
          <div class="flex flex-wrap items-center gap-1.5">
            <%= if @collection.resource_class do %>
              <span class="inline-flex items-center gap-1 text-xs px-2 py-0.5 rounded-full bg-indigo-50 dark:bg-indigo-900/30 text-indigo-600 dark:text-indigo-400 font-medium">
                <.icon name="hero-tag" class="w-3 h-3" />
                {@collection.resource_class.label}
              </span>
            <% end %>
            <%= if @collection.collection_type && @collection.collection_type != "" do %>
              <span class="text-xs px-2 py-0.5 rounded-full bg-gray-100 dark:bg-gray-700 text-gray-600 dark:text-gray-400">
                {String.capitalize(@collection.collection_type)}
              </span>
            <% end %>
            <%= if @collection.access_level && @collection.access_level != "public" do %>
              <span class="inline-flex items-center gap-1 text-xs px-2 py-0.5 rounded-full bg-amber-50 dark:bg-amber-900/30 text-amber-600 dark:text-amber-400">
                <.icon name="hero-lock-closed" class="w-3 h-3" />
                {String.capitalize(@collection.access_level)}
              </span>
            <% end %>
          </div>

          <%!-- Description --%>
          <%= if @collection.description && @collection.description != "" do %>
            <p class="mt-2 text-xs text-gray-400 dark:text-gray-500 line-clamp-2 leading-relaxed">
              {VoileWeb.SearchHTML.truncate_text(@collection.description, 160)}
            </p>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  # ── Item card ────────────────────────────────────────────────────────────

  attr :item, :map, required: true
  attr :query, :string, required: true

  defp item_card(assigns) do
    ~H"""
    <div class="group relative bg-white dark:bg-gray-800 rounded-2xl shadow-sm hover:shadow-lg border border-gray-100 dark:border-gray-700 hover:border-green-200 dark:hover:border-green-700 transition-all duration-200 overflow-hidden flex gap-0">
      <%!-- Left accent --%>
      <div class="w-1 shrink-0 bg-gradient-to-b from-green-400 to-emerald-500 rounded-l-2xl"></div>

      <div class="flex gap-4 p-4 flex-1 min-w-0">
        <%!-- Icon --%>
        <div class="shrink-0 w-12 h-16 rounded-lg bg-gradient-to-br from-green-100 to-emerald-100 dark:from-green-900/40 dark:to-emerald-900/40 flex items-center justify-center shadow-sm">
          <.icon name="hero-book-open" class="w-6 h-6 text-green-600 dark:text-green-400" />
        </div>

        <%!-- Body --%>
        <div class="flex-1 min-w-0">
          <div class="flex items-start justify-between gap-2 mb-1">
            <h3 class="font-semibold text-gray-900 dark:text-white leading-snug line-clamp-2 group-hover:text-green-600 dark:group-hover:text-green-400 transition-colors">
              <.link patch={~p"/collections/#{@item.collection_id}"}>
                {Phoenix.HTML.raw(
                  VoileWeb.SearchHTML.highlight_search_term(@item.collection.title, @query)
                )}
              </.link>
            </h3>
            <.avail_badge availability={@item.availability} />
          </div>

          <%!-- Call no + item codes --%>
          <div class="flex flex-wrap items-center gap-x-3 gap-y-0.5 text-sm text-gray-500 dark:text-gray-400 mb-2">
            <%= if @item.collection.collection_code && @item.collection.collection_code != "" do %>
              <span class="font-mono text-xs font-semibold text-green-700 dark:text-green-400 bg-green-50 dark:bg-green-900/30 px-2 py-0.5 rounded flex items-center gap-1">
                <.icon name="hero-tag" class="w-3 h-3" />
                {@item.collection.collection_code}
              </span>
            <% end %>
            <span class="flex items-center gap-1 text-xs">
              <.icon name="hero-qr-code" class="w-3.5 h-3.5 shrink-0" />
              {Phoenix.HTML.raw(VoileWeb.SearchHTML.highlight_search_term(@item.item_code, @query))}
            </span>
            <%= if @item.inventory_code && @item.inventory_code != "" do %>
              <span class="text-xs text-gray-400">
                Inv: {Phoenix.HTML.raw(
                  VoileWeb.SearchHTML.highlight_search_term(@item.inventory_code, @query)
                )}
              </span>
            <% end %>
          </div>

          <%!-- Location row --%>
          <div class="flex flex-wrap items-center gap-x-3 gap-y-0.5 text-xs text-gray-400 dark:text-gray-500 mb-2">
            <%= if @item.node do %>
              <span class="flex items-center gap-1">
                <.icon name="hero-building-library" class="w-3.5 h-3.5 shrink-0" />
                {@item.node.name}
              </span>
            <% end %>
            <%= if @item.location && @item.location != "" do %>
              <span class="flex items-center gap-1">
                <.icon name="hero-map-pin" class="w-3.5 h-3.5 shrink-0" />
                {Phoenix.HTML.raw(VoileWeb.SearchHTML.highlight_search_term(@item.location, @query))}
              </span>
            <% end %>
            <%= if @item.barcode && @item.barcode != "" do %>
              <span class="flex items-center gap-1">
                <.icon name="hero-bars-3-bottom-left" class="w-3 h-3 shrink-0" />
                {@item.barcode}
              </span>
            <% end %>
          </div>

          <%!-- Badges --%>
          <div class="flex flex-wrap items-center gap-1.5">
            <.cond_badge condition={@item.condition} />
            <%= if @item.status && @item.status != "" do %>
              <span class="text-xs px-2 py-0.5 rounded-full bg-gray-100 dark:bg-gray-700 text-gray-600 dark:text-gray-400">
                {String.capitalize(@item.status)}
              </span>
            <% end %>
            <%= if @item.acquisition_date do %>
              <span class="text-xs text-gray-400 dark:text-gray-500">
                Acq. {Calendar.strftime(@item.acquisition_date, "%Y")}
              </span>
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # ── Micro-components ─────────────────────────────────────────────────────

  attr :status, :string, default: nil

  defp coll_status_badge(assigns) do
    ~H"""
    <span class={[
      "shrink-0 text-xs font-medium px-2 py-0.5 rounded-full",
      case @status do
        "published" -> "bg-green-100 dark:bg-green-900/40 text-green-700 dark:text-green-300"
        "draft" -> "bg-gray-100 dark:bg-gray-700 text-gray-500 dark:text-gray-400"
        "pending" -> "bg-yellow-100 dark:bg-yellow-900/40 text-yellow-700 dark:text-yellow-300"
        "archived" -> "bg-gray-100 dark:bg-gray-700 text-gray-400"
        _ -> "bg-gray-100 dark:bg-gray-700 text-gray-400"
      end
    ]}>
      {String.capitalize(@status || "—")}
    </span>
    """
  end

  attr :availability, :string, default: nil

  defp avail_badge(assigns) do
    ~H"""
    <span class={[
      "shrink-0 text-xs font-semibold px-2.5 py-0.5 rounded-full",
      case @availability do
        "available" -> "bg-green-100 dark:bg-green-900/40 text-green-700 dark:text-green-300"
        "checked_out" -> "bg-red-100 dark:bg-red-900/40 text-red-600 dark:text-red-300"
        "reserved" -> "bg-amber-100 dark:bg-amber-900/40 text-amber-700 dark:text-amber-300"
        "reference" -> "bg-blue-100 dark:bg-blue-900/40 text-blue-600 dark:text-blue-300"
        "damaged" -> "bg-red-100 dark:bg-red-900/40 text-red-600 dark:text-red-300"
        "lost" -> "bg-red-100 dark:bg-red-900/40 text-red-600 dark:text-red-300"
        _ -> "bg-gray-100 dark:bg-gray-700 text-gray-500"
      end
    ]}>
      {String.replace(String.capitalize(@availability || "Unknown"), "_", " ")}
    </span>
    """
  end

  attr :condition, :string, default: nil

  defp cond_badge(assigns) do
    ~H"""
    <%= if @condition && @condition != "" do %>
      <span class={[
        "text-xs px-2 py-0.5 rounded-full",
        case @condition do
          "excellent" ->
            "bg-emerald-100 dark:bg-emerald-900/40 text-emerald-700 dark:text-emerald-300"

          "good" ->
            "bg-blue-100 dark:bg-blue-900/40 text-blue-600 dark:text-blue-300"

          "fair" ->
            "bg-yellow-100 dark:bg-yellow-900/40 text-yellow-700 dark:text-yellow-300"

          c when c in ["poor", "damaged"] ->
            "bg-red-100 dark:bg-red-900/40 text-red-600 dark:text-red-300"

          _ ->
            "bg-gray-100 dark:bg-gray-700 text-gray-500"
        end
      ]}>
        {String.capitalize(@condition)}
      </span>
    <% end %>
    """
  end

  # ── Pagination ────────────────────────────────────────────────────────────

  attr :p, :map, required: true
  attr :q, :string, required: true
  attr :type, :string, required: true

  defp pager(assigns) do
    ~H"""
    <div class="flex items-center justify-between mt-6 pt-4 border-t border-gray-100 dark:border-gray-700">
      <span class="text-sm text-gray-400 dark:text-gray-500">
        Page {@p.page} / {@p.total_pages}
        <span class="text-gray-300 dark:text-gray-600">({@p.total})</span>
      </span>
      <div class="flex gap-2">
        <.link
          :if={@p.has_prev}
          patch={~p"/search/live?q=#{@q}&type=#{@type}&page=#{@p.page - 1}"}
          class="flex items-center gap-1 px-4 py-2 text-sm font-medium rounded-xl border border-gray-200 dark:border-gray-700 text-gray-600 dark:text-gray-400 hover:bg-gray-50 dark:hover:bg-gray-700 transition-colors"
        >
          <.icon name="hero-chevron-left" class="w-4 h-4" /> Prev
        </.link>
        <.link
          :if={@p.has_next}
          patch={~p"/search/live?q=#{@q}&type=#{@type}&page=#{@p.page + 1}"}
          class="flex items-center gap-1 px-4 py-2 text-sm font-semibold rounded-xl voile-gradient text-white hover:opacity-90 transition-opacity"
        >
          Next <.icon name="hero-chevron-right" class="w-4 h-4" />
        </.link>
      </div>
    </div>
    """
  end

  # ── No results ────────────────────────────────────────────────────────────

  attr :query, :string, required: true

  defp no_results(assigns) do
    ~H"""
    <div class="text-center py-16 bg-white dark:bg-gray-800 rounded-2xl shadow-sm border border-gray-100 dark:border-gray-700">
      <div class="w-16 h-16 mx-auto mb-4 rounded-full bg-gray-100 dark:bg-gray-700 flex items-center justify-center">
        <.icon name="hero-magnifying-glass" class="w-8 h-8 text-gray-300 dark:text-gray-500" />
      </div>
      <h3 class="text-lg font-semibold text-gray-600 dark:text-gray-300 mb-1">
        No results found
      </h3>
      <p class="text-sm text-gray-400 dark:text-gray-500 mb-5">
        Nothing matched <span class="font-medium text-gray-600 dark:text-gray-400">"{@query}"</span>
      </p>
      <ul class="inline-block text-left text-sm text-gray-400 dark:text-gray-500 space-y-1 list-disc list-inside">
        <li>Check spelling or try different keywords</li>
        <li>Search by call number or item/inventory code</li>
        <li>Use the Advanced Search for precise filtering</li>
      </ul>
    </div>
    """
  end

  # ── Helpers ───────────────────────────────────────────────────────────────

  defp get_user_role(socket) do
    current_user = socket.assigns[:current_user]

    cond do
      is_nil(current_user) ->
        "patron"

      Accounts.primary_role(current_user) &&
          Accounts.primary_role(current_user).name in ["librarian", "admin", "superadmin"] ->
        "librarian"

      true ->
        "patron"
    end
  end
end
