defmodule VoileWeb.Dashboard.Glam.Library.ReadOnSpotLive.Index do
  use VoileWeb, :live_view_dashboard

  alias Voile.Schema.Library.Feats
  alias VoileWeb.Utils.FormatIndonesiaTime

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_scope.user
    is_super_admin = is_super_admin?(current_user)

    node_id = unless is_super_admin, do: current_user.node_id

    count_today = Feats.count_today(node_id)
    count_month = Feats.count_this_month(node_id)
    recent = Feats.list_read_on_spots(node_id: node_id, limit: 10)

    socket =
      socket
      |> assign(:page_title, "Read On Spot")
      |> assign(:is_super_admin, is_super_admin)
      |> assign(:current_user, current_user)
      |> assign(:count_today, count_today)
      |> assign(:count_month, count_month)
      |> stream(:recent_records, recent)

    {:ok, socket}
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
          %{label: "Read On Spot", path: nil}
        ]} />
        <div class="flex items-start justify-between mt-3">
          <div>
            <h1 class="text-2xl font-bold text-gray-800 dark:text-white">Read On Spot</h1>
            <p class="text-gray-500 dark:text-gray-400 text-sm mt-1">
              Track items that are being read or referenced in-library.
            </p>
          </div>
          <div class="flex gap-2">
            <.link
              navigate={~p"/manage/glam/library/read_on_spot/report"}
              class="inline-flex items-center gap-1.5 px-4 py-2 rounded-lg bg-gray-100 dark:bg-gray-700 text-gray-700 dark:text-gray-300 text-sm hover:bg-gray-200 dark:hover:bg-gray-600 transition"
            >
              <.icon name="hero-chart-bar" class="w-4 h-4" /> Report
            </.link>
            <.link
              navigate={~p"/manage/glam/library/read_on_spot/scan"}
              class="inline-flex items-center gap-1.5 px-4 py-2 rounded-lg bg-blue-600 text-white text-sm hover:bg-blue-700 transition"
            >
              <.icon name="hero-qr-code" class="w-4 h-4" /> Scan Items
            </.link>
          </div>
        </div>
      </div>
      <%!-- Stats Cards --%>
      <div class="grid grid-cols-2 gap-4 mb-6">
        <div class="bg-white dark:bg-gray-800 rounded-xl shadow-sm p-5">
          <p class="text-xs text-gray-500 dark:text-gray-400 uppercase tracking-wide mb-1">Today</p>
          <p class="text-3xl font-bold text-blue-600 dark:text-blue-400">{@count_today}</p>
          <p class="text-xs text-gray-400 mt-1">items scanned</p>
        </div>
        <div class="bg-white dark:bg-gray-800 rounded-xl shadow-sm p-5">
          <p class="text-xs text-gray-500 dark:text-gray-400 uppercase tracking-wide mb-1">
            This Month
          </p>
          <p class="text-3xl font-bold text-indigo-600 dark:text-indigo-400">{@count_month}</p>
          <p class="text-xs text-gray-400 mt-1">items scanned</p>
        </div>
      </div>
      <%!-- Recent Records --%>
      <div class="bg-white dark:bg-gray-800 rounded-lg shadow-sm p-4">
        <div class="flex items-center justify-between mb-3">
          <h2 class="text-sm font-semibold text-gray-700 dark:text-gray-300 uppercase tracking-wide">
            Recent Activity
          </h2>
          <.link
            navigate={~p"/manage/glam/library/read_on_spot/report"}
            class="text-xs text-blue-600 hover:underline"
          >
            Full report →
          </.link>
        </div>
        <div id="recent-records" phx-update="stream">
          <div class="text-gray-400 text-sm italic only:block hidden py-4 text-center">
            No scans recorded yet.
          </div>
          <%= for {dom_id, record} <- @streams.recent_records do %>
            <div
              id={dom_id}
              class="flex items-start gap-3 py-3 border-b border-gray-100 dark:border-gray-700 last:border-0"
            >
              <div class="w-9 h-9 rounded-full bg-blue-100 dark:bg-blue-900/30 flex items-center justify-center shrink-0">
                <.icon name="hero-book-open" class="w-4 h-4 text-blue-700 dark:text-blue-300" />
              </div>
              <div class="flex-1 min-w-0">
                <p class="text-sm font-medium text-gray-900 dark:text-white truncate">
                  {if record.item && record.item.collection,
                    do: record.item.collection.title,
                    else: "Unknown Title"}
                </p>
                <div class="flex flex-wrap gap-x-3 text-xs text-gray-500 mt-0.5">
                  <%= if record.item do %>
                    <span>{record.item.item_code}</span>
                  <% end %>
                  <%= if record.location do %>
                    <span>{record.location.location_name}</span>
                  <% end %>
                  <%= if record.node do %>
                    <span class="text-indigo-500">{record.node.name}</span>
                  <% end %>
                  <span>
                    {if record.read_at,
                      do:
                        Calendar.strftime(
                          FormatIndonesiaTime.shift_to_jakarta(record.read_at),
                          "%d %b %Y %H:%M"
                        ),
                      else:
                        Calendar.strftime(
                          FormatIndonesiaTime.shift_to_jakarta(record.inserted_at),
                          "%d %b %Y %H:%M"
                        )}
                  </span>
                </div>
              </div>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end
end
