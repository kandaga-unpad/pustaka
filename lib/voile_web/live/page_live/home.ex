defmodule VoileWeb.PageLive.Home do
  use VoileWeb, :live_view

  alias Voile.Search.Collections, as: SearchCollections
  alias Voile.Analytics.Dashboard
  alias VoileWeb.VoileComponents

  @impl true
  def mount(params, _session, socket) do
    search_query = Map.get(params, "q", "")
    current_glam_type = Map.get(params, "glam_type", "quick")

    # Get dashboard statistics with fallback defaults
    dashboard_stats = Dashboard.get_dashboard_stats()

    # Ensure we have default empty values for UI safety
    dashboard_stats = %{
      node_collection_count: dashboard_stats.node_collection_count || 0,
      total_item_count: dashboard_stats.total_item_count || 0,
      favorite_books: dashboard_stats.favorite_books || [],
      new_books: dashboard_stats.new_books || [],
      most_active_users: dashboard_stats.most_active_users || [],
      collection_categories: dashboard_stats.collection_categories || [],
      node_collections: dashboard_stats.node_collections || []
    }

    socket =
      socket
      |> assign(:search_query, search_query)
      |> assign(:current_glam_type, current_glam_type)
      |> assign(:search_results, [])
      |> assign(:show_suggestions, false)
      |> assign(:loading, false)
      |> assign(:dashboard_stats, dashboard_stats)

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    search_query = Map.get(params, "q", "")
    current_glam_type = Map.get(params, "glam_type", "quick")

    socket =
      socket
      |> assign(:search_query, search_query)
      |> assign(:current_glam_type, current_glam_type)

    {:noreply, socket}
  end

  @impl true
  def handle_event("search_change", %{"q" => query, "glam_type" => glam_type}, socket) do
    updated_socket =
      socket
      |> assign(:search_query, query)
      |> assign(:current_glam_type, glam_type)
      |> assign(:loading, true)

    # Debounced search for suggestions
    final_socket =
      if String.length(query) >= 2 do
        send(self(), {:perform_search_suggestions, query, glam_type})
        updated_socket
      else
        assign(updated_socket, :search_results, [])
      end

    final_socket = assign(final_socket, :loading, false)
    {:noreply, final_socket}
  end

  @impl true
  def handle_event("search", %{"q" => query, "glam_type" => glam_type}, socket) do
    # Redirect to search results page
    {:noreply,
     socket
     |> push_navigate(to: "/search?q=#{URI.encode(query)}&glam_type=#{glam_type}")}
  end

  @impl true
  def handle_event("show_suggestions", _params, socket) do
    query = socket.assigns.search_query

    if String.length(query) >= 2 do
      send(self(), {:perform_search_suggestions, query, socket.assigns.current_glam_type})
    end

    {:noreply, assign(socket, :show_suggestions, true)}
  end

  @impl true
  def handle_event("hide_suggestions", _params, socket) do
    # Add a small delay to allow for click events on suggestions
    Process.send_after(self(), :hide_suggestions_delayed, 200)
    {:noreply, socket}
  end

  @impl true
  def handle_event("perform_search", %{"query" => query, "glam_type" => glam_type}, socket) do
    {:noreply,
     socket
     |> push_navigate(to: "/search?q=#{URI.encode(query)}&glam_type=#{glam_type}")}
  end

  @impl true
  def handle_event("select_collection", %{"id" => collection_id}, socket) do
    {:noreply,
     socket
     |> push_navigate(to: "/collections/#{collection_id}")}
  end

  @impl true
  def handle_info({:perform_search_suggestions, query, glam_type}, socket) do
    # Only search if the query is still current (user hasn't typed something else)
    if query == socket.assigns.search_query do
      socket = assign(socket, :loading, true)

      # Simulate search - replace this with actual search logic
      search_results = perform_search_suggestions(query, glam_type)

      socket =
        socket
        |> assign(:search_results, search_results)
        |> assign(:loading, false)
        |> assign(:show_suggestions, true)

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info(:hide_suggestions_delayed, socket) do
    {:noreply, assign(socket, :show_suggestions, false)}
  end

  # Real search function using the Search context
  defp perform_search_suggestions(query, glam_type) do
    try do
      SearchCollections.get_search_suggestions(query, glam_type, 8)
    rescue
      _ ->
        # Fallback to empty results if there's an error
        []
    end
  end

  # Helper function to get modern gradient classes for categories
  defp get_category_gradient_class("Library"), do: "bg-gradient-to-br from-blue-500 to-indigo-600"

  defp get_category_gradient_class("Gallery"),
    do: "bg-gradient-to-br from-emerald-500 to-teal-600"

  defp get_category_gradient_class("Archive"),
    do: "bg-gradient-to-br from-amber-500 to-orange-600"

  defp get_category_gradient_class("Museum"), do: "bg-gradient-to-br from-rose-500 to-pink-600"
  defp get_category_gradient_class(_), do: "bg-gradient-to-br from-violet-500 to-purple-600"

  # Helper function to get icon for categories
  defp get_category_icon("Library"), do: "hero-book-open"
  defp get_category_icon("Gallery"), do: "hero-photo"
  defp get_category_icon("Archive"), do: "hero-archive-box"
  defp get_category_icon("Museum"), do: "hero-building-library"
  defp get_category_icon(_), do: "hero-squares-2x2"

  @impl true
  def render(assigns) do
    ~H"""
    <.modal id="advanced-search">
      <h5>{gettext("Advanced Search")}</h5>
      
      <div><.input type="text" name="keyword" value="" label={gettext("Keyword")} /></div>
    </.modal>

    <Layouts.app flash={@flash} current_scope={assigns[:current_scope]}>
      <section class="relative">
        <div>
          <img
            src="/images/default_bg.webp"
            class="absolute w-full h-[600px] md:max-h-[600px] object-cover"
            alt={gettext("Cover Background")}
          />
        </div>
        
        <div class="relative bg-white/50 dark:bg-gray-800/50 h-[600px] w-full">
          <div class="max-w-7xl mx-auto flex flex-col gap-3">
            <div class="flex flex-col items-center justify-center gap-3 pb-16 pt-4 relative z-5 bg-white/80 dark:bg-gray-800/80 rounded-b-xl">
              <img src="/images/v.png" alt="" class="h-full w-32" />
              <h5 class="text-center">{gettext("Voile, the Magic Library")}</h5>
              
              <p class="max-w-3xl mx-auto text-center text-sm">
                {gettext(
                  "Voile is your gateway to a world of cultural treasures. Imagine stepping into a digital sanctuary where libraries, museums, and archives converge into one intuitive space. Whether you're seeking your next great read, exploring rare artworks, or diving into historical archives, Voile offers a beautifully curated collection at your fingertips. Simply browse through diverse collections, uncover hidden gems, and let your curiosity lead you on a journey of discovery. With Voile, every click opens a door to inspiration and learning in an inviting, user-friendly environment."
                )}
              </p>
            </div>
            
            <div class="max-w-5xl mx-auto flex flex-col w-full gap-4">
              <div class="w-full flex flex-col gap-2">
                <VoileComponents.main_search
                  current_glam_type={@current_glam_type}
                  search_query={@search_query}
                  live_action={@live_action}
                  search_results={@search_results}
                  show_suggestions={@show_suggestions}
                  loading={@loading}
                />
                <div class="flex gap-2">
                  <.link navigate="/collections" class="w-full">
                    <.button class="w-full dashboard-menu-btn">{gettext("All Collections")}</.button>
                  </.link>
                  <.button class="w-full default-btn" phx-click={show_modal("advanced-search")}>
                    {gettext("Advanced Search")}
                  </.button>
                </div>
              </div>
            </div>
          </div>
        </div>
        <!-- Dashboard Highlights Section -->
        <section class="max-w-7xl mx-auto py-16 px-4">
          <div class="text-center mb-12">
            <h2 class="voile-text-gradient mb-4">{gettext("Collection Highlights")}</h2>
            
            <p class="text-gray-600 dark:text-gray-300 max-w-2xl mx-auto mb-8">
              {gettext(
                "Discover the collections within our digital sanctuary, from rare collections to active communities, you can search about anything. Here is the location and statistics of our collections."
              )}
            </p>
            <!-- Node Collection Stats -->
            <%= if length(@dashboard_stats.node_collections) > 0 do %>
              <div class="grid grid-cols-2 md:grid-cols-3 gap-4 max-w-4xl mx-auto mb-8">
                <%= for node <- @dashboard_stats.node_collections do %>
                  <.link
                    navigate={"/collections?unit_id=#{node.id}"}
                    class="block"
                  >
                    <div class="group cursor-pointer">
                      <div class="relative overflow-hidden rounded-2xl shadow-lg hover:shadow-xl transition-all duration-300 transform hover:-translate-y-1">
                        <div class={"absolute inset-0 bg-gradient-to-br opacity-90 #{node.color}"}>
                        </div>
                        
                        <div class="relative p-6 text-center text-white">
                          <div class="text-2xl font-bold mb-1">{node.collection_count}</div>
                          
                          <div class="text-sm opacity-90 truncate">{node.name}</div>
                          
                          <div class="text-lg opacity-75 mt-1">{node.abbr}</div>
                        </div>
                      </div>
                    </div>
                  </.link>
                <% end %>
              </div>
            <% end %>
          </div>
          <!-- Statistics Grid -->
          <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-12">
            <!-- Node Collections Count -->
            <div class="group relative overflow-hidden rounded-2xl bg-gradient-to-br from-white to-gray-50 dark:from-gray-800 dark:to-gray-900 border border-gray-200 dark:border-gray-700 shadow-lg hover:shadow-2xl transition-all duration-500 transform hover:-translate-y-2">
              <div class="absolute inset-0 bg-gradient-to-r from-violet-500/10 to-purple-500/10 opacity-0 group-hover:opacity-100 transition-opacity duration-500">
              </div>
              
              <div class="relative p-6 text-center">
                <div class="w-16 h-16 mx-auto mb-4 rounded-2xl bg-gradient-to-br from-violet-500 to-purple-600 flex items-center justify-center shadow-lg">
                  <.icon name="hero-building-library" class="w-8 h-8 text-white" />
                </div>
                
                <div class="text-3xl font-black text-transparent bg-clip-text bg-gradient-to-r from-violet-600 to-purple-600 mb-2">
                  {@dashboard_stats.node_collection_count}
                </div>
                
                <p class="text-sm font-medium text-gray-600 dark:text-gray-300">
                  {gettext("Total Collections")}
                </p>
                
                <div class="text-3xl font-black text-transparent bg-clip-text bg-gradient-to-r from-violet-600 to-purple-600 mb-2 mt-4">
                  {@dashboard_stats.total_item_count}
                </div>
                
                <p class="text-sm font-medium text-gray-600 dark:text-gray-300">
                  {gettext("Total Items")}
                </p>
              </div>
            </div>
            <!-- Collection Categories -->
            <div class="group relative overflow-hidden rounded-2xl bg-gradient-to-br from-white to-gray-50 dark:from-gray-800 dark:to-gray-900 border border-gray-200 dark:border-gray-700 shadow-lg hover:shadow-2xl transition-all duration-500 transform hover:-translate-y-2">
              <div class="absolute inset-0 bg-gradient-to-r from-emerald-500/10 to-teal-500/10 opacity-0 group-hover:opacity-100 transition-opacity duration-500">
              </div>
              
              <div class="relative p-6">
                <div class="w-16 h-16 mx-auto mb-4 rounded-2xl bg-gradient-to-br from-emerald-500 to-teal-600 flex items-center justify-center shadow-lg">
                  <.icon name="hero-squares-2x2" class="w-8 h-8 text-white" />
                </div>
                
                <h4 class="text-lg font-bold text-gray-800 dark:text-gray-100 mb-3 text-center">
                  {gettext("Collection Categories")}
                </h4>
                
                <div class="space-y-2">
                  <%= for category <- @dashboard_stats.collection_categories do %>
                    <div class="flex justify-between items-center text-sm bg-gray-50 dark:bg-gray-700 rounded-lg px-3 py-2">
                      <span class="text-gray-700 dark:text-gray-300 font-medium">
                        {category.category}
                      </span>
                      <span class="font-bold text-emerald-600 dark:text-emerald-400">
                        {category.count}
                      </span>
                    </div>
                  <% end %>
                </div>
              </div>
            </div>
            <!-- New Books -->
            <div class="group relative overflow-hidden rounded-2xl bg-gradient-to-br from-white to-gray-50 dark:from-gray-800 dark:to-gray-900 border border-gray-200 dark:border-gray-700 shadow-lg hover:shadow-2xl transition-all duration-500 transform hover:-translate-y-2">
              <div class="absolute inset-0 bg-gradient-to-r from-amber-500/10 to-orange-500/10 opacity-0 group-hover:opacity-100 transition-opacity duration-500">
              </div>
              
              <div class="relative p-6">
                <div class="w-16 h-16 mx-auto mb-4 rounded-2xl bg-gradient-to-br from-amber-500 to-orange-600 flex items-center justify-center shadow-lg">
                  <.icon name="hero-book-open" class="w-8 h-8 text-white" />
                </div>
                
                <h4 class="text-lg font-bold text-gray-800 dark:text-gray-100 mb-3 text-center">
                  {gettext("New Additions")}
                </h4>
                
                <div class="space-y-2">
                  <%= for item <- Enum.take(@dashboard_stats.new_books, 3) do %>
                    <div class="bg-gray-50 dark:bg-gray-700 rounded-lg p-2">
                      <p class="text-sm font-medium text-gray-800 dark:text-gray-200 truncate">
                        {if item.collection && item.collection.title,
                          do: item.collection.title,
                          else: gettext("Untitled")}
                      </p>
                      
                      <p class="text-xs text-gray-500 dark:text-gray-400">
                        {Calendar.strftime(item.inserted_at, "%b %d")}
                      </p>
                    </div>
                  <% end %>
                  
                  <%= if length(@dashboard_stats.new_books) == 0 do %>
                    <p class="text-sm text-gray-500 italic text-center py-2">
                      {gettext("No new additions this week")}
                    </p>
                  <% end %>
                </div>
              </div>
            </div>
            <!-- Active Users -->
            <div class="group relative overflow-hidden rounded-2xl bg-gradient-to-br from-white to-gray-50 dark:from-gray-800 dark:to-gray-900 border border-gray-200 dark:border-gray-700 shadow-lg hover:shadow-2xl transition-all duration-500 transform hover:-translate-y-2">
              <div class="absolute inset-0 bg-gradient-to-r from-rose-500/10 to-pink-500/10 opacity-0 group-hover:opacity-100 transition-opacity duration-500">
              </div>
              
              <div class="relative p-6">
                <div class="w-16 h-16 mx-auto mb-4 rounded-2xl bg-gradient-to-br from-rose-500 to-pink-600 flex items-center justify-center shadow-lg">
                  <.icon name="hero-users" class="w-8 h-8 text-white" />
                </div>
                
                <h4 class="text-lg font-bold text-gray-800 dark:text-gray-100 mb-3 text-center">
                  {gettext("Active Users")}
                </h4>
                
                <div class="space-y-2">
                  <%= for user <- Enum.take(@dashboard_stats.most_active_users, 3) do %>
                    <div class="bg-gray-50 dark:bg-gray-700 rounded-lg p-2">
                      <div class="flex items-center gap-3">
                        <%= if user.user_image do %>
                          <img
                            src={user.user_image}
                            alt={user.fullname}
                            class="w-8 h-8 rounded-full"
                            referrerpolicy="no-referrer"
                          />
                        <% else %>
                          <div class="w-8 h-8 rounded-full bg-gray-200 dark:bg-gray-600 flex items-center justify-center">
                            <.icon name="hero-user" class="w-5 h-5 text-gray-400 dark:text-gray-500" />
                          </div>
                        <% end %>
                        
                        <div>
                          <p class="text-sm font-medium text-gray-800 dark:text-gray-200 truncate">
                            {String.slice(user.fullname, 0..25)}{if String.length(user.fullname) > 25,
                              do: "..."}
                          </p>
                          
                          <p class="text-xs text-gray-500 dark:text-gray-400">
                            {gettext("Joined")} {Calendar.strftime(user.inserted_at, "%b %d")}
                          </p>
                        </div>
                      </div>
                    </div>
                  <% end %>
                  
                  <%= if length(@dashboard_stats.most_active_users) == 0 do %>
                    <p class="text-sm text-gray-500 italic text-center py-2">
                      {gettext("No active users")}
                    </p>
                  <% end %>
                </div>
              </div>
            </div>
          </div>
          <!-- Featured Collections -->
          <div class="grid grid-cols-1 lg:grid-cols-2 gap-8">
            <!-- Favorite Books Section -->
            <div class="relative overflow-hidden rounded-3xl bg-gradient-to-br from-white to-gray-50 dark:from-gray-800 dark:to-gray-900 border border-gray-200 dark:border-gray-700 shadow-xl">
              <div class="absolute inset-0 bg-gradient-to-r from-violet-500/5 to-purple-500/5"></div>
              
              <div class="relative p-8">
                <div class="flex items-center gap-4 mb-6">
                  <div class="w-14 h-14 rounded-2xl bg-gradient-to-br from-violet-500 to-purple-600 flex items-center justify-center shadow-lg">
                    <.icon name="hero-heart" class="w-7 h-7 text-white" />
                  </div>
                  
                  <div>
                    <h4 class="text-gray-800 dark:text-gray-100 mb-1">
                      {gettext("Featured Collections")}
                    </h4>
                    
                    <p class="text-sm text-gray-600 dark:text-gray-400">
                      {gettext("Recently added to our library")}
                    </p>
                  </div>
                </div>
                
                <div class="space-y-4">
                  <%= if length(@dashboard_stats.favorite_books) > 0 do %>
                    <%= for item <- Enum.take(@dashboard_stats.favorite_books, 4) do %>
                      <div class="group flex items-start gap-4 p-4 rounded-2xl bg-white dark:bg-gray-800 border border-gray-100 dark:border-gray-700 hover:shadow-lg hover:border-violet-200 dark:hover:border-violet-800 transition-all duration-300">
                        <div class="flex-shrink-0">
                          <%= if item.collection.thumbnail && item.collection.thumbnail != "" do %>
                            <img
                              src={item.collection.thumbnail}
                              alt={
                                if item.collection && item.collection.title,
                                  do: item.collection.title,
                                  else: "Collection thumbnail"
                              }
                              class="w-16 h-16 rounded-xl object-cover shadow-md"
                            />
                          <% else %>
                            <div class="w-16 h-16 rounded-xl bg-gradient-to-br from-gray-200 to-gray-300 dark:from-gray-600 dark:to-gray-700 flex items-center justify-center shadow-md">
                              <.icon
                                name="hero-book-open"
                                class="w-8 h-8 text-gray-500 dark:text-gray-400"
                              />
                            </div>
                          <% end %>
                        </div>
                        
                        <div class="flex-1 min-w-0">
                          <h5
                            class="text-gray-800 dark:text-gray-200 truncate mb-1"
                            title={
                              if item.collection && item.collection.title,
                                do: item.collection.title,
                                else: "Untitled Collection"
                            }
                          >
                            {if item.collection && item.collection.title,
                              do: item.collection.title,
                              else: "Untitled Collection"}
                          </h5>
                          
                          <p class="text-sm text-gray-600 dark:text-gray-400 line-clamp-2 mb-3">
                            {if item.collection && item.collection.description,
                              do: item.collection.description,
                              else: "No description available"}
                          </p>
                          
                          <div class="flex items-center gap-3">
                            <span class="inline-flex items-center px-2.5 py-1 rounded-full text-xs font-medium bg-gradient-to-r from-violet-100 to-purple-100 text-violet-800 dark:from-violet-900/50 dark:to-purple-900/50 dark:text-violet-200">
                              {if item.collection && item.collection.resource_class,
                                do: item.collection.resource_class.glam_type,
                                else: ""}
                            </span>
                            <span class="text-xs text-gray-500 dark:text-gray-400">
                              {Calendar.strftime(item.inserted_at, "%B %d, %Y")}
                            </span>
                          </div>
                        </div>
                      </div>
                    <% end %>
                  <% else %>
                    <div class="text-center py-12">
                      <div class="w-20 h-20 mx-auto mb-4 rounded-2xl bg-gradient-to-br from-gray-100 to-gray-200 dark:from-gray-700 dark:to-gray-800 flex items-center justify-center">
                        <.icon
                          name="hero-book-open"
                          class="w-10 h-10 text-gray-400 dark:text-gray-500"
                        />
                      </div>
                      
                      <p class="text-gray-500 dark:text-gray-400 font-medium mb-1">
                        {gettext("No collections available yet")}
                      </p>
                      
                      <p class="text-sm text-gray-400 dark:text-gray-500">
                        {gettext("Start building your digital library")}
                      </p>
                    </div>
                  <% end %>
                </div>
                
                <div class="mt-8">
                  <.link
                    navigate="/collections"
                    class="block w-full text-center py-3 px-6 rounded-2xl bg-gradient-to-r from-violet-500 to-purple-600 text-white font-medium shadow-lg hover:shadow-xl transform hover:-translate-y-0.5 transition-all duration-300"
                  >
                    {gettext("Explore All Collections")}
                  </.link>
                </div>
              </div>
            </div>
            <!-- Quick Stats & Actions -->
            <div class="relative overflow-hidden rounded-3xl bg-gradient-to-br from-white to-gray-50 dark:from-gray-800 dark:to-gray-900 border border-gray-200 dark:border-gray-700 shadow-xl">
              <div class="absolute inset-0 bg-gradient-to-r from-emerald-500/5 to-teal-500/5"></div>
              
              <div class="relative p-8">
                <div class="flex items-center gap-4 mb-6">
                  <div class="w-14 h-14 rounded-2xl bg-gradient-to-br from-emerald-500 to-teal-600 flex items-center justify-center shadow-lg">
                    <.icon name="hero-chart-bar" class="w-7 h-7 text-white" />
                  </div>
                  
                  <div>
                    <h4 class="text-gray-800 dark:text-gray-100 mb-1">{gettext("Quick Access")}</h4>
                    
                    <p class="text-sm text-gray-600 dark:text-gray-400">
                      {gettext("Navigate the digital sanctuary")}
                    </p>
                  </div>
                </div>
                
                <div class="grid grid-cols-2 gap-4 mb-8">
                  <%= for {category, index} <- Enum.with_index(@dashboard_stats.collection_categories) do %>
                    <div class="group text-center p-4 rounded-2xl bg-white dark:bg-gray-800 border border-gray-100 dark:border-gray-700 hover:shadow-md hover:border-emerald-200 dark:hover:border-emerald-800 transition-all duration-300">
                      <div class={"w-12 h-12 rounded-2xl flex items-center justify-center mx-auto mb-3 shadow-md #{get_category_gradient_class(category.category)}"}>
                        <.icon name={get_category_icon(category.category)} class="w-6 h-6 text-white" />
                      </div>
                      
                      <p class="text-2xl font-bold text-transparent bg-clip-text bg-gradient-to-r from-emerald-600 to-teal-600 mb-1">
                        {category.count}
                      </p>
                      
                      <p class="text-xs text-gray-600 dark:text-gray-400 font-medium">
                        {category.category} {gettext("collections")}
                      </p>
                    </div>
                  <% end %>
                </div>
                
                <div class="space-y-3">
                  <.link
                    navigate="/collections"
                    class="block w-full text-center py-3 px-6 rounded-2xl bg-gradient-to-r from-emerald-500 to-teal-600 text-white font-medium shadow-lg hover:shadow-xl transform hover:-translate-y-0.5 transition-all duration-300"
                  >
                    {gettext("Browse Collections")}
                  </.link>
                  <.link
                    navigate="/search/advanced"
                    class="block w-full text-center py-3 px-6 rounded-2xl border-2 border-emerald-200 dark:border-emerald-800 text-emerald-600 dark:text-emerald-400 font-medium hover:bg-emerald-50 dark:hover:bg-emerald-900/20 transition-all duration-300"
                  >
                    {gettext("Advanced Search")}
                  </.link>
                </div>
              </div>
            </div>
          </div>
        </section>
      </section>
    </Layouts.app>
    """
  end
end
