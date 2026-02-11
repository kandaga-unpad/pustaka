defmodule VoileWeb.Dashboard.StockOpnameLive.Report do
  use VoileWeb, :live_view_dashboard

  alias Voile.Schema.StockOpname
  alias VoileWeb.Utils.FormatIndonesiaTime

  def render(assigns) do
    ~H"""
    <div class="container mx-auto px-4 py-6">
      <%!-- Header --%>
      <div class="mb-6">
        <div class="flex items-center gap-3 mb-4">
          <.link
            navigate={~p"/manage/catalog/stock_opname"}
            class="p-2 hover:bg-gray-100 dark:hover:bg-gray-700 rounded-lg transition-colors"
          >
            <.icon name="hero-arrow-left" class="w-6 h-6" />
          </.link>
          <div>
            <h1 class="text-2xl font-bold text-gray-900 dark:text-gray-100">
              Librarian Work Reports
            </h1>
            <p class="text-sm text-gray-600 dark:text-gray-400 mt-1">
              View and manage librarian completion status for each stock opname session
            </p>
          </div>
        </div>
      </div>

      <%!-- Sessions List --%>
      <div class="space-y-4">
        <%= if @sessions == [] do %>
          <div class="bg-white dark:bg-gray-800 rounded-lg shadow-sm p-8 text-center">
            <.icon name="hero-inbox" class="w-16 h-16 mx-auto mb-4 text-gray-400 dark:text-gray-500" />
            <p class="text-gray-600 dark:text-gray-400">No stock opname sessions found.</p>
          </div>
        <% else %>
          <div :for={session <- @sessions} class="bg-white dark:bg-gray-800 rounded-lg shadow-sm">
            <%!-- Session Header --%>
            <button
              type="button"
              phx-click="toggle_session"
              phx-value-id={session.id}
              class="w-full px-6 py-4 flex items-center justify-between hover:bg-gray-50 dark:hover:bg-gray-700/50 transition-colors rounded-t-lg"
            >
              <div class="flex-1 text-left">
                <div class="flex items-center gap-3 flex-wrap">
                  <h3 class="text-lg font-semibold text-gray-900 dark:text-gray-100">
                    {session.title}
                  </h3>
                  <.session_status_badge status={session.status} />
                </div>
                <div class="flex items-center gap-4 mt-2 text-sm text-gray-600 dark:text-gray-400">
                  <span>Code: {session.session_code}</span>
                  <span>{session.checked_items} / {session.total_items} items checked</span>
                  <span>
                    {length(session.librarian_assignments)} librarian(s) assigned
                  </span>
                </div>
              </div>
              <.icon
                name={
                  if @expanded_sessions[session.id],
                    do: "hero-chevron-up",
                    else: "hero-chevron-down"
                }
                class="w-6 h-6 text-gray-400"
              />
            </button>

            <%!-- Librarian Details (Expandable) --%>
            <div
              :if={@expanded_sessions[session.id]}
              class="border-t border-gray-200 dark:border-gray-700"
            >
              <%= if session.librarian_assignments == [] do %>
                <div class="px-6 py-8 text-center text-gray-500 dark:text-gray-400">
                  <.icon name="hero-user-group" class="w-12 h-12 mx-auto mb-2 text-gray-400" />
                  <p>No librarians assigned to this session.</p>
                </div>
              <% else %>
                <div class="overflow-x-auto">
                  <table class="w-full">
                    <thead class="bg-gray-50 dark:bg-gray-700/50">
                      <tr>
                        <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                          Librarian
                        </th>
                        <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                          Items Checked
                        </th>
                        <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                          Status
                        </th>
                        <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                          Started At
                        </th>
                        <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                          Completed At
                        </th>
                        <th class="px-6 py-3 text-right text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                          Actions
                        </th>
                      </tr>
                    </thead>
                    <tbody class="divide-y divide-gray-200 dark:divide-gray-700">
                      <tr
                        :for={report <- Map.get(@session_reports, session.id, [])}
                        class="hover:bg-gray-50 dark:hover:bg-gray-700/30"
                      >
                        <td class="px-6 py-4">
                          <div class="flex items-center gap-3">
                            <div class="w-10 h-10 rounded-full bg-blue-100 dark:bg-blue-900 flex items-center justify-center">
                              <span class="text-blue-600 dark:text-blue-300 font-semibold text-sm">
                                {String.first(report.user.email)}
                              </span>
                            </div>
                            <div>
                              <p class="text-sm font-medium text-gray-900 dark:text-gray-100">
                                {report.user.email}
                              </p>
                              <%= if report.assignment.notes do %>
                                <p class="text-xs text-gray-500 dark:text-gray-400 mt-1">
                                  Note: {report.assignment.notes}
                                </p>
                              <% end %>
                            </div>
                          </div>
                        </td>
                        <td class="px-6 py-4">
                          <span class="text-sm font-semibold text-gray-900 dark:text-gray-100">
                            {report.items_checked}
                          </span>
                          <span class="text-sm text-gray-500 dark:text-gray-400">
                            items
                          </span>
                        </td>
                        <td class="px-6 py-4">
                          <.work_status_badge status={report.assignment.work_status} />
                        </td>
                        <td class="px-6 py-4">
                          <span class="text-sm text-gray-600 dark:text-gray-400">
                            <%= if report.assignment.started_at do %>
                              {FormatIndonesiaTime.format_utc_to_jakarta(report.assignment.started_at)}
                            <% else %>
                              <span class="text-gray-400 dark:text-gray-500">Not started</span>
                            <% end %>
                          </span>
                        </td>
                        <td class="px-6 py-4">
                          <span class="text-sm text-gray-600 dark:text-gray-400">
                            <%= if report.assignment.completed_at do %>
                              {FormatIndonesiaTime.format_utc_to_jakarta(
                                report.assignment.completed_at
                              )}
                            <% else %>
                              <span class="text-gray-400 dark:text-gray-500">-</span>
                            <% end %>
                          </span>
                        </td>
                        <td class="px-6 py-4">
                          <div class="flex items-center justify-end gap-2">
                            <%= if report.assignment.work_status == "completed" do %>
                              <button
                                type="button"
                                phx-click="reopen_work"
                                phx-value-session-id={session.id}
                                phx-value-user-id={report.user.id}
                                data-confirm="Are you sure you want to reopen this librarian's work session? They will be able to scan items again."
                                class="px-3 py-1.5 text-sm bg-yellow-600 hover:bg-yellow-700 text-white font-medium rounded-lg transition-colors"
                                title="Reopen work session"
                              >
                                <.icon name="hero-arrow-path" class="w-4 h-4 inline mr-1" /> Reopen
                              </button>
                            <% else %>
                              <button
                                type="button"
                                phx-click="complete_work"
                                phx-value-session-id={session.id}
                                phx-value-user-id={report.user.id}
                                data-confirm="Are you sure you want to manually complete this librarian's work? They won't be able to scan more items."
                                class="px-3 py-1.5 text-sm bg-green-600 hover:bg-green-700 text-white font-medium rounded-lg transition-colors"
                                title="Mark as completed"
                              >
                                <.icon name="hero-check-circle" class="w-4 h-4 inline mr-1" />
                                Complete
                              </button>
                            <% end %>
                          </div>
                        </td>
                      </tr>
                    </tbody>
                  </table>
                </div>
              <% end %>
            </div>
          </div>
        <% end %>
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
    """
  end

  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_scope.user

    # Only super admins can access this page
    unless VoileWeb.Auth.Authorization.is_super_admin?(current_user) do
      socket =
        socket
        |> put_flash(:error, "You don't have permission to access this page.")
        |> redirect(to: ~p"/manage/catalog/stock_opname")

      {:ok, socket}
    else
      socket =
        socket
        |> assign(:page_title, "Librarian Work Reports")
        |> assign(:page, 1)
        |> assign(:per_page, 10)
        |> assign(:session_reports, %{})
        |> assign(:expanded_sessions, %{})
        |> load_sessions()

      {:ok, socket}
    end
  end

  def handle_event("paginate", %{"page" => page}, socket) do
    socket =
      socket
      |> assign(:page, String.to_integer(page))
      |> assign(:expanded_sessions, %{})
      |> load_sessions()

    {:noreply, socket}
  end

  def handle_event("toggle_session", %{"id" => session_id}, socket) do
    expanded_sessions = socket.assigns.expanded_sessions
    is_expanded = Map.get(expanded_sessions, session_id, false)

    # If expanding, load the report data
    session_reports =
      if not is_expanded do
        session = Enum.find(socket.assigns.sessions, &(&1.id == session_id))

        if session do
          report = StockOpname.get_session_librarian_report(session)
          Map.put(socket.assigns.session_reports, session_id, report)
        else
          socket.assigns.session_reports
        end
      else
        socket.assigns.session_reports
      end

    updated_expanded =
      if is_expanded do
        Map.delete(expanded_sessions, session_id)
      else
        Map.put(expanded_sessions, session_id, true)
      end

    {:noreply,
     socket
     |> assign(:expanded_sessions, updated_expanded)
     |> assign(:session_reports, session_reports)}
  end

  def handle_event("complete_work", %{"session-id" => session_id, "user-id" => user_id}, socket) do
    session = Enum.find(socket.assigns.sessions, &(&1.id == session_id))
    user = Voile.Schema.Accounts.get_user!(user_id)

    case StockOpname.admin_complete_librarian_work(session, user) do
      {:ok, _} ->
        # Reload the report for this session
        report = StockOpname.get_session_librarian_report(session)

        session_reports = Map.put(socket.assigns.session_reports, session_id, report)

        {:noreply,
         socket
         |> assign(:session_reports, session_reports)
         |> put_flash(:info, "Librarian's work has been marked as completed.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to complete librarian's work.")}
    end
  end

  def handle_event("reopen_work", %{"session-id" => session_id, "user-id" => user_id}, socket) do
    session = Enum.find(socket.assigns.sessions, &(&1.id == session_id))
    user = Voile.Schema.Accounts.get_user!(user_id)

    case StockOpname.cancel_librarian_completion(session, user) do
      {:ok, _} ->
        # Reload the report for this session
        report = StockOpname.get_session_librarian_report(session)

        session_reports = Map.put(socket.assigns.session_reports, session_id, report)

        {:noreply,
         socket
         |> assign(:session_reports, session_reports)
         |> put_flash(:info, "Librarian's work session has been reopened.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to reopen librarian's work.")}
    end
  end

  defp load_sessions(socket) do
    %{page: page, per_page: per_page} = socket.assigns

    {sessions, total_pages, _total_count} =
      StockOpname.list_sessions(page, per_page, %{})

    socket
    |> assign(:sessions, sessions)
    |> assign(:total_pages, total_pages)
  end

  defp session_status_badge(assigns) do
    ~H"""
    <span class={[
      "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium",
      case @status do
        "draft" -> "bg-gray-100 text-gray-800 dark:bg-gray-700 dark:text-gray-300"
        "active" -> "bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-300"
        "completed" -> "bg-blue-100 text-blue-800 dark:bg-blue-900 dark:text-blue-300"
        "archived" -> "bg-gray-100 text-gray-800 dark:bg-gray-700 dark:text-gray-300"
        _ -> "bg-gray-100 text-gray-800 dark:bg-gray-700 dark:text-gray-300"
      end
    ]}>
      {String.capitalize(@status)}
    </span>
    """
  end

  defp work_status_badge(assigns) do
    ~H"""
    <span class={[
      "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium",
      case @status do
        "pending" -> "bg-gray-100 text-gray-800 dark:bg-gray-700 dark:text-gray-300"
        "in_progress" -> "bg-blue-100 text-blue-800 dark:bg-blue-900 dark:text-blue-300"
        "completed" -> "bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-300"
        _ -> "bg-gray-100 text-gray-800 dark:bg-gray-700 dark:text-gray-300"
      end
    ]}>
      <.icon
        name={
          case @status do
            "pending" -> "hero-clock"
            "in_progress" -> "hero-arrow-path"
            "completed" -> "hero-check-circle"
            _ -> "hero-question-mark-circle"
          end
        }
        class="w-3 h-3 mr-1"
      />
      {String.replace(@status, "_", " ") |> String.capitalize()}
    </span>
    """
  end
end
