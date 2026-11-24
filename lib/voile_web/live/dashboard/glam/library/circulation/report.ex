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

        <p class="mt-2 text-secondary">
          View circulation statistics and activity (read-only)
        </p>
      </div>
      <%!-- Tabs Navigation --%>
      <div class="mb-6">
        <div class="border-b border-subtle">
          <nav class="-mb-px flex space-x-8">
            <button
              :for={tab <- @tabs}
              phx-click="switch_tab"
              phx-value-tab={tab.id}
              class={[
                "whitespace-nowrap pb-4 px-1 border-b-2 font-medium text-sm",
                if(@active_tab == tab.id,
                  do:
                    "border-voile-primary text-voile-primary dark:border-voile-primary/60 dark:text-voile-primary/60",
                  else:
                    "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300 dark:text-gray-400 dark:hover:text-gray-300"
                )
              ]}
            >
              {tab.label}
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
            detailed_stats={@detailed_stats}
            filter_year={@filter_year}
            filter_month={@filter_month}
            year_options={@year_options}
            month_options={@month_options}
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
        <% "usability" -> %>
          <.usability_tab
            is_super_admin={@is_super_admin}
            nodes={@nodes}
            selected_node_id={@selected_node_id}
            filter_year={@usability_filter_year}
            filter_month={@usability_filter_month}
            year_options={@year_options}
            month_options={@month_options}
            stats={@usability_stats}
            pages={@usability_pages}
          />
      <% end %>
    </div>
    """
  end

  # Overview Tab Component
  defp overview_tab(assigns) do
    ~H"""
    <div id="overview-tab">
      <.filters_row
        is_super_admin={@is_super_admin}
        nodes={@nodes}
        selected_node_id={@selected_node_id}
        filter_year={@filter_year}
        filter_month={@filter_month}
        year_options={@year_options}
        month_options={@month_options}
      />
      <%!-- Statistics Section --%>
      <.circulation_stats stats={@stats} />
      <%!-- Detailed Statistics Breakdown --%>
      <.detailed_circulation_stats detailed_stats={@detailed_stats} loading={is_nil(@detailed_stats)} />
      <%!-- Recent Activities Section --%>
      <div class="surface-card rounded-lg shadow p-6 mb-8">
        <h2 class="text-xl font-semibold text-primary mb-4">Recent Activity</h2>

        <div class="space-y-4">
          <%= if Enum.empty?(@recent_activities) do %>
            <p class="text-tertiary text-center py-8">
              No recent activities to display
            </p>
          <% else %>
            <%= for activity <- @recent_activities do %>
              <div class="flex items-center justify-between py-3 border-b border-subtle last:border-0">
                <div class="flex items-start">
                  <div class="flex items-center justify-center w-10 h-10">
                    <div class={"w-2 h-2 rounded-full #{activity_color(activity.event_type)}"}></div>
                  </div>

                  <div class="ml-4">
                    <p class="text-sm text-gray-900 dark:text-gray-100">{activity.description}</p>

                    <p class="text-xs text-tertiary">
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
        <div class="surface-card rounded-lg shadow p-6">
          <h2 class="text-xl font-semibold text-primary mb-4">
            Quick Links (Admin)
          </h2>

          <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
            <.link
              navigate="/manage/glam/library/circulation/transactions"
              class="flex items-center p-4 bg-gray-50 dark:bg-gray-600 rounded-lg hover:bg-gray-100 dark:hover:bg-gray-500 transition-colors"
            >
              <.icon name="hero-document-text" class="w-6 h-6 text-blue-500 mr-3" />
              <span class="text-sm font-medium text-primary">
                View All Transactions
              </span>
            </.link>
            <.link
              navigate="/manage/glam/library/circulation/reservations"
              class="flex items-center p-4 bg-gray-50 dark:bg-gray-600 rounded-lg hover:bg-gray-100 dark:hover:bg-gray-500 transition-colors"
            >
              <.icon name="hero-bookmark" class="w-6 h-6 text-green-500 mr-3" />
              <span class="text-sm font-medium text-primary">View Reservations</span>
            </.link>
            <.link
              navigate="/manage/glam/library/circulation/fines"
              class="flex items-center p-4 bg-gray-50 dark:bg-gray-600 rounded-lg hover:bg-gray-100 dark:hover:bg-gray-500 transition-colors"
            >
              <.icon name="hero-banknotes" class="w-6 h-6 text-red-500 mr-3" />
              <span class="text-sm font-medium text-primary">View Fines</span>
            </.link>
            <.link
              navigate="/manage/glam/library/circulation/circulation_history"
              class="flex items-center p-4 bg-gray-50 dark:bg-gray-600 rounded-lg hover:bg-gray-100 dark:hover:bg-gray-500 transition-colors"
            >
              <.icon name="hero-clock" class="w-6 h-6 text-purple-500 mr-3" />
              <span class="text-sm font-medium text-primary">View History</span>
            </.link>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  # Shared node/year/month filter row (used by Overview and Usability tabs)
  attr :is_super_admin, :boolean, required: true
  attr :nodes, :list, default: []
  attr :selected_node_id, :integer, default: nil
  attr :filter_year, :integer, default: nil
  attr :filter_month, :integer, default: nil
  attr :year_options, :list, required: true
  attr :month_options, :list, required: true
  attr :year_event, :string, default: "filter_year"
  attr :month_event, :string, default: "filter_month"

  defp filters_row(assigns) do
    ~H"""
    <div class="mb-6 flex flex-wrap gap-4 items-end">
      <%= if @is_super_admin do %>
        <div class="w-48">
          <.form :let={f} for={%{}} phx-change="select_node">
            <.input
              field={f[:node_id]}
              type="select"
              options={
                [{gettext("All Nodes"), "all"}] ++
                  Enum.map(@nodes || [], fn n -> {n.name, to_string(n.id)} end)
              }
              value={if @selected_node_id, do: to_string(@selected_node_id), else: "all"}
              label={gettext("Node")}
            />
          </.form>
        </div>
      <% end %>
      <div class="w-36">
        <.form :let={f} for={%{}} phx-change={@year_event}>
          <.input
            field={f[:year]}
            type="select"
            options={@year_options}
            value={if @filter_year, do: @filter_year, else: ""}
            label={gettext("Year")}
          />
        </.form>
      </div>
      <div class="w-44">
        <.form :let={f} for={%{}} phx-change={@month_event}>
          <.input
            field={f[:month]}
            type="select"
            options={@month_options}
            value={if @filter_month, do: @filter_month, else: ""}
            label={gettext("Month")}
            disabled={is_nil(@filter_year)}
          />
        </.form>
      </div>
    </div>
    """
  end

  # Usability Tab Component
  @usability_per_page 5

  defp usability_tab(assigns) do
    ~H"""
    <div id="usability-tab">
      <.filters_row
        is_super_admin={@is_super_admin}
        nodes={@nodes}
        selected_node_id={@selected_node_id}
        filter_year={@filter_year}
        filter_month={@filter_month}
        year_options={@year_options}
        month_options={@month_options}
        year_event="usability_filter_year"
        month_event="usability_filter_month"
      />
      <%!-- Summary Cards: Total Loans spans the full first row (flex),
           the other two share a grid row --%>
      <div class="mb-8 space-y-6">
        <div class="flex">
          <.usability_summary_card
            class="flex-1"
            icon="hero-arrow-right-circle"
            icon_color="text-blue-500"
            border_color="border-blue-500"
            label={gettext("Total Loans")}
            value={usability_summary_value(@stats, :total_loans)}
          />
        </div>

        <div class="grid grid-cols-1 sm:grid-cols-2 gap-6">
          <.usability_summary_card
            icon="hero-user-circle"
            icon_color="text-green-500"
            border_color="border-green-500"
            label={gettext("Unique Borrowers")}
            value={usability_summary_value(@stats, :unique_borrowers)}
          />
          <.usability_summary_card
            icon="hero-user-group"
            icon_color="text-purple-500"
            border_color="border-purple-500"
            label={gettext("Library Visits")}
            value={usability_summary_value(@stats, :total_visits)}
          />
        </div>
      </div>
      <%!-- Rankings: Most Loaned Titles spans the full first row (flex),
           Members & Visitors share a grid row --%>
      <div class="space-y-6">
        <div class="flex">
          <.usability_ranking_card
            class="flex-1"
            list="collections"
            icon="hero-book-open"
            icon_color="text-blue-500"
            title={gettext("Most Loaned Titles")}
            name_label={gettext("Title")}
            count_label={gettext("Loans")}
            empty_text={gettext("No loans recorded for this period")}
            rows={usability_ranking_rows(@stats, :top_collections)}
            page={Map.get(@pages, "collections", 1)}
          />
        </div>

        <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
          <.usability_ranking_card
            list="members"
            icon="hero-user-circle"
            icon_color="text-green-500"
            title={gettext("Most Active Members")}
            name_label={gettext("Member")}
            count_label={gettext("Loans")}
            empty_text={gettext("No loans recorded for this period")}
            rows={usability_ranking_rows(@stats, :top_members)}
            page={Map.get(@pages, "members", 1)}
          />
          <.usability_ranking_card
            list="visitors"
            icon="hero-user-group"
            icon_color="text-purple-500"
            title={gettext("Most Frequent Visitors")}
            name_label={gettext("Visitor")}
            count_label={gettext("Visits")}
            empty_text={gettext("No visits recorded for this period")}
            rows={usability_ranking_rows(@stats, :top_visitors)}
            page={Map.get(@pages, "visitors", 1)}
          />
        </div>
      </div>
    </div>
    """
  end

  attr :icon, :string, required: true
  attr :icon_color, :string, required: true
  attr :border_color, :string, required: true
  attr :label, :string, required: true
  attr :value, :integer, default: nil
  attr :class, :string, default: nil

  defp usability_summary_card(assigns) do
    ~H"""
    <div class={["surface-card rounded-lg shadow p-6 border-l-4", @border_color, @class]}>
      <div class="flex items-center">
        <div class="flex-shrink-0">
          <.icon name={@icon} class={"w-8 h-8 #{@icon_color}"} />
        </div>

        <div class="ml-4 min-w-0">
          <h3 class="text-sm font-medium text-tertiary">{@label}</h3>

          <p class="text-2xl font-semibold text-gray-900 dark:text-gray-100 truncate">
            <%= if is_nil(@value) do %>
              <.loading_spinner size_class="h-6 w-6" />
            <% else %>
              {@value}
            <% end %>
          </p>
        </div>
      </div>
    </div>
    """
  end

  attr :list, :string, required: true
  attr :icon, :string, required: true
  attr :icon_color, :string, required: true
  attr :title, :string, required: true
  attr :name_label, :string, required: true
  attr :count_label, :string, required: true
  attr :empty_text, :string, required: true
  attr :rows, :list, required: true
  attr :page, :integer, required: true
  attr :class, :string, default: nil

  defp usability_ranking_card(assigns) do
    ~H"""
    <div class={["surface-card rounded-lg shadow p-6 flex flex-col", @class]}>
      <div class="flex items-center mb-4">
        <.icon name={@icon} class={"w-5 h-5 #{@icon_color} mr-2"} />
        <h3 class="text-base font-semibold text-gray-900 dark:text-gray-100">{@title}</h3>
      </div>

      <%= if is_nil(@rows) do %>
        <div class="animate-pulse space-y-2 flex-1">
          <div class="h-4 surface-raised rounded w-full"></div>
          <div class="h-4 surface-raised rounded w-5/6"></div>
          <div class="h-4 surface-raised rounded w-4/6"></div>
        </div>
      <% else %>
        <p :if={Enum.empty?(@rows)} class="text-tertiary text-center py-8 flex-1">
          {@empty_text}
        </p>

        <%= if not Enum.empty?(@rows) do %>
          <table class="w-full table-fixed">
            <thead>
              <tr>
                <th class="pb-2 text-left text-xs font-medium text-tertiary uppercase tracking-wider w-8">
                  #
                </th>

                <th class="pb-2 text-left text-xs font-medium text-tertiary uppercase tracking-wider">
                  {@name_label}
                </th>

                <th class="pb-2 text-right text-xs font-medium text-tertiary uppercase tracking-wider w-20">
                  {@count_label}
                </th>
              </tr>
            </thead>

            <tbody class="divide-y divide-gray-200 dark:divide-gray-600">
              <tr :for={row <- ranked_usability_rows(@rows, @page)}>
                <td class="py-2 pr-2 text-sm text-tertiary align-top">{row.rank}</td>
                <td class="py-2 pr-2 min-w-0">
                  <div
                    class="text-sm font-medium text-gray-900 dark:text-gray-100 truncate"
                    title={row.primary}
                  >
                    {row.primary}
                  </div>

                  <div
                    :if={row.secondary}
                    class="text-xs text-tertiary truncate"
                    title={row.secondary}
                  >
                    {row.secondary}
                  </div>
                </td>
                <td class="py-2 text-right text-sm font-semibold text-gray-700 dark:text-gray-200 whitespace-nowrap align-top">
                  {row.count}
                </td>
              </tr>
            </tbody>
          </table>
          <.usability_pagination list={@list} page={@page} total_pages={usability_total_pages(@rows)} />
        <% end %>
      <% end %>
    </div>
    """
  end

  defp usability_pagination(assigns) do
    ~H"""
    <div class="mt-4 pt-3 border-t border-subtle flex items-center justify-between">
      <span class="text-xs text-tertiary">
        {gettext("Page")} {@page} / {@total_pages}
      </span>

      <div class="flex items-center gap-2">
        <button
          type="button"
          phx-click="usability_prev_page"
          phx-value-list={@list}
          disabled={@page <= 1}
          class="p-1.5 rounded border border-subtle text-tertiary hover:bg-gray-50 dark:hover:bg-gray-600 disabled:opacity-40 disabled:cursor-not-allowed"
        >
          <.icon name="hero-chevron-left" class="h-4 w-4" />
        </button>
        <button
          type="button"
          phx-click="usability_next_page"
          phx-value-list={@list}
          disabled={@page >= @total_pages}
          class="p-1.5 rounded border border-subtle text-tertiary hover:bg-gray-50 dark:hover:bg-gray-600 disabled:opacity-40 disabled:cursor-not-allowed"
        >
          <.icon name="hero-chevron-right" class="h-4 w-4" />
        </button>
      </div>
    </div>
    """
  end

  attr :size_class, :string, default: "h-6 w-6"

  defp loading_spinner(assigns) do
    ~H"""
    <svg
      class={"animate-spin inline-block text-gray-600 #{@size_class}"}
      xmlns="http://www.w3.org/2000/svg"
      fill="none"
      viewBox="0 0 24 24"
    >
      <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4">
      </circle>
      <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8v4a4 4 0 00-4 4H4z"></path>
    </svg>
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
      <div class="surface-card rounded-lg shadow overflow-hidden">
        <table class="min-w-full divide-y divide-gray-200 dark:divide-gray-600">
          <thead class="bg-gray-50 dark:bg-gray-800">
            <tr>
              <th class="px-6 py-3 text-left text-xs font-medium text-tertiary uppercase tracking-wider">
                Member
              </th>

              <th class="px-6 py-3 text-left text-xs font-medium text-tertiary uppercase tracking-wider">
                Item
              </th>

              <th class="px-6 py-3 text-left text-xs font-medium text-tertiary uppercase tracking-wider">
                Status
              </th>

              <th class="px-6 py-3 text-left text-xs font-medium text-tertiary uppercase tracking-wider">
                Checkout Date
              </th>

              <th class="px-6 py-3 text-left text-xs font-medium text-tertiary uppercase tracking-wider">
                Due Date
              </th>

              <th class="px-6 py-3 text-left text-xs font-medium text-tertiary uppercase tracking-wider">
                Actions
              </th>
            </tr>
          </thead>

          <tbody class="surface-card divide-y divide-gray-200 dark:divide-gray-600">
            <%= if Enum.empty?(@transactions) do %>
              <tr>
                <td colspan="6" class="px-6 py-8 text-center text-tertiary">
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

                    <div class="text-sm text-tertiary">
                      {transaction.member.identifier}
                    </div>
                  </td>

                  <td class="px-6 py-4">
                    <div class="text-sm text-gray-900 dark:text-gray-100">
                      {transaction.item.collection.title}
                    </div>

                    <div class="text-sm text-tertiary">
                      {transaction.item.item_code}
                    </div>
                  </td>

                  <td class="px-6 py-4 whitespace-nowrap">
                    <span class={"inline-flex px-2 py-1 text-xs font-semibold rounded-full #{status_badge_class(transaction.status)}"}>
                      {String.upcase(transaction.status)}
                    </span>
                  </td>

                  <td class="px-6 py-4 whitespace-nowrap text-sm text-tertiary">
                    {format_datetime(transaction.transaction_date)}
                  </td>

                  <td class="px-6 py-4 whitespace-nowrap text-sm text-tertiary">
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
      <div class="surface-card rounded-lg shadow overflow-hidden">
        <table class="min-w-full divide-y divide-gray-200 dark:divide-gray-600">
          <thead class="bg-gray-50 dark:bg-gray-800">
            <tr>
              <th class="px-6 py-3 text-left text-xs font-medium text-tertiary uppercase tracking-wider">
                Member
              </th>

              <th class="px-6 py-3 text-left text-xs font-medium text-tertiary uppercase tracking-wider">
                Item
              </th>

              <th class="px-6 py-3 text-left text-xs font-medium text-tertiary uppercase tracking-wider">
                Status
              </th>

              <th class="px-6 py-3 text-left text-xs font-medium text-tertiary uppercase tracking-wider">
                Reserved On
              </th>

              <th class="px-6 py-3 text-left text-xs font-medium text-tertiary uppercase tracking-wider">
                Expiry
              </th>

              <th class="px-6 py-3 text-left text-xs font-medium text-tertiary uppercase tracking-wider">
                Actions
              </th>
            </tr>
          </thead>

          <tbody class="surface-card divide-y divide-gray-200 dark:divide-gray-600">
            <%= if Enum.empty?(@reservations) do %>
              <tr>
                <td colspan="6" class="px-6 py-8 text-center text-tertiary">
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

                    <div class="text-sm text-tertiary">
                      {reservation.member.identifier}
                    </div>
                  </td>

                  <td class="px-6 py-4">
                    <div class="text-sm text-gray-900 dark:text-gray-100">
                      {reservation.item.collection.title}
                    </div>

                    <div class="text-sm text-tertiary">
                      {reservation.item.item_code}
                    </div>
                  </td>

                  <td class="px-6 py-4 whitespace-nowrap">
                    <span class={"inline-flex px-2 py-1 text-xs font-semibold rounded-full #{reservation_status_badge_class(reservation.status)}"}>
                      {String.upcase(reservation.status)}
                    </span>
                  </td>

                  <td class="px-6 py-4 whitespace-nowrap text-sm text-tertiary">
                    {format_datetime(reservation.reservation_date)}
                  </td>

                  <td class="px-6 py-4 whitespace-nowrap text-sm text-tertiary">
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
      <div class="surface-card rounded-lg shadow overflow-hidden">
        <table class="min-w-full divide-y divide-gray-200 dark:divide-gray-600">
          <thead class="bg-gray-50 dark:bg-gray-800">
            <tr>
              <th class="px-6 py-3 text-left text-xs font-medium text-tertiary uppercase tracking-wider">
                Member
              </th>

              <th class="px-6 py-3 text-left text-xs font-medium text-tertiary uppercase tracking-wider">
                Type
              </th>

              <th class="px-6 py-3 text-left text-xs font-medium text-tertiary uppercase tracking-wider">
                Amount
              </th>

              <th class="px-6 py-3 text-left text-xs font-medium text-tertiary uppercase tracking-wider">
                Balance
              </th>

              <th class="px-6 py-3 text-left text-xs font-medium text-tertiary uppercase tracking-wider">
                Status
              </th>

              <th class="px-6 py-3 text-left text-xs font-medium text-tertiary uppercase tracking-wider">
                Date
              </th>

              <th class="px-6 py-3 text-left text-xs font-medium text-tertiary uppercase tracking-wider">
                Actions
              </th>
            </tr>
          </thead>

          <tbody class="surface-card divide-y divide-gray-200 dark:divide-gray-600">
            <%= if Enum.empty?(@fines) do %>
              <tr>
                <td colspan="7" class="px-6 py-8 text-center text-tertiary">
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

                    <div class="text-sm text-tertiary">
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

                  <td class="px-6 py-4 whitespace-nowrap text-sm text-tertiary">
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
    <div class="surface-card px-4 py-3 flex items-center justify-between border-t border-subtle sm:px-6 mt-4 rounded-lg shadow">
      <div class="flex-1 flex justify-between sm:hidden">
        <button
          :if={@page > 1}
          phx-click="prev_page"
          class="relative inline-flex items-center px-4 py-2 border border-gray-300 dark:border-gray-600 text-sm font-medium rounded-md text-secondary surface-card hover:bg-gray-50 dark:hover:bg-gray-600"
        >
          Previous
        </button>
        <button
          :if={@page < @total_pages}
          phx-click="next_page"
          class="ml-3 relative inline-flex items-center px-4 py-2 border border-gray-300 dark:border-gray-600 text-sm font-medium rounded-md text-secondary surface-card hover:bg-gray-50 dark:hover:bg-gray-600"
        >
          Next
        </button>
      </div>

      <div class="hidden sm:flex-1 sm:flex sm:items-center sm:justify-between">
        <div>
          <p class="text-sm text-secondary">
            Page <span class="font-medium">{@page}</span>
            of <span class="font-medium">{@total_pages}</span>
          </p>
        </div>

        <div>
          <nav class="relative z-0 inline-flex rounded-md shadow-sm -space-x-px">
            <button
              :if={@page > 1}
              phx-click="prev_page"
              class="relative inline-flex items-center px-2 py-2 rounded-l-md border border-gray-300 dark:border-gray-600 surface-card text-sm font-medium text-tertiary hover:bg-gray-50 dark:hover:bg-gray-600"
            >
              <.icon name="hero-chevron-left" class="h-5 w-5" />
            </button>
            <button
              :if={@page < @total_pages}
              phx-click="next_page"
              class="relative inline-flex items-center px-2 py-2 rounded-r-md border border-gray-300 dark:border-gray-600 surface-card text-sm font-medium text-tertiary hover:bg-gray-50 dark:hover:bg-gray-600"
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
        |> assign(:tabs, [
          %{id: "overview", label: gettext("Overview")},
          %{id: "transactions", label: gettext("Transactions")},
          %{id: "reservations", label: gettext("Reservations")},
          %{id: "fines", label: gettext("Fines")},
          %{id: "usability", label: gettext("Usability")}
        ])
        |> assign(:stats, %{
          active_transactions: nil,
          overdue_count: nil,
          active_reservations: nil,
          outstanding_fines: nil
        })
        |> assign(:detailed_stats, nil)
        |> assign(:filter_year, nil)
        |> assign(:filter_month, nil)
        |> assign(:year_options, year_options())
        |> assign(:month_options, month_options())
        |> assign(:recent_activities, [])
        |> assign(:transactions, [])
        |> assign(:reservations, [])
        |> assign(:fines, [])
        |> assign(:page, 1)
        |> assign(:total_pages, 1)
        |> assign(:search_query, "")
        |> assign(:usability_stats, nil)
        |> assign(:usability_filter_year, Date.utc_today().year)
        |> assign(:usability_filter_month, Date.utc_today().month)
        |> assign(:usability_pages, reset_usability_pages())

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
    node_id = resolved_node_id(socket)

    stats = Voile.get_circulation_stats(node_id)

    opts =
      []
      |> then(fn o ->
        if y = socket.assigns.filter_year, do: Keyword.put(o, :year, y), else: o
      end)
      |> then(fn o ->
        if m = socket.assigns.filter_month, do: Keyword.put(o, :month, m), else: o
      end)

    detailed_stats = Voile.get_detailed_circulation_stats(node_id, opts)

    {recent_activities, _, _} = Circulation.list_circulation_history_paginated(1, 10)

    {:noreply,
     socket
     |> assign(:stats, stats)
     |> assign(:detailed_stats, detailed_stats)
     |> assign(:recent_activities, recent_activities || [])}
  end

  @impl true
  def handle_info(:load_usability, socket) do
    node_id = resolved_node_id(socket)

    opts =
      []
      |> maybe_put_opt(:year, socket.assigns.usability_filter_year)
      |> maybe_put_opt(:month, socket.assigns.usability_filter_month)

    usability_stats = Voile.get_usability_stats(node_id, opts)

    {:noreply, assign(socket, :usability_stats, usability_stats)}
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
        "usability" -> maybe_load_usability(socket)
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

        socket = assign(socket, :selected_node_id, selected_node_id)

        case socket.assigns.active_tab do
          "usability" ->
            socket
            |> assign(:usability_stats, nil)
            |> then(fn s ->
              send(self(), :load_usability)
              s
            end)

          _ ->
            socket
            |> assign(:stats, %{
              active_transactions: nil,
              overdue_count: nil,
              active_reservations: nil,
              outstanding_fines: nil
            })
            |> assign(:detailed_stats, nil)
            |> then(fn s ->
              send(self(), :load_stats)
              s
            end)
        end
      else
        socket
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("filter_year", %{"year" => year_str}, socket) do
    filter_year =
      case year_str do
        "" -> nil
        y -> String.to_integer(y)
      end

    socket =
      socket
      |> assign(:filter_year, filter_year)
      |> assign(:filter_month, nil)
      |> assign(:detailed_stats, nil)
      |> then(fn s ->
        send(self(), :load_stats)
        s
      end)

    {:noreply, socket}
  end

  @impl true
  def handle_event("filter_month", %{"month" => month_str}, socket) do
    filter_month =
      case month_str do
        "" -> nil
        m -> String.to_integer(m)
      end

    socket =
      socket
      |> assign(:filter_month, filter_month)
      |> assign(:detailed_stats, nil)
      |> then(fn s ->
        send(self(), :load_stats)
        s
      end)

    {:noreply, socket}
  end

  @impl true
  def handle_event("usability_filter_year", %{"year" => year_str}, socket) do
    filter_year =
      case year_str do
        "" -> nil
        y -> String.to_integer(y)
      end

    socket =
      socket
      |> assign(:usability_filter_year, filter_year)
      |> assign(:usability_filter_month, nil)
      |> assign(:usability_stats, nil)
      |> assign(:usability_pages, reset_usability_pages())
      |> then(fn s ->
        send(self(), :load_usability)
        s
      end)

    {:noreply, socket}
  end

  @impl true
  def handle_event("usability_filter_month", %{"month" => month_str}, socket) do
    filter_month =
      case month_str do
        "" -> nil
        m -> String.to_integer(m)
      end

    socket =
      socket
      |> assign(:usability_filter_month, filter_month)
      |> assign(:usability_stats, nil)
      |> assign(:usability_pages, reset_usability_pages())
      |> then(fn s ->
        send(self(), :load_usability)
        s
      end)

    {:noreply, socket}
  end

  @impl true
  def handle_event("usability_prev_page", %{"list" => list}, socket) do
    {:noreply, update_usability_page(socket, list, -1)}
  end

  @impl true
  def handle_event("usability_next_page", %{"list" => list}, socket) do
    {:noreply, update_usability_page(socket, list, 1)}
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

  defp year_options do
    current_year = Date.utc_today().year
    [{"All Years", ""} | Enum.map(current_year..2020//-1, fn y -> {to_string(y), y} end)]
  end

  defp month_options do
    [
      {"All Months", ""},
      {"January", 1},
      {"February", 2},
      {"March", 3},
      {"April", 4},
      {"May", 5},
      {"June", 6},
      {"July", 7},
      {"August", 8},
      {"September", 9},
      {"October", 10},
      {"November", 11},
      {"December", 12}
    ]
  end

  # Usability tab helpers

  @usability_ranking_keys %{
    "collections" => :top_collections,
    "members" => :top_members,
    "visitors" => :top_visitors
  }

  defp resolved_node_id(socket) do
    current_user = socket.assigns.current_scope.user

    # Allow super_admin to select a node; if selected_node_id is set, override
    # the user's node_id when computing scoped stats.
    if Authorization.is_super_admin?(current_user) and
         Map.has_key?(socket.assigns, :selected_node_id) and
         not is_nil(socket.assigns.selected_node_id) do
      socket.assigns.selected_node_id
    else
      current_user.node_id
    end
  end

  defp maybe_put_opt(opts, _key, nil), do: opts
  defp maybe_put_opt(opts, key, value), do: Keyword.put(opts, key, value)

  # Lazily load usability stats the first time the tab is opened
  defp maybe_load_usability(socket) do
    if is_nil(socket.assigns.usability_stats) do
      send(self(), :load_usability)
    end

    socket
  end

  defp reset_usability_pages, do: %{"collections" => 1, "members" => 1, "visitors" => 1}

  defp update_usability_page(socket, list, delta) do
    current = Map.get(socket.assigns.usability_pages, list, 1)
    max_page = usability_max_page(socket.assigns.usability_stats, list)
    next_page = (current + delta) |> max(1) |> min(max_page)

    pages = Map.put(socket.assigns.usability_pages, list, next_page)

    assign(socket, :usability_pages, pages)
  end

  defp usability_max_page(nil, _list), do: 1

  defp usability_max_page(stats, list) do
    case Map.fetch(@usability_ranking_keys, list) do
      {:ok, key} -> stats |> Map.get(key, []) |> usability_total_pages()
      :error -> 1
    end
  end

  defp usability_summary_value(nil, _key), do: nil
  defp usability_summary_value(stats, key), do: Map.get(stats.summary, key)

  defp usability_ranking_rows(nil, _key), do: nil
  defp usability_ranking_rows(stats, key), do: Map.get(stats, key, [])

  defp usability_total_pages(rows) do
    rows
    |> length()
    |> then(&ceil(&1 / @usability_per_page))
    |> max(1)
  end

  defp ranked_usability_rows(rows, page) do
    offset = (page - 1) * @usability_per_page

    rows
    |> Enum.drop(offset)
    |> Enum.take(@usability_per_page)
    |> Enum.with_index(offset + 1)
    |> Enum.map(fn {row, rank} ->
      %{
        rank: rank,
        primary: usability_row_primary(row),
        secondary: usability_row_secondary(row),
        count: usability_row_count(row)
      }
    end)
  end

  defp usability_row_primary(%{title: title}), do: title
  defp usability_row_primary(%{fullname: fullname}), do: fullname
  defp usability_row_primary(%{identifier: identifier, name: name}), do: name || identifier

  defp usability_row_secondary(%{fullname: _fullname, identifier: nil}), do: nil

  defp usability_row_secondary(%{fullname: _fullname, identifier: identifier}) do
    Decimal.to_string(identifier)
  end

  defp usability_row_secondary(%{identifier: identifier}), do: identifier
  defp usability_row_secondary(_row), do: nil

  defp usability_row_count(%{loan_count: count}), do: count
  defp usability_row_count(%{visit_count: count}), do: count
end
