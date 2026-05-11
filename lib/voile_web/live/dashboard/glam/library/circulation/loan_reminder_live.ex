defmodule VoileWeb.Dashboard.Glam.Library.Circulation.LoanReminderLive do
  @moduledoc """
  LiveView for librarians to manually send loan reminders to members.

  Features:
  - Lists all members with active loans
  - Shows loan count and due dates per member
  - Allows sending manual reminders via email
  - Pagination and search functionality
  - View member's active loans in detail
  """

  use VoileWeb, :live_view_dashboard

  alias Voile.Schema.Library.Circulation
  alias Voile.Schema.Accounts
  alias Voile.Notifications.{LoanReminderEmail, EmailQueue}
  alias VoileWeb.Auth.Authorization

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    is_super_admin = Authorization.is_super_admin?(user)

    socket =
      socket
      |> assign(:page_title, gettext("Manual Reminder Sending"))
      |> assign(:page, 1)
      |> assign(:per_page, 10)
      |> assign(:search_query, "")
      |> assign(:sort_by, "due_date")
      |> assign(:selected_member_id, nil)
      |> assign(:selected_member_loans, [])
      |> assign(:sending_reminder, false)
      |> assign(:total_members, 0)
      |> assign(:user, user)
      |> assign(:is_super_admin, is_super_admin)

    socket =
      if is_super_admin do
        nodes = Voile.Schema.System.list_nodes()
        socket |> assign(:nodes, nodes) |> assign(:selected_node_id, nil)
      else
        socket |> assign(:nodes, []) |> assign(:selected_node_id, user.node_id)
      end

    socket = load_members(socket)

    {:ok, socket}
  end

  @impl true
  def handle_event("search", %{"query" => query}, socket) do
    socket =
      socket
      |> assign(:search_query, query)
      |> assign(:page, 1)
      |> load_members()

    {:noreply, socket}
  end

  @impl true
  def handle_event("sort", %{"by" => sort_by}, socket) do
    socket =
      socket
      |> assign(:sort_by, sort_by)
      |> assign(:page, 1)
      |> load_members()

    {:noreply, socket}
  end

  @impl true
  def handle_event("paginate", %{"page" => page}, socket) do
    page = String.to_integer(page)

    socket =
      socket
      |> assign(:page, page)
      |> load_members()

    {:noreply, socket}
  end

  @impl true
  def handle_event("view_loans", %{"member_id" => member_id}, socket) do
    loans = Circulation.list_member_active_transactions(member_id)

    socket =
      socket
      |> assign(:selected_member_id, member_id)
      |> assign(:selected_member_loans, loans)

    {:noreply, socket}
  end

  @impl true
  def handle_event("close_loans", _params, socket) do
    socket =
      socket
      |> assign(:selected_member_id, nil)
      |> assign(:selected_member_loans, [])

    {:noreply, socket}
  end

  @impl true
  def handle_event("send_reminder", %{"member_id" => member_id}, socket) do
    socket = assign(socket, :sending_reminder, true)

    case send_manual_reminder(member_id) do
      {:ok, _} ->
        socket =
          socket
          |> put_flash(:info, gettext("Reminder sent successfully"))
          |> assign(:sending_reminder, false)

        {:noreply, socket}

      {:error, reason} ->
        socket =
          socket
          |> put_flash(
            :error,
            gettext("Failed to send reminder") <> ": #{inspect(reason)}"
          )
          |> assign(:sending_reminder, false)

        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("select_node", %{"node_id" => node_id_str}, socket) do
    node_id =
      case node_id_str do
        nil -> nil
        "all" -> nil
        "" -> nil
        id -> String.to_integer(id)
      end

    socket =
      socket
      |> assign(:selected_node_id, node_id)
      |> assign(:page, 1)
      |> load_members()

    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
      <!-- Header -->
      <.breadcrumb items={[
        %{label: "Manage", path: ~p"/manage"},
        %{label: "GLAM", path: ~p"/manage/glam"},
        %{label: "Library", path: ~p"/manage/glam/library"},
        %{label: "Loan Reminder", path: nil}
      ]} />
      <div class="mb-8">
        <h1 class="text-3xl font-bold text-gray-900 dark:text-gray-100">
          {gettext("Manual Reminder Sending")}
        </h1>

        <p class="mt-2 text-gray-600 dark:text-gray-400">
          {gettext("Send manual email reminders to members with active loans")}
        </p>
      </div>
      <!-- Node Selector (Super Admin Only) -->
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
              class="block w-64 text-sm border border-gray-300 dark:border-gray-600 rounded-md shadow-sm"
              label="Filter node"
            />
          </.form>
        </div>
      <% end %>
      <!-- Search and Sort Bar -->
      <div class="mb-6 bg-white dark:bg-gray-800 shadow rounded-lg p-4">
        <div class="flex flex-col md:flex-row gap-4">
          <!-- Search -->
          <div class="flex-1">
            <form phx-change="search">
              <input
                type="text"
                name="query"
                value={@search_query}
                placeholder={gettext("Search name, email, or identifier...")}
                class="w-full px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-700 text-gray-900 dark:text-gray-100 placeholder-gray-500 dark:placeholder-gray-400 focus:ring-blue-500 focus:border-blue-500"
              />
            </form>
          </div>
          <!-- Sort -->
          <div class="md:w-48">
            <select
              phx-change="sort"
              name="by"
              class="w-full px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-700 text-gray-900 dark:text-gray-100 focus:ring-blue-500 focus:border-blue-500"
            >
              <option value="due_date" selected={@sort_by == "due_date"}>
                {gettext("Earliest Due")}
              </option>

              <option value="name" selected={@sort_by == "name"}>{gettext("Name")}</option>

              <option value="loan_count" selected={@sort_by == "loan_count"}>
                {gettext("Loans")}
              </option>
            </select>
          </div>
        </div>
      </div>
      <!-- Members List -->
      <div class="bg-white dark:bg-gray-800 shadow rounded-lg overflow-hidden">
        <div class="px-6 py-4 border-b border-gray-200 dark:border-gray-700">
          <h2 class="text-xl font-semibold text-gray-900 dark:text-gray-100">
            {gettext("Members with Active Loans")}
            <span class="text-sm font-normal text-gray-500 dark:text-gray-400">
              ({gettext("Total")}: {@total_members})
            </span>
          </h2>
        </div>

        <%= if @members_with_loans == [] do %>
          <div class="p-8 text-center text-gray-500 dark:text-gray-400">
            <.icon
              name="hero-check-circle"
              class="w-16 h-16 mx-auto mb-4 text-gray-400 dark:text-gray-500"
            />
            <p class="text-lg">{gettext("No members with active loans")}</p>
          </div>
        <% else %>
          <div class="overflow-x-auto">
            <table class="min-w-full divide-y divide-gray-200 dark:divide-gray-700">
              <thead class="bg-gray-50 dark:bg-gray-700">
                <tr>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-300 uppercase tracking-wider">
                    {gettext("Member")}
                  </th>

                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-300 uppercase tracking-wider">
                    {gettext("Loans")}
                  </th>

                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-300 uppercase tracking-wider">
                    {gettext("Earliest Due")}
                  </th>

                  <th class="px-6 py-3 text-right text-xs font-medium text-gray-500 dark:text-gray-300 uppercase tracking-wider">
                    {gettext("Actions")}
                  </th>
                </tr>
              </thead>

              <tbody class="bg-white dark:bg-gray-800 divide-y divide-gray-200 dark:divide-gray-700">
                <tr
                  :for={member <- @members_with_loans}
                  class="hover:bg-gray-50 dark:hover:bg-gray-700"
                >
                  <td class="px-6 py-4">
                    <div>
                      <div class="text-sm font-medium text-gray-900 dark:text-gray-100">
                        {member.member_name || "Unknown"}
                      </div>

                      <div class="text-sm text-gray-500 dark:text-gray-400">
                        {member.member_email}
                      </div>

                      <div class="text-xs text-gray-400 dark:text-gray-500">
                        ID: {member.member_identifier}
                      </div>
                    </div>
                  </td>

                  <td class="px-6 py-4">
                    <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-blue-100 dark:bg-blue-900 text-blue-800 dark:text-blue-200">
                      {member.active_loan_count} item{if member.active_loan_count > 1, do: "s"}
                    </span>
                  </td>

                  <td class="px-6 py-4 whitespace-nowrap">
                    <div class={[
                      "text-sm",
                      if(is_overdue?(member.earliest_due_date),
                        do: "text-red-600 dark:text-red-400 font-semibold",
                        else:
                          if(is_due_soon?(member.earliest_due_date),
                            do: "text-yellow-600 dark:text-yellow-400",
                            else: "text-gray-900 dark:text-gray-100"
                          )
                      )
                    ]}>
                      {format_due_date(member.earliest_due_date)}
                    </div>

                    <div class="text-xs text-gray-500 dark:text-gray-400">
                      {due_date_status(member.earliest_due_date)}
                    </div>
                  </td>

                  <td class="px-6 py-4 whitespace-nowrap text-right text-sm font-medium">
                    <button
                      phx-click="view_loans"
                      phx-value-member_id={member.member_id}
                      class="text-blue-600 dark:text-blue-400 hover:text-blue-900 dark:hover:text-blue-300 mr-4"
                    >
                      {gettext("View")}
                    </button>
                    <button
                      phx-click="send_reminder"
                      phx-value-member_id={member.member_id}
                      disabled={@sending_reminder}
                      class="inline-flex items-center px-3 py-1 border border-transparent text-sm leading-4 font-medium rounded-md text-white bg-indigo-600 hover:bg-indigo-700 dark:bg-indigo-500 dark:hover:bg-indigo-600 focus:outline-none focus:ring-2 focus:ring-offset-2 dark:ring-offset-gray-800 focus:ring-indigo-500 disabled:opacity-50"
                    >
                      <%= if @sending_reminder do %>
                        <.icon name="hero-arrow-path" class="animate-spin -ml-0.5 mr-2 h-4 w-4" />
                      <% else %>
                        <.icon name="hero-paper-airplane" class="-ml-0.5 mr-2 h-4 w-4" />
                      <% end %>
                      {gettext("Send")}
                    </button>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
          <!-- Pagination -->
          <%= if @total_pages > 1 do %>
            <div class="bg-white px-4 py-3 flex items-center justify-between border-t border-gray-200 sm:px-6">
              <div class="flex-1 flex justify-between sm:hidden">
                <button
                  :if={@page > 1}
                  phx-click="paginate"
                  phx-value-page={@page - 1}
                  class="relative inline-flex items-center px-4 py-2 border border-gray-300 text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50"
                >
                  {gettext("Previous")}
                </button>
                <button
                  :if={@page < @total_pages}
                  phx-click="paginate"
                  phx-value-page={@page + 1}
                  class="ml-3 relative inline-flex items-center px-4 py-2 border border-gray-300 text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50"
                >
                  {gettext("Next")}
                </button>
              </div>

              <div class="hidden sm:flex-1 sm:flex sm:items-center sm:justify-between">
                <div>
                  <p class="text-sm text-gray-700">
                    {gettext("Page")} <span class="font-medium">{@page}</span> {gettext("of")}
                    <span class="font-medium">{@total_pages}</span>
                  </p>
                </div>

                <div>
                  <nav class="relative z-0 inline-flex rounded-md shadow-sm -space-x-px">
                    <button
                      :if={@page > 1}
                      phx-click="paginate"
                      phx-value-page={@page - 1}
                      class="relative inline-flex items-center px-2 py-2 rounded-l-md border border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-700 text-sm font-medium text-gray-500 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-600"
                    >
                      <.icon name="hero-chevron-left" class="h-5 w-5" />
                    </button>
                    <button
                      :if={@page < @total_pages}
                      phx-click="paginate"
                      phx-value-page={@page + 1}
                      class="relative inline-flex items-center px-2 py-2 rounded-r-md border border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-700 text-sm font-medium text-gray-500 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-600"
                    >
                      <.icon name="hero-chevron-right" class="h-5 w-5" />
                    </button>
                  </nav>
                </div>
              </div>
            </div>
          <% end %>
        <% end %>
      </div>
      <!-- Member Loans Modal -->
      <%= if @selected_member_id do %>
        <div class="fixed inset-0 bg-gray-500/20 dark:bg-gray-900/50 bg-opacity-75 transition-opacity z-50">
          <div class="fixed inset-0 z-50 overflow-y-auto">
            <div class="flex min-h-full items-end justify-center p-4 text-center sm:items-center sm:p-0">
              <div class="relative transform overflow-hidden rounded-lg bg-white dark:bg-gray-800 text-left shadow-xl transition-all sm:my-8 sm:w-full sm:max-w-3xl">
                <div class="bg-white dark:bg-gray-800 px-4 pt-5 pb-4 sm:p-6 sm:pb-4">
                  <div class="flex justify-between items-start mb-4">
                    <h3 class="text-lg leading-6 font-medium text-gray-900 dark:text-gray-100">
                      {gettext("Member's Active Loans")}
                    </h3>

                    <button
                      phx-click="close_loans"
                      class="text-gray-400 dark:text-gray-500 hover:text-gray-500 dark:hover:text-gray-400"
                    >
                      <.icon name="hero-x-mark" class="h-6 w-6" />
                    </button>
                  </div>

                  <div class="mt-4 space-y-4">
                    <div
                      :for={loan <- @selected_member_loans}
                      class="border border-gray-200 dark:border-gray-700 rounded-lg p-4 bg-gray-50 dark:bg-gray-900"
                    >
                      <div class="flex justify-between items-start">
                        <div class="flex-1">
                          <h4 class="font-medium text-gray-900 dark:text-gray-100">
                            {get_collection_title(loan)}
                          </h4>

                          <p class="text-sm text-gray-600 dark:text-gray-400 mt-1">
                            {gettext("Item Code")}: {loan.item.item_code}
                          </p>

                          <%= if location_label = item_location_label(loan.item) do %>
                            <p class="text-sm text-gray-500 dark:text-gray-400 mt-1">
                              {location_label}
                            </p>
                          <% end %>

                          <div class="mt-2 flex items-center text-sm">
                            <.icon
                              name="hero-calendar"
                              class="h-4 w-4 mr-1 text-gray-400 dark:text-gray-500"
                            />
                            <span class="text-gray-600 dark:text-gray-400">
                              {gettext("Borrowed")}: {format_date(loan.transaction_date)}
                            </span>
                          </div>

                          <div class="mt-1 flex items-center text-sm">
                            <.icon
                              name="hero-clock"
                              class="h-4 w-4 mr-1 text-gray-400 dark:text-gray-500"
                            />
                            <span class={[
                              "font-medium",
                              if(is_overdue_loan?(loan),
                                do: "text-red-600 dark:text-red-400",
                                else:
                                  if(is_due_soon_loan?(loan),
                                    do: "text-yellow-600 dark:text-yellow-400",
                                    else: "text-gray-600 dark:text-gray-400"
                                  )
                              )
                            ]}>
                              {gettext("Due")}: {format_date(loan.due_date)} {loan_status_text(loan)}
                            </span>
                          </div>

                          <%= if loan.renewal_count > 0 do %>
                            <div class="mt-1 text-xs text-gray-500 dark:text-gray-400">
                              {gettext("Renewed")}: {loan.renewal_count} {gettext("times")}
                            </div>
                          <% end %>
                        </div>

                        <div>
                          <%= if is_overdue_loan?(loan) do %>
                            <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-red-100 dark:bg-red-900 text-red-800 dark:text-red-200">
                              {gettext("Overdue")}
                            </span>
                          <% else %>
                            <%= if is_due_soon_loan?(loan) do %>
                              <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-yellow-100 dark:bg-yellow-900 text-yellow-800 dark:text-yellow-200">
                                {gettext("Due Soon")}
                              </span>
                            <% else %>
                              <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 dark:bg-green-900 text-green-800 dark:text-green-200">
                                {gettext("Active")}
                              </span>
                            <% end %>
                          <% end %>
                        </div>
                      </div>
                    </div>
                  </div>
                </div>

                <div class="bg-gray-50 dark:bg-gray-900 px-4 py-3 sm:flex sm:flex-row-reverse sm:px-6">
                  <button
                    phx-click="send_reminder"
                    phx-value-member_id={@selected_member_id}
                    disabled={@sending_reminder}
                    class="w-full inline-flex justify-center rounded-md border border-transparent shadow-sm px-4 py-2 bg-indigo-600 dark:bg-indigo-500 text-base font-medium text-white hover:bg-indigo-700 dark:hover:bg-indigo-600 focus:outline-none focus:ring-2 focus:ring-offset-2 dark:ring-offset-gray-800 focus:ring-indigo-500 sm:ml-3 sm:w-auto sm:text-sm disabled:opacity-50"
                  >
                    <%= if @sending_reminder do %>
                      {gettext("Sending...")}
                    <% else %>
                      {gettext("Send Reminder")}
                    <% end %>
                  </button>
                  <button
                    phx-click="close_loans"
                    class="mt-3 w-full inline-flex justify-center rounded-md border border-gray-300 dark:border-gray-600 shadow-sm px-4 py-2 bg-white dark:bg-gray-700 text-base font-medium text-gray-700 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-600 focus:outline-none focus:ring-2 focus:ring-offset-2 dark:ring-offset-gray-800 focus:ring-indigo-500 sm:mt-0 sm:w-auto sm:text-sm"
                  >
                    {gettext("Close")}
                  </button>
                </div>
              </div>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  # Private helper functions

  defp load_members(socket) do
    filters = %{
      query: socket.assigns.search_query,
      sort_by: socket.assigns.sort_by,
      node_id: socket.assigns.selected_node_id
    }

    {members, total_pages, total_count} =
      Circulation.list_members_with_active_loans_paginated(
        socket.assigns.page,
        socket.assigns.per_page,
        filters
      )

    socket
    |> assign(:members_with_loans, members)
    |> assign(:total_pages, total_pages)
    |> assign(:total_members, total_count)
  end

  defp send_manual_reminder(member_id) do
    with member when not is_nil(member) <- Accounts.get_user(member_id),
         transactions <- Circulation.list_member_active_transactions(member_id),
         true <- length(transactions) > 0 do
      # If the email queue is disabled (e.g., development), send immediately so
      # the local mailbox preview at /dev/mailbox receives the email.
      if Application.get_env(:voile, :disable_email_queue, false) do
        case LoanReminderEmail.send_manual_reminder(member, transactions) do
          {:ok, _} = ok -> ok
          other -> other
        end
      else
        # Queue the email instead of sending immediately
        EmailQueue.enqueue(
          fn -> LoanReminderEmail.send_manual_reminder(member, transactions) end,
          metadata: %{
            member_id: member_id,
            type: :manual_reminder,
            transaction_count: length(transactions),
            sent_by: :librarian
          }
        )

        {:ok, "Email queued successfully"}
      end
    else
      nil -> {:error, "Member not found"}
      false -> {:error, "No active loans"}
      error -> error
    end
  end

  defp format_due_date(due_date) do
    Calendar.strftime(due_date, "%d %b %Y")
  end

  defp format_date(date) do
    Calendar.strftime(date, "%d %b %Y")
  end

  defp is_overdue?(due_date) do
    DateTime.compare(due_date, DateTime.utc_now()) == :lt
  end

  defp is_due_soon?(due_date) do
    days = DateTime.diff(due_date, DateTime.utc_now(), :day)
    days >= 0 and days <= 7
  end

  defp is_overdue_loan?(loan) do
    DateTime.compare(loan.due_date, DateTime.utc_now()) == :lt
  end

  defp is_due_soon_loan?(loan) do
    days = DateTime.diff(loan.due_date, DateTime.utc_now(), :day)
    days >= 0 and days <= 7
  end

  defp due_date_status(due_date) do
    cond do
      is_overdue?(due_date) ->
        days = abs(DateTime.diff(due_date, DateTime.utc_now(), :day))
        "Terlambat #{days} hari / #{days} days overdue"

      is_due_soon?(due_date) ->
        days = DateTime.diff(due_date, DateTime.utc_now(), :day)
        "#{days} hari lagi / in #{days} days"

      true ->
        days = DateTime.diff(due_date, DateTime.utc_now(), :day)
        "#{days} hari lagi / in #{days} days"
    end
  end

  defp loan_status_text(loan) do
    cond do
      is_overdue_loan?(loan) ->
        days = abs(DateTime.diff(loan.due_date, DateTime.utc_now(), :day))
        "(#{days} hari terlambat / #{days} days late)"

      is_due_soon_loan?(loan) ->
        days = DateTime.diff(loan.due_date, DateTime.utc_now(), :day)
        "(#{days} hari lagi / in #{days} days)"

      true ->
        ""
    end
  end

  defp get_collection_title(%{item: %{collection: %{title: title}}}), do: title
  defp get_collection_title(_), do: "Unknown Collection"

  defp item_location_label(%{
         item_location: %{location_name: location_name},
         node: %{name: node_name}
       })
       when is_binary(location_name) and is_binary(node_name) do
    "#{node_name} / #{location_name}"
  end

  defp item_location_label(%{item_location: %{location_name: location_name}})
       when is_binary(location_name),
       do: location_name

  defp item_location_label(%{node: %{name: node_name}}) when is_binary(node_name),
    do: node_name

  defp item_location_label(_), do: nil
end
