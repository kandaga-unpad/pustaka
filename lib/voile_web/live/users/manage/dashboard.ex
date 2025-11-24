defmodule VoileWeb.Users.Manage.Dashboard do
  use VoileWeb, :live_view_dashboard

  alias Voile.Schema.Accounts
  alias Voile.Schema.Accounts.User
  alias VoileWeb.Auth.Authorization
  import Ecto.Query

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_scope.user |> Voile.Repo.preload(:roles)

    # Check if user is authenticated
    if Authorization.can?(current_user, "system.settings") do
      stats = Accounts.get_user_statistics()
      recent_users = get_recent_users()

      {:ok,
       socket
       |> assign(:stats, stats)
       |> assign(:recent_users, recent_users)
       |> assign(:current_user, current_user)}
    else
      {:ok,
       socket
       |> put_flash(:error, "You don't have permission to access the admin dashboard.")
       |> redirect(to: ~p"/manage/settings")}
    end
  end

  @impl true
  def handle_event("refresh_stats", _params, socket) do
    stats = Accounts.get_user_statistics()
    recent_users = get_recent_users()

    {:noreply,
     socket
     |> assign(:stats, stats)
     |> assign(:recent_users, recent_users)
     |> put_flash(:info, "Statistics refreshed")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <.header>
        Admin Dashboard
        <:subtitle>System overview and management</:subtitle>

        <:actions>
          <.button
            phx-click="refresh_stats"
            class="btn btn-primary rounded-lg"
          >
            <.icon name="hero-arrow-path" class="w-4 h-4 mr-2" /> Refresh Stats
          </.button>
        </:actions>
      </.header>
      <!-- Statistics Cards -->
      <div class="grid grid-cols-1 gap-5 sm:grid-cols-2 lg:grid-cols-3">
        <!-- Total Users Card -->
        <div class="bg-white overflow-hidden shadow rounded-lg">
          <div class="p-5">
            <div class="flex items-center">
              <div class="flex-shrink-0">
                <svg
                  class="h-6 w-6 text-voile-info"
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z"
                  />
                </svg>
              </div>

              <div class="ml-5 w-0 flex-1">
                <dl>
                  <dt class="text-sm font-medium text-gray-500 truncate">Total Users</dt>

                  <dd class="text-lg font-medium text-gray-900">{@stats.total_users}</dd>
                </dl>
              </div>
            </div>
          </div>
        </div>
        <!-- Active Users Card -->
        <div class="bg-white overflow-hidden shadow rounded-lg">
          <div class="p-5">
            <div class="flex items-center">
              <div class="flex-shrink-0">
                <svg
                  class="h-6 w-6 text-green-400"
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"
                  />
                </svg>
              </div>

              <div class="ml-5 w-0 flex-1">
                <dl>
                  <dt class="text-sm font-medium text-gray-500 truncate">Active Users</dt>

                  <dd class="text-lg font-medium text-gray-900">{@stats.confirmed_users}</dd>
                </dl>
              </div>
            </div>
          </div>
        </div>
        <!-- Pending Users Card -->
        <div class="bg-white overflow-hidden shadow rounded-lg">
          <div class="p-5">
            <div class="flex items-center">
              <div class="flex-shrink-0">
                <svg
                  class="h-6 w-6 text-yellow-400"
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.964-.833-2.732 0L3.732 16.5c-.77.833.192 2.5 1.732 2.5z"
                  />
                </svg>
              </div>

              <div class="ml-5 w-0 flex-1">
                <dl>
                  <dt class="text-sm font-medium text-gray-500 truncate">Pending Users</dt>

                  <dd class="text-lg font-medium text-gray-900">{@stats.unconfirmed_users}</dd>
                </dl>
              </div>
            </div>
          </div>
        </div>
      </div>
      <!-- Users by Role Chart -->
      <div class="bg-white shadow rounded-lg">
        <div class="px-4 py-5 sm:p-6">
          <h3 class="text-lg leading-6 font-medium text-gray-900 mb-4">Users by Role</h3>

          <div class="space-y-3">
            <%= for {role, count} <- @stats.users_by_role do %>
              <div class="flex items-center justify-between">
                <div class="flex items-center">
                  <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium">
                    {role}
                  </span>
                </div>

                <div class="flex items-center">
                  <div class="w-32 bg-gray-200 rounded-full h-2 mr-3">
                    <div
                      class="bg-voile-info h-2 rounded-full"
                      style={"width: #{if @stats.total_users > 0, do: (count / @stats.total_users * 100), else: 0}%"}
                    >
                    </div>
                  </div>
                  <span class="text-sm font-medium text-gray-900">{count}</span>
                </div>
              </div>
            <% end %>
          </div>
        </div>
      </div>
      <!-- Recent Users -->
      <div class="bg-white shadow rounded-lg">
        <div class="px-4 py-5 sm:p-6">
          <h3 class="text-lg leading-6 font-medium text-gray-900 mb-4">Recent Users</h3>

          <div class="flow-root">
            <ul role="list" class="-my-5 divide-y divide-gray-200">
              <%= for user <- @recent_users do %>
                <li class="py-4">
                  <div class="flex items-center space-x-4">
                    <div class="flex-shrink-0">
                      <%= if user.user_image do %>
                        <img class="h-8 w-8 rounded-full" src={user.user_image} alt="" />
                      <% else %>
                        <div class="h-8 w-8 rounded-full bg-gray-300 flex items-center justify-center">
                          <span class="text-sm font-medium text-gray-700">
                            {String.first(user.email || "?") |> String.upcase()}
                          </span>
                        </div>
                      <% end %>
                    </div>

                    <div class="flex-1 min-w-0">
                      <p class="text-sm font-medium text-gray-900 truncate">{user.email}</p>

                      <p class="text-sm text-gray-500 truncate">
                        Joined {Calendar.strftime(user.inserted_at, "%B %d, %Y")}
                      </p>
                    </div>

                    <div class="flex items-center space-x-2">
                      <%= for role <- user.roles do %>
                        <span class="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium">
                          {role.name}
                        </span>
                      <% end %>

                      <%= if user.confirmed_at do %>
                        <span class="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-green-100 text-green-800">
                          Active
                        </span>
                      <% else %>
                        <span class="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-yellow-100 text-yellow-800">
                          Pending
                        </span>
                      <% end %>
                    </div>
                  </div>
                </li>
              <% end %>
            </ul>
          </div>

          <%= if @current_user do %>
            <div class="mt-6">
              <.link
                navigate={~p"/manage/settings/users"}
                class="w-full flex justify-center items-center px-4 py-2 border border-gray-300 shadow-sm text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-voile-info focus:border-voile-info"
              >
                View all users
              </.link>
            </div>
          <% end %>
        </div>
      </div>
      <!-- System Information -->
      <div class="bg-white shadow rounded-lg">
        <div class="px-4 py-5 sm:p-6">
          <h3 class="text-lg leading-6 font-medium text-gray-900 mb-4">System Information</h3>

          <dl class="grid grid-cols-1 gap-x-4 gap-y-6 sm:grid-cols-2">
            <div>
              <dt class="text-sm font-medium text-gray-500">Current User</dt>

              <dd class="mt-1 text-sm text-gray-900">{@current_user.email}</dd>
            </div>

            <div>
              <dt class="text-sm font-medium text-gray-500">Your Role</dt>

              <dd class="mt-1">
                <%= for role <- @current_user.roles do %>
                  <span class="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium mr-1">
                    {role.name}
                  </span>
                <% end %>
              </dd>
            </div>

            <div>
              <dt class="text-sm font-medium text-gray-500">Last Login</dt>

              <dd class="mt-1 text-sm text-gray-900">
                <%= if @current_user.last_login do %>
                  {Calendar.strftime(@current_user.last_login, "%B %d, %Y at %I:%M %p")}
                <% else %>
                  Never
                <% end %>
              </dd>
            </div>

            <div>
              <dt class="text-sm font-medium text-gray-500">Account Status</dt>

              <dd class="mt-1">
                <%= if @current_user.confirmed_at do %>
                  <span class="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-green-100 text-green-800">
                    Confirmed
                  </span>
                <% else %>
                  <span class="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-yellow-100 text-yellow-800">
                    Unconfirmed
                  </span>
                <% end %>
              </dd>
            </div>
          </dl>
        </div>
      </div>
    </div>
    """
  end

  # Private helper functions
  defp get_recent_users do
    from(u in User,
      order_by: [desc: u.inserted_at],
      limit: 5,
      preload: [:roles]
    )
    |> Voile.Repo.all()
  end
end
