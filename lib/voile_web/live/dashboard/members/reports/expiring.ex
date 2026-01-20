defmodule VoileWeb.Dashboard.Members.Reports.Expiring do
  use VoileWeb, :live_view_dashboard

  alias Voile.Repo
  alias Voile.Schema.Accounts.User

  import Ecto.Query

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user

    socket =
      socket
      |> assign(:page_title, "Expiring Memberships")
      |> assign(:user, user)
      |> load_expiring_members()

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
        %{label: "Expiring", path: nil}
      ]} />

      <%!-- Page Header --%>
      <div class="bg-white dark:bg-gray-700 shadow-sm rounded-lg p-6">
        <div class="flex items-center justify-between">
          <div>
            <h1 class="text-2xl font-bold text-gray-900 dark:text-white">Expiring Memberships</h1>
            <p class="text-gray-600 dark:text-gray-300 mt-1">
              Members whose memberships will expire soon
            </p>
          </div>
          <div class="text-sm text-gray-500 dark:text-gray-400">
            Total: {@expiring_members |> length()}
          </div>
        </div>
      </div>

      <%!-- Members List --%>
      <div class="bg-white dark:bg-gray-700 shadow-sm rounded-lg overflow-hidden">
        <%= if Enum.empty?(@expiring_members) do %>
          <div class="p-8 text-center">
            <div class="flex justify-center mb-4">
              <.icon name="hero-check-circle" class="w-12 h-12 text-green-500" />
            </div>
            <h3 class="text-lg font-medium text-gray-900 dark:text-white mb-2">
              No Expiring Memberships
            </h3>
            <p class="text-gray-600 dark:text-gray-300">
              All memberships are current or no members have expiry dates set.
            </p>
          </div>
        <% else %>
          <div class="overflow-x-auto">
            <.table
              id="expiring-members"
              rows={@expiring_members}
              row_click={fn member -> JS.navigate(~p"/manage/members/management/#{member}") end}
            >
              <:col :let={member} label="Member">
                <div class="flex items-center gap-3">
                  <div class="flex-shrink-0 h-10 w-10">
                    <div class="h-10 w-10 rounded-full bg-voile-light flex items-center justify-center">
                      <span class="text-sm font-medium text-gray-700">
                        {String.first(member.fullname || "?")}
                      </span>
                    </div>
                  </div>
                  <div>
                    <div class="font-medium text-gray-900 dark:text-white">{member.fullname}</div>
                    <div class="text-sm text-gray-500 dark:text-gray-400">{member.email}</div>
                  </div>
                </div>
              </:col>

              <:col :let={member} label="Member Type">
                {member.user_type && member.user_type.name}
              </:col>

              <:col :let={member} label="Expiry Date">
                <span class="font-medium">
                  {Calendar.strftime(member.expiry_date, "%b %d, %Y")}
                </span>
              </:col>

              <:col :let={member} label="Days Until Expiry">
                <span class={"inline-flex px-2 py-1 text-xs font-semibold rounded-full #{days_until_class(days_until_expiry(member.expiry_date))}"}>
                  {days_until_expiry(member.expiry_date)} days
                </span>
              </:col>

              <:action :let={member}>
                <div class="flex items-center gap-2">
                  <.link
                    navigate={~p"/manage/members/management/#{member.id}"}
                    class="text-voile-primary hover:text-voile-primary/80"
                  >
                    <.icon name="hero-eye" class="w-4 h-4" />
                  </.link>

                  <%= if can?(@current_scope.user, "users.update") do %>
                    <.link
                      patch={~p"/manage/members/management/#{member.id}/extend"}
                      class="text-green-600 hover:text-green-800"
                    >
                      <.icon name="hero-arrow-path" class="w-4 h-4" />
                    </.link>
                  <% end %>
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

  defp load_expiring_members(socket) do
    user = socket.assigns.user

    # Get members expiring in the next 30 days
    thirty_days_from_now = Date.add(Date.utc_today(), 30)

    base_query =
      from(u in User,
        left_join: mt in assoc(u, :user_type),
        where:
          not is_nil(u.expiry_date) and
            u.expiry_date <= ^thirty_days_from_now and
            u.expiry_date >= ^Date.utc_today(),
        order_by: u.expiry_date,
        preload: [:user_type]
      )

    query =
      if is_nil(user.node_id) do
        base_query
      else
        from(u in base_query, where: u.node_id == ^user.node_id)
      end

    expiring_members = Repo.all(query)

    assign(socket, :expiring_members, expiring_members)
  end

  defp days_until_expiry(expiry_date) do
    Date.diff(expiry_date, Date.utc_today())
  end

  defp days_until_class(days) do
    cond do
      days <= 7 -> "bg-red-100 text-red-800"
      days <= 14 -> "bg-orange-100 text-orange-800"
      true -> "bg-yellow-100 text-yellow-800"
    end
  end
end
