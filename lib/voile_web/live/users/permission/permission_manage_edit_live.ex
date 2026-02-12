defmodule VoileWeb.Users.Permission.ManageLive.Edit do
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
      |> assign(page_title: gettext("Edit Permission") <> " - #{permission.name}")
      |> assign(current_path: "/manage/settings/permissions/#{id}/edit")
      |> load_permission_roles()

    {:ok, socket}
  end

  @impl true
  def handle_info(
        {VoileWeb.Users.Permission.ManageLive.FormComponent, {:saved, permission}},
        socket
      ) do
    {:noreply,
     socket
     |> assign(permission: permission)
     |> put_flash(:info, gettext("Permission updated successfully"))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        {gettext("Edit Permission")}
        <:subtitle>{gettext("Update permission information")}</:subtitle>
      </.header>

      <div class="flex gap-4">
        <div class="w-full max-w-64">
          <.dashboard_settings_sidebar
            current_user={@current_scope.user}
            current_path={@current_path}
          />
        </div>

        <div class="w-full">
          <div class="mb-4">
            <.back navigate={~p"/manage/settings/permissions/#{@permission.id}"}>
              {gettext("Back to Permission")}
            </.back>
          </div>

          <div class="space-y-8">
            <%!-- Permission Basic Information --%>
            <div class="bg-white dark:bg-gray-900 shadow-xl rounded-xl p-8">
              <h3 class="text-lg font-semibold text-gray-900 dark:text-white mb-6">
                {gettext("Basic Information")}
              </h3>

              <.live_component
                module={VoileWeb.Users.Permission.ManageLive.FormComponent}
                id={@permission.id}
                title={gettext("Edit Permission")}
                action={:edit}
                permission={@permission}
                patch={~p"/manage/settings/permissions/#{@permission.id}"}
                current_scope={@current_scope}
              />
            </div>
            <%!-- Roles with this Permission --%>
            <div class="bg-white dark:bg-gray-900 shadow-xl rounded-xl p-8">
              <h3 class="text-lg font-semibold text-gray-900 dark:text-white mb-6">
                {gettext("Roles with This Permission")}
                <span class="text-sm font-normal text-gray-500 dark:text-gray-400">
                  ({length(@roles)} {gettext("role")}{if length(@roles) != 1, do: gettext("s")})
                </span>
              </h3>

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
