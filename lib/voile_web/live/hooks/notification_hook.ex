defmodule VoileWeb.Live.Hooks.NotificationHook do
  @moduledoc """
  LiveView hook that adds reservation notification support to all dashboard pages.
  """
  import Phoenix.LiveView
  import Phoenix.Component

  alias Voile.Notifications.ReservationNotifier

  def on_mount(:default, _params, _session, socket) do
    socket =
      if connected?(socket) do
        current_user = socket.assigns[:current_scope] && socket.assigns.current_scope.user

        # Only subscribe if user is staff/admin
        if current_user && is_staff?(current_user) do
          ReservationNotifier.subscribe_to_reservations()

          socket
          |> assign(:notifications, [])
          |> attach_hook(:reservation_notifications, :handle_info, fn
            {:new_reservation, notification_data}, socket ->
              # Add notification to the list
              notifications = [notification_data | socket.assigns.notifications]
              # Keep only last 10 notifications
              notifications = Enum.take(notifications, 10)

              socket =
                socket
                |> assign(:notifications, notifications)
                |> push_event("play_notification_sound", %{})

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
end
