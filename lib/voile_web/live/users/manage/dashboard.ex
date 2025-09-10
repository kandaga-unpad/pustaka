defmodule VoileWeb.Users.Manage.Dashboard do
  use VoileWeb, :live_view_dashboard

  alias Voile.Schema.Accounts
  alias Voile.Schema.Accounts.User
  alias VoileWeb.Helpers.AuthHelper
  import Ecto.Query

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns[:current_user]

    # Check if user has any admin permissions
    has_admin_access =
      AuthHelper.can_access?(current_user, "users") ||
        AuthHelper.can_access?(current_user, "roles") ||
        AuthHelper.can_access?(current_user, "system")

    if has_admin_access do
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
          <.button phx-click="refresh_stats" class="bg-blue-600 hover:bg-blue-700">
            <.icon name="hero-arrow-path" class="w-4 h-4 mr-2" /> Refresh Stats
          </.button>
        </:actions>
      </.header>
      <!-- Statistics Cards -->
      <div class="grid grid-cols-1 gap-5 sm:grid-cols-2 lg:grid-cols-4">
        <!-- Total Users Card -->
        <div class="bg-white overflow-hidden shadow rounded-lg">
          <div class="p-5">
            <div class="flex items-center">
              <div class="flex-shrink-0">
                <svg
                  class="h-6 w-6 text-blue-400"
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
        <!-- Total Roles Card -->
        <div class="bg-white overflow-hidden shadow rounded-lg">
          <div class="p-5">
            <div class="flex items-center">
              <div class="flex-shrink-0">
                <svg
                  class="h-6 w-6 text-purple-400"
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4"
                  />
                </svg>
              </div>

              <div class="ml-5 w-0 flex-1">
                <dl>
                  <dt class="text-sm font-medium text-gray-500 truncate">Total Roles</dt>

                  <dd class="text-lg font-medium text-gray-900">{map_size(@stats.users_by_role)}</dd>
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
                  <span class={"inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium #{AuthHelper.role_badge_class(role)}"}>
                    {role}
                  </span>
                </div>

                <div class="flex items-center">
                  <div class="w-32 bg-gray-200 rounded-full h-2 mr-3">
                    <div
                      class="bg-blue-600 h-2 rounded-full"
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
      <!-- Quick Actions -->
      <div class="bg-white shadow rounded-lg">
        <div class="px-4 py-5 sm:p-6">
          <h3 class="text-lg leading-6 font-medium text-gray-900 mb-4">Quick Actions</h3>

          <div class="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
            <%= if AuthHelper.can_access?(@current_user, "users") do %>
              <.link
                navigate={~p"/manage/settings/users/new"}
                class="group relative block p-4 border-2 border-gray-300 border-dashed rounded-lg text-center hover:border-gray-400 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
              >
                <svg
                  class="mx-auto h-8 w-8 text-gray-400 group-hover:text-gray-600"
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M18 9v3m0 0v3m0-3h3m-3 0h-3m-2-5a4 4 0 11-8 0 4 4 0 018 0zM3 20a6 6 0 0112 0v1H3v-1z"
                  />
                </svg>
                <span class="mt-2 block text-sm font-medium text-gray-900 group-hover:text-gray-600">
                  Create User
                </span>
              </.link>
            <% end %>

            <%= if AuthHelper.can_access?(@current_user, "roles") do %>
              <.link
                navigate={~p"/manage/settings/users/roles/new"}
                class="group relative block p-4 border-2 border-gray-300 border-dashed rounded-lg text-center hover:border-gray-400 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
              >
                <svg
                  class="mx-auto h-8 w-8 text-gray-400 group-hover:text-gray-600"
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M12 6v6m0 0v6m0-6h6m-6 0H6"
                  />
                </svg>
                <span class="mt-2 block text-sm font-medium text-gray-900 group-hover:text-gray-600">
                  Create Role
                </span>
              </.link>
            <% end %>

            <%= if AuthHelper.can_access?(@current_user, "users") do %>
              <.link
                navigate={~p"/manage/settings/users"}
                class="group relative block p-4 border-2 border-gray-300 border-dashed rounded-lg text-center hover:border-gray-400 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
              >
                <svg
                  class="mx-auto h-8 w-8 text-gray-400 group-hover:text-gray-600"
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
                <span class="mt-2 block text-sm font-medium text-gray-900 group-hover:text-gray-600">
                  Manage Users
                </span>
              </.link>
            <% end %>

            <%= if AuthHelper.can_access?(@current_user, "roles") do %>
              <.link
                navigate={~p"/manage/settings/users/roles"}
                class="group relative block p-4 border-2 border-gray-300 border-dashed rounded-lg text-center hover:border-gray-400 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
              >
                <svg
                  class="mx-auto h-8 w-8 text-gray-400 group-hover:text-gray-600"
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"
                  />
                </svg>
                <span class="mt-2 block text-sm font-medium text-gray-900 group-hover:text-gray-600">
                  Manage Roles
                </span>
              </.link>
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
                      <%= if user.avatar_url do %>
                        <img class="h-8 w-8 rounded-full" src={user.avatar_url} alt="" />
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
                        <span class={"inline-flex items-center px-2 py-1 rounded-full text-xs font-medium #{AuthHelper.role_badge_class(role.name)}"}>
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

          <%= if AuthHelper.can_access?(@current_user, "users") do %>
            <div class="mt-6">
              <.link
                navigate={~p"/manage/settings/users"}
                class="w-full flex justify-center items-center px-4 py-2 border border-gray-300 shadow-sm text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
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
                  <span class={"inline-flex items-center px-2 py-1 rounded-full text-xs font-medium #{AuthHelper.role_badge_class(role.name)} mr-1"}>
                    {role.name}
                  </span>
                <% end %>
              </dd>
            </div>

            <div>
              <dt class="text-sm font-medium text-gray-500">Last Login</dt>

              <dd class="mt-1 text-sm text-gray-900">
                <%= if @current_user.current_sign_in_at do %>
                  {Calendar.strftime(@current_user.current_sign_in_at, "%B %d, %Y at %I:%M %p")}
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
