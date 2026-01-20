defmodule VoileWeb.Dashboard.StockOpnameLive.Index do
  use VoileWeb, :live_view_dashboard

  alias Voile.Schema.StockOpname
  alias VoileWeb.Auth.StockOpnameAuthorization

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gradient-to-br from-gray-50 to-gray-100 dark:from-gray-900 dark:to-gray-800">
      <div class="container mx-auto px-4 py-8 sm:px-6 lg:px-8">
        <div class="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4 mb-8">
          <div>
            <h1 class="text-4xl font-extrabold text-gray-900 dark:text-gray-100 tracking-tight">
              Stock Opname
            </h1>
            <p class="mt-1 text-sm text-gray-600 dark:text-gray-400">
              Manage and monitor inventory checking sessions
            </p>
          </div>

          <.link
            :if={@can_create}
            navigate={~p"/manage/stock_opname/new"}
            class="inline-flex items-center px-5 py-2.5 bg-gradient-to-r from-blue-600 to-blue-700 hover:from-blue-700 hover:to-blue-800 text-white font-semibold rounded-xl shadow-lg shadow-blue-500/30 hover:shadow-xl hover:shadow-blue-500/40 transition-all duration-200 transform hover:scale-105"
          >
            <.icon name="hero-plus" class="w-5 h-5 mr-2" /> New Session
          </.link>
        </div>
        <%!-- Filters --%>
        <div class="bg-white/80 dark:bg-gray-800 backdrop-blur-sm rounded-2xl shadow-sm border border-gray-200/50 dark:border-gray-700/50 p-6 mb-8">
          <div class="flex items-center gap-2 mb-4">
            <.icon name="hero-funnel" class="w-5 h-5 text-gray-600 dark:text-gray-400" />
            <h2 class="text-lg font-semibold text-gray-900 dark:text-gray-100">Filter Sessions</h2>
          </div>
          <form phx-change="filter" phx-submit="filter" class="grid grid-cols-1 md:grid-cols-4 gap-4">
            <div>
              <label class="block text-sm font-semibold text-gray-700 dark:text-gray-300 mb-2">
                Status
              </label>
              <select
                name="status"
                class="w-full rounded-lg border-gray-300 dark:border-gray-600 shadow-sm focus:border-blue-500 focus:ring-2 focus:ring-blue-500/20 transition-all dark:bg-gray-700 dark:text-gray-200"
              >
                <option value="">All Status</option>

                <option
                  :for={{label, value} <- status_options()}
                  value={value}
                  selected={@filters.status == value}
                >
                  {label}
                </option>
              </select>
            </div>

            <div>
              <label class="block text-sm font-semibold text-gray-700 dark:text-gray-300 mb-2">
                From Date
              </label>
              <input
                type="date"
                name="from_date"
                value={@filters.from_date}
                class="w-full rounded-lg border-gray-300 dark:border-gray-600 shadow-sm focus:border-blue-500 focus:ring-2 focus:ring-blue-500/20 transition-all dark:bg-gray-700 dark:text-gray-200"
              />
            </div>

            <div>
              <label class="block text-sm font-semibold text-gray-700 dark:text-gray-300 mb-2">
                To Date
              </label>
              <input
                type="date"
                name="to_date"
                value={@filters.to_date}
                class="w-full rounded-lg border-gray-300 dark:border-gray-600 shadow-sm focus:border-blue-500 focus:ring-2 focus:ring-blue-500/20 transition-all dark:bg-gray-700 dark:text-gray-200"
              />
            </div>

            <div class="flex items-end">
              <button
                type="button"
                phx-click="clear_filters"
                class="w-full px-4 py-2.5 bg-gray-100 dark:bg-gray-700 hover:bg-gray-200 dark:hover:bg-gray-600 text-gray-700 dark:text-gray-300 font-medium rounded-lg shadow-sm transition-all duration-200 hover:shadow"
              >
                <span class="inline-flex items-center gap-2">
                  <.icon name="hero-x-mark" class="w-4 h-4" /> Clear Filters
                </span>
              </button>
            </div>
          </form>
        </div>
        <%!-- Sessions List --%>
        <div class="space-y-6">
          <div
            :for={session <- @sessions}
            class="bg-white/90 dark:bg-gray-800/90 backdrop-blur rounded-2xl shadow-md hover:shadow-xl transition-all duration-300 border border-gray-200/50 dark:border-gray-700/50 overflow-hidden group"
          >
            <div class="bg-gradient-to-r from-blue-50 to-indigo-50 dark:from-blue-900/30 dark:to-indigo-900/30 px-6 py-5 border-b border-gray-200/50 dark:border-gray-700/50">
              <div class="flex justify-between items-start">
                <div class="flex-1">
                  <div class="flex items-center gap-3 mb-2">
                    <.icon
                      name="hero-clipboard-document-list"
                      class="w-6 h-6 text-blue-600 dark:text-blue-400"
                    />
                    <h3 class="text-xl font-bold text-gray-900 dark:text-gray-100">
                      {session.title}
                    </h3>
                    <.session_status_badge status={session.status} />
                  </div>

                  <div class="flex items-center gap-4 text-sm">
                    <span class="inline-flex items-center gap-1.5 text-gray-600 dark:text-gray-400">
                      <.icon name="hero-hashtag" class="w-4 h-4" />
                      <span class="font-mono font-semibold">{session.session_code}</span>
                    </span>
                  </div>

                  <p
                    :if={session.description}
                    class="text-sm text-gray-600 dark:text-gray-400 mt-2 line-clamp-2"
                  >
                    {session.description}
                  </p>
                </div>
              </div>
            </div>

            <div class="p-6">
              <%!-- Progress Bar --%>
              <div class="mb-6">
                <div class="flex justify-between text-sm font-semibold text-gray-700 dark:text-gray-300 mb-2">
                  <span class="flex items-center gap-1.5">
                    <.icon name="hero-chart-bar" class="w-4 h-4" /> Progress
                  </span>
                  <span class="text-blue-600 dark:text-blue-400">
                    {session.checked_items} / {session.total_items} items
                  </span>
                </div>

                <div class="relative w-full bg-gray-200 dark:bg-gray-700 rounded-full h-3 overflow-hidden shadow-inner">
                  <div
                    class="absolute inset-0 bg-gradient-to-r from-blue-500 to-blue-600 rounded-full transition-all duration-500 ease-out shadow-sm"
                    style={"width: #{calculate_progress(session)}%"}
                  >
                    <div class="absolute inset-0 bg-white/20 animate-pulse"></div>
                  </div>
                </div>
              </div>
              <%!-- Statistics --%>
              <div class="grid grid-cols-2 md:grid-cols-4 gap-3 mb-6">
                <div class="bg-gradient-to-br from-blue-50 to-blue-100 dark:from-blue-900/30 dark:to-blue-800/30 rounded-xl p-4 text-center border border-blue-200/50 dark:border-blue-700/50 shadow-sm">
                  <p class="text-3xl font-extrabold text-blue-600 dark:text-blue-400 mb-1">
                    {session.checked_items}
                  </p>
                  <p class="text-xs font-semibold text-blue-700 dark:text-blue-300 uppercase tracking-wide">
                    Checked
                  </p>
                </div>

                <div class="bg-gradient-to-br from-red-50 to-red-100 dark:from-red-900/30 dark:to-red-800/30 rounded-xl p-4 text-center border border-red-200/50 dark:border-red-700/50 shadow-sm">
                  <p class="text-3xl font-extrabold text-red-600 dark:text-red-400 mb-1">
                    {session.missing_items}
                  </p>
                  <p class="text-xs font-semibold text-red-700 dark:text-red-300 uppercase tracking-wide">
                    Missing
                  </p>
                </div>

                <div class="bg-gradient-to-br from-amber-50 to-amber-100 dark:from-amber-900/30 dark:to-amber-800/30 rounded-xl p-4 text-center border border-amber-200/50 dark:border-amber-700/50 shadow-sm">
                  <p class="text-3xl font-extrabold text-amber-600 dark:text-amber-400 mb-1">
                    {session.items_with_changes}
                  </p>
                  <p class="text-xs font-semibold text-amber-700 dark:text-amber-300 uppercase tracking-wide">
                    Changes
                  </p>
                </div>

                <div class="bg-gradient-to-br from-gray-50 to-gray-100 dark:from-gray-800/50 dark:to-gray-700/50 rounded-xl p-4 text-center border border-gray-200/50 dark:border-gray-600/50 shadow-sm">
                  <p class="text-3xl font-extrabold text-gray-600 dark:text-gray-400 mb-1">
                    {session.total_items - session.checked_items}
                  </p>
                  <p class="text-xs font-semibold text-gray-700 dark:text-gray-300 uppercase tracking-wide">
                    Pending
                  </p>
                </div>
              </div>
              <%!-- Metadata --%>
              <div class="bg-gray-50 dark:bg-gray-900/50 rounded-xl p-4 mb-6 border border-gray-200/50 dark:border-gray-700/50">
                <div class="flex flex-wrap gap-4 text-xs text-gray-600 dark:text-gray-400">
                  <div class="flex items-center gap-1.5">
                    <.icon name="hero-user-circle" class="w-4 h-4 text-gray-500 dark:text-gray-400" />
                    <span>
                      Created by
                      <span class="font-semibold text-gray-900 dark:text-gray-200">
                        {session.created_by.fullname || session.created_by.email}
                      </span>
                    </span>
                  </div>

                  <div class="flex items-center gap-1.5">
                    <.icon name="hero-calendar" class="w-4 h-4 text-gray-500 dark:text-gray-400" />
                    <span>{format_date(session.inserted_at)}</span>
                  </div>

                  <div :if={session.started_at} class="flex items-center gap-1.5">
                    <.icon name="hero-play" class="w-4 h-4 text-green-500" />
                    <span>
                      Started:
                      <span class="font-semibold">{format_datetime(session.started_at)}</span>
                    </span>
                  </div>

                  <div :if={session.completed_at} class="flex items-center gap-1.5">
                    <.icon name="hero-check-circle" class="w-4 h-4 text-blue-500" />
                    <span>
                      Completed:
                      <span class="font-semibold">{format_datetime(session.completed_at)}</span>
                    </span>
                  </div>
                </div>
              </div>
              <%!-- Actions --%>
              <div class="flex gap-2 flex-wrap">
                <.link
                  navigate={~p"/manage/stock_opname/#{session.id}"}
                  class="inline-flex items-center gap-2 px-4 py-2 bg-gradient-to-r from-gray-100 to-gray-200 dark:from-gray-700 dark:to-gray-600 hover:from-gray-200 hover:to-gray-300 dark:hover:from-gray-600 dark:hover:to-gray-500 text-gray-700 dark:text-gray-200 text-sm font-medium rounded-lg shadow-sm hover:shadow transition-all duration-200"
                >
                  <.icon name="hero-eye" class="w-4 h-4" /> View Details
                </.link>
                <.link
                  :if={can_scan?(session, @current_user) and session.status == "in_progress"}
                  navigate={~p"/manage/stock_opname/#{session.id}/scan"}
                  class="inline-flex items-center gap-2 px-4 py-2 bg-gradient-to-r from-blue-600 to-blue-700 hover:from-blue-700 hover:to-blue-800 text-white text-sm font-semibold rounded-lg shadow-md shadow-blue-500/30 hover:shadow-lg hover:shadow-blue-500/40 transition-all duration-200"
                >
                  <.icon name="hero-qr-code" class="w-4 h-4" /> Continue Scanning
                </.link>
                <.link
                  :if={@can_create and session.status == "pending_review"}
                  navigate={~p"/manage/stock_opname/#{session.id}/review"}
                  class="inline-flex items-center gap-2 px-4 py-2 bg-gradient-to-r from-green-600 to-green-700 hover:from-green-700 hover:to-green-800 text-white text-sm font-semibold rounded-lg shadow-md shadow-green-500/30 hover:shadow-lg hover:shadow-green-500/40 transition-all duration-200"
                >
                  <.icon name="hero-clipboard-document-check" class="w-4 h-4" /> Review & Approve
                </.link>
                <button
                  :if={@can_create and session.status == "draft"}
                  phx-click="start_session"
                  phx-value-id={session.id}
                  class="inline-flex items-center gap-2 px-4 py-2 bg-gradient-to-r from-green-600 to-green-700 hover:from-green-700 hover:to-green-800 text-white text-sm font-semibold rounded-lg shadow-md shadow-green-500/30 hover:shadow-lg hover:shadow-green-500/40 transition-all duration-200"
                  data-confirm="Start this stock opname session? Librarians will be notified."
                >
                  <.icon name="hero-play" class="w-4 h-4" /> Start Session
                </button>
                <button
                  :if={@can_create and session.status == "in_progress" and can_complete?(session)}
                  phx-click="complete_session"
                  phx-value-id={session.id}
                  class="inline-flex items-center gap-2 px-4 py-2 bg-gradient-to-r from-orange-600 to-orange-700 hover:from-orange-700 hover:to-orange-800 text-white text-sm font-semibold rounded-lg shadow-md shadow-orange-500/30 hover:shadow-lg hover:shadow-orange-500/40 transition-all duration-200"
                  data-confirm="Complete this session? All unscanned items will be marked as missing."
                >
                  <.icon name="hero-check-badge" class="w-4 h-4" /> Complete Session
                </button>
                <button
                  :if={@can_create and session.status in ["draft", "in_progress"]}
                  phx-click="cancel_session"
                  phx-value-id={session.id}
                  class="inline-flex items-center gap-2 px-4 py-2 bg-gradient-to-r from-red-600 to-red-700 hover:from-red-700 hover:to-red-800 text-white text-sm font-semibold rounded-lg shadow-md shadow-red-500/30 hover:shadow-lg hover:shadow-red-500/40 transition-all duration-200"
                  data-confirm="Cancel this session? This cannot be undone."
                >
                  <.icon name="hero-x-circle" class="w-4 h-4" /> Cancel
                </button>
              </div>
            </div>
          </div>
          <%!-- Empty State --%>
          <div :if={@sessions == []} class="text-center py-16">
            <div class="bg-gradient-to-br from-blue-50 to-indigo-50 dark:from-blue-900/30 dark:to-indigo-900/30 rounded-3xl p-12 max-w-md mx-auto border border-blue-200/50 dark:border-blue-700/50 shadow-sm">
              <div class="bg-white dark:bg-gray-800 rounded-full w-20 h-20 flex items-center justify-center mx-auto mb-6 shadow-md">
                <.icon
                  name="hero-document-magnifying-glass"
                  class="w-10 h-10 text-blue-600 dark:text-blue-400"
                />
              </div>
              <h3 class="text-2xl font-bold text-gray-900 dark:text-gray-100 mb-3">
                No Stock Opname Sessions
              </h3>

              <p class="text-gray-600 dark:text-gray-400 mb-6 leading-relaxed">
                {if @can_create,
                  do: "Create your first stock opname session to start inventory checking.",
                  else: "No sessions have been assigned to you yet."}
              </p>

              <.link
                :if={@can_create}
                navigate={~p"/manage/stock_opname/new"}
                class="inline-flex items-center px-6 py-3 bg-gradient-to-r from-blue-600 to-blue-700 hover:from-blue-700 hover:to-blue-800 text-white font-semibold rounded-xl shadow-lg shadow-blue-500/30 hover:shadow-xl hover:shadow-blue-500/40 transition-all duration-200 transform hover:scale-105"
              >
                <.icon name="hero-plus" class="w-5 h-5 mr-2" /> Create Session
              </.link>
            </div>
          </div>
        </div>
        <%!-- Pagination --%>
        <div :if={@total_pages > 1} class="mt-8 flex justify-center">
          <nav class="flex items-center gap-3 bg-white/80 dark:bg-gray-800/80 backdrop-blur-sm rounded-xl shadow-sm border border-gray-200/50 dark:border-gray-700/50 p-2">
            <button
              :if={@page > 1}
              phx-click="paginate"
              phx-value-page={@page - 1}
              class="inline-flex items-center gap-2 px-4 py-2 bg-gradient-to-r from-gray-100 to-gray-200 dark:from-gray-700 dark:to-gray-600 hover:from-gray-200 hover:to-gray-300 dark:hover:from-gray-600 dark:hover:to-gray-500 text-gray-700 dark:text-gray-200 font-medium rounded-lg shadow-sm hover:shadow transition-all duration-200"
            >
              <.icon name="hero-chevron-left" class="w-4 h-4" /> Previous
            </button>
            <span class="px-6 py-2 text-gray-700 dark:text-gray-300 font-semibold">
              Page <span class="text-blue-600 dark:text-blue-400">{@page}</span> of {@total_pages}
            </span>
            <button
              :if={@page < @total_pages}
              phx-click="paginate"
              phx-value-page={@page + 1}
              class="inline-flex items-center gap-2 px-4 py-2 bg-gradient-to-r from-gray-100 to-gray-200 dark:from-gray-700 dark:to-gray-600 hover:from-gray-200 hover:to-gray-300 dark:hover:from-gray-600 dark:hover:to-gray-500 text-gray-700 dark:text-gray-200 font-medium rounded-lg shadow-sm hover:shadow transition-all duration-200"
            >
              Next <.icon name="hero-chevron-right" class="w-4 h-4" />
            </button>
          </nav>
        </div>
      </div>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_scope.user
    can_create = StockOpnameAuthorization.can_create_session?(current_user)

    socket =
      socket
      |> assign(:page_title, "Stock Opname Sessions")
      |> assign(:current_user, current_user)
      |> assign(:can_create, can_create)
      |> assign(:page, 1)
      |> assign(:per_page, 10)
      |> assign(:filters, %{status: nil, from_date: nil, to_date: nil})
      |> load_sessions()

    {:ok, socket}
  end

  def handle_event("filter", params, socket) do
    filters = %{
      status: params["status"],
      from_date: params["from_date"],
      to_date: params["to_date"]
    }

    socket =
      socket
      |> assign(:filters, filters)
      |> assign(:page, 1)
      |> load_sessions()

    {:noreply, socket}
  end

  def handle_event("clear_filters", _params, socket) do
    socket =
      socket
      |> assign(:filters, %{status: nil, from_date: nil, to_date: nil})
      |> assign(:page, 1)
      |> load_sessions()

    {:noreply, socket}
  end

  def handle_event("paginate", %{"page" => page}, socket) do
    socket =
      socket
      |> assign(:page, String.to_integer(page))
      |> load_sessions()

    {:noreply, socket}
  end

  def handle_event("start_session", %{"id" => id}, socket) do
    session = StockOpname.get_session_without_items!(id)

    case StockOpname.start_session(session, socket.assigns.current_user) do
      {:ok, _session} ->
        socket =
          socket
          |> put_flash(
            :info,
            "Stock opname session started successfully. Librarians have been notified."
          )
          |> load_sessions()

        {:noreply, socket}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to start session")}
    end
  end

  def handle_event("complete_session", %{"id" => id}, socket) do
    session = StockOpname.get_session_without_items!(id)

    case StockOpname.complete_session(session, socket.assigns.current_user) do
      {:ok, _session} ->
        socket =
          socket
          |> put_flash(:info, "Stock opname session completed and ready for review.")
          |> load_sessions()

        {:noreply, socket}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to complete session")}
    end
  end

  def handle_event("cancel_session", %{"id" => id}, socket) do
    session = StockOpname.get_session_without_items!(id)

    case StockOpname.cancel_session(session, socket.assigns.current_user) do
      {:ok, _session} ->
        socket =
          socket
          |> put_flash(:info, "Stock opname session cancelled.")
          |> load_sessions()

        {:noreply, socket}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to cancel session")}
    end
  end

  defp load_sessions(socket) do
    %{page: page, per_page: per_page, filters: filters, current_user: current_user} =
      socket.assigns

    filter_map =
      %{}
      |> maybe_put(:status, filters.status)
      |> maybe_put(:from_date, parse_date(filters.from_date))
      |> maybe_put(:to_date, parse_date(filters.to_date))
      |> Map.put(:user, current_user)

    {sessions, total_pages, total_count} =
      StockOpname.list_sessions(page, per_page, filter_map)

    socket
    |> assign(:sessions, sessions)
    |> assign(:total_pages, total_pages)
    |> assign(:total_count, total_count)
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, _key, ""), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp parse_date(nil), do: nil
  defp parse_date(""), do: nil

  defp parse_date(date_string) do
    case Date.from_iso8601(date_string) do
      {:ok, date} -> DateTime.new!(date, ~T[00:00:00])
      {:error, _} -> nil
    end
  end

  defp status_options do
    [
      {"Draft", "draft"},
      {"In Progress", "in_progress"},
      {"Completed", "completed"},
      {"Pending Review", "pending_review"},
      {"Approved", "approved"},
      {"Rejected", "rejected"},
      {"Cancelled", "cancelled"}
    ]
  end

  defp session_status_badge(assigns) do
    color_class =
      case assigns.status do
        "draft" ->
          "bg-gradient-to-r from-gray-100 to-gray-200 text-gray-800 border-gray-300"

        "initializing" ->
          "bg-gradient-to-r from-purple-100 to-purple-200 text-purple-800 border-purple-300 animate-pulse"

        "in_progress" ->
          "bg-gradient-to-r from-blue-100 to-blue-200 text-blue-800 border-blue-300"

        "completed" ->
          "bg-gradient-to-r from-yellow-100 to-yellow-200 text-yellow-800 border-yellow-300"

        "pending_review" ->
          "bg-gradient-to-r from-orange-100 to-orange-200 text-orange-800 border-orange-300"

        "approved" ->
          "bg-gradient-to-r from-green-100 to-green-200 text-green-800 border-green-300"

        "rejected" ->
          "bg-gradient-to-r from-red-100 to-red-200 text-red-800 border-red-300"

        "cancelled" ->
          "bg-gradient-to-r from-gray-100 to-gray-200 text-gray-800 border-gray-300"

        _ ->
          "bg-gradient-to-r from-gray-100 to-gray-200 text-gray-800 border-gray-300"
      end

    label =
      case assigns.status do
        "draft" -> "Draft"
        "initializing" -> "Initializing..."
        "in_progress" -> "In Progress"
        "completed" -> "Completed"
        "pending_review" -> "Pending Review"
        "approved" -> "Approved"
        "rejected" -> "Rejected"
        "cancelled" -> "Cancelled"
        _ -> assigns.status
      end

    assigns = assign(assigns, :color_class, color_class) |> assign(:label, label)

    ~H"""
    <span class={"inline-flex items-center px-3 py-1.5 text-xs font-bold uppercase tracking-wide rounded-full border shadow-sm #{@color_class}"}>
      {@label}
    </span>
    """
  end

  defp calculate_progress(session) do
    if session.total_items > 0 do
      Float.round(session.checked_items / session.total_items * 100, 1)
    else
      0
    end
  end

  defp can_scan?(session, user) do
    StockOpnameAuthorization.can_scan_items?(user, session)
  end

  defp can_complete?(session) do
    StockOpname.all_librarians_completed?(session)
  end

  defp format_date(datetime) do
    Calendar.strftime(datetime, "%B %d, %Y")
  end

  defp format_datetime(datetime) do
    Calendar.strftime(datetime, "%B %d, %Y %I:%M %p")
  end
end
