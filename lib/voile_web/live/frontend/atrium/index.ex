defmodule VoileWeb.Frontend.Atrium.Index do
  use VoileWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    tabs = [:profile, :collections, :items]
    {:ok, assign(socket, active_tab: :profile, tabs: tabs)}
  end

  @impl true
  def handle_event("select_tab", %{"tab" => tab}, socket) do
    tab_atom =
      case tab do
        "profile" -> :profile
        "collections" -> :collections
        "items" -> :items
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
      <div class="text-center max-w-7xl mx-auto">
        <div class="max-w-7xl mx-auto py-10 sm:px-6 lg:px-8">
          <h1 class="text-3xl font-bold mb-6 text-gray-900 dark:text-gray-100">My Atrium</h1>

          <div>
            <img
              src={@current_scope.user.user_image || ~p"/images/default_avatar.jpg"}
              alt="User Avatar"
              class="w-24 h-24 rounded-full mx-auto mb-4"
            />
            <h3 class="text-xl font-semibold mb-4 text-gray-800 dark:text-gray-200">
              Hello, {@current_scope.user.username}
            </h3>
          </div>

          <p class="text-lg text-gray-700 dark:text-gray-300">
            Welcome to the Atrium! This is your central hub for managing and accessing various features of the Voile platform. From here, you can navigate to different sections, manage your profile, and explore the tools available to you.
          </p>
        </div>
      </div>

      <div class="text-center max-w-7xl mx-auto">
        <div>
          <div>
            <h5>
              Manage your profile, view your collections, and explore new items all from your Atrium.
            </h5>

            <div class="mt-4">
              <nav
                role="tablist"
                aria-label="Atrium navigation"
                class="inline-flex overflow-hidden rounded-md bg-gray-100 w-full items-center justify-around dark:bg-gray-800"
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
                    class={"w-full px-4 py-2 text-sm font-medium focus:outline-none focus:ring-2 focus:ring-offset-1 focus:ring-indigo-500 " <> (if @active_tab == tab, do: "bg-white dark:bg-gray-700 text-indigo-600 dark:text-indigo-200 " <> rounded, else: "text-gray-700 dark:text-gray-200 hover:bg-white dark:hover:bg-gray-700 " <> rounded)}
                  >
                    {label}
                  </button>
                <% end %>
              </nav>
            </div>
            <!-- Placeholder tab panels (dummy content to be replaced later) -->
            <div class="mt-6 text-left max-w-3xl mx-auto">
              <h6 class="sr-only">Atrium tab panels</h6>

              <div id="atrium-tabpanels" class="space-y-4">
                <%= if @active_tab == :profile do %>
                  <div
                    id="tab-profile"
                    class="p-4 bg-white dark:bg-gray-900 rounded-md shadow-sm border border-gray-200 dark:border-gray-800"
                  >
                    <h4 class="text-lg font-semibold mb-2">Profile (placeholder)</h4>

                    <p class="text-sm text-gray-600 dark:text-gray-300">
                      Profile tab content will be added soon. This area will show profile settings, avatar upload, and user preferences.
                    </p>
                  </div>
                <% end %>

                <%= if @active_tab == :collections do %>
                  <div
                    id="tab-collections"
                    class="p-4 bg-white dark:bg-gray-900 rounded-md shadow-sm border border-gray-200 dark:border-gray-800"
                  >
                    <h4 class="text-lg font-semibold mb-2">Collections (placeholder)</h4>

                    <p class="text-sm text-gray-600 dark:text-gray-300">
                      Collections tab content will be added soon. This area will list and manage your collections.
                    </p>
                  </div>
                <% end %>

                <%= if @active_tab == :items do %>
                  <div
                    id="tab-items"
                    class="p-4 bg-white dark:bg-gray-900 rounded-md shadow-sm border border-gray-200 dark:border-gray-800"
                  >
                    <h4 class="text-lg font-semibold mb-2">Items (placeholder)</h4>

                    <p class="text-sm text-gray-600 dark:text-gray-300">
                      Items tab content will be added soon. This area will allow browsing and filtering items.
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
