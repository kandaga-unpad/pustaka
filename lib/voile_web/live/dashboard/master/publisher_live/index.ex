defmodule VoileWeb.Dashboard.Master.PublisherLive.Index do
  use VoileWeb, :live_view_dashboard

  alias Voile.Schema.Master
  alias Voile.Schema.Master.Publishers

  @impl true
  def mount(_params, _session, socket) do
    # Check permission for managing metadata/master data
    authorize!(socket, "metadata.manage")

    page = 1
    per_page = 10
    {publishers, total_pages} = Master.list_mst_publishers_paginated(page, per_page)

    socket =
      socket
      |> assign(:page_title, "Listing Publishers")
      |> assign(:live_action, :index)
      |> assign(:publishers, publishers)
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
    |> assign(:page_title, "Edit Publisher")
    |> assign(:publisher, Master.get_publishers!(id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Publisher")
    |> assign(:publisher, %Publishers{})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Listing Publishers")
    |> assign(:publisher, nil)
  end

  @impl true
  def handle_info(
        {VoileWeb.Dashboard.Master.PublisherLive.FormComponent, {:saved, publisher}},
        socket
      ) do
    {:noreply, stream_insert(socket, :publishers, publisher)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    publisher = Master.get_publishers!(id)
    {:ok, _} = Master.delete_publishers(publisher)

    {:noreply, stream_delete(socket, :publishers, publisher)}
  end

  @impl true
  def handle_event("paginate", %{"page" => page}, socket) do
    page = String.to_integer(page)
    per_page = 10
    {publishers, total_publishers} = Master.list_mst_publishers_paginated(page, per_page)

    socket =
      socket
      |> assign(:publishers, publishers)
      |> assign(:page, page)
      |> assign(:total_pages, total_publishers)

    {:noreply, socket}
  end
end
