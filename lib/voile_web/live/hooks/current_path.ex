defmodule VoileWeb.Live.Hooks.CurrentPath do
  @moduledoc """
  LiveView on-mount hook that ensures `:current_path` and `:current_uri` are
  available in assigns for all LiveViews, and kept up-to-date on navigation.

  - Seeds initial assigns from the HTTP session (set by `VoileWeb.Plugs.GetCurrentPath`).
  - Attaches a `:handle_params` hook so values are refreshed on live navigation
    (push_patch/push_navigate).
  """
  import Phoenix.LiveView
  alias Phoenix.Component

  @doc false
  def on_mount(:default, _params, session, socket) do
    socket =
      socket
      |> Component.assign_new(:current_path, fn -> Map.get(session, "current_path") end)
      |> Component.assign_new(:current_uri, fn -> Map.get(session, "current_uri") end)

    socket =
      attach_hook(socket, :current_path, :handle_params, fn _params, uri, socket ->
        path = URI.parse(uri).path
        {:cont, Component.assign(socket, current_path: path, current_uri: uri)}
      end)

    {:cont, socket}
  end
end
