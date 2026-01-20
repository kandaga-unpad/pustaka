defmodule VoileWeb.Dashboard.Members.Management.Index do
  use VoileWeb, :live_view_dashboard

  alias Voile.Repo
  alias Voile.Schema.Accounts.User
  alias Voile.Schema.Master.MemberType
  alias Voile.Schema.System.Node
  alias VoileWeb.Auth.Authorization

  import Ecto.Query

  @per_page 20

  @impl true
  def mount(params, _session, socket) do
    user = socket.assigns.current_scope.user

    is_super_admin = Authorization.is_super_admin?(user)

    socket =
      socket
      |> assign(:page_title, "Member Management")
      |> assign(:user, user)
      |> assign(:is_super_admin, is_super_admin)
      |> assign(:search_query, params["query"] || "")
      |> assign(:selected_node_id, params["node_id"] || (user.node_id && to_string(user.node_id)))
      |> assign(:selected_member_type_id, params["member_type_id"])
      |> assign(:selected_status, params["status"] || "all")
      |> assign(:current_page, String.to_integer(params["page"] || "1"))
      |> assign(:per_page, @per_page)
      |> load_members()
      |> load_filters()

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    socket =
      socket
      |> assign(:search_query, params["query"] || "")
      |> assign(:selected_node_id, params["node_id"])
      |> assign(:selected_member_type_id, params["member_type_id"])
      |> assign(:selected_status, params["status"] || "all")
      |> assign(:current_page, String.to_integer(params["page"] || "1"))
      |> load_members()

    {:noreply, socket}
  end

  @impl true
  def handle_event("search", %{"query" => query}, socket) do
    socket =
      socket
      |> assign(:search_query, query)
      |> assign(:current_page, 1)
      |> load_members()

    {:noreply, socket}
  end

  @impl true
  def handle_event("filter_node", %{"node_id" => node_id}, socket) do
    socket =
      socket
      |> assign(:selected_node_id, node_id)
      |> assign(:current_page, 1)
      |> load_members()

    {:noreply, socket}
  end

  @impl true
  def handle_event("filter_member_type", %{"member_type_id" => member_type_id}, socket) do
    socket =
      socket
      |> assign(:selected_member_type_id, member_type_id)
      |> assign(:current_page, 1)
      |> load_members()

    {:noreply, socket}
  end

  @impl true
  def handle_event("filter_status", %{"status" => status}, socket) do
    socket =
      socket
      |> assign(:selected_status, status)
      |> assign(:current_page, 1)
      |> load_members()

    {:noreply, socket}
  end

  @impl true
  def handle_event("change_page", %{"page" => page}, socket) do
    socket =
      socket
      |> assign(:current_page, String.to_integer(page))
      |> load_members()

    {:noreply, socket}
  end

  @impl true
  def handle_event("delete_member", %{"id" => id}, socket) do
    member = Repo.get!(User, id)

    case Repo.delete(member) do
      {:ok, _} ->
        socket =
          socket
          |> put_flash(:info, "Member deleted successfully")
          |> load_members()

        {:noreply, socket}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete member")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <%!-- Breadcrumb --%>
      <.breadcrumb items={[
        %{label: "Manage", path: ~p"/manage"},
        %{label: "Members", path: ~p"/manage/members"},
        %{label: "Management", path: nil}
      ]} />

      <%!-- Page Header --%>
      <div class="bg-white dark:bg-gray-700 shadow-sm rounded-lg p-6">
        <div class="flex items-center justify-between">
          <div>
            <h1 class="text-2xl font-bold text-gray-900 dark:text-white">Member Management</h1>
            <p class="text-gray-600 dark:text-gray-300 mt-1">
              Manage and oversee all library members
            </p>
          </div>

          <%= if can?(@current_scope.user, "users.create") do %>
            <.link patch={~p"/manage/members/management/new"}>
              <.button class="bg-voile-primary hover:bg-voile-primary/90 text-white">
                <.icon name="hero-plus" class="w-4 h-4 mr-2" /> Add Member
              </.button>
            </.link>
          <% end %>
        </div>
      </div>

      <%!-- Filters and Search --%>
      <div class="bg-white dark:bg-gray-700 shadow-sm rounded-lg p-6">
        <div class="flex flex-col lg:flex-row gap-4 mb-6">
          <%!-- Search --%>
          <div class="flex-1">
            <.form for={%{}} phx-change="search" class="flex gap-2">
              <div class="relative flex-1">
                <.input
                  name="query"
                  value={@search_query}
                  placeholder="Search by name, email, or username..."
                  class="pl-10"
                  phx-debounce="300"
                />
                <.icon
                  name="hero-magnifying-glass"
                  class="absolute left-3 top-1/2 transform -translate-y-1/2 w-4 h-4 text-gray-400"
                />
              </div>
            </.form>
          </div>

          <%!-- Filters --%>
          <div class="flex gap-2">
            <%= if @is_super_admin do %>
              <.form for={%{}} phx-change="filter_node" class="w-48">
                <.input
                  name="node_id"
                  type="select"
                  options={[{"All Nodes", ""}] ++ Enum.map(@nodes, &{&1.name, to_string(&1.id)})}
                  value={@selected_node_id}
                  label="Node"
                />
              </.form>
            <% end %>

            <.form for={%{}} phx-change="filter_member_type" class="w-48">
              <.input
                name="member_type_id"
                type="select"
                options={[{"All Types", ""}] ++ Enum.map(@member_types, &{&1.name, &1.id})}
                value={@selected_member_type_id}
                label="Member Type"
              />
            </.form>

            <.form for={%{}} phx-change="filter_status" class="w-48">
              <.input
                name="status"
                type="select"
                options={[
                  "All Status": "all",
                  Active: "active",
                  Suspended: "suspended",
                  Expired: "expired"
                ]}
                value={@selected_status}
                label="Status"
              />
            </.form>
          </div>
        </div>

        <%!-- Results Summary --%>
        <div class="text-sm text-gray-600 dark:text-gray-300 mb-4">
          Showing {@members.offset + 1} to {min(@members.offset + @per_page, @members.total_entries)} of {@members.total_entries} members
        </div>

        <%!-- Members Table --%>
        <div class="overflow-x-auto">
          <.table
            id="members"
            rows={@members.entries}
            row_click={fn member -> JS.navigate(~p"/manage/members/management/#{member}") end}
          >
            <:col :let={member} label="Member">
              <div class="flex items-center gap-3">
                <div class="flex-shrink-0 h-10 w-10">
                  <div class="h-10 w-10 rounded-full bg-voile-light flex items-center justify-center">
                    <span class="text-sm font-medium text-gray-700">
                      {String.first(member.fullname || "?")}
                    </span>
                  </div>
                </div>
                <div>
                  <div class="font-medium text-gray-900 dark:text-white">{member.fullname}</div>
                  <div class="text-sm text-gray-500 dark:text-gray-400">{member.email}</div>
                  <div class="text-xs text-gray-400 dark:text-gray-500">{member.username}</div>
                </div>
              </div>
            </:col>

            <:col :let={member} label="Member Type">{member.user_type && member.user_type.name}</:col>

            <:col :let={member} label="Status">
              <span class={"inline-flex px-2 py-1 text-xs font-semibold rounded-full #{status_badge_class(member)}"}>
                {member_status(member)}
              </span>
            </:col>

            <:col :let={member} label="Registration Date">
              {if member.registration_date,
                do: Calendar.strftime(member.registration_date, "%b %d, %Y"),
                else: "-"}
            </:col>

            <:col :let={member} label="Expiry Date">
              {if member.expiry_date,
                do: Calendar.strftime(member.expiry_date, "%b %d, %Y"),
                else: "-"}
            </:col>

            <:action :let={member}>
              <div class="flex items-center gap-2">
                <.link
                  navigate={~p"/manage/members/management/#{member.id}"}
                  class="text-voile-primary hover:text-voile-primary/80"
                >
                  <.icon name="hero-eye" class="w-4 h-4" />
                </.link>

                <%= if can?(@current_scope.user, "users.update") do %>
                  <.link
                    patch={~p"/manage/members/management/#{member.id}/edit"}
                    class="text-blue-600 hover:text-blue-800"
                  >
                    <.icon name="hero-pencil" class="w-4 h-4" />
                  </.link>
                <% end %>

                <%= if can?(@current_scope.user, "users.update") do %>
                  <.link
                    patch={~p"/manage/members/management/#{member.id}/extend"}
                    class="text-green-600 hover:text-green-800"
                  >
                    <.icon name="hero-arrow-path" class="w-4 h-4" />
                  </.link>
                <% end %>

                <%= if can?(@current_scope.user, "users.update") do %>
                  <.link
                    patch={~p"/manage/members/management/#{member.id}/change_password"}
                    class="text-orange-600 hover:text-orange-800"
                  >
                    <.icon name="hero-key" class="w-4 h-4" />
                  </.link>
                <% end %>

                <%= if can?(@current_scope.user, "users.delete") do %>
                  <.link
                    href="#"
                    phx-click="delete_member"
                    phx-value-id={member.id}
                    data-confirm="Are you sure you want to delete this member?"
                    class="text-red-600 hover:text-red-800"
                  >
                    <.icon name="hero-trash" class="w-4 h-4" />
                  </.link>
                <% end %>
              </div>
            </:action>
          </.table>
        </div>

        <%!-- Pagination --%>
        <%= if @members.total_pages > 1 do %>
          <div class="flex items-center justify-between mt-6">
            <div class="text-sm text-gray-700 dark:text-gray-300">
              Page {@members.page_number} of {@members.total_pages}
            </div>

            <div class="flex items-center gap-2">
              <%= if @members.page_number > 1 do %>
                <.link
                  patch={
                    ~p"/manage/members/management?#{%{page: @members.page_number - 1, query: @search_query, node_id: @selected_node_id, member_type_id: @selected_member_type_id, status: @selected_status}}"
                  }
                  class="px-3 py-2 text-sm font-medium text-gray-500 bg-white border border-gray-300 rounded-md hover:bg-gray-50"
                >
                  Previous
                </.link>
              <% end %>

              <%= if @members.page_number < @members.total_pages do %>
                <.link
                  patch={
                    ~p"/manage/members/management?#{%{page: @members.page_number + 1, query: @search_query, node_id: @selected_node_id, member_type_id: @selected_member_type_id, status: @selected_status}}"
                  }
                  class="px-3 py-2 text-sm font-medium text-gray-500 bg-white border border-gray-300 rounded-md hover:bg-gray-50"
                >
                  Next
                </.link>
              <% end %>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  # Private functions

  defp load_members(socket) do
    query = build_members_query(socket)
    page = socket.assigns.current_page
    per_page = socket.assigns.per_page
    offset = (page - 1) * per_page

    # Get paginated results
    members_query = query |> limit(^per_page) |> offset(^offset)
    members = Repo.all(members_query)

    # Get total count
    count_query = from(u in subquery(query), select: count(u.id))
    total_count = Repo.one(count_query)
    total_pages = div(total_count + per_page - 1, per_page)

    # Create a struct-like map for pagination info
    pagination_info = %{
      entries: members,
      page_number: page,
      page_size: per_page,
      total_entries: total_count,
      total_pages: total_pages,
      offset: offset
    }

    assign(socket, :members, pagination_info)
  end

  defp build_members_query(socket) do
    base_query =
      from(u in User,
        left_join: mt in MemberType,
        on: u.user_type_id == mt.id,
        left_join: n in Node,
        on: u.node_id == n.id,
        select: %{
          u
          | user_type: mt,
            node: n
        }
      )

    query = base_query

    # Apply search filter
    query =
      if socket.assigns.search_query != "" do
        search_term = "%#{socket.assigns.search_query}%"

        from(u in query,
          where:
            ilike(u.fullname, ^search_term) or
              ilike(u.email, ^search_term) or
              ilike(u.username, ^search_term)
        )
      else
        query
      end

    # Apply node filter
    query =
      if socket.assigns.selected_node_id && socket.assigns.selected_node_id != "" do
        from(u in query, where: u.node_id == ^String.to_integer(socket.assigns.selected_node_id))
      else
        query
      end

    # Apply member type filter
    query =
      if socket.assigns.selected_member_type_id && socket.assigns.selected_member_type_id != "" do
        from(u in query, where: u.user_type_id == ^socket.assigns.selected_member_type_id)
      else
        query
      end

    # Apply status filter
    query =
      case socket.assigns.selected_status do
        "active" ->
          from(u in query, where: u.manually_suspended == false or is_nil(u.manually_suspended))

        "suspended" ->
          from(u in query, where: u.manually_suspended == true)

        "expired" ->
          today = Date.utc_today()
          from(u in query, where: not is_nil(u.expiry_date) and u.expiry_date < ^today)

        _ ->
          query
      end

    # Order by creation date (newest first)
    from(u in query, order_by: [desc: u.inserted_at])
  end

  defp load_filters(socket) do
    member_types = Repo.all(from(mt in MemberType, order_by: mt.name))

    nodes =
      if socket.assigns.is_super_admin, do: Repo.all(from(n in Node, order_by: n.name)), else: []

    socket
    |> assign(:member_types, member_types)
    |> assign(:nodes, nodes)
  end

  defp member_status(member) do
    cond do
      member.manually_suspended -> "Suspended"
      member.expiry_date && Date.before?(member.expiry_date, Date.utc_today()) -> "Expired"
      true -> "Active"
    end
  end

  defp status_badge_class(member) do
    case member_status(member) do
      "Active" -> "bg-green-100 text-green-800"
      "Suspended" -> "bg-red-100 text-red-800"
      "Expired" -> "bg-orange-100 text-orange-800"
      _ -> "bg-gray-100 text-gray-800"
    end
  end
end
