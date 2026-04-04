defmodule VoileWeb.PluginRouterLive do
  @moduledoc """
  Dynamic plugin route dispatcher.

  This LiveView resolves plugin routes dynamically based on the plugin_id
  and path segments in the URL. It checks that the plugin is active and
  renders the plugin's LiveView inside the standard dashboard layout.
  """
  use VoileWeb, :live_view_dashboard

  require Logger

  @impl true
  def mount(%{"plugin_id" => plugin_id, "path" => path_segments} = _params, _session, socket) do
    path = "/" <> Enum.join(path_segments, "/")

    with {:ok, record} <- find_plugin_record(plugin_id),
         {:ok, module} <- resolve_module(record),
         true <- Voile.PluginManager.active?(module),
         {:ok, live_view, action} <- match_route(module, path) do
      socket =
        socket
        |> assign(:plugin_record, record)
        |> assign(:plugin_module, module)
        |> assign(:plugin_live_view, live_view)
        |> assign(:plugin_action, action)
        |> assign(:plugin_path, path)
        |> assign(:current_path, "/manage/plugins/#{plugin_id}#{path}")
        |> assign(:page_title, record.name)

      {:ok, socket}
    else
      _ ->
        {:ok,
         socket
         |> put_flash(:error, gettext("Plugin not found or not active."))
         |> push_navigate(to: ~p"/manage")}
    end
  end

  @impl true
  def mount(%{"plugin_id" => plugin_id} = _params, session, socket) do
    # Handle root plugin path (no additional path segments)
    mount(%{"plugin_id" => plugin_id, "path" => []}, session, socket)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <section class="space-y-6 p-6">
      <div class="flex flex-col md:flex-row gap-4">
        <div class="w-full md:w-auto md:max-w-64">
          <.plugin_settings_sidebar
            current_path={@current_path}
            current_plugin_id={@plugin_record.plugin_id}
          />
        </div>

        <div class="flex-1 min-w-0">
          {live_render(@socket, @plugin_live_view,
            id: "plugin-#{@plugin_record.plugin_id}",
            session: %{
              "plugin_id" => @plugin_record.plugin_id,
              "plugin_path" => @plugin_path,
              "action" => to_string(@plugin_action)
            }
          )}
        </div>
      </div>
    </section>
    """
  end

  defp find_plugin_record(plugin_id) do
    case Voile.Plugins.get_plugin_by_plugin_id(plugin_id) do
      nil -> {:error, :not_found}
      record -> {:ok, record}
    end
  end

  defp resolve_module(record) do
    try do
      {:ok, String.to_existing_atom(record.module)}
    rescue
      ArgumentError -> {:error, :module_not_loaded}
    end
  end

  defp match_route(module, request_path) do
    module.routes()
    |> Enum.find_value(fn {route_path, live_view, action} ->
      if route_matches?(route_path, request_path) do
        {:ok, live_view, action}
      end
    end)
    |> case do
      nil -> {:error, :no_matching_route}
      result -> result
    end
  end

  # Simple path matching — supports static paths and `:id` params
  defp route_matches?(route_path, request_path) do
    route_parts = String.split(route_path, "/", trim: true)
    request_parts = String.split(request_path, "/", trim: true)

    if length(route_parts) == length(request_parts) do
      Enum.zip(route_parts, request_parts)
      |> Enum.all?(fn
        {":" <> _, _} ->
          true

        # param segment matches anything
        {a, b} ->
          a == b
          # static segment must match exactly
      end)
    else
      # Allow root route "/" to match empty path
      route_parts == [] and request_parts == []
    end
  end
end
