defmodule VoileWeb.Dashboard.Catalog.ItemLive.Show do
  use VoileWeb, :live_view_dashboard

  alias Voile.Schema.Catalog

  # Import badge helper functions
  import VoileWeb.VoileComponents,
    only: [
      status_badge_class: 1,
      condition_badge_class: 1,
      availability_badge_class: 1,
      access_level_badge_class: 1
    ]

  @impl true
  def mount(_params, _session, socket) do
    # Check read permission for viewing item details
    authorize!(socket, "items.read")

    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    item = Catalog.get_item!(id)

    # Verify user has access to this item's unit
    current_user = socket.assigns.current_scope.user

    if Catalog.is_user_admin?(current_user) or item.unit_id == current_user.node_id do
      {:noreply,
       socket
       |> assign(:page_title, page_title(socket.assigns.live_action))
       |> assign(:item, item)}
    else
      {:noreply,
       socket
       |> put_flash(:error, "Access Denied: You don't have permission to view this item")
       |> push_navigate(to: ~p"/manage/catalog/items")}
    end
  end

  defp page_title(:show), do: "Show Item"
  defp page_title(:edit), do: "Edit Item"

  # Helper function to format price with Indonesian Rupiah format
  defp format_price(nil), do: "-"

  defp format_price(price) when is_number(price) do
    price
    |> :erlang.float_to_binary(decimals: 0)
    |> String.replace(~r/\B(?=(\d{3})+(?!\d))/, ".")
  end
end
