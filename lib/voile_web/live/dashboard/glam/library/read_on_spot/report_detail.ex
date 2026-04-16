defmodule VoileWeb.Dashboard.Glam.Library.ReadOnSpotLive.ReportDetail do
  use VoileWeb, :live_view_dashboard

  alias Voile.Schema.Library.Feats
  alias VoileWeb.Utils.FormatIndonesiaTime

  @per_page 20

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    current_user = socket.assigns.current_scope.user
    is_super_admin = is_super_admin?(current_user)

    type = Map.get(params, "type", "daily")
    date = Map.get(params, "date", "")
    node_id = parse_int(Map.get(params, "node_id"))
    location_id = parse_int(Map.get(params, "location_id"))
    page = parse_int(Map.get(params, "page")) || 1

    opts = [
      type: type,
      date: date,
      node_id: node_id,
      location_id: location_id,
      page: page,
      per_page: @per_page
    ]

    {records, total} = Feats.report_detail(opts)
    total_pages = max(1, ceil(total / @per_page))

    label =
      cond do
        type == "monthly" ->
          case String.split(date, "-") do
            [year, month | _] ->
              month_name =
                Calendar.strftime(
                  Date.new!(String.to_integer(year), String.to_integer(month), 1),
                  "%B %Y"
                )

              month_name

            _ ->
              date
          end

        true ->
          case Date.from_iso8601(date) do
            {:ok, d} -> Calendar.strftime(d, "%d %b %Y")
            _ -> date
          end
      end

    socket =
      socket
      |> assign(:page_title, "Read On Spot — Detail #{label}")
      |> assign(:is_super_admin, is_super_admin)
      |> assign(:current_user, current_user)
      |> assign(:type, type)
      |> assign(:date, date)
      |> assign(:node_id, node_id)
      |> assign(:location_id, location_id)
      |> assign(:label, label)
      |> assign(:records, records)
      |> assign(:total, total)
      |> assign(:page, page)
      |> assign(:total_pages, total_pages)
      |> assign(:per_page, @per_page)

    {:noreply, socket}
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
          %{label: "Report", path: ~p"/manage/glam/library/read_on_spot/report"},
          %{label: @label, path: nil}
        ]} />
        <div class="flex items-start justify-between mt-3">
          <div>
            <h1 class="text-2xl font-bold text-gray-800 dark:text-white">
              Read On Spot — {@label}
            </h1>
            <p class="text-gray-500 dark:text-gray-400 text-sm mt-1">
              {@total} item(s) recorded
              <%= if @node_id do %>
                at this node
              <% end %>
            </p>
          </div>
          <.link
            navigate={~p"/manage/glam/library/read_on_spot/report"}
            class="inline-flex items-center gap-1.5 px-4 py-2 rounded-lg bg-gray-100 dark:bg-gray-700 text-gray-700 dark:text-gray-300 text-sm hover:bg-gray-200 dark:hover:bg-gray-600 transition"
          >
            <.icon name="hero-arrow-left" class="w-4 h-4" /> Back to Report
          </.link>
        </div>
      </div>
      <%!-- Table --%>
      <div class="bg-white dark:bg-gray-800 rounded-lg shadow-sm overflow-hidden">
        <table class="w-full text-sm">
          <thead class="bg-gray-50 dark:bg-gray-700">
            <tr>
              <th class="px-4 py-3 text-left text-xs font-semibold text-gray-600 dark:text-gray-300 uppercase tracking-wide">
                Title
              </th>
              <th class="px-4 py-3 text-left text-xs font-semibold text-gray-600 dark:text-gray-300 uppercase tracking-wide hidden md:table-cell">
                Author
              </th>
              <th class="px-4 py-3 text-left text-xs font-semibold text-gray-600 dark:text-gray-300 uppercase tracking-wide hidden sm:table-cell">
                Barcode
              </th>
              <th class="px-4 py-3 text-left text-xs font-semibold text-gray-600 dark:text-gray-300 uppercase tracking-wide hidden sm:table-cell">
                Location
              </th>
              <th class="px-4 py-3 text-left text-xs font-semibold text-gray-600 dark:text-gray-300 uppercase tracking-wide">
                Time
              </th>
            </tr>
          </thead>
          <tbody>
            <%= if @records == [] do %>
              <tr>
                <td colspan="5" class="px-4 py-8 text-center text-gray-400 dark:text-gray-500 text-sm">
                  No records found.
                </td>
              </tr>
            <% end %>
            <%= for {record, idx} <- Enum.with_index(@records) do %>
              <tr class={[
                "border-t border-gray-100 dark:border-gray-700",
                if(rem(idx, 2) == 0,
                  do: "bg-white dark:bg-gray-800",
                  else: "bg-gray-50 dark:bg-gray-750"
                )
              ]}>
                <td class="px-4 py-3 text-gray-800 dark:text-gray-200 font-medium">
                  {record.title}
                </td>
                <td class="px-4 py-3 text-gray-600 dark:text-gray-400 hidden md:table-cell">
                  {record.author || "—"}
                </td>
                <td class="px-4 py-3 text-gray-600 dark:text-gray-400 hidden sm:table-cell">
                  {record.barcode || "—"}
                </td>
                <td class="px-4 py-3 text-gray-600 dark:text-gray-400 hidden sm:table-cell">
                  {record.location_name}
                </td>
                <td class="px-4 py-3 text-gray-500 dark:text-gray-400 text-xs whitespace-nowrap">
                  {Calendar.strftime(
                    FormatIndonesiaTime.shift_to_jakarta(record.read_at || record.inserted_at),
                    "%d %b %H:%M"
                  )}
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>
      <%!-- Pagination --%>
      <%= if @total_pages > 1 do %>
        <div class="flex items-center justify-between mt-4">
          <p class="text-sm text-gray-500 dark:text-gray-400">
            Showing {(@page - 1) * @per_page + 1}–{min(@page * @per_page, @total)} of {@total}
          </p>
          <div class="flex gap-1">
            <%= if @page > 1 do %>
              <.link
                navigate={detail_path(@type, @date, @node_id, @location_id, @page - 1)}
                class="px-3 py-1.5 text-sm rounded-lg bg-gray-100 dark:bg-gray-700 text-gray-700 dark:text-gray-300 hover:bg-gray-200 dark:hover:bg-gray-600 transition"
              >
                ← Prev
              </.link>
            <% end %>
            <span class="px-3 py-1.5 text-sm rounded-lg bg-blue-600 text-white font-medium">
              {@page} / {@total_pages}
            </span>
            <%= if @page < @total_pages do %>
              <.link
                navigate={detail_path(@type, @date, @node_id, @location_id, @page + 1)}
                class="px-3 py-1.5 text-sm rounded-lg bg-gray-100 dark:bg-gray-700 text-gray-700 dark:text-gray-300 hover:bg-gray-200 dark:hover:bg-gray-600 transition"
              >
                Next →
              </.link>
            <% end %>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp parse_int(nil), do: nil
  defp parse_int(""), do: nil
  defp parse_int(v) when is_binary(v), do: String.to_integer(v)
  defp parse_int(v) when is_integer(v), do: v

  defp detail_path(type, date, node_id, location_id, page) do
    params =
      %{"type" => type, "date" => date, "page" => page}
      |> maybe_add("node_id", node_id)
      |> maybe_add("location_id", location_id)

    "/manage/glam/library/read_on_spot/report/detail?" <> URI.encode_query(params)
  end

  defp maybe_add(map, _key, nil), do: map
  defp maybe_add(map, key, val), do: Map.put(map, key, val)
end
