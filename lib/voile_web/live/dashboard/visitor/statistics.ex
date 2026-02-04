defmodule VoileWeb.Dashboard.Visitor.Statistics do
  use VoileWeb, :live_view

  alias Voile.Schema.System

  @impl true
  def mount(_params, _session, socket) do
    nodes = System.list_nodes()

    # Default to last 30 days
    from_date = DateTime.utc_now() |> DateTime.add(-30, :day)
    to_date = DateTime.utc_now()

    socket =
      socket
      |> assign(:page_title, "Visitor Statistics")
      |> assign(:nodes, nodes)
      |> assign(:selected_node_id, nil)
      |> assign(:selected_location_id, nil)
      |> assign(:locations, [])
      |> assign(:from_date, from_date |> DateTime.to_date() |> Date.to_string())
      |> assign(:to_date, to_date |> DateTime.to_date() |> Date.to_string())
      |> assign(:statistics, nil)
      |> assign(:loading, false)

    {:ok, socket, temporary_assigns: [statistics: nil]}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    socket = load_statistics(socket)
    {:noreply, socket}
  end

  @impl true
  def handle_event("filter_node", %{"node_id" => ""}, socket) do
    socket =
      socket
      |> assign(:selected_node_id, nil)
      |> assign(:selected_location_id, nil)
      |> assign(:locations, [])
      |> load_statistics()

    {:noreply, socket}
  end

  @impl true
  def handle_event("filter_node", %{"node_id" => node_id}, socket) do
    node_id = String.to_integer(node_id)
    locations = Voile.Schema.Master.list_locations(node_id: node_id)

    socket =
      socket
      |> assign(:selected_node_id, node_id)
      |> assign(:selected_location_id, nil)
      |> assign(:locations, locations)
      |> load_statistics()

    {:noreply, socket}
  end

  @impl true
  def handle_event("filter_location", %{"location_id" => ""}, socket) do
    socket =
      socket
      |> assign(:selected_location_id, nil)
      |> load_statistics()

    {:noreply, socket}
  end

  @impl true
  def handle_event("filter_location", %{"location_id" => location_id}, socket) do
    location_id = String.to_integer(location_id)

    socket =
      socket
      |> assign(:selected_location_id, location_id)
      |> load_statistics()

    {:noreply, socket}
  end

  @impl true
  def handle_event("update_dates", %{"from" => from_date, "to" => to_date}, socket) do
    socket =
      socket
      |> assign(:from_date, from_date)
      |> assign(:to_date, to_date)
      |> load_statistics()

    {:noreply, socket}
  end

  @impl true
  def handle_event("refresh", _params, socket) do
    {:noreply, load_statistics(socket)}
  end

  defp load_statistics(socket) do
    from_date = parse_date(socket.assigns.from_date)
    to_date = parse_date(socket.assigns.to_date)

    opts = [
      from_date: from_date,
      to_date: to_date
    ]

    opts =
      if socket.assigns.selected_node_id do
        Keyword.put(opts, :node_id, socket.assigns.selected_node_id)
      else
        opts
      end

    opts =
      if socket.assigns.selected_location_id do
        Keyword.put(opts, :location_id, socket.assigns.selected_location_id)
      else
        opts
      end

    statistics = System.get_visitor_statistics(opts)

    assign(socket, :statistics, statistics)
  end

  defp parse_date(date_string) when is_binary(date_string) do
    case Date.from_iso8601(date_string) do
      {:ok, date} ->
        DateTime.new!(date, ~T[00:00:00], "Etc/UTC")

      {:error, _} ->
        DateTime.utc_now()
    end
  end

  defp parse_date(_), do: DateTime.utc_now()

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <!-- Header -->
      <div class="flex items-center justify-between">
        <div>
          <h1 class="text-2xl font-bold text-gray-900">Visitor Statistics</h1>
          <p class="text-sm text-gray-600 mt-1">Track and analyze visitor data</p>
        </div>
        <button
          type="button"
          phx-click="refresh"
          class="px-4 py-2 bg-blue-600 hover:bg-blue-700 text-white rounded-lg flex items-center"
        >
          <.icon name="hero-arrow-path" class="w-5 h-5 mr-2" /> Refresh
        </button>
      </div>
      
    <!-- Filters -->
      <div class="bg-white rounded-lg shadow p-6">
        <h2 class="text-lg font-semibold text-gray-900 mb-4">Filters</h2>
        <div class="grid grid-cols-1 md:grid-cols-4 gap-4">
          <!-- Date Range -->
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">From Date</label>
            <input
              type="date"
              value={@from_date}
              phx-change="update_dates"
              phx-value-from={@from_date}
              phx-value-to={@to_date}
              class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500"
            />
          </div>

          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">To Date</label>
            <input
              type="date"
              value={@to_date}
              phx-change="update_dates"
              phx-value-from={@from_date}
              phx-value-to={@to_date}
              class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500"
            />
          </div>
          
    <!-- Node Filter -->
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Location</label>
            <select
              phx-change="filter_node"
              class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500"
            >
              <option value="">All Locations</option>
              <option
                :for={node <- @nodes}
                value={node.id}
                selected={@selected_node_id == node.id}
              >
                {node.name}
              </option>
            </select>
          </div>
          
    <!-- Location/Room Filter -->
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Room</label>
            <select
              phx-change="filter_location"
              class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500"
              disabled={@locations == []}
            >
              <option value="">All Rooms</option>
              <option
                :for={location <- @locations}
                value={location.id}
                selected={@selected_location_id == location.id}
              >
                {location.location_name}
              </option>
            </select>
          </div>
        </div>
      </div>

      <%= if @statistics do %>
        <!-- Summary Cards -->
        <div class="grid grid-cols-1 md:grid-cols-3 gap-6">
          <!-- Total Visitors -->
          <div class="bg-white rounded-lg shadow p-6">
            <div class="flex items-center justify-between">
              <div>
                <p class="text-sm font-medium text-gray-600">Total Visitors</p>
                <p class="text-3xl font-bold text-gray-900 mt-2">
                  {format_number(@statistics.total_visitors)}
                </p>
              </div>
              <div class="p-3 bg-blue-100 rounded-lg">
                <.icon name="hero-user-group" class="w-8 h-8 text-blue-600" />
              </div>
            </div>
          </div>
          
    <!-- Unique Visitors -->
          <div class="bg-white rounded-lg shadow p-6">
            <div class="flex items-center justify-between">
              <div>
                <p class="text-sm font-medium text-gray-600">Unique Visitors</p>
                <p class="text-3xl font-bold text-gray-900 mt-2">
                  {format_number(@statistics.unique_visitors)}
                </p>
              </div>
              <div class="p-3 bg-green-100 rounded-lg">
                <.icon name="hero-users" class="w-8 h-8 text-green-600" />
              </div>
            </div>
          </div>
          
    <!-- Average Rating -->
          <div class="bg-white rounded-lg shadow p-6">
            <div class="flex items-center justify-between">
              <div>
                <p class="text-sm font-medium text-gray-600">Average Rating</p>
                <p class="text-3xl font-bold text-gray-900 mt-2">
                  {@statistics.surveys.average_rating} / 5
                </p>
                <p class="text-xs text-gray-500 mt-1">
                  {format_number(@statistics.surveys.total)} surveys
                </p>
              </div>
              <div class="p-3 bg-yellow-100 rounded-lg">
                <.icon name="hero-star" class="w-8 h-8 text-yellow-600" />
              </div>
            </div>
          </div>
        </div>
        
    <!-- Visitors by Room -->
        <%= if @statistics.by_room != [] do %>
          <div class="bg-white rounded-lg shadow p-6">
            <h2 class="text-lg font-semibold text-gray-900 mb-4">Visitors by Room</h2>
            <div class="space-y-3">
              <div
                :for={room_stat <- @statistics.by_room}
                class="flex items-center justify-between p-3 bg-gray-50 rounded-lg"
              >
                <span class="font-medium text-gray-700">{room_stat.room_name}</span>
                <span class="text-lg font-bold text-blue-600">
                  {format_number(room_stat.count)}
                </span>
              </div>
            </div>
          </div>
        <% end %>
        
    <!-- Visitors by Origin -->
        <%= if @statistics.by_origin != [] do %>
          <div class="bg-white rounded-lg shadow p-6">
            <h2 class="text-lg font-semibold text-gray-900 mb-4">Visitors by Origin</h2>
            <div class="space-y-3">
              <div
                :for={origin_stat <- @statistics.by_origin}
                class="flex items-center justify-between p-3 bg-gray-50 rounded-lg"
              >
                <span class="font-medium text-gray-700">{origin_stat.origin}</span>
                <span class="text-lg font-bold text-green-600">
                  {format_number(origin_stat.count)}
                </span>
              </div>
            </div>
          </div>
        <% end %>
        
    <!-- Rating Distribution -->
        <%= if @statistics.surveys.distribution != [] do %>
          <div class="bg-white rounded-lg shadow p-6">
            <h2 class="text-lg font-semibold text-gray-900 mb-4">Rating Distribution</h2>
            <div class="space-y-3">
              <div
                :for={rating_stat <- @statistics.surveys.distribution}
                class="flex items-center space-x-4"
              >
                <div class="flex items-center space-x-1">
                  <%= for _i <- 1..rating_stat.rating do %>
                    <.icon name="hero-star" class="w-5 h-5 text-yellow-400" />
                  <% end %>
                </div>
                <div class="flex-1">
                  <div class="w-full bg-gray-200 rounded-full h-4">
                    <div
                      class="bg-yellow-400 h-4 rounded-full"
                      style={"width: #{calculate_percentage(rating_stat.count, @statistics.surveys.total)}%"}
                    >
                    </div>
                  </div>
                </div>
                <span class="text-sm font-semibold text-gray-700 w-16 text-right">
                  {format_number(rating_stat.count)}
                </span>
              </div>
            </div>
          </div>
        <% end %>
        
    <!-- Daily Trend -->
        <%= if @statistics.daily_trend != [] do %>
          <div class="bg-white rounded-lg shadow p-6">
            <h2 class="text-lg font-semibold text-gray-900 mb-4">Daily Visitor Trend</h2>
            <div class="overflow-x-auto">
              <table class="min-w-full divide-y divide-gray-200">
                <thead>
                  <tr>
                    <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Date
                    </th>
                    <th class="px-4 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Visitors
                    </th>
                  </tr>
                </thead>
                <tbody class="bg-white divide-y divide-gray-200">
                  <tr :for={day <- @statistics.daily_trend}>
                    <td class="px-4 py-3 whitespace-nowrap text-sm text-gray-900">
                      {day.date}
                    </td>
                    <td class="px-4 py-3 whitespace-nowrap text-sm text-gray-900 text-right font-semibold">
                      {format_number(day.count)}
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>
        <% end %>
      <% else %>
        <div class="bg-white rounded-lg shadow p-8 text-center">
          <p class="text-gray-600">Loading statistics...</p>
        </div>
      <% end %>
    </div>
    """
  end

  defp calculate_percentage(_count, 0), do: 0

  defp calculate_percentage(count, total) do
    (count / total * 100) |> Float.round(1)
  end

  defp format_number(number) when is_integer(number) do
    number
    |> Integer.to_string()
    |> String.graphemes()
    |> Enum.reverse()
    |> Enum.chunk_every(3)
    |> Enum.join(",")
    |> String.reverse()
  end

  defp format_number(number), do: to_string(number)
end
