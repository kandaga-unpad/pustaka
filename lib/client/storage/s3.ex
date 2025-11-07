defmodule Client.Storage.S3 do
  @moduledoc """
  S3-compatible storage adapter (works with AWS S3, Backblaze B2, MinIO, etc.)

  This adapter reads configuration at runtime, allowing you to switch between
  S3 and local storage without recompiling.
  """

  @behaviour Client.Storage.Behaviour

  # Helper functions to get runtime configuration
  defp get_s3_region, do: Application.get_env(:voile, :s3_region, "us-east-1")
  defp get_s3_access_key_id, do: Application.get_env(:voile, :s3_access_key_id)
  defp get_s3_secret_key_access, do: Application.get_env(:voile, :s3_secret_key_access)
  defp get_s3_bucket_name, do: Application.get_env(:voile, :s3_bucket_name, "glam-storage")

  defp get_s3_public_url,
    do: Application.get_env(:voile, :s3_public_url, "https://library.unpad.ac.id")

  defp get_s3_public_url_format,
    do: Application.get_env(:voile, :s3_public_url_format, "{endpoint}/{bucket}/{key}")

  @impl true
  def upload(
        %{path: tmp_path, filename: original_filename, content_type: content_type} = upload,
        opts
      )
      when is_map(upload) do
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

    file_key =
      if unit_id = Keyword.get(opts, :unit_id) do
        Path.join([folder, to_string(unit_id), filename])
      else
        Path.join([folder, filename])
      end

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
  def upload(%{"file" => upload, "Content-Type" => content_type}, opts)
      when is_map(upload) do
    # Override content type if provided in params
    updated_upload = Map.put(upload, :content_type, content_type)
    upload(updated_upload, opts)
  end

  def upload(%{"file" => upload}, opts) when is_map(upload) do
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
        to_string(get_s3_bucket_name()),
        to_string(file_key),
        %{
          "Body" => file_content,
          "ContentMD5" => md5,
          "ContentType" => content_type
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
      |> AWS.S3.delete_object(to_string(get_s3_bucket_name()), to_string(file_key), %{})
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
    # Create AWS client with credentials and region
    # MinIO is compatible with AWS S3 API, so we use the AWS client
    # For MinIO, the region can be any value (commonly "us-east-1")
    client =
      AWS.Client.create(get_s3_access_key_id(), get_s3_secret_key_access(), get_s3_region())

    # Extract hostname from public URL (AWS.Client.put_endpoint expects hostname only, not full URL)
    endpoint_host =
      case URI.parse(get_s3_public_url()) do
        %URI{host: host} when is_binary(host) -> host
      end

    # Override the endpoint to point to MinIO server
    # This makes the client use MinIO instead of AWS S3
    client = AWS.Client.put_endpoint(client, endpoint_host)

    # Use Req instead of hackney for HTTP requests
    # This avoids adding hackney as an additional dependency
    Map.put(client, :http_client, {Client.Storage.AWSHTTPClient, []})
  end

  defp build_public_url(file_key) do
    # Support custom public URL format via config :s3_public_url_format
    # Placeholders supported: {endpoint} {bucket} {key}
    # Examples:
    #  - "{endpoint}/{bucket}/{key}" (default)
    #  - "https://{bucket}.{endpoint}/{key}" (virtual-hosted-style)
    #  - "{endpoint}/b2api/v1/b2_download_file_by_id?fileId={key}" (provider-specific)

    endpoint = get_s3_public_url()
    bucket = to_string(get_s3_bucket_name())

    format =
      case get_s3_public_url_format() do
        nil -> "{endpoint}/{bucket}/{key}"
        format_string -> format_string
      end

    format
    |> String.replace("{endpoint}", endpoint)
    |> String.replace("{bucket}", bucket)
    |> String.replace("{key}", file_key)
  end

  def extract_file_key_from_url(url) do
    # Extract the file key from a full S3/MinIO URL
    # Supports multiple URL formats:
    # 1. Path-style: https://library.unpad.ac.id/glam-storage/folder/file.jpg -> folder/file.jpg
    # 2. Virtual-hosted: https://bucket.s3.region.amazonaws.com/folder/file.jpg -> folder/file.jpg
    # 3. With custom format from s3_public_url_format

    uri = URI.parse(url)
    bucket = to_string(get_s3_bucket_name())

    # Try to find bucket name in path and extract everything after it
    case String.split(uri.path || "", "/", trim: true) do
      # If bucket is in the path, extract everything after it
      parts when is_list(parts) and length(parts) > 0 ->
        case Enum.find_index(parts, &(&1 == bucket)) do
          nil ->
            # Bucket not in path, assume entire path is the key
            Enum.join(parts, "/")

          index ->
            # Extract parts after bucket name
            parts
            |> Enum.drop(index + 1)
            |> Enum.join("/")
        end

      # Empty path, fallback to original URL
      _ ->
        url
    end
  end

  @doc """
  Generate a presigned GET URL for the given S3 file key.

  NOTE: This implementation assumes a path-style URL format of the form
  {endpoint}/{bucket}/{key}. If you use virtual-hosted style (bucket as
  subdomain) you may need to adjust the canonical URI and host construction.
  """
  def presign_get(file_key, expires_seconds \\ 900) when is_binary(file_key) do
    access_key = get_s3_access_key_id()
    secret_key = get_s3_secret_key_access()
    region = get_s3_region()
    bucket = to_string(get_s3_bucket_name())

    if is_nil(access_key) or is_nil(secret_key) do
      {:error, "S3 credentials not configured"}
    else
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      amz_date = Calendar.strftime(now, "%Y%m%dT%H%M%SZ")
      date_stamp = Calendar.strftime(now, "%Y%m%d")

      service = "s3"
      algorithm = "AWS4-HMAC-SHA256"

      credential_scope = "#{date_stamp}/#{region}/#{service}/aws4_request"
      credential = URI.encode_www_form("#{access_key}/#{credential_scope}")

      endpoint_full = get_s3_public_url()
      endpoint_host =
        case URI.parse(endpoint_full) do
          %URI{host: h} when is_binary(h) -> h
          _ -> endpoint_full
        end

      format = get_s3_public_url_format() || "{endpoint}/{bucket}/{key}"

      # Decide virtual-hosted vs path-style based on format
      virtual_hosted? = String.contains?(format, "{bucket}.{endpoint}")

      {host, canonical_uri, key_for_url} =
        if virtual_hosted? do
          host = "#{bucket}.#{endpoint_host}"
          canonical_uri = "/#{URI.encode(file_key)}"
          {host, canonical_uri, URI.encode(file_key)}
        else
          host = endpoint_host
          canonical_uri = "/#{bucket}/#{URI.encode(file_key)}"
          {host, canonical_uri, URI.encode(file_key)}
        end

      query_params = %{
        "X-Amz-Algorithm" => algorithm,
        "X-Amz-Credential" => credential,
        "X-Amz-Date" => amz_date,
        "X-Amz-Expires" => Integer.to_string(expires_seconds),
        "X-Amz-SignedHeaders" => "host"
      }

      canonical_querystring =
        query_params
        |> Enum.map(fn {k, v} -> {k, URI.encode_www_form(v)} end)
        |> Enum.sort_by(fn {k, _v} -> k end)
        |> Enum.map_join("&", fn {k, v} -> "#{k}=#{v}" end)

      canonical_headers = "host:#{host}\n"
      signed_headers = "host"
      payload_hash = "UNSIGNED-PAYLOAD"

      canonical_request =
        Enum.join([
          "GET",
          canonical_uri,
          canonical_querystring,
          canonical_headers,
          signed_headers,
          payload_hash
        ], "\n")

      hashed_canonical_request = :crypto.hash(:sha256, canonical_request) |> Base.encode16(case: :lower)

      string_to_sign =
        Enum.join([
          algorithm,
          amz_date,
          credential_scope,
          hashed_canonical_request
        ], "\n")

      # derive signing key
      k_secret = "AWS4" <> secret_key
      k_date = :crypto.mac(:hmac, :sha256, k_secret, date_stamp)
      k_region = :crypto.mac(:hmac, :sha256, k_date, region)
      k_service = :crypto.mac(:hmac, :sha256, k_region, service)
      k_signing = :crypto.mac(:hmac, :sha256, k_service, "aws4_request")

      signature = :crypto.mac(:hmac, :sha256, k_signing, string_to_sign) |> Base.encode16(case: :lower)

      # Construct final URL using configured format so it matches provider expectations
      final_url =
        format
        |> String.replace("{endpoint}", endpoint_full)
        |> String.replace("{bucket}", bucket)
        |> String.replace("{key}", key_for_url)

      url = final_url <> (if String.contains?(final_url, "?"), do: "&", else: "?") <> canonical_querystring <> "&X-Amz-Signature=" <> signature

      {:ok, url}
    end
  end

  @doc """
  Adapter-friendly presign wrapper.
  """
  @impl true
  def presign(file_key, opts \\ []) do
    expires = Keyword.get(opts, :expires, 900)
    presign_get(file_key, expires)
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
    {:ok, %{path: path, filename: filename, content_type: content_type}}
  end

  defp extract_upload_from_params(%{
         "path" => path,
         "filename" => filename,
         "content_type" => content_type
       }) do
    {:ok, %{path: path, filename: filename, content_type: content_type}}
  end

  defp extract_upload_from_params(_), do: {:error, "Invalid file parameters"}
end
