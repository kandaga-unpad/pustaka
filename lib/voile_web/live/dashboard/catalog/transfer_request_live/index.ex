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
    user_node_id = socket.assigns.current_scope.user.node_id

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
      |> assign(:page_title, gettext("Transfer Requests"))
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

    {:noreply, push_patch(socket, to: ~p"/manage/catalog/transfers?#{query_params}")}
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

    {:noreply, push_patch(socket, to: ~p"/manage/catalog/transfers?#{query_params}")}
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
           |> put_flash(:info, gettext("Transfer request deleted successfully"))
           |> push_patch(to: ~p"/manage/catalog/transfers")}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, gettext("Failed to delete transfer request"))}
      end
    else
      {:noreply, put_flash(socket, :error, gettext("You cannot delete this transfer request"))}
    end
  end

  defp status_badge(status) do
    {color_class, icon, label} =
      case status do
        "pending" ->
          {"bg-yellow-100 dark:bg-yellow-900 text-yellow-800 dark:text-yellow-200", "hero-clock",
           gettext("Pending")}

        "approved" ->
          {"bg-green-100 dark:bg-green-900 text-green-800 dark:text-green-200",
           "hero-check-circle", gettext("Approved")}

        "denied" ->
          {"bg-red-100 dark:bg-red-900 text-red-800 dark:text-red-200", "hero-x-circle",
           gettext("Denied")}

        "cancelled" ->
          {"bg-gray-100 dark:bg-gray-900 text-gray-800 dark:text-gray-200", "hero-minus-circle",
           gettext("Cancelled")}

        _ ->
          {"bg-gray-100 dark:bg-gray-900 text-gray-800 dark:text-gray-200",
           "hero-question-mark-circle",
           Gettext.gettext(VoileWeb.Gettext, String.capitalize(status))}
      end

    assigns = %{class: color_class, icon: icon, label: label}

    ~H"""
    <span class={"inline-flex items-center gap-1.5 #{@class} text-xs font-semibold px-3 py-1.5 rounded-full"}>
      <.icon name={@icon} class="w-4 h-4" /> {@label}
    </span>
    """
  end
end
