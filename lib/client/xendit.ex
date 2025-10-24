defmodule Client.Xendit do
  @moduledoc """
  Client for interacting with Xendit Payment Gateway API.
  Primarily uses the Payment Link API for fine payments.

  Documentation: https://developers.xendit.co/api-reference/
  """

  require Logger

  @base_url "https://api.xendit.co"

  @doc """
  Creates a payment link for a fine.

  ## Options
  - `:external_id` - Unique ID for the payment (defaults to "fine_{fine_id}_{timestamp}")
  - `:amount` - Amount in IDR (required)
  - `:description` - Payment description
  - `:customer` - Map with customer details (:given_names, :email, :mobile_number)
  - `:success_redirect_url` - URL to redirect after successful payment
  - `:failure_redirect_url` - URL to redirect after failed payment
  - `:items` - List of line items (optional)

  ## Examples

      iex> Client.Xendit.create_payment_link(
        amount: 50000,
        description: "Library Fine Payment",
        customer: %{
          given_names: "John Doe",
          email: "john@example.com"
        }
      )
      {:ok, %{
        "id" => "pl-xxx",
        "external_id" => "fine_123_1234567890",
        "invoice_url" => "https://checkout.xendit.co/web/pl-xxx",
        "amount" => 50000,
        "status" => "PENDING"
      }}
  """
  def create_payment_link(opts \\ []) do
    amount = Keyword.fetch!(opts, :amount)
    description = Keyword.get(opts, :description, "Library Fine Payment")
    external_id = Keyword.get(opts, :external_id, generate_external_id())
    customer = Keyword.get(opts, :customer, %{})
    success_redirect_url = Keyword.get(opts, :success_redirect_url)
    failure_redirect_url = Keyword.get(opts, :failure_redirect_url)
    items = Keyword.get(opts, :items, [])

    body = %{
      external_id: external_id,
      amount: amount,
      description: description,
      customer: customer,
      success_redirect_url: success_redirect_url,
      failure_redirect_url: failure_redirect_url,
      items: items
    }

    # Remove nil values
    body = Map.reject(body, fn {_k, v} -> is_nil(v) or v == [] end)

    case post("/v2/payment_links", body) do
      {:ok, response} ->
        Logger.info("Xendit payment link created: #{response["id"]}")
        {:ok, response}

      {:error, reason} ->
        Logger.error("Failed to create Xendit payment link: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Retrieves a payment link by ID.

  ## Examples

      iex> Client.Xendit.get_payment_link("pl-xxx")
      {:ok, %{
        "id" => "pl-xxx",
        "status" => "PENDING",
        "amount" => 50000
      }}
  """
  def get_payment_link(payment_link_id) do
    case get("/v2/payment_links/#{payment_link_id}") do
      {:ok, response} ->
        {:ok, response}

      {:error, reason} ->
        Logger.error("Failed to get Xendit payment link: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Gets payment link by external_id.

  ## Examples

      iex> Client.Xendit.get_payment_link_by_external_id("fine_123_1234567890")
      {:ok, %{
        "id" => "pl-xxx",
        "external_id" => "fine_123_1234567890",
        "status" => "PAID"
      }}
  """
  def get_payment_link_by_external_id(external_id) do
    case get("/v2/payment_links?external_id=#{external_id}") do
      {:ok, %{"data" => [payment_link | _]}} ->
        {:ok, payment_link}

      {:ok, %{"data" => []}} ->
        {:error, :not_found}

      {:error, reason} ->
        Logger.error("Failed to get Xendit payment link by external_id: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Validates a Xendit webhook callback signature.

  ## Examples

      iex> Client.Xendit.validate_webhook_signature(webhook_token, request_body)
      true
  """
  def validate_webhook_signature(webhook_token, _request_body) do
    # Xendit uses X-CALLBACK-TOKEN header for webhook validation
    # Compare the token from header with your configured webhook verification token
    configured_token = get_webhook_verification_token()

    if configured_token do
      Plug.Crypto.secure_compare(webhook_token, configured_token)
    else
      Logger.warning("Xendit webhook verification token not configured")
      false
    end
  end

  @doc """
  Parses a webhook payload and returns the event data.

  ## Examples

      iex> Client.Xendit.parse_webhook_payload(%{
        "id" => "pl-xxx",
        "external_id" => "fine_123_1234567890",
        "status" => "PAID",
        "paid_amount" => 50000
      })
      {:ok, %{
        payment_link_id: "pl-xxx",
        external_id: "fine_123_1234567890",
        status: "PAID",
        paid_amount: 50000
      }}
  """
  def parse_webhook_payload(payload) when is_map(payload) do
    parsed = %{
      payment_link_id: payload["id"],
      external_id: payload["external_id"],
      status: payload["status"],
      paid_amount: payload["paid_amount"] || payload["amount"],
      payment_method: payload["payment_method"],
      paid_at: payload["paid_at"],
      expired_at: payload["expired_at"],
      failure_reason: payload["failure_reason"]
    }

    {:ok, parsed}
  rescue
    e ->
      Logger.error("Failed to parse Xendit webhook payload: #{inspect(e)}")
      {:error, :invalid_payload}
  end

  # Private HTTP helpers

  defp post(path, body) do
    url = @base_url <> path
    api_key = get_api_key()

    if is_nil(api_key) do
      {:error, :api_key_not_configured}
    else
      auth = Base.encode64("#{api_key}:")

      case Req.post(url,
             json: body,
             headers: [
               {"authorization", "Basic #{auth}"},
               {"content-type", "application/json"}
             ],
             retry: :transient,
             max_retries: 3
           ) do
        {:ok, %Req.Response{status: status, body: body}} when status in 200..299 ->
          {:ok, body}

        {:ok, %Req.Response{status: status, body: body}} ->
          Logger.error("Xendit API error: #{status} - #{inspect(body)}")
          {:error, {:http_error, status, body}}

        {:error, reason} ->
          Logger.error("Xendit API request failed: #{inspect(reason)}")
          {:error, reason}
      end
    end
  end

  defp get(path) do
    url = @base_url <> path
    api_key = get_api_key()

    if is_nil(api_key) do
      {:error, :api_key_not_configured}
    else
      auth = Base.encode64("#{api_key}:")

      case Req.get(url,
             headers: [
               {"authorization", "Basic #{auth}"}
             ],
             retry: :transient,
             max_retries: 3
           ) do
        {:ok, %Req.Response{status: status, body: body}} when status in 200..299 ->
          {:ok, body}

        {:ok, %Req.Response{status: 404}} ->
          {:error, :not_found}

        {:ok, %Req.Response{status: status, body: body}} ->
          Logger.error("Xendit API error: #{status} - #{inspect(body)}")
          {:error, {:http_error, status, body}}

        {:error, reason} ->
          Logger.error("Xendit API request failed: #{inspect(reason)}")
          {:error, reason}
      end
    end
  end

  # Configuration helpers

  defp get_api_key do
    Application.get_env(:voile, :xendit_api_key) ||
      System.get_env("XENDIT_API_KEY")
  end

  defp get_webhook_verification_token do
    Application.get_env(:voile, :xendit_webhook_token) ||
      System.get_env("XENDIT_WEBHOOK_TOKEN")
  end

  defp generate_external_id do
    timestamp = System.system_time(:millisecond)
    random = :crypto.strong_rand_bytes(4) |> Base.encode16(case: :lower)
    "payment_#{timestamp}_#{random}"
  end
end
