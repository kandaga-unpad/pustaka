defmodule VoileWeb.Dashboard.Master.PlacesLive.Index do
  use VoileWeb, :live_view_dashboard

  alias Voile.Schema.Master
  alias Voile.Schema.Master.Places

  @impl true
  def mount(_params, _session, socket) do
    page = 1
    per_page = 10
    {places, total_pages} = Master.list_mst_places_paginated(page, per_page)

    socket =
      socket
      |> assign(:page_title, "Listing Places")
      |> assign(:live_action, :index)
      |> assign(:places, places)
      |> assign(:page, page)
      |> assign(:total_pages, total_pages)

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit Place")
    |> assign(:place, Master.get_places!(id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Place")
    |> assign(:place, %Places{})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Listing Places")
    |> assign(:place, nil)
  end

  @impl true
  def handle_info({VoileWeb.Dashboard.Master.PlacesLive.FormComponent, {:saved, place}}, socket) do
    {:noreply, stream_insert(socket, :places, place)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    place = Master.get_places!(id)
    {:ok, _} = Master.delete_places(place)

    {:noreply, stream_delete(socket, :places, place)}
  end

  @impl true
  def handle_event("paginate", %{"page" => page}, socket) do
    page = String.to_integer(page)
    per_page = 10
    {places, total_pages} = Master.list_mst_places_paginated(page, per_page)

    socket =
      socket
      |> assign(:places, places)
      |> assign(:page, page)
      |> assign(:total_pages, total_pages)

    {:noreply, socket}
  end
end
