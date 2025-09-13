defmodule VoileWeb.Dashboard.Circulation.CirculationHistory.Show do
  use VoileWeb, :live_view_dashboard
  import VoileWeb.Dashboard.Circulation.Helpers
  import VoileWeb.Dashboard.Circulation.Components

  alias Voile.Schema.Library.Circulation

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    history = Circulation.get_circulation_history!(id)

    {:noreply,
     socket
     |> assign(:history, history)
     |> assign(:page_title, "Circulation History Details")}
  end

  # Import helper functions
  # defdelegate status_badge_class(status), to: VoileWeb.Dashboard.Circulation.Helpers
  # defdelegate format_datetime(datetime), to: VoileWeb.Dashboard.Circulation.Helpers

  def action_badge_class("checkout"), do: "bg-blue-100 text-blue-800"
  def action_badge_class("return"), do: "bg-green-100 text-green-800"
  def action_badge_class("renewal"), do: "bg-yellow-100 text-yellow-800"
  def action_badge_class("reservation"), do: "bg-purple-100 text-purple-800"
  def action_badge_class("cancel"), do: "bg-red-100 text-red-800"
  def action_badge_class(_), do: "bg-gray-100 text-gray-800"
end
