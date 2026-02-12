defmodule VoileWeb.Users.Role.ManageLive.Show do
  use VoileWeb, :live_view_dashboard

  alias VoileWeb.Auth.PermissionManager

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    # Check permission
    authorize!(socket, "roles.create")

    role = PermissionManager.get_role(id)

    socket =
      socket
      |> assign(role: role)
      |> assign(:page_title, gettext("Role Details"))
      |> assign(current_path: "/manage/members/management/roles/#{id}")
      |> assign(users_page: 1, users_per_page: 10, users_total_pages: 1)
      |> load_role_users()

    {:ok, socket}
  end

  @impl true
  def handle_event("paginate_users", %{"page" => page}, socket) do
    page = String.to_integer(page)

    socket =
      socket
      |> assign(users_page: page)
      |> load_role_users()

    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <%!-- Breadcrumb --%>
      <.breadcrumb items={[
        %{label: gettext("Manage"), path: ~p"/manage"},
        %{label: gettext("Members"), path: ~p"/manage/members"},
        %{label: gettext("Management"), path: ~p"/manage/members/management"},
        %{label: gettext("Role Management"), path: ~p"/manage/members/management/roles"},
        %{label: String.capitalize(@role.name), path: nil}
      ]} />
      <.header>
        {gettext("Role Details")}
        <:subtitle>{gettext("View role information")}</:subtitle>
      </.header>

      <div class="flex gap-4">
        <div class="w-full bg-white dark:bg-gray-700 p-6 rounded-lg">
          <div class="flex items-center justify-between mb-4">
            <.back navigate={~p"/manage/members/management/roles"}>
              {gettext("Back to Roles")}
            </.back>

            <%= if can?(@current_scope.user, "roles.update") and not @role.is_system_role do %>
              <.link
                navigate={~p"/manage/members/management/roles/#{@role.id}/edit"}
                class="primary-btn"
              >
                {gettext("Edit Role")}
              </.link>
            <% end %>
          </div>

          <div class="bg-white dark:bg-gray-900 shadow-xl rounded-xl p-8">
            <div class="space-y-6">
              <div>
                <h3 class="text-lg font-semibold text-gray-900 dark:text-white mb-4 flex items-center gap-2">
                  {String.capitalize(@role.name)}
                  <%= if @role.is_system_role do %>
                    <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-voile-info/10 text-voile-info">
                      {gettext("System Role")}
                    </span>
                  <% end %>
                </h3>

                <%= if @role.description do %>
                  <p class="text-sm text-gray-600 dark:text-gray-400">{@role.description}</p>
                <% end %>
              </div>

              <div class="border-t border-gray-200 dark:border-gray-700 pt-6">
                <h4 class="text-base font-medium text-gray-900 dark:text-white mb-4">
                  {gettext("Permissions")} ({length(@role.permissions)})
                </h4>

                <%= if length(@role.permissions) > 0 do %>
                  <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-3">
                    <%= for permission <- @role.permissions do %>
                      <div class="flex items-center gap-2 px-3 py-2 bg-green-50 dark:bg-green-900/20 rounded-lg">
                        <.icon name="hero-check-circle" class="w-5 h-5 text-green-600" />
                        <div>
                          <div class="text-sm font-medium text-gray-900 dark:text-white">
                            {permission.name}
                          </div>

                          <%= if permission.description do %>
                            <div class="text-xs text-gray-500 dark:text-gray-400">
                              {permission.description}
                            </div>
                          <% end %>
                        </div>
                      </div>
                    <% end %>
                  </div>
                <% else %>
                  <p class="text-sm text-gray-500 dark:text-gray-400">
                    {gettext("No permissions assigned to this role.")}
                  </p>
                <% end %>
              </div>

              <div class="border-t border-gray-200 dark:border-gray-700 pt-6">
                <h4 class="text-base font-medium text-gray-900 dark:text-white mb-4">
                  {gettext("Assigned Users")} ({length(@role_users)})
                </h4>

                <%= if length(@role_users) > 0 do %>
                  <div class="space-y-2">
                    <%= for user <- @role_users do %>
                      <div class="flex items-center gap-3 p-3 bg-gray-50 dark:bg-gray-800 rounded-lg">
                        <%= if user.user_image do %>
                          <img
                            src={user.user_image}
                            alt={user.fullname || user.username}
                            class="w-10 h-10 rounded-full object-cover"
                            referrerpolicy="no-referrer"
                          />
                        <% else %>
                          <div class="w-10 h-10 rounded-full bg-gray-200 flex items-center justify-center text-sm font-bold text-gray-500">
                            {String.first(user.fullname || user.username) |> String.upcase()}
                          </div>
                        <% end %>

                        <div>
                          <div class="text-sm font-medium text-gray-900 dark:text-white">
                            {user.fullname || user.username}
                          </div>

                          <div class="text-xs text-gray-500 dark:text-gray-400">{user.email}</div>
                        </div>
                      </div>
                    <% end %>
                  </div>

                  <%= if @users_total_pages > 1 do %>
                    <div class="mt-4">
                      <.pagination
                        page={@users_page}
                        total_pages={@users_total_pages}
                        event="paginate_users"
                      />
                    </div>
                  <% end %>
                <% else %>
                  <p class="text-sm text-gray-500 dark:text-gray-400">
                    {gettext("No users assigned to this role.")}
                  </p>
                <% end %>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp load_role_users(socket) do
    page = socket.assigns[:users_page] || 1
    per_page = socket.assigns[:users_per_page] || 10

    {users, total_pages} =
      PermissionManager.list_users_with_role_paginated(
        socket.assigns.role.id,
        page,
        per_page
      )

    socket
    |> assign(role_users: users)
    |> assign(users_total_pages: total_pages)
  end
end
