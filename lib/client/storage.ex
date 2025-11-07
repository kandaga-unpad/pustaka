defmodule Client.Storage do
  @moduledoc """
  Main storage interface that delegates to configured storage adapter.

  ## Configuration

  Set the storage adapter in your config:

      config :voile, :storage_adapter, Client.Storage.S3

  Or use environment variable:

      export VOILE_STORAGE_ADAPTER="s3"  # or "local"

  The adapter is automatically selected at runtime:
  - If VOILE_S3_ACCESS_KEY_ID and VOILE_S3_SECRET_ACCESS_KEY are set, uses S3
  - Otherwise, uses Local filesystem storage

  ## Adapters

  - `Client.Storage.Local` - Store files on local filesystem
  - `Client.Storage.S3` - Store files on S3-compatible storage (AWS S3, MinIO, Backblaze B2, etc.)
  """

  @doc """
  Upload a file using the configured storage adapter.

  ## Options
    * `:adapter` - Override the default storage adapter
    * `:folder` - Specify upload folder (e.g., "thumbnails", "attachments")
    * `:unit_id` - Unit ID for organizing files by unit
    * `:generate_filename` - Whether to generate a unique filename (default: true)
    * `:preserve_extension` - Whether to preserve original file extension (default: true)

  ## Examples

      # Upload with default settings
      {:ok, url} = Client.Storage.upload(upload)

      # Upload to specific folder
      {:ok, url} = Client.Storage.upload(upload, folder: "thumbnails")

      # Upload with unit organization
      {:ok, url} = Client.Storage.upload(upload, folder: "files", unit_id: 123)

      # Override adapter temporarily
      {:ok, url} = Client.Storage.upload(upload, adapter: Client.Storage.Local)
  """
  def upload(file_params, opts \\ []) do
    adapter = get_adapter(opts)
    adapter.upload(file_params, opts)
  end

  @doc """
  Delete a file using the configured storage adapter.

  ## Examples

      {:ok, url} = Client.Storage.delete(url)
      {:ok, url} = Client.Storage.delete(url, adapter: Client.Storage.S3)
  """
  def delete(file_url, opts \\ []) do
    adapter = get_adapter(opts)
    adapter.delete(file_url, opts)
  end

  @doc """
  Generate a presigned URL for the given file key using the configured adapter.

  For S3 adapters this should return a short-lived URL that allows direct GET
  access to the object. For local adapters it may return {:error, :not_supported}.
  """
  def presign(file_key, opts \\ []) do
    adapter = get_adapter(opts)

    if function_exported?(adapter, :presign, 2) do
      adapter.presign(file_key, opts)
    else
      {:error, :not_supported}
    end
  end

  # Private functions

  defp get_adapter(opts) do
    case Keyword.get(opts, :adapter) do
      nil -> get_configured_adapter()
      adapter when is_atom(adapter) -> adapter
    end
  end

  defp get_configured_adapter do
    # First check explicit environment variable
    case System.get_env("VOILE_STORAGE_ADAPTER") do
      "s3" ->
        Client.Storage.S3

      "local" ->
        Client.Storage.Local

      nil ->
        # Fall back to application config (set at runtime based on credentials)
        Application.get_env(:voile, :storage_adapter, Client.Storage.Local)

      adapter_string ->
        # Try to convert string to module atom
        try do
          Module.concat([adapter_string])
        rescue
          ArgumentError -> Application.get_env(:voile, :storage_adapter, Client.Storage.Local)
        end
    end
  end
end
