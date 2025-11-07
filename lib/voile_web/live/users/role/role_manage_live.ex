defmodule VoileWeb.Users.Role.ManageLive do
  use VoileWeb, :live_view_dashboard

  alias VoileWeb.Auth.PermissionManager
  alias Voile.Schema.Accounts.Role

  @impl true
  def mount(_params, _session, socket) do
    handle_mount_errors do
      # Check permission: require explicit RBAC `roles.read` to view this page
      authorize!(socket, "roles.read")

      is_super_admin = VoileWeb.Auth.Authorization.is_super_admin?(socket)

      {roles, total_pages} = PermissionManager.list_roles_paginated(1, 10)

      socket =
        socket
        |> assign(page_title: "Role Management")
        |> assign(searching: false)
        |> assign(current_path: "/manage/settings/roles")
        |> assign(page: 1, per_page: 10, total_pages: total_pages)
        |> assign(:is_super_admin, is_super_admin)
        |> stream(:roles, roles)

      {:ok, socket}
    end
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Role Management")
    |> assign(:role, nil)
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Role")
    |> assign(:role, %Role{})
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    role = PermissionManager.get_role(id)

    socket
    |> assign(:page_title, "Edit Role")
    |> assign(:role, role)
  end

  @impl true
  def handle_event("search", %{"query" => query}, socket) do
    socket = assign(socket, searching: true)

    if query == "" do
      {roles, total_pages} = PermissionManager.list_roles_paginated(1, socket.assigns.per_page)

      socket =
        socket
        |> stream(:roles, roles, reset: true)
        |> assign(searching: false)
        |> assign(page: 1)
        |> assign(total_pages: total_pages)

      {:noreply, socket}
    else
      roles = search_roles(query)

      socket =
        socket
        |> stream(:roles, roles, reset: true)
        |> assign(searching: false)
        |> assign(page: 1)
        |> assign(total_pages: 1)

      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("paginate", %{"page" => page}, socket) do
    page = String.to_integer(page)
    per_page = socket.assigns.per_page

    {roles, total_pages} = PermissionManager.list_roles_paginated(page, per_page)

    socket =
      socket
      |> stream(:roles, roles, reset: true)
      |> assign(:page, page)
      |> assign(:total_pages, total_pages)

    {:noreply, socket}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    # Only super_admins can delete roles
    if not socket.assigns[:is_super_admin] do
      {:noreply, put_flash(socket, :error, "Only super admins can delete roles")}
    else
      role = PermissionManager.get_role(id)

      case can_delete_role?(role) do
        {:ok, _} ->
          case PermissionManager.delete_role(role) do
            {:ok, _} ->
              {:noreply,
               socket
               |> put_flash(:info, "Role deleted successfully")
               |> stream_delete(:roles, role)}

            {:error, _changeset} ->
              {:noreply,
               socket
               |> put_flash(:error, "Failed to delete role")}
          end

        {:error, reason} ->
          {:noreply, put_flash(socket, :error, reason)}
      end
    end
  end

  @impl true
  def handle_info({VoileWeb.Users.Role.ManageLive.FormComponent, {:saved, role}}, socket) do
    {:noreply, stream_insert(socket, :roles, role)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        Role Management
        <:subtitle>Manage system roles and their permissions</:subtitle>

        <:actions>
          <%= if @is_super_admin do %>
            <.link patch={~p"/manage/settings/roles/new"}><.button>New Role</.button></.link>
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
            <.form for={%{}} as={:search} phx-change="search" class="flex gap-4">
              <div class="flex items-center gap-2 w-full">
                <.input name="query" phx-debounce="300" placeholder="Search roles..." value="" />
                <%= if @searching do %>
                  <div class="flex items-center gap-2">
                    <svg
                      class="w-4 h-4 text-gray-500 animate-spin"
                      xmlns="http://www.w3.org/2000/svg"
                      fill="none"
                      viewBox="0 0 24 24"
                      aria-hidden="true"
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
                        d="M4 12a8 8 0 018-8v4a4 4 0 00-4 4H4z"
                      >
                      </path>
                    </svg>
                     <span class="text-sm text-gray-500">Searching...</span>
                  </div>
                <% end %>
              </div>
            </.form>
          </div>

          <.table
            id="roles"
            rows={@streams.roles}
            row_click={fn {_id, role} -> JS.navigate(~p"/manage/settings/roles/#{role}") end}
          >
            <:col :let={{_id, role}} label="Name">
              <div class="flex items-center gap-2">
                <span class="font-medium">{role.name}</span>
                <%= if role.is_system_role do %>
                  <span class="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-voile-info/10 text-voile-info">
                    System
                  </span>
                <% end %>
              </div>
            </:col>

            <:col :let={{_id, role}} label="Description">{role.description || "-"}</:col>

            <:col :let={{_id, role}} label="Permissions">
              <span class="text-sm text-gray-500">{length(role.permissions || [])} permissions</span>
            </:col>

            <:col :let={{_id, role}} label="Users">
              <span class="text-sm text-gray-500">{count_users_with_role(role.id)} users</span>
            </:col>

            <:action :let={{_id, role}}>
              <div class="sr-only">
                <.link navigate={~p"/manage/settings/roles/#{role}"}>Show</.link>
              </div>

              <%= if @is_super_admin do %>
                <.link patch={~p"/manage/settings/roles/#{role}/edit"}>Edit</.link>
              <% end %>
            </:action>

            <:action :let={{id, role}}>
              <%= if @is_super_admin and not role.is_system_role do %>
                <.link
                  phx-click={JS.push("delete", value: %{id: role.id}) |> hide("##{id}")}
                  data-confirm="Are you sure you want to delete this role?"
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
      id="role-modal"
      show
      on_cancel={JS.patch(~p"/manage/settings/roles")}
    >
      <.live_component
        module={VoileWeb.Users.Role.ManageLive.FormComponent}
        id={@role.id || :new}
        title={@page_title}
        action={@live_action}
        role={@role}
        patch={~p"/manage/settings/roles"}
        current_scope={@current_scope}
      />
    </.modal>
    """
  end

  defp search_roles(query) do
    import Ecto.Query

    Voile.Schema.Accounts.Role
    |> where([r], ilike(r.name, ^"%#{query}%") or ilike(r.description, ^"%#{query}%"))
    |> Voile.Repo.all()
    |> Enum.map(&Voile.Repo.preload(&1, :permissions))
  end

  defp count_users_with_role(role_id) do
    import Ecto.Query

    Voile.Schema.Accounts.UserRoleAssignment
    |> where([ura], ura.role_id == ^role_id)
    |> where(
      [ura],
      is_nil(ura.expires_at) or ura.expires_at > ^DateTime.utc_now()
    )
    |> Voile.Repo.aggregate(:count, :id)
  end

  defp can_delete_role?(role) do
    cond do
      role.is_system_role ->
        {:error, "Cannot delete system roles"}

      count_users_with_role(role.id) > 0 ->
        {:error, "Cannot delete role with assigned users"}

      true ->
        {:ok, role}
    end
  end
end
