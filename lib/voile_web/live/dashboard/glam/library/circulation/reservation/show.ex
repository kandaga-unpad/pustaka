defmodule VoileWeb.Dashboard.Glam.Library.Circulation.Reservation.Show do
  use VoileWeb, :live_view_dashboard
  import VoileWeb.Dashboard.Glam.Library.Circulation.Helpers

  alias Voile.Schema.Library.Circulation
  alias VoileWeb.Auth.Authorization

  @impl true
  def mount(_params, _session, socket) do
    # Check permission for managing reservations
    unless Authorization.can?(socket, "circulation.manage_reservations") do
      socket =
        socket
        |> put_flash(:error, "You don't have permission to access reservation details")
        |> push_navigate(to: ~p"/manage/glam/library/circulation")

      {:ok, socket}
    else
      {:ok,
       socket
       |> assign(show_fulfill_modal: false)
       |> assign(show_cancel_modal: false)
       |> assign(pending_fulfill_id: nil)
       |> assign(pending_cancel_id: nil)}
    end
  end

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    reservation = Circulation.get_reservation!(id)

    {:noreply,
     socket
     |> assign(:reservation, reservation)
     |> assign(:page_title, "Reservation Details")}
  end

  @impl true
  # Open the fulfill confirmation modal
  def handle_event("open_fulfill_modal", %{"id" => id}, socket) do
    {:noreply, assign(socket, show_fulfill_modal: true, pending_fulfill_id: id)}
  end

  @impl true
  def handle_event("close_fulfill_modal", _params, socket) do
    {:noreply, assign(socket, show_fulfill_modal: false, pending_fulfill_id: nil)}
  end

  @impl true
  def handle_event("confirm_fulfill", %{"id" => id}, socket) do
    reservation = Circulation.get_reservation!(id)
    current_user_id = socket.assigns.current_scope.user.id

    case Circulation.fulfill_reservation(reservation, current_user_id) do
      {:ok, _transaction} ->
        {:noreply,
         socket
         |> assign(show_fulfill_modal: false, pending_fulfill_id: nil)
         |> put_flash(:info, "Reservation fulfilled successfully.")
         |> push_navigate(to: ~p"/manage/glam/library/circulation/reservations/#{reservation.id}")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  @impl true
  def handle_event("open_cancel_modal", %{"id" => id}, socket) do
    {:noreply, assign(socket, show_cancel_modal: true, pending_cancel_id: id)}
  end

  @impl true
  def handle_event("close_cancel_modal", _params, socket) do
    {:noreply, assign(socket, show_cancel_modal: false, pending_cancel_id: nil)}
  end

  @impl true
  def handle_event("confirm_cancel", %{"id" => id}, socket) do
    reservation = Circulation.get_reservation!(id)

    case Circulation.update_reservation(reservation, %{
           status: "cancelled",
           cancelled_date: DateTime.utc_now()
         }) do
      {:ok, _reservation} ->
        {:noreply,
         socket
         |> assign(show_cancel_modal: false, pending_cancel_id: nil)
         |> put_flash(:info, "Reservation cancelled successfully.")
         |> push_navigate(to: ~p"/manage/glam/library/circulation/reservations/#{reservation.id}")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  @impl true
  def handle_event("cancel", %{"id" => id}, socket) do
    reservation = Circulation.get_reservation!(id)

    case Circulation.update_reservation(reservation, %{
           status: "cancelled",
           cancelled_date: DateTime.utc_now()
         }) do
      {:ok, _reservation} ->
        {:noreply,
         socket
         |> put_flash(:info, "Reservation cancelled successfully.")
         |> push_navigate(to: ~p"/manage/glam/library/circulation/reservations/#{reservation.id}")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  @impl true
  def handle_event("notify", %{"id" => id}, socket) do
    reservation = Circulation.get_reservation!(id)

    # Try to send notification to member (realtime pubsub preferred, email fallback)
    case Voile.Notifications.ReservationNotifier.notify_member(reservation) do
      {:ok, _tag} ->
        case Circulation.update_reservation(reservation, %{notification_sent: true}) do
          {:ok, _reservation} ->
            {:noreply,
             socket
             |> put_flash(:info, "Notification sent to member successfully.")
             |> push_navigate(
               to: ~p"/manage/glam/library/circulation/reservations/#{reservation.id}"
             )}

          {:error, %Ecto.Changeset{} = changeset} ->
            {:noreply, assign(socket, :changeset, changeset)}
        end

      {:error, reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to send notification: #{inspect(reason)}")
         |> assign(:notification_error, reason)}
    end
  end

  # Import helper functions
  # defdelegate status_badge_class(status), to: VoileWeb.Dashboard.Glam.Library.Circulation.Helpers
  # defdelegate priority_badge_class(priority), to: VoileWeb.Dashboard.Glam.Library.Circulation.Helpers
  # defdelegate format_datetime(datetime), to: VoileWeb.Dashboard.Glam.Library.Circulation.Helpers

  # Local helper functions that aren't in the shared helpers
  def priority_badge_class("high"), do: "bg-red-100 text-red-800"
  def priority_badge_class("urgent"), do: "bg-red-200 text-red-900"
  def priority_badge_class("normal"), do: "bg-blue-100 text-blue-800"
  def priority_badge_class("low"), do: "bg-gray-100 text-gray-800"
  def priority_badge_class(_), do: "bg-gray-100 text-gray-800"
end
