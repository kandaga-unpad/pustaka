defmodule VoileWeb.Dashboard.Members.Management.Index do
  use VoileWeb, :live_view_dashboard

  alias Voile.Repo
  alias Voile.Schema.Accounts
  alias Voile.Schema.Accounts.User
  alias Voile.Schema.Master.MemberType
  alias Voile.Schema.System.Node
  alias VoileWeb.Auth.Authorization

  import Ecto.Query
  import VoileWeb.Dashboard.Members.Management.Component

  @per_page 20
  @member_export_headers ~w(
    fullname email username identifier member_type node registration_date expiry_date
    user_image groups address phone_number birth_date birth_place gender organization
    department position manually_suspended suspension_reason
  )

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
      |> allow_upload(:user_image,
        accept: ~w(.jpg .jpeg .png .webp),
        max_entries: 1,
        auto_upload: true,
        progress: &handle_progress/3
      )
      |> load_members()
      |> load_filters()

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    user = socket.assigns.current_scope.user
    is_super_admin = Authorization.is_super_admin?(user)

    socket =
      case socket.assigns.live_action do
        :edit ->
          member = Repo.get!(User, params["id"]) |> Repo.preload([:user_type, :node, :roles])

          selected_role_ids =
            member
            |> Map.get(:roles, [])
            |> Enum.map(& &1.id)

          socket
          |> assign(:member, member)
          |> assign(:selected_role_ids, selected_role_ids)
          |> assign(:form, to_form(User.changeset(member, %{})))
          |> assign(:is_super_admin, is_super_admin)
          |> assign(:tab, "upload")
          |> assign(:thumbnail_source, nil)
          |> assign(:thumbnail_url_input, "")
          |> assign(:asset_vault_files, Voile.Schema.Catalog.list_all_attachments("image"))
          |> assign(:shown_images_count, 12)
          |> load_filters()

        :new ->
          socket
          |> assign(:member, %User{})
          |> assign(:selected_role_ids, [])
          |> assign(:form, to_form(User.changeset(%User{}, %{})))
          |> assign(:is_super_admin, is_super_admin)
          |> assign(:tab, "upload")
          |> assign(:thumbnail_source, nil)
          |> assign(:thumbnail_url_input, "")
          |> assign(:asset_vault_files, Voile.Schema.Catalog.list_all_attachments("image"))
          |> assign(:shown_images_count, 12)
          |> load_filters()

        _ ->
          socket
          |> assign(:search_query, params["query"] || "")
          |> assign(:selected_node_id, params["node_id"])
          |> assign(:selected_member_type_id, params["member_type_id"])
          |> assign(:selected_status, params["status"] || "all")
          |> assign(:current_page, String.to_integer(params["page"] || "1"))
          |> load_members()
      end

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
  def handle_event("validate", %{"user" => user_params}, socket) do
    user_params = prepare_user_params(user_params)

    # Extract and store role_ids for form state
    role_ids =
      user_params
      |> Map.get("role_ids", [])
      |> Enum.reject(&(&1 == ""))
      |> Enum.map(fn
        id when is_integer(id) -> id
        id when is_binary(id) -> String.to_integer(id)
      end)

    changeset = User.changeset(socket.assigns.member, user_params)

    {:noreply,
     socket
     |> assign(:selected_role_ids, role_ids)
     |> assign(form: to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"user" => user_params}, socket) do
    save_member(socket, socket.assigns.live_action, user_params)
  end

  @impl true
  def handle_event("delete_member", %{"id" => id}, socket) do
    member = Repo.get!(User, id)

    case Repo.delete(member) do
      {:ok, _} ->
        socket =
          socket
          |> put_flash(:info, gettext("Member deleted successfully"))
          |> load_members()

        {:noreply, socket}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, gettext("Failed to delete member"))}
    end
  end

  @impl true
  def handle_event("export_members", _params, socket) do
    csv_content = build_members_export_csv(socket)

    filename =
      if socket.assigns.selected_node_id && socket.assigns.selected_node_id != "" do
        "members_export_node_#{socket.assigns.selected_node_id}.csv"
      else
        "members_export_all.csv"
      end

    {:noreply,
     push_event(socket, "download", %{
       filename: filename,
       content: csv_content,
       mime_type: "text/csv"
     })}
  end

  # Image upload event handlers
  def handle_event("switch_image_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :tab, tab)}
  end

  def handle_event("update_image_url", %{"image_url" => url}, socket) do
    {:noreply, assign(socket, :thumbnail_url_input, url)}
  end

  def handle_event("add_image_from_url", %{"url" => url}, socket) do
    # TODO: Implement URL image fetching
    # For now, just set the URL directly
    form_params = (socket.assigns.form.params || %{}) |> Map.put("user_image", url)

    socket =
      socket
      |> assign(:form, %{socket.assigns.form | params: form_params})
      |> assign(:thumbnail_source, "url")

    {:noreply, socket}
  end

  def handle_event("select_image_from_vault", %{"attachment_id" => attachment_id}, socket) do
    attachment = Voile.Schema.Catalog.get_attachment!(attachment_id)

    form_params =
      (socket.assigns.form.params || %{})
      |> Map.put("user_image", attachment.file_path)

    socket =
      socket
      |> assign(:form, %{socket.assigns.form | params: form_params})
      |> assign(:thumbnail_source, "vault")

    {:noreply, socket}
  end

  def handle_event("cancel_image_upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :user_image, ref)}
  end

  def handle_event("delete_image", %{"image" => _image_path}, socket) do
    form_params = (socket.assigns.form.params || %{}) |> Map.put("user_image", "")

    socket =
      socket
      |> assign(:form, %{socket.assigns.form | params: form_params})
      |> assign(:thumbnail_source, nil)

    {:noreply, socket}
  end

  def handle_event("load_more_images", _params, socket) do
    {:noreply, assign(socket, :shown_images_count, socket.assigns.shown_images_count + 12)}
  end

  def handle_progress(:user_image, entry, socket) do
    if entry.done? do
      # Handle completed upload
      uploaded_file = List.first(socket.assigns.uploads.user_image.entries)
      # This should be replaced with actual file path logic
      file_path = uploaded_file.client_name

      form_params = (socket.assigns.form.params || %{}) |> Map.put("user_image", file_path)

      socket =
        socket
        |> assign(:form, %{socket.assigns.form | params: form_params})
        |> assign(:thumbnail_source, "local")

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6 bg-gray-100 dark:bg-gray-800 min-h-screen p-6 rounded-lg">
      <%= if @live_action in [:new, :edit] do %>
        <.member_form
          form={@form}
          member={@member}
          action={@live_action}
          nodes={@nodes}
          member_types={@member_types}
          available_roles={@available_roles}
          selected_role_ids={@selected_role_ids}
          is_super_admin={@is_super_admin}
          tab={@tab}
          thumbnail_source={@thumbnail_source}
          thumbnail_url_input={@thumbnail_url_input}
          asset_vault_files={@asset_vault_files}
          shown_images_count={@shown_images_count}
          uploads={@uploads}
        />
      <% else %>
        <%!-- Breadcrumb --%>
        <.breadcrumb items={[
          %{label: gettext("Manage"), path: ~p"/manage"},
          %{label: gettext("Members"), path: ~p"/manage/members"},
          %{label: gettext("Management"), path: nil}
        ]} />

        <%!-- Page Header --%>
        <div class="bg-white dark:bg-gray-700 shadow-sm rounded-lg p-6">
          <div class="flex items-center justify-between">
            <div>
              <h1 class="text-2xl font-bold text-gray-900 dark:text-white">
                {gettext("Member Management")}
              </h1>
              <p class="text-gray-600 dark:text-gray-300 mt-1">
                {gettext("Manage and oversee all library members")}
              </p>
            </div>

            <%= if can?(@current_scope.user, "users.create") do %>
              <div class="flex flex-wrap items-center gap-3">
                <.link
                  patch={~p"/manage/members/management/import"}
                  class="inline-flex items-center gap-2 px-4 py-2 text-sm font-semibold text-gray-700 bg-white border border-gray-300 rounded-md hover:bg-gray-50 dark:bg-gray-700 dark:border-gray-600 dark:text-gray-200 dark:hover:bg-gray-600 transition-colors"
                >
                  <.icon name="hero-arrow-up-tray" class="w-5 h-5" />
                  {gettext("Import CSV")}
                </.link>

                <.button
                  phx-click="export_members"
                  class="inline-flex items-center gap-2 px-4 py-2 text-sm font-semibold text-gray-700 bg-white border border-gray-300 rounded-md hover:bg-gray-50 dark:bg-gray-700 dark:border-gray-600 dark:text-gray-200 dark:hover:bg-gray-600 transition-colors"
                  type="button"
                >
                  <.icon name="hero-arrow-down-tray" class="w-5 h-5" />
                  {gettext("Export CSV")}
                </.button>

                <.link patch={~p"/manage/members/management/new"}>
                  <.button class="bg-gradient-to-r from-voile-primary to-voile-primary/90 hover:from-voile-primary/90 hover:to-voile-primary text-white px-6 py-3 text-lg font-semibold shadow-lg hover:shadow-xl transition-all duration-200 hover:scale-105">
                    <.icon name="hero-plus" class="w-6 h-6 mr-3" /> {gettext("Add New Member")}
                  </.button>
                </.link>
              </div>
            <% end %>
          </div>
        </div>

        <%!-- Filters and Search --%>
        <div class="bg-white dark:bg-gray-700 shadow-sm rounded-lg p-6">
          <div class="flex flex-col items-center justify-center lg:flex-row gap-4 mb-6">
            <%!-- Search --%>
            <div class="flex-1">
              <.form for={%{}} phx-change="search" class="flex gap-2">
                <div class="relative flex-1">
                  <.input
                    name="query"
                    value={@search_query}
                    placeholder={gettext("Search by name, email, username, or identifier...")}
                    phx-debounce="300"
                  />
                </div>
              </.form>
            </div>

            <%!-- Filters --%>
            <div class="flex gap-2 mb-5">
              <%= if @is_super_admin do %>
                <.form for={%{}} phx-change="filter_node" class="w-48">
                  <.input
                    name="node_id"
                    type="select"
                    options={
                      [{gettext("All Nodes"), ""}] ++ Enum.map(@nodes, &{&1.name, to_string(&1.id)})
                    }
                    value={@selected_node_id}
                    label={gettext("Node")}
                  />
                </.form>
              <% end %>

              <.form for={%{}} phx-change="filter_member_type" class="w-48">
                <.input
                  name="member_type_id"
                  type="select"
                  options={[{gettext("All Types"), ""}] ++ Enum.map(@member_types, &{&1.name, &1.id})}
                  value={@selected_member_type_id}
                  label={gettext("Member Type")}
                />
              </.form>

              <.form for={%{}} phx-change="filter_status" class="w-48">
                <.input
                  name="status"
                  type="select"
                  options={[
                    {gettext("All Status"), "all"},
                    {gettext("Active"), "active"},
                    {gettext("Suspended"), "suspended"},
                    {gettext("Expired"), "expired"}
                  ]}
                  value={@selected_status}
                  label={gettext("Status")}
                />
              </.form>
            </div>
          </div>

          <%!-- Results Summary --%>
          <div class="text-sm text-gray-600 dark:text-gray-300 mb-4">
            {gettext("Showing %{from} to %{to} of %{total} members",
              from: @members.offset + 1,
              to: min(@members.offset + @per_page, @members.total_entries),
              total: @members.total_entries
            )}
          </div>

          <%!-- Members Table --%>
          <div class="overflow-x-auto">
            <.table
              id="members"
              rows={@members.entries}
              row_click={fn member -> JS.navigate(~p"/manage/members/management/#{member}") end}
            >
              <:col :let={member} label={gettext("Member")}>
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

              <:col :let={member} label={gettext("Member Type")}>
                {member.user_type && member.user_type.name}
              </:col>
              <:col :let={member} label={gettext("Identifier")}>
                <span class="text-sm text-gray-700 dark:text-gray-300">
                  {display_identifier(member)}
                </span>
              </:col>
              <:col :let={member} label={gettext("Status")}>
                <span class={"inline-flex px-2 py-1 text-xs font-semibold rounded-full #{status_badge_class(member)}"}>
                  {member_status(member)}
                </span>
              </:col>

              <:col :let={member} label={gettext("Registration Date")}>
                {if member.registration_date,
                  do: Calendar.strftime(member.registration_date, "%b %d, %Y"),
                  else: "-"}
              </:col>

              <:col :let={member} label={gettext("Expiry Date")}>
                {if member.expiry_date,
                  do: Calendar.strftime(member.expiry_date, "%b %d, %Y"),
                  else: "-"}
              </:col>

              <:action :let={member}>
                <.link
                  navigate={~p"/manage/members/management/#{member.id}"}
                  class="inline-flex items-center gap-1 px-2 py-1 text-xs font-medium text-voile-primary bg-voile-primary/10 hover:bg-voile-primary/20 dark:bg-gray-700 dark:hover:bg-gray-600 rounded-md transition-colors"
                >
                  <.icon name="hero-eye" class="w-4 h-4" />
                  <span class="hidden md:inline">{gettext("View")}</span>
                </.link>
              </:action>
            </.table>
          </div>

          <%!-- Pagination --%>
          <%= if @members.total_pages > 1 do %>
            <div class="flex items-center justify-between mt-6">
              <div class="text-sm text-gray-700 dark:text-gray-300">
                {gettext("Page %{page} of %{total}",
                  page: @members.page_number,
                  total: @members.total_pages
                )}
              </div>

              <div class="flex items-center gap-2">
                <%= if @members.page_number > 1 do %>
                  <.link
                    patch={
                      ~p"/manage/members/management?#{%{page: @members.page_number - 1, query: @search_query, node_id: @selected_node_id, member_type_id: @selected_member_type_id, status: @selected_status}}"
                    }
                    class="inline-flex items-center gap-1 px-3 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-md hover:bg-gray-50 hover:border-gray-400 dark:bg-gray-700 dark:border-gray-600 dark:text-gray-300 dark:hover:bg-gray-600 dark:hover:border-gray-500 transition-colors"
                  >
                    <.icon name="hero-chevron-left" class="w-4 h-4" /> {gettext("Previous")}
                  </.link>
                <% end %>

                <%= if @members.page_number < @members.total_pages do %>
                  <.link
                    patch={
                      ~p"/manage/members/management?#{%{page: @members.page_number + 1, query: @search_query, node_id: @selected_node_id, member_type_id: @selected_member_type_id, status: @selected_status}}"
                    }
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

  # Private functions

  defp save_member(socket, :edit, user_params) do
    user_params = prepare_user_params(user_params)

    # Extract role_ids from params
    role_ids = Map.get(user_params, "role_ids", [])

    case Accounts.admin_update_user(socket.assigns.member, user_params) do
      {:ok, user} ->
        # Update role assignments
        update_user_roles(user, role_ids, socket.assigns.current_scope.user.id)

        socket =
          socket
          |> put_flash(:info, gettext("Member updated successfully"))
          |> push_patch(to: ~p"/manage/members/management")

        {:noreply, socket}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_member(socket, :new, user_params) do
    user_params = prepare_user_params(user_params)

    # Extract role_ids from params
    role_ids = Map.get(user_params, "role_ids", [])

    user_params =
      if socket.assigns.is_super_admin do
        user_params
      else
        Map.put(user_params, "node_id", socket.assigns.current_scope.user.node_id)
      end

    case Accounts.register_user(user_params) do
      {:ok, user} ->
        # Assign roles to new user
        update_user_roles(user, role_ids, socket.assigns.current_scope.user.id)

        socket =
          socket
          |> put_flash(:info, gettext("Member created successfully"))
          |> push_patch(to: ~p"/manage/members/management")

        {:noreply, socket}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp load_members(socket) do
    query = build_members_query(socket)
    page = socket.assigns.current_page
    per_page = socket.assigns.per_page
    offset = (page - 1) * per_page

    # Get paginated results
    members_query = query |> limit(^per_page) |> offset(^offset)
    members = Repo.all(members_query)

    # Get total count
    count_query = build_count_query(socket)
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
              ilike(u.username, ^search_term) or
              ilike(fragment("CAST(? AS TEXT)", u.identifier), ^search_term)
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

    available_roles = VoileWeb.Auth.PermissionManager.list_roles()

    socket
    |> assign(:member_types, member_types)
    |> assign(:nodes, nodes)
    |> assign(:available_roles, available_roles)
  end

  defp build_members_export_csv(socket) do
    rows = Repo.all(build_members_query(socket))

    header_row = @member_export_headers
    data_rows = Enum.map(rows, &member_to_csv_row/1)

    ([header_row] ++ data_rows)
    |> NimbleCSV.RFC4180.dump_to_iodata()
    |> IO.iodata_to_binary()
  end

  defp member_to_csv_row(member) do
    [
      member.fullname || "",
      member.email || "",
      member.username || "",
      display_identifier(member),
      (member.user_type && member.user_type.name) || "",
      (member.node && member.node.name) || "",
      date_to_string(member.registration_date),
      date_to_string(member.expiry_date),
      member.user_image || "",
      Enum.join(member.groups || [], ","),
      member.address || "",
      member.phone_number || "",
      date_to_string(member.birth_date),
      member.birth_place || "",
      member.gender || "",
      member.organization || "",
      member.department || "",
      member.position || "",
      bool_to_string(member.manually_suspended),
      member.suspension_reason || ""
    ]
  end

  defp date_to_string(%Date{} = date), do: Date.to_iso8601(date)
  defp date_to_string(_), do: ""

  defp bool_to_string(true), do: "true"
  defp bool_to_string(false), do: "false"
  defp bool_to_string(_), do: ""

  defp member_status(member) do
    cond do
      member.manually_suspended ->
        gettext("Suspended")

      member.expiry_date && Date.before?(member.expiry_date, Date.utc_today()) ->
        gettext("Expired")

      true ->
        gettext("Active")
    end
  end

  defp display_identifier(member) do
    case member.identifier do
      %Decimal{} = decimal -> Decimal.to_string(decimal)
      identifier when is_integer(identifier) -> Integer.to_string(identifier)
      identifier when is_binary(identifier) -> identifier
      _ -> "-"
    end
  end

  defp build_count_query(socket) do
    base_query = from(u in User)

    query = base_query

    # Apply search filter
    query =
      if socket.assigns.search_query != "" do
        search_term = "%#{socket.assigns.search_query}%"

        from(u in query,
          where:
            ilike(u.fullname, ^search_term) or
              ilike(u.email, ^search_term) or
              ilike(u.username, ^search_term) or
              ilike(fragment("CAST(? AS TEXT)", u.identifier), ^search_term)
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

    from(u in query, select: count(u.id))
  end

  defp status_badge_class(member) do
    case member_status(member) do
      "Active" -> "bg-green-100 text-green-800"
      "Suspended" -> "bg-red-100 text-red-800"
      "Expired" -> "bg-orange-100 text-orange-800"
      _ -> "bg-gray-100 text-gray-800"
    end
  end

  defp prepare_user_params(params) do
    # Convert groups string to array
    groups =
      case params["groups"] do
        nil ->
          []

        "" ->
          []

        groups_string ->
          groups_string
          |> String.split(",")
          |> Enum.map(&String.trim/1)
          |> Enum.reject(&(&1 == ""))
      end

    Map.put(params, "groups", groups)
  end

  # Helper to update user roles
  defp update_user_roles(user, role_ids, assigned_by_id) do
    alias VoileWeb.Auth.Authorization

    # Get current role IDs
    current_role_ids =
      user
      |> Repo.preload(:roles)
      |> Map.get(:roles, [])
      |> Enum.map(& &1.id)
      |> MapSet.new()

    # Convert role_ids to integers and create set
    new_role_ids =
      role_ids
      |> Enum.reject(&(&1 == ""))
      |> Enum.map(fn
        id when is_integer(id) -> id
        id when is_binary(id) -> String.to_integer(id)
      end)
      |> MapSet.new()

    # Determine roles to add and remove
    roles_to_add = MapSet.difference(new_role_ids, current_role_ids)
    roles_to_remove = MapSet.difference(current_role_ids, new_role_ids)

    # Add new roles
    add_results =
      Enum.map(roles_to_add, fn role_id ->
        Authorization.assign_role(user.id, role_id, assigned_by_id: assigned_by_id)
      end)

    # Remove old roles
    remove_results =
      Enum.map(roles_to_remove, fn role_id ->
        Authorization.revoke_role(user.id, role_id)
      end)

    # Check for errors
    add_errors = Enum.filter(add_results, fn result -> match?({:error, _}, result) end)

    remove_errors =
      Enum.filter(remove_results, fn result ->
        case result do
          {:error, _} -> true
          _ -> false
        end
      end)

    if add_errors != [] or remove_errors != [] do
      require Logger

      Logger.error(
        "Failed to update user roles for user #{user.id}: add_errors=#{inspect(add_errors)}, remove_errors=#{inspect(remove_errors)}"
      )
    end

    :ok
  end
end
