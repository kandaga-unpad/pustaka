defmodule VoileWeb.Dashboard.Glam.Library.Circulation.CirculationHistory.Show do
  use VoileWeb, :live_view_dashboard
  import VoileWeb.Dashboard.Glam.Library.Circulation.Helpers

  alias Voile.Schema.Library.Circulation
  alias VoileWeb.Auth.Authorization

  @impl true
  def mount(_params, _session, socket) do
    # Check permission for viewing circulation history
    unless Authorization.can?(socket, "circulation.view_history") do
      socket =
        socket
        |> put_flash(:error, "You don't have permission to access circulation history details")
        |> push_navigate(to: ~p"/manage/glam/library/circulation")

      {:ok, socket}
    else
      {:ok, socket}
    end
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
  # defdelegate status_badge_class(status), to: VoileWeb.Dashboard.Glam.Library.Circulation.Helpers
  # defdelegate format_datetime(datetime), to: VoileWeb.Dashboard.Glam.Library.Circulation.Helpers

  def action_badge_class("checkout"), do: "bg-voile-info/10 text-voile-info"
  def action_badge_class("return"), do: "bg-voile-success/10 text-voile-success"
  def action_badge_class("renewal"), do: "bg-voile-warning/10 text-voile-warning"
  def action_badge_class("reservation"), do: "bg-voile-primary/10 text-voile-primary"
  def action_badge_class("cancel"), do: "bg-voile-error/10 text-voile-error"
  def action_badge_class(_), do: "bg-gray-100 text-gray-800"
end
