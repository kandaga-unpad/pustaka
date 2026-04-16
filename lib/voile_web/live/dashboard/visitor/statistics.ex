defmodule VoileWeb.Dashboard.Visitor.Statistics do
  use VoileWeb, :live_view_dashboard

  alias Voile.Schema.System
  alias VoileWeb.Auth.Authorization

  @per_page 5

  @impl true
  def mount(_params, _session, socket) do
    nodes = System.list_nodes()
    current_user = socket.assigns.current_scope.user
    is_super_admin = Authorization.is_super_admin?(current_user)

    # For non-super admins, auto-select their node
    selected_node_id =
      if is_super_admin do
        nil
      else
        current_user.node_id
      end

    socket =
      socket
      |> assign(:page_title, "Visitor Statistics")
      |> assign(:nodes, nodes)
      |> assign(:is_super_admin, is_super_admin)
      |> assign(:selected_node_id, selected_node_id)
      |> assign(:selected_date, Date.utc_today())
      |> assign(:selected_month, Date.utc_today())
      |> assign(:selected_year, Date.utc_today().year)
      |> assign(:today_stats, nil)
      |> assign(:month_stats, nil)
      |> assign(:year_stats, nil)
      # pagination state for today & month tables
      |> assign(:today_page, 1)
      |> assign(:month_page, 1)
      |> assign(:today_pagination, %{})
      |> assign(:month_pagination, %{})
      |> assign(:today_displayed_rooms, [])
      |> assign(:month_displayed_rooms, [])
      |> assign(:loading, false)

    {:ok, socket}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    socket = load_all_statistics(socket)
    {:noreply, socket}
  end

  @impl true
  def handle_event("filter_node", %{"node_id" => ""}, socket) do
    # Only super admins can change node filter
    if socket.assigns.is_super_admin do
      socket =
        socket
        |> assign(:selected_node_id, nil)
        |> load_all_statistics()

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("filter_node", %{"node_id" => node_id}, socket) do
    # Only super admins can change node filter
    if socket.assigns.is_super_admin do
      node_id = String.to_integer(node_id)
      IO.inspect(node_id, label: "Selected node_id")

      socket =
        socket
        |> assign(:selected_node_id, node_id)
        |> load_all_statistics()

      IO.inspect(socket.assigns.today_stats, label: "Today stats after load")
      IO.inspect(socket.assigns.month_stats, label: "Month stats after load")

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("update_date", %{"value" => date_string}, socket) do
    case Date.from_iso8601(date_string) do
      {:ok, date} ->
        socket =
          socket
          |> assign(:selected_date, date)
          |> load_all_statistics()

        {:noreply, socket}

      {:error, _} ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("update_month", %{"value" => month_string}, socket) do
    case Date.from_iso8601(month_string <> "-01") do
      {:ok, date} ->
        socket =
          socket
          |> assign(:selected_month, date)
          |> load_all_statistics()

        {:noreply, socket}

      {:error, _} ->
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
          |> load_all_statistics()

        {:noreply, socket}

      _ ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("refresh", _params, socket) do
    {:noreply, load_all_statistics(socket)}
  end

  @impl true
  def handle_event("paginate_today", %{"page" => page}, socket) do
    page = String.to_integer(page)
    pagination = paginate_list(socket.assigns.today_stats.by_room, page, @per_page)

    socket =
      socket
      |> assign(:today_page, pagination.page)
      |> assign(:today_pagination, pagination)
      |> assign(:today_displayed_rooms, pagination.items)

    {:noreply, socket}
  end

  @impl true
  def handle_event("paginate_month", %{"page" => page}, socket) do
    page = String.to_integer(page)
    pagination = paginate_list(socket.assigns.month_stats.by_room, page, @per_page)

    socket =
      socket
      |> assign(:month_page, pagination.page)
      |> assign(:month_pagination, pagination)
      |> assign(:month_displayed_rooms, pagination.items)

    {:noreply, socket}
  end

  defp load_all_statistics(socket) do
    socket
    |> assign(:today_page, 1)
    |> assign(:month_page, 1)
    |> load_today_statistics()
    |> load_month_statistics()
    |> load_year_statistics()
  end

  defp load_today_statistics(socket) do
    date = socket.assigns.selected_date
    node_id = socket.assigns.selected_node_id
    page = socket.assigns.today_page || 1

    IO.inspect(%{date: date, node_id: node_id}, label: "load_today_statistics params")

    from_datetime = DateTime.new!(date, ~T[00:00:00], "Etc/UTC")
    to_datetime = DateTime.new!(date, ~T[23:59:59], "Etc/UTC")

    opts = [from_date: from_datetime, to_date: to_datetime]
    opts = if node_id, do: Keyword.put(opts, :node_id, node_id), else: opts

    IO.inspect(opts, label: "Calling get_visitor_statistics with opts")

    stats = System.get_visitor_statistics(opts)

    IO.inspect(stats.total_visitors, label: "Total visitors returned")

    # build pagination for rooms
    pagination = paginate_list(stats.by_room, page, @per_page)

    socket
    |> assign(:today_stats, stats)
    |> assign(:today_page, pagination.page)
    |> assign(:today_pagination, pagination)
    |> assign(:today_displayed_rooms, pagination.items)
  end

  defp load_month_statistics(socket) do
    date = socket.assigns.selected_month
    node_id = socket.assigns.selected_node_id

    IO.inspect(%{month: date, node_id: node_id}, label: "load_month_statistics params")

    first_day = Date.beginning_of_month(date)
    last_day = Date.end_of_month(date)

    from_datetime = DateTime.new!(first_day, ~T[00:00:00], "Etc/UTC")
    to_datetime = DateTime.new!(last_day, ~T[23:59:59], "Etc/UTC")

    opts = [from_date: from_datetime, to_date: to_datetime]
    opts = if node_id, do: Keyword.put(opts, :node_id, node_id), else: opts

    IO.inspect(opts, label: "Month stats opts")

    stats = System.get_visitor_statistics(opts)

    IO.inspect(stats.total_visitors, label: "Month total visitors returned")

    # pagination
    pagination = paginate_list(stats.by_room, socket.assigns.month_page || 1, @per_page)

    socket
    |> assign(:month_stats, stats)
    |> assign(:month_pagination, pagination)
    |> assign(:month_page, pagination.page)
    |> assign(:month_displayed_rooms, pagination.items)
  end

  defp load_year_statistics(socket) do
    year = socket.assigns.selected_year
    node_id = socket.assigns.selected_node_id

    # Get visitor count for each month of the year
    monthly_data =
      Enum.map(1..12, fn month ->
        first_day = Date.new!(year, month, 1)
        last_day = Date.end_of_month(first_day)

        from_datetime = DateTime.new!(first_day, ~T[00:00:00], "Etc/UTC")
        to_datetime = DateTime.new!(last_day, ~T[23:59:59], "Etc/UTC")

        opts = [from_date: from_datetime, to_date: to_datetime]
        opts = if node_id, do: Keyword.put(opts, :node_id, node_id), else: opts

        stats = System.get_visitor_statistics(opts)

        %{
          month: month,
          month_name: month_name(month),
          count: stats.total_visitors
        }
      end)

    assign(socket, :year_stats, monthly_data)
  end

  defp month_name(1), do: "January"
  defp month_name(2), do: "February"
  defp month_name(3), do: "March"
  defp month_name(4), do: "April"
  defp month_name(5), do: "May"
  defp month_name(6), do: "June"
  defp month_name(7), do: "July"
  defp month_name(8), do: "August"
  defp month_name(9), do: "September"
  defp month_name(10), do: "October"
  defp month_name(11), do: "November"
  defp month_name(12), do: "December"

  # generic paginator for simple lists
  defp paginate_list(list, page, per_page) do
    total_count = Enum.count(list)
    total_pages = if total_count > 0, do: Float.ceil(total_count / per_page) |> trunc(), else: 0
    page = max(min(page, total_pages), 1)
    offset = (page - 1) * per_page
    items = Enum.slice(list, offset, per_page)

    %{
      items: items,
      page: page,
      per_page: per_page,
      total_count: total_count,
      total_pages: total_pages,
      has_prev: page > 1,
      has_next: page < total_pages
    }
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <!-- Header -->
      <div>
        <h1 class="text-2xl font-bold text-gray-900 dark:text-white">
          {gettext("Visitor Data")}
        </h1>
        <p class="text-sm text-gray-600 dark:text-gray-400 mt-1">
          {gettext("Visitor data recap to the library")}
        </p>
      </div>

      <div class="mb-4">
        <.back navigate="/manage/glam">{gettext("Back to GLAM")}</.back>
      </div>
      
    <!-- Quick Links -->
      <div class="bg-white dark:bg-gray-800 rounded-lg shadow p-6">
        <h2 class="text-lg font-semibold text-gray-900 dark:text-white mb-4">
          {gettext("Quick Links")}
        </h2>
        <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
          <.link
            navigate="/manage/visitor/logs"
            class="flex items-center p-4 border-2 border-gray-200 dark:border-gray-600 rounded-lg hover:border-blue-500 dark:hover:border-blue-400 hover:bg-blue-50 dark:hover:bg-blue-900/30 transition-all"
          >
            <div class="p-3 bg-blue-100 dark:bg-blue-900/30 rounded-lg mr-4">
              <.icon
                name="hero-clipboard-document-list"
                class="w-6 h-6 text-blue-600 dark:text-blue-400"
              />
            </div>
            <div>
              <h3 class="font-semibold text-gray-900 dark:text-white">
                {gettext("Visitor Check-In Logs")}
              </h3>
              <p class="text-sm text-gray-600 dark:text-gray-400">
                {gettext("View detailed visitor check-in records")}
              </p>
            </div>
          </.link>

          <.link
            navigate="/manage/visitor/surveys"
            class="flex items-center p-4 border-2 border-gray-200 dark:border-gray-600 rounded-lg hover:border-blue-500 dark:hover:border-blue-400 hover:bg-blue-50 dark:hover:bg-blue-900/30 transition-all"
          >
            <div class="p-3 bg-purple-100 dark:bg-purple-900/30 rounded-lg mr-4">
              <.icon
                name="hero-chat-bubble-left-right"
                class="w-6 h-6 text-purple-600 dark:text-purple-400"
              />
            </div>
            <div>
              <h3 class="font-semibold text-gray-900 dark:text-white">
                {gettext("Survey Feedback Logs")}
              </h3>
              <p class="text-sm text-gray-600 dark:text-gray-400">
                {gettext("View detailed survey feedback records")}
              </p>
            </div>
          </.link>

          <.link
            navigate="/manage/visitor/statistics/node"
            class="flex items-center p-4 border-2 border-gray-200 dark:border-gray-600 rounded-lg hover:border-blue-500 dark:hover:border-blue-400 hover:bg-blue-50 dark:hover:bg-blue-900/30 transition-all"
          >
            <div class="p-3 bg-green-100 dark:bg-green-900/30 rounded-lg mr-4">
              <.icon
                name="hero-building-library"
                class="w-6 h-6 text-green-600 dark:text-green-400"
              />
            </div>
            <div>
              <h3 class="font-semibold text-gray-900 dark:text-white">
                {gettext("Statistics by Location")}
              </h3>
              <p class="text-sm text-gray-600 dark:text-gray-400">
                {gettext("Monthly visitor totals by location")}
              </p>
            </div>
          </.link>
        </div>
      </div>
      
    <!-- Filters -->
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
        <div class="grid grid-cols-1 md:grid-cols-4 gap-4">
          <!-- Node Filter -->
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
                {Enum.find(@nodes, fn n -> n.id == @selected_node_id end)
                |> then(fn n -> n && n.name end) || gettext("Your Location")}
              </div>
            </div>
          <% end %>

          <form phx-change="update_date">
            <div>
              <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                {gettext("Date")}
              </label>
              <input
                type="date"
                name="value"
                value={Date.to_string(@selected_date)}
                class="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 dark:bg-gray-700 dark:text-white rounded-lg focus:ring-2 focus:ring-blue-500 dark:focus:ring-blue-400"
              />
            </div>
          </form>

          <form phx-change="update_month">
            <div>
              <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                {gettext("Month")}
              </label>
              <input
                type="month"
                name="value"
                value={
                  "#{@selected_month.year}-#{String.pad_leading(to_string(@selected_month.month), 2, "0")}"
                }
                class="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 dark:bg-gray-700 dark:text-white rounded-lg focus:ring-2 focus:ring-blue-500 dark:focus:ring-blue-400"
              />
            </div>
          </form>

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
                max="2030"
                class="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 dark:bg-gray-700 dark:text-white rounded-lg focus:ring-2 focus:ring-blue-500 dark:focus:ring-blue-400"
              />
            </div>
          </form>
        </div>
        
    <!-- Selected Filter Display -->
        <%= if @selected_node_id do %>
          <div class="mt-4 p-3 bg-blue-50 dark:bg-blue-900/20 border border-blue-200 dark:border-blue-800 rounded-lg">
            <p class="text-sm text-blue-800 dark:text-blue-300">
              <span class="font-medium">
                {if @is_super_admin, do: gettext("Filtering by:"), else: gettext("Showing data for:")}
              </span>
              {Enum.find(@nodes, fn n -> n.id == @selected_node_id end)
              |> then(fn n -> n && n.name end) || gettext("Your Location")}
            </p>
          </div>
        <% end %>
      </div>
      
    <!-- Today's Visitors -->
      <%= if @today_stats do %>
        <div class="bg-white dark:bg-gray-800 rounded-lg shadow p-6">
          <h2 class="text-xl font-semibold text-gray-900 dark:text-white mb-4">
            {gettext("Today's Visitor Data")}
          </h2>
          <p class="text-sm text-gray-600 dark:text-gray-400 mb-4">
            {Calendar.strftime(@selected_date, "%B %-d, %Y")}
          </p>

          <%= if @today_stats.by_room != [] do %>
            <div class="space-y-2 mb-4">
              <div
                :for={room <- @today_displayed_rooms}
                class="flex items-center justify-between p-3 bg-gray-50 dark:bg-gray-700 rounded-lg"
              >
                <span class="font-medium text-gray-700 dark:text-gray-300">{room.room_name}</span>
                <div class="flex items-center gap-2">
                  <span class="text-2xl font-bold text-blue-600 dark:text-blue-400">
                    {format_number(room.count)}
                  </span>
                  <span class="text-sm text-gray-500 dark:text-gray-400">{gettext("visitors")}</span>
                </div>
              </div>
            </div>

            <%= if @today_pagination.total_pages > 1 do %>
              <div class="flex items-center justify-between mt-2 pt-2 border-t border-gray-200 dark:border-gray-700">
                <div class="text-sm text-gray-700 dark:text-gray-300">
                  Page {@today_pagination.page} of {@today_pagination.total_pages}
                </div>
                <div class="flex gap-2">
                  <button
                    :if={@today_pagination.has_prev}
                    phx-click="paginate_today"
                    phx-value-page={@today_pagination.page - 1}
                    class="px-3 py-2 text-sm font-medium text-gray-700 dark:text-gray-300 bg-white dark:bg-gray-700 border border-gray-300 dark:border-gray-600 rounded-md hover:bg-gray-50 dark:hover:bg-gray-600"
                  >
                    Previous
                  </button>
                  <button
                    :if={@today_pagination.has_next}
                    phx-click="paginate_today"
                    phx-value-page={@today_pagination.page + 1}
                    class="px-3 py-2 text-sm font-medium text-gray-700 dark:text-gray-300 bg-white dark:bg-gray-700 border border-gray-300 dark:border-gray-600 rounded-md hover:bg-gray-50 dark:hover:bg-gray-600"
                  >
                    Next
                  </button>
                </div>
              </div>
            <% end %>
          <% else %>
            <div class="p-8 text-center bg-gray-50 dark:bg-gray-700 rounded-lg">
              <.icon
                name="hero-users"
                class="w-12 h-12 mx-auto text-gray-400 dark:text-gray-500 mb-2"
              />
              <p class="text-gray-600 dark:text-gray-400">
                {gettext("No visitor data for selected filters")}
              </p>
            </div>
          <% end %>

          <div class="pt-4 border-t border-gray-200 dark:border-gray-700">
            <div class="flex items-center justify-between">
              <span class="text-lg font-semibold text-gray-700 dark:text-gray-300">
                {gettext("Total Visitors Today")}
              </span>
              <div class="flex items-center gap-2">
                <span class="text-3xl font-bold text-green-600 dark:text-green-400">
                  {format_number(@today_stats.total_visitors)}
                </span>
                <span class="text-sm text-gray-500 dark:text-gray-400">{gettext("visitors")}</span>
              </div>
            </div>
          </div>
        </div>
      <% end %>
      
    <!-- This Month's Visitors -->
      <%= if @month_stats do %>
        <div class="bg-white dark:bg-gray-800 rounded-lg shadow p-6">
          <h2 class="text-xl font-semibold text-gray-900 dark:text-white mb-4">
            {gettext("This Month's Visitor Data")}
          </h2>
          <p class="text-sm text-gray-600 dark:text-gray-400 mb-4">
            {Calendar.strftime(@selected_month, "%B %Y")}
          </p>

          <%= if @month_stats.by_room != [] do %>
            <div class="space-y-2 mb-4">
              <div
                :for={room <- @month_displayed_rooms}
                class="flex items-center justify-between p-3 bg-gray-50 dark:bg-gray-700 rounded-lg"
              >
                <span class="font-medium text-gray-700 dark:text-gray-300">{room.room_name}</span>
                <div class="flex items-center gap-2">
                  <span class="text-2xl font-bold text-blue-600 dark:text-blue-400">
                    {format_number(room.count)}
                  </span>
                  <span class="text-sm text-gray-500 dark:text-gray-400">{gettext("visitors")}</span>
                </div>
              </div>
            </div>

            <%= if @month_pagination.total_pages > 1 do %>
              <div class="flex items-center justify-between mt-2 pt-2 border-t border-gray-200 dark:border-gray-700">
                <div class="text-sm text-gray-700 dark:text-gray-300">
                  Page {@month_pagination.page} of {@month_pagination.total_pages}
                </div>
                <div class="flex gap-2">
                  <button
                    :if={@month_pagination.has_prev}
                    phx-click="paginate_month"
                    phx-value-page={@month_pagination.page - 1}
                    class="px-3 py-2 text-sm font-medium text-gray-700 dark:text-gray-300 bg-white dark:bg-gray-700 border border-gray-300 dark:border-gray-600 rounded-md hover:bg-gray-50 dark:hover:bg-gray-600"
                  >
                    Previous
                  </button>
                  <button
                    :if={@month_pagination.has_next}
                    phx-click="paginate_month"
                    phx-value-page={@month_pagination.page + 1}
                    class="px-3 py-2 text-sm font-medium text-gray-700 dark:text-gray-300 bg-white dark:bg-gray-700 border border-gray-300 dark:border-gray-600 rounded-md hover:bg-gray-50 dark:hover:bg-gray-600"
                  >
                    Next
                  </button>
                </div>
              </div>
            <% end %>
          <% else %>
            <div class="p-8 text-center bg-gray-50 dark:bg-gray-700 rounded-lg">
              <.icon
                name="hero-users"
                class="w-12 h-12 mx-auto text-gray-400 dark:text-gray-500 mb-2"
              />
              <p class="text-gray-600 dark:text-gray-400">
                {gettext("No visitor data for selected filters")}
              </p>
            </div>
          <% end %>

          <div class="pt-4 border-t border-gray-200 dark:border-gray-700">
            <div class="flex items-center justify-between">
              <span class="text-lg font-semibold text-gray-700 dark:text-gray-300">
                {gettext("Total Visitors This Month")}
              </span>
              <div class="flex items-center gap-2">
                <span class="text-3xl font-bold text-green-600 dark:text-green-400">
                  {format_number(@month_stats.total_visitors)}
                </span>
                <span class="text-sm text-gray-500 dark:text-gray-400">{gettext("visitors")}</span>
              </div>
            </div>
          </div>
        </div>
      <% end %>
      
    <!-- Yearly Statistics -->
      <%= if @year_stats do %>
        <div class="bg-white dark:bg-gray-800 rounded-lg shadow p-6">
          <h2 class="text-xl font-semibold text-gray-900 dark:text-white mb-4">
            {gettext("Monthly Visitor Data for %{year}", year: @selected_year)}
          </h2>

          <div class="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4">
            <div
              :for={month_data <- @year_stats}
              class="p-4 bg-gray-50 dark:bg-gray-700 rounded-lg text-center"
            >
              <div class="text-sm font-medium text-gray-600 dark:text-gray-400 mb-2">
                {month_data.month_name}
              </div>
              <div class="text-2xl font-bold text-blue-600 dark:text-blue-400">
                {format_number(month_data.count)}
              </div>
            </div>
          </div>
        </div>
      <% end %>
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
