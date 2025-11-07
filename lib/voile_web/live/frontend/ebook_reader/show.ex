defmodule VoileWeb.Frontend.EbookReader.Show do
  @moduledoc """
  Simple LiveView to render a PDF e-book either from a local static path
  (e.g. `/uploads/...`) or from a public S3 URL.

  Usage:
    /ebooks/view?url=/uploads/files/ab/1234.pdf
    /ebooks/view?url=https://bucket.example.com/folder/book.pdf
  """

  use VoileWeb, :live_view

  # Require logged-in users with Admin/Staff member types to access the reader
  on_mount {VoileWeb.UserAuth, :require_authenticated_and_verified_staff_user}

  alias Voile.Schema.Catalog

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:file_url, nil)
     |> assign(:loading, false)
     |> assign(:page_title, "E-Book Reader")}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    socket = assign(socket, :page_title, "E-Book Reader")

    cond do
      id = params["id"] ->
        # Resolve attachment by id and use the download controller to stream it
        case fetch_attachment_url(id) do
          {:ok, download_path} ->
            {:noreply, assign(socket, :file_url, download_path)}

          {:error, reason} ->
            {:noreply, socket |> put_flash(:error, reason) |> assign(:file_url, nil)}
        end

      url = params["url"] || params["file_url"] ->
        {:noreply, assign(socket, :file_url, url)}

      true ->
        {:noreply, assign(socket, :file_url, nil)}
    end
  end

  defp fetch_attachment_url(id) do
    try do
      attachment = Catalog.get_attachment!(id)

      fp = attachment.file_path

      cond do
        is_binary(fp) and String.starts_with?(fp, "/uploads") ->
          # Local file served by existing controller
          {:ok, "/attachments/#{attachment.id}/download"}

        is_binary(fp) and (String.starts_with?(fp, "http://") or
                             String.starts_with?(fp, "https://")) ->
          # Remote file (S3-like) - presign the underlying key
          file_key = Client.Storage.S3.extract_file_key_from_url(fp)

          case Client.Storage.presign(file_key) do
            {:ok, url} -> {:ok, url}
            {:error, reason} -> {:error, reason}
          end

        true ->
          {:error, "Unsupported attachment path"}
      end
    rescue
      Ecto.NoResultsError -> {:error, "Attachment not found"}
      e -> {:error, "Failed to load attachment: #{Exception.message(e)}"}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div class="mb-4">
          <.link navigate={~p"/"} class="text-sm text-gray-500">← Back</.link>
        </div>

        <%= if @file_url do %>
          <div class="mb-4 flex gap-2">
            <a href={@file_url} target="_blank" rel="noopener noreferrer" class="px-3 py-2 bg-voile-primary text-white rounded">Open in new tab</a>
            <a href={@file_url} download class="px-3 py-2 border rounded">Download</a>
          </div>

          <div class="bg-white dark:bg-gray-800 border border-voile-light dark:border-voile-dark rounded-lg overflow-hidden">
            <iframe src={@file_url} class="w-full h-[80vh]" frameborder="0"></iframe>
          </div>
        <% else %>
          <div class="p-6 bg-white dark:bg-gray-800 rounded-lg shadow">
            <p class="text-gray-600 dark:text-gray-300">No file specified. Provide a file URL via query parameter <code>?url=</code> (local path like <code>/uploads/...</code> or full S3 URL).</p>
          </div>
        <% end %>
      </div>
    </Layouts.app>
    """
  end
end
