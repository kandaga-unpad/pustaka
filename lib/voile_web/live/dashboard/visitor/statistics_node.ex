defmodule VoileWeb.Dashboard.Visitor.StatisticsNode do
  use VoileWeb, :live_view_dashboard

  alias Voile.Schema.System
  alias VoileWeb.Auth.Authorization

  @impl true
  def mount(_params, _session, socket) do
    nodes = System.list_nodes()
    current_user = socket.assigns.current_scope.user
    is_super_admin = Authorization.is_super_admin?(current_user)

    selected_node_id =
      if is_super_admin do
        nil
      else
        current_user.node_id
      end

    socket =
      socket
      |> assign(:page_title, "Visitor Statistics by Location")
      |> assign(:nodes, nodes)
      |> assign(:is_super_admin, is_super_admin)
      |> assign(:selected_node_id, selected_node_id)
      |> assign(:selected_year, Date.utc_today().year)
      |> assign(:node_monthly_stats, [])
      |> assign(:total_monthly_counts, %{})
      |> assign(:year_total, 0)

    {:ok, socket}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    socket = load_yearly_node_statistics(socket)
    {:noreply, socket}
  end

  @impl true
  def handle_event("filter_node", %{"node_id" => ""}, socket) do
    if socket.assigns.is_super_admin do
      socket =
        socket
        |> assign(:selected_node_id, nil)
        |> load_yearly_node_statistics()

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("filter_node", %{"node_id" => node_id}, socket) do
    if socket.assigns.is_super_admin do
      socket =
        socket
        |> assign(:selected_node_id, String.to_integer(node_id))
        |> load_yearly_node_statistics()

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("update_year", %{"value" => year_string}, socket) do
    case Integer.parse(year_string) do
      {year, ""} ->
        socket =
          socket
          |> assign(:selected_year, year)
          |> load_yearly_node_statistics()

        {:noreply, socket}

      _ ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("refresh", _params, socket) do
    {:noreply, load_yearly_node_statistics(socket)}
  end

  defp load_yearly_node_statistics(socket) do
    year = socket.assigns.selected_year
    node_id = socket.assigns.selected_node_id

    opts = if node_id, do: [node_id: node_id], else: []
    stats = System.get_visitor_statistics_by_node_year(year, opts)

    stats_by_node = Enum.group_by(stats, & &1.node_id)

    selected_nodes =
      if node_id do
        Enum.filter(socket.assigns.nodes, fn node -> node.id == node_id end)
      else
        socket.assigns.nodes
      end

    node_monthly_stats =
      Enum.map(selected_nodes, fn node ->
        node_rows = Map.get(stats_by_node, node.id, [])

        month_counts =
          1..12
          |> Enum.map(fn month ->
            {month, Map.get(Map.new(node_rows, fn row -> {row.month, row.count} end), month, 0)}
          end)
          |> Map.new()

        %{
          node_id: node.id,
          node_name: node.name,
          months: month_counts,
          total: Enum.sum(Map.values(month_counts))
        }
      end)

    total_monthly_counts =
      1..12
      |> Enum.map(fn month ->
        {month,
         Enum.reduce(node_monthly_stats, 0, fn stats, acc ->
           acc + Map.get(stats.months, month, 0)
         end)}
      end)
      |> Map.new()

    year_total = Enum.reduce(node_monthly_stats, 0, fn stats, acc -> acc + stats.total end)

    socket
    |> assign(:node_monthly_stats, node_monthly_stats)
    |> assign(:total_monthly_counts, total_monthly_counts)
    |> assign(:year_total, year_total)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <div>
        <h1 class="text-2xl font-bold text-gray-900 dark:text-white">
          {gettext("Location/Faculty Monthly Visitor Summary")}
        </h1>
        <p class="text-sm text-gray-600 dark:text-gray-400 mt-1">
          {gettext("Monthly visitor totals by location for the selected year.")}
        </p>
      </div>

      <div class="mb-4">
        <.back navigate="/manage/visitor/statistics">{gettext("Back to Visitor Statistics")}</.back>
      </div>

      <div class="bg-white dark:bg-gray-800 rounded-lg shadow p-6">
        <div class="flex items-center justify-between mb-4">
          <h2 class="text-lg font-semibold text-gray-900 dark:text-white">{gettext("Filters")}</h2>
          <button
            type="button"
            phx-click="refresh"
            class="px-3 py-1.5 text-sm bg-blue-600 hover:bg-blue-700 dark:bg-blue-700 dark:hover:bg-blue-600 text-white rounded-lg flex items-center"
          >
            <.icon name="hero-arrow-path" class="w-4 h-4 mr-1" /> {gettext("Refresh")}
          </button>
        </div>

        <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
          <%= if @is_super_admin do %>
            <form phx-change="filter_node">
              <div>
                <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                  {gettext("Location/Faculty")}
                </label>
                <select
                  name="node_id"
                  class="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 dark:bg-gray-700 dark:text-white rounded-lg focus:ring-2 focus:ring-blue-500 dark:focus:ring-blue-400"
                >
                  <option value="">{gettext("All Locations")}</option>
                  <option
                    :for={node <- @nodes}
                    value={node.id}
                    selected={@selected_node_id == node.id}
                  >
                    {node.name}
                  </option>
                </select>
              </div>
            </form>
          <% else %>
            <div>
              <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                {gettext("Location/Faculty")}
              </label>
              <div class="w-full px-3 py-2 bg-gray-100 dark:bg-gray-700 text-gray-700 dark:text-gray-300 rounded-lg border border-gray-300 dark:border-gray-600">
                {Enum.find(@nodes, fn node -> node.id == @selected_node_id end)
                |> then(fn node -> node && node.name end) || gettext("Your Location")}
              </div>
            </div>
          <% end %>

          <form phx-change="update_year">
            <div>
              <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                {gettext("Year")}
              </label>
              <input
                type="number"
                name="value"
                value={@selected_year}
                min="2020"
                max={to_string(Date.utc_today().year + 5)}
                class="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 dark:bg-gray-700 dark:text-white rounded-lg focus:ring-2 focus:ring-blue-500 dark:focus:ring-blue-400"
              />
            </div>
          </form>
        </div>
      </div>

      <div class="bg-white dark:bg-gray-800 rounded-lg shadow p-6">
        <div class="flex flex-col gap-2 md:flex-row md:items-center md:justify-between mb-4">
          <div>
            <h2 class="text-xl font-semibold text-gray-900 dark:text-white">
              {gettext("Monthly Visitor Totals")}
            </h2>
            <p class="text-sm text-gray-600 dark:text-gray-400">
              {gettext("Year %{year}", year: @selected_year)}
            </p>
          </div>

          <div class="rounded-lg border border-gray-200 dark:border-gray-700 bg-gray-50 dark:bg-gray-700 px-4 py-3">
            <div class="text-sm text-gray-500 dark:text-gray-400">{gettext("Total visitors")}</div>
            <div class="text-3xl font-bold text-green-600 dark:text-green-400">
              {format_number(@year_total)}
            </div>
          </div>
        </div>

        <div class="overflow-x-auto">
          <table class="min-w-full text-left text-sm text-gray-700 dark:text-gray-200">
            <thead class="border-b border-gray-200 dark:border-gray-700">
              <tr>
                <th class="px-3 py-3 font-medium">{gettext("Location")}</th>
                <th class="px-3 py-3 font-medium">Jan</th>
                <th class="px-3 py-3 font-medium">Feb</th>
                <th class="px-3 py-3 font-medium">Mar</th>
                <th class="px-3 py-3 font-medium">Apr</th>
                <th class="px-3 py-3 font-medium">May</th>
                <th class="px-3 py-3 font-medium">Jun</th>
                <th class="px-3 py-3 font-medium">Jul</th>
                <th class="px-3 py-3 font-medium">Aug</th>
                <th class="px-3 py-3 font-medium">Sep</th>
                <th class="px-3 py-3 font-medium">Oct</th>
                <th class="px-3 py-3 font-medium">Nov</th>
                <th class="px-3 py-3 font-medium">Dec</th>
                <th class="px-3 py-3 font-medium">{gettext("Year")}</th>
              </tr>
            </thead>
            <tbody>
              <%= for stats <- @node_monthly_stats do %>
                <tr class="border-b border-gray-200 dark:border-gray-700">
                  <td class="px-3 py-3 font-medium text-gray-900 dark:text-white">
                    {stats.node_name}
                  </td>
                  <%= for month <- 1..12 do %>
                    <td class="px-3 py-3">{format_number(Map.get(stats.months, month, 0))}</td>
                  <% end %>
                  <td class="px-3 py-3 font-semibold">{format_number(stats.total)}</td>
                </tr>
              <% end %>
            </tbody>
            <tfoot>
              <tr class="border-t border-gray-200 dark:border-gray-700 font-semibold bg-gray-50 dark:bg-gray-900">
                <td class="px-3 py-3">{gettext("Total")}</td>
                <%= for month <- 1..12 do %>
                  <td class="px-3 py-3">{format_number(Map.get(@total_monthly_counts, month, 0))}</td>
                <% end %>
                <td class="px-3 py-3">{format_number(@year_total)}</td>
              </tr>
            </tfoot>
          </table>
        </div>

        <%= if @node_monthly_stats == [] do %>
          <div class="mt-6 p-6 text-center bg-gray-50 dark:bg-gray-700 rounded-lg">
            <.icon name="hero-users" class="w-12 h-12 mx-auto text-gray-400 dark:text-gray-500 mb-2" />
            <p class="text-gray-600 dark:text-gray-400">
              {gettext("No visitor data found for the selected filters.")}
            </p>
          </div>
        <% end %>
      </div>
    </div>
    """
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
