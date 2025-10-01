defmodule VoileWeb.Users.ManageLive do
  use VoileWeb, :live_view_dashboard

  alias Voile.Schema.Accounts
  alias Voile.Schema.Accounts.User

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        Users Management
        <:subtitle>Manage system users and their roles</:subtitle>
        
        <:actions>
          <.link patch={~p"/manage/settings/users/new"}><.button>New User</.button></.link>
        </:actions>
      </.header>
      
      <div class="flex gap-4">
        <div class="w-full max-w-64 ">
          <.dashboard_settings_sidebar current_user={@current_scope.user} />
        </div>
        
        <div class="w-full bg-white dark:bg-gray-700 shadow-sm rounded-lg p-6">
          <div class="mb-6">
            <.form for={%{}} as={:search} phx-change="search" class="flex gap-4">
              <div class="flex items-center gap-2 w-full">
                <.input name="query" phx-debounce="300" placeholder="Search users..." value="" />
                <select name="node_id" id="node-filter" class="w-48">
                  <option value="">All nodes</option>
                  
                  <%= for node <- @node_list do %>
                    <option value={node.id}>{node.name}</option>
                  <% end %>
                </select>
                <select name="user_role_id" id="role-filter" class="w-48">
                  <option value="">All roles</option>
                  
                  <%= for {label, id} <- @user_role_options do %>
                    <option value={id}>{label}</option>
                  <% end %>
                </select>
                <select name="user_type_id" id="member-type-filter" class="w-48">
                  <option value="">All member types</option>
                  
                  <%= for t <- @user_type_options do %>
                    <option value={t.id}>{t.name}</option>
                  <% end %>
                </select>
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
                    </svg> <span class="text-sm text-gray-500">Searching...</span>
                  </div>
                <% end %>
              </div>
            </.form>
          </div>
          
          <.table
            id="users"
            rows={@streams.users}
            row_click={fn {_id, user} -> JS.navigate(~p"/manage/settings/users/#{user}") end}
          >
            <:col :let={{_id, user}} label="Username">{user.username}</:col>
            
            <:col :let={{_id, user}} label="Full Name">{user.fullname}</:col>
            
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
              <.link navigate={~p"/manage/settings/users/#{user}"}>Show</.link>
            </:action>
            
            <:action :let={{_id, user}}>
              <.link patch={~p"/manage/settings/users/#{user}/edit"}>Edit</.link>
            </:action>
            
            <:action :let={{id, user}}>
              <.link
                phx-click={JS.push("delete", value: %{id: user.id}) |> hide("##{id}")}
                data-confirm="Are you sure?"
              >
                Delete
              </.link>
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
          current_scope={@current_scope}
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
      |> assign(:searching, false)
      |> assign(:last_query, nil)
      |> assign(:user_type_options, user_type)

    if current_user do
      {users, total_pages} =
        Accounts.list_users_paginated(socket.assigns.page, socket.assigns.per_page)

      socket =
        socket
        |> stream(:users, users)
        |> assign(total_pages: total_pages)
        |> assign(:search_timer, nil)

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

    socket
    |> assign(:page_title, "Edit User")
    |> assign(:current_user, current_user)
    |> assign(:user, Accounts.get_user!(id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New User")
    |> assign(:user, %User{})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Users")
    |> assign(:user, nil)
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    user = Accounts.get_user!(id)
    {:ok, _} = Accounts.delete_user(user)

    {:noreply, stream_delete(socket, :users, user)}
  end

  @impl true
  def handle_event("search", %{"search" => %{"query" => query}}, socket) do
    # When the from sends a nested "search" map with other filters
    params = Map.get(socket.assigns, :last_search_params, %{}) |> Map.put("query", query)
    do_search(params, socket)
  end

  def handle_event("search", params, socket) do
    # collect params from form submission and pass as map
    query_params =
      case params do
        %{"search" => %{} = s} -> s
        _ -> params
      end

    # persist last search params so the other handler can reuse
    socket = assign(socket, :last_search_params, query_params)

    do_search(query_params, socket)
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

  defp do_search(params, socket) when is_map(params) do
    page = socket.assigns[:page] || 1
    per_page = socket.assigns[:per_page] || 10

    query_string = Map.get(params, "query", "") |> String.trim()

    # If query is empty and no filters provided, just load the paginated list synchronously
    no_filters? =
      query_string == "" and
        Enum.all?(["node_id", "user_role_id", "user_type_id"], fn k ->
          case Map.get(params, k) do
            nil -> true
            "" -> true
            _ -> false
          end
        end)

    cond do
      no_filters? ->
        {users, total_pages} = Accounts.list_users_paginated(page, per_page)

        socket =
          socket
          |> stream(:users, users, reset: true)
          |> assign(:total_pages, total_pages)

        {:noreply, assign(socket, :searching, false)}

      query_string != "" and String.length(query_string) < 2 ->
        # too short, show no results
        socket = socket |> assign(:searching, false)
        {:noreply, socket}

      true ->
        # Run search under Task.Supervisor and let the worker send results back
        caller = self()
        params_copy = params

        Task.Supervisor.async_nolink(Voile.TaskSupervisor, fn ->
          users = Accounts.search_users(params_copy)
          send(caller, {:search_results, params_copy, users})
        end)

        # schedule a timeout in case the worker doesn't respond in time
        timer_ref = Process.send_after(caller, {:search_timeout, params_copy}, 5_000)

        {:noreply,
         socket
         |> assign(:searching, true)
         |> assign(:last_query, params)
         |> assign(:search_timer, timer_ref)}
    end
  end

  @impl true
  def handle_info({:search_results, query, users}, socket) do
    # Ignore stale results if another query was issued after this one
    if socket.assigns[:last_query] == query do
      # cancel the scheduled timeout if present
      if timer = socket.assigns[:search_timer] do
        Process.cancel_timer(timer)
      end

      socket =
        socket
        |> stream(:users, users, reset: true)
        |> assign(:searching, false)
        |> assign(:search_timer, nil)

      {:noreply, socket}
    else
      # stale, ignore
      {:noreply, socket}
    end
  end

  # Some supervisors/wrappers send messages wrapped with a monitor reference
  def handle_info({_, {:search_results, query, users}}, socket) do
    handle_info({:search_results, query, users}, socket)
  end

  @impl true
  def handle_info({VoileWeb.Users.ManageLive.FormComponent, {:saved, user}}, socket) do
    {:noreply, stream_insert(socket, :users, user)}
  end

  @impl true
  def handle_info({:search_timeout, query}, socket) do
    # If the timed out query is the last one issued, clear searching and show a message
    if socket.assigns[:last_query] == query do
      socket = assign(socket, :searching, false)
      {:noreply, put_flash(socket, :error, "Search timed out. Please try again.")}
    else
      {:noreply, socket}
    end
  end

  # allow timeout messages wrapped by monitor refs
  def handle_info({_, {:search_timeout, query}}, socket) do
    handle_info({:search_timeout, query}, socket)
  end
end
