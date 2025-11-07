defmodule Client.Storage.AWSHTTPClient do
  @moduledoc """
  HTTP client adapter for AWS SDK that uses Req instead of hackney.

  This allows us to use the already-included Req library for HTTP requests
  instead of adding hackney as an additional dependency.
  """

  @behaviour AWS.HTTPClient

  require Logger

  @impl true
  def request(method, url, body, headers, options) do
    # Convert AWS method atom to Req method
    req_method = method |> to_string() |> String.downcase() |> String.to_atom()

    # Build Req request options
    req_options = [
      method: req_method,
      url: url,
      headers: headers,
      body: body,
      receive_timeout: Keyword.get(options, :timeout, 30_000),
      retry: false,
      # Disable automatic decompression to preserve content as-is
      compressed: false,
      # For development/testing with self-signed certificates, you may need to disable SSL verification
      # Remove or adjust this in production
      connect_options:
        if Mix.env() == :dev do
          [transport_opts: [verify: :verify_none]]
        else
          []
        end
    ]

    Logger.debug("AWS HTTP Request: #{req_method} #{url}")

    # Make the request
    case Req.request(req_options) do
      {:ok, %Req.Response{status: status, headers: resp_headers, body: resp_body}} ->
        # Convert headers to the format AWS SDK expects
        # Req returns headers as a map, AWS expects a list of tuples with lowercase keys
        aws_headers =
          Enum.map(resp_headers, fn {key, values} ->
            # Handle both single values and lists
            value =
              case values do
                [v | _] -> v
                v when is_binary(v) -> v
                _ -> ""
              end

            {String.downcase(to_string(key)), value}
          end)

        Logger.debug("AWS HTTP Response: #{status}")

        {:ok, %{status_code: status, headers: aws_headers, body: resp_body}}

      {:error, %Req.Response{status: status} = response} ->
        Logger.error("AWS HTTP Error Response: #{status}")
        {:error, %{status_code: status, body: response.body}}

      {:error, reason} ->
        Logger.error("AWS HTTP Request Failed: #{inspect(reason)}")
        {:error, reason}
    end
  end
end
