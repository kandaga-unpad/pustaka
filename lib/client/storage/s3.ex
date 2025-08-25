defmodule Client.Storage.S3 do
  @moduledoc """
  S3-compatible storage adapter (works with AWS S3, Backblaze B2, etc.)
  """

  @behaviour Client.Storage.Behaviour

  @s3_region Application.compile_env(:voile, :s3_region, nil)
  @s3_access_key_id Application.compile_env(:voile, :s3_access_key_id, nil)
  @s3_secret_key_access Application.compile_env(:voile, :s3_secret_key_access, nil)
  @s3_bucket_name Application.compile_env(:voile, :s3_bucket_name, nil)
  @s3_public_url Application.compile_env(:voile, :s3_public_url, nil)

  @impl true
  def upload(
        %Plug.Upload{path: tmp_path, filename: original_filename, content_type: content_type},
        opts
      ) do
    folder = Keyword.get(opts, :folder, "files")
    generate_filename = Keyword.get(opts, :generate_filename, true)
    preserve_extension = Keyword.get(opts, :preserve_extension, true)

    # Generate S3 key (path)
    filename =
      if generate_filename do
        generate_unique_filename(original_filename, content_type, preserve_extension)
      else
        original_filename
      end

    file_key = Path.join([folder, filename])

    # Read file and calculate MD5
    file_content = File.read!(tmp_path)
    md5 = :crypto.hash(:md5, file_content) |> Base.encode64()

    case put_object(file_key, file_content, content_type, md5) do
      {:ok, _} ->
        url = build_public_url(file_key)
        {:ok, url}

      {:error, reason} ->
        {:error, "S3 upload failed: #{inspect(reason)}"}
    end
  end

  # Support legacy map format
  def upload(%{"file" => %Plug.Upload{} = upload, "Content-Type" => content_type}, opts) do
    # Override content type if provided in params
    updated_upload = %{upload | content_type: content_type}
    upload(updated_upload, opts)
  end

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

  def delete(file_url), do: delete(file_url, [])

  @impl true
  def delete(file_url, _opts) do
    # Extract file key from URL
    file_key = extract_file_key_from_url(file_url)

    if is_binary(file_key) and file_key != "" and file_key != file_url do
      case delete_object(file_key) do
        {:ok, _} -> {:ok, file_url}
        {:error, reason} -> {:error, "S3 delete failed: #{inspect(reason)}"}
      end
    else
      {:error, "Invalid file URL: could not extract file key"}
    end
  end

  # Private functions

  defp put_object(file_key, file_content, content_type, md5) do
    try do
      get_client()
      |> AWS.S3.put_object(
        to_string(@s3_bucket_name),
        to_string(file_key),
        %{
          body: file_content,
          content_md5: md5,
          content_type: content_type
        }
      )
      |> case do
        {:ok, _, %{status_code: 200}} -> {:ok, :uploaded}
        response -> {:error, "Upload failed: #{inspect(response)}"}
      end
    rescue
      e -> {:error, "Exception during upload: #{Exception.message(e)}"}
    catch
      :exit, reason -> {:error, "Process exited: #{inspect(reason)}"}
      :throw, reason -> {:error, "Thrown: #{inspect(reason)}"}
    end
  end

  defp delete_object(file_key) do
    try do
      get_client()
      |> AWS.S3.delete_object(to_string(@s3_bucket_name), to_string(file_key), %{})
      |> case do
        {:ok, _, %{status_code: code}} when code in [200, 204] -> {:ok, :deleted}
        response -> {:error, "Delete failed: #{inspect(response)}"}
      end
    rescue
      e -> {:error, "Exception during delete: #{Exception.message(e)}"}
    catch
      :exit, reason -> {:error, "Process exited: #{inspect(reason)}"}
      :throw, reason -> {:error, "Thrown: #{inspect(reason)}"}
    end
  end

  defp get_client do
    @s3_access_key_id
    |> AWS.Client.create(@s3_secret_key_access, @s3_region)
    |> AWS.Client.put_endpoint(@s3_public_url)
  end

  defp build_public_url(file_key) do
    "#{@s3_public_url}/#{@s3_bucket_name}/#{file_key}"
  end

  defp extract_file_key_from_url(url) do
    # Extract the file key from a full S3 URL
    # Example: https://s3.region.backblazeb2.com/bucket/folder/file.jpg -> folder/file.jpg
    uri = URI.parse(url)

    case String.split(uri.path, "/", trim: true) do
      [_bucket | key_parts] -> Enum.join(key_parts, "/")
      # Fallback to original URL if parsing fails
      _ -> url
    end
  end

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
end
