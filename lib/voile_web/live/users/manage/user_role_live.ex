defmodule VoileWeb.Users.ManageLive.Role do
  use VoileWeb, :live_view

  alias Voile.Schema.Accounts
  alias Voile.Schema.Accounts.UserRole
  alias VoileWeb.Helpers.AuthHelper

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      Roles Management
      <:subtitle>Manage user roles and permissions</:subtitle>
      
      <:actions>
        <%= if VoileWeb.Helpers.AuthHelper.can?(@current_user, "roles", "create") do %>
          <.link patch={~p"/manage/settings/users/roles/new"}><.button>New Role</.button></.link>
        <% end %>
      </:actions>
    </.header>

    <.table
      id="user_roles"
      rows={@streams.user_roles}
      row_click={
        fn {_id, user_role} -> JS.navigate(~p"/manage/settings/users/roles/#{user_role}") end
      }
    >
      <:col :let={{_id, user_role}} label="Name">
        <span class={"inline-flex items-center px-3 py-1 rounded-full text-sm font-medium #{VoileWeb.Helpers.AuthHelper.role_badge_class(user_role.name)}"}>
          {user_role.name}
        </span>
      </:col>
      
      <:col :let={{_id, user_role}} label="Description">
        <div class="max-w-xs truncate">{user_role.description}</div>
      </:col>
      
      <:col :let={{_id, user_role}} label="Resources">
        <div class="flex flex-wrap gap-1">
          <%= for resource <- Map.keys(user_role.permissions) |> Enum.take(3) do %>
            <span class="inline-flex items-center px-2 py-1 rounded text-xs font-medium bg-blue-100 text-blue-800">
              {resource}
            </span>
          <% end %>
          
          <%= if map_size(user_role.permissions) > 3 do %>
            <span class="text-xs text-gray-500">+{map_size(user_role.permissions) - 3} more</span>
          <% end %>
        </div>
      </:col>
      
      <:col :let={{_id, user_role}} label="Users Count">
        {length(Accounts.get_users_by_role(user_role.name))}
      </:col>
      
      <:action :let={{_id, user_role}}>
        <%= if AuthHelper.can?(@current_user, "roles", "read") do %>
          <.link navigate={~p"/manage/settings/users/roles/#{user_role}"}>Show</.link>
        <% end %>
      </:action>
      
      <:action :let={{_id, user_role}}>
        <%= if AuthHelper.can?(@current_user, "roles", "update") do %>
          <.link patch={~p"/manage/settings/users/roles/#{user_role}/edit"}>Edit</.link>
        <% end %>
      </:action>
      
      <:action :let={{id, user_role}}>
        <%= if AuthHelper.can?(@current_user, "roles", "delete") do %>
          <.link
            phx-click={JS.push("delete", value: %{id: user_role.id}) |> hide("##{id}")}
            data-confirm="Are you sure? This action cannot be undone."
          >
            Delete
          </.link>
        <% end %>
      </:action>
    </.table>

    <.modal
      :if={@live_action in [:new, :edit]}
      id="user_role-modal"
      show
      on_cancel={JS.patch(~p"/manage/settings/users/roles")}
    >
      <.live_component
        module={VoileWeb.Users.Manage.UserRoleFormComponent}
        id={@user_role.id || :new}
        title={@page_title}
        action={@live_action}
        user_role={@user_role}
        available_resources={@available_resources || []}
        patch={~p"/manage/settings/users/roles"}
      />
    </.modal>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns[:current_user]

    # Check if user has permission to access roles
    if AuthHelper.can_access?(current_user, "roles") do
      {:ok, stream(socket, :user_roles, Accounts.list_user_roles())}
    else
      {:ok,
       socket
       |> put_flash(:error, "You don't have permission to access role management.")
       |> redirect(to: ~p"/manage")}
    end
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    current_user = socket.assigns[:current_user]

    if AuthHelper.can?(current_user, "roles", "update") do
      socket
      |> assign(:page_title, "Edit Role")
      |> assign(:user_role, Accounts.get_user_role!(id))
      |> assign(:available_resources, Accounts.get_available_resources())
    else
      socket
      |> put_flash(:error, "You don't have permission to edit roles.")
      |> push_patch(to: ~p"/manage/settings/users/roles")
    end
  end

  defp apply_action(socket, :new, _params) do
    current_user = socket.assigns[:current_user]

    if AuthHelper.can?(current_user, "roles", "create") do
      socket
      |> assign(:page_title, "New Role")
      |> assign(:user_role, %UserRole{})
      |> assign(:available_resources, Accounts.get_available_resources())
    else
      socket
      |> put_flash(:error, "You don't have permission to create roles.")
      |> push_patch(to: ~p"/manage/settings/users/roles")
    end
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Roles")
    |> assign(:user_role, nil)
  end

  @impl true
  def handle_info({VoileWeb.RoleLive.FormComponent, {:saved, user_role}}, socket) do
    {:noreply, stream_insert(socket, :user_roles, user_role)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    current_user = socket.assigns[:current_user]

    if AuthHelper.can?(current_user, "roles", "delete") do
      user_role = Accounts.get_user_role!(id)

      # Check if role is being used by any users
      users_with_role = Accounts.get_users_by_role(user_role.name)

      if Enum.empty?(users_with_role) do
        {:ok, _} = Accounts.delete_user_role(user_role)
        {:noreply, stream_delete(socket, :user_roles, user_role)}
      else
        {:noreply,
         socket
         |> put_flash(
           :error,
           "Cannot delete role. It is currently assigned to #{length(users_with_role)} user(s)."
         )}
      end
    else
      {:noreply,
       socket
       |> put_flash(:error, "You don't have permission to delete roles.")}
    end
  end
end
