defmodule VoileWeb.Dashboard.Settings.SettingLive do
  use VoileWeb, :live_view_dashboard

  def mount(_params, _session, socket) do
    handle_mount_errors do
      # Check permission - if unauthorized, error handling is automatic
      authorize!(socket, "system.settings")

      current_user = socket.assigns.current_scope.user

      dbg(current_user.user_type.slug)

      socket =
        socket
        |> assign(:current_user, current_user)

      {:ok, socket}
    end
  end

  def render(assigns) do
    ~H"""
    <.header>
      <h4>Settings</h4>

      <:subtitle>Manage the system</:subtitle>
    </.header>

    <div class="flex gap-4">
      <div class="w-full max-w-64"><.dashboard_settings_sidebar current_user={@current_user} /></div>

      <div class="w-full bg-white dark:bg-gray-700 p-4 rounded-lg">Content goes here.</div>
    </div>
    """
  end
end
