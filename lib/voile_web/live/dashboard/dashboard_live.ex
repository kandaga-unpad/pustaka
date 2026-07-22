defmodule VoileWeb.DashboardLive do
  @moduledoc """
  The Voile staff dashboard home (`/manage`).

  Phase 2 of the dashboard redesign: this LiveView renders on the `:dashboard`
  layout and is composed entirely from `DashboardComponents` primitives —
  `voile_page_header`, `voile_glam_strip`, `voile_stat_card`, `voile_section_card`,
  `voile_metric_row`, `voile_activity_feed`, `voile_action_link`, and
  `voile_search_insights`.

  Data is loaded asynchronously after the initial paint so the first connected
  render shows shimmer skeletons instead of zeros that later jump to real
  numbers. The composition is role-aware insofar as super admins get an "all
  nodes" view with a node filter; deeper per-role widget variants
  (archivist / gallery_curator / museum_curator) are tracked as follow-up work
  in `plans/dashboard-redesign.md` §8.1.
  """

  use VoileWeb, :live_view_dashboard

  require Logger

  alias Voile.Analytics.SearchAnalytics
  alias Voile.Dashboard.{Feed, Stats}
  alias VoileWeb.Auth.Authorization

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    is_super_admin = Authorization.is_super_admin?(user)

    socket =
      socket
      |> assign(:page_title, gettext("Dashboard"))
      |> assign(:breadcrumb, [%{label: gettext("Dashboard"), path: nil}])
      |> assign(:user, user)
      |> assign(:is_super_admin, is_super_admin)
      |> assign(:greeting, build_greeting(user))
      |> assign(:dashboard_loading, true)
      |> assign(:glam_stats, empty_glam_stats())
      |> assign(:circulation_stats, empty_circulation_stats())
      |> assign(:catalog_stats, empty_catalog_stats())
      |> assign(:member_stats, empty_member_stats())
      |> assign(:attention_items, [])
      |> assign(:search_stats, SearchAnalytics.get_search_stats())
      |> assign_node_context(user, is_super_admin)

    # Plugin widgets are cheap (a filter over registered hooks) and render
    # their own live_components, so they can mount with the page.
    socket = assign(socket, :plugin_widgets, Voile.Hooks.run_filter(:dashboard_widgets, []))

    # Defer every database-backed stat query to after first paint so the UI
    # shows skeletons, then fills in.
    if connected?(socket) do
      send(self(), {:load_dashboard, socket.assigns.user})
    end

    {:ok, socket}
  end

  @impl true
  def handle_event("select_node", %{"node_id" => node_id_str}, socket) do
    node_id = parse_node_id(node_id_str)

    user =
      if Authorization.is_super_admin?(socket.assigns.user) and not is_nil(node_id) do
        Map.put(socket.assigns.user, :node_id, node_id)
      else
        socket.assigns.user
      end

    socket =
      socket
      |> assign(:selected_node_id, node_id)
      |> assign(:user, user)
      |> assign(:dashboard_loading, true)

    send(self(), {:load_dashboard, user})

    {:noreply, socket}
  end

  @impl true
  def handle_info({:load_dashboard, user}, socket) do
    {:noreply, load_dashboard(socket, user)}
  end

  defp load_dashboard(socket, user) do
    socket
    |> assign(:glam_stats, Stats.get_glam_statistics(user))
    |> assign(:circulation_stats, Voile.get_circulation_stats(user.node_id))
    |> assign(:catalog_stats, Stats.get_catalog_stats(user))
    |> assign(:member_stats, Stats.get_member_stats(user))
    |> assign(:attention_items, Feed.attention_items(user))
    |> assign(:dashboard_loading, false)
  end

  defp assign_node_context(socket, user, true) do
    nodes = Voile.Schema.System.list_nodes()

    socket
    |> assign(:nodes, nodes)
    |> assign(:selected_node_id, nil)
    |> assign(:current_node_id, user.node_id)
    |> assign(:current_node_name, gettext("All Nodes"))
  end

  defp assign_node_context(socket, user, false) do
    node_name =
      Voile.Schema.System.list_nodes()
      |> Enum.find(fn n -> n.id == user.node_id end)
      |> case do
        %{name: name} -> name
        _ -> gettext("Unknown")
      end

    socket
    |> assign(:nodes, [])
    |> assign(:selected_node_id, user.node_id)
    |> assign(:current_node_id, user.node_id)
    |> assign(:current_node_name, node_name)
  end

  defp parse_node_id("all"), do: nil
  defp parse_node_id(""), do: nil
  defp parse_node_id(nil), do: nil
  defp parse_node_id(id) when is_binary(id), do: String.to_integer(id)

  defp build_greeting(user) do
    hour = DateTime.utc_now().hour
    name = user_fullname_first(user)

    salutation =
      cond do
        hour < 12 -> gettext("Good morning")
        hour < 18 -> gettext("Good afternoon")
        true -> gettext("Good evening")
      end

    if name && name != "", do: "#{salutation}, #{name}", else: salutation
  end

  defp user_fullname_first(%{fullname: fullname}) when is_binary(fullname) and fullname != "" do
    fullname |> String.split() |> List.first()
  end

  defp user_fullname_first(_), do: nil

  # Empty shapes so the first (skeleton) paint never raises on nil access.
  defp empty_glam_stats do
    %{
      gallery_count: 0,
      library_count: 0,
      archive_count: 0,
      museum_count: 0,
      gallery_delta: 0,
      library_delta: 0,
      archive_delta: 0,
      museum_delta: 0,
      total_collections: 0,
      total_items: 0,
      total_nodes: 0,
      resource_classes: 0
    }
  end

  defp empty_circulation_stats,
    do: %{
      active_transactions: 0,
      overdue_count: 0,
      active_reservations: 0,
      outstanding_fines: 0
    }

  defp empty_catalog_stats,
    do: %{
      total_collections: 0,
      published_collections: 0,
      total_items: 0,
      available_items: 0
    }

  defp empty_member_stats,
    do: %{
      total_members: 0,
      active_members: 0,
      suspended_members: 0,
      expiring_soon: 0,
      expired_members: 0
    }

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

  @impl true
  def render(assigns) do
    ~H"""
    <.voile_page_header
      eyebrow={gettext("Library · Overview")}
      title={@greeting}
      description={gettext("Press ⌘K anywhere to jump to a page. Stats are scoped to your node.")}
      icon="hero-sparkles"
      tone={:brand}
    >
      <:actions>
        <%= if @is_super_admin do %>
          <form phx-change="select_node" class="voile-chip">
            <.icon name="hero-map-pin" class="w-4 h-4 text-tertiary" />
            <select
              name="node_id"
              class="bg-transparent text-sm text-primary outline-none cursor-pointer"
            >
              <option value="all">
                {gettext("All Nodes")}
              </option>
              <%= for node <- @nodes || [] do %>
                <option value={node.id} selected={@selected_node_id == node.id}>
                  {node.name}
                </option>
              <% end %>
            </select>
          </form>
        <% else %>
          <span class="voile-chip" title={gettext("Your node")}>
            <.icon name="hero-map-pin" class="w-4 h-4 text-tertiary" />
            <span class="text-sm text-primary">{@current_node_name}</span>
          </span>
        <% end %>
      </:actions>
    </.voile_page_header>

    <.voile_glam_strip stats={@glam_stats} />

    <div class="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-4 gap-3 md:gap-4 mb-6">
      <.voile_stat_card
        label={gettext("Active loans")}
        value={@circulation_stats.active_transactions}
        icon="hero-book-open"
        tone={:success}
        loading={@dashboard_loading}
      />
      <.voile_stat_card
        label={gettext("Overdue")}
        value={@circulation_stats.overdue_count}
        icon="hero-exclamation-triangle"
        tone={:error}
        loading={@dashboard_loading}
      />
      <.voile_stat_card
        label={gettext("Reservations")}
        value={@circulation_stats.active_reservations}
        icon="hero-bookmark"
        tone={:info}
        loading={@dashboard_loading}
      />
      <.voile_stat_card
        label={gettext("Outstanding fines")}
        value={"Rp #{format_currency(@circulation_stats.outstanding_fines)}"}
        icon="hero-banknotes"
        tone={:warning}
        loading={@dashboard_loading}
      />
    </div>

    <div class="grid grid-cols-1 lg:grid-cols-3 gap-4 mb-6">
      <.voile_section_card
        title={gettext("Attention required")}
        icon="hero-bell-alert"
        tone={:error}
        action_label={gettext("View all")}
        action_path="/manage/glam/library/circulation"
        class="lg:col-span-2"
      >
        <%= if @dashboard_loading do %>
          <.skeleton_feed />
        <% else %>
          <.voile_activity_feed
            items={@attention_items}
            empty_text={gettext("Nothing needs your attention right now.")}
          />
        <% end %>
      </.voile_section_card>

      <.voile_section_card title={gettext("Quick actions")} icon="hero-bolt" tone={:brand}>
        <div class="grid grid-cols-1 gap-2">
          <.voile_action_link
            icon="hero-banknotes"
            tone={:brand}
            label={gettext("Start transaction")}
            description={gettext("Checkout, return, or renew an item")}
            href="/manage/glam/library/ledger"
          />
          <.voile_action_link
            icon="hero-user-plus"
            tone={:info}
            label={gettext("Add member")}
            description={gettext("Register a new library member")}
            href="/manage/members/management/new"
          />
          <.voile_action_link
            icon="hero-document-plus"
            tone={:success}
            label={gettext("New collection")}
            description={gettext("Create a catalog collection")}
            href="/manage/catalog/collections/new"
          />
        </div>
      </.voile_section_card>
    </div>

    <div class="grid grid-cols-1 lg:grid-cols-2 gap-4 mb-6">
      <.voile_section_card
        title={gettext("Member overview")}
        icon="hero-user-group"
        tone={:glam_library}
        action_label={gettext("Details")}
        action_path="/manage/settings/user_dashboard"
      >
        <%= if @dashboard_loading do %>
          <.skeleton_metrics />
        <% else %>
          <.voile_metric_row
            label={gettext("Active members")}
            value={@member_stats.active_members}
            total={@member_stats.total_members}
            tone={:success}
          />
          <.voile_metric_row
            label={gettext("Suspended")}
            value={@member_stats.suspended_members}
            total={@member_stats.total_members}
            tone={:error}
          />
          <.voile_metric_row
            label={gettext("Expiring in 30 days")}
            value={@member_stats.expiring_soon}
            total={@member_stats.total_members}
            tone={:warning}
          />
          <.voile_metric_row
            label={gettext("Expired")}
            value={@member_stats.expired_members}
            total={@member_stats.total_members}
            tone={:brand}
          />
        <% end %>
      </.voile_section_card>

      <.voile_section_card
        title={gettext("Catalog snapshot")}
        icon="hero-rectangle-stack"
        tone={:glam_archive}
        action_label={gettext("Browse")}
        action_path="/manage/catalog/collections"
      >
        <%= if @dashboard_loading do %>
          <.skeleton_metrics />
        <% else %>
          <.voile_metric_row
            label={gettext("Total collections")}
            value={@catalog_stats.total_collections}
            tone={:info}
          />
          <.voile_metric_row
            label={gettext("Published")}
            value={@catalog_stats.published_collections}
            total={@catalog_stats.total_collections}
            tone={:success}
          />
          <.voile_metric_row
            label={gettext("Total items")}
            value={@catalog_stats.total_items}
            tone={:brand}
          />
          <.voile_metric_row
            label={gettext("Available")}
            value={@catalog_stats.available_items}
            total={@catalog_stats.total_items}
            tone={:glam_library}
          />
        <% end %>
      </.voile_section_card>
    </div>

    <div class="grid grid-cols-1 lg:grid-cols-2 gap-4">
      <.voile_search_insights stats={@search_stats} action_path="/manage/settings/metrics" />

      <%= for widget <- @plugin_widgets do %>
        <.voile_section_card title={widget.title} icon="hero-puzzle-piece" tone={:brand}>
          <.live_component module={widget.component} id={to_string(widget.key)} />
        </.voile_section_card>
      <% end %>
    </div>
    """
  end

  defp skeleton_metrics(assigns) do
    ~H"""
    <div class="space-y-3">
      <%= for _ <- 1..4 do %>
        <div class="flex items-center justify-between py-2">
          <div class="skeleton h-3 w-1/3"></div>
          <div class="skeleton h-3 w-10"></div>
        </div>
      <% end %>
    </div>
    """
  end

  defp skeleton_feed(assigns) do
    ~H"""
    <div class="space-y-2">
      <%= for _ <- 1..4 do %>
        <div class="flex items-center gap-3 p-2">
          <div class="skeleton w-8 h-8 rounded-lg shrink-0"></div>
          <div class="flex-1 space-y-2">
            <div class="skeleton h-3 w-2/3"></div>
            <div class="skeleton h-3 w-1/3"></div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end
end
