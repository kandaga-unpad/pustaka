defmodule VoileWeb.Dashboard.Glam.Library.Circulation.Report do
  use VoileWeb, :live_view_dashboard

  import VoileWeb.Dashboard.Glam.Library.Circulation.Helpers
  import VoileWeb.Dashboard.Glam.Library.Circulation.Components

  alias Voile.Schema.Library.Circulation
  alias VoileWeb.Auth.Authorization
  alias Voile.Schema.System, as: VoileSystem

  @impl true
  def render(assigns) do
    ~H"""
    <div class="px-4 py-6">
      <.breadcrumb items={[
        %{label: "Manage", path: ~p"/manage"},
        %{label: "GLAM", path: ~p"/manage/glam"},
        %{label: "Library", path: ~p"/manage/glam/library"},
        %{label: "Circulation Report", path: nil}
      ]} />
      <div class="mb-8">
        <h1 class="text-3xl font-bold text-gray-900 dark:text-gray-100">Circulation Report</h1>

        <p class="mt-2 text-gray-600 dark:text-gray-400">
          View circulation statistics and activity (read-only)
        </p>
      </div>
      <%!-- Tabs Navigation --%>
      <div class="mb-6">
        <div class="border-b border-gray-200 dark:border-gray-600">
          <nav class="-mb-px flex space-x-8">
            <button
              phx-click="switch_tab"
              phx-value-tab="overview"
              class={[
                "whitespace-nowrap pb-4 px-1 border-b-2 font-medium text-sm",
                if(@active_tab == "overview",
                  do:
                    "border-voile-primary text-voile-primary dark:border-voile-primary/60 dark:text-voile-primary/60",
                  else:
                    "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300 dark:text-gray-400 dark:hover:text-gray-300"
                )
              ]}
            >
              Overview
            </button>
            <button
              phx-click="switch_tab"
              phx-value-tab="transactions"
              class={[
                "whitespace-nowrap pb-4 px-1 border-b-2 font-medium text-sm",
                if(@active_tab == "transactions",
                  do:
                    "border-voile-primary text-voile-primary dark:border-voile-primary/60 dark:text-voile-primary/60",
                  else:
                    "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300 dark:text-gray-400 dark:hover:text-gray-300"
                )
              ]}
            >
              Transactions
            </button>
            <button
              phx-click="switch_tab"
              phx-value-tab="reservations"
              class={[
                "whitespace-nowrap pb-4 px-1 border-b-2 font-medium text-sm",
                if(@active_tab == "reservations",
                  do:
                    "border-voile-primary text-voile-primary dark:border-voile-primary/60 dark:text-voile-primary/60",
                  else:
                    "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300 dark:text-gray-400 dark:hover:text-gray-300"
                )
              ]}
            >
              Reservations
            </button>
            <button
              phx-click="switch_tab"
              phx-value-tab="fines"
              class={[
                "whitespace-nowrap pb-4 px-1 border-b-2 font-medium text-sm",
                if(@active_tab == "fines",
                  do:
                    "border-voile-primary text-voile-primary dark:border-voile-primary/60 dark:text-voile-primary/60",
                  else:
                    "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300 dark:text-gray-400 dark:hover:text-gray-300"
                )
              ]}
            >
              Fines
            </button>
          </nav>
        </div>
      </div>
      <%!-- Tab Content --%>
      <%= case @active_tab do %>
        <% "overview" -> %>
          <.overview_tab
            is_super_admin={@is_super_admin}
            nodes={@nodes}
            selected_node_id={@selected_node_id}
            stats={@stats}
            recent_activities={@recent_activities}
          />
        <% "transactions" -> %>
          <.transactions_tab
            transactions={@transactions}
            page={@page}
            total_pages={@total_pages}
            search_query={@search_query}
          />
        <% "reservations" -> %>
          <.reservations_tab
            reservations={@reservations}
            page={@page}
            total_pages={@total_pages}
            search_query={@search_query}
          />
        <% "fines" -> %>
          <.fines_tab
            fines={@fines}
            page={@page}
            total_pages={@total_pages}
            search_query={@search_query}
          />
      <% end %>
    </div>
    """
  end

  # Overview Tab Component
  defp overview_tab(assigns) do
    ~H"""
    <div>
      <%= if @is_super_admin do %>
        <div class="mb-6">
          <.form :let={f} for={%{}} phx-change="select_node">
            <.input
              field={f[:node_id]}
              type="select"
              options={
                [{"All Nodes", "all"}] ++
                  Enum.map(@nodes || [], fn n -> {n.name, to_string(n.id)} end)
              }
              value={if @selected_node_id, do: to_string(@selected_node_id), else: "all"}
              class="block w-64 text-sm border border-voile-muted rounded-md shadow-sm"
              label="Filter node"
            />
          </.form>
        </div>
      <% end %>
      <%!-- Statistics Section --%>
      <.circulation_stats stats={@stats} />
      <%!-- Recent Activities Section --%>
      <div class="bg-white dark:bg-gray-700 rounded-lg shadow p-6 mb-8">
        <h2 class="text-xl font-semibold text-gray-900 dark:text-white mb-4">Recent Activity</h2>

        <div class="space-y-4">
          <%= if Enum.empty?(@recent_activities) do %>
            <p class="text-gray-500 dark:text-gray-400 text-center py-8">
              No recent activities to display
            </p>
          <% else %>
            <%= for activity <- @recent_activities do %>
              <div class="flex items-center justify-between py-3 border-b border-gray-200 dark:border-gray-600 last:border-0">
                <div class="flex items-start">
                  <div class="flex items-center justify-center w-10 h-10">
                    <div class={"w-2 h-2 rounded-full #{activity_color(activity.event_type)}"}></div>
                  </div>

                  <div class="ml-4">
                    <p class="text-sm text-gray-900 dark:text-gray-100">{activity.description}</p>

                    <p class="text-xs text-gray-500 dark:text-gray-400">
                      {format_datetime(activity.event_date)}
                    </p>
                  </div>
                </div>

                <div class="text-xs text-gray-400 dark:text-gray-300">{activity.event_type}</div>
              </div>
            <% end %>
          <% end %>
        </div>
      </div>
      <%!-- Quick Links Section (Super Admin Only) --%>
      <%= if @is_super_admin do %>
        <div class="bg-white dark:bg-gray-700 rounded-lg shadow p-6">
          <h2 class="text-xl font-semibold text-gray-900 dark:text-white mb-4">
            Quick Links (Admin)
          </h2>

          <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
            <.link
              navigate="/manage/glam/library/circulation/transactions"
              class="flex items-center p-4 bg-gray-50 dark:bg-gray-600 rounded-lg hover:bg-gray-100 dark:hover:bg-gray-500 transition-colors"
            >
              <.icon name="hero-document-text" class="w-6 h-6 text-blue-500 mr-3" />
              <span class="text-sm font-medium text-gray-900 dark:text-white">
                View All Transactions
              </span>
            </.link>
            <.link
              navigate="/manage/glam/library/circulation/reservations"
              class="flex items-center p-4 bg-gray-50 dark:bg-gray-600 rounded-lg hover:bg-gray-100 dark:hover:bg-gray-500 transition-colors"
            >
              <.icon name="hero-bookmark" class="w-6 h-6 text-green-500 mr-3" />
              <span class="text-sm font-medium text-gray-900 dark:text-white">View Reservations</span>
            </.link>
            <.link
              navigate="/manage/glam/library/circulation/fines"
              class="flex items-center p-4 bg-gray-50 dark:bg-gray-600 rounded-lg hover:bg-gray-100 dark:hover:bg-gray-500 transition-colors"
            >
              <.icon name="hero-banknotes" class="w-6 h-6 text-red-500 mr-3" />
              <span class="text-sm font-medium text-gray-900 dark:text-white">View Fines</span>
            </.link>
            <.link
              navigate="/manage/glam/library/circulation/circulation_history"
              class="flex items-center p-4 bg-gray-50 dark:bg-gray-600 rounded-lg hover:bg-gray-100 dark:hover:bg-gray-500 transition-colors"
            >
              <.icon name="hero-clock" class="w-6 h-6 text-purple-500 mr-3" />
              <span class="text-sm font-medium text-gray-900 dark:text-white">View History</span>
            </.link>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  # Transactions Tab Component
  defp transactions_tab(assigns) do
    ~H"""
    <div>
      <%!-- Search Bar --%>
      <div class="mb-6">
        <.form :let={f} for={%{}} phx-change="search" phx-submit="search">
          <.input
            field={f[:search]}
            type="text"
            placeholder="Search by member name or item code..."
            value={@search_query}
            class="block w-full rounded-lg border border-gray-200 bg-white px-4 py-3 text-sm text-gray-900 shadow-sm placeholder:text-gray-400 transition duration-150 focus:border-voile-primary focus:outline-none focus:ring-2 focus:ring-voile-primary/20 dark:border-gray-600 dark:bg-gray-800 dark:text-gray-100 dark:placeholder:text-gray-500"
            label="Search Transactions"
          />
        </.form>
      </div>
      <%!-- Transactions Table --%>
      <div class="bg-white dark:bg-gray-700 rounded-lg shadow overflow-hidden">
        <table class="min-w-full divide-y divide-gray-200 dark:divide-gray-600">
          <thead class="bg-gray-50 dark:bg-gray-800">
            <tr>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                Member
              </th>

              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                Item
              </th>

              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                Status
              </th>

              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                Checkout Date
              </th>

              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                Due Date
              </th>

              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                Actions
              </th>
            </tr>
          </thead>

          <tbody class="bg-white dark:bg-gray-700 divide-y divide-gray-200 dark:divide-gray-600">
            <%= if Enum.empty?(@transactions) do %>
              <tr>
                <td colspan="6" class="px-6 py-8 text-center text-gray-500 dark:text-gray-400">
                  No transactions found
                </td>
              </tr>
            <% else %>
              <%= for transaction <- @transactions do %>
                <tr class="hover:bg-gray-50 dark:hover:bg-gray-600">
                  <td class="px-6 py-4 whitespace-nowrap">
                    <div class="text-sm font-medium text-gray-900 dark:text-gray-100">
                      {transaction.member.fullname}
                    </div>

                    <div class="text-sm text-gray-500 dark:text-gray-400">
                      {transaction.member.identifier}
                    </div>
                  </td>

                  <td class="px-6 py-4">
                    <div class="text-sm text-gray-900 dark:text-gray-100">
                      {transaction.item.collection.title}
                    </div>

                    <div class="text-sm text-gray-500 dark:text-gray-400">
                      {transaction.item.item_code}
                    </div>
                  </td>

                  <td class="px-6 py-4 whitespace-nowrap">
                    <span class={"inline-flex px-2 py-1 text-xs font-semibold rounded-full #{status_badge_class(transaction.status)}"}>
                      {String.upcase(transaction.status)}
                    </span>
                  </td>

                  <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500 dark:text-gray-400">
                    {format_datetime(transaction.transaction_date)}
                  </td>

                  <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500 dark:text-gray-400">
                    {format_datetime(transaction.due_date)}
                  </td>

                  <td class="px-6 py-4 whitespace-nowrap text-sm">
                    <.link
                      navigate={~p"/manage/glam/library/circulation/transactions/#{transaction.id}"}
                      class="text-voile-primary hover:underline font-medium"
                    >
                      View
                    </.link>
                  </td>
                </tr>
              <% end %>
            <% end %>
          </tbody>
        </table>
      </div>
      <%!-- Pagination --%> <.pagination_controls page={@page} total_pages={@total_pages} />
    </div>
    """
  end

  # Reservations Tab Component
  defp reservations_tab(assigns) do
    ~H"""
    <div>
      <%!-- Search Bar --%>
      <div class="mb-6">
        <.form :let={f} for={%{}} phx-change="search" phx-submit="search">
          <.input
            field={f[:search]}
            type="text"
            placeholder="Search by member name or item..."
            value={@search_query}
            class="block w-full rounded-lg border border-gray-200 bg-white px-4 py-3 text-sm text-gray-900 shadow-sm placeholder:text-gray-400 transition duration-150 focus:border-voile-primary focus:outline-none focus:ring-2 focus:ring-voile-primary/20 dark:border-gray-600 dark:bg-gray-800 dark:text-gray-100 dark:placeholder:text-gray-500"
            label="Search Reservations"
          />
        </.form>
      </div>
      <%!-- Reservations Table --%>
      <div class="bg-white dark:bg-gray-700 rounded-lg shadow overflow-hidden">
        <table class="min-w-full divide-y divide-gray-200 dark:divide-gray-600">
          <thead class="bg-gray-50 dark:bg-gray-800">
            <tr>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                Member
              </th>

              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                Item
              </th>

              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                Status
              </th>

              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                Reserved On
              </th>

              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                Expiry
              </th>

              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                Actions
              </th>
            </tr>
          </thead>

          <tbody class="bg-white dark:bg-gray-700 divide-y divide-gray-200 dark:divide-gray-600">
            <%= if Enum.empty?(@reservations) do %>
              <tr>
                <td colspan="6" class="px-6 py-8 text-center text-gray-500 dark:text-gray-400">
                  No reservations found
                </td>
              </tr>
            <% else %>
              <%= for reservation <- @reservations do %>
                <tr class="hover:bg-gray-50 dark:hover:bg-gray-600">
                  <td class="px-6 py-4 whitespace-nowrap">
                    <div class="text-sm font-medium text-gray-900 dark:text-gray-100">
                      {reservation.member.fullname}
                    </div>

                    <div class="text-sm text-gray-500 dark:text-gray-400">
                      {reservation.member.identifier}
                    </div>
                  </td>

                  <td class="px-6 py-4">
                    <div class="text-sm text-gray-900 dark:text-gray-100">
                      {reservation.item.collection.title}
                    </div>

                    <div class="text-sm text-gray-500 dark:text-gray-400">
                      {reservation.item.item_code}
                    </div>
                  </td>

                  <td class="px-6 py-4 whitespace-nowrap">
                    <span class={"inline-flex px-2 py-1 text-xs font-semibold rounded-full #{reservation_status_badge_class(reservation.status)}"}>
                      {String.upcase(reservation.status)}
                    </span>
                  </td>

                  <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500 dark:text-gray-400">
                    {format_datetime(reservation.reservation_date)}
                  </td>

                  <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500 dark:text-gray-400">
                    {format_datetime(reservation.expiry_date)}
                  </td>

                  <td class="px-6 py-4 whitespace-nowrap text-sm">
                    <.link
                      navigate={~p"/manage/glam/library/circulation/reservations/#{reservation.id}"}
                      class="text-voile-primary hover:underline font-medium"
                    >
                      View
                    </.link>
                  </td>
                </tr>
              <% end %>
            <% end %>
          </tbody>
        </table>
      </div>
      <%!-- Pagination --%> <.pagination_controls page={@page} total_pages={@total_pages} />
    </div>
    """
  end

  # Fines Tab Component
  defp fines_tab(assigns) do
    ~H"""
    <div>
      <%!-- Search Bar --%>
      <div class="mb-6">
        <.form :let={f} for={%{}} phx-change="search" phx-submit="search">
          <.input
            field={f[:search]}
            type="text"
            placeholder="Search by member name..."
            value={@search_query}
            class="block w-full rounded-lg border border-gray-200 bg-white px-4 py-3 text-sm text-gray-900 shadow-sm placeholder:text-gray-400 transition duration-150 focus:border-voile-primary focus:outline-none focus:ring-2 focus:ring-voile-primary/20 dark:border-gray-600 dark:bg-gray-800 dark:text-gray-100 dark:placeholder:text-gray-500"
            label="Search Fines"
          />
        </.form>
      </div>
      <%!-- Fines Table --%>
      <div class="bg-white dark:bg-gray-700 rounded-lg shadow overflow-hidden">
        <table class="min-w-full divide-y divide-gray-200 dark:divide-gray-600">
          <thead class="bg-gray-50 dark:bg-gray-800">
            <tr>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                Member
              </th>

              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                Type
              </th>

              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                Amount
              </th>

              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                Balance
              </th>

              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                Status
              </th>

              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                Date
              </th>

              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                Actions
              </th>
            </tr>
          </thead>

          <tbody class="bg-white dark:bg-gray-700 divide-y divide-gray-200 dark:divide-gray-600">
            <%= if Enum.empty?(@fines) do %>
              <tr>
                <td colspan="7" class="px-6 py-8 text-center text-gray-500 dark:text-gray-400">
                  No fines found
                </td>
              </tr>
            <% else %>
              <%= for fine <- @fines do %>
                <tr class="hover:bg-gray-50 dark:hover:bg-gray-600">
                  <td class="px-6 py-4 whitespace-nowrap">
                    <div class="text-sm font-medium text-gray-900 dark:text-gray-100">
                      {fine.member.fullname}
                    </div>

                    <div class="text-sm text-gray-500 dark:text-gray-400">
                      {fine.member.identifier}
                    </div>
                  </td>

                  <td class="px-6 py-4 whitespace-nowrap">
                    <span class={"inline-flex px-2 py-1 text-xs font-semibold rounded-full #{fine_type_badge_class(fine.fine_type)}"}>
                      {String.upcase(fine.fine_type)}
                    </span>
                  </td>

                  <td class="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900 dark:text-gray-100">
                    {format_idr(fine.amount)}
                  </td>

                  <td class="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900 dark:text-gray-100">
                    {format_idr(fine.balance)}
                  </td>

                  <td class="px-6 py-4 whitespace-nowrap">
                    <span class={"inline-flex px-2 py-1 text-xs font-semibold rounded-full #{fine_status_badge_class(fine.fine_status)}"}>
                      {String.upcase(fine.fine_status)}
                    </span>
                  </td>

                  <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500 dark:text-gray-400">
                    {format_datetime(fine.inserted_at)}
                  </td>

                  <td class="px-6 py-4 whitespace-nowrap text-sm">
                    <.link
                      navigate={~p"/manage/glam/library/circulation/fines/#{fine.id}"}
                      class="text-voile-primary hover:underline font-medium"
                    >
                      View
                    </.link>
                  </td>
                </tr>
              <% end %>
            <% end %>
          </tbody>
        </table>
      </div>
      <%!-- Pagination --%> <.pagination_controls page={@page} total_pages={@total_pages} />
    </div>
    """
  end

  # Pagination Controls Component
  defp pagination_controls(assigns) do
    ~H"""
    <div class="bg-white dark:bg-gray-700 px-4 py-3 flex items-center justify-between border-t border-gray-200 dark:border-gray-600 sm:px-6 mt-4 rounded-lg shadow">
      <div class="flex-1 flex justify-between sm:hidden">
        <button
          :if={@page > 1}
          phx-click="prev_page"
          class="relative inline-flex items-center px-4 py-2 border border-gray-300 dark:border-gray-600 text-sm font-medium rounded-md text-gray-700 dark:text-gray-300 bg-white dark:bg-gray-800 hover:bg-gray-50 dark:hover:bg-gray-600"
        >
          Previous
        </button>
        <button
          :if={@page < @total_pages}
          phx-click="next_page"
          class="ml-3 relative inline-flex items-center px-4 py-2 border border-gray-300 dark:border-gray-600 text-sm font-medium rounded-md text-gray-700 dark:text-gray-300 bg-white dark:bg-gray-800 hover:bg-gray-50 dark:hover:bg-gray-600"
        >
          Next
        </button>
      </div>

      <div class="hidden sm:flex-1 sm:flex sm:items-center sm:justify-between">
        <div>
          <p class="text-sm text-gray-700 dark:text-gray-300">
            Page <span class="font-medium">{@page}</span>
            of <span class="font-medium">{@total_pages}</span>
          </p>
        </div>

        <div>
          <nav class="relative z-0 inline-flex rounded-md shadow-sm -space-x-px">
            <button
              :if={@page > 1}
              phx-click="prev_page"
              class="relative inline-flex items-center px-2 py-2 rounded-l-md border border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-800 text-sm font-medium text-gray-500 dark:text-gray-400 hover:bg-gray-50 dark:hover:bg-gray-600"
            >
              <.icon name="hero-chevron-left" class="h-5 w-5" />
            </button>
            <button
              :if={@page < @total_pages}
              phx-click="next_page"
              class="relative inline-flex items-center px-2 py-2 rounded-r-md border border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-800 text-sm font-medium text-gray-500 dark:text-gray-400 hover:bg-gray-50 dark:hover:bg-gray-600"
            >
              <.icon name="hero-chevron-right" class="h-5 w-5" />
            </button>
          </nav>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    # Check if user has basic circulation viewing permission
    # This is available to all library staff, not just super_admin
    unless Authorization.can?(socket, "circulation.view_transactions") do
      socket =
        socket
        |> put_flash(:error, "You don't have permission to access circulation reports")
        |> push_navigate(to: ~p"/manage/glam/library")

      {:ok, socket}
    else
      # Assign placeholders and load heavy data asynchronously
      socket =
        socket
        |> assign(:page_title, "Circulation Report")
        |> assign(:active_tab, "overview")
        |> assign(:stats, %{
          active_transactions: nil,
          overdue_count: nil,
          active_reservations: nil,
          outstanding_fines: nil
        })
        |> assign(:recent_activities, [])
        |> assign(:transactions, [])
        |> assign(:reservations, [])
        |> assign(:fines, [])
        |> assign(:page, 1)
        |> assign(:total_pages, 1)
        |> assign(:search_query, "")

      # Expose node list for super_admin so they can filter stats per node
      current_user = socket.assigns.current_scope.user
      is_super_admin = Authorization.is_super_admin?(current_user)

      socket = assign(socket, :is_super_admin, is_super_admin)

      socket =
        if is_super_admin do
          nodes = VoileSystem.list_nodes()

          socket
          |> assign(:nodes, nodes)
          |> assign(:selected_node_id, nil)
        else
          socket |> assign(:nodes, []) |> assign(:selected_node_id, current_user.node_id)
        end

      # Trigger async load of stats and recent activities
      if connected?(socket), do: send(self(), :load_stats)

      {:ok, socket}
    end
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_info(:load_stats, socket) do
    # Perform DB queries asynchronously and scope by user's node/unit unless super_admin
    current_user = socket.assigns.current_scope.user

    # Allow super_admin to select a node; if selected_node_id is set, override
    # the user's node_id when computing scoped stats.
    node_id =
      if Authorization.is_super_admin?(current_user) and
           Map.has_key?(socket.assigns, :selected_node_id) and
           not is_nil(socket.assigns.selected_node_id) do
        socket.assigns.selected_node_id
      else
        current_user.node_id
      end

    stats = Voile.get_circulation_stats(node_id)

    {recent_activities, _, _} = Circulation.list_circulation_history_paginated(1, 10)

    {:noreply,
     socket
     |> assign(:stats, stats)
     |> assign(:recent_activities, recent_activities || [])}
  end

  @impl true
  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    socket =
      socket
      |> assign(:active_tab, tab)
      |> assign(:page, 1)
      |> assign(:search_query, "")

    socket =
      case tab do
        "transactions" -> load_transactions(socket)
        "reservations" -> load_reservations(socket)
        "fines" -> load_fines(socket)
        _ -> socket
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("search", %{"search" => search_query}, socket) do
    socket =
      socket
      |> assign(:search_query, search_query)
      |> assign(:page, 1)

    socket =
      case socket.assigns.active_tab do
        "transactions" -> load_transactions(socket)
        "reservations" -> load_reservations(socket)
        "fines" -> load_fines(socket)
        _ -> socket
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("prev_page", _params, socket) do
    page = max(socket.assigns.page - 1, 1)
    socket = assign(socket, :page, page)

    socket =
      case socket.assigns.active_tab do
        "transactions" -> load_transactions(socket)
        "reservations" -> load_reservations(socket)
        "fines" -> load_fines(socket)
        _ -> socket
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("next_page", _params, socket) do
    page = min(socket.assigns.page + 1, socket.assigns.total_pages)
    socket = assign(socket, :page, page)

    socket =
      case socket.assigns.active_tab do
        "transactions" -> load_transactions(socket)
        "reservations" -> load_reservations(socket)
        "fines" -> load_fines(socket)
        _ -> socket
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("select_node", %{"node_id" => node_id_str}, socket) do
    current_user = socket.assigns.current_scope.user

    socket =
      if Authorization.is_super_admin?(current_user) do
        selected_node_id =
          case node_id_str do
            "all" -> nil
            id -> String.to_integer(id)
          end

        socket
        |> assign(:selected_node_id, selected_node_id)
        |> assign(:stats, %{
          active_transactions: nil,
          overdue_count: nil,
          active_reservations: nil,
          outstanding_fines: nil
        })
        |> then(fn s ->
          send(self(), :load_stats)
          s
        end)
      else
        socket
      end

    {:noreply, socket}
  end

  # Data loading functions for each tab
  defp load_transactions(socket) do
    current_user = socket.assigns.current_scope.user
    page = socket.assigns.page
    search_query = socket.assigns.search_query
    per_page = 15

    filters =
      if search_query != "" do
        %{query: search_query}
      else
        %{}
      end

    {transactions, total_pages, _} =
      if Authorization.is_super_admin?(current_user) and is_nil(socket.assigns.selected_node_id) do
        Circulation.list_transaction_paginated_with_filter(page, per_page, filters)
      else
        node_id = socket.assigns.selected_node_id || current_user.node_id

        Circulation.list_transaction_paginated_with_filter_by_node(
          page,
          per_page,
          filters,
          node_id
        )
      end

    socket
    |> assign(:transactions, transactions)
    |> assign(:total_pages, total_pages)
  end

  defp load_reservations(socket) do
    current_user = socket.assigns.current_scope.user
    page = socket.assigns.page
    search_query = socket.assigns.search_query
    per_page = 15

    filters =
      if search_query != "" do
        %{search: search_query}
      else
        %{}
      end

    {reservations, total_pages, _} =
      if Authorization.is_super_admin?(current_user) and is_nil(socket.assigns.selected_node_id) do
        Circulation.list_reservations_paginated_with_filters(page, per_page, filters)
      else
        node_id = socket.assigns.selected_node_id || current_user.node_id

        Circulation.list_reservations_paginated_with_filters_by_node(
          page,
          per_page,
          filters,
          node_id
        )
      end

    socket
    |> assign(:reservations, reservations)
    |> assign(:total_pages, total_pages)
  end

  defp load_fines(socket) do
    current_user = socket.assigns.current_scope.user
    page = socket.assigns.page
    search_query = socket.assigns.search_query
    per_page = 15

    filters =
      if search_query != "" do
        %{search: search_query}
      else
        %{}
      end

    {fines, total_pages, _} =
      if Authorization.is_super_admin?(current_user) and is_nil(socket.assigns.selected_node_id) do
        Circulation.list_fines_paginated_with_filters(page, per_page, filters)
      else
        node_id = socket.assigns.selected_node_id || current_user.node_id
        Circulation.list_fines_paginated_with_filters_by_node(page, per_page, filters, node_id)
      end

    socket
    |> assign(:fines, fines)
    |> assign(:total_pages, total_pages)
  end

  # Helper function for activity color (not in imported helpers)
  defp activity_color("checkout"), do: "bg-blue-500"
  defp activity_color("return"), do: "bg-green-500"
  defp activity_color("renewal"), do: "bg-yellow-500"
  defp activity_color("reservation"), do: "bg-purple-500"
  defp activity_color("fine_paid"), do: "bg-green-600"
  defp activity_color(_), do: "bg-gray-500"
end
