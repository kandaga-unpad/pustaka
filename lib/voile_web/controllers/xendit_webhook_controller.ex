defmodule VoileWeb.XenditWebhookController do
  use VoileWeb, :controller
  require Logger

  alias Voile.Schema.Library.Circulation

  @doc """
  Handles Xendit payment webhook callbacks.

  Xendit sends callbacks when payment status changes (paid, expired, failed, etc.).
  The `X-CALLBACK-TOKEN` header is verified against the configured
  `VOILE_XENDIT_WEBHOOK_TOKEN` to ensure the request originates from Xendit
  before any payment state is mutated.
  """
  def payment_callback(conn, params) do
    callback_token =
      conn
      |> get_req_header("x-callback-token")
      |> List.first()

    if Client.Xendit.validate_webhook_signature(callback_token, params) do
      Logger.info("Received Xendit webhook", external_id: params["external_id"])

      case Circulation.handle_payment_webhook(params) do
        {:ok, payment} ->
          Logger.info("Payment webhook processed successfully",
            payment_id: payment.id,
            status: payment.status
          )

          conn
          |> put_status(:ok)
          |> json(%{success: true, payment_id: payment.id})

        {:error, :not_found} ->
          Logger.warning("Payment not found for webhook", external_id: params["external_id"])

          conn
          |> put_status(:not_found)
          |> json(%{error: "Payment not found"})

        {:error, reason} ->
          Logger.error("Failed to process payment webhook", reason: reason)

          conn
          |> put_status(:unprocessable_entity)
          |> json(%{error: "Processing failed"})
      end
    else
      Logger.warning("Rejected Xendit webhook: missing or invalid callback token")

      conn
      |> put_status(:unauthorized)
      |> json(%{error: "Invalid webhook signature"})
    end
  end
end
