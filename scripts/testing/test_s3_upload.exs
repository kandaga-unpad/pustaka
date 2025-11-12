#!/usr/bin/env elixir

# Test S3 Upload within Phoenix app context
# Usage: mix run scripts/test_s3_upload.exs

IO.puts("\n=== S3 Upload Test ===\n")

IO.puts("Configuration:")
IO.puts("  Region: #{Application.get_env(:voile, :s3_region)}")
IO.puts("  Bucket: #{Application.get_env(:voile, :s3_bucket_name)}")
IO.puts("  Endpoint: #{Application.get_env(:voile, :s3_public_url)}")
IO.puts("")

# Create a test file
test_file = "/tmp/s3_test_#{System.system_time(:microsecond)}.txt"
test_content = "Hello from Voile S3 Upload Test - #{DateTime.utc_now()}"
File.write!(test_file, test_content)

IO.puts("Created test file: #{test_file}")
IO.puts("Content: #{test_content}")
IO.puts("")

# Create an upload map (compatible with Plug.Upload)
upload = %{
  path: test_file,
  filename: "test.txt",
  content_type: "text/plain"
}

IO.puts("Uploading to S3...")

# If the project modules aren't loaded (running with plain `elixir`), show
# a helpful message instead of crashing with UndefinedFunctionError.
if Code.ensure_loaded?(Client.Storage.S3) and function_exported?(Client.Storage.S3, :upload, 2) do
  case Client.Storage.S3.upload(upload, folder: "test") do
    {:ok, url} ->
      IO.puts("✅ SUCCESS: File uploaded!")
      IO.puts("   URL: #{url}")
      IO.puts("")
      IO.puts("You can verify the upload with:")
      IO.puts("   mc ls kandaga/#{Application.get_env(:voile, :s3_bucket_name)}/test/")

      # Cleanup
      File.rm(test_file)

      :ok

    {:error, reason} ->
      IO.puts("❌ ERROR: Upload failed")
      IO.puts("   Reason: #{inspect(reason)}")

      # Cleanup
      File.rm(test_file)

      System.halt(1)
  end
else
  IO.puts("\nThe `Client.Storage.S3` module is not loaded in this plain Elixir run.")

  IO.puts(
    "This script needs to run inside the Mix/Release application so project modules and config are available."
  )

  IO.puts("")
  IO.puts("Recommended ways to run:")
  IO.puts("  - In development (from project root): mix run scripts/testing/test_s3_upload.exs")

  IO.puts(
    "  - In a release on the server: _build/prod/rel/voile/bin/voile eval '\"Code.require_file(\\\"scripts/testing/test_s3_upload.exs\\\")\"' "
  )

  IO.puts("")

  IO.puts(
    "If you intentionally want to run this standalone, start iex -S mix or ensure the app modules are loaded before calling upload."
  )

  # Cleanup local test file
  File.rm(test_file)

  System.halt(1)
end
