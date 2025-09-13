defmodule VoileWeb.Dashboard.Circulation.Reservation.Index do
  use VoileWeb, :live_view_dashboard
  import VoileWeb.Dashboard.Circulation.Helpers
  import VoileWeb.Dashboard.Circulation.Components

  alias Voile.Schema.Library.Circulation
  alias Voile.Schema.Library.Reservation

  @impl true
  def mount(_params, _session, socket) do
    page = 1
    per_page = 15
    {reservations, total_pages} = Circulation.list_reservations_paginated(page, per_page)

    socket =
      socket
      |> stream(:reservations, reservations)
      |> assign(:page, page)
      |> assign(:total_pages, total_pages)
      |> assign(:filter_status, "all")

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Library Reservations")
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Reservation")
    |> assign(:reservation, %Reservation{})
  end

  @impl true
  def handle_event(
        "create_reservation",
        %{"member_id" => member_id, "item_id" => item_id},
        socket
      ) do
    case Circulation.create_reservation(member_id, item_id) do
      {:ok, reservation} ->
        socket =
          socket
          |> stream_insert(:reservations, reservation, at: 0)
          |> put_flash(:info, "Reservation created successfully")

        {:noreply, socket}

      {:error, changeset} ->
        socket =
          socket
          |> put_flash(
            :error,
            "Failed to create reservation: #{extract_error_message(changeset)}"
          )

        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("cancel_reservation", %{"id" => id}, socket) do
    case Circulation.cancel_reservation(id, "Cancelled by librarian") do
      {:ok, reservation} ->
        socket =
          socket
          |> stream_insert(:reservations, reservation)
          |> put_flash(:info, "Reservation cancelled successfully")

        {:noreply, socket}

      {:error, reason} ->
        socket =
          socket
          |> put_flash(:error, "Failed to cancel reservation: #{reason}")

        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("mark_available", %{"id" => id}, socket) do
    current_user_id = socket.assigns.current_user.id

    case Circulation.mark_reservation_available(id, current_user_id) do
      {:ok, reservation} ->
        socket =
          socket
          |> stream_insert(:reservations, reservation)
          |> put_flash(:info, "Reservation marked as available for pickup")

        {:noreply, socket}

      {:error, reason} ->
        socket =
          socket
          |> put_flash(:error, "Failed to mark reservation available: #{reason}")

        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("fulfill_reservation", %{"id" => id}, socket) do
    current_user_id = socket.assigns.current_user.id

    case Circulation.fulfill_reservation(id, current_user_id) do
      {:ok, transaction} ->
        # Remove the reservation from the stream and show success message
        reservation = Circulation.get_reservation!(id)

        socket =
          socket
          |> stream_delete(:reservations, reservation)
          |> put_flash(
            :info,
            "Reservation fulfilled and item checked out with transaction id : #{transaction.id}"
          )

        {:noreply, socket}

      {:error, changeset} ->
        socket =
          socket
          |> put_flash(
            :error,
            "Failed to fulfill reservation: #{extract_error_message(changeset)}"
          )

        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("filter", %{"status" => status}, socket) do
    socket =
      socket
      |> assign(:filter_status, status)
      |> reload_reservations()

    {:noreply, socket}
  end

  @impl true
  def handle_event("paginate", %{"page" => page}, socket) do
    page = String.to_integer(page)
    per_page = 15

    {reservations, total_pages} = Circulation.list_reservations_paginated(page, per_page)

    socket =
      socket
      |> stream(:reservations, reservations, reset: true)
      |> assign(:page, page)
      |> assign(:total_pages, total_pages)

    {:noreply, socket}
  end

  defp reload_reservations(socket) do
    page = 1
    per_page = 15
    {reservations, total_pages} = Circulation.list_reservations_paginated(page, per_page)

    socket
    |> stream(:reservations, reservations, reset: true)
    |> assign(:page, page)
    |> assign(:total_pages, total_pages)
  end

  defp extract_error_message(changeset) do
    changeset
    |> Map.get(:errors, [])
    |> Enum.map(fn {field, {message, _}} -> "#{field}: #{message}" end)
    |> Enum.join(", ")
  end
end
