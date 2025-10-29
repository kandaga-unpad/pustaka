defmodule VoileWeb.Plugs.GetCurrentPath do
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    # Get the request path without query string for clean URLs
    current_path = conn.request_path

    conn
    |> assign(:current_uri, current_path)
    |> assign(:current_path, current_path)
  end
end
