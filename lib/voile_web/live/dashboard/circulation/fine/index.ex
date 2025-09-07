defmodule VoileWeb.Dashboard.Circulation.Fine.Index do
  use VoileWeb, :live_view_dashboard
  import VoileWeb.Dashboard.Circulation.Helpers

  alias Voile.Schema.Library.Circulation
  alias Voile.Schema.Library.Fine

  @impl true
  def mount(_params, _session, socket) do
    page = 1
    per_page = 15
    filters = %{status: "all", type: "all"}
    {fines, total_pages} = Circulation.list_fines_paginated_with_filters(page, per_page, filters)

    socket =
      socket
      |> stream(:fines, fines)
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
    |> assign(:page_title, "Library Fines")
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Fine")
    |> assign(:fine, %Fine{})
  end

  @impl true
  def handle_event("create_fine", params, socket) do
    case Circulation.create_fine(params) do
      {:ok, fine} ->
        socket =
          socket
          |> stream_insert(:fines, fine, at: 0)
          |> put_flash(:info, "Fine created successfully")

        {:noreply, socket}

      {:error, changeset} ->
        socket =
          socket
          |> put_flash(:error, "Failed to create fine: #{extract_error_message(changeset)}")

        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("filter", %{"status" => status, "type" => type}, socket) do
    socket =
      socket
      |> assign(:filter_status, status)
      |> assign(:filter_type, type)
      |> reload_fines()

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

    {fines, total_pages} = Circulation.list_fines_paginated_with_filters(page, per_page, filters)

    socket =
      socket
      |> stream(:fines, fines, reset: true)
      |> assign(:page, page)
      |> assign(:total_pages, total_pages)

    {:noreply, socket}
  end

  defp reload_fines(socket) do
    page = 1
    per_page = 15

    filters = %{
      status: socket.assigns.filter_status,
      type: socket.assigns.filter_type
    }

    {fines, total_pages} = Circulation.list_fines_paginated_with_filters(page, per_page, filters)

    socket
    |> stream(:fines, fines, reset: true)
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
