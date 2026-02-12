defmodule VoileWeb.Dashboard.Visitor.Surveys do
  use VoileWeb, :live_view_dashboard

  alias Voile.Schema.System
  alias Voile.Schema.Master
  alias VoileWeb.Auth.Authorization

  @per_page 50

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

    # Get locations for the selected node
    locations =
      if selected_node_id do
        Master.list_locations(node_id: selected_node_id, is_active: true)
      else
        []
      end

    socket =
      socket
      |> assign(:page_title, "Survey Feedback")
      |> assign(:nodes, nodes)
      |> assign(:locations, locations)
      |> assign(:is_super_admin, is_super_admin)
      |> assign(:selected_node_id, selected_node_id)
      |> assign(:selected_location_id, nil)
      |> assign(:selected_rating, nil)
      |> assign(:from_date, Date.utc_today() |> Date.add(-7))
      |> assign(:to_date, Date.utc_today())
      |> assign(:page, 1)
      |> assign(:surveys, [])
      |> assign(:total_count, 0)
      |> assign(:total_pages, 0)
      |> assign(:stats, nil)

    {:ok, socket}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    socket =
      socket
      |> load_surveys()
      |> load_stats()

    {:noreply, socket}
  end

  @impl true
  def handle_event("filter_node", %{"node_id" => ""}, socket) do
    if socket.assigns.is_super_admin do
      socket =
        socket
        |> assign(:selected_node_id, nil)
        |> assign(:selected_location_id, nil)
        |> assign(:locations, [])
        |> assign(:page, 1)
        |> load_surveys()
        |> load_stats()

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("filter_node", %{"node_id" => node_id}, socket) do
    if socket.assigns.is_super_admin do
      node_id = String.to_integer(node_id)
      locations = Master.list_locations(node_id: node_id, is_active: true)

      socket =
        socket
        |> assign(:selected_node_id, node_id)
        |> assign(:selected_location_id, nil)
        |> assign(:locations, locations)
        |> assign(:page, 1)
        |> load_surveys()
        |> load_stats()

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("filter_location", %{"location_id" => ""}, socket) do
    socket =
      socket
      |> assign(:selected_location_id, nil)
      |> assign(:page, 1)
      |> load_surveys()
      |> load_stats()

    {:noreply, socket}
  end

  @impl true
  def handle_event("filter_location", %{"location_id" => location_id}, socket) do
    location_id = String.to_integer(location_id)

    socket =
      socket
      |> assign(:selected_location_id, location_id)
      |> assign(:page, 1)
      |> load_surveys()
      |> load_stats()

    {:noreply, socket}
  end

  @impl true
  def handle_event("filter_rating", %{"rating" => ""}, socket) do
    socket =
      socket
      |> assign(:selected_rating, nil)
      |> assign(:page, 1)
      |> load_surveys()

    {:noreply, socket}
  end

  @impl true
  def handle_event("filter_rating", %{"rating" => rating}, socket) do
    rating = String.to_integer(rating)

    socket =
      socket
      |> assign(:selected_rating, rating)
      |> assign(:page, 1)
      |> load_surveys()

    {:noreply, socket}
  end

  @impl true
  def handle_event("update_from_date", %{"value" => date_string}, socket) do
    case Date.from_iso8601(date_string) do
      {:ok, date} ->
        socket =
          socket
          |> assign(:from_date, date)
          |> assign(:page, 1)
          |> load_surveys()
          |> load_stats()

        {:noreply, socket}

      {:error, _} ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("update_to_date", %{"value" => date_string}, socket) do
    case Date.from_iso8601(date_string) do
      {:ok, date} ->
        socket =
          socket
          |> assign(:to_date, date)
          |> assign(:page, 1)
          |> load_surveys()
          |> load_stats()

        {:noreply, socket}

      {:error, _} ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("goto_page", %{"page" => page}, socket) do
    page = String.to_integer(page)

    socket =
      socket
      |> assign(:page, page)
      |> load_surveys()

    {:noreply, socket}
  end

  @impl true
  def handle_event("next_page", _params, socket) do
    if socket.assigns.page < socket.assigns.total_pages do
      socket =
        socket
        |> assign(:page, socket.assigns.page + 1)
        |> load_surveys()

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("prev_page", _params, socket) do
    if socket.assigns.page > 1 do
      socket =
        socket
        |> assign(:page, socket.assigns.page - 1)
        |> load_surveys()

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("refresh", _params, socket) do
    socket =
      socket
      |> load_surveys()
      |> load_stats()

    {:noreply, socket}
  end

  defp load_surveys(socket) do
    from_datetime = DateTime.new!(socket.assigns.from_date, ~T[00:00:00], "Etc/UTC")
    to_datetime = DateTime.new!(socket.assigns.to_date, ~T[23:59:59], "Etc/UTC")

    opts = [
      from_date: from_datetime,
      to_date: to_datetime,
      preload: [:node, :location]
    ]

    opts =
      if socket.assigns.selected_node_id,
        do: Keyword.put(opts, :node_id, socket.assigns.selected_node_id),
        else: opts

    opts =
      if socket.assigns.selected_location_id,
        do: Keyword.put(opts, :location_id, socket.assigns.selected_location_id),
        else: opts

    opts =
      if socket.assigns.selected_rating,
        do: Keyword.put(opts, :rating, socket.assigns.selected_rating),
        else: opts

    {surveys, total_pages, total_count} =
      System.list_visitor_surveys_paginated(socket.assigns.page, @per_page, opts)

    socket
    |> assign(:surveys, surveys)
    |> assign(:total_pages, total_pages)
    |> assign(:total_count, total_count)
  end

  defp load_stats(socket) do
    from_datetime = DateTime.new!(socket.assigns.from_date, ~T[00:00:00], "Etc/UTC")
    to_datetime = DateTime.new!(socket.assigns.to_date, ~T[23:59:59], "Etc/UTC")

    opts = [from_date: from_datetime, to_date: to_datetime]

    opts =
      if socket.assigns.selected_node_id,
        do: Keyword.put(opts, :node_id, socket.assigns.selected_node_id),
        else: opts

    opts =
      if socket.assigns.selected_location_id,
        do: Keyword.put(opts, :location_id, socket.assigns.selected_location_id),
        else: opts

    stats = System.get_visitor_statistics(opts)
    assign(socket, :stats, stats.surveys)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <!-- Header -->
      <div>
        <h1 class="text-2xl font-bold text-gray-900 dark:text-white">
          {gettext("Survey Feedback Logs")}
        </h1>
        <p class="text-sm text-gray-600 dark:text-gray-400 mt-1">
          {gettext("Detailed logs of all visitor survey feedback")}
        </p>
      </div>

      <div class="mb-4">
        <.back navigate="/manage/visitor/statistics">{gettext("Back to Statistics")}</.back>
      </div>
      
    <!-- Statistics Summary -->
      <%= if @stats do %>
        <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
          <div class="bg-white dark:bg-gray-800 rounded-lg shadow p-6">
            <div class="flex items-center">
              <div class="p-3 bg-blue-100 dark:bg-blue-900/30 rounded-lg">
                <.icon
                  name="hero-chat-bubble-left-right"
                  class="w-6 h-6 text-blue-600 dark:text-blue-400"
                />
              </div>
              <div class="ml-4">
                <p class="text-sm text-gray-600 dark:text-gray-400">{gettext("Total Surveys")}</p>
                <p class="text-2xl font-bold text-gray-900 dark:text-white">
                  {format_number(@stats.total)}
                </p>
              </div>
            </div>
          </div>

          <div class="bg-white dark:bg-gray-800 rounded-lg shadow p-6">
            <div class="flex items-center">
              <div class="p-3 bg-yellow-100 dark:bg-yellow-900/30 rounded-lg">
                <.icon name="hero-star" class="w-6 h-6 text-yellow-600 dark:text-yellow-400" />
              </div>
              <div class="ml-4">
                <p class="text-sm text-gray-600 dark:text-gray-400">{gettext("Average Rating")}</p>
                <p class="text-2xl font-bold text-gray-900 dark:text-white">
                  {if @stats.average_rating,
                    do: :erlang.float_to_binary(@stats.average_rating, decimals: 2),
                    else: "N/A"}
                </p>
              </div>
            </div>
          </div>

          <div class="bg-white dark:bg-gray-800 rounded-lg shadow p-6">
            <div class="text-sm text-gray-600 dark:text-gray-400 mb-2">
              {gettext("Rating Distribution")}
            </div>
            <div class="space-y-1">
              <%= for dist <- @stats.distribution do %>
                <div class="flex items-center justify-between text-xs">
                  <span class="text-gray-700 dark:text-gray-300">
                    {dist.rating} ⭐
                  </span>
                  <span class="font-semibold text-gray-900 dark:text-white">{dist.count}</span>
                </div>
              <% end %>
            </div>
          </div>
        </div>
      <% end %>
      
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

        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-5 gap-4">
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
          
    <!-- Room/Location Filter -->
          <form phx-change="filter_location">
            <div>
              <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                {gettext("Room/Location")}
              </label>
              <select
                name="location_id"
                class="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 dark:bg-gray-700 dark:text-white rounded-lg focus:ring-2 focus:ring-blue-500 dark:focus:ring-blue-400"
                disabled={@locations == []}
              >
                <option value="">{gettext("All Rooms")}</option>
                <option
                  :for={location <- @locations}
                  value={location.id}
                  selected={@selected_location_id == location.id}
                >
                  {location.location_name}
                </option>
              </select>
            </div>
          </form>
          
    <!-- Rating Filter -->
          <form phx-change="filter_rating">
            <div>
              <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                {gettext("Rating")}
              </label>
              <select
                name="rating"
                class="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 dark:bg-gray-700 dark:text-white rounded-lg focus:ring-2 focus:ring-blue-500 dark:focus:ring-blue-400"
              >
                <option value="">{gettext("All Ratings")}</option>
                <option value="5" selected={@selected_rating == 5}>{gettext("5 Stars")}</option>
                <option value="4" selected={@selected_rating == 4}>{gettext("4 Stars")}</option>
                <option value="3" selected={@selected_rating == 3}>{gettext("3 Stars")}</option>
                <option value="2" selected={@selected_rating == 2}>{gettext("2 Stars")}</option>
                <option value="1" selected={@selected_rating == 1}>{gettext("1 Star")}</option>
              </select>
            </div>
          </form>

          <form phx-change="update_from_date">
            <div>
              <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                {gettext("From Date")}
              </label>
              <input
                type="date"
                name="value"
                value={Date.to_string(@from_date)}
                class="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 dark:bg-gray-700 dark:text-white rounded-lg focus:ring-2 focus:ring-blue-500 dark:focus:ring-blue-400"
              />
            </div>
          </form>

          <form phx-change="update_to_date">
            <div>
              <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                {gettext("To Date")}
              </label>
              <input
                type="date"
                name="value"
                value={Date.to_string(@to_date)}
                class="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 dark:bg-gray-700 dark:text-white rounded-lg focus:ring-2 focus:ring-blue-500 dark:focus:ring-blue-400"
              />
            </div>
          </form>
        </div>
      </div>
      
    <!-- Results Info -->
      <div class="flex items-center justify-between">
        <p class="text-sm text-gray-600 dark:text-gray-400">
          {gettext("Showing %{count} of %{total} total survey responses",
            count: length(@surveys),
            total: format_number(@total_count)
          )}
        </p>
        <p class="text-sm text-gray-600 dark:text-gray-400">
          {gettext("Page %{page} of %{total}", page: @page, total: @total_pages)}
        </p>
      </div>
      
    <!-- Surveys Table -->
      <div class="bg-white dark:bg-gray-800 rounded-lg shadow overflow-hidden">
        <%= if @surveys == [] do %>
          <div class="p-12 text-center">
            <.icon
              name="hero-chat-bubble-left-right"
              class="w-16 h-16 mx-auto text-gray-400 dark:text-gray-500 mb-4"
            />
            <p class="text-lg text-gray-600 dark:text-gray-400">
              {gettext("No survey responses found")}
            </p>
            <p class="text-sm text-gray-500 dark:text-gray-500 mt-2">
              {gettext("Try adjusting your filters or date range")}
            </p>
          </div>
        <% else %>
          <div class="overflow-x-auto">
            <table class="min-w-full divide-y divide-gray-200 dark:divide-gray-700">
              <thead class="bg-gray-50 dark:bg-gray-700">
                <tr>
                  <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-300 uppercase tracking-wider">
                    {gettext("Date")}
                  </th>
                  <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-300 uppercase tracking-wider">
                    {gettext("Rating")}
                  </th>
                  <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-300 uppercase tracking-wider">
                    {gettext("Comment")}
                  </th>
                  <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-300 uppercase tracking-wider">
                    {gettext("Location/Room")}
                  </th>
                  <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-300 uppercase tracking-wider">
                    {gettext("Faculty/Node")}
                  </th>
                  <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-300 uppercase tracking-wider">
                    {gettext("Type")}
                  </th>
                </tr>
              </thead>
              <tbody class="bg-white dark:bg-gray-800 divide-y divide-gray-200 dark:divide-gray-700">
                <tr :for={survey <- @surveys} class="hover:bg-gray-50 dark:hover:bg-gray-700">
                  <td class="px-4 py-3 whitespace-nowrap text-sm text-gray-900 dark:text-white">
                    {Calendar.strftime(survey.inserted_at, "%Y-%m-%d %H:%M")}
                  </td>
                  <td class="px-4 py-3 whitespace-nowrap text-sm">
                    <span class={[
                      "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium",
                      rating_color_class(survey.rating)
                    ]}>
                      {survey.rating} ⭐
                    </span>
                  </td>
                  <td class="px-4 py-3 text-sm text-gray-900 dark:text-white max-w-md">
                    <%= if survey.comment do %>
                      <div class="truncate" title={survey.comment}>{survey.comment}</div>
                    <% else %>
                      <span class="text-gray-400 dark:text-gray-500">{gettext("No comment")}</span>
                    <% end %>
                  </td>
                  <td class="px-4 py-3 whitespace-nowrap text-sm text-gray-900 dark:text-white">
                    {survey.location && survey.location.location_name}
                  </td>
                  <td class="px-4 py-3 whitespace-nowrap text-sm text-gray-900 dark:text-white">
                    {survey.node && survey.node.name}
                  </td>
                  <td class="px-4 py-3 whitespace-nowrap text-sm text-gray-900 dark:text-white">
                    {survey.survey_type || "general"}
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        <% end %>
      </div>
      
    <!-- Pagination -->
      <%= if @total_pages > 1 do %>
        <div class="flex items-center justify-between bg-white dark:bg-gray-800 rounded-lg shadow px-6 py-3">
          <button
            type="button"
            phx-click="prev_page"
            disabled={@page == 1}
            class="px-4 py-2 text-sm font-medium text-gray-700 dark:text-gray-300 bg-white dark:bg-gray-700 border border-gray-300 dark:border-gray-600 rounded-lg hover:bg-gray-50 dark:hover:bg-gray-600 disabled:opacity-50 disabled:cursor-not-allowed"
          >
            <.icon name="hero-chevron-left" class="w-4 h-4 inline" /> {gettext("Previous")}
          </button>

          <div class="flex items-center gap-2">
            <%= for page_num <- page_numbers(@page, @total_pages) do %>
              <%= if page_num == :ellipsis do %>
                <span class="px-3 py-2 text-sm text-gray-500 dark:text-gray-400">...</span>
              <% else %>
                <button
                  type="button"
                  phx-click="goto_page"
                  phx-value-page={page_num}
                  class={[
                    "px-4 py-2 text-sm font-medium rounded-lg",
                    if(page_num == @page,
                      do: "bg-blue-600 text-white dark:bg-blue-700",
                      else:
                        "text-gray-700 dark:text-gray-300 bg-white dark:bg-gray-700 border border-gray-300 dark:border-gray-600 hover:bg-gray-50 dark:hover:bg-gray-600"
                    )
                  ]}
                >
                  {page_num}
                </button>
              <% end %>
            <% end %>
          </div>

          <button
            type="button"
            phx-click="next_page"
            disabled={@page == @total_pages}
            class="px-4 py-2 text-sm font-medium text-gray-700 dark:text-gray-300 bg-white dark:bg-gray-700 border border-gray-300 dark:border-gray-600 rounded-lg hover:bg-gray-50 dark:hover:bg-gray-600 disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {gettext("Next")} <.icon name="hero-chevron-right" class="w-4 h-4 inline" />
          </button>
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

  defp rating_color_class(rating) when rating >= 4,
    do: "bg-green-100 text-green-800 dark:bg-green-900/30 dark:text-green-400"

  defp rating_color_class(rating) when rating == 3,
    do: "bg-yellow-100 text-yellow-800 dark:bg-yellow-900/30 dark:text-yellow-400"

  defp rating_color_class(_rating),
    do: "bg-red-100 text-red-800 dark:bg-red-900/30 dark:text-red-400"

  # Generate page numbers with ellipsis
  defp page_numbers(_current, total) when total <= 7 do
    1..total |> Enum.to_list()
  end

  defp page_numbers(current, total) do
    cond do
      current <= 4 ->
        [1, 2, 3, 4, 5, :ellipsis, total]

      current >= total - 3 ->
        [1, :ellipsis, total - 4, total - 3, total - 2, total - 1, total]

      true ->
        [1, :ellipsis, current - 1, current, current + 1, :ellipsis, total]
    end
  end
end
