defmodule VoileWeb.Dashboard.Master.LocationsLive.Index do
  use VoileWeb, :live_view_dashboard

  alias Voile.Schema.Master
  alias Voile.Schema.Master.Location
  alias VoileWeb.Auth.Authorization

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user

    unless Authorization.can?(user, "metadata.manage") do
      socket =
        socket
        |> put_flash(:error, "Access Denied: You don't have permission to access this page")
        |> push_navigate(to: ~p"/manage/master")

      {:ok, socket}
    else
      page = 1
      per_page = 10
      {locations, total_pages, _} = Master.list_mst_locations_paginated(page, per_page)

      socket =
        socket
        |> assign(:page_title, "Listing Locations")
        |> assign(:live_action, :index)
        |> stream(:locations, locations)
        |> assign(:page, page)
        |> assign(:total_pages, total_pages)

      {:ok, socket}
    end
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit Location")
    |> assign(:location, Master.get_locations!(id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Location")
    |> assign(:location, %Location{})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Listing Locations")
    |> assign(:location, nil)
  end

  @impl true
  def handle_info(
        {VoileWeb.Dashboard.Master.LocationsLive.FormComponent, {:saved, location}},
        socket
      ) do
    {:noreply, stream_insert(socket, :locations, location)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    location = Master.get_locations!(id)
    {:ok, _} = Master.delete_locations(location)

    {:noreply, stream_delete(socket, :locations, location)}
  end

  @impl true
  def handle_event("paginate", %{"page" => page}, socket) do
    page = String.to_integer(page)
    per_page = 10
    {locations, total_pages, _} = Master.list_mst_locations_paginated(page, per_page)

    socket =
      socket
      |> stream(:locations, locations, reset: true)
      |> assign(:page, page)
      |> assign(:total_pages, total_pages)

    {:noreply, socket}
  end
end
