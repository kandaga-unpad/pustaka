defmodule VoileWeb.Dashboard.Settings.SettingLive do
  use VoileWeb, :live_view_dashboard

  defp format_uptime(seconds) do
    days = div(seconds, 86400)
    hours = div(rem(seconds, 86400), 3600)
    minutes = div(rem(seconds, 3600), 60)

    cond do
      days > 0 -> "#{days}d #{hours}h #{minutes}m"
      hours > 0 -> "#{hours}h #{minutes}m"
      true -> "#{minutes}m"
    end
  end

  defp format_number(number) when is_integer(number) do
    number
    |> Integer.to_string()
    |> String.graphemes()
    |> Enum.reverse()
    |> Enum.chunk_every(3)
    |> Enum.join(",")
    |> String.reverse()
  end

  def mount(_params, _session, socket) do
    handle_mount_errors do
      # Check permission - if unauthorized, error handling is automatic
      authorize!(socket, "system.settings")

      current_user = socket.assigns.current_scope.user

      # Gather system information
      system_info = get_system_info()

      socket =
        socket
        |> assign(:current_user, current_user)
        |> assign(:system_info, system_info)
        |> assign(:is_super_admin, VoileWeb.Auth.Authorization.is_super_admin?(current_user))
        |> assign(:breadcrumb, [
          %{label: gettext("Manage"), path: "/manage"},
          %{label: gettext("Settings"), path: nil}
        ])

      {:ok, socket}
    end
  end

  defp get_system_info do
    %{
      elixir_version: System.version(),
      otp_version: System.otp_release(),
      phoenix_version: Application.spec(:phoenix, :vsn) |> to_string(),
      phoenix_liveview_version: Application.spec(:phoenix_live_view, :vsn) |> to_string(),
      ecto_version: Application.spec(:ecto, :vsn) |> to_string(),
      postgres_version: get_postgres_version(),
      storage_mode: get_storage_mode(),
      node_name: node(),
      system_architecture: :erlang.system_info(:system_architecture) |> to_string(),
      schedulers: :erlang.system_info(:schedulers),
      schedulers_online: :erlang.system_info(:schedulers_online),
      process_count: :erlang.system_info(:process_count),
      process_limit: :erlang.system_info(:process_limit),
      uptime: :erlang.statistics(:wall_clock) |> elem(0) |> div(1000),
      environment: Application.get_env(:voile, :environment)
    }
  end

  defp get_postgres_version do
    try do
      case Ecto.Adapters.SQL.query(Voile.Repo, "SELECT version()") do
        {:ok, %{rows: [[version]]}} ->
          version
          |> String.split(" ")
          |> Enum.at(1, "Unknown")

        _ ->
          "Unknown"
      end
    rescue
      _ -> "Unavailable"
    end
  end

  defp get_storage_mode do
    case System.get_env("VOILE_STORAGE_ADAPTER") do
      "s3" ->
        "S3"

      "local" ->
        "Local"

      nil ->
        # Check if S3 credentials are configured
        if System.get_env("VOILE_S3_ACCESS_KEY_ID") &&
             System.get_env("VOILE_S3_SECRET_ACCESS_KEY") do
          "S3 (Auto)"
        else
          configured = Application.get_env(:voile, :storage_adapter, Client.Storage.Local)

          case configured do
            Client.Storage.S3 -> "S3"
            Client.Storage.Local -> "Local"
            _ -> "Unknown"
          end
        end

      _ ->
        "Custom"
    end
  end

  def render(assigns) do
    ~H"""
    <.voile_page_header
      eyebrow={gettext("System · Settings")}
      title={gettext("System Settings")}
      description={gettext("Configure and manage your GLAM system")}
      icon="hero-cog-6-tooth"
      tone={:brand}
    />

    <.voile_settings_shell
      title={gettext("Settings")}
      items={voile_settings_nav_items()}
      current_path={@current_path}
    >
      <div class="space-y-6">
        <!-- Welcome Section -->
        <div class="bg-gradient-to-r from-voile-primary/10 to-voile-primary/5 dark:from-voile-primary/20 dark:to-voile-primary/10 p-6 rounded-lg border border-voile-primary/20">
          <div class="flex items-start gap-4">
            <div class="p-3 bg-voile-primary/20 rounded-full">
              <.icon name="hero-cog-6-tooth" class="w-8 h-8 text-voile-primary" />
            </div>
            <div>
              <h2 class="text-xl font-semibold text-primary mb-2">
                {gettext("Welcome to System Settings")}
              </h2>
              <p class="text-secondary mb-3">
                {gettext(
                  "Configure and customize your GLAM system. Use the sidebar to navigate between different configuration areas."
                )}
              </p>
              <p class="text-sm text-secondary">
                {gettext("Currently logged in as")}
                <span class="font-semibold">{@current_user.fullname} ({@current_user.email})</span>
              </p>
            </div>
          </div>
        </div>
        <!-- System Overview Cards -->
        <div class="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 gap-4">
          <div class="surface-card p-6 rounded-lg border border-subtle">
            <div class="flex items-center justify-between mb-4">
              <h5 class="font-semibold text-primary">{gettext("System Status")}</h5>
              <div class="p-2 bg-tone-success-soft rounded-lg">
                <.icon name="hero-check-circle" class="w-5 h-5 text-voile-success" />
              </div>
            </div>
            <div class="space-y-3">
              <div class="flex justify-between items-center">
                <span class="text-sm text-secondary">{gettext("Database")}</span>
                <span class="text-sm font-medium text-voile-success">
                  {gettext("Connected")}
                </span>
              </div>
              <div class="flex justify-between items-center">
                <span class="text-sm text-secondary">
                  {gettext("Storage Mode")}
                </span>
                <span class="text-sm font-mono font-medium text-voile-success">
                  {@system_info.storage_mode}
                </span>
              </div>
              <div class="flex justify-between items-center">
                <span class="text-sm text-secondary">{gettext("Cache")}</span>
                <span class="text-sm font-medium text-voile-success">
                  {gettext("Active")}
                </span>
              </div>
            </div>
          </div>

          <div class="surface-card p-6 rounded-lg border border-subtle">
            <div class="flex items-center justify-between mb-4">
              <h5 class="font-semibold text-primary">{gettext("Your Access")}</h5>
              <div class="p-2 bg-tone-info-soft rounded-lg">
                <.icon name="hero-shield-check" class="w-5 h-5 text-voile-info" />
              </div>
            </div>
            <div class="space-y-3">
              <div>
                <span class="text-xs text-tertiary">{gettext("Role")}</span>
                <p class="font-medium text-primary">
                  {if @current_user.user_type, do: @current_user.user_type.name, else: gettext("User")}
                </p>
              </div>
              <div>
                <span class="text-xs text-tertiary">{gettext("Permissions")}</span>
                <p class="font-medium text-primary">{gettext("Administrator")}</p>
              </div>
            </div>
          </div>

          <div class="surface-card p-6 rounded-lg border border-subtle">
            <div class="flex items-center justify-between mb-4">
              <h5 class="font-semibold text-primary">{gettext("Quick Actions")}</h5>
              <div class="p-2 bg-tone-brand-soft rounded-lg">
                <.icon name="hero-bolt" class="w-5 h-5 text-voile-primary" />
              </div>
            </div>
            <div class="space-y-2">
              <.link
                navigate="/manage/settings/user_profile"
                class="block text-sm"
              >
                {gettext("Edit Profile →")}
              </.link>
              <.link
                navigate="/manage/settings/apps"
                class="block text-sm"
              >
                {gettext("Update App Settings →")}
              </.link>
              <.link
                navigate="/manage/settings/permissions"
                class="block text-sm"
              >
                {gettext("Manage Permissions →")}
              </.link>
            </div>
          </div>
        </div>
        <!-- System Version Information -->
        <div class="surface-card p-6 rounded-lg border border-subtle">
          <div class="flex items-start gap-3 mb-4">
            <div class="p-2 bg-tone-brand-soft rounded-lg">
              <.icon name="hero-server-stack" class="w-5 h-5 text-voile-primary" />
            </div>
            <div class="flex-1">
              <h5 class="font-semibold text-primary mb-4">
                {gettext("System Information")}
              </h5>

              <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
                <div>
                  <div class="text-xs text-tertiary mb-1">{gettext("Elixir")}</div>
                  <div class="font-mono text-sm font-medium text-primary">
                    v{@system_info.elixir_version}
                  </div>
                </div>

                <div>
                  <div class="text-xs text-tertiary mb-1">
                    {gettext("Erlang/OTP")}
                  </div>
                  <div class="font-mono text-sm font-medium text-primary">
                    {@system_info.otp_version}
                  </div>
                </div>

                <div>
                  <div class="text-xs text-tertiary mb-1">
                    {gettext("Phoenix")}
                  </div>
                  <div class="font-mono text-sm font-medium text-primary">
                    v{@system_info.phoenix_version}
                  </div>
                </div>

                <div>
                  <div class="text-xs text-tertiary mb-1">
                    {gettext("LiveView")}
                  </div>
                  <div class="font-mono text-sm font-medium text-primary">
                    v{@system_info.phoenix_liveview_version}
                  </div>
                </div>

                <div>
                  <div class="text-xs text-tertiary mb-1">{gettext("Ecto")}</div>
                  <div class="font-mono text-sm font-medium text-primary">
                    v{@system_info.ecto_version}
                  </div>
                </div>

                <div>
                  <div class="text-xs text-tertiary mb-1">
                    {gettext("PostgreSQL")}
                  </div>
                  <div class="font-mono text-sm font-medium text-primary">
                    {@system_info.postgres_version}
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
        <!-- Contact & Social Settings -->
        <!-- Runtime Details -->
        <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div class="surface-card p-6 rounded-lg border border-subtle">
            <div class="flex items-start gap-3">
              <div class="p-2 bg-tone-brand-soft rounded-lg">
                <.icon name="hero-cpu-chip" class="w-5 h-5 text-voile-primary" />
              </div>
              <div class="flex-1">
                <h5 class="font-semibold text-primary mb-3">
                  {gettext("Runtime Information")}
                </h5>
                <div class="space-y-2 text-sm">
                  <div class="flex justify-between">
                    <span class="text-secondary">{gettext("Node Name")}</span>
                    <span class="font-mono text-primary text-xs">
                      {@system_info.node_name}
                    </span>
                  </div>
                  <div class="flex justify-between">
                    <span class="text-secondary">{gettext("Environment")}</span>
                    <span class="font-mono text-primary uppercase">
                      {@system_info.environment}
                    </span>
                  </div>
                  <div class="flex justify-between">
                    <span class="text-secondary">{gettext("Architecture")}</span>
                    <span class="font-mono text-primary text-xs">
                      {@system_info.system_architecture}
                    </span>
                  </div>
                  <div class="flex justify-between">
                    <span class="text-secondary">{gettext("Uptime")}</span>
                    <span class="font-mono text-primary">
                      {format_uptime(@system_info.uptime)}
                    </span>
                  </div>
                </div>
              </div>
            </div>
          </div>

          <div class="surface-card p-6 rounded-lg border border-subtle">
            <div class="flex items-start gap-3">
              <div class="p-2 bg-tone-info-soft rounded-lg">
                <.icon name="hero-rectangle-group" class="w-5 h-5 text-voile-info" />
              </div>
              <div class="flex-1">
                <h5 class="font-semibold text-primary mb-3">
                  {gettext("Process & Scheduler Info")}
                </h5>
                <div class="space-y-2 text-sm">
                  <div class="flex justify-between">
                    <span class="text-secondary">{gettext("Schedulers")}</span>
                    <span class="font-mono text-primary">
                      {@system_info.schedulers_online} / {@system_info.schedulers}
                    </span>
                  </div>
                  <div class="flex justify-between">
                    <span class="text-secondary">
                      {gettext("Active Processes")}
                    </span>
                    <span class="font-mono text-primary">
                      {format_number(@system_info.process_count)}
                    </span>
                  </div>
                  <div class="flex justify-between">
                    <span class="text-secondary">{gettext("Process Limit")}</span>
                    <span class="font-mono text-primary">
                      {format_number(@system_info.process_limit)}
                    </span>
                  </div>
                  <div class="flex justify-between">
                    <span class="text-secondary">{gettext("Utilization")}</span>
                    <span class="font-mono text-primary">
                      {Float.round(@system_info.process_count / @system_info.process_limit * 100, 2)}%
                    </span>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </.voile_settings_shell>
    """
  end
end
