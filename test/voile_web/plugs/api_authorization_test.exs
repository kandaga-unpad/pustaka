defmodule VoileWeb.Plugs.APIAuthorizationTest do
  use VoileWeb.ConnCase, async: true

  import Voile.AccountsFixtures

  alias Voile.Schema.System

  @whitelisted_ip {192, 168, 1, 100}
  @whitelisted_ip_str "192.168.1.100"
  @attacker_ip {10, 0, 0, 5}

  # All tests route through the real :api_authenticated pipeline
  # (accepts → APIAuthorization → rate limiter) by hitting an actual endpoint.

  describe "IP allow-list enforcement (C2: X-Forwarded-For spoofing)" do
    setup do
      user = user_fixture()

      {:ok, _token, plain_token} =
        System.create_api_token(user, %{
          "name" => "ip-locked-token",
          "scopes" => ["read"],
          "ip_whitelist" => [@whitelisted_ip_str]
        })

      %{user: user, plain_token: plain_token}
    end

    @tag :api_ip_security
    test "accepts when remote_ip is whitelisted (ignoring spoofed X-Forwarded-For)", %{
      conn: conn,
      plain_token: plain_token
    } do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{plain_token}")
        |> put_req_header("x-forwarded-for", "5.6.7.8")
        |> with_remote_ip(@whitelisted_ip)
        |> get(~p"/api/v1/collections")

      # Not 403 means the IP check passed and the request reached the controller
      refute conn.status == 403
    end

    @tag :api_ip_security
    test "rejects when remote_ip is NOT whitelisted even with spoofed X-Forwarded-For", %{
      conn: conn,
      plain_token: plain_token
    } do
      # This is the core C2 regression test: before the fix, the spoofed
      # X-Forwarded-For header would bypass the IP allow-list. After the fix,
      # only conn.remote_ip is used, so the spoof is ignored.
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{plain_token}")
        |> put_req_header("x-forwarded-for", @whitelisted_ip_str)
        |> with_remote_ip(@attacker_ip)
        |> get(~p"/api/v1/collections")

      assert conn.status == 403
    end

    @tag :api_ip_security
    test "uses remote_ip, never the raw X-Forwarded-For header", %{
      conn: conn,
      plain_token: plain_token
    } do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{plain_token}")
        |> put_req_header("x-forwarded-for", "203.0.113.99")
        |> with_remote_ip(@whitelisted_ip)
        |> get(~p"/api/v1/collections")

      refute conn.status == 403
    end

    @tag :api_ip_security
    test "rejects when neither remote_ip nor X-Forwarded-For is whitelisted", %{
      conn: conn,
      plain_token: plain_token
    } do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{plain_token}")
        |> put_req_header("x-forwarded-for", "203.0.113.50")
        |> with_remote_ip(@attacker_ip)
        |> get(~p"/api/v1/collections")

      assert conn.status == 403
    end
  end

  describe "token verification without IP whitelist" do
    setup do
      %{user: user_fixture()}
    end

    @tag :api_ip_security
    test "accepts a valid token from any IP when no allow-list is set", %{
      user: user,
      conn: conn
    } do
      {:ok, _token, plain_token} =
        System.create_api_token(user, %{"name" => "open-token", "scopes" => ["read"]})

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{plain_token}")
        |> with_remote_ip({8, 8, 8, 8})
        |> get(~p"/api/v1/collections")

      refute conn.status == 403
    end

    @tag :api_ip_security
    test "rejects an invalid token", %{conn: conn} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer not-a-real-token")
        |> get(~p"/api/v1/collections")

      assert conn.status == 403
    end

    @tag :api_ip_security
    test "rejects a request with no token at all", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/collections")

      assert conn.status == 403
    end
  end

  # Set the actual TCP peer IP on the test conn before dispatching through the
  # router.  This is the value Plug/Pandit exposes as conn.remote_ip and is
  # what APIAuthorization.get_ip_address/1 must rely on.
  defp with_remote_ip(conn, ip), do: %{conn | remote_ip: ip}
end
