defmodule VoileWeb.Dashboard.Plugins.Index do
  @moduledoc """
  Plugin management admin page.

  Lists all installed plugins and provides controls for:
  - Installing new plugins
  - Activating/deactivating plugins
  - Uninstalling plugins
  - Accessing plugin settings
  """
  use VoileWeb, :live_view_dashboard

  alias Voile.Plugins

  @impl true
  def mount(_params, _session, socket) do
    plugins = Plugins.list_plugins()
    available = Voile.PluginManager.discover_available()

    {:ok,
     socket
     |> assign(:plugins, plugins)
     |> assign(:available_plugins, available)
     |> assign(:page_title, gettext("Plugin Management"))
     |> assign(:current_path, "/manage/plugins")}
  end

  @impl true
  def handle_event("install", %{"module" => module_str}, socket) do
    case Voile.PluginManager.install(module_str) do
      :ok ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Plugin installed successfully."))
         |> assign(:plugins, Plugins.list_plugins())
         |> assign(:available_plugins, Voile.PluginManager.discover_available())}

      {:error, reason} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           gettext("Failed to install: %{reason}", reason: inspect(reason))
         )}
    end
  end

  @impl true
  def handle_event("activate", %{"module" => module_str}, socket) do
    case Voile.PluginManager.activate(module_str) do
      :ok ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Plugin activated successfully."))
         |> assign(:plugins, Plugins.list_plugins())}

      {:error, reason} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           gettext("Failed to activate: %{reason}", reason: inspect(reason))
         )}
    end
  end

  @impl true
  def handle_event("deactivate", %{"module" => module_str}, socket) do
    case Voile.PluginManager.deactivate(module_str) do
      :ok ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Plugin deactivated successfully."))
         |> assign(:plugins, Plugins.list_plugins())}

      {:error, reason} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           gettext("Failed to deactivate: %{reason}", reason: inspect(reason))
         )}
    end
  end

  @impl true
  def handle_event(
        "uninstall",
        %{"module" => module_str, "remove_data" => remove_data_str},
        socket
      ) do
    remove_data = remove_data_str == "true"

    case Voile.PluginManager.uninstall(module_str, remove_data: remove_data) do
      :ok ->
        message =
          if remove_data do
            gettext("Plugin uninstalled and data removed.")
          else
            gettext("Plugin uninstalled. Data preserved.")
          end

        {:noreply,
         socket
         |> put_flash(:info, message)
         |> assign(:plugins, Plugins.list_plugins())
         |> assign(:available_plugins, Voile.PluginManager.discover_available())}

      {:error, reason} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           gettext("Failed to uninstall: %{reason}", reason: inspect(reason))
         )}
    end
  end

  @impl true
  def handle_event("update", %{"module" => module_str}, socket) do
    case Voile.PluginManager.update(module_str) do
      :ok ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Plugin updated successfully."))
         |> assign(:plugins, Plugins.list_plugins())}

      {:error, :same_version} ->
        {:noreply, put_flash(socket, :info, gettext("Plugin is already at the latest version."))}

      {:error, reason} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           gettext("Failed to update: %{reason}", reason: inspect(reason))
         )}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <section class="space-y-6 p-6">
      <div class="flex flex-col md:flex-row gap-4">
        <div class="w-full md:w-auto md:max-w-64">
          <.dashboard_settings_sidebar
            current_user={@current_scope.user}
            current_path={@current_path}
          />
        </div>

        <div class="space-y-6 flex-1">
          <div class="flex items-center justify-between">
            <div>
              <h1 class="text-3xl font-bold text-gray-900 dark:text-white">
                {gettext("Plugin Management")}
              </h1>
              <p class="text-gray-600 dark:text-gray-400 mt-1">
                {gettext("Manage installed plugins and their settings")}
              </p>
            </div>
          </div>

          <%!-- Available (not yet installed) plugins discovered in the VM --%>
          <%= if @available_plugins != [] do %>
            <div class="bg-blue-50 dark:bg-blue-900/20 border border-blue-200 dark:border-blue-700 rounded-lg overflow-hidden">
              <div class="px-6 py-4 border-b border-blue-200 dark:border-blue-700">
                <h2 class="text-base font-semibold text-blue-900 dark:text-blue-200">
                  {gettext("Available Plugins")}
                </h2>
                <p class="text-sm text-blue-700 dark:text-blue-400 mt-0.5">
                  {gettext("These plugins are loaded but not yet installed.")}
                </p>
              </div>
              <div class="divide-y divide-blue-100 dark:divide-blue-800">
                <%= for avail <- @available_plugins do %>
                  <div class="p-5 flex items-center justify-between">
                    <div>
                      <div class="flex items-center gap-2">
                        <span class="font-semibold text-gray-900 dark:text-white">{avail.name}</span>
                        <span class="text-xs text-gray-500 dark:text-gray-400">v{avail.version}</span>
                        <span class="px-2 py-0.5 text-xs rounded-full bg-blue-100 text-blue-800 dark:bg-blue-900/50 dark:text-blue-300">
                          {gettext("NOT INSTALLED")}
                        </span>
                      </div>
                      <p class="text-sm text-gray-600 dark:text-gray-400 mt-0.5">
                        {avail.description}
                      </p>
                      <p class="text-xs text-gray-400 mt-0.5">
                        {gettext("By: %{author}", author: avail.author)}
                      </p>
                    </div>
                    <button
                      phx-click="install"
                      phx-value-module={avail.module}
                      data-confirm={
                        gettext("Install %{name}? This will run its database migrations.",
                          name: avail.name
                        )
                      }
                      class="ml-4 px-4 py-2 text-sm font-medium text-white bg-blue-600 rounded-lg hover:bg-blue-700"
                    >
                      {gettext("Install")}
                    </button>
                  </div>
                <% end %>
              </div>
            </div>
          <% end %>

          <div class="bg-white dark:bg-gray-800 shadow rounded-lg overflow-hidden">
            <div class="divide-y divide-gray-200 dark:divide-gray-700">
              <%= for plugin <- @plugins do %>
                <div class="p-6">
                  <div class="flex items-start justify-between">
                    <div class="flex-1">
                      <div class="flex items-center gap-3">
                        <h3 class="text-lg font-semibold text-gray-900 dark:text-white">
                          {plugin.name}
                        </h3>
                        <span class={[
                          "px-2 py-1 text-xs font-medium rounded-full",
                          status_color(plugin.status)
                        ]}>
                          {String.upcase(to_string(plugin.status))}
                        </span>
                        <span class="text-sm text-gray-500 dark:text-gray-400">
                          v{plugin.version}
                        </span>
                      </div>
                      <p class="text-gray-600 dark:text-gray-400 mt-1">
                        {plugin.description}
                      </p>
                      <div class="flex items-center gap-4 mt-2 text-sm text-gray-500 dark:text-gray-400">
                        <span>{gettext("By: %{author}", author: plugin.author)}</span>
                        <span>{gettext("ID: %{id}", id: plugin.plugin_id)}</span>
                        <span class={[
                          plugin.license_type == "premium" && "text-amber-600 dark:text-amber-400"
                        ]}>
                          {plugin.license_type}
                        </span>
                      </div>
                      <%= if plugin.error_message do %>
                        <div class="mt-2 p-2 bg-red-50 dark:bg-red-900/20 rounded text-sm text-red-600 dark:text-red-400">
                          {plugin.error_message}
                        </div>
                      <% end %>
                    </div>

                    <div class="flex items-center gap-2 ml-4">
                      <%= if plugin.status == :active do %>
                        <.link
                          navigate={~p"/manage/plugins/#{plugin.plugin_id}/settings"}
                          class="px-3 py-2 text-sm font-medium text-gray-700 dark:text-gray-300 bg-gray-100 dark:bg-gray-700 rounded-lg hover:bg-gray-200 dark:hover:bg-gray-600"
                        >
                          {gettext("Settings")}
                        </.link>
                        <button
                          phx-click="deactivate"
                          phx-value-module={plugin.module}
                          class="px-3 py-2 text-sm font-medium text-amber-700 dark:text-amber-300 bg-amber-100 dark:bg-amber-900/30 rounded-lg hover:bg-amber-200 dark:hover:bg-amber-900/50"
                        >
                          {gettext("Deactivate")}
                        </button>
                      <% end %>

                      <%= if plugin.status == :installed do %>
                        <button
                          phx-click="activate"
                          phx-value-module={plugin.module}
                          class="px-3 py-2 text-sm font-medium text-green-700 dark:text-green-300 bg-green-100 dark:bg-green-900/30 rounded-lg hover:bg-green-200 dark:hover:bg-green-900/50"
                        >
                          {gettext("Activate")}
                        </button>
                      <% end %>

                      <%= if plugin.status == :inactive do %>
                        <button
                          phx-click="activate"
                          phx-value-module={plugin.module}
                          class="px-3 py-2 text-sm font-medium text-green-700 dark:text-green-300 bg-green-100 dark:bg-green-900/30 rounded-lg hover:bg-green-200 dark:hover:bg-green-900/50"
                        >
                          {gettext("Reactivate")}
                        </button>
                      <% end %>

                      <%= if plugin.status in [:installed, :inactive, :error] do %>
                        <button
                          phx-click="uninstall"
                          phx-value-module={plugin.module}
                          phx-value-remove_data="false"
                          data-confirm={
                            gettext(
                              "Are you sure you want to uninstall this plugin? Data will be preserved."
                            )
                          }
                          class="px-3 py-2 text-sm font-medium text-red-700 dark:text-red-300 bg-red-100 dark:bg-red-900/30 rounded-lg hover:bg-red-200 dark:hover:bg-red-900/50"
                        >
                          {gettext("Uninstall")}
                        </button>
                      <% end %>
                    </div>
                  </div>
                </div>
              <% end %>

              <%= if @plugins == [] do %>
                <div class="p-12 text-center">
                  <div class="text-gray-400 dark:text-gray-500 mb-4">
                    <.icon name="hero-puzzle-piece" class="w-16 h-16 mx-auto" />
                  </div>
                  <h3 class="text-lg font-medium text-gray-900 dark:text-white">
                    {gettext("No plugins installed")}
                  </h3>
                  <p class="text-gray-500 dark:text-gray-400 mt-2">
                    {gettext("Add plugins to your mix.exs dependencies to get started.")}
                  </p>
                </div>
              <% end %>
            </div>
          </div>
        </div>
      </div>
    </section>
    """
  end

  defp status_color(:active),
    do: "bg-green-100 text-green-800 dark:bg-green-900/30 dark:text-green-400"

  defp status_color(:installed),
    do: "bg-blue-100 text-blue-800 dark:bg-blue-900/30 dark:text-blue-400"

  defp status_color(:inactive),
    do: "bg-gray-100 text-gray-800 dark:bg-gray-700 dark:text-gray-400"

  defp status_color(:error), do: "bg-red-100 text-red-800 dark:bg-red-900/30 dark:text-red-400"

  defp status_color(:uninstalled),
    do: "bg-gray-100 text-gray-500 dark:bg-gray-800 dark:text-gray-500"

  defp status_color(_), do: "bg-gray-100 text-gray-800 dark:bg-gray-700 dark:text-gray-400"
end
