defmodule VoileWeb.Dashboard.Settings.TokenManagerLive do
  use VoileWeb, :live_view_dashboard

  alias Voile.Schema.System

  def mount(_params, _session, socket) do
    handle_mount_errors do
      # Check permission - if unauthorized, error handling is automatic
      authorize!(socket, "system.settings")

      current_user = socket.assigns.current_scope.user
      tokens = System.list_user_api_tokens(current_user)

      socket =
        socket
        |> assign(:current_user, current_user)
        |> assign(:tokens, tokens)

      {:ok, socket}
    end
  end

  def render(assigns) do
    ~H"""
    <.header>
      <h4>{gettext("API Token Manager")}</h4>

      <:subtitle>{gettext("Manage your API tokens")}</:subtitle>
    </.header>

    <div>
      <!-- Token management UI goes here -->
      <p>{gettext("This is where the token management interface will be implemented.")}</p>
    </div>
    """
  end
end
