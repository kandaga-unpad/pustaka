defmodule VoileWeb.OaiViewerController do
  use VoileWeb, :controller

  @moduledoc """
  Controller for serving OAI-PMH viewer HTML pages.
  Provides human-friendly interfaces to browse OAI-PMH metadata.
  """

  @doc """
  Serves the OAI-PMH viewer page.
  This is a JavaScript-based viewer that fetches and displays OAI-PMH XML beautifully.
  """
  def viewer(conn, _params) do
    html_path = Application.app_dir(:voile, "priv/static/oai-viewer.html")

    case File.read(html_path) do
      {:ok, content} ->
        conn
        |> put_resp_content_type("text/html")
        |> send_resp(200, content)

      {:error, _reason} ->
        conn
        |> put_status(404)
        |> text("OAI Viewer not found")
    end
  end

  @doc """
  Serves the OAI-PMH demo/landing page.
  Shows all available OAI-PMH verbs with links to the viewer.
  """
  def demo(conn, _params) do
    html_path = Application.app_dir(:voile, "priv/static/oai-demo.html")

    case File.read(html_path) do
      {:ok, content} ->
        conn
        |> put_resp_content_type("text/html")
        |> send_resp(200, content)

      {:error, _reason} ->
        conn
        |> put_status(404)
        |> text("OAI Demo page not found")
    end
  end
end
