defmodule Client.Storage.Local do
  @moduledoc """
  Local filesystem storage adapter.
  """

  @behaviour Client.Storage.Behaviour

  @base_upload_path "priv/static/uploads"
  @base_url_path "/uploads"

  @impl true
  def upload(
        %Plug.Upload{path: tmp_path, filename: original_filename, content_type: content_type},
        opts
      ) do
    folder = Keyword.get(opts, :folder, "files")
    unit_id = Keyword.get(opts, :unit_id, nil)
    generate_filename = Keyword.get(opts, :generate_filename, true)
    preserve_extension = Keyword.get(opts, :preserve_extension, true)

    # Create upload directory with optional unit_id sharding
    upload_dir =
      if unit_id do
        Path.join([@base_upload_path, folder, to_string(unit_id)])
      else
        # For non-unit files, use hash-based sharding to avoid single large directory
        hash =
          :crypto.hash(:md5, original_filename <> to_string(System.system_time()))
          |> Base.encode16()
          |> String.slice(0, 2)

        Path.join([@base_upload_path, folder, hash])
      end

    File.mkdir_p!(upload_dir)

    # Generate filename
    filename =
      if generate_filename do
        generate_unique_filename(original_filename, content_type, preserve_extension)
      else
        original_filename
      end

    destination_path = Path.join([upload_dir, filename])

    case File.cp(tmp_path, destination_path) do
      :ok ->
        # Build URL path including shard directory
        url_path_parts =
          if unit_id do
            [@base_url_path, folder, to_string(unit_id), filename]
          else
            hash = Path.basename(Path.dirname(destination_path))
            [@base_url_path, folder, hash, filename]
          end

        url = Path.join(url_path_parts)
        {:ok, url}

      {:error, reason} ->
        {:error, "Failed to copy file: #{inspect(reason)}"}
    end
  end

  # Support legacy map format
  def upload(%{"file" => %Plug.Upload{} = upload}, opts) do
    upload(upload, opts)
  end

  # Support direct file params
  def upload(file_params, opts) when is_map(file_params) do
    case extract_upload_from_params(file_params) do
      {:ok, upload} -> upload(upload, opts)
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def delete(file_url, _opts) do
    # Convert URL path to filesystem path
    file_path = Path.join(["priv/static", file_url])

    case File.rm(file_path) do
      :ok -> {:ok, file_url}
      # File doesn't exist, consider it deleted
      {:error, :enoent} -> {:ok, file_url}
      {:error, reason} -> {:error, "Failed to delete file: #{inspect(reason)}"}
    end
  end

  # Private functions

  defp generate_unique_filename(original_filename, content_type, preserve_extension) do
    timestamp = System.system_time(:microsecond)
    uuid = Ecto.UUID.generate()

    extension =
      if preserve_extension do
        get_extension(original_filename, content_type)
      else
        ""
      end

    "#{timestamp}-#{uuid}#{extension}"
  end

  defp get_extension(filename, content_type) do
    case Path.extname(filename) do
      "" -> get_extension_from_mime(content_type)
      ext -> ext
    end
  end

  defp get_extension_from_mime(content_type) do
    case MIME.extensions(content_type) do
      [ext | _] -> ".#{ext}"
      [] -> ""
    end
  end

  defp extract_upload_from_params(%{path: path, filename: filename, content_type: content_type}) do
    {:ok, %Plug.Upload{path: path, filename: filename, content_type: content_type}}
  end

  defp extract_upload_from_params(%{
         "path" => path,
         "filename" => filename,
         "content_type" => content_type
       }) do
    {:ok, %Plug.Upload{path: path, filename: filename, content_type: content_type}}
  end

  defp extract_upload_from_params(_), do: {:error, "Invalid file parameters"}

  @doc """
  Local adapter does not support presigned URLs since files are served
  directly via the application. Return `{:error, :not_supported}`.
  """
  @impl true
  def presign(_file_key, _opts \\ []) do
    {:error, :not_supported}
  end
end
