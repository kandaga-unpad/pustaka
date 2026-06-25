defmodule VoileWeb.XenditWebhookControllerTest do
  use VoileWeb.ConnCase, async: false

  alias Client.Xendit

  @valid_payload %{
    "id" => "pl_test_123",
    "external_id" => "fine_test_123",
    "status" => "PAID",
    "paid_amount" => 50_000
  }

  describe "validate_webhook_signature/2 — token configured" do
    setup do
      Application.put_env(:voile, :xendit_webhook_token, "configured-secret-token")
      on_exit(fn -> Application.delete_env(:voile, :xendit_webhook_token) end)
      :ok
    end

    test "returns true when the token matches the configured value" do
      assert Xendit.validate_webhook_signature("configured-secret-token", @valid_payload)
    end

    test "returns false when the token does not match" do
      refute Xendit.validate_webhook_signature("wrong-token", @valid_payload)
    end

    test "returns false when the token is nil (header missing)" do
      refute Xendit.validate_webhook_signature(nil, @valid_payload)
    end

    test "returns false when the token is an empty string" do
      refute Xendit.validate_webhook_signature("", @valid_payload)
    end

    test "does not crash on a tampered payload (token-only verification)" do
      assert Xendit.validate_webhook_signature("configured-secret-token", %{})
    end
  end

  describe "validate_webhook_signature/2 — token NOT configured" do
    setup do
      Application.delete_env(:voile, :xendit_webhook_token)
      on_exit(fn -> Application.delete_env(:voile, :xendit_webhook_token) end)
      :ok
    end

    test "returns false (fail-closed) when no verification token is configured" do
      refute Xendit.validate_webhook_signature("any-token", @valid_payload)
    end

    test "returns false even for a nil token when unconfigured" do
      refute Xendit.validate_webhook_signature(nil, @valid_payload)
    end
  end

  describe "POST /webhooks/xendit/payment — signature gate" do
    setup do
      token = "webhook-secret-#{System.unique_integer([:positive])}"
      Application.put_env(:voile, :xendit_webhook_token, token)
      on_exit(fn -> Application.delete_env(:voile, :xendit_webhook_token) end)
      %{webhook_token: token}
    end

    @tag :webhook_security
    test "rejects a request with NO X-CALLBACK-TOKEN header", %{conn: conn} do
      conn = post(conn, ~p"/webhooks/xendit/payment", @valid_payload)

      assert json_response(conn, 401)
      assert response(conn, 401) =~ "Invalid webhook signature"
    end

    @tag :webhook_security
    test "rejects a request with a WRONG X-CALLBACK-TOKEN header", %{conn: conn} do
      conn =
        conn
        |> put_req_header("x-callback-token", "definitely-wrong")
        |> post(~p"/webhooks/xendit/payment", @valid_payload)

      assert json_response(conn, 401)
    end

    @tag :webhook_security
    test "rejects an empty X-CALLBACK-TOKEN header", %{conn: conn} do
      conn =
        conn
        |> put_req_header("x-callback-token", "")
        |> post(~p"/webhooks/xendit/payment", @valid_payload)

      assert json_response(conn, 401)
    end

    @tag :webhook_security
    test "passes the signature gate with a VALID token (reaches payment processing)", %{
      conn: conn,
      webhook_token: token
    } do
      conn =
        conn
        |> put_req_header("x-callback-token", token)
        |> post(~p"/webhooks/xendit/payment", @valid_payload)

      # No Payment record exists for this external_id, so the handler returns
      # :not_found → 404.  A 404 (not 401) proves the signature check PASSED
      # and the request was forwarded to Circulation.handle_payment_webhook/1.
      assert json_response(conn, 404)
      assert response(conn, 404) =~ "Payment not found"
    end

    @tag :webhook_security
    test "rejects every request when the verification token is not configured", %{conn: conn} do
      Application.delete_env(:voile, :xendit_webhook_token)

      conn =
        conn
        |> put_req_header("x-callback-token", "anything-at-all")
        |> post(~p"/webhooks/xendit/payment", @valid_payload)

      assert json_response(conn, 401)
    end
  end
end
