defmodule VoileWeb.Users.Permission.ManageLive.Show do
  use VoileWeb, :live_view_dashboard

  alias VoileWeb.Auth.PermissionManager

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    # Check permission
    authorize!(socket, "permissions.manage")

    permission = PermissionManager.get_permission(id)

    socket =
      socket
      |> assign(permission: permission)
      |> assign(:page_title, gettext("Permission Details"))
      |> assign(current_path: "/manage/settings/permissions/#{id}")
      |> load_permission_roles()

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        {gettext("Permission Details")}
        <:subtitle>{gettext("View permission information and assigned roles")}</:subtitle>
      </.header>

      <div class="flex gap-4">
        <div class="w-full max-w-64">
          <.dashboard_settings_sidebar
            current_user={@current_scope.user}
            current_path={@current_path}
          />
        </div>

        <div class="w-full bg-white dark:bg-gray-700 p-6 rounded-lg">
          <div class="flex items-center justify-between mb-4">
            <.back navigate={~p"/manage/settings/permissions"}>
              {gettext("Back to Permissions")}
            </.back>

            <%= if can?(@current_scope.user, "permissions.manage") do %>
              <.link
                navigate={~p"/manage/settings/permissions/#{@permission.id}/edit"}
                class="primary-btn"
              >
                {gettext("Edit Permission")}
              </.link>
            <% end %>
          </div>

          <div class="bg-white dark:bg-gray-900 shadow-xl rounded-xl p-8">
            <div class="space-y-6">
              <div>
                <h3 class="text-lg font-semibold text-gray-900 dark:text-white mb-4">
                  {gettext("Permission Information")}
                </h3>

                <dl class="grid grid-cols-1 gap-4 sm:grid-cols-2">
                  <div>
                    <dt class="text-sm font-medium text-gray-500 dark:text-gray-400">
                      {gettext("Name")}
                    </dt>

                    <dd class="mt-1 text-sm text-gray-900 dark:text-white font-mono">
                      {@permission.name}
                    </dd>
                  </div>

                  <div>
                    <dt class="text-sm font-medium text-gray-500 dark:text-gray-400">
                      {gettext("Resource")}
                    </dt>

                    <dd class="mt-1">
                      <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-blue-100 text-blue-800 dark:bg-blue-900 dark:text-blue-200">
                        {@permission.resource}
                      </span>
                    </dd>
                  </div>

                  <div>
                    <dt class="text-sm font-medium text-gray-500 dark:text-gray-400">
                      {gettext("Action")}
                    </dt>

                    <dd class="mt-1">
                      <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-200">
                        {@permission.action}
                      </span>
                    </dd>
                  </div>

                  <div class="sm:col-span-2">
                    <dt class="text-sm font-medium text-gray-500 dark:text-gray-400">
                      {gettext("Description")}
                    </dt>

                    <dd class="mt-1 text-sm text-gray-900 dark:text-white">
                      {@permission.description || gettext("No description provided")}
                    </dd>
                  </div>

                  <div>
                    <dt class="text-sm font-medium text-gray-500 dark:text-gray-400">
                      {gettext("Created At")}
                    </dt>

                    <dd class="mt-1 text-sm text-gray-900 dark:text-white">
                      {Calendar.strftime(@permission.inserted_at, "%B %d, %Y %I:%M %p")}
                    </dd>
                  </div>

                  <div>
                    <dt class="text-sm font-medium text-gray-500 dark:text-gray-400">
                      {gettext("Updated At")}
                    </dt>

                    <dd class="mt-1 text-sm text-gray-900 dark:text-white">
                      {Calendar.strftime(@permission.updated_at, "%B %d, %Y %I:%M %p")}
                    </dd>
                  </div>
                </dl>
              </div>

              <div class="border-t border-gray-200 dark:border-gray-700 pt-6">
                <h4 class="text-md font-semibold text-gray-900 dark:text-white mb-4">
                  {gettext("Roles with This Permission")}
                  <span class="text-sm font-normal text-gray-500 dark:text-gray-400">
                    ({length(@roles)} {gettext("role")}{if length(@roles) != 1, do: gettext("s")})
                  </span>
                </h4>

                <%= if @roles == [] do %>
                  <div class="text-center py-8 text-gray-500 dark:text-gray-400">
                    <.icon name="hero-shield-exclamation" class="w-12 h-12 mx-auto mb-2 opacity-50" />
                    <p>{gettext("No roles currently have this permission")}</p>
                  </div>
                <% else %>
                  <div class="space-y-2">
                    <%= for role <- @roles do %>
                      <div class="flex items-center justify-between p-3 bg-gray-50 dark:bg-gray-800 rounded-lg hover:bg-gray-100 dark:hover:bg-gray-750 transition-colors">
                        <div class="flex items-center gap-3">
                          <.icon
                            name="hero-shield-check"
                            class="w-5 h-5 text-blue-600 dark:text-blue-400"
                          />
                          <div>
                            <div class="font-medium text-gray-900 dark:text-white flex items-center gap-2">
                              {String.capitalize(role.name)}
                              <%= if role.is_system_role do %>
                                <span class="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-voile-primary/10 text-voile-primary dark:bg-voile-primary/30 dark:text-voile-primary">
                                  {gettext("System")}
                                </span>
                              <% end %>
                            </div>

                            <%= if role.description do %>
                              <div class="text-sm text-gray-500 dark:text-gray-400">
                                {role.description}
                              </div>
                            <% end %>
                          </div>
                        </div>

                        <.link
                          navigate={~p"/manage/settings/roles/#{role.id}"}
                          class="text-sm text-blue-600 dark:text-blue-400 hover:text-blue-800 dark:hover:text-blue-300"
                        >
                          {gettext("View Role →")}
                        </.link>
                      </div>
                    <% end %>
                  </div>
                <% end %>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp load_permission_roles(socket) do
    import Ecto.Query

    roles =
      Voile.Schema.Accounts.Role
      |> join(:inner, [r], rp in Voile.Schema.Accounts.RolePermission, on: r.id == rp.role_id)
      |> where([r, rp], rp.permission_id == ^socket.assigns.permission.id)
      |> order_by([r], r.name)
      |> Voile.Repo.all()

    assign(socket, :roles, roles)
  end
end
