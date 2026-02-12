defmodule VoileWeb.Dashboard.Master.MasterLive do
  use VoileWeb, :live_view_dashboard
  alias VoileWeb.Auth.Authorization

  def render(assigns) do
    ~H"""
    <div class="">
      <h5>{gettext("Master Dashboard")}</h5>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user

    unless Authorization.can?(user, "metadata.manage") do
      socket =
        socket
        |> put_flash(
          :error,
          gettext("Access Denied: You don't have permission to access this page")
        )
        |> push_navigate(to: ~p"/manage")

      {:ok, socket}
    else
      socket =
        socket
        |> assign(:page_title, gettext("Master Component"))

      {:ok, socket}
    end
  end
end
