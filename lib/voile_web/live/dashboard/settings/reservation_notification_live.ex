defmodule VoileWeb.Dashboard.Settings.ReservationNotificationLive do
  use VoileWeb, :live_view_dashboard

  alias Voile.Schema.System

  @impl true
  def mount(_params, _session, socket) do
    handle_mount_errors do
      # Check permission for managing system settings
      authorize!(socket, "system.settings")

      # Load current settings
      enabled = System.get_setting_value("reservation_notifications_enabled", "true")
      sound_enabled = System.get_setting_value("reservation_notifications_sound", "true")
      desktop_enabled = System.get_setting_value("reservation_notifications_desktop", "false")

      socket =
        socket
        |> assign(:current_path, "/manage/settings/reservation_notifications")
        |> assign(:notifications_enabled, enabled == "true")
        |> assign(:sound_enabled, sound_enabled == "true")
        |> assign(:desktop_enabled, desktop_enabled == "true")
        |> assign(:save_status, nil)

      {:ok, socket}
    end
  end

  @impl true
  def handle_event("toggle_notifications", %{"enabled" => enabled}, socket) do
    value = if enabled == "true", do: "true", else: "false"

    case System.upsert_setting("reservation_notifications_enabled", value) do
      {:ok, _setting} ->
        {:noreply,
         socket
         |> assign(:notifications_enabled, enabled == "true")
         |> assign(:save_status, :success)
         |> put_flash(:info, "Notification settings updated successfully")}

      {:error, _changeset} ->
        {:noreply,
         socket
         |> assign(:save_status, :error)
         |> put_flash(:error, "Failed to update notification settings")}
    end
  end

  @impl true
  def handle_event("toggle_sound", %{"enabled" => enabled}, socket) do
    value = if enabled == "true", do: "true", else: "false"

    case System.upsert_setting("reservation_notifications_sound", value) do
      {:ok, _setting} ->
        {:noreply,
         socket
         |> assign(:sound_enabled, enabled == "true")
         |> assign(:save_status, :success)
         |> put_flash(:info, "Sound notification settings updated successfully")}

      {:error, _changeset} ->
        {:noreply,
         socket
         |> assign(:save_status, :error)
         |> put_flash(:error, "Failed to update sound notification settings")}
    end
  end

  @impl true
  def handle_event("toggle_desktop", %{"enabled" => enabled}, socket) do
    value = if enabled == "true", do: "true", else: "false"

    case System.upsert_setting("reservation_notifications_desktop", value) do
      {:ok, _setting} ->
        {:noreply,
         socket
         |> assign(:desktop_enabled, enabled == "true")
         |> assign(:save_status, :success)
         |> put_flash(:info, "Desktop notification settings updated successfully")}

      {:error, _changeset} ->
        {:noreply,
         socket
         |> assign(:save_status, :error)
         |> put_flash(:error, "Failed to update desktop notification settings")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      Reservation Notification Settings
      <:subtitle>
        Configure how staff and admins receive notifications when members request reservations
      </:subtitle>
    </.header>

    <section class="flex gap-4">
      <div class="w-full max-w-64">
        <.dashboard_settings_sidebar
          current_user={@current_scope.user}
          current_path={@current_path}
        />
      </div>
      
      <div class="flex-1">
        <div class="bg-white dark:bg-gray-700 shadow rounded-lg">
          <div class="px-6 py-4 border-b border-gray-200 dark:border-gray-600">
            <h3 class="text-lg font-medium">Notification Preferences</h3>
            
            <p class="mt-1 text-sm text-gray-500 dark:text-gray-400">
              Control how you want to be notified about new reservation requests
            </p>
          </div>
          
          <div class="px-6 py-4 space-y-6">
            <!-- Enable/Disable Notifications -->
            <div class="flex items-start">
              <div class="flex-1">
                <h4 class="text-base font-medium">Enable Reservation Notifications</h4>
                
                <p class="text-sm text-gray-500 dark:text-gray-400 mt-1">
                  Receive real-time notifications when members create reservation requests.
                  When disabled, no notification popup will appear but reservations will still be recorded.
                </p>
              </div>
              
              <div class="ml-4 flex-shrink-0">
                <label class="relative inline-flex items-center cursor-pointer">
                  <input
                    type="checkbox"
                    checked={@notifications_enabled}
                    phx-change="toggle_notifications"
                    name="enabled"
                    value={if @notifications_enabled, do: "false", else: "true"}
                    class="sr-only peer"
                  />
                  <div class="w-11 h-6 bg-gray-200 peer-focus:outline-none peer-focus:ring-4 peer-focus:ring-blue-300 dark:peer-focus:ring-blue-800 rounded-full peer dark:bg-gray-600 peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all dark:border-gray-600 peer-checked:bg-blue-600">
                  </div>
                </label>
              </div>
            </div>
            
            <div class="border-t border-gray-200 dark:border-gray-600 pt-6"></div>
            <!-- Sound Notifications -->
            <div class={[
              "flex items-start",
              !@notifications_enabled && "opacity-50 pointer-events-none"
            ]}>
              <div class="flex-1">
                <h4 class="text-base font-medium">Sound Alerts</h4>
                
                <p class="text-sm text-gray-500 dark:text-gray-400 mt-1">
                  Play a sound when a new reservation notification arrives. Requires notifications to be enabled.
                </p>
              </div>
              
              <div class="ml-4 flex-shrink-0">
                <label class="relative inline-flex items-center cursor-pointer">
                  <input
                    type="checkbox"
                    checked={@sound_enabled}
                    phx-change="toggle_sound"
                    name="enabled"
                    value={if @sound_enabled, do: "false", else: "true"}
                    disabled={!@notifications_enabled}
                    class="sr-only peer"
                  />
                  <div class="w-11 h-6 bg-gray-200 peer-focus:outline-none peer-focus:ring-4 peer-focus:ring-blue-300 dark:peer-focus:ring-blue-800 rounded-full peer dark:bg-gray-600 peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all dark:border-gray-600 peer-checked:bg-blue-600">
                  </div>
                </label>
              </div>
            </div>
            
            <div class="border-t border-gray-200 dark:border-gray-600 pt-6"></div>
            <!-- Desktop Notifications -->
            <div class={[
              "flex items-start",
              !@notifications_enabled && "opacity-50 pointer-events-none"
            ]}>
              <div class="flex-1">
                <h4 class="text-base font-medium">Browser Desktop Notifications</h4>
                
                <p class="text-sm text-gray-500 dark:text-gray-400 mt-1">
                  Show browser notifications even when you're on a different tab.
                  You'll need to grant permission in your browser. Requires notifications to be enabled.
                </p>
              </div>
              
              <div class="ml-4 flex-shrink-0">
                <label class="relative inline-flex items-center cursor-pointer">
                  <input
                    type="checkbox"
                    checked={@desktop_enabled}
                    phx-change="toggle_desktop"
                    name="enabled"
                    value={if @desktop_enabled, do: "false", else: "true"}
                    disabled={!@notifications_enabled}
                    class="sr-only peer"
                  />
                  <div class="w-11 h-6 bg-gray-200 peer-focus:outline-none peer-focus:ring-4 peer-focus:ring-blue-300 dark:peer-focus:ring-blue-800 rounded-full peer dark:bg-gray-600 peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all dark:border-gray-600 peer-checked:bg-blue-600">
                  </div>
                </label>
              </div>
            </div>
          </div>
          
          <div class="px-6 py-4 bg-gray-50 dark:bg-gray-800 border-t border-gray-200 dark:border-gray-600">
            <div class="flex items-center gap-2 text-sm">
              <.icon name="hero-information-circle" class="w-5 h-5 text-blue-500" />
              <p class="text-gray-600 dark:text-gray-300">
                These settings apply to your account only. Each staff member can configure their own notification preferences.
              </p>
            </div>
          </div>
        </div>
        <!-- Information Card -->
        <div class="mt-6 bg-blue-50 dark:bg-blue-900/20 border border-blue-200 dark:border-blue-800 rounded-lg p-4">
          <div class="flex">
            <div class="flex-shrink-0">
              <.icon name="hero-light-bulb" class="w-5 h-5 text-blue-400" />
            </div>
            
            <div class="ml-3">
              <h3 class="text-sm font-medium text-blue-800 dark:text-blue-300">
                About Reservation Notifications
              </h3>
              
              <div class="mt-2 text-sm text-blue-700 dark:text-blue-400">
                <ul class="list-disc list-inside space-y-1">
                  <li>Notifications appear when members request to reserve items</li>
                  
                  <li>Only staff and admin users receive these notifications</li>
                  
                  <li>Notifications show member name, item details, and notes</li>
                  
                  <li>Click on a notification to view the full reservation details</li>
                </ul>
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>
    """
  end
end
