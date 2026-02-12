defmodule VoileWeb.Dashboard.Master.PublisherLive.Show do
  use VoileWeb, :live_view_dashboard

  alias Voile.Schema.Master
  alias VoileWeb.Auth.Authorization

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user

    unless Authorization.can?(user, "metadata.manage") do
      socket =
        socket
        |> put_flash(
          :error,
          gettext("Access Denied: You don't have permission to access this page")
        )
        |> push_navigate(to: ~p"/manage/master")

      {:ok, socket}
    else
      {:ok, socket}
    end
  end

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    {:noreply,
     socket
     |> assign(:page_title, page_title(socket.assigns.live_action))
     |> assign(:publishers, Master.get_publishers!(id))}
  end

  defp page_title(:show), do: gettext("Show Publisher")
  defp page_title(:edit), do: gettext("Edit Publisher")
end
