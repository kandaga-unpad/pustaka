defmodule VoileWeb.Dashboard.Glam.Library.Circulation.Requisition.Index do
  use VoileWeb, :live_view_dashboard
  import VoileWeb.Dashboard.Glam.Library.Circulation.Helpers

  alias Voile.Schema.Library.Circulation
  alias Voile.Schema.Library.Requisition

  @impl true
  def mount(_params, _session, socket) do
    page = 1
    per_page = 15
    {requisitions, total_pages} = Circulation.list_requisitions_paginated(page, per_page)

    socket =
      socket
      |> stream(:requisitions, requisitions)
      |> assign(:page, page)
      |> assign(:total_pages, total_pages)
      |> assign(:filter_status, "all")
      |> assign(:filter_type, "all")

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Library Requisitions")
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Requisition")
    |> assign(:requisition, %Requisition{})
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    requisition = Circulation.get_requisition!(id)

    socket
    |> assign(:page_title, "Edit Requisition")
    |> assign(:requisition, requisition)
  end

  @impl true
  def handle_event("create_requisition", params, socket) do
    current_user_id = socket.assigns.current_user.id

    case Circulation.create_requisition(current_user_id, params) do
      {:ok, requisition} ->
        socket =
          socket
          |> stream_insert(:requisitions, requisition, at: 0)
          |> put_flash(:info, "Requisition created successfully")

        {:noreply, socket}

      {:error, changeset} ->
        socket =
          socket
          |> put_flash(
            :error,
            "Failed to create requisition: #{extract_error_message(changeset)}"
          )

        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("update_status", %{"id" => id, "status" => status}, socket) do
    requisition = Circulation.get_requisition!(id)

    case Circulation.update_requisition(requisition, %{status: status}) do
      {:ok, updated_requisition} ->
        socket =
          socket
          |> stream_insert(:requisitions, updated_requisition)
          |> put_flash(:info, "Requisition status updated successfully")

        {:noreply, socket}

      {:error, changeset} ->
        socket =
          socket
          |> put_flash(
            :error,
            "Failed to update requisition: #{extract_error_message(changeset)}"
          )

        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    requisition = Circulation.get_requisition!(id)

    case Circulation.delete_requisition(requisition) do
      {:ok, _} ->
        socket =
          socket
          |> stream_delete(:requisitions, requisition)
          |> put_flash(:info, "Requisition deleted successfully")

        {:noreply, socket}

      {:error, changeset} ->
        socket =
          socket
          |> put_flash(
            :error,
            "Failed to delete requisition: #{extract_error_message(changeset)}"
          )

        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("filter", %{"status" => status, "type" => type}, socket) do
    socket =
      socket
      |> assign(:filter_status, status)
      |> assign(:filter_type, type)
      |> reload_requisitions()

    {:noreply, socket}
  end

  @impl true
  def handle_event("paginate", %{"page" => page}, socket) do
    page = String.to_integer(page)
    per_page = 15

    filters = %{
      status: socket.assigns.filter_status,
      type: socket.assigns.filter_type
    }

    {requisitions, total_pages} =
      Circulation.list_requisitions_paginated_with_filters(page, per_page, filters)

    socket =
      socket
      |> stream(:requisitions, requisitions, reset: true)
      |> assign(:page, page)
      |> assign(:total_pages, total_pages)

    {:noreply, socket}
  end

  defp reload_requisitions(socket) do
    page = 1
    per_page = 15

    filters = %{
      status: socket.assigns.filter_status,
      type: socket.assigns.filter_type
    }

    {requisitions, total_pages} =
      Circulation.list_requisitions_paginated_with_filters(page, per_page, filters)

    socket
    |> stream(:requisitions, requisitions, reset: true)
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
