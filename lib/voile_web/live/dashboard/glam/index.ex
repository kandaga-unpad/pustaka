defmodule VoileWeb.Dashboard.Glam.Index do
  use VoileWeb, :live_view_dashboard

  alias Voile.Repo
  alias Voile.Schema.Catalog.Collection
  alias Voile.Schema.Catalog.Item
  alias Voile.Schema.Metadata.ResourceClass
  alias VoileWeb.Auth.Authorization

  import Ecto.Query

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user

    is_super_admin = Authorization.is_super_admin?(user)

    socket =
      socket
      |> assign(:page_title, gettext("GLAM Dashboard"))
      |> assign(:user, user)
      |> assign(:is_super_admin, is_super_admin)

    socket =
      if is_super_admin do
        nodes = Voile.Schema.System.list_nodes()

        socket |> assign(:nodes, nodes) |> assign(:selected_node_id, nil)
      else
        socket |> assign(:nodes, []) |> assign(:selected_node_id, user.node_id)
      end

    # compute initial stats scoped by user/node and recent collections
    socket =
      socket
      |> assign(:glam_stats, get_glam_statistics(user))
      |> assign(:recent_collections, get_recent_collections(5, user))

    {:ok, socket}
  end

  @impl true
  def handle_event("select_node", %{"node_id" => node_id_str}, socket) do
    node_id =
      case node_id_str do
        nil -> nil
        "all" -> nil
        "" -> nil
        id -> String.to_integer(id)
      end

    socket = assign(socket, :selected_node_id, node_id)

    # Determine user context for stats (override node for super_admin when a node is selected)
    user = socket.assigns.user

    user_for_stats =
      if Authorization.is_super_admin?(user) and not is_nil(node_id) do
        Map.put(user, :node_id, node_id)
      else
        user
      end

    socket =
      socket
      |> assign(:glam_stats, get_glam_statistics(user_for_stats))
      |> assign(:recent_collections, get_recent_collections(5, user_for_stats))

    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6 px-3 mt-5 md:px-0">
      <%= if @is_super_admin do %>
        <div class="mb-4">
          <.form :let={f} for={%{}} phx-change="select_node">
            <.input
              field={f[:node_id]}
              type="select"
              options={
                [{"All Nodes", "all"}] ++
                  Enum.map(@nodes || [], fn n -> {n.name, to_string(n.id)} end)
              }
              value={if @selected_node_id, do: to_string(@selected_node_id), else: "all"}
              class="block w-64 text-sm border border-voile-muted rounded-md shadow-sm"
              label={gettext("Filter node")}
            />
          </.form>
        </div>
      <% end %>
      <%!-- Breadcrumb --%>
      <.breadcrumb items={[
        %{label: gettext("Manage"), path: ~p"/manage"},
        %{label: gettext("GLAM"), path: nil}
      ]} /> <%!-- Page Header --%>
      <div class="bg-gradient-to-r from-purple-600 to-indigo-600 rounded-xl p-8 text-white shadow-lg">
        <div class="flex items-center justify-between">
          <div>
            <h1 class="text-3xl font-bold mb-2">{gettext("GLAM Management Dashboard")}</h1>

            <p class="text-white text-lg">
              {gettext("Gallery, Library, Archive & Museum - Unified Collections Management")}
            </p>
          </div>

          <div class="hidden md:block">
            <.icon name="hero-building-library" class="w-24 h-24 opacity-20" />
          </div>
        </div>
      </div>
      <%!-- GLAM Type Navigation Cards --%> <.glam_navigation_cards glam_stats={@glam_stats} />
      <%!-- Quick Stats Overview --%>
      <div class="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-4 gap-6">
        <.stat_card
          title={gettext("Total Collections")}
          value={@glam_stats.total_collections}
          icon="hero-rectangle-stack"
          color="blue"
          trend="+12%"
        />
        <.stat_card
          title={gettext("Total Items")}
          value={@glam_stats.total_items}
          icon="hero-cube"
          color="green"
          trend="+8%"
        />
        <.stat_card
          title={gettext("Total Nodes")}
          value={@glam_stats.total_nodes}
          icon="hero-map-pin"
          color="purple"
        />
        <.stat_card
          title={gettext("Resource Classes")}
          value={@glam_stats.resource_classes}
          icon="hero-tag"
          color="orange"
        />
      </div>
      <%!-- Recent Activity --%>
      <div class="bg-white dark:bg-gray-700 rounded-xl p-6 shadow">
        <div class="flex items-center justify-between mb-6">
          <div class="flex items-center gap-3">
            <.icon name="hero-clock" class="w-6 h-6 text-gray-600 dark:text-gray-300" />
            <h2 class="text-xl font-semibold text-gray-900 dark:text-white">
              {gettext("Recent Collections")}
            </h2>
          </div>

          <.link
            navigate="/manage/catalog/collections"
            class="text-sm text-voile-primary hover:text-voile-primary/80 dark:text-voile-primary/60 dark:hover:text-voile-primary/40 font-medium"
          >
            {gettext("View All")} →
          </.link>
        </div>

        <div class="space-y-3">
          <%= for collection <- @recent_collections do %>
            <.recent_collection_item collection={collection} />
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  # Private helper functions

  defp get_glam_statistics(user) do
    gallery_count = count_collections_by_glam("Gallery", user)
    library_count = count_collections_by_glam("Library", user)
    archive_count = count_collections_by_glam("Archive", user)
    museum_count = count_collections_by_glam("Museum", user)

    total_collections = gallery_count + library_count + archive_count + museum_count

    total_items =
      if is_nil(user.node_id) do
        # Super admin viewing all nodes or no node_id set
        Repo.aggregate(Item, :count, :id)
      else
        # Scoped to specific node
        Repo.aggregate(
          from(i in Item, join: c in assoc(i, :collection), where: c.unit_id == ^user.node_id),
          :count,
          :id
        )
      end

    # Count all nodes (no is_active field in the schema)
    total_nodes = Repo.aggregate(Voile.Schema.System.Node, :count, :id)

    resource_classes = Repo.aggregate(ResourceClass, :count, :id)

    %{
      gallery: %{
        count: gallery_count,
        percentage: calculate_percentage(gallery_count, total_collections)
      },
      library: %{
        count: library_count,
        percentage: calculate_percentage(library_count, total_collections)
      },
      archive: %{
        count: archive_count,
        percentage: calculate_percentage(archive_count, total_collections)
      },
      museum: %{
        count: museum_count,
        percentage: calculate_percentage(museum_count, total_collections)
      },
      total_collections: total_collections,
      total_items: total_items,
      total_nodes: total_nodes,
      resource_classes: resource_classes
    }
  end

  defp count_collections_by_glam(glam_type, user) do
    base =
      from(c in Collection,
        join: rc in assoc(c, :resource_class),
        where: rc.glam_type == ^glam_type
      )

    query =
      if is_nil(user.node_id) do
        # No node filter - show all
        base
      else
        # Filter by node
        from(c in base, where: c.unit_id == ^user.node_id)
      end

    Repo.aggregate(query, :count, :id)
  end

  defp calculate_percentage(_count, 0), do: 0
  defp calculate_percentage(count, total), do: Float.round(count / total * 100, 3)

  defp get_recent_collections(limit, user) do
    base =
      from(c in Collection,
        join: rc in assoc(c, :resource_class),
        order_by: [desc: c.inserted_at],
        limit: ^limit,
        preload: [:resource_class, :mst_creator]
      )

    query =
      if is_nil(user.node_id) do
        # No node filter - show all
        base
      else
        # Filter by node
        from(c in base, where: c.unit_id == ^user.node_id)
      end

    Repo.all(query)
  end
end
