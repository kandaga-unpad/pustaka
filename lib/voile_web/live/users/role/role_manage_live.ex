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

      {roles, total_pages, _} = PermissionManager.list_roles_paginated(1, 10)

      socket =
        socket
        |> assign(page_title: gettext("Role Management"))
        |> assign(searching: false)
        |> assign(current_path: "/manage/members/management/roles")
        |> assign(page: 1, per_page: 10, total_pages: total_pages)
        |> assign(:is_super_admin, is_super_admin)
        |> assign(:all_permissions, PermissionManager.list_permissions())
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
    |> assign(:page_title, gettext("Role Management"))
    |> assign(:role, nil)
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, gettext("New Role"))
    |> assign(:role, %Role{})
    |> assign_form(Role.changeset(%Role{}, %{}))
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    role = PermissionManager.get_role(id)

    socket
    |> assign(:page_title, gettext("Edit Role"))
    |> assign(:role, role)
    |> assign_form(Role.changeset(role, %{}))
  end

  @impl true
  def handle_event("search", %{"query" => query}, socket) do
    socket = assign(socket, searching: true)

    if query == "" do
      {roles, total_pages, _} = PermissionManager.list_roles_paginated(1, socket.assigns.per_page)

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
  def handle_event("validate", %{"role" => role_params}, socket) do
    changeset =
      socket.assigns.role
      |> Role.changeset(role_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  @impl true
  def handle_event("save", %{"role" => role_params}, socket) do
    save_role(socket, socket.assigns.live_action, role_params)
  end

  @impl true
  def handle_event("paginate", %{"page" => page}, socket) do
    page = String.to_integer(page)
    per_page = socket.assigns.per_page

    {roles, total_pages, _} = PermissionManager.list_roles_paginated(page, per_page)

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
      {:noreply, put_flash(socket, :error, gettext("Only super admins can delete roles"))}
    else
      role = PermissionManager.get_role(id)

      case can_delete_role?(role) do
        {:ok, _} ->
          case PermissionManager.delete_role(role) do
            {:ok, _} ->
              {:noreply,
               socket
               |> put_flash(:info, gettext("Role deleted successfully"))
               |> stream_delete(:roles, role)}

            {:error, _changeset} ->
              {:noreply,
               socket
               |> put_flash(:error, gettext("Failed to delete role"))}
          end

        {:error, reason} ->
          {:noreply, put_flash(socket, :error, reason)}
      end
    end
  end

  # Helper functions

  defp save_role(socket, :edit, role_params) do
    case PermissionManager.update_role(socket.assigns.role, role_params) do
      {:ok, role} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Role updated successfully"))
         |> push_navigate(to: ~p"/manage/members/management/roles/#{role.id}")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp save_role(socket, :new, role_params) do
    # Extract permission_ids from params
    permission_ids = Map.get(role_params, "permission_ids", [])
    role_params = Map.delete(role_params, "permission_ids")

    case PermissionManager.create_role(role_params) do
      {:ok, role} ->
        # Assign permissions to the new role
        if length(permission_ids) > 0 do
          permission_ids
          |> Enum.map(&String.to_integer/1)
          |> Enum.each(fn permission_id ->
            PermissionManager.add_permission_to_role(role.id, permission_id)
          end)
        end

        # Reload role with permissions
        role = PermissionManager.get_role(role.id)

        {:noreply,
         socket
         |> put_flash(:info, gettext("Role created successfully"))
         |> push_navigate(to: ~p"/manage/members/management/roles/#{role.id}")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset))
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <%= if @live_action in [:new, :edit] do %>
        <.role_form
          form={@form}
          role={@role}
          action={@live_action}
          is_super_admin={@is_super_admin}
          all_permissions={@all_permissions}
        />
      <% else %>
        <%!-- Breadcrumb --%>
        <.breadcrumb items={[
          %{label: gettext("Manage"), path: ~p"/manage"},
          %{label: gettext("Members"), path: ~p"/manage/members"},
          %{label: gettext("Management"), path: ~p"/manage/members/management"},
          %{label: gettext("Role Management"), path: nil}
        ]} />

        <%!-- Page Header --%>
        <div class="bg-white dark:bg-gray-700 shadow-sm rounded-lg p-6">
          <div class="flex items-center justify-between">
            <div>
              <h1 class="text-2xl font-bold text-gray-900 dark:text-white">
                {gettext("Role Management")}
              </h1>
              <p class="text-gray-600 dark:text-gray-300 mt-1">
                {gettext("Manage system roles and their permissions")}
              </p>
            </div>

            <%= if @is_super_admin do %>
              <.link patch={~p"/manage/members/management/roles/new"}>
                <.button class="bg-gradient-to-r from-voile-primary to-voile-primary/90 hover:from-voile-primary/90 hover:to-voile-primary text-white px-6 py-3 text-lg font-semibold shadow-lg hover:shadow-xl transition-all duration-200 hover:scale-105">
                  <.icon name="hero-plus" class="w-6 h-6 mr-3" /> {gettext("Add New Role")}
                </.button>
              </.link>
            <% end %>
          </div>
        </div>

        <%!-- Search --%>
        <div class="bg-white dark:bg-gray-700 shadow-sm rounded-lg p-6">
          <div class="flex flex-col items-center justify-center lg:flex-row gap-4 mb-6">
            <div class="flex-1">
              <.form for={%{}} phx-change="search" class="flex gap-2">
                <div class="relative flex-1">
                  <.input
                    name="query"
                    value=""
                    placeholder={gettext("Search roles by name or description...")}
                    phx-debounce="300"
                  />
                </div>
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
                    <span class="text-sm text-gray-500">{gettext("Searching...")}</span>
                  </div>
                <% end %>
              </.form>
            </div>
          </div>

          <%!-- Results Summary --%>
          <div class="text-sm text-gray-600 dark:text-gray-300 mb-4">
            {gettext("Showing %{page} of %{total_pages} pages",
              page: @page,
              total_pages: @total_pages
            )}
          </div>

          <%!-- Roles Table --%>
          <div class="overflow-x-auto">
            <.table
              id="roles"
              rows={@streams.roles}
              row_click={
                fn {_id, role} -> JS.navigate(~p"/manage/members/management/roles/#{role}") end
              }
            >
              <:col :let={{_id, role}} label={gettext("Name")}>
                <div class="flex items-center gap-2">
                  <span class="font-medium text-gray-900 dark:text-white">{role.name}</span>
                  <%= if role.is_system_role do %>
                    <span class="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-voile-info/10 text-voile-info">
                      {gettext("System")}
                    </span>
                  <% end %>
                </div>
              </:col>

              <:col :let={{_id, role}} label={gettext("Description")}>
                {role.description || "-"}
              </:col>

              <:col :let={{_id, role}} label={gettext("Permissions")}>
                <span class="text-sm text-gray-500">
                  {length(role.permissions || [])} permissions
                </span>
              </:col>

              <:col :let={{_id, role}} label={gettext("Users")}>
                <span class="text-sm text-gray-500">{count_users_with_role(role.id)} users</span>
              </:col>

              <:action :let={{_id, role}}>
                <.link
                  navigate={~p"/manage/members/management/roles/#{role.id}"}
                  class="inline-flex items-center gap-1 px-2 py-1 text-xs font-medium text-voile-primary bg-voile-primary/10 hover:bg-voile-primary/20 dark:bg-gray-700 dark:hover:bg-gray-600 rounded-md transition-colors"
                >
                  <.icon name="hero-eye" class="w-4 h-4" />
                  <span class="hidden md:inline">{gettext("View")}</span>
                </.link>
              </:action>

              <:action :let={{_id, role}}>
                <%= if @is_super_admin do %>
                  <.link
                    patch={~p"/manage/members/management/roles/#{role.id}/edit"}
                    class="inline-flex items-center gap-1 px-2 py-1 text-xs font-medium text-blue-600 bg-blue-50 hover:bg-blue-100 dark:bg-blue-900/20 dark:text-blue-400 dark:hover:bg-blue-900/40 rounded-md transition-colors"
                  >
                    <.icon name="hero-pencil" class="w-4 h-4" />
                    <span class="hidden md:inline">{gettext("Edit")}</span>
                  </.link>
                <% end %>
              </:action>

              <:action :let={{id, role}}>
                <%= if @is_super_admin and not role.is_system_role do %>
                  <.link
                    phx-click={JS.push("delete", value: %{id: role.id}) |> hide("##{id}")}
                    data-confirm={gettext("Are you sure you want to delete this role?")}
                    class="inline-flex items-center gap-1 px-2 py-1 text-xs font-medium text-red-600 bg-red-50 hover:bg-red-100 dark:bg-red-900/20 dark:text-red-400 dark:hover:bg-red-900/40 rounded-md transition-colors"
                  >
                    <.icon name="hero-trash" class="w-4 h-4" />
                    <span class="hidden md:inline">{gettext("Delete")}</span>
                  </.link>
                <% end %>
              </:action>
            </.table>
          </div>

          <%!-- Pagination --%>
          <%= if @total_pages > 1 do %>
            <div class="flex items-center justify-between mt-6">
              <div class="text-sm text-gray-700 dark:text-gray-300">
                {gettext("Page %{page} of %{total_pages}", page: @page, total_pages: @total_pages)}
              </div>

              <div class="flex items-center gap-2">
                <%= if @page > 1 do %>
                  <.link
                    patch={~p"/manage/members/management/roles?page=#{@page - 1}&query="}
                    class="inline-flex items-center gap-1 px-3 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-md hover:bg-gray-50 hover:border-gray-400 dark:bg-gray-700 dark:border-gray-600 dark:text-gray-300 dark:hover:bg-gray-600 dark:hover:border-gray-500 transition-colors"
                  >
                    <.icon name="hero-chevron-left" class="w-4 h-4" /> {gettext("Previous")}
                  </.link>
                <% end %>

                <%= if @page < @total_pages do %>
                  <.link
                    patch={~p"/manage/members/management/roles?page=#{@page + 1}&query="}
                    class="inline-flex items-center gap-1 px-3 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-md hover:bg-gray-50 hover:border-gray-400 dark:bg-gray-700 dark:border-gray-600 dark:text-gray-300 dark:hover:bg-gray-600 dark:hover:border-gray-500 transition-colors"
                  >
                    {gettext("Next")} <.icon name="hero-chevron-right" class="w-4 h-4" />
                  </.link>
                <% end %>
              </div>
            </div>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  attr :form, :map, required: true
  attr :role, :map, required: true
  attr :action, :atom, required: true
  attr :is_super_admin, :boolean, required: true
  attr :all_permissions, :list, required: true

  def role_form(assigns) do
    ~H"""
    <div class="space-y-6">
      <%!-- Breadcrumb --%>
      <.breadcrumb items={[
        %{label: "Manage", path: ~p"/manage"},
        %{label: "Members", path: ~p"/manage/members"},
        %{label: "Management", path: ~p"/manage/members/management"},
        %{label: "Role Management", path: ~p"/manage/members/management/roles"},
        %{label: if(@action == :new, do: gettext("New Role"), else: gettext("Edit Role")), path: nil}
      ]} />

      <div class="bg-white dark:bg-gray-700 shadow-sm rounded-lg p-6">
        <div class="flex items-center gap-3 mb-6">
          <.icon name="hero-shield-check" class="w-8 h-8 text-voile-primary" />
          <div>
            <h1 class="text-2xl font-bold text-gray-900 dark:text-white">
              {if @action == :new, do: gettext("Add New Role"), else: gettext("Edit Role")}
            </h1>
            <p class="text-gray-600 dark:text-gray-300">
              {if @action == :new,
                do: gettext("Create a new system role with permissions"),
                else: gettext("Update role information and permissions")}
            </p>
          </div>
        </div>

        <.form for={@form} phx-submit="save" phx-change="validate" class="space-y-6">
          <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
            <.input
              field={@form[:name]}
              type="text"
              label={gettext("Role Name")}
              placeholder={gettext("e.g., Content Manager, Moderator")}
              required
              disabled={@role.is_system_role}
            />
            <.input
              field={@form[:description]}
              type="textarea"
              label={gettext("Description")}
              placeholder={gettext("Describe what this role can do...")}
              rows="3"
            />
          </div>

          <%= if @action == :new do %>
            <div class="mt-6">
              <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-4">
                {gettext("Permissions")}
              </label>
              <div class="space-y-2 max-h-96 overflow-y-auto p-4 bg-gray-50 dark:bg-gray-800 rounded-lg border">
                <%= for permission <- @all_permissions do %>
                  <label class="flex items-start gap-3 p-3 hover:bg-white dark:hover:bg-gray-700 rounded cursor-pointer transition-colors">
                    <input
                      type="checkbox"
                      name="role[permission_ids][]"
                      value={permission.id}
                      class="mt-1 h-4 w-4 text-voile-primary border-gray-300 rounded focus:ring-voile-primary"
                    />
                    <div class="flex-1">
                      <div class="text-sm font-medium text-gray-900 dark:text-white">
                        {permission.name}
                      </div>

                      <%= if permission.description do %>
                        <div class="text-xs text-gray-500 dark:text-gray-400 mt-1">
                          {permission.description}
                        </div>
                      <% end %>

                      <div class="mt-2 flex items-center gap-2">
                        <span class="text-xs px-2 py-0.5 bg-voile-info/10 text-voile-info rounded">
                          {permission.resource}
                        </span>
                        <span class="text-xs px-2 py-0.5 bg-voile-primary/10 text-voile-primary rounded">
                          {permission.action}
                        </span>
                      </div>
                    </div>
                  </label>
                <% end %>
              </div>
            </div>
          <% end %>

          <div class="flex items-center gap-4 pt-6 border-t border-gray-200 dark:border-gray-600">
            <.button type="submit" class="primary-btn">
              <.icon
                name={if @action == :new, do: "hero-plus", else: "hero-check"}
                class="w-4 h-4 mr-2"
              />
              {if @action == :new, do: gettext("Create Role"), else: gettext("Update Role")}
            </.button>

            <.link
              navigate={~p"/manage/members/management/roles"}
              class="text-gray-600 hover:text-gray-800 dark:text-gray-400 dark:hover:text-gray-200"
            >
              {gettext("Cancel")}
            </.link>
          </div>
        </.form>
      </div>
    </div>
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
        {:error, gettext("Cannot delete system roles")}

      count_users_with_role(role.id) > 0 ->
        {:error, gettext("Cannot delete role with assigned users")}

      true ->
        {:ok, role}
    end
  end

  # Import for to_form
  import Phoenix.Component
end
