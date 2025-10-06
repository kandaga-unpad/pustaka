defmodule VoileWeb.VoileDashboardComponents do
  use Phoenix.Component
  use Phoenix.LiveComponent
  use Gettext, backend: VoileWeb.Gettext

  alias Phoenix.LiveView.JS
  alias VoileWeb.Layouts

  import VoileWeb.CoreComponents, only: [icon: 1, modal: 1, button: 1]
  import VoileWeb.Components.SearchBar

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
        name: "Katalog",
        url: "/manage/catalog"
      },
      %{
        name: "Sirkulasi",
        url: "/manage/circulation"
      },
      %{
        name: "Pengaturan",
        url: "/manage/settings"
      }
    ]

  def nav_bar(assigns) do
    ~H"""
    <div class="w-full bg-white dark:bg-gray-700 flex items-center my-5 p-5 rounded-lg gap-6">
      <div class="nav-bar-logo">
        <.link patch="/manage#">
          <img src="/images/v.png" class="w-24 h-full" alt="Voile Logo" />
        </.link>
      </div>
      
      <div class="w-full text-voile-primary flex gap-4">
        <.link
          patch="/manage"
          class={["default-menu", @active_nav == "/manage" && "active-menu"]}
        >
          Dashboard
        </.link>
        <%= for menu <- @list_menu do %>
          <.link
            patch={menu.url}
            class={["default-menu", @active_nav |> String.starts_with?(menu.url) && "active-menu"]}
          >
            {menu.name}
          </.link>
        <% end %>
      </div>
      
      <div class="w-full flex justify-end gap-3">
        <Layouts.theme_toggle />
        <.link
          href="/users/log_out"
          method="delete"
          class="default-menu bg-red-400 hover:bg-red-500 text-white"
        >
          <.icon name="hero-x-circle" class="h-5 w-5" /> Logout
        </.link>
        <.link href="/" class="default-menu bg-voile-primary text-voile-surface">
          Home <.icon name="hero-arrow-right-solid" class="h-3 w-3" />
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
          <h5>Halo, {@user.fullname}!</h5>
          
          <p>Data Koleksi bisa kamu cek disini</p>
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
            Collections
          </.link>
          <.link
            patch="/manage/catalog/items"
            class={[
              "dashboard-menu-btn",
              @active_menu |> String.starts_with?("/manage/catalog/items") &&
                "dashboard-menu-btn-active"
            ]}
          >
            Items
          </.link>
        </div>
      </div>
      
      <div><.icon name="hero-document-magnifying-glass" class="w-32 h-32 voile-gradient" /></div>
    </div>
    """
  end

  @doc """
  Dashboard search widget component
  """
  def dashboard_search_widget(assigns) do
    ~H"""
    <div class="bg-white dark:bg-gray-700 rounded-xl p-5 w-full">
      <div class="flex items-center gap-3 mb-4">
        <.icon name="hero-magnifying-glass" class="w-6 h-6 text-blue-600 dark:text-blue-400" />
        <h3 class="text-lg font-semibold text-gray-900 dark:text-white">Quick Search</h3>
      </div>
      
      <.search_bar
        placeholder="Search collections, items, authors..."
        show_filters={true}
        size="default"
        class="w-full"
      />
      <div class="mt-4 flex gap-2">
        <.link
          href="/search/advanced"
          class="text-sm text-blue-600 dark:text-blue-400 hover:text-blue-800 dark:hover:text-blue-300 font-medium"
        >
          Advanced Search →
        </.link>
      </div>
    </div>
    """
  end

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
        <.icon name="hero-chart-bar" class="w-6 h-6 text-green-600 dark:text-green-400" />
        <h3 class="text-lg font-semibold text-gray-900 dark:text-white">Search Statistics</h3>
      </div>
      
      <div class="space-y-4">
        <!-- Total searches today -->
        <div class="flex justify-between items-center">
          <span class="text-sm text-gray-600 dark:text-gray-300">Searches Today</span>
          <span class="text-2xl font-bold text-blue-600 dark:text-blue-400">
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
  """
  attr :current_user, :map, required: false
  attr :current_path, :string, default: nil

  def dashboard_settings_sidebar(assigns) do
    ~H"""
    <.side_bar_dashboard>
      <.link navigate="/manage/settings/">
        <h3 class="text-lg font-semibold mb-4">Settings</h3>
      </.link>
      <ul class="space-y-6">
        <li>
          <.link
            navigate="/manage/settings/user_profile"
            class={[
              "hover:underline",
              if(String.starts_with?(@current_path || "", "/manage/settings/user_profile"),
                do: "text-blue-700 dark:text-blue-400 font-semibold",
                else: "text-blue-600 dark:text-blue-200"
              )
            ]}
          >
            User Profile
          </.link>
        </li>
        
        <li>
          <.link
            navigate="/manage/settings/users"
            class={[
              "hover:underline",
              if(
                String.starts_with?(@current_path || "", "/manage/settings/users") and
                  not String.contains?(@current_path || "", "/manage/settings/user_profile"),
                do: "text-blue-700 dark:text-blue-400 font-semibold",
                else: "text-blue-600 dark:text-blue-200"
              )
            ]}
          >
            User Management
          </.link>
        </li>
        
        <li>
          <.link
            navigate="/manage/settings/roles"
            class={[
              "hover:underline",
              if(String.starts_with?(@current_path || "", "/manage/settings/roles"),
                do: "text-blue-700 dark:text-blue-400 font-semibold",
                else: "text-blue-600 dark:text-blue-200"
              )
            ]}
          >
            Role Management
          </.link>
        </li>
      </ul>
    </.side_bar_dashboard>
    """
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
end
