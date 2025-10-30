defmodule VoileWeb.Dashboard.Glam.Index do
  use VoileWeb, :live_view_dashboard

  alias Voile.Repo
  alias Voile.Schema.Catalog.Collection
  alias Voile.Schema.Catalog.Item
  alias Voile.Schema.Metadata.ResourceClass

  import Ecto.Query

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user

    # Get statistics for each GLAM type
    glam_stats = get_glam_statistics()

    # Get recent activity across all GLAM types
    recent_collections = get_recent_collections(5)

    socket =
      socket
      |> assign(:page_title, "GLAM Dashboard")
      |> assign(:glam_stats, glam_stats)
      |> assign(:recent_collections, recent_collections)
      |> assign(:user, user)

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <%!-- Breadcrumb --%>
      <.breadcrumb items={[
        %{label: "Manage", path: ~p"/manage"},
        %{label: "GLAM", path: nil}
      ]} /> <%!-- Page Header --%>
      <div class="bg-gradient-to-r from-purple-600 to-indigo-600 rounded-xl p-8 text-white shadow-lg">
        <div class="flex items-center justify-between">
          <div>
            <h1 class="text-3xl font-bold mb-2">GLAM Management Dashboard</h1>

            <p class="text-white text-lg">
              Gallery, Library, Archive & Museum - Unified Collections Management
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
          title="Total Collections"
          value={@glam_stats.total_collections}
          icon="hero-rectangle-stack"
          color="blue"
          trend="+12%"
        />
        <.stat_card
          title="Total Items"
          value={@glam_stats.total_items}
          icon="hero-cube"
          color="green"
          trend="+8%"
        />
        <.stat_card
          title="Total Nodes"
          value={@glam_stats.total_nodes}
          icon="hero-map-pin"
          color="purple"
        />
        <.stat_card
          title="Resource Classes"
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
            <h2 class="text-xl font-semibold text-gray-900 dark:text-white">Recent Collections</h2>
          </div>

          <.link
            navigate="/manage/catalog/collections"
            class="text-sm text-voile-primary hover:text-voile-primary/80 dark:text-voile-primary/60 dark:hover:text-voile-primary/40 font-medium"
          >
            View All →
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

  defp get_glam_statistics do
    gallery_count = count_collections_by_glam("Gallery")
    library_count = count_collections_by_glam("Library")
    archive_count = count_collections_by_glam("Archive")
    museum_count = count_collections_by_glam("Museum")

    total_collections = gallery_count + library_count + archive_count + museum_count

    total_items = Repo.aggregate(Item, :count, :id)

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

  defp count_collections_by_glam(glam_type) do
    from(c in Collection,
      join: rc in assoc(c, :resource_class),
      where: rc.glam_type == ^glam_type
    )
    |> Repo.aggregate(:count, :id)
  end

  defp calculate_percentage(_count, 0), do: 0
  defp calculate_percentage(count, total), do: Float.round(count / total * 100, 3)

  defp get_recent_collections(limit) do
    from(c in Collection,
      join: rc in assoc(c, :resource_class),
      order_by: [desc: c.inserted_at],
      limit: ^limit,
      preload: [:resource_class, :mst_creator]
    )
    |> Repo.all()
  end
end
