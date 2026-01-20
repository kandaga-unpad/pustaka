defmodule VoileWeb.Dashboard.Members.Reports.Overdue do
  use VoileWeb, :live_view_dashboard

  alias Voile.Repo
  alias Voile.Schema.Library.Transaction
  alias Voile.Schema.Accounts.User
  alias Voile.Schema.Catalog.Item

  import Ecto.Query

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user

    socket =
      socket
      |> assign(:page_title, "Overdue Items")
      |> assign(:user, user)
      |> load_overdue_items()

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <%!-- Breadcrumb --%>
      <.breadcrumb items={[
        %{label: "Manage", path: ~p"/manage"},
        %{label: "Members", path: ~p"/manage/members"},
        %{label: "Reports", path: ~p"/manage/members/reports"},
        %{label: "Overdue", path: nil}
      ]} />

      <%!-- Page Header --%>
      <div class="bg-white dark:bg-gray-700 shadow-sm rounded-lg p-6">
        <div class="flex items-center justify-between">
          <div>
            <h1 class="text-2xl font-bold text-gray-900 dark:text-white">Overdue Items</h1>
            <p class="text-gray-600 dark:text-gray-300 mt-1">Members with overdue library items</p>
          </div>
          <div class="text-sm text-gray-500 dark:text-gray-400">
            Total: {@overdue_items |> length()}
          </div>
        </div>
      </div>

      <%!-- Overdue Items List --%>
      <div class="bg-white dark:bg-gray-700 shadow-sm rounded-lg overflow-hidden">
        <%= if Enum.empty?(@overdue_items) do %>
          <div class="p-8 text-center">
            <div class="flex justify-center mb-4">
              <.icon name="hero-check-circle" class="w-12 h-12 text-green-500" />
            </div>
            <h3 class="text-lg font-medium text-gray-900 dark:text-white mb-2">No Overdue Items</h3>
            <p class="text-gray-600 dark:text-gray-300">All items have been returned on time.</p>
          </div>
        <% else %>
          <div class="overflow-x-auto">
            <.table
              id="overdue-items"
              rows={@overdue_items}
            >
              <:col :let={item} label="Member">
                <div class="flex items-center gap-3">
                  <div class="flex-shrink-0 h-10 w-10">
                    <div class="h-10 w-10 rounded-full bg-voile-light flex items-center justify-center">
                      <span class="text-sm font-medium text-gray-700">
                        {String.first(item.member.fullname || "?")}
                      </span>
                    </div>
                  </div>
                  <div>
                    <div class="font-medium text-gray-900 dark:text-white">
                      {item.member.fullname}
                    </div>
                    <div class="text-sm text-gray-500 dark:text-gray-400">{item.member.email}</div>
                  </div>
                </div>
              </:col>

              <:col :let={item} label="Item">
                <div>
                  <div class="font-medium text-gray-900 dark:text-white">{item.item.title}</div>
                  <div class="text-sm text-gray-500 dark:text-gray-400">
                    Loan Date: {Calendar.strftime(item.loan_date, "%b %d, %Y")}
                  </div>
                </div>
              </:col>

              <:col :let={item} label="Due Date">
                <span class="font-medium text-red-600">
                  {Calendar.strftime(item.due_date, "%b %d, %Y")}
                </span>
              </:col>

              <:col :let={item} label="Days Overdue">
                <span class="inline-flex px-2 py-1 text-xs font-semibold rounded-full bg-red-100 text-red-800">
                  {days_overdue(item.due_date)} days
                </span>
              </:col>

              <:col :let={item} label="Fine Amount">
                <span class="font-medium text-red-600">
                  {calculate_fine(days_overdue(item.due_date))}
                </span>
              </:col>

              <:action :let={item}>
                <div class="flex items-center gap-2">
                  <.link
                    navigate={~p"/manage/members/management/#{item.member.id}"}
                    class="text-voile-primary hover:text-voile-primary/80"
                  >
                    <.icon name="hero-eye" class="w-4 h-4" />
                  </.link>

                  <.link
                    navigate={~p"/manage/glam/library/circulation/transactions/#{item.id}/return"}
                    class="text-green-600 hover:text-green-800"
                  >
                    <.icon name="hero-arrow-left-on-rectangle" class="w-4 h-4" />
                  </.link>
                </div>
              </:action>
            </.table>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  # Private functions

  defp load_overdue_items(socket) do
    user = socket.assigns.user

    today = Date.utc_today()

    base_query =
      from(t in Transaction,
        join: m in User,
        on: t.member_id == m.id,
        join: i in Item,
        on: t.item_id == i.id,
        join: c in assoc(i, :collection),
        where: is_nil(t.return_date) and t.due_date < ^today,
        order_by: t.due_date,
        preload: [member: [], item: [collection: []]]
      )

    query =
      if is_nil(user.node_id) do
        base_query
      else
        # Filter by node
        from([t, m, i, c] in base_query,
          where: c.unit_id == ^user.node_id
        )
      end

    overdue_items = Repo.all(query)

    assign(socket, :overdue_items, overdue_items)
  end

  defp days_overdue(due_date) do
    Date.diff(Date.utc_today(), due_date)
  end

  defp calculate_fine(days_overdue) do
    # Simple fine calculation - $0.50 per day
    fine_amount = Decimal.mult(Decimal.new(days_overdue), Decimal.new("0.50"))
    "$#{Decimal.to_string(fine_amount)}"
  end
end
