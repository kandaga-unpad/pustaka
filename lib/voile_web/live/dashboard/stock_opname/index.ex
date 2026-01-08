defmodule VoileWeb.Dashboard.StockOpnameLive.Index do
  use VoileWeb, :live_view_dashboard

  alias Voile.Schema.StockOpname
  alias VoileWeb.Auth.StockOpnameAuthorization

  def render(assigns) do
    ~H"""
    <div class="container mx-auto px-4 py-6">
      <div class="flex justify-between items-center mb-6">
        <h1 class="text-3xl font-bold text-gray-900">Stock Opname Sessions</h1>
        
        <.link
          :if={@can_create}
          navigate={~p"/manage/stock-opname/new"}
          class="inline-flex items-center px-4 py-2 bg-blue-600 hover:bg-blue-700 text-white font-medium rounded-lg transition-colors"
        >
          <.icon name="hero-plus" class="w-5 h-5 mr-2" /> New Session
        </.link>
      </div>
       <%!-- Filters --%>
      <div class="bg-white rounded-lg shadow-sm p-4 mb-6">
        <form phx-change="filter" phx-submit="filter" class="grid grid-cols-1 md:grid-cols-4 gap-4">
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Status</label>
            <select name="status" class="w-full rounded-md border-gray-300">
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
            <label class="block text-sm font-medium text-gray-700 mb-1">From Date</label>
            <input
              type="date"
              name="from_date"
              value={@filters.from_date}
              class="w-full rounded-md border-gray-300"
            />
          </div>
          
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">To Date</label>
            <input
              type="date"
              name="to_date"
              value={@filters.to_date}
              class="w-full rounded-md border-gray-300"
            />
          </div>
          
          <div class="flex items-end">
            <button
              type="button"
              phx-click="clear_filters"
              class="w-full px-4 py-2 bg-gray-200 hover:bg-gray-300 text-gray-700 rounded-md transition-colors"
            >
              Clear Filters
            </button>
          </div>
        </form>
      </div>
       <%!-- Sessions List --%>
      <div class="space-y-4">
        <div
          :for={session <- @sessions}
          class="bg-white rounded-lg shadow-sm hover:shadow-md transition-shadow p-6"
        >
          <div class="flex justify-between items-start mb-4">
            <div class="flex-1">
              <div class="flex items-center gap-3 mb-2">
                <h3 class="text-xl font-semibold text-gray-900">{session.title}</h3>
                 <.session_status_badge status={session.status} />
              </div>
              
              <p class="text-sm text-gray-600 mb-1">Code: {session.session_code}</p>
              
              <p :if={session.description} class="text-sm text-gray-500">{session.description}</p>
            </div>
          </div>
           <%!-- Progress Bar --%>
          <div class="mb-4">
            <div class="flex justify-between text-sm text-gray-600 mb-1">
              <span>Progress</span> <span>{session.checked_items} / {session.total_items} items</span>
            </div>
            
            <div class="w-full bg-gray-200 rounded-full h-2">
              <div
                class="bg-blue-600 h-2 rounded-full transition-all"
                style={"width: #{calculate_progress(session)}%"}
              >
              </div>
            </div>
          </div>
           <%!-- Statistics --%>
          <div class="grid grid-cols-2 md:grid-cols-4 gap-4 mb-4">
            <div class="text-center">
              <p class="text-2xl font-bold text-blue-600">{session.checked_items}</p>
              
              <p class="text-xs text-gray-500">Checked</p>
            </div>
            
            <div class="text-center">
              <p class="text-2xl font-bold text-red-600">{session.missing_items}</p>
              
              <p class="text-xs text-gray-500">Missing</p>
            </div>
            
            <div class="text-center">
              <p class="text-2xl font-bold text-yellow-600">{session.items_with_changes}</p>
              
              <p class="text-xs text-gray-500">With Changes</p>
            </div>
            
            <div class="text-center">
              <p class="text-2xl font-bold text-gray-600">
                {session.total_items - session.checked_items}
              </p>
              
              <p class="text-xs text-gray-500">Pending</p>
            </div>
          </div>
           <%!-- Metadata --%>
          <div class="text-xs text-gray-500 mb-4">
            <p>
              Created by {session.created_by.fullname || session.created_by.email} on {format_date(
                session.inserted_at
              )}
            </p>
            
            <p :if={session.started_at}>Started: {format_datetime(session.started_at)}</p>
            
            <p :if={session.completed_at}>Completed: {format_datetime(session.completed_at)}</p>
          </div>
           <%!-- Actions --%>
          <div class="flex gap-2 flex-wrap">
            <.link
              navigate={~p"/manage/stock-opname/#{session.id}"}
              class="px-3 py-2 bg-gray-100 hover:bg-gray-200 text-gray-700 text-sm rounded transition-colors"
            >
              View Details
            </.link>
            <.link
              :if={can_scan?(session, @current_user) and session.status == "in_progress"}
              navigate={~p"/manage/stock-opname/#{session.id}/scan"}
              class="px-3 py-2 bg-blue-600 hover:bg-blue-700 text-white text-sm rounded transition-colors"
            >
              Continue Scanning
            </.link>
            <.link
              :if={@can_create and session.status == "pending_review"}
              navigate={~p"/manage/stock-opname/#{session.id}/review"}
              class="px-3 py-2 bg-green-600 hover:bg-green-700 text-white text-sm rounded transition-colors"
            >
              Review & Approve
            </.link>
            <button
              :if={@can_create and session.status == "draft"}
              phx-click="start_session"
              phx-value-id={session.id}
              class="px-3 py-2 bg-green-600 hover:bg-green-700 text-white text-sm rounded transition-colors"
              data-confirm="Start this stock opname session? Librarians will be notified."
            >
              Start Session
            </button>
            <button
              :if={@can_create and session.status == "in_progress" and can_complete?(session)}
              phx-click="complete_session"
              phx-value-id={session.id}
              class="px-3 py-2 bg-orange-600 hover:bg-orange-700 text-white text-sm rounded transition-colors"
              data-confirm="Complete this session? All unscanned items will be marked as missing."
            >
              Complete Session
            </button>
            <button
              :if={@can_create and session.status in ["draft", "in_progress"]}
              phx-click="cancel_session"
              phx-value-id={session.id}
              class="px-3 py-2 bg-red-600 hover:bg-red-700 text-white text-sm rounded transition-colors"
              data-confirm="Cancel this session? This cannot be undone."
            >
              Cancel
            </button>
          </div>
        </div>
         <%!-- Empty State --%>
        <div :if={@sessions == []} class="text-center py-12">
          <.icon name="hero-document-magnifying-glass" class="w-16 h-16 mx-auto text-gray-400 mb-4" />
          <h3 class="text-lg font-medium text-gray-900 mb-2">No Stock Opname Sessions</h3>
          
          <p class="text-gray-500 mb-4">
            {if @can_create,
              do: "Create your first stock opname session to start inventory checking.",
              else: "No sessions have been assigned to you yet."}
          </p>
          
          <.link
            :if={@can_create}
            navigate={~p"/manage/stock-opname/new"}
            class="inline-flex items-center px-4 py-2 bg-blue-600 hover:bg-blue-700 text-white font-medium rounded-lg transition-colors"
          >
            <.icon name="hero-plus" class="w-5 h-5 mr-2" /> Create Session
          </.link>
        </div>
      </div>
       <%!-- Pagination --%>
      <div :if={@total_pages > 1} class="mt-6 flex justify-center">
        <nav class="flex items-center gap-2">
          <button
            :if={@page > 1}
            phx-click="paginate"
            phx-value-page={@page - 1}
            class="px-3 py-2 bg-white border border-gray-300 rounded-md hover:bg-gray-50"
          >
            Previous
          </button> <span class="px-4 py-2 text-gray-700">Page {@page} of {@total_pages}</span>
          <button
            :if={@page < @total_pages}
            phx-click="paginate"
            phx-value-page={@page + 1}
            class="px-3 py-2 bg-white border border-gray-300 rounded-md hover:bg-gray-50"
          >
            Next
          </button>
        </nav>
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
    %{page: page, per_page: per_page, filters: filters} = socket.assigns

    filter_map =
      %{}
      |> maybe_put(:status, filters.status)
      |> maybe_put(:from_date, parse_date(filters.from_date))
      |> maybe_put(:to_date, parse_date(filters.to_date))

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
        "draft" -> "bg-gray-100 text-gray-800"
        "initializing" -> "bg-purple-100 text-purple-800 animate-pulse"
        "in_progress" -> "bg-blue-100 text-blue-800"
        "completed" -> "bg-yellow-100 text-yellow-800"
        "pending_review" -> "bg-orange-100 text-orange-800"
        "approved" -> "bg-green-100 text-green-800"
        "rejected" -> "bg-red-100 text-red-800"
        "cancelled" -> "bg-gray-100 text-gray-800"
        _ -> "bg-gray-100 text-gray-800"
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
    <span class={"inline-flex items-center px-2 py-1 text-xs font-medium rounded #{@color_class}"}>
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
