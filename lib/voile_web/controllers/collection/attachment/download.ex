defmodule VoileWeb.Collection.AttachmentController.Download do
  use VoileWeb, :controller

  alias Voile.Schema.Catalog

  def download(conn, %{"id" => id}) do
    attachment = Catalog.get_attachment!(id)

    # Perform authorization check using the same logic that powers
    # AttachmentAccess.accessible_by/2 and AttachmentAccess.can_access?/2.
    # The `current_scope` assign is populated by the browser pipeline so we
    # pull the user out if it's available.  This prevents users from
    # bypassing embargo/window restrictions or downloading files they
    # shouldn't see.
    user = conn.assigns[:current_scope] && conn.assigns.current_scope.user

    unless Voile.Catalog.AttachmentAccess.can_access?(attachment, user) do
      conn
      |> put_status(:forbidden)
      |> put_resp_content_type("text/plain")
      |> send_resp(403, "You are not authorized to access this attachment")
    else
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
              #
              # SSRF protection: validate the URL before fetching and never
              # follow redirects (a redirect can point to internal services
              # such as the cloud metadata endpoint).
              if safe_remote_url?(fp) do
                case :hackney.request(:get, fp, [], :stream, [
                       {:recv_timeout, 120_000},
                       {:follow_redirect, false}
                     ]) do
                  {:ok, status, headers, client_ref}
                  when status in 200..299 ->
                    # Determine content type
                    content_type =
                      case MIME.from_path(attachment.file_name) do
                        "application/octet-stream" ->
                          # Try to get from response headers
                          get_resp_header_value(headers, "content-type") ||
                            "application/octet-stream"

                        ct ->
                          ct
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
                        # send_chunked returns the connection; stream from it
                        stream_hackney_body(chunked_conn, client_ref)
                    end

                  {:ok, status, _headers, client_ref} when status in 300..399 ->
                    :hackney.close(client_ref)

                    conn
                    |> put_status(:forbidden)
                    |> put_resp_content_type("text/plain")
                    |> send_resp(403, "Remote file redirected; refusing to follow")

                  {:ok, status, _headers, client_ref} ->
                    :hackney.close(client_ref)

                    conn
                    |> put_status(502)
                    |> put_resp_content_type("text/plain")
                    |> send_resp(502, "Remote file returned status #{status}")

                  {:error, _reason} ->
                    conn
                    |> put_status(502)
                    |> put_resp_content_type("text/plain")
                    |> send_resp(502, "Failed to fetch remote file")
                end
              else
                conn
                |> put_status(:forbidden)
                |> put_resp_content_type("text/plain")
                |> send_resp(403, "Remote file URL is not allowed")
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
  end

  defp build_url_attachment(attachment) do
    Path.join([
      :code.priv_dir(:voile),
      "static",
      Catalog.get_file_url(attachment)
    ])
  end

  defp get_resp_header_value(headers, key) do
    # Headers from hackney are always a list of {key, value} tuples.
    headers
    |> Enum.find_value(fn
      {k, v} when is_binary(k) -> if String.downcase(k) == String.downcase(key), do: v
      _ -> nil
    end)
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

  # ── SSRF protection ──────────────────────────────────────────────────────────
  #
  # Only allow http(s) URLs whose host does not resolve to a private, loopback,
  # or link-local address.  This prevents the server from being tricked into
  # fetching internal resources (e.g. cloud metadata at 169.254.169.254).

  defp safe_remote_url?(url) do
    case URI.parse(url) do
      %URI{scheme: scheme, host: host}
      when scheme in ["http", "https"] and is_binary(host) and host != "" ->
        not internal_host?(host)

      _ ->
        false
    end
  end

  defp internal_host?(host) do
    charlist = String.to_charlist(host)

    case :inet.parse_address(charlist) do
      {:ok, ip} ->
        internal_ip?(ip)

      {:error, _} ->
        # Not a literal IP — block obvious internal hostnames.
        String.equivalent?(host, "localhost") or
          String.ends_with?(host, ".local") or
          String.ends_with?(host, ".internal")
    end
  end

  # Private IPv4 ranges (RFC 1918), loopback, link-local, metadata
  defp internal_ip?({10, _, _, _}), do: true
  defp internal_ip?({172, b, _, _}) when b in 16..31, do: true
  defp internal_ip?({192, 168, _, _}), do: true
  defp internal_ip?({127, _, _, _}), do: true
  defp internal_ip?({169, 254, _, _}), do: true
  defp internal_ip?({0, _, _, _}), do: true
  # Carrier-grade NAT 100.64.0.0/10
  defp internal_ip?({100, b, _, _}) when b in 64..127, do: true

  # IPv6 loopback & link-local
  defp internal_ip?({0, 0, 0, 0, 0, 0, 0, 1}), do: true
  defp internal_ip?({0xFE80, _, _, _, _, _, _, _}), do: true

  defp internal_ip?(_), do: false
end
