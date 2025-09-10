defmodule VoileWeb.Users.ManageLive do
  use VoileWeb, :live_view_dashboard

  alias Voile.Schema.Accounts
  alias Voile.Schema.Accounts.User
  alias VoileWeb.Helpers.AuthHelper

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        Users Management
        <:subtitle>Manage system users and their roles</:subtitle>

        <:actions>
          <%= if AuthHelper.can?(@current_scope.user, "users", "create") do %>
            <.link patch={~p"/manage/settings/users/new"}><.button>New User</.button></.link>
          <% end %>
        </:actions>
      </.header>

      <div class="flex gap-4">
        <div class="w-full max-w-64 "><.dashboard_settings_sidebar /></div>

        <div class="w-full bg-white dark:bg-gray-700 shadow-sm rounded-lg p-6">
          <div class="mb-6">
            <.form for={%{}} as={:search} phx-change="search" class="flex gap-4">
              <.input name="query" placeholder="Search users..." value="" />
            </.form>
          </div>

          <.table
            id="users"
            rows={@streams.users}
            row_click={fn {_id, user} -> JS.navigate(~p"/manage/settings/users/#{user}") end}
          >
            <:col :let={{_id, user}} label="User Image">
              <%= if user.user_image do %>
                <img
                  class="h-10 w-10 rounded-full"
                  src={user.user_image}
                  alt={user.fullname || user.username}
                />
              <% else %>
                <div class="h-10 w-10 rounded-full bg-gray-300 flex items-center justify-center">
                  <span class="text-sm font-medium text-gray-700">
                    {String.first(user.fullname || user.username) |> String.upcase()}
                  </span>
                </div>
              <% end %>
            </:col>

            <:col :let={{_id, user}} label="Username">{user.username}</:col>

            <:col :let={{_id, user}} label="Full Name">{user.fullname}</:col>

            <:col :let={{_id, user}} label="Role">
              <span class={"inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium #{VoileWeb.Helpers.AuthHelper.role_badge_class(user.user_role && user.user_role.name || nil)}"}>
                {(user.user_role && user.user_role.name) || "-"}
              </span>
            </:col>

            <:col :let={{_id, user}} label="Status">
              <%= if user.confirmed_at do %>
                <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800">
                  Active
                </span>
              <% else %>
                <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-yellow-100 text-yellow-800">
                  Pending
                </span>
              <% end %>
            </:col>

            <:action :let={{_id, user}}>
              <%= if AuthHelper.can?(@current_scope.user, "users", "read") do %>
                <.link navigate={~p"/manage/settings/users/#{user}"}>Show</.link>
              <% end %>
            </:action>

            <:action :let={{_id, user}}>
              <%= if AuthHelper.can?(@current_scope.user, "users", "update") do %>
                <.link patch={~p"/manage/settings/users/#{user}/edit"}>Edit</.link>
              <% end %>
            </:action>

            <:action :let={{id, user}}>
              <%= if AuthHelper.can?(@current_scope.user, "users", "delete") do %>
                <.link
                  phx-click={JS.push("delete", value: %{id: user.id}) |> hide("##{id}")}
                  data-confirm="Are you sure?"
                >
                  Delete
                </.link>
              <% end %>
            </:action>
          </.table>
          <.pagination page={@page} total_pages={@total_pages} event="paginate" />
        </div>
      </div>

      <.modal
        :if={@live_action in [:new, :edit]}
        id="user-modal"
        show
        on_cancel={JS.patch(~p"/manage/settings/users")}
      >
        <.live_component
          module={VoileWeb.Users.ManageLive.FormComponent}
          id={@user.id || :new}
          title={@page_title}
          action={@live_action}
          node_list={@node_list}
          user_type_options={@user_type_options}
          user={@user}
          patch={~p"/manage/settings/users"}
        />
      </.modal>
    </div>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_scope.user
    node_list = Voile.Schema.System.list_nodes()
    user_type = Voile.Schema.Master.list_mst_member_types()

    socket =
      socket
      |> assign(page: 1, per_page: 10, total_pages: 1)
      |> assign(:node_list, node_list)
      |> assign(:user_type_options, user_type)

    if AuthHelper.can_access?(current_user, "users") do
      {users, total_pages} =
        Accounts.list_users_paginated(socket.assigns.page, socket.assigns.per_page)

      socket =
        socket
        |> stream(:users, users)
        |> assign(total_pages: total_pages)

      {:ok, socket}
    else
      socket =
        socket
        |> put_flash(:error, "You don't have permission to access user management.")
        |> redirect(to: ~p"/manage")

      {:ok, socket}
    end
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    current_user = socket.assigns.current_scope.user

    if AuthHelper.can?(current_user, "users", "update") do
      socket
      |> assign(:page_title, "Edit User")
      |> assign(:user, Accounts.get_user!(id))
    else
      socket
      |> put_flash(:error, "You don't have permission to edit users.")
      |> push_navigate(to: ~p"/manage/settings/users")
    end
  end

  defp apply_action(socket, :new, _params) do
    current_user = socket.assigns.current_scope.user

    if AuthHelper.can?(current_user, "users", "create") do
      socket
      |> assign(:page_title, "New User")
      |> assign(:user, %User{})
    else
      socket
      |> put_flash(:error, "You don't have permission to create users.")
      |> push_navigate(to: ~p"/manage/settings/users")
    end
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Users")
    |> assign(:user, nil)
  end

  @impl true
  def handle_info({VoileWeb.Users.ManageLive.FormComponent, {:saved, user}}, socket) do
    {:noreply, stream_insert(socket, :users, user)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    current_user = socket.assigns.current_scope.user

    if AuthHelper.can?(current_user, "users", "delete") do
      user = Accounts.get_user!(id)
      {:ok, _} = Accounts.delete_user(user)

      {:noreply, stream_delete(socket, :users, user)}
    else
      {:noreply,
       socket
       |> put_flash(:error, "You don't have permission to delete users.")}
    end
  end

  @impl true
  def handle_event("search", %{"search" => %{"query" => query}}, socket) do
    page = socket.assigns[:page] || 1
    per_page = socket.assigns[:per_page] || 10

    {users, total_pages} =
      if query == "",
        do: Accounts.list_users_paginated(page, per_page),
        else: {Accounts.search_users(query), socket.assigns[:total_pages] || 1}

    socket =
      socket
      |> stream(:users, users, reset: true)
      |> assign(:total_pages, total_pages)

    {:noreply, socket}
  end

  def handle_event("search", %{"query" => query}, socket) do
    page = socket.assigns[:page] || 1
    per_page = socket.assigns[:per_page] || 10

    {users, total_pages} =
      if query == "",
        do: Accounts.list_users_paginated(page, per_page),
        else: {Accounts.search_users(query), socket.assigns[:total_pages] || 1}

    socket =
      socket
      |> stream(:users, users, reset: true)
      |> assign(:total_pages, total_pages)

    {:noreply, socket}
  end

  @impl true
  def handle_event("paginate", %{"page" => page}, socket) do
    page = String.to_integer(page)
    per_page = 10

    {users, total_pages} = Accounts.list_users_paginated(page, per_page)

    socket =
      socket
      |> stream(:users, users, reset: true)
      |> assign(:page, page)
      |> assign(:total_pages, total_pages)

    {:noreply, socket}
  end
end
