defmodule VoileWeb.Dashboard.Glam.Library.ReadOnSpotLive.Report do
  use VoileWeb, :live_view_dashboard

  alias Voile.Schema.Library.Feats

  @default_report_type "daily"
  @per_page 25

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_scope.user
    is_super_admin = is_super_admin?(current_user)

    nodes =
      if is_super_admin do
        Feats.list_nodes()
      else
        []
      end

    default_node_id = unless is_super_admin, do: current_user.node_id

    locations =
      if default_node_id do
        Feats.list_locations_by_node(default_node_id)
      else
        []
      end

    today = Date.utc_today()
    default_date_from = Date.beginning_of_month(today) |> Date.to_iso8601()
    default_date_to = Date.to_iso8601(today)

    socket =
      socket
      |> assign(:page_title, "Read On Spot — Report")
      |> assign(:is_super_admin, is_super_admin)
      |> assign(:current_user, current_user)
      |> assign(:nodes, nodes)
      |> assign(:selected_node_id, default_node_id)
      |> assign(:locations, locations)
      |> assign(:selected_location_id, nil)
      |> assign(:report_type, @default_report_type)
      |> assign(:date_from, default_date_from)
      |> assign(:date_to, default_date_to)
      |> assign(:report_data, [])
      |> assign(:report_page, 1)
      |> assign(:report_total, 0)
      |> assign(:report_total_pages, 1)
      |> assign(:per_page, @per_page)
      |> assign(
        :filter_form,
        to_form(%{
          "node_id" => if(default_node_id, do: to_string(default_node_id), else: ""),
          "location_id" => "",
          "date_from" => default_date_from,
          "date_to" => default_date_to
        })
      )

    {:ok, load_report(socket)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="container mx-auto px-2 sm:px-4 py-4 max-w-6xl">
      <%!-- Header --%>
      <div class="mb-6">
        <.breadcrumb items={[
          %{label: "Manage", path: ~p"/manage"},
          %{label: "GLAM", path: ~p"/manage/glam"},
          %{label: "Library", path: ~p"/manage/glam/library"},
          %{label: "Read On Spot", path: ~p"/manage/glam/library/read_on_spot"},
          %{label: "Report", path: nil}
        ]} />
        <h1 class="text-2xl font-bold text-gray-800 dark:text-white mt-3">Read On Spot — Report</h1>
        <p class="text-gray-500 dark:text-gray-400 text-sm mt-1">
          In-library item usage statistics by location.
        </p>
      </div>
      <%!-- Filters --%>
      <div class="bg-white dark:bg-gray-800 rounded-lg shadow-sm p-4 mb-5">
        <h2 class="text-sm font-semibold text-gray-700 dark:text-gray-300 uppercase tracking-wide mb-3">
          Filters
        </h2>
        <.form for={@filter_form} id="report-filter-form" phx-change="apply_filters">
          <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
            <%!-- Report type toggle --%>
            <div>
              <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                Report Type
              </label>
              <div class="flex rounded-lg overflow-hidden border border-gray-300 dark:border-gray-600">
                <button
                  type="button"
                  phx-click="set_report_type"
                  phx-value-type="daily"
                  class={[
                    "flex-1 px-3 py-2 text-sm font-medium transition",
                    if(@report_type == "daily",
                      do: "bg-blue-600 text-white",
                      else:
                        "bg-white dark:bg-gray-700 text-gray-700 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-600"
                    )
                  ]}
                >
                  Daily
                </button>
                <button
                  type="button"
                  phx-click="set_report_type"
                  phx-value-type="monthly"
                  class={[
                    "flex-1 px-3 py-2 text-sm font-medium border-l border-gray-300 dark:border-gray-600 transition",
                    if(@report_type == "monthly",
                      do: "bg-blue-600 text-white",
                      else:
                        "bg-white dark:bg-gray-700 text-gray-700 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-600"
                    )
                  ]}
                >
                  Monthly
                </button>
              </div>
            </div>
            <%!-- Node filter (super_admin only) --%>
            <%= if @is_super_admin do %>
              <div>
                <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                  Node / Branch
                </label>
                <select
                  id="report-node-select"
                  name="node_id"
                  class="w-full rounded-lg border border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-700 text-gray-900 dark:text-white px-3 py-2 text-sm focus:ring-2 focus:ring-blue-500"
                >
                  <option value="">All Nodes</option>
                  <%= for node <- @nodes do %>
                    <option
                      value={node.id}
                      selected={to_string(node.id) == to_string(@selected_node_id)}
                    >
                      {node.name}
                    </option>
                  <% end %>
                </select>
              </div>
            <% end %>
            <%!-- Location filter --%>
            <div>
              <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                Location
              </label>
              <select
                id="report-location-select"
                name="location_id"
                class="w-full rounded-lg border border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-700 text-gray-900 dark:text-white px-3 py-2 text-sm focus:ring-2 focus:ring-blue-500"
                disabled={@locations == []}
              >
                <option value="">All Locations</option>
                <%= for loc <- @locations do %>
                  <option
                    value={loc.id}
                    selected={to_string(loc.id) == to_string(@selected_location_id)}
                  >
                    {loc.location_name}
                  </option>
                <% end %>
              </select>
            </div>
            <%!-- Date From --%>
            <div>
              <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                <%= if @report_type == "daily" do %>
                  From Date
                <% else %>
                  From Month
                <% end %>
              </label>
              <input
                type={if @report_type == "daily", do: "date", else: "month"}
                id="date-from"
                name="date_from"
                value={date_input_value(@date_from, @report_type)}
                class="w-full rounded-lg border border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-700 text-gray-900 dark:text-white px-3 py-2 text-sm focus:ring-2 focus:ring-blue-500"
              />
            </div>
            <%!-- Date To --%>
            <div>
              <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                <%= if @report_type == "daily" do %>
                  To Date
                <% else %>
                  To Month
                <% end %>
              </label>
              <input
                type={if @report_type == "daily", do: "date", else: "month"}
                id="date-to"
                name="date_to"
                value={date_input_value(@date_to, @report_type)}
                class="w-full rounded-lg border border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-700 text-gray-900 dark:text-white px-3 py-2 text-sm focus:ring-2 focus:ring-blue-500"
              />
            </div>
          </div>
        </.form>
      </div>
      <%!-- Report Table --%>
      <div class="bg-white dark:bg-gray-800 rounded-lg shadow-sm overflow-hidden">
        <table class="w-full text-sm">
          <thead class="bg-gray-50 dark:bg-gray-700">
            <tr>
              <th class="px-4 py-3 text-left text-xs font-semibold text-gray-600 dark:text-gray-300 uppercase tracking-wide">
                {if @report_type == "daily", do: "Date", else: "Month"}
              </th>
              <th class="px-4 py-3 text-left text-xs font-semibold text-gray-600 dark:text-gray-300 uppercase tracking-wide">
                Node
              </th>
              <th class="px-4 py-3 text-left text-xs font-semibold text-gray-600 dark:text-gray-300 uppercase tracking-wide">
                Location
              </th>
              <th class="px-4 py-3 text-right text-xs font-semibold text-gray-600 dark:text-gray-300 uppercase tracking-wide">
                Count
              </th>
            </tr>
          </thead>
          <tbody id="report-table-body">
            <%= if @report_data == [] do %>
              <tr>
                <td
                  colspan="5"
                  class="px-4 py-8 text-center text-gray-400 dark:text-gray-500 text-sm"
                >
                  No data for the selected filters.
                </td>
              </tr>
            <% end %>
            <%= for {row, idx} <- Enum.with_index(@report_data) do %>
              <tr class={[
                "border-t border-gray-100 dark:border-gray-700 cursor-pointer group",
                if(rem(idx, 2) == 0,
                  do: "bg-white dark:bg-gray-800 hover:bg-blue-50 dark:hover:bg-blue-900/20",
                  else: "bg-gray-50 dark:bg-gray-750 hover:bg-blue-50 dark:hover:bg-blue-900/20"
                )
              ]}>
                <td class="px-4 py-3 text-gray-800 dark:text-gray-200 font-medium">
                  {format_period(row, @report_type)}
                </td>
                <td class="px-4 py-3 text-gray-600 dark:text-gray-400">{row.node_name}</td>
                <td class="px-4 py-3 text-gray-600 dark:text-gray-400">{row.location_name}</td>
                <td class="px-4 py-3 text-right font-semibold text-blue-700 dark:text-blue-400">
                  {row.count}
                </td>
                <td class="px-4 py-3 text-right">
                  <.link
                    navigate={detail_path(row, @report_type)}
                    class="inline-flex items-center gap-1 text-xs text-blue-600 hover:text-blue-800 dark:text-blue-400 dark:hover:text-blue-200 transition"
                  >
                    Detail <.icon name="hero-arrow-right" class="w-3 h-3" />
                  </.link>
                </td>
              </tr>
            <% end %>
          </tbody>
          <%= if @report_data != [] do %>
            <tfoot class="bg-gray-50 dark:bg-gray-700 border-t-2 border-gray-200 dark:border-gray-600">
              <tr>
                <td
                  colspan="3"
                  class="px-4 py-2 text-xs font-semibold text-gray-600 dark:text-gray-300 uppercase"
                >
                  Total (this page)
                </td>
                <td class="px-4 py-2 text-right font-bold text-blue-700 dark:text-blue-400">
                  {Enum.sum(Enum.map(@report_data, & &1.count))}
                </td>
                <td></td>
              </tr>
            </tfoot>
          <% end %>
        </table>
      </div>
      <%!-- Pagination --%>
      <%= if @report_total_pages > 1 do %>
        <div class="flex items-center justify-between mt-4">
          <p class="text-sm text-gray-500 dark:text-gray-400">
            Showing {@report_page * @per_page - @per_page + 1}–{min(
              @report_page * @per_page,
              @report_total
            )} of {@report_total} groups
          </p>
          <div class="flex gap-1">
            <%= if @report_page > 1 do %>
              <button
                type="button"
                phx-click="report_page"
                phx-value-page={@report_page - 1}
                class="px-3 py-1.5 text-sm rounded-lg bg-gray-100 dark:bg-gray-700 text-gray-700 dark:text-gray-300 hover:bg-gray-200 dark:hover:bg-gray-600 transition"
              >
                ← Prev
              </button>
            <% end %>
            <span class="px-3 py-1.5 text-sm rounded-lg bg-blue-600 text-white font-medium">
              {@report_page} / {@report_total_pages}
            </span>
            <%= if @report_page < @report_total_pages do %>
              <button
                type="button"
                phx-click="report_page"
                phx-value-page={@report_page + 1}
                class="px-3 py-1.5 text-sm rounded-lg bg-gray-100 dark:bg-gray-700 text-gray-700 dark:text-gray-300 hover:bg-gray-200 dark:hover:bg-gray-600 transition"
              >
                Next →
              </button>
            <% end %>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  @impl true
  def handle_event("set_report_type", %{"type" => type}, socket) do
    {:noreply, socket |> assign(:report_type, type) |> assign(:report_page, 1) |> load_report()}
  end

  @impl true
  def handle_event("report_page", %{"page" => page}, socket) do
    {:noreply, socket |> assign(:report_page, String.to_integer(page)) |> load_report()}
  end

  @impl true
  def handle_event("apply_filters", params, socket) do
    node_id =
      if socket.assigns.is_super_admin do
        case Map.get(params, "node_id", "") do
          "" -> nil
          v -> String.to_integer(v)
        end
      else
        socket.assigns.current_user.node_id
      end

    prev_node_id = socket.assigns.selected_node_id

    {location_id, locations} =
      if node_id != prev_node_id do
        locs = if node_id, do: Feats.list_locations_by_node(node_id), else: []
        {nil, locs}
      else
        loc_id =
          case Map.get(params, "location_id", "") do
            "" -> nil
            v -> String.to_integer(v)
          end

        {loc_id, socket.assigns.locations}
      end

    date_from = Map.get(params, "date_from", "")
    date_to = Map.get(params, "date_to", "")

    socket =
      socket
      |> assign(:selected_node_id, node_id)
      |> assign(:locations, locations)
      |> assign(:selected_location_id, location_id)
      |> assign(:date_from, date_from)
      |> assign(:date_to, date_to)
      |> assign(:filter_form, to_form(params))
      |> assign(:report_page, 1)

    {:noreply, load_report(socket)}
  end

  # -----------------------------------------------------------------------
  # Private helpers
  # -----------------------------------------------------------------------

  defp load_report(socket) do
    %{
      report_type: report_type,
      selected_node_id: node_id,
      selected_location_id: location_id,
      date_from: date_from_str,
      date_to: date_to_str,
      report_page: page
    } = socket.assigns

    date_from = parse_date_from(date_from_str, report_type, :start)
    date_to = parse_date_from(date_to_str, report_type, :end)

    opts =
      [node_id: node_id, location_id: location_id, date_from: date_from, date_to: date_to]
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)

    {data, total} =
      cond do
        report_type == "monthly" -> Feats.monthly_report(opts, page: page, per_page: @per_page)
        true -> Feats.daily_report(opts, page: page, per_page: @per_page)
      end

    total_pages = max(1, ceil(total / @per_page))

    socket
    |> assign(:report_data, data)
    |> assign(:report_total, total)
    |> assign(:report_total_pages, total_pages)
  end

  defp parse_date_from(nil, _type, _boundary), do: nil
  defp parse_date_from("", _type, _boundary), do: nil

  defp parse_date_from(value, "monthly", boundary) do
    case String.split(value, "-") do
      [year_str, month_str] ->
        year = String.to_integer(year_str)
        month = String.to_integer(month_str)

        date =
          cond do
            boundary == :start ->
              Date.new!(year, month, 1)

            true ->
              last_day = Date.days_in_month(Date.new!(year, month, 1))
              Date.new!(year, month, last_day)
          end

        DateTime.new!(
          date,
          if(boundary == :start, do: ~T[00:00:00], else: ~T[23:59:59]),
          "Etc/UTC"
        )

      _ ->
        nil
    end
  end

  defp parse_date_from(value, _type, boundary) do
    case Date.from_iso8601(value) do
      {:ok, date} ->
        DateTime.new!(
          date,
          if(boundary == :start, do: ~T[00:00:00], else: ~T[23:59:59]),
          "Etc/UTC"
        )

      _ ->
        nil
    end
  end

  defp date_input_value(nil, _), do: ""

  defp date_input_value(value, "monthly") do
    case String.split(value, "-") do
      [year, month | _] -> "#{year}-#{month}"
      _ -> value
    end
  end

  defp date_input_value(value, _), do: value

  defp format_period(%{date: date}, "daily") when is_struct(date, Date) do
    Calendar.strftime(date, "%d %b %Y")
  end

  defp format_period(%{date: date}, "daily") do
    to_string(date)
  end

  defp format_period(%{month: %DateTime{} = dt}, "monthly") do
    Calendar.strftime(dt, "%B %Y")
  end

  defp format_period(%{month: month}, "monthly") do
    to_string(month)
  end

  defp format_period(row, _), do: inspect(row)

  defp detail_path(%{date: date, node_id: node_id, location_id: location_id}, "daily") do
    params =
      %{"type" => "daily", "date" => Date.to_iso8601(date)}
      |> maybe_add("node_id", node_id)
      |> maybe_add("location_id", location_id)

    "/manage/glam/library/read_on_spot/report/detail?" <> URI.encode_query(params)
  end

  defp detail_path(
         %{month: %DateTime{} = dt, node_id: node_id, location_id: location_id},
         "monthly"
       ) do
    date_str = "#{dt.year}-#{String.pad_leading(to_string(dt.month), 2, "0")}"

    params =
      %{"type" => "monthly", "date" => date_str}
      |> maybe_add("node_id", node_id)
      |> maybe_add("location_id", location_id)

    "/manage/glam/library/read_on_spot/report/detail?" <> URI.encode_query(params)
  end

  defp detail_path(%{month: month, node_id: node_id, location_id: location_id}, "monthly") do
    params =
      %{"type" => "monthly", "date" => to_string(month)}
      |> maybe_add("node_id", node_id)
      |> maybe_add("location_id", location_id)

    "/manage/glam/library/read_on_spot/report/detail?" <> URI.encode_query(params)
  end

  defp detail_path(row, _type), do: detail_path(row, "daily")

  defp maybe_add(map, _key, nil), do: map
  defp maybe_add(map, key, val), do: Map.put(map, key, to_string(val))
end
