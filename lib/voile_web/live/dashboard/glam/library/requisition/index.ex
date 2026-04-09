defmodule VoileWeb.Dashboard.Glam.Library.Requisition.Index do
  use VoileWeb, :live_view_dashboard
  import VoileWeb.Dashboard.Glam.Library.Circulation.Helpers

  alias Voile.Schema.Library.Circulation
  alias VoileWeb.Auth.Authorization
  alias Voile.Schema.System

  @impl true
  def mount(_params, _session, socket) do
    unless Authorization.can?(socket, "circulation.view_transactions") do
      socket =
        socket
        |> put_flash(:error, "You don't have permission to access requisition management")
        |> push_navigate(to: ~p"/manage/glam/library")

      {:ok, socket}
    else
      user = socket.assigns.current_scope.user
      is_super_admin = Authorization.is_super_admin?(user)

      {node_id, nodes, selected_node_id} =
        if is_super_admin do
          {nil, System.list_nodes(), nil}
        else
          {user.node_id, [], user.node_id}
        end

      page = 1
      per_page = 15
      filters = %{status: "all", type: "all"}

      {requisitions, total_pages, _} =
        if is_super_admin do
          Circulation.list_requisitions_paginated_with_filters(page, per_page, filters)
        else
          Circulation.list_requisitions_paginated_with_filters_by_node(
            page,
            per_page,
            filters,
            node_id
          )
        end

      socket =
        socket
        |> stream(:requisitions, requisitions)
        |> assign(:page, page)
        |> assign(:total_pages, total_pages)
        |> assign(:filter_status, "all")
        |> assign(:filter_type, "all")
        |> assign(:node_id, node_id)
        |> assign(:is_super_admin, is_super_admin)
        |> assign(:nodes, nodes)
        |> assign(:selected_node_id, selected_node_id)
        |> assign(:page_title, "Library Requisitions")
        |> assign(:action_modal, nil)

      {:ok, socket}
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
  def handle_event("select_node", %{"node_id" => node_id_str}, socket) do
    node_id = if node_id_str in [nil, "all", ""], do: nil, else: String.to_integer(node_id_str)

    socket =
      socket
      |> assign(:node_id, node_id)
      |> assign(:selected_node_id, node_id)
      |> reload_requisitions()

    {:noreply, socket}
  end

  @impl true
  def handle_event("paginate", %{"page" => page_str}, socket) do
    page = String.to_integer(page_str)
    per_page = 15
    is_super_admin = socket.assigns.is_super_admin
    node_id = socket.assigns.node_id

    filters = %{
      status: socket.assigns.filter_status,
      type: socket.assigns.filter_type
    }

    {requisitions, total_pages, _} =
      if is_super_admin do
        Circulation.list_requisitions_paginated_with_filters(page, per_page, filters)
      else
        Circulation.list_requisitions_paginated_with_filters_by_node(
          page,
          per_page,
          filters,
          node_id
        )
      end

    socket =
      socket
      |> stream(:requisitions, requisitions, reset: true)
      |> assign(:page, page)
      |> assign(:total_pages, total_pages)

    {:noreply, socket}
  end

  @impl true
  def handle_event("update_status", %{"id" => id, "status" => status}, socket) do
    requisition = Circulation.get_requisition!(id)

    case Circulation.update_requisition(requisition, %{status: status}) do
      {:ok, updated} ->
        {:noreply,
         socket
         |> stream_insert(:requisitions, updated)
         |> put_flash(:info, "Status updated to #{status}.")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to update status.")}
    end
  end

  @impl true
  def handle_event("open_action_modal", %{"req_id" => req_id, "action" => action}, socket) do
    requisition = Circulation.get_requisition!(req_id)

    {:noreply,
     assign(socket, :action_modal, %{
       action: action,
       req_id: req_id,
       staff_notes: requisition.staff_notes || ""
     })}
  end

  @impl true
  def handle_event("close_action_modal", _params, socket) do
    {:noreply, assign(socket, :action_modal, nil)}
  end

  @impl true
  def handle_event("confirm_status_action", %{"staff_notes" => notes}, socket) do
    %{action: action, req_id: req_id} = socket.assigns.action_modal

    new_status =
      case action do
        "approve" -> "approved"
        "reject" -> "rejected"
        "fulfill" -> "fulfilled"
        _ -> action
      end

    requisition = Circulation.get_requisition!(req_id)

    case Circulation.update_requisition(requisition, %{status: new_status, staff_notes: notes}) do
      {:ok, updated} ->
        {:noreply,
         socket
         |> assign(:action_modal, nil)
         |> stream_insert(:requisitions, updated)
         |> put_flash(:info, "Requisition #{new_status}.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update requisition.")}
    end
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    requisition = Circulation.get_requisition!(id)

    case Circulation.delete_requisition(requisition) do
      {:ok, _} ->
        {:noreply,
         socket
         |> stream_delete(:requisitions, requisition)
         |> put_flash(:info, "Requisition deleted.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete requisition.")}
    end
  end

  defp reload_requisitions(socket) do
    page = 1
    per_page = 15
    is_super_admin = socket.assigns.is_super_admin
    node_id = socket.assigns.node_id

    filters = %{
      status: socket.assigns.filter_status,
      type: socket.assigns.filter_type
    }

    {requisitions, total_pages, _} =
      if is_super_admin do
        Circulation.list_requisitions_paginated_with_filters(page, per_page, filters)
      else
        Circulation.list_requisitions_paginated_with_filters_by_node(
          page,
          per_page,
          filters,
          node_id
        )
      end

    socket
    |> stream(:requisitions, requisitions, reset: true)
    |> assign(:page, page)
    |> assign(:total_pages, total_pages)
  end
end
