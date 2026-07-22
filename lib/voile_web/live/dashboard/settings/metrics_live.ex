defmodule VoileWeb.Dashboard.Settings.MetricsLive do
  use VoileWeb, :live_view_dashboard
  require Logger

  alias VoileWeb.Auth.Authorization

  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user

    if not Authorization.is_super_admin?(user) do
      {:halt, redirect(socket, to: ~p"/manage")}
    else
      if connected?(socket) do
        send(self(), :update_presence)
      end

      current_user = socket.assigns.current_scope.user

      socket =
        socket
        |> assign(:page_title, gettext("System Metrics"))
        |> assign(:is_super_admin, true)
        |> assign(:current_user, current_user)
        |> assign(:breadcrumb, [
          %{label: gettext("Manage"), path: "/manage"},
          %{label: gettext("Settings"), path: "/manage/settings"},
          %{label: gettext("Metrics"), path: nil}
        ])
        |> assign(:connection_stats, %{total: 0, authenticated: 0, unauthenticated: 0})
        |> assign(:system_metrics, get_system_metrics())

      {:ok, socket}
    end
  end

  def handle_params(_params, url, socket) do
    {:noreply, assign(socket, :current_path, URI.parse(url).path)}
  end

  def handle_info(:update_presence, socket) do
    connection_stats = VoileWeb.UserPresence.get_connection_stats()
    system_metrics = get_system_metrics()

    Process.send_after(self(), :update_presence, 5_000)

    socket =
      socket
      |> assign(:connection_stats, connection_stats)
      |> assign(:system_metrics, system_metrics)

    {:noreply, socket}
  end

  def handle_info(_message, socket) do
    {:noreply, socket}
  end

  def handle_event("refresh_stats", _params, socket) do
    connection_stats = VoileWeb.UserPresence.get_connection_stats()
    system_metrics = get_system_metrics()

    socket =
      socket
      |> assign(:connection_stats, connection_stats)
      |> assign(:system_metrics, system_metrics)

    {:noreply, socket}
  end

  defp get_system_metrics do
    %{
      memory_usage: get_memory_usage(),
      system_info: get_system_info()
    }
  end

  defp get_memory_usage do
    :erlang.memory()
  end

  defp get_system_info do
    %{
      total_processes: :erlang.system_info(:process_count),
      run_queue: :erlang.statistics(:run_queue),
      reduction_count: :erlang.statistics(:reductions),
      garbage_collection: :erlang.statistics(:garbage_collection),
      io: :erlang.statistics(:io)
    }
  end

  def render(assigns) do
    ~H"""
    <.voile_page_header
      eyebrow={gettext("System · Settings")}
      title={gettext("System metrics")}
      description={gettext("Real-time system performance and user monitoring")}
      icon="hero-chart-bar"
      tone={:brand}
    >
      <:actions>
        <.voile_button tone={:brand} variant={:outline} size={:md} phx-click="refresh_stats">
          <.icon name="hero-arrow-path" class="w-4 h-4" />
          {gettext("Refresh")}
        </.voile_button>
      </:actions>
    </.voile_page_header>

    <.voile_settings_shell
      title={gettext("Settings")}
      items={voile_settings_nav_items()}
      current_path={@current_path}
    >
      <div class="w-full flex flex-col gap-4">
        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
          <.metric_card
            title={gettext("Total Connected")}
            value={@connection_stats.total}
            icon="hero-users"
            color="blue"
          />
          <.metric_card
            title={gettext("Total Processes")}
            value={@system_metrics.system_info.total_processes}
            icon="hero-cpu-chip"
            color="green"
          />
          <.metric_card
            title={gettext("Run Queue")}
            value={@system_metrics.system_info.run_queue}
            icon="hero-arrow-path"
            color="orange"
          />
          <.metric_card
            title={gettext("Memory (MB)")}
            value={round(Keyword.get(@system_metrics.memory_usage, :total, 0) / 1_048_576)}
            icon="hero-server"
            color="purple"
          />
        </div>

        <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
          <.connection_stats_card connection_stats={@connection_stats} />
          <.system_metrics_card system_metrics={@system_metrics} />
        </div>

        <.memory_details_card memory_usage={@system_metrics.memory_usage} />
      </div>
    </.voile_settings_shell>
    """
  end

  defp metric_card(assigns) do
    ~H"""
    <div class="surface-card rounded-xl shadow p-6 border border-subtle">
      <div class="flex items-center justify-between mb-4">
        <div class={"p-3 bg-#{@color}-100 dark:bg-#{@color}-900/30 rounded-lg"}>
          <.icon name={@icon} class={"w-6 h-6 text-#{@color}-600 dark:text-#{@color}-400"} />
        </div>
      </div>
      <div class="text-2xl font-bold text-primary">{@value}</div>
      <div class="text-sm text-secondary mt-1">{@title}</div>
    </div>
    """
  end

  defp connection_stats_card(assigns) do
    ~H"""
    <div class="surface-card rounded-xl shadow p-6 border border-subtle">
      <h3 class="text-lg font-semibold text-primary mb-6 flex items-center">
        <.icon name="hero-users" class="w-5 h-5 mr-2 text-voile-info" />
        {gettext("Connection Statistics")}
      </h3>

      <div class="grid grid-cols-1 gap-4">
        <div class="bg-gradient-to-br from-blue-50 to-blue-100 dark:from-blue-900/20 dark:to-blue-800/20 rounded-xl p-5 border border-blue-200 dark:border-blue-700">
          <div class="flex items-center justify-between">
            <div>
              <p class="text-sm font-medium text-voile-info mb-1">
                {gettext("Total Connections")}
              </p>
              <p class="text-xs text-voile-info">
                {gettext("All active users")}
              </p>
            </div>
            <div class="text-right">
              <p class="text-4xl font-bold text-voile-info">
                {@connection_stats.total}
              </p>
            </div>
          </div>
        </div>

        <div class="grid grid-cols-2 gap-4">
          <div class="bg-gradient-to-br from-green-50 to-green-100 dark:from-green-900/20 dark:to-green-800/20 rounded-xl p-5 border border-green-200 dark:border-green-700">
            <div class="flex items-center justify-between mb-2">
              <p class="text-sm font-medium text-voile-success">
                {gettext("Authenticated")}
              </p>
              <div class="p-2 bg-tone-success-soft rounded-lg">
                <.icon name="hero-user" class="w-4 h-4 text-voile-success" />
              </div>
            </div>
            <p class="text-3xl font-bold text-voile-success">
              {@connection_stats.authenticated}
            </p>
            <p class="text-xs text-voile-success mt-1">
              {gettext("Logged in")}
            </p>
          </div>

          <div class="bg-gradient-to-br from-orange-50 to-orange-100 dark:from-orange-900/20 dark:to-orange-800/20 rounded-xl p-5 border border-orange-200 dark:border-orange-700">
            <div class="flex items-center justify-between mb-2">
              <p class="text-sm font-medium text-orange-700 dark:text-orange-300">
                {gettext("Unauthenticated")}
              </p>
              <div class="p-2 bg-orange-200 dark:bg-orange-900/40 rounded-lg">
                <.icon name="hero-user-group" class="w-4 h-4 text-orange-600 dark:text-orange-400" />
              </div>
            </div>
            <p class="text-3xl font-bold text-orange-600 dark:text-orange-400">
              {@connection_stats.unauthenticated}
            </p>
            <p class="text-xs text-orange-600 dark:text-orange-400 mt-1">
              {gettext("Visitors")}
            </p>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp system_metrics_card(assigns) do
    ~H"""
    <div class="surface-card rounded-xl shadow p-6 border border-subtle">
      <h3 class="text-lg font-semibold text-primary mb-4 flex items-center">
        <.icon name="hero-chart-bar" class="w-5 h-5 mr-2 text-voile-success" />
        {gettext("System Metrics")}
      </h3>
      <div class="space-y-4">
        <.metric_row
          label={gettext("Total Processes")}
          value={@system_metrics.system_info.total_processes}
        />
        <.metric_row
          label={gettext("Run Queue Length")}
          value={@system_metrics.system_info.run_queue}
        />
        <.metric_row
          label={gettext("Reductions")}
          value={format_number(elem(@system_metrics.system_info.reduction_count, 0))}
        />
        <.metric_row
          label={gettext("GC Count")}
          value={format_number(elem(@system_metrics.system_info.garbage_collection, 0))}
        />
        <.metric_row
          label={gettext("GC Words Reclaimed")}
          value={format_number(elem(@system_metrics.system_info.garbage_collection, 1))}
        />
        <.metric_row
          label={gettext("Input (bytes)")}
          value={format_number(elem(@system_metrics.system_info.io, 0))}
        />
        <.metric_row
          label={gettext("Output (bytes)")}
          value={format_number(elem(@system_metrics.system_info.io, 1))}
        />
      </div>
    </div>
    """
  end

  defp memory_details_card(assigns) do
    ~H"""
    <div class="surface-card rounded-xl shadow p-6 border border-subtle">
      <h3 class="text-lg font-semibold text-primary mb-4 flex items-center">
        <.icon name="hero-server" class="w-5 h-5 mr-2 text-voile-primary" />
        {gettext("Memory Usage Details")}
      </h3>
      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
        <.memory_detail
          label={gettext("Total")}
          value={format_bytes(Keyword.get(@memory_usage, :total, 0))}
          color="blue"
        />
        <.memory_detail
          label={gettext("Processes")}
          value={format_bytes(Keyword.get(@memory_usage, :processes, 0))}
          color="green"
        />
        <.memory_detail
          label={gettext("System")}
          value={format_bytes(Keyword.get(@memory_usage, :system, 0))}
          color="purple"
        />
        <.memory_detail
          label={gettext("Atom")}
          value={format_bytes(Keyword.get(@memory_usage, :atom, 0))}
          color="orange"
        />
        <.memory_detail
          label={gettext("Binary")}
          value={format_bytes(Keyword.get(@memory_usage, :binary, 0))}
          color="teal"
        />
        <.memory_detail
          label={gettext("Code")}
          value={format_bytes(Keyword.get(@memory_usage, :code, 0))}
          color="pink"
        />
        <.memory_detail
          label={gettext("ETS")}
          value={format_bytes(Keyword.get(@memory_usage, :ets, 0))}
          color="indigo"
        />
      </div>
    </div>
    """
  end

  defp metric_row(assigns) do
    ~H"""
    <div class="flex justify-between items-center py-2 border-b border-subtle last:border-0">
      <span class="text-sm text-secondary">{@label}</span>
      <span class="text-sm font-mono font-medium text-primary">{@value}</span>
    </div>
    """
  end

  defp memory_detail(assigns) do
    ~H"""
    <div class="bg-gray-50 dark:bg-gray-600 rounded-lg p-4">
      <div class="text-xs text-tertiary mb-1">{@label}</div>
      <div class={"text-lg font-bold text-#{@color}-600 dark:text-#{@color}-400"}>
        {@value}
      </div>
    </div>
    """
  end

  defp format_bytes(bytes) when is_integer(bytes) do
    cond do
      bytes >= 1_073_741_824 ->
        "#{Float.round(bytes / 1_073_741_824, 2)} GB"

      bytes >= 1_048_576 ->
        "#{Float.round(bytes / 1_048_576, 2)} MB"

      bytes >= 1024 ->
        "#{Float.round(bytes / 1024, 2)} KB"

      true ->
        "#{bytes} B"
    end
  end

  defp format_bytes(_), do: "N/A"

  defp format_number(number) when is_integer(number) do
    number
    |> Integer.to_string()
    |> String.graphemes()
    |> Enum.reverse()
    |> Enum.chunk_every(3)
    |> Enum.join(",")
    |> String.reverse()
  end

  defp format_number(_), do: "N/A"
end
