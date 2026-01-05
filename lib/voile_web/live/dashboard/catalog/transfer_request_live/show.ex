defmodule VoileWeb.Dashboard.Catalog.TransferRequestLive.Show do
  use VoileWeb, :live_view_dashboard

  alias Voile.Schema.Catalog

  @impl true
  def mount(_params, _session, socket) do
    authorize!(socket, "transfer_requests.read")
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    transfer_request = Catalog.get_transfer_request!(id)

    # Check if current user can review (is from target node)
    can_review =
      transfer_request.status == "pending" &&
        socket.assigns.current_scope.user.unit_id == transfer_request.to_node_id

    socket =
      socket
      |> assign(:page_title, "Transfer Request Details")
      |> assign(:transfer_request, transfer_request)
      |> assign(:can_review, can_review)
      |> assign(:review_notes, "")

    {:noreply, socket}
  end

  @impl true
  def handle_event("approve", _params, socket) do
    transfer_request = socket.assigns.transfer_request
    user_id = socket.assigns.current_scope.user.id

    case Catalog.approve_transfer_request(transfer_request, user_id) do
      {:ok, {updated_transfer, _item}} ->
        {:noreply,
         socket
         |> put_flash(:info, "Transfer request approved successfully")
         |> assign(:transfer_request, Catalog.get_transfer_request!(updated_transfer.id))
         |> assign(:can_review, false)}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to approve transfer request")}
    end
  end

  @impl true
  def handle_event("deny", %{"notes" => notes}, socket) do
    transfer_request = socket.assigns.transfer_request
    user_id = socket.assigns.current_scope.user.id

    case Catalog.deny_transfer_request(transfer_request, user_id, notes) do
      {:ok, updated_transfer} ->
        {:noreply,
         socket
         |> put_flash(:info, "Transfer request denied")
         |> assign(:transfer_request, updated_transfer)
         |> assign(:can_review, false)}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to deny transfer request")}
    end
  end

  @impl true
  def handle_event("validate_notes", %{"notes" => notes}, socket) do
    {:noreply, assign(socket, :review_notes, notes)}
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
