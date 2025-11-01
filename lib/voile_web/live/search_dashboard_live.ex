defmodule VoileWeb.SearchDashboardLive do
  @moduledoc """
  LiveView for search dashboard with real-time analytics
  """
  use VoileWeb, :live_view

  alias Voile.Analytics.SearchAnalytics

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      # Subscribe to search updates (could be implemented with PubSub later)
      :timer.send_interval(30_000, self(), :refresh_stats)
    end

    socket =
      socket
      |> assign(:search_stats, SearchAnalytics.get_search_stats())
      |> assign(:popular_searches, SearchAnalytics.get_popular_searches())
      |> assign(:search_trends, SearchAnalytics.get_search_trends())

    {:ok, socket}
  end

  @impl true
  def handle_info(:refresh_stats, socket) do
    socket =
      socket
      |> assign(:search_stats, SearchAnalytics.get_search_stats())
      |> assign(:popular_searches, SearchAnalytics.get_popular_searches())

    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-6 space-y-6">
      <!-- Page Header -->
      <div class="flex items-center justify-between">
        <div>
          <h1 class="text-2xl font-bold text-gray-900 dark:text-white">Search Dashboard</h1>
          
          <p class="text-gray-600 dark:text-gray-300">Monitor search activity and trends</p>
        </div>
        
        <.link
          href="/search"
          class="inline-flex items-center px-4 py-2 border border-transparent rounded-md shadow-sm text-sm font-medium text-voile-surface bg-voile-primary hover:bg-voile-primary/80 dark:bg-voile-primary dark:hover:bg-voile-primary/80"
        >
          <.icon name="hero-magnifying-glass" class="w-4 h-4 mr-2" /> New Search
        </.link>
      </div>
      <!-- Search Statistics Grid -->
      <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <!-- Search Stats Widget -->
        <.search_stats_widget stats={@search_stats} />
        <!-- Quick Search Widget -->
        <.dashboard_search_widget />
        <!-- Popular Searches -->
        <div class="bg-white dark:bg-gray-700 rounded-xl p-5">
          <div class="flex items-center gap-3 mb-4">
            <.icon name="hero-fire" class="w-6 h-6 text-red-600 dark:text-red-400" />
            <h3 class="text-lg font-semibold text-gray-900 dark:text-white">Trending Searches</h3>
          </div>
          
          <div class="space-y-3">
            <%= for {query, count} <- Enum.take(@popular_searches, 5) do %>
              <div class="flex items-center justify-between">
                <.link
                  href={"/search?q=#{URI.encode_www_form(query)}"}
                  class="text-sm text-voile-info dark:text-voile-info/60 hover:text-voile-info/80 dark:hover:text-voile-info/80 truncate"
                >
                  {query}
                </.link>
                <span class="text-xs text-gray-500 dark:text-gray-400 bg-gray-100 dark:bg-gray-600 px-2 py-1 rounded">
                  {count}
                </span>
              </div>
            <% end %>
            
            <%= if length(@popular_searches) == 0 do %>
              <p class="text-sm text-gray-500 dark:text-gray-400 italic">No searches yet today</p>
            <% end %>
          </div>
        </div>
      </div>
      <!-- Search Trends Chart (placeholder) -->
      <div class="bg-white dark:bg-gray-700 rounded-xl p-6">
        <div class="flex items-center gap-3 mb-4">
          <.icon name="hero-chart-bar" class="w-6 h-6 text-green-600 dark:text-green-400" />
          <h3 class="text-lg font-semibold text-gray-900 dark:text-white">Search Activity by Hour</h3>
        </div>
        
        <div class="grid grid-cols-12 gap-2 h-32">
          <%= for hour <- 0..23 do %>
            <div class="flex flex-col items-center justify-end">
              <div
                class="bg-voile-info/10 dark:bg-voile-info/30 rounded-t w-full"
                style={"height: #{get_hour_percentage(@search_trends, hour)}%"}
              >
              </div>
               <span class="text-xs text-gray-500 dark:text-gray-400 mt-1">{hour}</span>
            </div>
          <% end %>
        </div>
        
        <div class="mt-4 text-sm text-gray-600 dark:text-gray-300">
          <p>Peak search hours: {get_peak_hours(@search_trends)}</p>
        </div>
      </div>
      <!-- Recent Search Activity -->
      <div class="bg-white dark:bg-gray-700 rounded-xl p-6">
        <div class="flex items-center gap-3 mb-4">
          <.icon name="hero-clock" class="w-6 h-6 text-voile-primary dark:text-voile-primary" />
          <h3 class="text-lg font-semibold text-gray-900 dark:text-white">Recent Activity</h3>
        </div>
        
        <div class="space-y-2">
          <%= for activity <- @search_stats.recent_activity do %>
            <div class="text-sm text-gray-600 dark:text-gray-300 py-1">{activity}</div>
          <% end %>
          
          <%= if length(@search_stats.recent_activity) == 0 do %>
            <p class="text-sm text-gray-500 dark:text-gray-400 italic">No recent search activity</p>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  # Helper functions

  defp get_hour_percentage(trends, hour) do
    max_count = trends |> Map.values() |> Enum.max(fn -> 1 end)
    current_count = Map.get(trends, hour, 0)

    if max_count > 0 do
      trunc(current_count / max_count * 100)
    else
      0
    end
  end

  defp get_peak_hours(trends) do
    if map_size(trends) == 0 do
      "No data available"
    else
      max_count = trends |> Map.values() |> Enum.max()

      peak_hours =
        trends
        |> Enum.filter(fn {_hour, count} -> count == max_count end)
        |> Enum.map(fn {hour, _count} -> "#{hour}:00" end)
        |> Enum.join(", ")

      peak_hours
    end
  end
end
