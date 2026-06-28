defmodule VoileWeb.AttachmentDownloadSsrfTest do
  use VoileWeb.ConnCase, async: true

  import Voile.AccountsFixtures

  alias Voile.Repo
  alias Voile.Schema.Catalog.Attachment

  setup %{conn: conn} do
    user = user_fixture(%{fullname: "Security Tester", phone_number: "555-0100"})
    conn = log_in_user(conn, user)
    %{user: user, conn: conn}
  end

  describe "GET /attachments/:id/download — SSRF protection (H4)" do
    @tag :ssrf_security
    test "blocks download of attachment pointing to cloud metadata endpoint", %{conn: conn} do
      attachment = ssrf_attachment("http://169.254.169.254/latest/meta-data/iam/")

      conn = get(conn, "/attachments/#{attachment.id}/download")

      assert conn.status == 403
      assert response(conn, 403) =~ "not allowed"
    end

    @tag :ssrf_security
    test "blocks download pointing to localhost", %{conn: conn} do
      attachment = ssrf_attachment("http://localhost:8080/admin")

      conn = get(conn, "/attachments/#{attachment.id}/download")

      assert conn.status == 403
    end

    @tag :ssrf_security
    test "blocks download pointing to 127.0.0.1", %{conn: conn} do
      attachment = ssrf_attachment("http://127.0.0.1:9090/metrics")

      conn = get(conn, "/attachments/#{attachment.id}/download")

      assert conn.status == 403
    end

    @tag :ssrf_security
    test "blocks download pointing to private 10.x range", %{conn: conn} do
      attachment = ssrf_attachment("http://10.0.0.1/internal-api/secret")

      conn = get(conn, "/attachments/#{attachment.id}/download")

      assert conn.status == 403
    end

    @tag :ssrf_security
    test "blocks download pointing to private 192.168.x range", %{conn: conn} do
      attachment = ssrf_attachment("http://192.168.1.1/router/config")

      conn = get(conn, "/attachments/#{attachment.id}/download")

      assert conn.status == 403
    end

    @tag :ssrf_security
    test "blocks download pointing to private 172.16-31.x range", %{conn: conn} do
      attachment = ssrf_attachment("http://172.16.0.1/intranet/data")

      conn = get(conn, "/attachments/#{attachment.id}/download")

      assert conn.status == 403
    end

    @tag :ssrf_security
    test "blocks non-http schemes (file://)", %{conn: conn} do
      attachment = ssrf_attachment("file:///etc/passwd")

      conn = get(conn, "/attachments/#{attachment.id}/download")

      # file:// scheme doesn't start with http:// so it hits the "Unsupported" path
      assert conn.status in [400, 403]
    end
  end

  # Helper: insert an attachment with the given (malicious) file_path.
  # Uses access_level: "public" so any authenticated user passes the access check,
  # isolating the SSRF protection test from authorization concerns.
  defp ssrf_attachment(file_path) do
    collection = Voile.CatalogFixtures.collection_fixture()

    {:ok, attachment} =
      %Attachment{}
      |> Ecto.Changeset.cast(
        %{
          file_name: "document.pdf",
          original_name: "document.pdf",
          file_path: file_path,
          mime_type: "application/pdf",
          access_level: "public",
          attachable_type: "collection",
          attachable_id: collection.id
        },
        [
          :file_name,
          :original_name,
          :file_path,
          :mime_type,
          :access_level,
          :attachable_type,
          :attachable_id
        ]
      )
      |> Repo.insert()

    attachment || flunk("Failed to create test attachment")
  end
end
