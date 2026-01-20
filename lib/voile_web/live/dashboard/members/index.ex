defmodule VoileWeb.Dashboard.Members.Index do
  use VoileWeb, :live_view_dashboard

  alias Voile.Repo
  alias Voile.Schema.Accounts.User
  alias VoileWeb.Auth.Authorization

  import Ecto.Query

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user

    is_super_admin = Authorization.is_super_admin?(user)

    socket =
      socket
      |> assign(:page_title, "Members Dashboard")
      |> assign(:user, user)
      |> assign(:is_super_admin, is_super_admin)

    socket =
      if is_super_admin do
        nodes = Voile.Schema.System.list_nodes()

        socket |> assign(:nodes, nodes) |> assign(:selected_node_id, nil)
      else
        socket |> assign(:nodes, []) |> assign(:selected_node_id, user.node_id)
      end

    # compute initial stats scoped by user/node and recent members
    socket =
      socket
      |> assign(:members_stats, get_members_statistics(user))
      |> assign(:recent_members, get_recent_members(5, user))

    {:ok, socket}
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

    socket = assign(socket, :selected_node_id, node_id)

    # Determine user context for stats (override node for super_admin when a node is selected)
    user = socket.assigns.user

    user_for_stats =
      if Authorization.is_super_admin?(user) and not is_nil(node_id) do
        Map.put(user, :node_id, node_id)
      else
        user
      end

    socket =
      socket
      |> assign(:members_stats, get_members_statistics(user_for_stats))
      |> assign(:recent_members, get_recent_members(5, user_for_stats))

    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6 px-3 md:px-0">
      <%= if @is_super_admin do %>
        <div class="mb-4">
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

      <%!-- Breadcrumb --%>
      <.breadcrumb items={[
        %{label: "Manage", path: ~p"/manage"},
        %{label: "Members", path: nil}
      ]} />

      <%!-- Page Header --%>
      <div class="bg-gradient-to-r from-green-600 to-teal-600 rounded-xl p-8 text-white shadow-lg">
        <div class="flex items-center justify-between">
          <div>
            <h1 class="text-3xl font-bold mb-2">Members Management Dashboard</h1>
            <p class="text-white text-lg">
              Comprehensive Member Management & Administration
            </p>
          </div>
          <div class="hidden md:block">
            <.icon name="hero-users" class="w-24 h-24 opacity-20" />
          </div>
        </div>
      </div>

      <%!-- Members Navigation Cards --%>
      <.members_navigation_cards members_stats={@members_stats} />

      <%!-- Quick Stats Overview --%>
      <div class="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-4 gap-6">
        <.stat_card
          title="Total Members"
          value={@members_stats.total_members}
          icon="hero-users"
          color="green"
          trend="+5%"
        />
        <.stat_card
          title="Active Members"
          value={@members_stats.active_members}
          icon="hero-user-group"
          color="blue"
          trend="+3%"
        />
        <.stat_card
          title="Expiring Soon"
          value={@members_stats.expiring_soon}
          icon="hero-clock"
          color="orange"
          trend="7 days"
        />
        <.stat_card
          title="Suspended Members"
          value={@members_stats.suspended_members}
          icon="hero-exclamation-triangle"
          color="red"
          trend="0%"
        />
      </div>

      <%!-- Recent Activity --%>
      <div class="bg-white dark:bg-gray-700 rounded-xl p-6 shadow">
        <div class="flex items-center justify-between mb-6">
          <div class="flex items-center gap-3">
            <.icon name="hero-clock" class="w-6 h-6 text-gray-600 dark:text-gray-300" />
            <h2 class="text-xl font-semibold text-gray-900 dark:text-white">Recent Members</h2>
          </div>

          <.link
            navigate="/manage/members/management"
            class="text-sm text-voile-primary hover:text-voile-primary/80 dark:text-voile-primary/60 dark:hover:text-voile-primary/40 font-medium"
          >
            View All →
          </.link>
        </div>

        <div class="space-y-3">
          <%= for member <- @recent_members do %>
            <.recent_member_item member={member} />
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  # Private helper functions

  defp get_members_statistics(user) do
    base_query = from(u in User)

    scoped_query =
      if is_nil(user.node_id) do
        base_query
      else
        from(u in base_query, where: u.node_id == ^user.node_id)
      end

    total_members = Repo.aggregate(scoped_query, :count, :id)

    active_members =
      Repo.aggregate(
        from(u in scoped_query,
          where: u.manually_suspended == false or is_nil(u.manually_suspended)
        ),
        :count,
        :id
      )

    suspended_members =
      Repo.aggregate(
        from(u in scoped_query, where: u.manually_suspended == true),
        :count,
        :id
      )

    # Members expiring in next 30 days
    thirty_days_from_now = Date.add(Date.utc_today(), 30)

    expiring_soon =
      Repo.aggregate(
        from(u in scoped_query,
          where: not is_nil(u.expiry_date) and u.expiry_date <= ^thirty_days_from_now
        ),
        :count,
        :id
      )

    %{
      total_members: total_members,
      active_members: active_members,
      suspended_members: suspended_members,
      expiring_soon: expiring_soon
    }
  end

  defp get_recent_members(limit, user) do
    base_query = from(u in User, order_by: [desc: u.inserted_at], limit: ^limit)

    query =
      if is_nil(user.node_id) do
        base_query
      else
        from(u in base_query, where: u.node_id == ^user.node_id)
      end

    Repo.all(query)
  end
end
