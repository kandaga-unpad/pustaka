defmodule VoileWeb.VoileDashboardComponents do
  use Phoenix.Component
  use Phoenix.LiveComponent
  use Gettext, backend: VoileWeb.Gettext

  alias Phoenix.LiveView.JS
  alias VoileWeb.Layouts

  import VoileWeb.CoreComponents, only: [icon: 1, modal: 1, button: 1]

  @doc """
  Navigation Bar Component for GLAM (Gallery, Library, Archive, Museum)

  ## Examples

    <.nav_bar />
  This component need :active menu and :list_menu props.
  """
  attr :active_nav, :string, default: "home"

  attr :list_menu, :list,
    default: [
      %{
        name: "Catalogs",
        url: "/manage/catalog"
      },
      %{
        name: "GLAM",
        url: "/manage/glam"
      },
      %{
        name: "Settings",
        url: "/manage/settings"
      }
    ]

  def nav_bar(assigns) do
    ~H"""
    <div class="w-full bg-white dark:bg-gray-700 flex items-center my-5 p-5 rounded-lg gap-6">
      <div class="nav-bar-logo">
        <.link patch="/manage#">
          <%= if Voile.Schema.System.get_setting_value("app_logo_url", nil) do %>
            <img
              src={Voile.Schema.System.get_setting_value("app_logo_url", nil)}
              class="h-full w-24 object-cover"
              alt="App Logo"
            />
          <% else %>
            <img src="/images/v.png" class="w-24 h-full" alt="Voile Logo" />
          <% end %>
        </.link>
      </div>

      <div class="w-full text-voile-primary flex gap-4">
        <.link
          patch="/manage"
          class={["default-menu", @active_nav == "/manage" && "active-menu"]}
        >
          {gettext("Dashboard")}
        </.link>
        <%= for menu <- @list_menu do %>
          <.link
            patch={menu.url}
            class={["default-menu", @active_nav |> String.starts_with?(menu.url) && "active-menu"]}
          >
            {Gettext.gettext(VoileWeb.Gettext, menu.name)}
          </.link>
        <% end %>
      </div>

      <div class="w-full flex justify-end gap-3">
        <Layouts.theme_toggle />
        <.link
          href="/users/log_out"
          method="delete"
          class="default-menu bg-voile-error text-white hover:bg-voile-error/80"
        >
          <.icon name="hero-x-circle" class="h-5 w-5" /> {gettext("Logout")}
        </.link>
        <.link href="/" class="default-menu bg-voile-primary text-voile-surface">
          {gettext("Home")} <.icon name="hero-arrow-right-solid" class="h-3 w-3" />
        </.link>
      </div>
    </div>
    """
  end

  @doc """
  Component for Side Bar Menu
  """
  attr :active_side, :string, default: "no value"
  slot :inner_block

  def side_bar_dashboard(assigns) do
    ~H"""
    <section class="bg-white dark:bg-gray-700 rounded-xl p-5 max-w-64 w-full h-full mr-5">
      <div class="flex flex-col gap-2">{render_slot(@inner_block)}</div>
    </section>
    """
  end

  attr :active_menu, :string, default: ""
  attr :user, :map, default: %{fullname: ""}

  def dashboard_menu_bar(assigns) do
    ~H"""
    <div class="bg-white dark:bg-gray-700 rounded-xl p-5 w-full h-full flex items-center justify-between">
      <div class="flex flex-col items-start justify-between gap-10 w-full">
        <div>
          <h5>{gettext("Hello, %{name}!", name: @user.fullname)}</h5>

          <p>{gettext("You can check your collection data here")}</p>
        </div>

        <div class="flex gap-2">
          <.link
            patch="/manage/catalog/collections"
            class={[
              "dashboard-menu-btn",
              @active_menu |> String.starts_with?("/manage/catalog/collections") &&
                "dashboard-menu-btn-active"
            ]}
          >
            {gettext("Collections")}
          </.link>
          <.link
            patch="/manage/catalog/items"
            class={[
              "dashboard-menu-btn",
              @active_menu |> String.starts_with?("/manage/catalog/items") &&
                "dashboard-menu-btn-active"
            ]}
          >
            {gettext("Items")}
          </.link>
          <.link
            patch="/manage/catalog/labels"
            class={[
              "dashboard-menu-btn",
              @active_menu |> String.starts_with?("/manage/catalog/labels") &&
                "dashboard-menu-btn-active"
            ]}
          >
            {gettext("Labels")}
          </.link>
          <.link
            navigate="/manage/catalog/asset-vault"
            class={[
              "dashboard-menu-btn",
              @active_menu |> String.starts_with?("/manage/catalog/asset-vault") &&
                "dashboard-menu-btn-active"
            ]}
          >
            {gettext("Asset Vault")}
          </.link>
        </div>
      </div>

      <div><.icon name="hero-document-magnifying-glass" class="w-32 h-32 voile-gradient" /></div>
    </div>
    """
  end

  @doc """
  Dashboard search widget component with inline results
  """
  attr :id, :string, default: "dashboard-search-widget"
  attr :search_query, :string, default: ""
  attr :search_results, :list, default: []
  attr :searching, :boolean, default: false

  def dashboard_search_widget(assigns) do
    ~H"""
    <div class="bg-white dark:bg-gray-700 rounded-xl p-5 w-full">
      <div class="flex items-center gap-3 mb-4">
        <.icon name="hero-magnifying-glass" class="w-6 h-6 text-voile-info dark:text-voile-info" />
        <h3 class="text-lg font-semibold text-gray-900 dark:text-white">{gettext("Quick Search")}</h3>
      </div>
      <!-- Debug info (remove after testing) -->
      <div class="text-xs text-gray-500 mb-2">
        Query: {@search_query} | Searching: {inspect(@searching)} | Results: {length(@search_results)}
      </div>

      <form phx-change="search" phx-submit="search" class="mb-4">
        <div class="relative">
          <input
            type="text"
            name="query"
            value={@search_query}
            placeholder={gettext("Search collections, items, authors...")}
            class="block w-full pl-10 pr-3 py-3 border border-gray-300 dark:border-gray-600 rounded-md bg-white dark:bg-gray-800 text-gray-900 dark:text-white placeholder-gray-500 dark:placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-voile-primary focus:border-voile-primary"
            phx-debounce="300"
          />
          <div class="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
            <svg
              class="h-5 w-5 text-gray-400 dark:text-gray-500"
              fill="none"
              stroke="currentColor"
              viewBox="0 0 24 24"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"
              >
              </path>
            </svg>
          </div>
        </div>
      </form>

      <%= if @searching do %>
        <div class="flex items-center justify-center py-8">
          <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-voile-info"></div>

          <span class="ml-2 text-sm text-gray-600 dark:text-gray-400">{gettext("Searching...")}</span>
        </div>
      <% else %>
        <%= if @search_query != "" do %>
          <div class="max-h-96 overflow-y-auto">
            <%= if length(@search_results) > 0 do %>
              <div class="space-y-2">
                <%= for result <- @search_results do %>
                  <.link
                    navigate={get_result_path(result)}
                    class="block p-3 rounded-lg border border-gray-200 dark:border-gray-600 hover:bg-gray-50 dark:hover:bg-gray-600 transition-colors"
                  >
                    <div class="flex items-start gap-3">
                      <div class={[
                        "flex-shrink-0 w-10 h-10 rounded-lg flex items-center justify-center",
                        get_result_bg_class(result)
                      ]}>
                        <.icon name={get_result_icon(result)} class="w-5 h-5 text-white" />
                      </div>

                      <div class="flex-1 min-w-0">
                        <h4 class="text-sm font-semibold text-gray-900 dark:text-white truncate">
                          {get_result_title(result)}
                        </h4>

                        <div class="flex items-center gap-2 mt-1">
                          <span class={[
                            "inline-flex items-center px-2 py-0.5 rounded text-xs font-medium",
                            get_result_badge_class(result)
                          ]}>
                            {get_result_type(result)}
                          </span>
                          <%= if creator_name = get_creator_name(result) do %>
                            <span class="text-xs text-gray-500 dark:text-gray-400 truncate">
                              {gettext("by %{creator}", creator: creator_name)}
                            </span>
                          <% end %>
                        </div>

                        <%= if desc = get_result_description(result) do %>
                          <p class="text-xs text-gray-600 dark:text-gray-400 mt-1 line-clamp-2">
                            {desc}
                          </p>
                        <% end %>
                      </div>
                    </div>
                  </.link>
                <% end %>
              </div>
            <% else %>
              <div class="text-center py-8">
                <.icon name="hero-magnifying-glass" class="w-12 h-12 mx-auto text-gray-400 mb-2" />
                <p class="text-sm text-gray-500 dark:text-gray-400">{gettext("No results found")}</p>

                <p class="text-xs text-gray-400 dark:text-gray-500 mt-1">
                  {gettext("Try a different search term")}
                </p>
              </div>
            <% end %>
          </div>
        <% end %>
      <% end %>

      <div class="mt-4 pt-4 border-t border-gray-200 dark:border-gray-600 flex gap-2">
        <.link
          href="/search/advanced"
          class="text-sm text-voile-info dark:text-voile-info hover:text-voile-info/80 font-medium"
        >
          Advanced Search →
        </.link>
        <%= if @search_query != "" && length(@search_results) > 0 do %>
          <.link
            href={"/search?q=#{URI.encode_www_form(@search_query)}"}
            class="text-sm text-voile-info dark:text-voile-info hover:text-voile-info/80 font-medium"
          >
            View All Results →
          </.link>
        <% end %>
      </div>
    </div>
    """
  end

  # Helper functions for search results display
  defp get_result_path(%{__struct__: Voile.Schema.Catalog.Collection, id: id}),
    do: "/manage/catalog/collections/#{id}"

  defp get_result_path(%{__struct__: Voile.Schema.Catalog.Item, id: id}),
    do: "/manage/catalog/items/#{id}"

  defp get_result_path(_), do: "#"

  defp get_result_type(%{__struct__: Voile.Schema.Catalog.Collection}), do: "Collection"
  defp get_result_type(%{__struct__: Voile.Schema.Catalog.Item}), do: "Item"
  defp get_result_type(_), do: "Unknown"

  defp get_result_icon(%{__struct__: Voile.Schema.Catalog.Collection, resource_class: rc})
       when not is_nil(rc) do
    get_glam_type_icon(rc.glam_type)
  end

  defp get_result_icon(%{__struct__: Voile.Schema.Catalog.Collection}), do: "hero-folder"
  defp get_result_icon(%{__struct__: Voile.Schema.Catalog.Item}), do: "hero-document"
  defp get_result_icon(_), do: "hero-cube"

  defp get_result_bg_class(%{__struct__: Voile.Schema.Catalog.Collection, resource_class: rc})
       when not is_nil(rc) do
    get_glam_badge_bg(rc.glam_type)
  end

  defp get_result_bg_class(%{__struct__: Voile.Schema.Catalog.Collection}),
    do: "voile-gradient"

  defp get_result_bg_class(%{__struct__: Voile.Schema.Catalog.Item}), do: "voile-gradient"

  defp get_result_bg_class(_), do: "voile-gradient"

  defp get_result_badge_class(%{__struct__: Voile.Schema.Catalog.Collection, resource_class: rc})
       when not is_nil(rc) do
    get_glam_badge_class(rc.glam_type)
  end

  defp get_result_badge_class(%{__struct__: Voile.Schema.Catalog.Collection}),
    do: "bg-voile-info/10 text-voile-info dark:bg-voile-info/30 dark:text-voile-info/80"

  defp get_result_badge_class(%{__struct__: Voile.Schema.Catalog.Item}),
    do: "bg-gray-100 text-gray-800 dark:bg-gray-900/50 dark:text-gray-200"

  defp get_result_badge_class(_),
    do: "bg-gray-100 text-gray-800 dark:bg-gray-900/50 dark:text-gray-200"

  # Add a helper to safely get creator name
  defp get_creator_name(%{mst_creator: %{creator_name: name}}) when not is_nil(name), do: name

  defp get_creator_name(%{collection: %{mst_creator: %{creator_name: name}}})
       when not is_nil(name), do: name

  defp get_creator_name(_), do: nil

  # Helper to get title from either Collection or Item
  defp get_result_title(%{__struct__: Voile.Schema.Catalog.Collection, title: title}), do: title

  defp get_result_title(%{__struct__: Voile.Schema.Catalog.Item, collection: %{title: title}}),
    do: title

  defp get_result_title(%{__struct__: Voile.Schema.Catalog.Item, item_code: code}), do: code
  defp get_result_title(_), do: "Untitled"

  # Helper to get description from either Collection or Item
  defp get_result_description(%{__struct__: Voile.Schema.Catalog.Collection, description: desc})
       when not is_nil(desc) and desc != "" do
    String.trim(desc)
  end

  defp get_result_description(%{
         __struct__: Voile.Schema.Catalog.Item,
         collection: %{description: desc}
       })
       when not is_nil(desc) and desc != "" do
    String.trim(desc)
  end

  defp get_result_description(_), do: nil

  @doc """
  Search statistics widget for dashboard
  """
  def search_stats_widget(assigns) do
    assigns =
      assign_new(assigns, :stats, fn ->
        %{
          total_searches: 0,
          popular_queries: [],
          recent_activity: []
        }
      end)

    ~H"""
    <div class="bg-white dark:bg-gray-700 rounded-xl p-5 w-full">
      <div class="flex items-center gap-3 mb-4">
        <.icon name="hero-chart-bar" class="w-6 h-6 text-voile-success dark:text-voile-success" />
        <h3 class="text-lg font-semibold text-gray-900 dark:text-white">Search Statistics</h3>
      </div>

      <div class="space-y-4">
        <!-- Total searches today -->
        <div class="flex justify-between items-center">
          <span class="text-sm text-gray-600 dark:text-gray-300">Searches Today</span>
          <span class="text-2xl font-bold text-voile-info dark:text-voile-info/60">
            {@stats.total_searches}
          </span>
        </div>
        <!-- Popular queries -->
        <div>
          <h4 class="text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">Popular Queries</h4>

          <div class="space-y-1">
            <%= for {query, count} <- Enum.take(@stats.popular_queries, 3) do %>
              <div class="flex justify-between text-xs">
                <span class="text-gray-600 dark:text-gray-400 truncate">{query}</span>
                <span class="text-gray-500 dark:text-gray-500">{count}</span>
              </div>
            <% end %>
          </div>
        </div>
        <!-- Recent activity -->
        <div>
          <h4 class="text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">Recent Activity</h4>

          <div class="space-y-1">
            <%= for activity <- Enum.take(@stats.recent_activity, 3) do %>
              <div class="text-xs text-gray-600 dark:text-gray-400">{activity}</div>
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Renders the dashboard settings sidebar with navigation links.

  ## Examples

      <.dashboard_settings_sidebar current_user={@current_scope.user} current_path={@current_path} />

      # With custom menu items
      <.dashboard_settings_sidebar
        current_path={@current_path}
        menu_items={[
          %{label: "Profile", path: "/manage/settings/user_profile"},
          %{label: "Users", path: "/manage/settings/users"},
          %{label: "System", path: "/manage/settings/system"}
        ]}
      />
  """
  attr :current_user, :map, required: false
  attr :current_path, :string, default: nil

  attr :menu_items, :list,
    default: [
      %{label: "Application Settings", path: "/manage/settings/apps", icon: "hero-cog-solid"},
      %{label: "User Profile", path: "/manage/settings/user_profile", icon: "hero-user"},
      %{label: "User Management", path: "/manage/settings/users", icon: "hero-users"},
      %{label: "Role Management", path: "/manage/settings/roles", icon: "hero-shield-check"},
      %{label: "Permission Management", path: "/manage/settings/permissions", icon: "hero-key"},
      %{label: "Nodes / Units", path: "/manage/settings/nodes", icon: "hero-building-library"},
      %{label: "Holidays", path: "/manage/settings/holidays", icon: "hero-calendar-days"},
      %{
        label: "Reservation Notifications",
        path: "/manage/settings/reservation_notifications",
        icon: "hero-bell"
      },
      %{label: "API Manager", path: "/manage/settings/api_manager", icon: "hero-code-bracket"}
    ],
    doc: """
    List of menu items. Each item should be a map with:
    - `label`: String - Display text for the menu item
    - `path`: String - URL path for navigation
    - `icon`: String (optional) - Heroicon name for the menu item
    - `exclude_paths`: List (optional) - Paths to exclude from active state matching
    """

  def dashboard_settings_sidebar(assigns) do
    ~H"""
    <.side_bar_dashboard>
      <.link navigate="/manage/settings/">
        <h3 class="text-lg font-semibold mb-4">Settings</h3>
      </.link>
      <ul class="space-y-4 text-sm">
        <%= for item <- @menu_items do %>
          <li>
            <.link
              navigate={item.path}
              class={[
                "rounded-lg flex items-center gap-2",
                if(is_menu_active?(@current_path, item),
                  do:
                    "bg-voile-primary/10 text-voile-primary font-semibold p-2 rounded-lg hover:bg-voile-primary/30",
                  else: "hover:bg-gray-100 dark:hover:bg-voile-primary/10 p-2"
                )
              ]}
            >
              <%= if Map.get(item, :icon) do %>
                <.icon name={item.icon} class="w-5 h-5" />
              <% end %>
              {item.label}
            </.link>
          </li>
        <% end %>
      </ul>
    </.side_bar_dashboard>
    """
  end

  # Helper function to determine if a menu item is active
  defp is_menu_active?(nil, _item), do: false

  defp is_menu_active?(current_path, item) do
    path = item.path
    exclude_paths = Map.get(item, :exclude_paths, [])

    # Check if current path starts with the menu item path
    is_active = String.starts_with?(current_path, path)

    # Check if current path matches any excluded paths
    is_excluded =
      Enum.any?(exclude_paths, fn excluded ->
        String.starts_with?(current_path, excluded)
      end)

    # Active only if path matches and not in excluded paths
    is_active and not is_excluded
  end

  @doc """
  Renders a collection modal.

  ## Examples

      <.collection_modal id="confirm-modal">
        This is a collection modal.
      </.collection_modal>

  JS commands may be passed to the `:on_cancel` to configure
  the closing/cancel event, for example:

      <.collection_modal id="confirm" on_cancel={JS.navigate(~p"/posts")}>
        This is another collection modal.
      </.collection_modal>

  """
  attr :id, :string, required: true
  attr :show, :boolean, default: false
  attr :on_cancel, JS, default: %JS{}
  slot :inner_block, required: true

  def collection_modal(assigns) do
    ~H"""
    <div
      id={@id}
      phx-mounted={@show && show_collection_modal(@id)}
      phx-remove={hide_collection_modal(@id)}
      data-cancel={JS.exec(@on_cancel, "phx-remove")}
      class="relative z-50 hidden"
    >
      <div
        id={"#{@id}-bg"}
        class="bg-zinc-50/90 dark:bg-gray-700 fixed inset-0 transition-opacity"
        aria-hidden="true"
      />
      <div
        class="fixed inset-0 overflow-y-auto"
        aria-labelledby={"#{@id}-title"}
        aria-describedby={"#{@id}-description"}
        role="dialog"
        aria-modal="true"
        tabindex="0"
      >
        <div class="flex w-full h-full items-center justify-center">
          <div class="w-full h-full p-1">
            <.focus_wrap
              id={"#{@id}-container"}
              phx-window-keydown={JS.exec("data-cancel", to: "##{@id}")}
              phx-key="escape"
              phx-click-away={JS.exec("data-cancel", to: "##{@id}")}
              class="shadow-zinc-700/10 min-h-full ring-zinc-700/10 relative hidden rounded-2xl bg-white dark:bg-gray-700 p-14 shadow-lg ring-1 transition"
            >
              <div class="absolute top-6 right-5">
                <button
                  phx-click={JS.exec("data-cancel", to: "##{@id}")}
                  type="button"
                  class="-m-3 flex-none p-3 opacity-40 hover:opacity-60"
                  aria-label={gettext("close")}
                >
                  <.icon name="hero-x-mark-solid" class="h-5 w-5" />
                </button>
              </div>

              <div id={"#{@id}-content"}>{render_slot(@inner_block)}</div>
            </.focus_wrap>
          </div>
        </div>
      </div>
    </div>
    """
  end

  attr :id, :string, required: true

  def delete_modal(assigns) do
    ~H"""
    <.modal id={@id}>
      <div class="flex flex-col gap-2">
        <h3 class="text-lg font-semibold">Delete Confirmation</h3>

        <p>Are you sure you want to delete this item?</p>
      </div>

      <div class="flex justify-end gap-2 mt-4">
        <.button phx-click={JS.exec("data-cancel", to: "#delete-modal")}>Cancel</.button>
        <.button phx-click={JS.exec("data-confirm", to: "#delete-modal")}>Delete</.button>
      </div>
    </.modal>
    """
  end

  attr :params, :map, default: %{}
  attr :page, :integer, required: true
  attr :total_pages, :integer, required: true
  attr :event, :string, default: "paginate"
  attr :path, :string, default: nil

  def pagination(assigns) do
    ~H"""
    <nav class="pagination">
      <%= if @page > 1 do %>
        <%= if @path do %>
          <.link patch={"#{@path}?#{build_query_string(assigns, @page - 1)}"} class="primary-btn">
            Prev
          </.link>
        <% else %>
          <.button phx-click={@event} {build_phx_values(assigns, @page - 1)}>Prev</.button>
        <% end %>
      <% else %>
        <.button class="disabled-btn" disabled>Prev</.button>
      <% end %>

      <%= for p <- pagination_range(@page, @total_pages) do %>
        <%= if is_integer(p) do %>
          <%= if p == @page do %>
            <button class="active-pagination" disabled>{p}</button>
          <% else %>
            <%= if @path do %>
              <.link patch={"#{@path}?#{build_query_string(assigns, p)}"} class="pagination-btn">
                {p}
              </.link>
            <% else %>
              <button class="pagination-btn" phx-click={@event} {build_phx_values(assigns, p)}>
                {p}
              </button>
            <% end %>
          <% end %>
        <% else %>
          <button class="disabled-btn" disabled>{p}</button>
        <% end %>
      <% end %>

      <%= if @page < @total_pages do %>
        <%= if @path do %>
          <.link patch={"#{@path}?#{build_query_string(assigns, @page + 1)}"} class="primary-btn">
            Next
          </.link>
        <% else %>
          <.button phx-click={@event} {build_phx_values(assigns, @page + 1)}>Next</.button>
        <% end %>
      <% else %>
        <.button class="disabled-btn" disabled>Next</.button>
      <% end %>
    </nav>
    """
  end

  defp pagination_range(_current_page, total_pages) when total_pages <= 0, do: []

  defp pagination_range(current_page, total_pages) do
    range = 1..total_pages

    cond do
      total_pages <= 5 ->
        Enum.to_list(range)

      current_page <= 3 ->
        Enum.to_list(1..4) ++ ["..."] ++ [total_pages]

      current_page >= total_pages - 2 ->
        [1] ++ ["..."] ++ Enum.to_list((total_pages - 3)..total_pages)

      true ->
        [1] ++
          ["..."] ++
          Enum.to_list((current_page - 1)..(current_page + 1)) ++ ["..."] ++ [total_pages]
    end
  end

  defp build_query_string(assigns, new_page) do
    assigns.params
    |> Map.merge(%{"page" => new_page})
    |> URI.encode_query()
  end

  defp build_phx_values(assigns, new_page) do
    params = Map.merge(assigns.params, %{"page" => new_page})

    Enum.reduce(params, %{}, fn {key, value}, acc ->
      key_str = "phx-value-#{key}"
      Map.put(acc, key_str, value)
    end)
  end

  def collection_show(js \\ %JS{}, selector) do
    JS.show(js,
      to: selector,
      time: 300,
      transition:
        {"transition-all transform ease-out duration-300",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95",
         "opacity-100 translate-y-0 sm:scale-100"}
    )
  end

  def collection_hide(js \\ %JS{}, selector) do
    JS.hide(js,
      to: selector,
      time: 200,
      transition:
        {"transition-all transform ease-in duration-200",
         "opacity-100 translate-y-0 sm:scale-100",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95"}
    )
  end

  def show_collection_modal(js \\ %JS{}, id) when is_binary(id) do
    js
    |> JS.show(to: "##{id}")
    |> JS.show(
      to: "##{id}-bg",
      time: 300,
      transition: {"transition-all transform ease-out duration-300", "opacity-0", "opacity-100"}
    )
    |> collection_show("##{id}-container")
    |> JS.add_class("overflow-hidden", to: "body")
    |> JS.focus_first(to: "##{id}-content")
  end

  def hide_collection_modal(js \\ %JS{}, id) do
    js
    |> JS.hide(
      to: "##{id}-bg",
      transition: {"transition-all transform ease-in duration-200", "opacity-100", "opacity-0"}
    )
    |> collection_hide("##{id}-container")
    |> JS.hide(to: "##{id}", transition: {"block", "block", "hidden"})
    |> JS.remove_class("overflow-hidden", to: "body")
    |> JS.pop_focus()
  end

  @doc """
  GLAM Navigation Cards - Beautiful cards for each GLAM type with statistics
  """
  attr :glam_stats, :map, required: true

  def glam_navigation_cards(assigns) do
    ~H"""
    <div class="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-4 gap-6">
      <.glam_type_card
        type="gallery"
        title="Gallery"
        description="Visual arts & exhibitions"
        icon="hero-photo"
        color="pink"
        count={@glam_stats.gallery.count}
        percentage={@glam_stats.gallery.percentage}
        link="/manage/glam/gallery"
      />
      <.glam_type_card
        type="library"
        title="Library"
        description="Books & publications"
        icon="hero-book-open"
        color="blue"
        count={@glam_stats.library.count}
        percentage={@glam_stats.library.percentage}
        link="/manage/glam/library"
      />
      <.glam_type_card
        type="archive"
        title="Archive"
        description="Historical documents"
        icon="hero-archive-box"
        color="amber"
        count={@glam_stats.archive.count}
        percentage={@glam_stats.archive.percentage}
        link="/manage/glam/archive"
      />
      <.glam_type_card
        type="museum"
        title="Museum"
        description="Artifacts & objects"
        icon="hero-building-library"
        color="purple"
        count={@glam_stats.museum.count}
        percentage={@glam_stats.museum.percentage}
        link="/manage/glam/museum"
      />
    </div>
    """
  end

  @doc """
  Individual GLAM type card with statistics
  """
  attr :type, :string, required: true
  attr :title, :string, required: true
  attr :description, :string, required: true
  attr :icon, :string, required: true
  attr :color, :string, required: true
  attr :count, :integer, required: true
  attr :percentage, :integer, default: 0
  attr :link, :string, required: true

  def glam_type_card(assigns) do
    ~H"""
    <.link
      navigate={@link}
      class={[
        "group relative overflow-hidden rounded-xl p-6 shadow-lg hover:shadow-2xl transition-all duration-300 transform hover:-translate-y-1",
        get_glam_card_gradient(@color)
      ]}
    >
      <div class="relative z-10">
        <div class="flex items-center justify-between mb-4">
          <div class={["p-3 rounded-lg", get_glam_icon_bg(@color)]}>
            <.icon name={@icon} class="w-8 h-8 text-white" />
          </div>

          <div class="text-right">
            <div class="text-3xl font-bold text-white">{@count}</div>

            <div class="text-xs text-white/80">collections</div>
          </div>
        </div>

        <h3 class="text-xl font-bold text-white mb-1">{@title}</h3>

        <p class="text-white/90 text-sm mb-3">{@description}</p>

        <div class="flex items-center justify-between">
          <div class="flex items-center gap-2">
            <div class="text-xs text-white/80">{@percentage}% of total</div>
          </div>

          <.icon
            name="hero-arrow-right"
            class="w-5 h-5 text-white transform group-hover:translate-x-1 transition-transform"
          />
        </div>
      </div>
      <%!-- Decorative background pattern --%>
      <div class="absolute top-0 right-0 w-32 h-32 opacity-10">
        <.icon name={@icon} class="w-full h-full text-white" />
      </div>
    </.link>
    """
  end

  @doc """
  Statistics card component
  """
  attr :title, :string, required: true
  attr :value, :integer, required: true
  attr :icon, :string, required: true
  attr :color, :string, default: "blue"
  attr :trend, :string, default: nil

  def stat_card(assigns) do
    assigns = assign(assigns, :icon_color_class, get_stat_icon_color(assigns.color))

    ~H"""
    <div class="bg-white dark:bg-gray-700 rounded-xl p-6 shadow hover:shadow-lg transition-shadow">
      <div class="flex items-center justify-between mb-4">
        <div class={["p-3 rounded-lg", get_stat_icon_bg(@color)]}>
          <.icon name={@icon} class={"w-6 h-6 #{@icon_color_class}"} />
        </div>

        <%= if @trend do %>
          <span class="text-xs font-semibold text-green-600 dark:text-green-400">{@trend}</span>
        <% end %>
      </div>

      <h3 class="text-sm font-medium text-gray-600 dark:text-gray-400 mb-1">{@title}</h3>

      <p class="text-3xl font-bold text-gray-900 dark:text-white">{@value}</p>
    </div>
    """
  end

  @doc """
  Recent collection item component
  """
  attr :collection, :map, required: true

  def recent_collection_item(assigns) do
    ~H"""
    <.link
      navigate={"/manage/catalog/collections/#{@collection.id}"}
      class="flex items-center gap-4 p-4 rounded-lg border border-gray-200 dark:border-gray-600 hover:bg-gray-50 dark:hover:bg-gray-600 transition-colors"
    >
      <div class={[
        "flex-shrink-0 w-12 h-12 rounded-lg flex items-center justify-center",
        get_glam_badge_bg(@collection.resource_class.glam_type)
      ]}>
        <.icon
          name={get_glam_type_icon(@collection.resource_class.glam_type)}
          class="w-6 h-6 text-white"
        />
      </div>

      <div class="flex-1 min-w-0">
        <h4 class="text-sm font-semibold text-gray-900 dark:text-white truncate">
          {@collection.title}
        </h4>

        <div class="flex items-center gap-2 mt-1">
          <span class={[
            "inline-flex items-center px-2 py-0.5 rounded text-xs font-medium",
            get_glam_badge_class(@collection.resource_class.glam_type)
          ]}>
            {@collection.resource_class.glam_type}
          </span>
          <%= if @collection.mst_creator do %>
            <span class="text-xs text-gray-500 dark:text-gray-400">
              by {@collection.mst_creator.creator_name}
            </span>
          <% end %>
        </div>
      </div>
      <.icon name="hero-chevron-right" class="w-5 h-5 text-gray-400" />
    </.link>
    """
  end

  # Helper functions for styling

  defp get_glam_card_gradient("pink"),
    do: "bg-gradient-to-br from-pink-500 to-rose-600 dark:from-pink-600 dark:to-rose-700"

  defp get_glam_card_gradient("blue"),
    do: "bg-gradient-to-br from-blue-500 to-indigo-600 dark:from-blue-600 dark:to-indigo-700"

  defp get_glam_card_gradient("amber"),
    do: "bg-gradient-to-br from-amber-500 to-orange-600 dark:from-amber-600 dark:to-orange-700"

  defp get_glam_card_gradient("purple"),
    do: "museum-gradient"

  defp get_glam_card_gradient(_), do: "bg-gradient-to-br from-gray-500 to-gray-600"

  defp get_glam_icon_bg("pink"), do: "bg-voile-accent/20"
  defp get_glam_icon_bg("blue"), do: "bg-voile-info/20"
  defp get_glam_icon_bg("amber"), do: "bg-voile-warning/20"
  defp get_glam_icon_bg("purple"), do: "bg-voile-primary/20"
  defp get_glam_icon_bg(_), do: "bg-gray-600/20"

  defp get_stat_icon_bg("blue"), do: "bg-voile-info/10 dark:bg-voile-info/30"
  defp get_stat_icon_bg("green"), do: "bg-voile-success/10 dark:bg-voile-success/30"
  defp get_stat_icon_bg("purple"), do: "bg-voile-primary/10 dark:bg-voile-primary/30"
  defp get_stat_icon_bg("orange"), do: "bg-voile-warning/10 dark:bg-voile-warning/30"
  defp get_stat_icon_bg(_), do: "bg-gray-100 dark:bg-gray-900/30"

  defp get_stat_icon_color("blue"), do: "text-voile-info dark:text-voile-info"
  defp get_stat_icon_color("green"), do: "text-voile-success dark:text-voile-success"
  defp get_stat_icon_color("purple"), do: "text-voile-primary dark:text-voile-primary"
  defp get_stat_icon_color("orange"), do: "text-voile-warning dark:text-voile-warning"
  defp get_stat_icon_color(_), do: "text-gray-600 dark:text-gray-400"

  defp get_glam_type_icon("Gallery"), do: "hero-photo"
  defp get_glam_type_icon("Library"), do: "hero-book-open"
  defp get_glam_type_icon("Archive"), do: "hero-archive-box"
  defp get_glam_type_icon("Museum"), do: "hero-building-library"
  defp get_glam_type_icon(_), do: "hero-cube"

  defp get_glam_badge_class("Gallery"),
    do: "bg-voile-accent/10 text-voile-accent dark:bg-voile-accent/30 dark:text-voile-accent"

  defp get_glam_badge_class("Library"),
    do: "bg-voile-info/10 text-voile-info dark:bg-voile-info/30 dark:text-voile-info"

  defp get_glam_badge_class("Archive"),
    do: "bg-voile-warning/10 text-voile-warning dark:bg-voile-warning/30 dark:text-voile-warning"

  defp get_glam_badge_class("Museum"),
    do: "bg-voile-primary/10 text-voile-primary dark:bg-voile-primary/30 dark:text-voile-primary"

  defp get_glam_badge_class(_),
    do: "bg-gray-100 text-gray-800 dark:bg-gray-900/50 dark:text-gray-200"

  defp get_glam_badge_bg("Gallery"), do: "voile-gradient"
  defp get_glam_badge_bg("Library"), do: "voile-gradient"
  defp get_glam_badge_bg("Archive"), do: "voile-gradient"
  defp get_glam_badge_bg("Museum"), do: "museum-gradient"
  defp get_glam_badge_bg(_), do: "voile-gradient"
end
