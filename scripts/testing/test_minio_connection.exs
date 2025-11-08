#!/usr/bin/env elixir

# MinIO Connection Test Script
# Usage: elixir scripts/test_minio_connection.exs

Mix.install([
  {:aws, "~> 1.0"},
  {:req, "~> 0.4"},
  {:jason, "~> 1.4"}
])

defmodule AWS.HTTPClient.Req do
  @moduledoc """
  HTTP client adapter for AWS that uses Req instead of hackney.
  """

  @behaviour AWS.HTTPClient

  @impl true
  def request(method, url, body, headers, options) do
    # Convert AWS method atom to Req method
    req_method = method |> to_string() |> String.downcase() |> String.to_atom()

    IO.puts("  DEBUG: Requesting #{req_method} #{url}")

    # Build Req request
    request =
      Req.new(
        method: req_method,
        url: url,
        headers: headers,
        body: body,
        receive_timeout: Keyword.get(options, :timeout, 30_000),
        retry: false,
        # Allow self-signed certificates in development
        connect_options: [
          transport_opts: [
            verify: :verify_none
          ]
        ]
      )

    case Req.request(request) do
      {:ok, %Req.Response{status: status, headers: resp_headers, body: resp_body}} ->
        # Convert headers to the format AWS expects
        aws_headers =
          Enum.map(resp_headers, fn {k, v} ->
            {String.downcase(k), List.wrap(v) |> List.first()}
          end)

        {:ok, %{status_code: status, headers: aws_headers, body: resp_body}}

      {:error, reason} ->
        IO.puts("  DEBUG: Request failed with: #{inspect(reason)}")
        {:error, reason}
    end
  end
end

defmodule MinIOTest do
  def run do
    IO.puts("\n=== MinIO Connection Test ===\n")

    # Get configuration from environment variables
    config = %{
      region: System.get_env("VOILE_S3_REGION") || "us-east-1",
      access_key: System.get_env("VOILE_S3_ACCESS_KEY_ID"),
      secret_key: System.get_env("VOILE_S3_SECRET_ACCESS_KEY"),
      bucket: System.get_env("VOILE_S3_BUCKET_NAME") || "glam-storage",
      endpoint: System.get_env("VOILE_S3_PUBLIC_URL") || "https://library.unpad.ac.id"
    }

    IO.puts("Configuration:")
    IO.puts("  Region: #{config.region}")
    IO.puts("  Access Key: #{if config.access_key, do: mask(config.access_key), else: "NOT SET"}")
    IO.puts("  Secret Key: #{if config.secret_key, do: mask(config.secret_key), else: "NOT SET"}")
    IO.puts("  Bucket: #{config.bucket}")
    IO.puts("  Endpoint: #{config.endpoint}")
    IO.puts("")

    # Validate configuration
    unless config.access_key && config.secret_key do
      IO.puts("❌ ERROR: Access key and secret key are required!")
      IO.puts("   Please set VOILE_S3_ACCESS_KEY_ID and VOILE_S3_SECRET_ACCESS_KEY")
      System.halt(1)
    end

    # Test connection
    IO.puts("Testing connection...")

    # Parse the endpoint to extract just the host
    endpoint_uri = URI.parse(config.endpoint)
    endpoint_host = endpoint_uri.host || config.endpoint

    client =
      AWS.Client.create(config.access_key, config.secret_key, config.region)
      |> AWS.Client.put_endpoint(endpoint_host)
      |> Map.put(:http_client, {AWS.HTTPClient.Req, []})

    # Try to list bucket contents (limited to 1 item)
    case AWS.S3.list_objects_v2(client, config.bucket, %{"max-keys" => "1"}) do
      {:ok, response, %{status_code: 200}} ->
        IO.puts("✅ SUCCESS: Connected to MinIO successfully!")
        IO.puts("")
        IO.puts("Bucket Info:")

        # The response body is already parsed XML
        case response do
          %{"ListBucketResult" => result} ->
            key_count = result["KeyCount"] || "0"
            IO.puts("  Objects found: #{key_count}")

            if contents = result["Contents"] do
              contents_list = if is_list(contents), do: contents, else: [contents]

              if length(contents_list) > 0 do
                first = List.first(contents_list)
                IO.puts("  Sample object: #{first["Key"]}")
                IO.puts("  Size: #{first["Size"]} bytes")
                IO.puts("  Last Modified: #{first["LastModified"]}")
              end
            else
              IO.puts("  Bucket is empty")
            end

          _ ->
            IO.puts("  Response format: #{inspect(response)}")
        end

        IO.puts("")
        IO.puts("✅ Your MinIO configuration is correct!")
        IO.puts("   You can now use the storage adapter in your application.")

      {:ok, _response, %{status_code: status_code}} ->
        IO.puts("❌ ERROR: Unexpected status code #{status_code}")
        IO.puts("   Check your bucket name and permissions")
        System.halt(1)

      {:error, reason} ->
        IO.puts("❌ ERROR: Connection failed")
        IO.puts("   Reason: #{inspect(reason)}")
        IO.puts("")
        IO.puts("Common issues:")
        IO.puts("  1. Wrong endpoint URL")
        IO.puts("  2. Invalid access key or secret key")
        IO.puts("  3. Bucket doesn't exist")
        IO.puts("  4. Network/firewall issues")
        IO.puts("  5. SSL certificate issues")
        System.halt(1)
    end
  end

  defp mask(string) when is_binary(string) do
    len = String.length(string)
    visible = min(4, div(len, 2))

    if len <= 4 do
      String.duplicate("*", len)
    else
      prefix = String.slice(string, 0, visible)
      suffix = String.slice(string, -visible, visible)
      "#{prefix}#{"*" |> String.duplicate(len - visible * 2)}#{suffix}"
    end
  end
end

MinIOTest.run()
