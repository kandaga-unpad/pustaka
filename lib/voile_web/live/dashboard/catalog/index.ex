defmodule VoileWeb.Dashboard.Catalog.Index do
  use VoileWeb, :live_view_dashboard

  import VoileWeb.VoileDashboardComponents, only: [dashboard_menu_bar: 1]

  alias Voile.Schema.Catalog

  # A small list of Tailwind color classes to pick from
  @node_colors [
    "from-blue-400 to-blue-600",
    "from-green-400 to-green-600",
    "from-indigo-400 to-indigo-600",
    "from-purple-400 to-purple-600",
    "from-pink-400 to-pink-600",
    "from-yellow-400 to-yellow-600",
    "from-red-400 to-red-600",
    "from-teal-400 to-teal-600"
  ]

  defp pick_node_color(id) do
    # phash2 returns 0..(range-1), so safe to use with Enum.at
    idx = :erlang.phash2(id, length(@node_colors))
    Enum.at(@node_colors, idx)
  end

  def render(assigns) do
    ~H"""
    <section class="flex flex-col gap-4">
      <div><.dashboard_menu_bar user={@current_scope.user} /></div>
      
      <div class="flex flex-col gap-4 p-4 rounded-lg shadow-md bg-white dark:bg-gray-800">
        <h1 class="text-2xl font-bold">{gettext("Catalog")}</h1>
        
        <div class="w-full">
          <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <div class="rounded-lg p-4 bg-gray-50 dark:bg-gray-700 shadow flex items-center gap-4">
              <div class="p-3 rounded-md bg-blue-50 dark:bg-blue-900/30">
                <!-- GLAM icon small -->
                <svg
                  class="h-6 w-6 text-blue-600 dark:text-blue-300"
                  xmlns="http://www.w3.org/2000/svg"
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="1.5"
                >
                  <path d="M3 10l9-6 9 6" stroke-linecap="round" stroke-linejoin="round" />
                  <path
                    d="M5 10v6M9 10v6M13 10v6M17 10v6"
                    stroke-linecap="round"
                    stroke-linejoin="round"
                  /> <path d="M3 18h18" stroke-linecap="round" stroke-linejoin="round" />
                </svg>
              </div>
              
              <div class="flex-1">
                <div class="text-sm text-gray-500 dark:text-gray-300 font-semibold">
                  {gettext("Total Collections")}
                </div>
                
                <div class="mt-1 flex items-center gap-3">
                  <div class="text-2xl font-bold text-gray-800 dark:text-gray-100">
                    <%= if is_nil(@count_collections) do %>
                      <span class="inline-flex items-center gap-2">
                        <svg
                          class="animate-spin h-5 w-5 text-blue-600 dark:text-blue-300"
                          xmlns="http://www.w3.org/2000/svg"
                          viewBox="0 0 24 24"
                          fill="none"
                        >
                          <circle
                            class="opacity-25"
                            cx="12"
                            cy="12"
                            r="10"
                            stroke="currentColor"
                            stroke-width="4"
                          >
                          </circle>
                          
                          <path
                            class="opacity-75"
                            fill="currentColor"
                            d="M4 12a8 8 0 018-8v4a4 4 0 00-4 4H4z"
                          >
                          </path>
                        </svg>
                        <span class="text-sm text-gray-500 dark:text-gray-300">
                          {gettext("Loading")}
                        </span>
                      </span>
                    <% else %>
                      {@count_collections}
                    <% end %>
                  </div>
                  
                  <div class="text-xs text-gray-500 dark:text-gray-400">
                    {gettext("collections across nodes")}
                  </div>
                </div>
              </div>
            </div>
            
            <div class="rounded-lg p-4 bg-gray-50 dark:bg-gray-700 shadow flex items-center gap-4">
              <div class="p-3 rounded-md bg-green-50 dark:bg-green-900/30">
                <!-- gallery small icon -->
                <svg
                  class="h-6 w-6 text-green-600 dark:text-green-300"
                  xmlns="http://www.w3.org/2000/svg"
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="1.5"
                >
                  <rect x="3" y="4" width="18" height="16" rx="2" ry="2" class="fill-none" />
                  <path d="M7 15l3-4 4 5 3-4" stroke-linecap="round" stroke-linejoin="round" />
                  <circle cx="17" cy="8" r="1.5" />
                </svg>
              </div>
              
              <div class="flex-1">
                <div class="text-sm text-gray-500 dark:text-gray-300 font-semibold">
                  {gettext("Items")}
                </div>
                
                <div class="mt-1 flex items-center gap-3">
                  <div class="text-2xl font-bold text-gray-800 dark:text-gray-100">
                    <%= if is_nil(@count_items) do %>
                      <span class="inline-flex items-center gap-2">
                        <svg
                          class="animate-spin h-5 w-5 text-green-600 dark:text-green-300"
                          xmlns="http://www.w3.org/2000/svg"
                          viewBox="0 0 24 24"
                          fill="none"
                        >
                          <circle
                            class="opacity-25"
                            cx="12"
                            cy="12"
                            r="10"
                            stroke="currentColor"
                            stroke-width="4"
                          >
                          </circle>
                          
                          <path
                            class="opacity-75"
                            fill="currentColor"
                            d="M4 12a8 8 0 018-8v4a4 4 0 00-4 4H4z"
                          >
                          </path>
                        </svg>
                        <span class="text-sm text-gray-500 dark:text-gray-300">
                          {gettext("Loading")}
                        </span>
                      </span>
                    <% else %>
                      {@count_items}
                    <% end %>
                  </div>
                  
                  <div class="text-xs text-gray-500 dark:text-gray-400">
                    {gettext("items across nodes")}
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
         <hr class="my-4 text-gray-200 dark:text-gray-700" />
        <div class="w-full">
          <h3 class="text-lg font-semibold mb-2">{gettext("Per Node Statistics")}</h3>
          
          <%= if @count_all_nodes == [] do %>
            <div class="flex items-center justify-center p-4">
              <svg
                class="animate-spin h-8 w-8 text-gray-600 dark:text-gray-300"
                xmlns="http://www.w3.org/2000/svg"
                fill="none"
                viewBox="0 0 24 24"
              >
                <circle
                  class="opacity-25"
                  cx="12"
                  cy="12"
                  r="10"
                  stroke="currentColor"
                  stroke-width="4"
                >
                </circle>
                
                <path
                  class="opacity-75"
                  fill="currentColor"
                  d="M4 12a8 8 0 018-8v4a4 4 0 00-4 4H4z"
                >
                </path>
              </svg>
              <span class="ml-2 text-gray-600 dark:text-gray-300">{gettext("Loading nodes...")}</span>
            </div>
          <% else %>
            <div class="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 gap-4">
              <%= for node <- @count_all_nodes do %>
                <div class="rounded-lg overflow-hidden shadow hover:shadow-lg transform hover:-translate-y-1 transition-all bg-white dark:bg-gray-400">
                  <div class={"px-4 py-3 bg-gradient-to-r " <> node.color}>
                    <h4 class="text-sm font-medium text-white truncate">{node.name}</h4>
                  </div>
                  
                  <div class="p-4 grid grid-cols-2 gap-3 bg-white dark:bg-gray-600">
                    <div class="flex items-center gap-3">
                      <div class="p-2 rounded-md bg-gray-100 dark:bg-gray-900">
                        <!-- GLAM / collection icon: classical building with columns -->
                        <svg
                          class="h-5 w-5 text-gray-600 dark:text-gray-300"
                          xmlns="http://www.w3.org/2000/svg"
                          viewBox="0 0 24 24"
                          fill="none"
                          stroke="currentColor"
                          stroke-width="1.5"
                        >
                          <path d="M3 10l9-6 9 6" stroke-linecap="round" stroke-linejoin="round" />
                          <path
                            d="M5 10v6M9 10v6M13 10v6M17 10v6"
                            stroke-linecap="round"
                            stroke-linejoin="round"
                          /> <path d="M3 18h18" stroke-linecap="round" stroke-linejoin="round" />
                        </svg>
                      </div>
                      
                      <div>
                        <div class="text-xs text-gray-500 dark:text-gray-300">
                          {gettext("Collections")}
                        </div>
                        
                        <div class="text-lg font-semibold text-gray-800 dark:text-gray-100">
                          <%= if is_nil(node.count_collections) do %>
                            <span class="inline-flex items-center gap-2">
                              <svg
                                class="animate-spin h-4 w-4 text-gray-600 dark:text-gray-300"
                                xmlns="http://www.w3.org/2000/svg"
                                fill="none"
                                viewBox="0 0 24 24"
                              >
                                <circle
                                  class="opacity-25"
                                  cx="12"
                                  cy="12"
                                  r="10"
                                  stroke="currentColor"
                                  stroke-width="4"
                                >
                                </circle>
                                
                                <path
                                  class="opacity-75"
                                  fill="currentColor"
                                  d="M4 12a8 8 0 018-8v4a4 4 0 00-4 4H4z"
                                >
                                </path>
                              </svg> <span class="text-sm">{gettext("Loading")}</span>
                            </span>
                          <% else %>
                            {node.count_collections}
                          <% end %>
                        </div>
                      </div>
                    </div>
                    
                    <div class="flex items-center gap-3">
                      <div class="p-2 rounded-md bg-gray-100 dark:bg-gray-900">
                        <!-- gallery / item icon: framed photo with mountain and sun -->
                        <svg
                          class="h-5 w-5 text-gray-600 dark:text-gray-300"
                          xmlns="http://www.w3.org/2000/svg"
                          viewBox="0 0 24 24"
                          fill="none"
                          stroke="currentColor"
                          stroke-width="1.5"
                        >
                          <rect x="3" y="4" width="18" height="16" rx="2" ry="2" class="fill-none" />
                          <path d="M7 15l3-4 4 5 3-4" stroke-linecap="round" stroke-linejoin="round" />
                          <circle cx="17" cy="8" r="1.5" />
                        </svg>
                      </div>
                      
                      <div>
                        <div class="text-xs text-gray-500 dark:text-gray-300">{gettext("Items")}</div>
                        
                        <div class="text-lg font-semibold text-gray-800 dark:text-gray-100">
                          <%= if is_nil(node.count_items) do %>
                            <span class="inline-flex items-center gap-2">
                              <svg
                                class="animate-spin h-4 w-4 text-gray-600 dark:text-gray-300"
                                xmlns="http://www.w3.org/2000/svg"
                                fill="none"
                                viewBox="0 0 24 24"
                              >
                                <circle
                                  class="opacity-25"
                                  cx="12"
                                  cy="12"
                                  r="10"
                                  stroke="currentColor"
                                  stroke-width="4"
                                >
                                </circle>
                                
                                <path
                                  class="opacity-75"
                                  fill="currentColor"
                                  d="M4 12a8 8 0 018-8v4a4 4 0 00-4 4H4z"
                                >
                                </path>
                              </svg> <span class="text-sm">{gettext("Loading")}</span>
                            </span>
                          <% else %>
                            {node.count_items}
                          <% end %>
                        </div>
                      </div>
                    </div>
                  </div>
                </div>
              <% end %>
            </div>
          <% end %>
        </div>
      </div>
    </section>
    """
  end

  def mount(_params, _session, socket) do
    # Initially assign nils so template shows spinners/placeholders
    socket =
      socket
      |> assign(:count_collections, nil)
      |> assign(:count_items, nil)
      |> assign(:count_all_nodes, [])
      |> assign(:page_title, gettext("Catalog Dashboard"))

    # Defer loading counts to handle_info so UI mounts fast
    if connected?(socket), do: send(self(), :load_counts)

    {:ok, socket}
  end

  def handle_info(:load_counts, socket) do
    count_collections = Catalog.count_collections()
    count_items = Catalog.count_items()
    get_nodes = Voile.Schema.System.list_nodes()

    # Prepare nodes with deterministic color and nil counts initially,
    # then populate counts so UI shows spinners first per node.
    count_all_nodes =
      Enum.map(get_nodes, fn node ->
        color = pick_node_color(node.id)

        %{
          id: node.id,
          name: node.name,
          color: color,
          count_collections: nil,
          count_items: nil
        }
      end)

    # Assign the placeholder nodes first so the template can render spinners per node,
    # then fetch counts and update the assigns.
    socket = assign(socket, :count_all_nodes, count_all_nodes)

    # Fetch counts for nodes and update entries (synchronously here; can be async later)
    count_all_nodes =
      Enum.map(count_all_nodes, fn node ->
        Map.put(node, :count_collections, Catalog.count_collections(node.id))
        |> Map.put(:count_items, Catalog.count_items(node.id))
      end)

    socket =
      socket
      |> assign(:count_collections, count_collections)
      |> assign(:count_items, count_items)
      |> assign(:count_all_nodes, count_all_nodes)

    {:noreply, socket}
  end
end
