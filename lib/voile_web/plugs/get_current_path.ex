defmodule VoileWeb.Plugs.GetCurrentPath do
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    # Compute current path and full URI (path + optional query string)
    current_path = conn.request_path

    current_uri =
      case conn.query_string do
        "" -> current_path
        qs -> current_path <> "?" <> qs
      end

    conn
    |> put_session(:current_path, current_path)
    |> put_session(:current_uri, current_uri)
    |> assign(:current_uri, current_uri)
    |> assign(:current_path, current_path)
  end
end
