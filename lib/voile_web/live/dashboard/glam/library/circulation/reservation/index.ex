defmodule VoileWeb.Dashboard.Glam.Library.Circulation.Reservation.Index do
  use VoileWeb, :live_view_dashboard
  import VoileWeb.Dashboard.Glam.Library.Circulation.Helpers

  alias Voile.Schema.Library.Circulation
  alias Voile.Schema.Library.Reservation
  alias VoileWeb.Auth.Authorization
  alias Voile.Schema.System

  @impl true
  def mount(_params, _session, socket) do
    # Check permission for managing reservations
    unless Authorization.can?(socket, "circulation.manage_reservations") do
      socket =
        socket
        |> put_flash(:error, "You don't have permission to access reservation management")
        |> push_navigate(to: ~p"/manage/glam/library/circulation")

      {:ok, socket}
    else
      user = socket.assigns.current_scope.user
      is_super_admin = Authorization.is_super_admin?(user)

      # For super_admin allow selecting nodes (nil = all nodes)
      {node_id, nodes, selected_node_id} =
        if is_super_admin do
          {nil, System.list_nodes(), nil}
        else
          {user.node_id, [], user.node_id}
        end

      page = 1
      per_page = 15

      {reservations, total_pages, _} =
        if is_super_admin do
          Circulation.list_reservations_paginated(page, per_page)
        else
          Circulation.list_reservations_paginated_with_filters_by_node(
            page,
            per_page,
            %{status: "all"},
            node_id
          )
        end

      socket =
        socket
        |> stream(:reservations, reservations)
        |> assign(:page, page)
        |> assign(:total_pages, total_pages)
        |> assign(:filter_status, "all")
        |> assign(:node_id, node_id)
        |> assign(:is_super_admin, is_super_admin)
        |> assign(:nodes, nodes)
        |> assign(:selected_node_id, selected_node_id)
        |> assign(:form, to_form(%{}))

      {:ok, socket}
    end
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
    current_user_id = socket.assigns.current_scope.user.id

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
    current_user_id = socket.assigns.current_scope.user.id

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
  def handle_event("select_node", %{"node_id" => node_id_str}, socket) do
    node_id = if node_id_str in [nil, "all", ""], do: nil, else: String.to_integer(node_id_str)

    socket =
      socket
      |> assign(:node_id, node_id)
      |> assign(:selected_node_id, node_id)
      |> reload_reservations()

    {:noreply, socket}
  end

  @impl true
  def handle_event("paginate", %{"page" => page}, socket) do
    page = String.to_integer(page)
    per_page = 15
    is_super_admin = socket.assigns.is_super_admin
    node_id = socket.assigns.node_id

    filters = %{status: socket.assigns.filter_status}

    {reservations, total_pages, _} =
      if is_super_admin do
        Circulation.list_reservations_paginated_with_filters(page, per_page, filters)
      else
        Circulation.list_reservations_paginated_with_filters_by_node(
          page,
          per_page,
          filters,
          node_id
        )
      end

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
    is_super_admin = socket.assigns.is_super_admin
    node_id = socket.assigns.node_id
    filters = %{status: socket.assigns.filter_status}

    {reservations, total_pages, _} =
      if is_super_admin do
        Circulation.list_reservations_paginated_with_filters(page, per_page, filters)
      else
        Circulation.list_reservations_paginated_with_filters_by_node(
          page,
          per_page,
          filters,
          node_id
        )
      end

    socket
    |> stream(:reservations, reservations, reset: true)
    |> assign(:page, page)
    |> assign(:total_pages, total_pages)
  end

  defp extract_error_message(error) do
    cond do
      is_binary(error) ->
        error

      is_struct(error, Ecto.Changeset) and error.errors != %{} ->
        error
        |> Ecto.Changeset.traverse_errors(fn {msg, _opts} -> msg end)
        |> Enum.map(fn {field, messages} ->
          "#{field}: #{Enum.join(messages, ", ")}"
        end)
        |> Enum.join(", ")

      true ->
        "Unknown error"
    end
  end
end
