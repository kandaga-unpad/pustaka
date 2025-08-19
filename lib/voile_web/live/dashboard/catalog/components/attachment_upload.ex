defmodule VoileWeb.Dashboard.Catalog.Components.AttachmentUpload do
  use VoileWeb, :live_component

  alias Voile.Schema.Catalog

  @impl true
  def render(assigns) do
    ~H"""
    <div class="attachment-upload" id={"attachment-upload-#{@id}"}>
      <div class="space-y-6">
        <!-- Upload Section -->
        <div class="bg-white shadow rounded-lg p-6">
          <h3 class="text-lg font-medium text-gray-900 mb-4">Upload Files</h3>
          
          <form phx-submit="save_attachments" phx-change="validate" phx-target={@myself}>
            <div class="space-y-4">
              <!-- File Upload Area -->
              <div class="flex justify-center px-6 pt-5 pb-6 border-2 border-gray-300 border-dashed rounded-md">
                <div class="space-y-1 text-center">
                  <svg
                    class="mx-auto h-12 w-12 text-gray-400"
                    stroke="currentColor"
                    fill="none"
                    viewBox="0 0 48 48"
                  >
                    <path
                      d="M28 8H12a4 4 0 00-4 4v20m32-12v8m0 0v8a4 4 0 01-4 4H12a4 4 0 01-4-4v-4m32-4l-3.172-3.172a4 4 0 00-5.656 0L28 28M8 32l9.172-9.172a4 4 0 015.656 0L28 28m0 0l4 4m4-24h8m-4-4v8m-12 4h.02"
                      stroke-width="2"
                      stroke-linecap="round"
                      stroke-linejoin="round"
                    />
                  </svg>
                  <div class="flex text-sm text-gray-600">
                    <label
                      for="file-upload"
                      class="relative cursor-pointer bg-white rounded-md font-medium text-indigo-600 hover:text-indigo-500 focus-within:outline-none focus-within:ring-2 focus-within:ring-offset-2 focus-within:ring-indigo-500"
                    >
                      <span>Upload files</span>
                    </label>
                    <p class="pl-1">or drag and drop</p>
                  </div>
                  
                  <p class="text-xs text-gray-500">Any file up to 100MB</p>
                </div>
              </div>
              <!-- Live Upload -->
              <div phx-drop-target={@uploads.attachments.ref} class="space-y-2">
                <.live_file_input upload={@uploads.attachments} class="hidden" />
                <!-- Upload Progress -->
                <%= for entry <- @uploads.attachments.entries do %>
                  <div class="bg-gray-50 rounded-lg p-4">
                    <div class="flex items-center justify-between">
                      <div class="flex-1">
                        <p class="text-sm font-medium text-gray-900">{entry.client_name}</p>
                        
                        <p class="text-xs text-gray-500">
                          {format_bytes(entry.client_size)} • {entry.client_type}
                        </p>
                      </div>
                      
                      <button
                        type="button"
                        phx-click="cancel_upload"
                        phx-value-ref={entry.ref}
                        phx-target={@myself}
                        class="ml-4 text-sm text-red-600 hover:text-red-500"
                      >
                        Cancel
                      </button>
                    </div>
                    <!-- Progress Bar -->
                    <div class="mt-2">
                      <div class="bg-gray-200 rounded-full h-2">
                        <div
                          class="bg-indigo-600 h-2 rounded-full transition-all duration-300"
                          style={"width: #{entry.progress}%"}
                        >
                        </div>
                      </div>
                      
                      <p class="text-xs text-gray-500 mt-1">{entry.progress}% uploaded</p>
                    </div>
                    <!-- Upload Errors -->
                    <%= for err <- upload_errors(@uploads.attachments, entry) do %>
                      <p class="text-sm text-red-600 mt-2">{humanize_upload_error(err)}</p>
                    <% end %>
                  </div>
                <% end %>
              </div>
            </div>
          </form>
        </div>
        <!-- Existing Attachments -->
        <div class="bg-white shadow rounded-lg p-6">
          <div class="flex justify-between items-center mb-4">
            <h3 class="text-lg font-medium text-gray-900">Attachments</h3>
             <span class="text-sm text-gray-500">{length(@attachments)} files</span>
          </div>
          
          <%= if @attachments == [] do %>
            <p class="text-gray-500 text-center py-8">No attachments uploaded yet</p>
          <% else %>
            <div class="space-y-3">
              <%= for attachment <- @attachments do %>
                <div class="flex items-center justify-between p-4 border border-gray-200 rounded-lg hover:bg-gray-50">
                  <div class="flex items-center space-x-3">
                    <!-- File Type Icon -->
                    <div class="flex-shrink-0">{file_type_icon(assigns, attachment.file_type)}</div>
                    
                    <div class="flex-1 min-w-0">
                      <p class="text-sm font-medium text-gray-900 truncate">
                        {attachment.original_name}
                        <%= if attachment.is_primary do %>
                          <span class="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-green-100 text-green-800 ml-2">
                            Primary
                          </span>
                        <% end %>
                      </p>
                      
                      <p class="text-sm text-gray-500">
                        {format_bytes(attachment.file_size)} • {attachment.mime_type} •
                        <span class="capitalize">{attachment.file_type}</span>
                      </p>
                      
                      <%= if attachment.description do %>
                        <p class="text-xs text-gray-400 mt-1">{attachment.description}</p>
                      <% end %>
                    </div>
                  </div>
                  
                  <div class="flex items-center space-x-2">
                    <!-- Set as Primary -->
                    <%= unless attachment.is_primary do %>
                      <button
                        type="button"
                        phx-click="set_primary"
                        phx-value-id={attachment.id}
                        phx-target={@myself}
                        class="text-xs text-indigo-600 hover:text-indigo-500"
                      >
                        Set Primary
                      </button>
                    <% end %>
                    <!-- Download -->
                    <a
                      href={Catalog.get_file_url(attachment)}
                      download={attachment.original_name}
                      class="text-xs text-gray-600 hover:text-gray-500"
                    >
                      Download
                    </a>
                    <!-- Delete -->
                    <button
                      type="button"
                      phx-click="delete_attachment"
                      phx-value-id={attachment.id}
                      phx-target={@myself}
                      data-confirm="Are you sure you want to delete this file?"
                      class="text-xs text-red-600 hover:text-red-500"
                    >
                      Delete
                    </button>
                  </div>
                </div>
              <% end %>
            </div>
            <!-- Attachment Stats -->
            <div class="mt-6 pt-4 border-t border-gray-200">
              <div class="grid grid-cols-2 md:grid-cols-4 gap-4 text-center">
                <div>
                  <p class="text-2xl font-semibold text-gray-900">{length(@attachments)}</p>
                  
                  <p class="text-xs text-gray-500">Total Files</p>
                </div>
                
                <div>
                  <p class="text-2xl font-semibold text-gray-900">
                    {format_bytes(Enum.sum(Enum.map(@attachments, & &1.file_size)))}
                  </p>
                  
                  <p class="text-xs text-gray-500">Total Size</p>
                </div>
                
                <div>
                  <p class="text-2xl font-semibold text-gray-900">
                    {@attachments |> Enum.count(&(&1.file_type == "image"))}
                  </p>
                  
                  <p class="text-xs text-gray-500">Images</p>
                </div>
                
                <div>
                  <p class="text-2xl font-semibold text-gray-900">
                    {@attachments |> Enum.count(&(&1.file_type == "document"))}
                  </p>
                  
                  <p class="text-xs text-gray-500">Documents</p>
                </div>
              </div>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def mount(socket) do
    socket =
      socket
      |> assign(:uploaded_files, [])
      |> assign(:attachments, [])
      |> allow_upload(:attachments,
        accept: :any,
        max_entries: 10,
        max_file_size: 100_000_000,
        progress: &handle_progress/3,
        auto_upload: true
      )

    {:ok, socket}
  end

  @impl true
  def update(%{entity: entity} = _assigns, socket) do
    attachments = Catalog.list_attachments(entity)

    socket =
      socket
      |> assign(:attachments, attachments)

    {:ok, socket}
  end

  @impl true
  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("cancel_upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :attachments, ref)}
  end

  @impl true
  def handle_event("set_primary", %{"id" => attachment_id}, socket) do
    attachment = Enum.find(socket.assigns.attachments, &(&1.id == attachment_id))

    case Catalog.set_primary_attachment(attachment) do
      {:ok, _} ->
        updated_attachments = Catalog.list_attachments(socket.assigns.entity)
        send(self(), {:attachment_updated, :primary_set})

        {:noreply,
         socket
         |> assign(:attachments, updated_attachments)
         |> put_flash(:info, "Primary attachment updated successfully")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to set primary attachment")}
    end
  end

  @impl true
  def handle_event("delete_attachment", %{"id" => attachment_id}, socket) do
    attachment = Enum.find(socket.assigns.attachments, &(&1.id == attachment_id))

    case Catalog.delete_attachment(attachment) do
      {:ok, _} ->
        updated_attachments = Catalog.list_attachments(socket.assigns.entity)
        send(self(), {:attachment_updated, :deleted})

        {:noreply,
         socket
         |> assign(:attachments, updated_attachments)
         |> put_flash(:info, "Attachment deleted successfully")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to delete attachment")}
    end
  end

  defp handle_progress(:attachments, entry, socket) when entry.done? do
    uploaded_file =
      consume_uploaded_entry(socket, entry, fn %{path: path} ->
        # Save the uploaded file
        case Catalog.create_attachment(socket.assigns.entity, %{
               path: path,
               filename: entry.client_name,
               content_type: entry.client_type,
               description: ""
             }) do
          {:ok, attachment} ->
            send(self(), {:attachment_updated, :uploaded})
            {:ok, attachment}

          {:error, reason} ->
            {:error, reason}
        end
      end)

    case uploaded_file do
      {:ok, _attachment} ->
        updated_attachments = Catalog.list_attachments(socket.assigns.entity)
        {:noreply, assign(socket, :attachments, updated_attachments)}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to save attachment")}
    end
  end

  defp handle_progress(:attachments, _entry, socket) do
    {:noreply, socket}
  end

  # Helper functions
  defp format_bytes(bytes) when bytes < 1024, do: "#{bytes} B"
  defp format_bytes(bytes) when bytes < 1_048_576, do: "#{Float.round(bytes / 1024, 1)} KB"

  defp format_bytes(bytes) when bytes < 1_073_741_824,
    do: "#{Float.round(bytes / 1_048_576, 1)} MB"

  defp format_bytes(bytes), do: "#{Float.round(bytes / 1_073_741_824, 1)} GB"

  defp file_type_icon(assigns, "image") do
    ~H"""
    <svg class="h-8 w-8 text-green-400" fill="currentColor" viewBox="0 0 20 20">
      <path
        fill-rule="evenodd"
        d="M4 3a2 2 0 00-2 2v10a2 2 0 002 2h12a2 2 0 002-2V5a2 2 0 00-2-2H4zm12 12H4l4-8 3 6 2-4 3 6z"
        clip-rule="evenodd"
      />
    </svg>
    """
  end

  defp file_type_icon(assigns, "document") do
    ~H"""
    <svg class="h-8 w-8 text-blue-400" fill="currentColor" viewBox="0 0 20 20">
      <path
        fill-rule="evenodd"
        d="M4 4a2 2 0 012-2h4.586A2 2 0 0112 2.586L15.414 6A2 2 0 0116 7.414V16a2 2 0 01-2 2H6a2 2 0 01-2-2V4zm2 6a1 1 0 011-1h6a1 1 0 110 2H7a1 1 0 01-1-1zm1 3a1 1 0 100 2h6a1 1 0 100-2H7z"
        clip-rule="evenodd"
      />
    </svg>
    """
  end

  defp file_type_icon(assigns, "video") do
    ~H"""
    <svg class="h-8 w-8 text-purple-400" fill="currentColor" viewBox="0 0 20 20">
      <path
        fill-rule="evenodd"
        d="M2 6a2 2 0 012-2h6a2 2 0 012 2v4a2 2 0 01-2 2H4a2 2 0 01-2-2V6zm12.553 1.106A1 1 0 0014 8v4a1 1 0 00.553.894l2 1A1 1 0 0018 13V7a1 1 0 00-1.447-.894l-2 1z"
        clip-rule="evenodd"
      />
    </svg>
    """
  end

  defp file_type_icon(assigns, "audio") do
    ~H"""
    <svg class="h-8 w-8 text-yellow-400" fill="currentColor" viewBox="0 0 20 20">
      <path
        fill-rule="evenodd"
        d="M18 3a1 1 0 00-1.447-.894L8.763 6H5a3 3 0 000 6h.28l1.771 5.316A1 1 0 008 18a1 1 0 001-1v-4.382l6.553 3.276A1 1 0 0017 15V3z"
        clip-rule="evenodd"
      />
    </svg>
    """
  end

  defp file_type_icon(assigns, "software") do
    ~H"""
    <svg class="h-8 w-8 text-indigo-400" fill="currentColor" viewBox="0 0 20 20">
      <path
        fill-rule="evenodd"
        d="M12.316 3.051a1 1 0 01.633 1.265l-4 12a1 1 0 11-1.898-.632l4-12a1 1 0 011.265-.633zM5.707 6.293a1 1 0 010 1.414L3.414 10l2.293 2.293a1 1 0 11-1.414 1.414l-3-3a1 1 0 010-1.414l3-3a1 1 0 011.414 0zm8.586 0a1 1 0 011.414 0l3 3a1 1 0 010 1.414l-3 3a1 1 0 11-1.414-1.414L16.586 10l-2.293-2.293a1 1 0 010-1.414z"
        clip-rule="evenodd"
      />
    </svg>
    """
  end

  defp file_type_icon(assigns, "archive") do
    ~H"""
    <svg class="h-8 w-8 text-orange-400" fill="currentColor" viewBox="0 0 20 20">
      <path d="M4 3a2 2 0 100 4h12a2 2 0 100-4H4z" />
      <path
        fill-rule="evenodd"
        d="M3 8h14v7a2 2 0 01-2 2H5a2 2 0 01-2-2V8zm5 3a1 1 0 011-1h2a1 1 0 110 2H9a1 1 0 01-1-1z"
        clip-rule="evenodd"
      />
    </svg>
    """
  end

  defp file_type_icon(assigns, _) do
    ~H"""
    <svg class="h-8 w-8 text-gray-400" fill="currentColor" viewBox="0 0 20 20">
      <path
        fill-rule="evenodd"
        d="M4 4a2 2 0 012-2h4.586A2 2 0 0112 2.586L15.414 6A2 2 0 0116 7.414V16a2 2 0 01-2 2H6a2 2 0 01-2-2V4z"
        clip-rule="evenodd"
      />
    </svg>
    """
  end

  defp humanize_upload_error(:too_large), do: "File is too large"
  defp humanize_upload_error(:too_many_files), do: "Too many files selected"
  defp humanize_upload_error(:not_accepted), do: "File type not accepted"
  defp humanize_upload_error(_), do: "Something went wrong"
end
