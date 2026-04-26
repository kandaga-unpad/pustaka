defmodule VoileWeb.Dashboard.Members.Clearance.Index do
  use VoileWeb, :live_view_dashboard
  use Gettext, backend: VoileWeb.Gettext

  alias Voile.Clearance
  alias Voile.Schema.Accounts
  alias Voile.Schema.System
  alias VoileWeb.Auth.Authorization
  alias VoileWeb.Utils.FormatIndonesiaTime

  @per_page 20

  @impl true
  def mount(_params, _session, socket) do
    handle_mount_errors do
      authorize!(socket, "system.settings")

      user = socket.assigns.current_scope.user
      is_super_admin = Authorization.is_super_admin?(socket)

      nodes =
        if is_super_admin do
          System.list_nodes()
        else
          []
        end

      socket =
        socket
        |> assign(:page_title, gettext("Clearance Letters"))
        |> assign(:is_super_admin, is_super_admin)
        |> assign(:current_user, user)
        |> assign(:nodes, nodes)
        |> assign(:search, "")
        |> assign(:selected_node_id, if(is_super_admin, do: nil, else: user.node_id))
        |> assign(:page, 1)
        |> assign(:total_pages, 1)
        |> assign(:total_count, 0)
        |> assign(:create_user_search, "")
        |> assign(:create_user, nil)
        |> assign(:create_identifier, "")
        |> assign(:create_user_error, nil)
        |> assign(:create_error, nil)
        |> assign(:creating_letter, false)
        |> stream(:letters, [])

      {:ok, socket}
    end
  end

  @impl true
  def handle_params(params, _uri, socket) do
    page = max(String.to_integer(params["page"] || "1"), 1)
    search = params["search"] || ""

    selected_node_id =
      if socket.assigns.is_super_admin do
        case params["node_id"] do
          nil -> nil
          "" -> nil
          id -> String.to_integer(id)
        end
      else
        socket.assigns.current_user.node_id
      end

    opts =
      [search: search]
      |> then(fn o ->
        if selected_node_id, do: Keyword.put(o, :node_id, selected_node_id), else: o
      end)

    {letters, total, total_pages} =
      Clearance.list_letters_paginated(page, @per_page, opts)

    socket =
      socket
      |> assign(:page, page)
      |> assign(:search, search)
      |> assign(:selected_node_id, selected_node_id)
      |> assign(:total_pages, total_pages)
      |> assign(:total_count, total)
      |> stream(:letters, letters, reset: true)

    {:noreply, socket}
  end

  @impl true
  def handle_event("search", %{"search" => query}, socket) do
    {:noreply,
     push_patch(socket,
       to: build_path(socket, search: query, page: 1)
     )}
  end

  @impl true
  def handle_event("filter_node", %{"node_id" => node_id}, socket) do
    {:noreply,
     push_patch(socket,
       to: build_path(socket, node_id: node_id, page: 1)
     )}
  end

  @impl true
  def handle_event("find_member", %{"search" => search}, socket) do
    search = String.trim(search || "")

    if search == "" do
      {:noreply,
       assign(socket,
         create_user: nil,
         create_user_error: gettext("Please enter an email or identifier."),
         create_error: nil
       )}
    else
      case Accounts.get_user_by_login(search) do
        nil ->
          {:noreply,
           assign(socket,
             create_user: nil,
             create_user_error: gettext("Member not found."),
             create_error: nil
           )}

        user ->
          {:noreply,
           assign(socket,
             create_user_search: search,
             create_user: user,
             create_identifier: format_user_identifier(user.identifier),
             create_user_error: nil,
             create_error: nil
           )}
      end
    end
  end

  @impl true
  def handle_event("update_create_identifier", %{"identifier" => value}, socket) do
    {:noreply, assign(socket, create_identifier: value)}
  end

  @impl true
  def handle_event("create_letter", params, socket) do
    identifier =
      params["identifier"]
      |> to_string()
      |> String.trim()
      |> case do
        "" -> String.trim(socket.assigns.create_identifier || "")
        value -> value
      end

    case {socket.assigns.create_user, identifier} do
      {nil, _} ->
        {:noreply,
         assign(socket,
           create_error: gettext("Select a member before creating a letter."),
           creating_letter: false
         )}

      {_, ""} ->
        {:noreply,
         assign(socket,
           create_error: gettext("Identifier is required."),
           creating_letter: false
         )}

      {user, identifier} ->
        socket = assign(socket, creating_letter: true, create_error: nil)

        case Clearance.generate_letter_for_member(user, identifier) do
          {:ok, letter} ->
            {:noreply, push_navigate(socket, to: ~p"/manage/members/clearance/#{letter.id}")}

          {:error, :already_exists, _letter} ->
            {:noreply,
             assign(socket,
               create_error: gettext("A clearance letter already exists for this identifier."),
               creating_letter: false
             )}

          {:error, changeset} ->
            error =
              changeset.errors
              |> Enum.map(fn {field, {msg, _}} -> "#{field}: #{msg}" end)
              |> Enum.join(", ")

            {:noreply,
             assign(socket,
               create_error: gettext("Failed to create letter: %{reason}", reason: error),
               creating_letter: false
             )}
        end
    end
  end

  defp format_user_identifier(nil), do: ""
  defp format_user_identifier(identifier) when is_binary(identifier), do: identifier

  defp format_user_identifier(identifier) when is_integer(identifier),
    do: Integer.to_string(identifier)

  defp format_user_identifier(%Decimal{} = identifier), do: Decimal.to_string(identifier)

  defp build_path(socket, overrides) do
    page = Keyword.get(overrides, :page, socket.assigns.page)
    search = Keyword.get(overrides, :search, socket.assigns.search)

    node_id_param =
      if socket.assigns.is_super_admin do
        raw = Keyword.get(overrides, :node_id, to_string_or_nil(socket.assigns.selected_node_id))
        if raw && raw != "", do: raw, else: nil
      else
        nil
      end

    params =
      %{}
      |> then(fn m -> if page > 1, do: Map.put(m, :page, page), else: m end)
      |> then(fn m -> if search != "", do: Map.put(m, :search, search), else: m end)
      |> then(fn m ->
        if node_id_param, do: Map.put(m, :node_id, node_id_param), else: m
      end)

    ~p"/manage/members/clearance?#{params}"
  end

  defp to_string_or_nil(nil), do: nil
  defp to_string_or_nil(v), do: to_string(v)

  defp clearance_nav(assigns) do
    ~H"""
    <div class="bg-white dark:bg-gray-700 shadow-sm rounded-lg">
      <nav
        class="flex gap-1 px-4 border-b border-gray-200 dark:border-gray-600"
        aria-label={gettext("Clearance navigation")}
      >
        <.link
          navigate={~p"/manage/members/clearance"}
          class={[
            "px-4 py-3 text-sm font-medium border-b-2 -mb-px transition-colors",
            if @active == :letters do
              "border-voile-primary text-voile-primary"
            else
              "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300 dark:text-gray-400 dark:hover:text-gray-200"
            end
          ]}
        >
          <.icon name="hero-document-text" class="w-4 h-4 inline-block mr-1" />
          {gettext("Letters")}
        </.link>
        <.link
          navigate={~p"/manage/members/clearance/verify"}
          class={[
            "px-4 py-3 text-sm font-medium border-b-2 -mb-px transition-colors",
            if @active == :verify do
              "border-voile-primary text-voile-primary"
            else
              "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300 dark:text-gray-400 dark:hover:text-gray-200"
            end
          ]}
        >
          <.icon name="hero-shield-check" class="w-4 h-4 inline-block mr-1" />
          {gettext("Verify")}
        </.link>
        <.link
          navigate={~p"/manage/members/clearance/settings"}
          class={[
            "px-4 py-3 text-sm font-medium border-b-2 -mb-px transition-colors",
            if @active == :settings do
              "border-voile-primary text-voile-primary"
            else
              "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300 dark:text-gray-400 dark:hover:text-gray-200"
            end
          ]}
        >
          <.icon name="hero-cog-6-tooth" class="w-4 h-4 inline-block mr-1" />
          {gettext("Settings")}
        </.link>
      </nav>
    </div>
    """
  end

  defp status_badge(assigns) do
    ~H"""
    <%= if @letter.is_revoked do %>
      <span class="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-red-100 text-red-800 dark:bg-red-900/30 dark:text-red-400">
        {gettext("Revoked")}
      </span>
    <% else %>
      <span class="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-green-100 text-green-800 dark:bg-green-900/30 dark:text-green-400">
        {gettext("Active")}
      </span>
    <% end %>
    """
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6 bg-gray-100 dark:bg-gray-800 min-h-screen p-6 rounded-lg">
      <%!-- Breadcrumb --%>
      <.breadcrumb items={[
        %{label: gettext("Manage"), path: ~p"/manage"},
        %{label: gettext("Members"), path: ~p"/manage/members"},
        %{label: gettext("Clearance Letters"), path: nil}
      ]} />

      <%!-- Clearance sub-navigation --%>
      <.clearance_nav active={:letters} />

      <%!-- Page Header --%>
      <div class="bg-white dark:bg-gray-700 shadow-sm rounded-lg p-6">
        <div class="flex items-center justify-between">
          <div>
            <h1 class="text-2xl font-bold text-gray-900 dark:text-white">
              {gettext("Clearance Letters")}
            </h1>
            <p class="text-gray-600 dark:text-gray-300 mt-1">
              {gettext("All clearance letters generated by the system")}
            </p>
          </div>

          <div class="text-sm text-gray-500 dark:text-gray-400">
            {gettext("Total: %{count}", count: @total_count)}
          </div>
        </div>
      </div>

      <%!-- Filters --%>
      <div class="bg-white dark:bg-gray-700 shadow-sm rounded-lg p-4">
        <div class="flex flex-col gap-3 sm:flex-row sm:items-end">
          <%!-- Search --%>
          <div class="flex-1">
            <form id="search-form" phx-submit="search" class="flex gap-2">
              <input
                type="text"
                name="search"
                value={@search}
                placeholder={gettext("Search by letter number or member name...")}
                class="flex-1 px-3 py-2 text-sm border border-gray-300 rounded-md shadow-sm dark:bg-gray-800 dark:border-gray-600 dark:text-white focus:outline-none focus:ring-2 focus:ring-voile-primary focus:border-transparent"
              />
              <button
                type="submit"
                class="inline-flex items-center gap-1 px-3 py-2 text-sm font-medium text-white bg-voile-primary rounded-md hover:bg-voile-primary/90 transition-colors"
              >
                <.icon name="hero-magnifying-glass" class="w-4 h-4" />
                {gettext("Search")}
              </button>
            </form>
          </div>

          <%!-- Node filter (super admin only) --%>
          <%= if @is_super_admin do %>
            <div>
              <form id="node-filter-form" phx-change="filter_node">
                <select
                  name="node_id"
                  class="px-3 py-2 text-sm border border-gray-300 rounded-md shadow-sm dark:bg-gray-800 dark:border-gray-600 dark:text-white focus:outline-none focus:ring-2 focus:ring-voile-primary"
                >
                  <option value="">{gettext("All Nodes")}</option>
                  <%= for node <- @nodes do %>
                    <option
                      value={node.id}
                      selected={to_string(@selected_node_id) == to_string(node.id)}
                    >
                      {node.name}
                    </option>
                  <% end %>
                </select>
              </form>
            </div>
          <% end %>
        </div>
      </div>

      <%= if @is_super_admin do %>
        <div class="bg-white dark:bg-gray-700 shadow-sm rounded-lg p-6">
          <div class="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
            <div>
              <h2 class="text-lg font-semibold text-gray-900 dark:text-white">
                {gettext("Create Clearance Letter for Next Degree")}
              </h2>
              <p class="text-sm text-gray-500 dark:text-gray-400 mt-1">
                {gettext(
                  "Select an existing member and provide a new identifier for their next degree clearance letter."
                )}
              </p>
            </div>
          </div>

          <form phx-submit="find_member" class="mt-5 grid gap-3 sm:grid-cols-[1.5fr_auto]">
            <input
              type="text"
              name="search"
              value={@create_user_search}
              placeholder={gettext("Search by email or existing identifier")}
              class="w-full px-3 py-2 text-sm border border-gray-300 rounded-md shadow-sm dark:bg-gray-800 dark:border-gray-600 dark:text-white focus:outline-none focus:ring-2 focus:ring-voile-primary focus:border-transparent"
            />
            <button
              type="submit"
              class="inline-flex items-center justify-center gap-2 rounded-xl bg-indigo-600 px-4 py-2 text-sm font-semibold text-white hover:bg-indigo-700"
            >
              <.icon name="hero-magnifying-glass" class="w-4 h-4" />
              {gettext("Find Member")}
            </button>
          </form>

          <%= if @create_user_error do %>
            <div class="mt-3 rounded-3xl border border-red-200 bg-red-50 p-4 text-sm text-red-700 dark:border-red-700/30 dark:bg-red-950/20 dark:text-red-200">
              {@create_user_error}
            </div>
          <% end %>

          <%= if @create_user do %>
            <div class="mt-5 rounded-3xl border border-slate-200 bg-slate-50 p-5 dark:border-slate-700 dark:bg-slate-900/80">
              <div class="grid gap-4 sm:grid-cols-2">
                <div>
                  <p class="text-sm font-semibold text-slate-700 dark:text-slate-200">
                    {gettext("Selected Member")}
                  </p>
                  <p class="mt-2 text-lg font-semibold text-slate-900 dark:text-white">
                    {@create_user.fullname}
                  </p>
                  <p class="text-sm text-slate-500 dark:text-slate-400">{@create_user.email}</p>
                  <p class="mt-2 text-sm text-slate-500 dark:text-slate-400">
                    {gettext("Current identifier: %{identifier}",
                      identifier: format_user_identifier(@create_user.identifier)
                    )}
                  </p>
                </div>

                <div>
                  <form phx-submit="create_letter" class="space-y-4">
                    <label class="block text-sm font-medium text-slate-700 dark:text-slate-300">
                      {gettext("Identifier for new clearance letter")}
                    </label>
                    <input
                      type="text"
                      name="identifier"
                      value={@create_identifier}
                      phx-change="update_create_identifier"
                      class="mt-2 w-full px-3 py-2 text-sm border border-gray-300 rounded-md shadow-sm dark:bg-gray-800 dark:border-gray-600 dark:text-white focus:outline-none focus:ring-2 focus:ring-voile-primary focus:border-transparent"
                    />
                    <div class="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
                      <button
                        type="submit"
                        disabled={@creating_letter}
                        class="inline-flex items-center gap-2 rounded-xl bg-indigo-600 px-4 py-2 text-sm font-semibold text-white hover:bg-indigo-700 disabled:opacity-60"
                      >
                        <.icon name="hero-document-plus" class="w-4 h-4" />
                        {gettext("Create Letter")}
                      </button>
                      <span class="text-xs text-slate-500 dark:text-slate-400">
                        {gettext("This will create a letter even if a previous degree letter exists.")}
                      </span>
                    </div>
                  </form>
                </div>
              </div>

              <%= if @create_error do %>
                <div class="mt-4 rounded-3xl border border-red-200 bg-red-50 p-4 text-sm text-red-700 dark:border-red-700/30 dark:bg-red-950/20 dark:text-red-200">
                  {@create_error}
                </div>
              <% end %>
            </div>
          <% end %>
        </div>
      <% end %>

      <%!-- Table --%>
      <div class="bg-white dark:bg-gray-700 shadow-sm rounded-lg overflow-hidden">
        <div class="overflow-x-auto">
          <table class="min-w-full divide-y divide-gray-200 dark:divide-gray-600">
            <thead class="bg-gray-50 dark:bg-gray-800">
              <tr>
                <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                  {gettext("Letter Number")}
                </th>
                <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                  {gettext("Member")}
                </th>
                <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider hidden md:table-cell">
                  {gettext("Node")}
                </th>
                <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider hidden lg:table-cell">
                  {gettext("Generated At")}
                </th>
                <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                  {gettext("Status")}
                </th>
                <th class="px-4 py-3 text-right text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                  {gettext("Actions")}
                </th>
              </tr>
            </thead>
            <tbody
              id="letters-table"
              phx-update="stream"
              class="bg-white dark:bg-gray-700 divide-y divide-gray-200 dark:divide-gray-600"
            >
              <tr
                :for={{id, letter} <- @streams.letters}
                id={id}
                class="hover:bg-gray-50 dark:hover:bg-gray-600 transition-colors"
              >
                <td class="px-4 py-3 text-sm font-medium text-gray-900 dark:text-white">
                  {letter.letter_number}
                </td>
                <td class="px-4 py-3 text-sm text-gray-700 dark:text-gray-300">
                  <div>{letter.member_snapshot["fullname"]}</div>
                  <div class="text-xs text-gray-500 dark:text-gray-400">
                    {letter.member_snapshot["identifier"]}
                  </div>
                </td>
                <td class="px-4 py-3 text-sm text-gray-500 dark:text-gray-400 hidden md:table-cell">
                  {letter.member_snapshot["node_name"] || gettext("—")}
                </td>
                <td class="px-4 py-3 text-sm text-gray-500 dark:text-gray-400 hidden lg:table-cell">
                  {FormatIndonesiaTime.format_utc_to_jakarta(letter.generated_at)}
                </td>
                <td class="px-4 py-3">
                  <.status_badge letter={letter} />
                </td>
                <td class="px-4 py-3 text-right">
                  <.link
                    navigate={~p"/manage/members/clearance/#{letter.id}"}
                    class="inline-flex items-center gap-1 px-2 py-1 text-xs font-medium text-voile-primary bg-voile-primary/10 hover:bg-voile-primary/20 dark:bg-gray-600 dark:hover:bg-gray-500 rounded-md transition-colors"
                  >
                    <.icon name="hero-eye" class="w-4 h-4" />
                    <span class="hidden sm:inline">{gettext("View")}</span>
                  </.link>
                </td>
              </tr>
            </tbody>
          </table>

          <%!-- Empty state --%>
          <%= if @total_count == 0 do %>
            <div class="text-center py-12 text-gray-500 dark:text-gray-400">
              <.icon name="hero-document-text" class="w-12 h-12 mx-auto mb-3 opacity-40" />
              <p class="text-sm">{gettext("No clearance letters found.")}</p>
            </div>
          <% end %>
        </div>

        <%!-- Pagination --%>
        <%= if @total_pages > 1 do %>
          <div class="flex items-center justify-between px-4 py-3 border-t border-gray-200 dark:border-gray-600">
            <div class="text-sm text-gray-700 dark:text-gray-300">
              {gettext("Page %{page} of %{total}", page: @page, total: @total_pages)}
            </div>

            <div class="flex items-center gap-2">
              <%= if @page > 1 do %>
                <.link
                  patch={build_path(assigns, page: @page - 1)}
                  class="inline-flex items-center gap-1 px-3 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-md hover:bg-gray-50 dark:bg-gray-700 dark:border-gray-600 dark:text-gray-300 dark:hover:bg-gray-600 transition-colors"
                >
                  <.icon name="hero-chevron-left" class="w-4 h-4" /> {gettext("Previous")}
                </.link>
              <% end %>

              <%= if @page < @total_pages do %>
                <.link
                  patch={build_path(assigns, page: @page + 1)}
                  class="inline-flex items-center gap-1 px-3 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-md hover:bg-gray-50 dark:bg-gray-700 dark:border-gray-600 dark:text-gray-300 dark:hover:bg-gray-600 transition-colors"
                >
                  {gettext("Next")} <.icon name="hero-chevron-right" class="w-4 h-4" />
                </.link>
              <% end %>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end
end
