defmodule VoileWeb.Collection.AttachmentController.Download do
  use VoileWeb, :controller

  alias Voile.Schema.Catalog

  def download(conn, %{"id" => id}) do
    attachment = Catalog.get_attachment!(id)

    # For local attachments (uploaded into priv/static/uploads) we serve the
    # file directly from disk using send_file which is efficient.
    if attachment.file_path && String.starts_with?(attachment.file_path, "/uploads") do
      url = build_url_attachment(attachment)

      conn
      |> put_resp_content_type(MIME.from_path(attachment.file_name))
      |> put_resp_header(
        "content-disposition",
        ~s[attachment; filename="#{attachment.original_name}"]
      )
      |> send_file(200, url)
    else
      # Remote file (S3 or other HTTP URL). Try to get a presigned URL and
      # redirect the client to it to offload bandwidth to the object store.
      fp = attachment.file_path || ""

      if String.starts_with?(fp, "http://") or String.starts_with?(fp, "https://") do
        # Extract a file key and try to presign via the storage adapter.
        file_key = Client.Storage.S3.extract_file_key_from_url(fp)

        case Client.Storage.presign(file_key) do
          {:ok, presigned_url} when is_binary(presigned_url) ->
            conn
            |> redirect(external: presigned_url)

          _ ->
            # Fallback: proxy the remote resource through the app. This
            # preserves authorization but consumes server bandwidth. Use
            # streaming to avoid buffering the entire file in memory.
            # We use hackney directly for chunked streaming.
            case :hackney.request(:get, fp, [], :stream, [{:recv_timeout, 120_000}, {:follow_redirect, true}]) do
              {:ok, status, headers, client_ref} ->
                # Determine content type
                content_type =
                  case MIME.from_path(attachment.file_name) do
                    "application/octet-stream" ->
                      # Try to get from response headers
                      get_resp_header_value(headers, "content-type") || "application/octet-stream"

                    ct -> ct
                  end

                conn =
                  conn
                  |> put_resp_content_type(content_type)
                  |> put_resp_header(
                    "content-disposition",
                    ~s[attachment; filename="#{attachment.original_name}"]
                  )

                case Plug.Conn.send_chunked(conn, status) do
                  %Plug.Conn{} = chunked_conn ->
                    # Some Plug versions (or the static analysis) represent the
                    # send_chunked result as the conn directly; handle that form.
                    stream_hackney_body(chunked_conn, client_ref)

                  other ->
                    conn
                    |> put_status(502)
                    |> put_resp_content_type("text/plain")
                    |> send_resp(502, "Failed to initiate chunked response: #{inspect(other)}")
                end

              {:error, reason} ->
                conn
                |> put_status(502)
                |> put_resp_content_type("text/plain")
                |> send_resp(502, "Failed to fetch remote file: #{inspect(reason)}")
            end
        end
      else
        conn
        |> put_status(400)
        |> put_resp_content_type("text/plain")
        |> send_resp(400, "Unsupported attachment path")
      end
    end
  end

  defp build_url_attachment(attachment) do
    Path.join([
      :code.priv_dir(:voile),
      "static",
      Catalog.get_file_url(attachment)
    ])
  end

  defp get_resp_header_value(headers, key) do
    cond do
      is_map(headers) -> Map.get(headers, key) || Map.get(headers, String.downcase(key))
      is_list(headers) -> headers |> Enum.find_value(fn {k, v} -> if String.downcase(k) == String.downcase(key), do: v end)
      true -> nil
    end
  end

  defp stream_hackney_body(conn, client_ref) do
    case :hackney.stream_body(client_ref) do
      {:ok, chunk} when is_binary(chunk) ->
        case Plug.Conn.chunk(conn, chunk) do
          {:ok, conn} -> stream_hackney_body(conn, client_ref)
          {:error, _} -> conn
        end

      :done ->
        conn

      {:error, _reason} ->
        conn
    end
  end
end
