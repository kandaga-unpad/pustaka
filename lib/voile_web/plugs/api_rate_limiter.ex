defmodule VoileWeb.Plugs.APIRateLimiter do
  @moduledoc """
  Rate limiter plug using Hammer 7.0+ for API endpoints.

  Limits API requests based on:
  - Authenticated users: by user_id
  - Unauthenticated: by IP address

  Default limits:
  - Authenticated users: 1000 requests per hour
  - Unauthenticated: 100 requests per hour
  """
  import Plug.Conn
  import Phoenix.Controller
  require Logger

  def init(opts) do
    %{
      limit: Keyword.get(opts, :limit, 100),
      scale_ms: Keyword.get(opts, :scale_ms, 60_000),
      authenticated_limit: Keyword.get(opts, :authenticated_limit, 1000)
    }
  end

  def call(conn, opts) do
    identifier = get_identifier(conn)
    limit = get_limit(conn, opts)
    scale_ms = opts.scale_ms

    # Hammer 7.x uses hit/3 (key, scale_ms, limit)
    case Voile.RateLimiter.hit(identifier, scale_ms, limit) do
      {:allow, count} ->
        conn
        |> put_rate_limit_headers(limit, limit - count, scale_ms)

      {:deny, retry_after_ms} ->
        Logger.warning("Rate limit exceeded for #{identifier}")

        conn
        |> put_rate_limit_headers(limit, 0, scale_ms)
        |> put_resp_header("retry-after", to_string(div(retry_after_ms, 1000)))
        |> put_status(:too_many_requests)
        |> put_view(json: VoileWeb.API.ErrorJSON)
        |> render(:"429", %{
          error: "Rate limit exceeded. Please try again later.",
          retry_after_ms: retry_after_ms
        })
        |> halt()
    end
  end

  defp get_identifier(conn) do
    case conn.assigns[:current_user] do
      %{id: user_id} ->
        "api:user:#{user_id}"

      _ ->
        ip = conn.remote_ip |> :inet.ntoa() |> to_string()
        "api:ip:#{ip}"
    end
  end

  defp get_limit(conn, opts) do
    case conn.assigns[:current_user] do
      %{id: _user_id} -> opts.authenticated_limit
      _ -> opts.limit
    end
  end

  defp put_rate_limit_headers(conn, limit, remaining, scale_ms) do
    reset_time = System.system_time(:second) + div(scale_ms, 1000)

    conn
    |> put_resp_header("x-ratelimit-limit", to_string(limit))
    |> put_resp_header("x-ratelimit-remaining", to_string(max(remaining, 0)))
    |> put_resp_header("x-ratelimit-reset", to_string(reset_time))
  end
end
