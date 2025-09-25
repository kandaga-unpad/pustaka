defmodule VoileWeb.Dashboard.Circulation.Reservation.Show do
  use VoileWeb, :live_view_dashboard
  import VoileWeb.Dashboard.Circulation.Helpers
  import VoileWeb.Dashboard.Circulation.Components

  alias Voile.Schema.Library.Circulation

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    reservation = Circulation.get_reservation!(id)

    dbg(reservation)

    {:noreply,
     socket
     |> assign(:reservation, reservation)
     |> assign(:page_title, "Reservation Details")}
  end

  @impl true
  def handle_event("fulfill", %{"id" => id}, socket) do
    reservation = Circulation.get_reservation!(id)
    current_user_id = socket.assigns.current_user.id

    case Circulation.fulfill_reservation(reservation, current_user_id) do
      {:ok, _reservation} ->
        {:noreply,
         socket
         |> put_flash(:info, "Reservation fulfilled successfully.")
         |> push_navigate(to: ~p"/manage/circulation/reservations/#{reservation.id}")}

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
         |> push_navigate(to: ~p"/manage/circulation/reservations/#{reservation.id}")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  @impl true
  def handle_event("notify", %{"id" => id}, socket) do
    reservation = Circulation.get_reservation!(id)

    case Circulation.update_reservation(reservation, %{is_notified: true}) do
      {:ok, _reservation} ->
        {:noreply,
         socket
         |> put_flash(:info, "Notification sent successfully.")
         |> push_navigate(to: ~p"/manage/circulation/reservations/#{reservation.id}")}

      {:error, changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to send notification.")
         |> assign(:changeset, changeset)}
    end
  end

  # Import helper functions
  # defdelegate status_badge_class(status), to: VoileWeb.Dashboard.Circulation.Helpers
  # defdelegate priority_badge_class(priority), to: VoileWeb.Dashboard.Circulation.Helpers
  # defdelegate format_datetime(datetime), to: VoileWeb.Dashboard.Circulation.Helpers

  # Local helper functions that aren't in the shared helpers
  def priority_badge_class("high"), do: "bg-red-100 text-red-800"
  def priority_badge_class("urgent"), do: "bg-red-200 text-red-900"
  def priority_badge_class("normal"), do: "bg-blue-100 text-blue-800"
  def priority_badge_class("low"), do: "bg-gray-100 text-gray-800"
  def priority_badge_class(_), do: "bg-gray-100 text-gray-800"
end
