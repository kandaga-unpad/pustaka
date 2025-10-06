defmodule VoileWeb.Users.Role.ManageLive.Edit do
  use VoileWeb, :live_view_dashboard

  alias VoileWeb.Auth.{PermissionManager, Authorization}
  alias Voile.Schema.Accounts

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    # Check permission
    authorize!(socket, "roles.update")

    role = PermissionManager.get_role(id)

    if role.is_system_role do
      {:ok,
       socket
       |> put_flash(:error, "System roles cannot be edited")
       |> push_navigate(to: ~p"/manage/settings/roles/#{role.id}")}
    else
      socket =
        socket
        |> assign(role: role)
        |> assign(page_title: "Edit Role - #{role.name}")
        |> assign(current_path: "/manage/settings/roles/#{id}/edit")
        |> assign(:all_permissions, PermissionManager.list_permissions())
        |> assign(searching_users: false)
        |> assign(search_results: [])
        |> assign(showing_add_user: false)
        |> load_role_users()

      {:ok, socket}
    end
  end

  @impl true
  def handle_event("toggle_add_user", _params, socket) do
    {:noreply, assign(socket, showing_add_user: !socket.assigns.showing_add_user)}
  end

  @impl true
  def handle_event("search_users", %{"query" => query}, socket) do
    socket = assign(socket, searching_users: true)

    results =
      if String.length(query) >= 2 do
        search_users(query, socket.assigns.role.id)
      else
        []
      end

    socket =
      socket
      |> assign(search_results: results)
      |> assign(searching_users: false)

    {:noreply, socket}
  end

  @impl true
  def handle_event("add_user_to_role", %{"user-id" => user_id}, socket) do
    authorize!(socket, "roles.update")

    case Authorization.assign_role(
           user_id,
           socket.assigns.role.id,
           assigned_by_id: socket.assigns.current_scope.user.id
         ) do
      {:ok, _assignment} ->
        socket =
          socket
          |> put_flash(:info, "User assigned to role successfully")
          |> assign(showing_add_user: false)
          |> assign(search_results: [])
          |> load_role_users()

        {:noreply, socket}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to assign user to role")}
    end
  end

  @impl true
  def handle_event("remove_user_from_role", %{"user-id" => user_id}, socket) do
    authorize!(socket, "roles.update")

    case Authorization.revoke_role(user_id, socket.assigns.role.id) do
      {count, _} when count > 0 ->
        socket =
          socket
          |> put_flash(:info, "User removed from role successfully")
          |> load_role_users()

        {:noreply, socket}

      _ ->
        {:noreply, put_flash(socket, :error, "Failed to remove user from role")}
    end
  end

  @impl true
  def handle_event("toggle_permission", %{"permission-id" => permission_id}, socket) do
    authorize!(socket, "permissions.manage")

    role = socket.assigns.role
    permission_id = String.to_integer(permission_id)

    # Check if permission is currently assigned
    has_permission? = Enum.any?(role.permissions, &(&1.id == permission_id))

    result =
      if has_permission? do
        PermissionManager.remove_permission_from_role(role.id, permission_id)
      else
        PermissionManager.add_permission_to_role(role.id, permission_id)
      end

    case result do
      {:ok, _} ->
        # Reload role with updated permissions
        role = PermissionManager.get_role(role.id)

        socket =
          socket
          |> assign(role: role)
          |> put_flash(:info, "Permission updated successfully")

        {:noreply, socket}

      _ ->
        {:noreply, put_flash(socket, :error, "Failed to update permission")}
    end
  end

  @impl true
  def handle_info({VoileWeb.Users.Role.ManageLive.FormComponent, {:saved, role}}, socket) do
    {:noreply,
     socket
     |> assign(role: role)
     |> put_flash(:info, "Role updated successfully")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        Edit Role
        <:subtitle>Update role information and manage permissions</:subtitle>
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
            <.back navigate={~p"/manage/settings/roles/#{@role.id}"}>Back to Role</.back>
          </div>
          
          <div class="space-y-8">
            <%!-- Role Basic Information --%>
            <div class="bg-white dark:bg-gray-900 shadow-xl rounded-xl p-8">
              <h3 class="text-lg font-semibold text-gray-900 dark:text-white mb-6">
                Basic Information
              </h3>
              
              <.live_component
                module={VoileWeb.Users.Role.ManageLive.FormComponent}
                id={@role.id}
                title="Edit Role"
                action={:edit}
                role={@role}
                patch={~p"/manage/settings/roles/#{@role.id}"}
                current_scope={@current_scope}
              />
            </div>
             <%!-- Permissions Management --%>
            <%= if can?(@current_scope.user, "permissions.manage") do %>
              <div class="bg-white dark:bg-gray-900 shadow-xl rounded-xl p-8">
                <h3 class="text-lg font-semibold text-gray-900 dark:text-white mb-6">
                  Manage Permissions
                </h3>
                
                <div class="space-y-4">
                  <%= for permission <- @all_permissions do %>
                    <% has_permission? = Enum.any?(@role.permissions, &(&1.id == permission.id)) %>
                    <div class="flex items-center justify-between p-4 bg-gray-50 dark:bg-gray-800 rounded-lg">
                      <div class="flex-1">
                        <div class="text-sm font-medium text-gray-900 dark:text-white">
                          {permission.name}
                        </div>
                        
                        <%= if permission.description do %>
                          <div class="text-xs text-gray-500 dark:text-gray-400 mt-1">
                            {permission.description}
                          </div>
                        <% end %>
                        
                        <div class="mt-2 flex items-center gap-2 text-xs text-gray-500">
                          <span class="px-2 py-0.5 bg-blue-100 text-blue-800 rounded">
                            {permission.resource}
                          </span>
                          <span class="px-2 py-0.5 bg-purple-100 text-purple-800 rounded">
                            {permission.action}
                          </span>
                        </div>
                      </div>
                      
                      <button
                        type="button"
                        phx-click="toggle_permission"
                        phx-value-permission-id={permission.id}
                        class={[
                          "relative inline-flex h-6 w-11 items-center rounded-full transition-colors focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-green-500",
                          if(has_permission?,
                            do: "bg-green-600",
                            else: "bg-gray-200 dark:bg-gray-700"
                          )
                        ]}
                      >
                        <span class="sr-only">Toggle permission</span>
                        <span class={[
                          "inline-block h-4 w-4 transform rounded-full bg-white transition-transform",
                          if(has_permission?, do: "translate-x-6", else: "translate-x-1")
                        ]} />
                      </button>
                    </div>
                  <% end %>
                </div>
              </div>
            <% end %>
             <%!-- User Assignment --%>
            <%= if can?(@current_scope.user, "roles.update") do %>
              <div class="bg-white dark:bg-gray-900 shadow-xl rounded-xl p-8">
                <div class="flex items-center justify-between mb-6">
                  <h3 class="text-lg font-semibold text-gray-900 dark:text-white">
                    Assigned Users ({length(@role_users)})
                  </h3>
                  
                  <.button phx-click="toggle_add_user" class="secondary-btn">
                    <.icon name="hero-plus" class="w-4 h-4 mr-1" /> Add User
                  </.button>
                </div>
                
                <%= if @showing_add_user do %>
                  <div class="mb-6 p-4 bg-gray-50 dark:bg-gray-800 rounded-lg">
                    <.form for={%{}} as={:user_search} phx-change="search_users">
                      <.input
                        name="query"
                        phx-debounce="300"
                        placeholder="Search users by name or email..."
                        value=""
                      />
                    </.form>
                    
                    <%= if @searching_users do %>
                      <div class="mt-2 text-sm text-gray-500">Searching...</div>
                    <% end %>
                    
                    <%= if length(@search_results) > 0 do %>
                      <div class="mt-2 space-y-1">
                        <%= for user <- @search_results do %>
                          <div class="flex items-center justify-between p-2 bg-white dark:bg-gray-700 rounded">
                            <div>
                              <div class="text-sm font-medium">{user.fullname || user.username}</div>
                              
                              <div class="text-xs text-gray-500">{user.email}</div>
                            </div>
                            
                            <.button
                              phx-click="add_user_to_role"
                              phx-value-user-id={user.id}
                              class="text-xs"
                            >
                              Add
                            </.button>
                          </div>
                        <% end %>
                      </div>
                    <% end %>
                  </div>
                <% end %>
                
                <%= if length(@role_users) > 0 do %>
                  <div class="space-y-2">
                    <%= for user <- @role_users do %>
                      <div class="flex items-center justify-between p-3 bg-gray-50 dark:bg-gray-800 rounded-lg">
                        <div class="flex items-center gap-3">
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
                        
                        <.button
                          phx-click="remove_user_from_role"
                          phx-value-user-id={user.id}
                          data-confirm="Remove this user from the role?"
                          class="text-xs text-red-600 hover:text-red-800"
                        >
                          Remove
                        </.button>
                      </div>
                    <% end %>
                  </div>
                <% else %>
                  <p class="text-sm text-gray-500 dark:text-gray-400">
                    No users assigned to this role.
                  </p>
                <% end %>
              </div>
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp load_role_users(socket) do
    users =
      PermissionManager.list_users_with_role(socket.assigns.role.id)
      |> Enum.map(& &1.user)

    assign(socket, role_users: users)
  end

  defp search_users(query, role_id) do
    import Ecto.Query

    # Get users already assigned to this role
    assigned_user_ids =
      Voile.Schema.Accounts.UserRoleAssignment
      |> where([ura], ura.role_id == ^role_id)
      |> where(
        [ura],
        is_nil(ura.expires_at) or ura.expires_at > ^DateTime.utc_now()
      )
      |> select([ura], ura.user_id)
      |> Voile.Repo.all()

    # Search for users not already assigned
    Accounts.User
    |> where(
      [u],
      (ilike(u.fullname, ^"%#{query}%") or ilike(u.email, ^"%#{query}%") or
         ilike(u.username, ^"%#{query}%")) and u.id not in ^assigned_user_ids
    )
    |> limit(10)
    |> Voile.Repo.all()
  end
end
