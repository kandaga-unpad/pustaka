defmodule VoileWeb.Dashboard.Glam.Library.Index do
  use VoileWeb, :live_view_dashboard

  alias Voile.Repo
  alias Voile.Schema.Catalog.{Collection, Item}

  import Ecto.Query

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user

    # preview collection list (limited)
    preview_collections = get_library_collections()

    # global aggregates
    total_collections = get_library_total_collections()
    total_items = get_library_total_items()
    published_collections = get_library_published_collections()

    socket =
      socket
      |> assign(:page_title, "Library Dashboard")
      |> assign(:library_collections, preview_collections)
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
        %{label: "Library", path: nil}
      ]} /> <%!-- Page Header --%>
      <div class="bg-gradient-to-r from-indigo-600 to-blue-600 rounded-xl p-8 text-white shadow-lg">
        <div class="flex items-center justify-between">
          <div>
            <h1 class="text-3xl font-bold mb-2">Library Management</h1>
            
            <p class="text-indigo-100 text-lg">Manage library collections, circulation, and items</p>
          </div>
          
          <div class="hidden md:block">
            <.icon name="hero-book-open" class="w-24 h-24 opacity-20" />
          </div>
        </div>
      </div>
       <%!-- Quick Actions --%>
      <div class="grid grid-cols-1 md:grid-cols-3 gap-6">
        <.link
          navigate="/manage/catalog/collections?glam_type=Library"
          class="bg-white dark:bg-gray-700 rounded-xl p-6 shadow hover:shadow-lg transition-shadow"
        >
          <div class="flex items-center gap-4">
            <div class="p-3 rounded-lg bg-indigo-100 dark:bg-indigo-900/30">
              <.icon name="hero-rectangle-stack" class="w-6 h-6 text-indigo-600 dark:text-indigo-400" />
            </div>
            
            <div>
              <h3 class="font-semibold text-gray-900 dark:text-white">View Collections</h3>
              
              <p class="text-sm text-gray-600 dark:text-gray-400">Browse all library collections</p>
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
              
              <p class="text-sm text-gray-600 dark:text-gray-400">Create a new library collection</p>
            </div>
          </div>
        </.link>
        <.link
          navigate="/manage/catalog/items?glam_type=Library"
          class="bg-white dark:bg-gray-700 rounded-xl p-6 shadow hover:shadow-lg transition-shadow"
        >
          <div class="flex items-center gap-4">
            <div class="p-3 rounded-lg bg-blue-100 dark:bg-blue-900/30">
              <.icon name="hero-cube" class="w-6 h-6 text-blue-600 dark:text-blue-400" />
            </div>
            
            <div>
              <h3 class="font-semibold text-gray-900 dark:text-white">View Items</h3>
              
              <p class="text-sm text-gray-600 dark:text-gray-400">Browse all library items</p>
            </div>
          </div>
        </.link>
      </div>
       <%!-- Statistics --%>
      <div class="bg-white dark:bg-gray-700 rounded-xl p-6 shadow">
        <h2 class="text-xl font-semibold text-gray-900 dark:text-white mb-4">Library Statistics</h2>
        
        <div class="grid grid-cols-1 md:grid-cols-3 gap-6">
          <div class="text-center">
            <div class="text-3xl font-bold text-indigo-600 dark:text-indigo-400">
              {@total_collections}
            </div>
            
            <div class="text-sm text-gray-600 dark:text-gray-400 mt-1">Total Collections</div>
          </div>
          
          <div class="text-center">
            <div class="text-3xl font-bold text-blue-600 dark:text-blue-400">{@total_items}</div>
            
            <div class="text-sm text-gray-600 dark:text-gray-400 mt-1">Total Items</div>
          </div>
          
          <div class="text-center">
            <div class="text-3xl font-bold text-purple-600 dark:text-purple-400">
              {@published_collections}
            </div>
            
            <div class="text-sm text-gray-600 dark:text-gray-400 mt-1">Published</div>
          </div>
        </div>
      </div>
       <%!-- Library Operationals --%>
      <div class="bg-white dark:bg-gray-700 rounded-xl p-6 shadow">
        <h2 class="text-xl font-semibold text-gray-900 dark:text-white mb-4">Library Operations</h2>
        
        <div class="grid grid-cols-1 md:grid-cols-3 gap-6">
          <.link
            navigate="/manage/glam/library/circulation"
            class="bg-gray-200 dark:bg-gray-600 rounded-xl p-6 shadow hover:shadow-lg transition-shadow"
          >
            <div class="flex items-center gap-4">
              <div class="p-3 rounded-lg bg-yellow-100 dark:bg-yellow-900/30">
                <.icon name="hero-arrow-path" class="w-6 h-6 text-yellow-600 dark:text-yellow-400" />
              </div>
              
              <div>
                <h4 class="font-semibold text-gray-900 dark:text-white">Manage Circulations</h4>
                
                <p class="text-sm text-gray-600 dark:text-gray-400">
                  View and manage book circulations
                </p>
              </div>
            </div>
          </.link>
        </div>
      </div>
    </div>
    """
  end

  defp get_library_collections do
    from(c in Collection,
      join: rc in assoc(c, :resource_class),
      where: rc.glam_type == "Library",
      order_by: [desc: c.inserted_at],
      limit: 50,
      preload: [:resource_class, :items]
    )
    |> Repo.all()
  end

  defp get_library_total_collections do
    from(c in Collection,
      join: rc in assoc(c, :resource_class),
      where: rc.glam_type == "Library"
    )
    |> Repo.aggregate(:count, :id)
  end

  defp get_library_total_items do
    from(i in Item,
      join: c in assoc(i, :collection),
      join: rc in assoc(c, :resource_class),
      where: rc.glam_type == "Library"
    )
    |> Repo.aggregate(:count, :id)
  end

  defp get_library_published_collections do
    from(c in Collection,
      join: rc in assoc(c, :resource_class),
      where: rc.glam_type == "Library" and c.status == "published"
    )
    |> Repo.aggregate(:count, :id)
  end
end
