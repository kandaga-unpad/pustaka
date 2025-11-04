defmodule VoileWeb.XenditWebhookController do
  use VoileWeb, :controller
  require Logger

  alias Voile.Schema.Library.Circulation

  @doc """
  Handles Xendit payment webhook callbacks.

  Xendit sends callbacks when payment status changes (paid, expired, failed, etc.).

  Note: Xendit Payment Links webhooks don't require signature verification.
  For production, you can verify the callback comes from Xendit by checking
  the source IP or using webhook verification tokens if configured.
  """
  def payment_callback(conn, params) do
    Logger.info("Received Xendit webhook", params: params)

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
        Logger.error("Failed to process payment webhook", reason: reason, params: params)

        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Processing failed", reason: inspect(reason)})
    end
  end
end
