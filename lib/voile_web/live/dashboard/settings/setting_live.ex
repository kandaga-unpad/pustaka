defmodule VoileWeb.Dashboard.Settings.SettingLive do
  use VoileWeb, :live_view_dashboard

  # alias VoileWeb.Dashboard.Settings

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <.header>
      <h4>Settings</h4>

      <:subtitle>Manage the system</:subtitle>
    </.header>

    <div class="flex gap-4">
      <div class="w-full max-w-64"><.dashboard_settings_sidebar /></div>

      <div class="w-full bg-white dark:bg-gray-700 p-4 rounded-lg">Content goes here.</div>
    </div>
    """
  end
end
