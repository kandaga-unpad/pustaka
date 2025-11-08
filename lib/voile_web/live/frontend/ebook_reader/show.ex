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
  def mount(params, _session, socket) do
    attachment = Catalog.get_attachment!(params["id"])

    socket =
      socket
      |> assign(:file_url, nil)
      |> assign(:loading, false)
      |> assign(:page_title, "E-Book Reader")
      |> assign(:collection_id, attachment.attachable.id)

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    socket = assign(socket, :page_title, "E-Book Reader")

    cond do
      id = params["id"] ->
        # Resolve attachment by id and use the download controller to stream it
        case fetch_attachment_url(id) do
          {:ok, download_path} ->
            file_type = detect_file_type(download_path)
            {:noreply, assign(socket, :file_url, download_path) |> assign(:file_type, file_type)}

          {:error, reason} ->
            {:noreply,
             socket
             |> put_flash(:error, reason)
             |> assign(:file_url, nil)
             |> assign(:file_type, nil)}
        end

      url = params["url"] || params["file_url"] ->
        file_type = detect_file_type(url)
        {:noreply, assign(socket, :file_url, url) |> assign(:file_type, file_type)}

      true ->
        {:noreply, assign(socket, :file_url, nil) |> assign(:file_type, nil)}
    end
  end

  defp fetch_attachment_url(id) do
    try do
      attachment = Catalog.get_attachment!(id)

      fp = attachment.file_path

      cond do
        is_binary(fp) and String.starts_with?(fp, "/uploads") ->
          # Local file already stored under priv/static/uploads; embed the
          # static URL directly in the reader instead of proxying through the
          # download controller. This avoids sending the file via the
          # controller (which may reference built app priv paths) and allows
          # the browser to fetch the static asset directly.
          {:ok, fp}

        is_binary(fp) and
            (String.starts_with?(fp, "http://") or
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

  defp detect_file_type(url) do
    cond do
      String.ends_with?(url, ".pdf") -> "pdf"
      String.ends_with?(url, ".epub") -> "epub"
      true -> "unknown"
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="h-screen flex flex-col max-w-7xl mx-auto">
        <div class="bg-white dark:bg-gray-800 border-b border-gray-200 dark:border-gray-700 px-4 py-3 flex justify-between items-center">
          <div class="flex items-center gap-4">
            <.link
              navigate={~p"/collections/#{@collection_id}"}
              class="text-sm text-gray-600 dark:text-gray-400 hover:text-voile-primary"
            >
              ← Back
            </.link>
            <h1 class="text-lg font-semibold text-gray-800 dark:text-gray-200">E-Book Reader</h1>
          </div>
          
          <%= if @file_url && @file_type in ["pdf", "epub"] do %>
            <div class="flex gap-2">
              <a
                href={@file_url}
                target="_blank"
                rel="noopener noreferrer"
                class="px-3 py-1.5 text-sm bg-voile-primary text-white rounded hover:bg-voile-primary-dark transition-colors"
                title="Open in new tab"
              >
                <span class="hidden sm:inline">Open in Tab</span> <span class="sm:hidden">Open</span>
              </a>
              <a
                href={@file_url}
                download
                class="px-3 py-1.5 text-sm border border-gray-300 dark:border-gray-600 rounded hover:bg-gray-50 dark:hover:bg-gray-700 transition-colors"
                title="Download file"
              >
                <span class="hidden sm:inline">Download</span> <span class="sm:hidden">⬇</span>
              </a>
            </div>
          <% end %>
        </div>
        
        <%= if @file_url && @file_type in ["pdf", "epub"] do %>
          <div class="flex-1 overflow-hidden">
            <div
              id="ebook-reader"
              phx-hook="EbookReader"
              data-file-url={@file_url}
              data-file-type={@file_type}
              class="w-full h-full"
            >
            </div>
          </div>
        <% else %>
          <div class="flex-1 flex items-center justify-center p-6">
            <div class="max-w-md text-center p-8 bg-white dark:bg-gray-800 rounded-lg shadow">
              <div class="text-5xl mb-4">📚</div>
              
              <h2 class="text-xl font-semibold mb-2 text-gray-800 dark:text-gray-200">
                {if @file_url, do: "Unsupported File Type", else: "No File Selected"}
              </h2>
              
              <p class="text-gray-600 dark:text-gray-400">
                <%= if @file_url do %>
                  Only PDF and EPUB files are supported.
                <% else %>
                  Provide a file URL via query parameter
                  <code class="px-1 py-0.5 bg-gray-100 dark:bg-gray-700 rounded">?url=</code>
                  or <code class="px-1 py-0.5 bg-gray-100 dark:bg-gray-700 rounded">?id=</code>
                  to load an e-book.
                <% end %>
              </p>
            </div>
          </div>
        <% end %>
      </div>
    </Layouts.app>
    """
  end
end
