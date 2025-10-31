defmodule VoileWeb.Dashboard.Master.CreatorLive.Index do
  use VoileWeb, :live_view_dashboard

  alias Voile.Schema.Master
  alias Voile.Schema.Master.Creator
  alias VoileWeb.Auth.Authorization

  @impl true
  def mount(_params, _session, socket) do
    # Check permission for managing metadata/master data
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
      {creators, total_pages} = Master.list_mst_creator_paginated(page, per_page)

      socket =
        socket
        |> assign(:page_title, "Listing Creators")
        |> assign(:live_action, :index)
        |> assign(:creators, creators)
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
    |> assign(:page_title, "Edit Creator")
    |> assign(:creator, Master.get_creator!(id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Item")
    |> assign(:creator, %Creator{})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Listing Creators")
    |> assign(:creator, nil)
  end

  @impl true
  def handle_info(
        {VoileWeb.Dashboard.Master.CreatorLive.FormComponent, {:saved, creator}},
        socket
      ) do
    {:noreply, stream_insert(socket, :creators, creator)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    creator = Master.get_creator!(id)
    {:ok, _} = Master.delete_creator(creator)

    {:noreply, stream_delete(socket, :creators, creator)}
  end

  @impl true
  def handle_event("paginate", %{"page" => page}, socket) do
    page = String.to_integer(page)
    per_page = 10
    {creators, total_pages} = Master.list_mst_creator_paginated(page, per_page)

    socket =
      socket
      |> assign(:creators, creators)
      |> assign(:page, page)
      |> assign(:total_pages, total_pages)

    {:noreply, socket}
  end
end
