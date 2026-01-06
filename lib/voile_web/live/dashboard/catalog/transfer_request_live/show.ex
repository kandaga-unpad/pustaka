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
    {color_class, icon, label} =
      case status do
        "pending" -> 
          {"bg-yellow-100 dark:bg-yellow-900 text-yellow-800 dark:text-yellow-200", "hero-clock", "Pending"}
        "approved" -> 
          {"bg-green-100 dark:bg-green-900 text-green-800 dark:text-green-200", "hero-check-circle", "Approved"}
        "denied" -> 
          {"bg-red-100 dark:bg-red-900 text-red-800 dark:text-red-200", "hero-x-circle", "Denied"}
        "cancelled" -> 
          {"bg-gray-100 dark:bg-gray-900 text-gray-800 dark:text-gray-200", "hero-minus-circle", "Cancelled"}
        _ -> 
          {"bg-gray-100 dark:bg-gray-900 text-gray-800 dark:text-gray-200", "hero-question-mark-circle", String.capitalize(status)}
      end

    assigns = %{class: color_class, icon: icon, label: label}

    ~H"""
    <span class={"inline-flex items-center gap-1.5 #{@class} text-sm font-semibold px-4 py-2 rounded-full"}>
      <.icon name={@icon} class="w-5 h-5" />
      {@label}
    </span>
    """
  end
end
