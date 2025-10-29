defmodule VoileWeb.Live.Hooks.NotificationHook do
  @moduledoc """
  LiveView hook that adds reservation notification support to all dashboard pages.
  """
  import Phoenix.LiveView
  import Phoenix.Component

  alias Voile.Notifications.ReservationNotifier
  alias Voile.Schema.System

  def on_mount(:default, _params, _session, socket) do
    socket =
      if connected?(socket) do
        current_user = socket.assigns[:current_scope] && socket.assigns.current_scope.user

        # Only subscribe if user is staff/admin AND notifications are enabled
        if current_user && is_staff?(current_user) && notifications_enabled?() do
          ReservationNotifier.subscribe_to_reservations()

          socket
          |> assign(:notifications, [])
          |> assign(:notification_sound_enabled, sound_enabled?())
          |> attach_hook(:reservation_notifications, :handle_info, fn
            {:new_reservation, notification_data}, socket ->
              # Add notification to the list
              notifications = [notification_data | socket.assigns.notifications]
              # Keep only last 10 notifications
              notifications = Enum.take(notifications, 10)

              socket =
                socket
                |> assign(:notifications, notifications)

              # Play sound only if enabled
              socket =
                if socket.assigns[:notification_sound_enabled] do
                  push_event(socket, "play_notification_sound", %{})
                else
                  socket
                end

              {:halt, socket}

            {:update_notifications, notifications}, socket ->
              {:halt, assign(socket, :notifications, notifications)}

            _msg, socket ->
              {:cont, socket}
          end)
        else
          assign(socket, :notifications, [])
        end
      else
        assign(socket, :notifications, [])
      end

    {:cont, socket}
  end

  # Helper to check if user is staff
  defp is_staff?(user) do
    user = Voile.Repo.preload(user, :roles)

    Enum.any?(user.roles, fn role ->
      role.name in [
        "super_admin",
        "admin",
        "librarian",
        "archivist",
        "gallery_curator",
        "museum_curator"
      ]
    end)
  end

  # Check if notifications are enabled in settings
  defp notifications_enabled? do
    System.get_setting_value("reservation_notifications_enabled", "true") == "true"
  end

  # Check if sound notifications are enabled in settings
  defp sound_enabled? do
    System.get_setting_value("reservation_notifications_sound", "true") == "true"
  end
end
