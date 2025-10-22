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
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    dbg(Catalog.get_item!(id))

    {:noreply,
     socket
     |> assign(:page_title, page_title(socket.assigns.live_action))
     |> assign(:item, Catalog.get_item!(id))}
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
