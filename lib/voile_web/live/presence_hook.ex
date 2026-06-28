defmodule VoileWeb.Live.PresenceHook do
  @moduledoc """
  LiveView hook to track connected users.
  Tracks all connections and separately counts authenticated users.
  """

  import Phoenix.LiveView

  def on_mount(:default, _params, _session, socket) do
    if connected?(socket) do
      current_scope = socket.assigns[:current_scope]
      user = if current_scope, do: current_scope.user, else: nil
      VoileWeb.UserPresence.track_user(user)
    end

    {:cont, socket}
  end
end
