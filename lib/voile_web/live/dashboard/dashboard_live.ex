defmodule VoileWeb.DashboardLive do
  use VoileWeb, :live_view_dashboard
  require Logger

  alias Voile.Analytics.SearchAnalytics
  alias Voile.Schema.Search

  def render(assigns) do
    ~H"""
    <section>
      <h6 class="text-center py-5">Manage your Collection with Voile</h6>
      <!-- Search Dashboard Section -->
      <div class="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-8">
        <.dashboard_search_widget
          search_query={@search_query}
          search_results={@search_results}
          searching={@searching}
        />
        <.search_stats_widget stats={@search_stats} />
      </div>
    </section>
    """
  end

  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:page_title, "Dashboard")
      |> assign(:search_stats, SearchAnalytics.get_search_stats())
      |> assign(:search_query, "")
      |> assign(:search_results, [])
      |> assign(:searching, false)

    {:ok, socket}
  end

  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  def handle_event("search", %{"query" => query}, socket) do
    query = String.trim(query)
    Logger.debug("Dashboard search event: query=#{inspect(query)}")

    if query == "" do
      socket =
        socket
        |> assign(:search_query, "")
        |> assign(:search_results, [])
        |> assign(:searching, false)

      {:noreply, socket}
    else
      send(self(), {:perform_search, query})

      socket =
        socket
        |> assign(:search_query, query)
        |> assign(:searching, true)

      {:noreply, socket}
    end
  end

  def handle_info({:perform_search, query}, socket) do
    Logger.debug("Performing search for: #{inspect(query)}")

    # Perform universal search with limited results for dashboard widget
    results = Search.universal_search(query, %{collections_per_page: 3, items_per_page: 2})

    Logger.debug("Search results: #{inspect(results)}")

    # Combine and flatten results for display
    combined_results =
      (results.collections.results ++ results.items.results)
      |> Enum.take(5)

    Logger.debug("Combined results count: #{length(combined_results)}")

    socket =
      socket
      |> assign(:search_results, combined_results)
      |> assign(:searching, false)

    {:noreply, socket}
  end
end
