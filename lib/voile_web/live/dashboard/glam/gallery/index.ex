defmodule VoileWeb.Dashboard.Glam.Gallery.Index do
  use VoileWeb, :live_view_dashboard

  alias Voile.Repo
  alias Voile.Schema.Catalog.Collection
  alias Voile.Schema.Catalog.Item

  import Ecto.Query

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user

    # Get gallery-specific collections
    gallery_collections = get_gallery_collections()

    # Compute global aggregates (not limited to the preview list)
    total_collections = get_gallery_total_collections()
    total_items = get_gallery_total_items()
    published_collections = get_gallery_published_collections()

    socket =
      socket
      |> assign(:page_title, "Gallery Dashboard")
      |> assign(:gallery_collections, gallery_collections)
      |> assign(:total_collections, total_collections)
      |> assign(:total_items, total_items)
      |> assign(:published_collections, published_collections)
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
        %{label: "GLAM", path: ~p"/manage/glam"},
        %{label: "Gallery", path: nil}
      ]} /> <%!-- Page Header --%>
      <div class="voile-gradient rounded-xl p-8 text-white shadow-lg">
        <div class="flex items-center justify-between">
          <div>
            <h1 class="text-3xl font-bold mb-2">Gallery Management</h1>
            
            <p class="text-voile-accent text-lg">
              Manage visual arts, photographs, and artistic collections
            </p>
          </div>
          
          <div class="hidden md:block"><.icon name="hero-photo" class="w-24 h-24 opacity-20" /></div>
        </div>
      </div>
       <%!-- Quick Actions --%>
      <div class="grid grid-cols-1 md:grid-cols-3 gap-6">
        <.link
          navigate="/manage/catalog/collections?glam_type=Gallery"
          class="bg-white dark:bg-gray-700 rounded-xl p-6 shadow hover:shadow-lg transition-shadow"
        >
          <div class="flex items-center gap-4">
            <div class="p-3 rounded-lg bg-voile-accent/10 dark:bg-voile-accent/30">
              <.icon
                name="hero-rectangle-stack"
                class="w-6 h-6 text-voile-accent dark:text-voile-accent/60"
              />
            </div>
            
            <div>
              <h3 class="font-semibold text-gray-900 dark:text-white">View Collections</h3>
              
              <p class="text-sm text-gray-600 dark:text-gray-400">Browse all gallery collections</p>
            </div>
          </div>
        </.link>
        <.link
          navigate="/manage/catalog/collections/new"
          class="bg-white dark:bg-gray-700 rounded-xl p-6 shadow hover:shadow-lg transition-shadow"
        >
          <div class="flex items-center gap-4">
            <div class="p-3 rounded-lg bg-voile-success/10 dark:bg-voile-success/30">
              <.icon
                name="hero-plus-circle"
                class="w-6 h-6 text-voile-success dark:text-voile-success/60"
              />
            </div>
            
            <div>
              <h3 class="font-semibold text-gray-900 dark:text-white">New Collection</h3>
              
              <p class="text-sm text-gray-600 dark:text-gray-400">Create a new gallery collection</p>
            </div>
          </div>
        </.link>
        <.link
          navigate="/manage/catalog/items?glam_type=Gallery"
          class="bg-white dark:bg-gray-700 rounded-xl p-6 shadow hover:shadow-lg transition-shadow"
        >
          <div class="flex items-center gap-4">
            <div class="p-3 rounded-lg bg-voile-info/10 dark:bg-voile-info/30">
              <.icon name="hero-cube" class="w-6 h-6 text-voile-info dark:text-voile-info/60" />
            </div>
            
            <div>
              <h3 class="font-semibold text-gray-900 dark:text-white">View Items</h3>
              
              <p class="text-sm text-gray-600 dark:text-gray-400">Browse all gallery items</p>
            </div>
          </div>
        </.link>
      </div>
       <%!-- Statistics --%>
      <div class="bg-white dark:bg-gray-700 rounded-xl p-6 shadow">
        <h2 class="text-xl font-semibold text-gray-900 dark:text-white mb-4">Gallery Statistics</h2>
        
        <div class="grid grid-cols-1 md:grid-cols-3 gap-6">
          <div class="text-center">
            <div class="text-3xl font-bold text-voile-accent dark:text-voile-accent/60">
              {@total_collections}
            </div>
            
            <div class="text-sm text-gray-600 dark:text-gray-400 mt-1">Total Collections</div>
          </div>
          
          <div class="text-center">
            <div class="text-3xl font-bold text-voile-accent dark:text-voile-accent/60">
              {@total_items}
            </div>
            
            <div class="text-sm text-gray-600 dark:text-gray-400 mt-1">Total Items</div>
          </div>
          
          <div class="text-center">
            <div class="text-3xl font-bold text-voile-primary dark:text-voile-primary">
              {@published_collections}
            </div>
            
            <div class="text-sm text-gray-600 dark:text-gray-400 mt-1">Published</div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # Private helper functions

  defp get_gallery_collections do
    from(c in Collection,
      join: rc in assoc(c, :resource_class),
      where: rc.glam_type == "Gallery",
      order_by: [desc: c.inserted_at],
      limit: 50,
      preload: [:resource_class, :items]
    )
    |> Repo.all()
  end

  # Aggregate helpers that count across the whole DB (not limited)
  defp get_gallery_total_collections do
    from(c in Collection,
      join: rc in assoc(c, :resource_class),
      where: rc.glam_type == "Gallery"
    )
    |> Repo.aggregate(:count, :id)
  end

  defp get_gallery_total_items do
    from(i in Item,
      join: c in assoc(i, :collection),
      join: rc in assoc(c, :resource_class),
      where: rc.glam_type == "Gallery"
    )
    |> Repo.aggregate(:count, :id)
  end

  defp get_gallery_published_collections do
    from(c in Collection,
      join: rc in assoc(c, :resource_class),
      where: rc.glam_type == "Gallery" and c.status == "published"
    )
    |> Repo.aggregate(:count, :id)
  end
end
