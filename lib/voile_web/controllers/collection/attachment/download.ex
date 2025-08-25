defmodule VoileWeb.Collection.AttachmentController.Download do
  use VoileWeb, :controller

  alias Voile.Schema.Catalog

  def download(conn, %{"id" => id}) do
    attachment = Catalog.get_attachment!(id)
    url = build_url_attachment(attachment)

    conn
    |> put_resp_content_type(MIME.from_path(attachment.file_name))
    |> put_resp_header(
      "content-disposition",
      ~s[attachment; filename="#{attachment.original_name}"]
    )
    |> send_file(200, url)
  end

  defp build_url_attachment(attachment) do
    Path.join([
      :code.priv_dir(:voile),
      "static",
      Catalog.get_file_url(attachment)
    ])
  end
end
