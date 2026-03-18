defmodule VoileWeb.DashboardLive do
  use VoileWeb, :live_view_dashboard
  require Logger

  alias Voile.Analytics.SearchAnalytics
  alias Voile.Schema.Search
  alias Voile.Repo
  alias Voile.Schema.Accounts.User
  alias Voile.Schema.Catalog.{Collection, Item}
  alias VoileWeb.Auth.Authorization

  import Ecto.Query

  def render(assigns) do
    ~H"""
    <section class="space-y-6 p-6">
      <div class="flex flex-col md:flex-wrap items-center justify-between gap-4">
        <div class="w-full">
          <h1 class="text-3xl font-bold text-gray-900 dark:text-white">
            {gettext("Dashboard")}
          </h1>
          <p class="text-gray-600 dark:text-gray-400 mt-1">
            {gettext("Overview of your GLAM system")}
          </p>
        </div>
        <%= if @is_super_admin do %>
          <div class="w-full flex justify-end">
            <.form :let={f} for={%{}} phx-change="select_node">
              <.input
                field={f[:node_id]}
                type="select"
                options={
                  [{gettext("All Nodes"), "all"}] ++
                    Enum.map(@nodes || [], fn n -> {n.name, to_string(n.id)} end)
                }
                value={if @selected_node_id, do: to_string(@selected_node_id), else: "all"}
                class="text-sm border-gray-300 dark:border-gray-600 rounded-md shadow-sm"
                label={gettext("Filter by Node")}
              />
            </.form>
          </div>
        <% end %>
      </div>
      <%!-- Quick Actions --%>
      <div class="w-full">
        <h5 class="text-center my-3">{gettext("Library Transaction Circulation")}</h5>
        <.link
          class="w-full inline-flex items-center justify-center px-6 py-4 bg-gradient-to-r from-violet-600 to-violet-700 text-white text-lg font-semibold rounded-xl shadow-lg hover:shadow-xl hover:from-violet-700 hover:to-violet-800"
          navigate={~p"/manage/glam/library/ledger"}
        >
          {gettext("Start Transaction")}
        </.link>
      </div>
      <%!-- Quick Stats Cards --%>
      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        <.stat_card
          title={gettext("Total Members")}
          value={@member_stats.total_members}
          icon="hero-users"
          color="blue"
        />
        <.stat_card
          title={gettext("Active Loans")}
          value={@circulation_stats.active_transactions}
          icon="hero-book-open"
          color="green"
        />
        <.stat_card
          title={gettext("Overdue Items")}
          value={@circulation_stats.overdue_count}
          icon="hero-exclamation-triangle"
          color="red"
        />
        <.stat_card
          title={gettext("Collections")}
          value={@catalog_stats.total_collections}
          icon="hero-rectangle-stack"
          color="purple"
        />
      </div>
      <%!-- Member Statistics --%>
      <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <div class="bg-white dark:bg-gray-700 rounded-xl shadow p-6">
          <h3 class="text-lg font-semibold text-gray-900 dark:text-white mb-4">
            <.icon name="hero-users" class="w-5 h-5 inline mr-2" /> {gettext("Member Overview")}
          </h3>
          <div class="space-y-4">
            <.stat_row
              label={gettext("Active Members")}
              value={@member_stats.active_members}
              color="green"
            />
            <.stat_row
              label={gettext("Suspended Members")}
              value={@member_stats.suspended_members}
              color="red"
            />
            <.stat_row
              label={gettext("Expiring Soon (30 days)")}
              value={@member_stats.expiring_soon}
              color="orange"
            />
            <.stat_row
              label={gettext("Expired Memberships")}
              value={@member_stats.expired_members}
              color="gray"
            />
          </div>
          <%= if @is_super_admin do %>
            <div class="mt-6 text-center">
              <.link navigate={~p"/manage/settings/user_dashboard"}>
                <.button>{gettext("View Detailed Member Statistics &rarr;")}</.button>
              </.link>
            </div>
          <% end %>
        </div>
        <%!-- Circulation Statistics --%>
        <div class="bg-white dark:bg-gray-700 rounded-xl shadow p-6">
          <h3 class="text-lg font-semibold text-gray-900 dark:text-white mb-4">
            <.icon name="hero-arrow-path" class="w-5 h-5 inline mr-2" /> {gettext(
              "Circulation Overview"
            )}
          </h3>
          <div class="space-y-4">
            <.stat_row
              label={gettext("Active Transactions")}
              value={@circulation_stats.active_transactions}
              color="blue"
            />
            <.stat_row
              label={gettext("Overdue Transactions")}
              value={@circulation_stats.overdue_count}
              color="red"
            />
            <.stat_row
              label={gettext("Active Reservations")}
              value={@circulation_stats.active_reservations}
              color="purple"
            />
            <.stat_row
              label={gettext("Outstanding Fines")}
              value={"Rp #{format_currency(@circulation_stats.outstanding_fines)}"}
              color="orange"
            />
          </div>
        </div>
      </div>
      <%!-- Catalog & Search Statistics --%>
      <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <div class="bg-white dark:bg-gray-700 rounded-xl shadow p-6">
          <h3 class="text-lg font-semibold text-gray-900 dark:text-white mb-4">
            <.icon name="hero-rectangle-stack" class="w-5 h-5 inline mr-2" /> {gettext(
              "Catalog Overview"
            )}
          </h3>
          <div class="space-y-4">
            <.stat_row
              label={gettext("Total Collections")}
              value={@catalog_stats.total_collections}
              color="blue"
            />
            <.stat_row
              label={gettext("Published Collections")}
              value={@catalog_stats.published_collections}
              color="green"
            />
            <.stat_row
              label={gettext("Total Items")}
              value={@catalog_stats.total_items}
              color="purple"
            />
            <.stat_row
              label={gettext("Available Items")}
              value={@catalog_stats.available_items}
              color="green"
            />
          </div>
        </div>
        <%!-- Search Widget --%>
        <.dashboard_search_widget
          search_query={@search_query}
          search_results={@search_results}
          searching={@searching}
        />
      </div>
      <%!-- Search Statistics Widget --%>
      <div class="bg-white dark:bg-gray-700 rounded-xl shadow p-6">
        <.search_stats_widget stats={@search_stats} />
      </div>

      <%!-- Plugin Dashboard Widgets --%>
      <%= for widget <- @plugin_widgets do %>
        <div class="bg-white dark:bg-gray-700 rounded-xl shadow p-6">
          <h3 class="text-lg font-semibold text-gray-900 dark:text-white mb-4">
            {widget.title}
          </h3>
          <.live_component module={widget.component} id={to_string(widget.key)} />
        </div>
      <% end %>
    </section>
    """
  end

  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    is_super_admin = Authorization.is_super_admin?(user)

    socket =
      socket
      |> assign(:page_title, gettext("Dashboard"))
      |> assign(:user, user)
      |> assign(:is_super_admin, is_super_admin)
      |> assign(:search_stats, SearchAnalytics.get_search_stats())
      |> assign(:search_query, "")
      |> assign(:search_results, [])
      |> assign(:searching, false)

    socket =
      if is_super_admin do
        nodes = Voile.Schema.System.list_nodes()
        socket |> assign(:nodes, nodes) |> assign(:selected_node_id, nil)
      else
        socket |> assign(:nodes, []) |> assign(:selected_node_id, user.node_id)
      end

    # Load statistics
    socket =
      socket
      |> load_member_stats(user)
      |> load_circulation_stats(user)
      |> load_catalog_stats(user)

    # Let plugins inject their own widgets
    plugin_widgets = Voile.Hooks.run_filter(:dashboard_widgets, [])
    socket = assign(socket, :plugin_widgets, plugin_widgets)

    {:ok, socket}
  end

  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  def handle_event("select_node", %{"node_id" => node_id_str}, socket) do
    node_id =
      case node_id_str do
        nil -> nil
        "all" -> nil
        "" -> nil
        id -> String.to_integer(id)
      end

    socket = assign(socket, :selected_node_id, node_id)

    # Determine user context for stats
    user = socket.assigns.user

    user_for_stats =
      if Authorization.is_super_admin?(user) and not is_nil(node_id) do
        Map.put(user, :node_id, node_id)
      else
        user
      end

    socket =
      socket
      |> load_member_stats(user_for_stats)
      |> load_circulation_stats(user_for_stats)
      |> load_catalog_stats(user_for_stats)

    {:noreply, socket}
  end

  def handle_event("search", %{"query" => query}, socket) do
    query = String.trim(query)
    Logger.debug("Dashboard search event: query=#{inspect(query)}")

    if query == "" do
      socket =
        socket
        |> assign(:search_query, "")
        |> assign(:search_results, [])
        |> assign(:searching, false)

      {:noreply, socket}
    else
      send(self(), {:perform_search, query})

      socket =
        socket
        |> assign(:search_query, query)
        |> assign(:searching, true)

      {:noreply, socket}
    end
  end

  def handle_info({:perform_search, query}, socket) do
    Logger.debug("Performing search for: #{inspect(query)}")

    # Perform universal search with limited results for dashboard widget
    results = Search.universal_search(query, %{collections_per_page: 3, items_per_page: 2})

    Logger.debug("Search results: #{inspect(results)}")

    # Combine and flatten results for display
    combined_results =
      (results.collections.results ++ results.items.results)
      |> Enum.take(5)

    Logger.debug("Combined results count: #{length(combined_results)}")

    socket =
      socket
      |> assign(:search_results, combined_results)
      |> assign(:searching, false)

    {:noreply, socket}
  end

  # Private helper functions for loading statistics

  defp load_member_stats(socket, user) do
    base_query = from(u in User)

    scoped_query =
      if is_nil(user.node_id) do
        base_query
      else
        from(u in base_query, where: u.node_id == ^user.node_id)
      end

    total_members = Repo.aggregate(scoped_query, :count, :id)

    active_members =
      Repo.aggregate(
        from(u in scoped_query,
          where: u.manually_suspended == false or is_nil(u.manually_suspended)
        ),
        :count,
        :id
      )

    suspended_members =
      Repo.aggregate(
        from(u in scoped_query, where: u.manually_suspended == true),
        :count,
        :id
      )

    # Members expiring in next 30 days
    thirty_days_from_now = Date.add(Date.utc_today(), 30)

    expiring_soon =
      Repo.aggregate(
        from(u in scoped_query,
          where:
            not is_nil(u.expiry_date) and u.expiry_date <= ^thirty_days_from_now and
              u.expiry_date >= ^Date.utc_today()
        ),
        :count,
        :id
      )

    expired_members =
      Repo.aggregate(
        from(u in scoped_query,
          where: not is_nil(u.expiry_date) and u.expiry_date < ^Date.utc_today()
        ),
        :count,
        :id
      )

    member_stats = %{
      total_members: total_members,
      active_members: active_members,
      suspended_members: suspended_members,
      expiring_soon: expiring_soon,
      expired_members: expired_members
    }

    assign(socket, :member_stats, member_stats)
  end

  defp load_circulation_stats(socket, user) do
    # Use the shared circulation stats function from the context
    # This handles all the node filtering and null unit_id logic
    circulation_stats = Voile.get_circulation_stats(user.node_id)

    assign(socket, :circulation_stats, circulation_stats)
  end

  defp load_catalog_stats(socket, user) do
    # Total collections
    total_collections =
      if is_nil(user.node_id) do
        Repo.aggregate(Collection, :count, :id)
      else
        Collection
        |> where([c], c.unit_id == ^user.node_id)
        |> Repo.aggregate(:count, :id)
      end

    # Published collections
    published_collections =
      if is_nil(user.node_id) do
        Collection
        |> where([c], c.status == "published")
        |> Repo.aggregate(:count, :id)
      else
        Collection
        |> where([c], c.status == "published" and c.unit_id == ^user.node_id)
        |> Repo.aggregate(:count, :id)
      end

    # Total items
    total_items =
      if is_nil(user.node_id) do
        Repo.aggregate(Item, :count, :id)
      else
        Item
        |> where([i], i.unit_id == ^user.node_id)
        |> Repo.aggregate(:count, :id)
      end

    # Available items
    available_items =
      if is_nil(user.node_id) do
        Item
        |> where([i], i.availability == "available")
        |> Repo.aggregate(:count, :id)
      else
        Item
        |> where([i], i.availability == "available" and i.unit_id == ^user.node_id)
        |> Repo.aggregate(:count, :id)
      end

    catalog_stats = %{
      total_collections: total_collections,
      published_collections: published_collections,
      total_items: total_items,
      available_items: available_items
    }

    assign(socket, :catalog_stats, catalog_stats)
  end

  defp format_currency(amount) when is_integer(amount) do
    amount
    |> Integer.to_string()
    |> String.graphemes()
    |> Enum.reverse()
    |> Enum.chunk_every(3)
    |> Enum.join(".")
    |> String.reverse()
  end

  defp format_currency(_amount), do: "0"

  # Stat row component for overview cards
  defp stat_row(assigns) do
    ~H"""
    <div class="flex items-center justify-between py-2 border-b border-gray-200 dark:border-gray-600 last:border-0">
      <span class="text-sm font-medium text-gray-700 dark:text-gray-300">{@label}</span>
      <span class={"text-sm font-semibold #{get_text_color_class(@color)}"}>{@value}</span>
    </div>
    """
  end

  defp get_text_color_class("blue"), do: "text-blue-600 dark:text-blue-400"
  defp get_text_color_class("green"), do: "text-green-600 dark:text-green-400"
  defp get_text_color_class("red"), do: "text-red-600 dark:text-red-400"
  defp get_text_color_class("purple"), do: "text-purple-600 dark:text-purple-400"
  defp get_text_color_class("orange"), do: "text-orange-600 dark:text-orange-400"
  defp get_text_color_class("gray"), do: "text-gray-600 dark:text-gray-400"
  defp get_text_color_class(_), do: "text-gray-600 dark:text-gray-400"
end
