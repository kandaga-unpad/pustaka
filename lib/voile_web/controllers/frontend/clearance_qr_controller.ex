defmodule VoileWeb.Frontend.ClearanceQrController do
  use VoileWeb, :controller

  alias QRCode
  alias QRCode.Render.SvgSettings
  alias Voile.Clearance

  def show(conn, %{"uuid" => uuid}) do
    with %{} = letter <- Clearance.get_letter(uuid),
         {:ok, qr} <- QRCode.create(letter.id, :high),
         {:ok, svg} <- QRCode.render({:ok, qr}, :svg, svg_settings()) do
      conn
      |> put_resp_content_type("image/svg+xml")
      |> send_resp(200, svg)
    else
      _ ->
        conn
        |> send_resp(404, "QR code not found")
    end
  end

  defp svg_settings do
    %SvgSettings{
      scale: 4,
      background_color: "transparent",
      qrcode_color: "#1f2937",
      structure: :minify,
      quiet_zone: 2
    }
  end
end
