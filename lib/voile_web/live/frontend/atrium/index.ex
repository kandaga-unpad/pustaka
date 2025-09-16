defmodule VoileWeb.Frontend.Atrium.Index do
  use VoileWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    tabs = [:profile, :collections, :settings]
    {:ok, assign(socket, active_tab: :profile, tabs: tabs)}
  end

  @impl true
  def handle_event("select_tab", %{"tab" => tab}, socket) do
    tab_atom =
      case tab do
        "profile" -> :profile
        "collections" -> :collections
        "settings" -> :settings
        _ -> :profile
      end

    {:noreply, assign(socket, :active_tab, tab_atom)}
  end

  @impl true
  def handle_event("navigate_tab", %{"key" => key}, socket) do
    tabs = socket.assigns.tabs
    current = socket.assigns.active_tab
    idx = Enum.find_index(tabs, fn t -> t == current end) || 0
    len = length(tabs)

    new_idx =
      case key do
        "ArrowRight" -> rem(idx + 1, len)
        "ArrowLeft" -> rem(idx - 1 + len, len)
        "Home" -> 0
        "End" -> len - 1
        _ -> idx
      end

    {:noreply, assign(socket, :active_tab, Enum.at(tabs, new_idx))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="text-center max-w-7xl mx-auto px-5">
        <div class="max-w-4xl mx-auto py-10 sm:px-6 lg:px-8">
          <h1 class="text-3xl font-bold mb-6 voile-text-gradient">My Atrium</h1>
          
          <div>
            <img
              src={@current_scope.user.user_image || ~p"/images/default_avatar.jpg"}
              alt="User Avatar"
              class="w-24 h-24 rounded-full mx-auto mb-4"
              referrerpolicy="no-referrer"
            />
            <h3 class="text-xl font-semibold mb-4">Hello, {@current_scope.user.fullname}!</h3>
          </div>
          
          <p class="italic text-xs">
            Welcome to the Atrium! This is your central hub for managing and accessing various features of the Voile platform. From here, you can navigate to different sections, manage your profile, and explore the tools available to you.
          </p>
        </div>
      </div>
      
      <div class="text-center max-w-7xl mx-auto px-5">
        <div>
          <div>
            <h5>
              Manage your profile, view your collections, and explore new items all from your Atrium.
            </h5>
            
            <div class="mt-4">
              <nav
                role="tablist"
                aria-label="Atrium navigation"
                class="inline-flex overflow-hidden rounded-md w-full items-center justify-around"
                phx-keydown="navigate_tab"
                tabindex="0"
              >
                <%= for {tab, idx} <- Enum.with_index(@tabs) do %>
                  <% tab_str = Atom.to_string(tab) %> <% label = String.capitalize(tab_str) %> <% last_idx =
                    length(@tabs) - 1 %> <% rounded =
                    cond do
                      idx == 0 -> "rounded-l-md"
                      idx == last_idx -> "rounded-r-md"
                      true -> ""
                    end %>
                  <button
                    type="button"
                    role="tab"
                    aria-selected={@active_tab == tab}
                    phx-click="select_tab"
                    phx-value-tab={tab_str}
                    class={"w-full px-4 py-2 text-sm font-medium focus:outline-none focus:ring-2 focus:ring-offset-1 focus:ring-indigo-500 border border-brand-300 dark:border-brand-700 " <> (if @active_tab == tab, do: "bg-brand-100 dark:bg-brand-700 text-indigo-600 dark:text-indigo-200 " <> rounded, else: "dark:text-voile-muted hover:bg-voile-surface dark:hover:bg-voile-dark " <> rounded)}
                  >
                    {label}
                  </button>
                <% end %>
              </nav>
            </div>
            <!-- Placeholder tab panels (dummy content to be replaced later) -->
            <div class="mt-6 text-left max-w-7xl mx-auto">
              <h6 class="sr-only">Atrium tab panels</h6>
              
              <div id="atrium-tabpanels" class="space-y-4">
                <%= if @active_tab == :profile do %>
                  <div
                    id="tab-profile"
                    class="p-4 rounded-md shadow-sm border border-voile-light dark:border-voile-dark"
                  >
                    <h4 class="text-lg font-semibold mb-2">Profile (placeholder)</h4>
                    
                    <p class="text-sm">
                      Profile tab content will be added soon. This area will show profile settings, avatar upload, and user preferences.
                    </p>
                  </div>
                <% end %>
                
                <%= if @active_tab == :collections do %>
                  <div
                    id="tab-collections"
                    class="p-4 rounded-md shadow-sm border border-voile-light dark:border-voile-dark"
                  >
                    <h4 class="text-lg font-semibold mb-2">Collections (placeholder)</h4>
                    
                    <p class="text-sm">
                      Collections tab content will be added soon. This area will list and manage your collections.
                    </p>
                  </div>
                <% end %>
                
                <%= if @active_tab == :settings do %>
                  <div
                    id="tab-settings"
                    class="p-4 rounded-md shadow-sm border border-voile-light dark:border-voile-dark"
                  >
                    <h4 class="text-lg font-semibold mb-2">Settings (placeholder)</h4>
                    
                    <p class="text-sm">
                      Settings tab content will be added soon. This area will allow managing user preferences and application settings.
                    </p>
                  </div>
                <% end %>
              </div>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
