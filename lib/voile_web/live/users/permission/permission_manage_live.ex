defmodule VoileWeb.Users.Permission.ManageLive do
  use VoileWeb, :live_view_dashboard

  alias VoileWeb.Auth.PermissionManager
  alias Voile.Schema.Accounts.Permission

  @impl true
  def mount(_params, _session, socket) do
    handle_mount_errors do
      # Check permission
      authorize!(socket, "permissions.manage")

      {permissions, total_pages, _} = PermissionManager.list_permissions_paginated(1, 10)

      socket =
        socket
        |> assign(page_title: "Permission Management")
        |> assign(searching: false)
        |> assign(current_path: "/manage/settings/permissions")
        |> assign(page: 1, per_page: 10, total_pages: total_pages)
        |> stream(:permissions, permissions)

      {:ok, socket}
    end
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Permission Management")
    |> assign(:permission, nil)
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Permission")
    |> assign(:permission, %Permission{})
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    permission = PermissionManager.get_permission(id)

    socket
    |> assign(:page_title, "Edit Permission")
    |> assign(:permission, permission)
  end

  @impl true
  def handle_event("search", %{"search" => %{"query" => query}}, socket) do
    socket =
      socket
      |> assign(searching: true)

    # Debounce search
    Process.send_after(self(), {:perform_search, query}, 300)

    {:noreply, socket}
  end

  @impl true
  def handle_event("paginate", %{"page" => page}, socket) do
    page = String.to_integer(page)
    per_page = socket.assigns.per_page

    {permissions, total_pages, _} = PermissionManager.list_permissions_paginated(page, per_page)

    socket =
      socket
      |> stream(:permissions, permissions, reset: true)
      |> assign(:page, page)
      |> assign(:total_pages, total_pages)

    {:noreply, socket}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    permission = PermissionManager.get_permission(id)

    case can_delete_permission?(permission) do
      {:ok, _} ->
        case PermissionManager.delete_permission(permission) do
          {:ok, _} ->
            {:noreply,
             socket
             |> put_flash(:info, "Permission deleted successfully")
             |> stream_delete(:permissions, permission)}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Failed to delete permission")}
        end

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, reason)}
    end
  end

  @impl true
  def handle_info({:perform_search, query}, socket) do
    if query == "" do
      # If search is cleared, reload with pagination
      {perms, total_pages, _} =
        PermissionManager.list_permissions_paginated(1, socket.assigns.per_page)

      {:noreply,
       socket
       |> assign(searching: false)
       |> assign(page: 1)
       |> assign(total_pages: total_pages)
       |> stream(:permissions, perms, reset: true)}
    else
      permissions = search_permissions(query)

      {:noreply,
       socket
       |> assign(searching: false)
       |> assign(page: 1)
       |> assign(total_pages: 1)
       |> stream(:permissions, permissions, reset: true)}
    end
  end

  @impl true
  def handle_info(
        {VoileWeb.Users.Permission.ManageLive.FormComponent, {:saved, permission}},
        socket
      ) do
    {:noreply,
     socket
     |> put_flash(:info, "Permission saved successfully")
     |> stream_insert(:permissions, permission)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        Permission Management
        <:subtitle>Manage system permissions and access controls</:subtitle>

        <:actions>
          <%= if can?(@current_scope.user, "permissions.manage") do %>
            <.link patch={~p"/manage/settings/permissions/new"}>
              <.button>New Permission</.button>
            </.link>
          <% end %>
        </:actions>
      </.header>

      <div class="flex gap-4">
        <div class="w-full max-w-64">
          <.dashboard_settings_sidebar
            current_user={@current_scope.user}
            current_path={@current_path}
          />
        </div>

        <div class="w-full bg-white dark:bg-gray-700 shadow-sm rounded-lg p-6">
          <div class="mb-6">
            <.form for={%{}} phx-change="search" id="search-form">
              <div class="relative">
                <.input
                  type="text"
                  name="search[query]"
                  value=""
                  placeholder="Search permissions by name, resource, or action..."
                  phx-debounce="300"
                />
                <%= if @searching do %>
                  <div class="absolute right-3 top-3">
                    <svg
                      class="animate-spin h-5 w-5 text-gray-400"
                      xmlns="http://www.w3.org/2000/svg"
                      fill="none"
                      viewBox="0 0 24 24"
                    >
                      <circle
                        class="opacity-25"
                        cx="12"
                        cy="12"
                        r="10"
                        stroke="currentColor"
                        stroke-width="4"
                      >
                      </circle>

                      <path
                        class="opacity-75"
                        fill="currentColor"
                        d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
                      >
                      </path>
                    </svg>
                  </div>
                <% end %>
              </div>
            </.form>
          </div>

          <.table
            id="permissions"
            rows={@streams.permissions}
            row_click={
              fn {_id, permission} -> JS.navigate(~p"/manage/settings/permissions/#{permission}") end
            }
          >
            <:col :let={{_id, permission}} label="Name">
              <span class="font-medium font-mono text-sm">{permission.name}</span>
            </:col>

            <:col :let={{_id, permission}} label="Resource">
              <span class="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-blue-100 text-blue-800 dark:bg-blue-900 dark:text-blue-200">
                {permission.resource}
              </span>
            </:col>

            <:col :let={{_id, permission}} label="Action">
              <span class="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-200">
                {permission.action}
              </span>
            </:col>

            <:col :let={{_id, permission}} label="Description">{permission.description || "-"}</:col>

            <:action :let={{_id, permission}}>
              <div class="sr-only">
                <.link navigate={~p"/manage/settings/permissions/#{permission}"}>Show</.link>
              </div>

              <%= if can?(@current_scope.user, "permissions.manage") do %>
                <.link navigate={~p"/manage/settings/permissions/#{permission}/edit"}>Edit</.link>
              <% end %>
            </:action>

            <:action :let={{id, permission}}>
              <%= if can?(@current_scope.user, "permissions.manage") do %>
                <.link
                  phx-click={JS.push("delete", value: %{id: permission.id}) |> hide("##{id}")}
                  data-confirm="Are you sure you want to delete this permission?"
                >
                  Delete
                </.link>
              <% end %>
            </:action>
          </.table>
          <.pagination page={@page} total_pages={@total_pages} event="paginate" />
        </div>
      </div>
    </div>

    <.modal
      :if={@live_action in [:new, :edit]}
      id="permission-modal"
      show
      on_cancel={JS.patch(~p"/manage/settings/permissions")}
    >
      <.live_component
        module={VoileWeb.Users.Permission.ManageLive.FormComponent}
        id={@permission.id || :new}
        title={@page_title}
        action={@live_action}
        permission={@permission}
        patch={~p"/manage/settings/permissions"}
        current_scope={@current_scope}
      />
    </.modal>
    """
  end

  defp search_permissions(query) do
    import Ecto.Query

    Voile.Schema.Accounts.Permission
    |> where([p], ilike(p.name, ^"%#{query}%"))
    |> or_where([p], ilike(p.resource, ^"%#{query}%"))
    |> or_where([p], ilike(p.action, ^"%#{query}%"))
    |> or_where([p], ilike(p.description, ^"%#{query}%"))
    |> order_by([p], p.name)
    |> Voile.Repo.all()
  end

  defp can_delete_permission?(permission) do
    # Check if permission is assigned to any roles
    role_count = count_roles_with_permission(permission.id)

    if role_count > 0 do
      {:error, "Cannot delete permission that is assigned to #{role_count} role(s)"}
    else
      {:ok, permission}
    end
  end

  defp count_roles_with_permission(permission_id) do
    import Ecto.Query

    Voile.Schema.Accounts.RolePermission
    |> where([rp], rp.permission_id == ^permission_id)
    |> Voile.Repo.aggregate(:count, :id)
  end
end
