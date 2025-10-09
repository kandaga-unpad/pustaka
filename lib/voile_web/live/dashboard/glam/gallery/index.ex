defmodule VoileWeb.Dashboard.Glam.Gallery.Index do
  use VoileWeb, :live_view_dashboard

  alias Voile.Repo
  alias Voile.Schema.Catalog.Collection

  import Ecto.Query
  import VoileWeb.Dashboard.Glam.Library.Circulation.Components, only: [circulation_breadcrumb: 1]

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user

    # Get gallery-specific collections
    gallery_collections = get_gallery_collections()

    socket =
      socket
      |> assign(:page_title, "Gallery Dashboard")
      |> assign(:gallery_collections, gallery_collections)
      |> assign(:user, user)

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <%!-- Breadcrumb --%>
      <.circulation_breadcrumb
        root_label="Manage"
        root_path={~p"/manage"}
        section_label="GLAM"
        section_path={~p"/manage/glam"}
        current_label="Gallery"
      /> <%!-- Page Header --%>
      <div class="bg-gradient-to-r from-pink-500 to-rose-600 rounded-xl p-8 text-white shadow-lg">
        <div class="flex items-center justify-between">
          <div>
            <h1 class="text-3xl font-bold mb-2">Gallery Management</h1>
            
            <p class="text-pink-100 text-lg">
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
            <div class="p-3 rounded-lg bg-pink-100 dark:bg-pink-900/30">
              <.icon name="hero-rectangle-stack" class="w-6 h-6 text-pink-600 dark:text-pink-400" />
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
            <div class="p-3 rounded-lg bg-green-100 dark:bg-green-900/30">
              <.icon name="hero-plus-circle" class="w-6 h-6 text-green-600 dark:text-green-400" />
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
            <div class="p-3 rounded-lg bg-blue-100 dark:bg-blue-900/30">
              <.icon name="hero-cube" class="w-6 h-6 text-blue-600 dark:text-blue-400" />
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
            <div class="text-3xl font-bold text-pink-600 dark:text-pink-400">
              {length(@gallery_collections)}
            </div>
            
            <div class="text-sm text-gray-600 dark:text-gray-400 mt-1">Total Collections</div>
          </div>
          
          <div class="text-center">
            <div class="text-3xl font-bold text-rose-600 dark:text-rose-400">
              {count_total_items(@gallery_collections)}
            </div>
            
            <div class="text-sm text-gray-600 dark:text-gray-400 mt-1">Total Items</div>
          </div>
          
          <div class="text-center">
            <div class="text-3xl font-bold text-purple-600 dark:text-purple-400">
              {count_public_collections(@gallery_collections)}
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

  defp count_total_items(collections) do
    Enum.reduce(collections, 0, fn collection, acc ->
      acc + length(collection.items)
    end)
  end

  defp count_public_collections(collections) do
    Enum.count(collections, fn collection ->
      collection.status == "published"
    end)
  end
end
