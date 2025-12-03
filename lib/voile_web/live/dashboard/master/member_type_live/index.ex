defmodule VoileWeb.Dashboard.Master.MemberTypeLive.Index do
  use VoileWeb, :live_view_dashboard

  alias Voile.Schema.Master
  alias Voile.Schema.Master.MemberType
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

      {member_types, total_pages, _} = Master.list_mst_member_types_paginated(page, per_page)

      socket =
        socket
        |> assign(:page_title, "Listing Member Types")
        |> assign(:live_action, :index)
        |> stream(:member_types, member_types)
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
    |> assign(:page_title, "Edit Member Type")
    |> assign(:member_type, Master.get_member_type!(id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Member Type")
    |> assign(:member_type, %MemberType{})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Listing Member Types")
    |> assign(:member_type, nil)
  end

  @impl true
  def handle_info(
        {VoileWeb.Dashboard.Master.MemberTypeLive.FormComponent, {:saved, member_type}},
        socket
      ) do
    {:noreply, stream_insert(socket, :member_types, member_type)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    member_type = Master.get_member_type!(id)
    {:ok, _} = Master.delete_member_type(member_type)

    {:noreply, stream_delete(socket, :member_types, member_type)}
  end

  @impl true
  def handle_event("paginate", %{"page" => page}, socket) do
    page = String.to_integer(page)
    per_page = 10
    {member_types, total_pages, _} = Master.list_mst_member_types_paginated(page, per_page)

    socket =
      socket
      # reset the stream with the new page of member_types
      |> stream(:member_types, member_types, reset: true)
      |> assign(:page, page)
      |> assign(:total_pages, total_pages)

    {:noreply, socket}
  end
end
