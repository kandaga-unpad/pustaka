defmodule VoileWeb.Dashboard.Catalog.TransferRequestLive.Index do
  use VoileWeb, :live_view_dashboard

  alias Voile.Schema.Catalog
  alias Voile.Schema.System

  @impl true
  def mount(_params, _session, socket) do
    # Check permission
    authorize!(socket, "transfer_requests.read")

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    status_filter = Map.get(params, "status")
    node_filter = Map.get(params, "node_id")

    filters = %{}
    filters = if status_filter, do: Map.put(filters, :status, status_filter), else: filters
    filters = if node_filter, do: Map.put(filters, :to_node_id, node_filter), else: filters

    # Get user's node if they have one
    user_node_id = socket.assigns.current_scope.user.unit_id

    # If user has a node, show transfers to their node by default
    filters =
      if user_node_id && !status_filter && !node_filter do
        Map.put(filters, :to_node_id, user_node_id)
      else
        filters
      end

    transfer_requests = Catalog.list_transfer_requests(filters)
    nodes = System.list_nodes()

    socket =
      socket
      |> assign(:page_title, "Transfer Requests")
      |> assign(:transfer_requests, transfer_requests)
      |> assign(:nodes, nodes)
      |> assign(:status_filter, status_filter)
      |> assign(:node_filter, node_filter)
      |> assign(:user_node_id, user_node_id)

    {:noreply, socket}
  end

  @impl true
  def handle_event("filter", %{"status" => status}, socket) do
    query_params = %{}

    query_params =
      if status != "", do: Map.put(query_params, "status", status), else: query_params

    query_params =
      if socket.assigns.node_filter do
        Map.put(query_params, "node_id", socket.assigns.node_filter)
      else
        query_params
      end

    {:noreply, push_patch(socket, to: ~p"/manage/transfers?#{query_params}")}
  end

  @impl true
  def handle_event("filter_node", %{"node_id" => node_id}, socket) do
    query_params = %{}

    query_params =
      if node_id != "", do: Map.put(query_params, "node_id", node_id), else: query_params

    query_params =
      if socket.assigns.status_filter do
        Map.put(query_params, "status", socket.assigns.status_filter)
      else
        query_params
      end

    {:noreply, push_patch(socket, to: ~p"/manage/transfers?#{query_params}")}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    transfer_request = Catalog.get_transfer_request!(id)

    # Only allow deletion by requester and if still pending
    if transfer_request.requested_by_id == socket.assigns.current_scope.user.id &&
         transfer_request.status == "pending" do
      case Catalog.delete_transfer_request(transfer_request) do
        {:ok, _} ->
          {:noreply,
           socket
           |> put_flash(:info, "Transfer request deleted successfully")
           |> push_patch(to: ~p"/manage/transfers")}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to delete transfer request")}
      end
    else
      {:noreply, put_flash(socket, :error, "You cannot delete this transfer request")}
    end
  end

  defp status_badge(status) do
    {color_class, label} =
      case status do
        "pending" -> {"bg-yellow-100 text-yellow-800", "Pending"}
        "approved" -> {"bg-green-100 text-green-800", "Approved"}
        "denied" -> {"bg-red-100 text-red-800", "Denied"}
        "cancelled" -> {"bg-gray-100 text-gray-800", "Cancelled"}
        _ -> {"bg-gray-100 text-gray-800", String.capitalize(status)}
      end

    assigns = %{class: color_class, label: label}

    ~H"""
    <span class={"#{@class} text-xs font-medium px-2.5 py-1 rounded-full"}>
      {@label}
    </span>
    """
  end
end
