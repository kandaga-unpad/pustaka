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

  # Only import if modules exist (for attachment deletion)
  if Code.ensure_loaded?(Voile.Repo) and Code.ensure_loaded?(Voile.Schema.Catalog.Attachment) do
    # No aliases needed, using full module names
  end

  @doc """
  Upload a file using the configured storage adapter.

  ## Options
    * `:adapter` - Override the default storage adapter
    * `:folder` - Specify upload folder (e.g., "thumbnails", "attachments")
    * `:unit_id` - Unit ID for organizing files by unit
    * `:generate_filename` - Whether to generate a unique filename (default: true)
    * `:preserve_extension` - Whether to preserve original file extension (default: true)
    * `:create_attachment` - Whether to create an attachment record in the database (default: false)
    * `:attachable_id` - ID of the entity the attachment belongs to (required if create_attachment: true)
    * `:attachable_type` - Type of entity the attachment belongs to (required if create_attachment: true)
    * `:access_level` - Access level for the attachment (default: "restricted")
    * `:file_type` - Type of file (default: inferred from mime_type)

  ## Examples

      # Upload with default settings
      {:ok, url} = Client.Storage.upload(upload)

      # Upload to specific folder
      {:ok, url} = Client.Storage.upload(upload, folder: "thumbnails")

      # Upload with attachment creation
      {:ok, url} = Client.Storage.upload(upload,
        create_attachment: true,
        attachable_id: user_id,
        attachable_type: "User",
        access_level: "restricted"
      )
  """
  def upload(file_params, opts \\ []) do
    adapter = get_adapter(opts)

    case adapter.upload(file_params, opts) do
      {:ok, url} ->
        # Create attachment record if requested
        if Keyword.get(opts, :create_attachment, false) do
          create_attachment_record(url, file_params, opts)
        end

        {:ok, url}

      error ->
        error
    end
  end

  @doc """
  Delete a file using the configured storage adapter.

  ## Options
    * `:adapter` - Override the default storage adapter
    * `:delete_attachment` - If true, also delete the attachment record from database (default: false)

  ## Examples

      {:ok, url} = Client.Storage.delete(url)
      {:ok, url} = Client.Storage.delete(url, adapter: Client.Storage.S3)
      {:ok, url} = Client.Storage.delete(url, delete_attachment: true)
  """
  def delete(file_url, opts \\ []) do
    # Delete attachment record if requested
    if Keyword.get(opts, :delete_attachment, false) do
      delete_attachment_record(file_url)
    end

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

  if Code.ensure_loaded?(Voile.Repo) and Code.ensure_loaded?(Voile.Schema.Catalog.Attachment) do
    defp create_attachment_record(url, file_params, opts) do
      # Extract file information
      filename = file_params[:filename] || "unknown"
      content_type = file_params[:content_type] || "application/octet-stream"
      size = file_params[:size] || 0

      # Determine file type from mime type
      file_type =
        cond do
          String.starts_with?(content_type, "image/") -> "image"
          String.starts_with?(content_type, "video/") -> "video"
          String.starts_with?(content_type, "audio/") -> "audio"
          String.starts_with?(content_type, "text/") -> "document"
          String.starts_with?(content_type, "application/pdf") -> "document"
          true -> "file"
        end

      # Get attachment options
      attachable_id = Keyword.get(opts, :attachable_id)
      attachable_type = Keyword.get(opts, :attachable_type)
      access_level = Keyword.get(opts, :access_level, "restricted")
      custom_file_type = Keyword.get(opts, :file_type)

      # Use custom file_type if provided, otherwise use inferred
      final_file_type = custom_file_type || file_type

      # Validate required fields
      if is_nil(attachable_id) or is_nil(attachable_type) do
        # Log warning but don't fail the upload
        require Logger
        Logger.warning("Attachment creation skipped: missing attachable_id or attachable_type")
        :ok
      else
        attachment_params = %{
          file_name: filename,
          original_name: filename,
          file_path: url,
          file_key: url,
          file_size: size,
          mime_type: content_type,
          file_type: final_file_type,
          attachable_id: attachable_id,
          attachable_type: attachable_type,
          access_level: access_level
        }

        case Voile.Repo.insert(
               Voile.Schema.Catalog.Attachment.changeset(
                 %Voile.Schema.Catalog.Attachment{},
                 attachment_params
               )
             ) do
          {:ok, _attachment} ->
            :ok

          {:error, changeset} ->
            # Log error but don't fail the upload
            require Logger
            Logger.error("Failed to create attachment record: #{inspect(changeset.errors)}")
            :ok
        end
      end
    end

    defp delete_attachment_record(file_url) do
      case Voile.Repo.get_by(Voile.Schema.Catalog.Attachment, file_path: file_url) do
        nil -> :ok
        attachment -> Voile.Repo.delete(attachment)
      end
    end
  else
    defp create_attachment_record(_url, _file_params, _opts), do: :ok
    defp delete_attachment_record(_file_url), do: :ok
  end
end
