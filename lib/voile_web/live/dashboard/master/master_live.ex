defmodule VoileWeb.Dashboard.Master.MasterLive do
  use VoileWeb, :live_view_dashboard

  def render(assigns) do
    ~H"""
    <div class="">
      <h5>{gettext("Master Dashboard")}</h5>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:page_title, gettext("Master Component"))

    {:ok, socket}
  end
end
