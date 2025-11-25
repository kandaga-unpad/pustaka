defmodule VoileWeb.Plugs.APIAuthorization do
  import Plug.Conn
  import Phoenix.Controller

  def init(opts), do: opts

  def call(conn, opts) do
    required_scope = Keyword.get(opts, :scope)

    token = get_token_from_header(conn) || get_token_from_params(conn)

    if token do
      verify_token(conn, token, required_scope)
    else
      unauthorized(conn)
    end
  end

  defp get_token_from_header(conn) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] -> token
      _ -> nil
    end
  end

  defp get_token_from_params(conn) do
    conn.params["token"] || conn.query_params["token"]
  end

  defp verify_token(conn, token, required_scope) do
    ip_address = get_ip_address(conn)

    case Voile.Schema.System.verify_api_token(token, ip_address: ip_address) do
      {:ok, user, api_token} ->
        if scope_authorized?(api_token, required_scope) do
          conn
          |> assign(:current_user, user)
          |> assign(:api_token, api_token)
        else
          forbidden(conn)
        end

      {:error, :invalid_token} ->
        unauthorized(conn)

      {:error, :ip_not_allowed} ->
        forbidden(conn, "IP address not allowed")
    end
  end

  defp scope_authorized?(_token, nil), do: true

  defp scope_authorized?(token, required_scope) do
    Voile.Schema.System.UserApiToken.has_scope?(token, required_scope)
  end

  defp get_ip_address(conn) do
    case get_req_header(conn, "x-forwarded-for") do
      [ip | _] -> ip
      [] -> conn.remote_ip |> :inet.ntoa() |> to_string()
    end
  end

  defp unauthorized(conn, message \\ "Unauthorized access") do
    conn
    |> put_status(:forbidden)
    |> put_view(json: VoileWeb.API.ErrorJSON)
    |> render(:"401", %{message: message, code: 401})
    |> halt()
  end

  defp forbidden(conn, message \\ "Forbidden access") do
    conn
    |> put_status(:forbidden)
    |> put_view(json: VoileWeb.API.ErrorJSON)
    |> render(:"403", %{message: message, code: 403})
    |> halt()
  end
end
