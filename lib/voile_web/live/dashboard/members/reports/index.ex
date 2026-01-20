defmodule VoileWeb.Dashboard.Members.Reports.Index do
  use VoileWeb, :live_view_dashboard

  alias Voile.Repo
  alias Voile.Schema.Accounts.User

  import Ecto.Query

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user

    socket =
      socket
      |> assign(:page_title, "Member Reports")
      |> assign(:user, user)
      |> load_report_data()

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
        %{label: "Reports", path: nil}
      ]} />

      <%!-- Page Header --%>
      <div class="bg-white dark:bg-gray-700 shadow-sm rounded-lg p-6">
        <h1 class="text-2xl font-bold text-gray-900 dark:text-white">Member Reports</h1>
        <p class="text-gray-600 dark:text-gray-300 mt-1">
          Comprehensive reports on member activity and status
        </p>
      </div>

      <%!-- Report Cards --%>
      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        <.link navigate="/manage/members/reports/expiring" class="block">
          <div class="bg-white dark:bg-gray-700 shadow-sm rounded-lg p-6 hover:shadow-md transition-shadow">
            <div class="flex items-center gap-4">
              <div class="flex-shrink-0 h-12 w-12">
                <div class="h-12 w-12 rounded-lg bg-orange-100 flex items-center justify-center">
                  <.icon name="hero-clock" class="w-6 h-6 text-orange-600" />
                </div>
              </div>
              <div>
                <h3 class="text-lg font-medium text-gray-900 dark:text-white">
                  Expiring Memberships
                </h3>
                <p class="text-sm text-gray-600 dark:text-gray-300">
                  Members with expiring memberships
                </p>
                <p class="text-2xl font-bold text-orange-600 mt-2">{@expiring_count}</p>
              </div>
            </div>
          </div>
        </.link>

        <.link navigate="/manage/members/reports/overdue" class="block">
          <div class="bg-white dark:bg-gray-700 shadow-sm rounded-lg p-6 hover:shadow-md transition-shadow">
            <div class="flex items-center gap-4">
              <div class="flex-shrink-0 h-12 w-12">
                <div class="h-12 w-12 rounded-lg bg-red-100 flex items-center justify-center">
                  <.icon name="hero-exclamation-triangle" class="w-6 h-6 text-red-600" />
                </div>
              </div>
              <div>
                <h3 class="text-lg font-medium text-gray-900 dark:text-white">Overdue Items</h3>
                <p class="text-sm text-gray-600 dark:text-gray-300">Members with overdue loans</p>
                <p class="text-2xl font-bold text-red-600 mt-2">{@overdue_count}</p>
              </div>
            </div>
          </div>
        </.link>

        <div class="bg-white dark:bg-gray-700 shadow-sm rounded-lg p-6">
          <div class="flex items-center gap-4">
            <div class="flex-shrink-0 h-12 w-12">
              <div class="h-12 w-12 rounded-lg bg-blue-100 flex items-center justify-center">
                <.icon name="hero-users" class="w-6 h-6 text-blue-600" />
              </div>
            </div>
            <div>
              <h3 class="text-lg font-medium text-gray-900 dark:text-white">Active Members</h3>
              <p class="text-sm text-gray-600 dark:text-gray-300">Currently active members</p>
              <p class="text-2xl font-bold text-blue-600 mt-2">{@active_members_count}</p>
            </div>
          </div>
        </div>
      </div>

      <%!-- Quick Stats --%>
      <div class="bg-white dark:bg-gray-700 shadow-sm rounded-lg p-6">
        <h3 class="text-lg font-medium text-gray-900 dark:text-white mb-4">Membership Overview</h3>
        <div class="grid grid-cols-1 md:grid-cols-4 gap-4">
          <.stat_card
            title="Total Members"
            value={@total_members}
            icon="hero-users"
            color="blue"
          />
          <.stat_card
            title="Active Members"
            value={@active_members_count}
            icon="hero-user-group"
            color="green"
          />
          <.stat_card
            title="Suspended Members"
            value={@suspended_members_count}
            icon="hero-exclamation-triangle"
            color="red"
          />
          <.stat_card
            title="Expired Members"
            value={@expired_members_count}
            icon="hero-x-mark"
            color="orange"
          />
        </div>
      </div>
    </div>
    """
  end

  # Private functions

  defp load_report_data(socket) do
    user = socket.assigns.user

    base_query = from(u in User)

    scoped_query =
      if is_nil(user.node_id) do
        base_query
      else
        from(u in base_query, where: u.node_id == ^user.node_id)
      end

    total_members = Repo.aggregate(scoped_query, :count, :id)

    active_members_count =
      Repo.aggregate(
        from(u in scoped_query,
          where: u.manually_suspended == false or is_nil(u.manually_suspended)
        ),
        :count,
        :id
      )

    suspended_members_count =
      Repo.aggregate(
        from(u in scoped_query, where: u.manually_suspended == true),
        :count,
        :id
      )

    expired_members_count =
      Repo.aggregate(
        from(u in scoped_query,
          where: not is_nil(u.expiry_date) and u.expiry_date < ^Date.utc_today()
        ),
        :count,
        :id
      )

    # Expiring in next 30 days
    thirty_days_from_now = Date.add(Date.utc_today(), 30)

    expiring_count =
      Repo.aggregate(
        from(u in scoped_query,
          where:
            not is_nil(u.expiry_date) and u.expiry_date <= ^thirty_days_from_now and
              u.expiry_date >= ^Date.utc_today()
        ),
        :count,
        :id
      )

    # Overdue items (simplified - would need to join with transactions)
    # Placeholder - would need proper implementation
    overdue_count = 0

    socket
    |> assign(:total_members, total_members)
    |> assign(:active_members_count, active_members_count)
    |> assign(:suspended_members_count, suspended_members_count)
    |> assign(:expired_members_count, expired_members_count)
    |> assign(:expiring_count, expiring_count)
    |> assign(:overdue_count, overdue_count)
  end
end
