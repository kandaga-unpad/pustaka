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

    # Check if current user can review (is super_admin or from target node)
    is_super_admin =
      Enum.any?(socket.assigns.current_scope.user.roles, &(&1.name == "super_admin"))

    can_review =
      transfer_request.status == "pending" &&
        (is_super_admin ||
           socket.assigns.current_scope.user.node_id == transfer_request.to_node_id)

    socket =
      socket
      |> assign(:page_title, gettext("Transfer Request Details"))
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
         |> put_flash(:info, gettext("Transfer request approved successfully"))
         |> assign(:transfer_request, Catalog.get_transfer_request!(updated_transfer.id))
         |> assign(:can_review, false)}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, gettext("Failed to approve transfer request"))}
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
         |> put_flash(:info, gettext("Transfer request denied"))
         |> assign(:transfer_request, updated_transfer)
         |> assign(:can_review, false)}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, gettext("Failed to deny transfer request"))}
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
          {"bg-tone-warning-soft text-voile-warning", "hero-clock", gettext("Pending")}

        "approved" ->
          {"bg-tone-success-soft text-voile-success", "hero-check-circle", gettext("Approved")}

        "denied" ->
          {"bg-tone-error-soft text-voile-error", "hero-x-circle", gettext("Denied")}

        "cancelled" ->
          {"surface-raised text-gray-800 dark:text-gray-200", "hero-minus-circle",
           gettext("Cancelled")}

        _ ->
          {"surface-raised text-gray-800 dark:text-gray-200", "hero-question-mark-circle",
           Gettext.gettext(VoileWeb.Gettext, String.capitalize(status))}
      end

    assigns = %{class: color_class, icon: icon, label: label}

    ~H"""
    <span class={"inline-flex items-center gap-1.5 #{@class} text-sm font-semibold px-4 py-2 rounded-full"}>
      <.icon name={@icon} class="w-5 h-5" /> {@label}
    </span>
    """
  end
end
