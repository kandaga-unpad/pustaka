defmodule VoileWeb.Dashboard.Catalog.Components.AttachmentUpload do
  use VoileWeb, :live_component

  alias Voile.Schema.Catalog
  alias Voile.Schema.Catalog.Attachment

  @impl true
  def render(assigns) do
    ~H"""
    <div class="attachment-upload" id={"attachment-upload-#{@entity.id}"}>
      <div class="space-y-6">
        <!-- Upload Section -->
        <div class="bg-white dark:bg-gray-600 shadow rounded-lg p-6">
          <div class="flex justify-between items-center mb-4">
            <h3 class="text-lg font-medium text-gray-900 dark:text-white">Upload Files</h3>
            
            <%= if @collection_type do %>
              <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-indigo-100 text-indigo-800 capitalize">
                {@collection_type} Collection
              </span>
            <% end %>
          </div>
          <!-- Collection Type Specific Hints -->
          <%= if @upload_hints do %>
            <div class="mb-4 p-3 bg-blue-50 border border-blue-200 rounded-md">
              <p class="text-sm text-blue-700">
                <svg class="inline w-4 h-4 mr-1" fill="currentColor" viewBox="0 0 20 20">
                  <path
                    fill-rule="evenodd"
                    d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z"
                    clip-rule="evenodd"
                  />
                </svg> {@upload_hints}
              </p>
            </div>
          <% end %>
          
          <form phx-submit="save_attachments" phx-change="validate" phx-target={@myself}>
            <!-- File Upload Area -->
            <div
              phx-drop-target={@uploads.attachments.ref}
              id="upload-area"
              class="upload-area flex justify-center px-6 pt-5 pb-6 border-2 border-gray-300 border-dashed rounded-md hover:border-indigo-400 transition-colors duration-200"
              phx-hook="DragUpload"
            >
              <div class="space-y-1 text-center flex flex-col items-center">
                {collection_type_icon(@collection_type)}
                <div class="flex text-sm text-gray-600 dark:text-white">
                  <label
                    for={@uploads.attachments.ref}
                    class="relative cursor-pointer bg-white dark:bg-gray-600 rounded-md font-medium text-indigo-600 hover:text-indigo-500 dark:text-indigo-200 dark:hover:text-indigo-100 focus-within:outline-none focus-within:ring-2 focus-within:ring-offset-2 focus-within:ring-indigo-500"
                  >
                    <span>Upload files</span>
                    <.live_file_input upload={@uploads.attachments} class="sr-only" />
                  </label>
                  <p class="pl-1">or drag and drop</p>
                </div>
                <!-- Dynamic file type hints -->
                <p class="text-xs text-gray-500 dark:text-white">
                  {format_allowed_types(@allowed_types)} up to 100MB each
                </p>
              </div>
            </div>
            <!-- Upload Progress -->
            <div class="mt-4 space-y-2">
              <%= for entry <- @uploads.attachments.entries do %>
                <div class="bg-gray-50 rounded-lg p-4 border border-gray-200">
                  <div class="flex items-center justify-between">
                    <div class="flex-1">
                      <div class="flex items-center">
                        {file_type_icon(determine_file_type_from_name(entry.client_name))}
                        <div class="ml-3">
                          <p class="text-sm font-medium text-gray-900">{entry.client_name}</p>
                          
                          <p class="text-xs text-gray-500">
                            {format_bytes(entry.client_size)} • {entry.client_type}
                            <%= if @collection_type && !is_file_type_allowed?(entry.client_type, @collection_type) do %>
                              <span class="ml-2 text-red-600 font-medium">
                                ⚠ May not be suitable for this collection type
                              </span>
                            <% end %>
                          </p>
                        </div>
                      </div>
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
                  <div class="mt-3">
                    <div class="bg-gray-200 rounded-full h-2">
                      <div
                        class="bg-indigo-600 h-2 rounded-full transition-all duration-300"
                        style={"width: #{entry.progress}%"}
                      >
                      </div>
                    </div>
                    
                    <div class="flex justify-between text-xs text-gray-500 mt-1">
                      <span>{entry.progress}% uploaded</span>
                      <span>{if entry.done?, do: "Complete", else: "Uploading..."}</span>
                    </div>
                  </div>
                  <!-- Upload Errors -->
                  <%= for err <- upload_errors(@uploads.attachments, entry) do %>
                    <div class="mt-2 p-2 bg-red-50 border border-red-200 rounded">
                      <p class="text-sm text-red-600 flex items-center">
                        <svg class="w-4 h-4 mr-1" fill="currentColor" viewBox="0 0 20 20">
                          <path
                            fill-rule="evenodd"
                            d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7 4a1 1 0 11-2 0 1 1 0 012 0zm-1-9a1 1 0 00-1 1v4a1 1 0 102 0V6a1 1 0 00-1-1z"
                            clip-rule="evenodd"
                          />
                        </svg> {humanize_upload_error(err)}
                      </p>
                    </div>
                  <% end %>
                </div>
              <% end %>
            </div>
          </form>
        </div>
        <!-- Existing Attachments -->
        <div class="bg-white dark:bg-gray-600 shadow rounded-lg p-6">
          <div class="flex justify-between items-center mb-4">
            <h3 class="text-lg font-medium text-gray-900 dark:text-white">Attachments</h3>
            
            <div class="flex items-center space-x-4">
              <!-- File type filter -->
              <%= if length(@attachments) > 0 do %>
                <select
                  phx-change="filter_by_type"
                  phx-target={@myself}
                  class="text-sm border-gray-300 rounded-md focus:ring-indigo-500 focus:border-indigo-500"
                >
                  <option value="">All files ({length(@attachments)})</option>
                  
                  <%= for {type, count} <- get_file_type_counts(@attachments) do %>
                    <option value={type} class="capitalize">{type} ({count})</option>
                  <% end %>
                </select>
              <% else %>
                <span class="text-sm text-gray-500 dark:text-white">0 files</span>
              <% end %>
            </div>
          </div>
          
          <%= if @attachments == [] do %>
            <div class="text-center py-12">
              {collection_type_icon(@collection_type, "h-12 w-12 mx-auto text-gray-300")}
              <h3 class="mt-2 text-sm font-medium text-gray-900 dark:text-white">No attachments</h3>
              
              <p class="mt-1 text-sm text-gray-500 dark:text-gray-300">
                Start by uploading your first {if @collection_type, do: @collection_type, else: "file"}.
              </p>
            </div>
          <% else %>
            <!-- Attachment Grid/List -->
            <div class="space-y-3">
              <%= for attachment <- filter_attachments(@attachments, @filter_type || "") do %>
                <div class="flex items-center justify-between p-4 border border-gray-200 rounded-lg hover:bg-gray-50 dark:hover:bg-gray-500 transition-colors duration-150">
                  <div class="flex items-center space-x-4">
                    <!-- File Type Icon -->
                    <div class="flex-shrink-0">{file_type_icon(attachment.file_type)}</div>
                    
                    <div class="flex-1 min-w-0">
                      <div class="flex items-center">
                        <p class="text-sm font-medium text-gray-900 dark:text-white truncate">
                          {attachment.original_name}
                        </p>
                        
                        <%= if attachment.is_primary do %>
                          <span class="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-green-100 text-green-800 ml-2">
                            <svg class="w-3 h-3 mr-1" fill="currentColor" viewBox="0 0 20 20">
                              <path
                                fill-rule="evenodd"
                                d="M6.267 3.455a3.066 3.066 0 001.745-.723 3.066 3.066 0 013.976 0 3.066 3.066 0 001.745.723 3.066 3.066 0 012.812 2.812c.051.643.304 1.254.723 1.745a3.066 3.066 0 010 3.976 3.066 3.066 0 00-.723 1.745 3.066 3.066 0 01-2.812 2.812 3.066 3.066 0 00-1.745.723 3.066 3.066 0 01-3.976 0 3.066 3.066 0 00-1.745-.723 3.066 3.066 0 01-2.812-2.812 3.066 3.066 0 00-.723-1.745 3.066 3.066 0 010-3.976 3.066 3.066 0 00.723-1.745 3.066 3.066 0 012.812-2.812zm7.44 5.252a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z"
                                clip-rule="evenodd"
                              />
                            </svg>
                            Primary
                          </span>
                        <% end %>
                      </div>
                      
                      <p class="text-sm text-gray-500 dark:text-gray-400 mt-1">
                        {format_bytes(attachment.file_size)} •
                        <span class="capitalize">{attachment.file_type}</span>
                        <%= if attachment.inserted_at do %>
                          • Uploaded {format_date(attachment.inserted_at)}
                        <% end %>
                      </p>
                      
                      <%= if attachment.description && attachment.description != "" do %>
                        <p class="text-xs text-gray-400 dark:text-white mt-1">
                          <svg class="inline w-3 h-3 mr-1" fill="currentColor" viewBox="0 0 20 20">
                            <path
                              fill-rule="evenodd"
                              d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z"
                              clip-rule="evenodd"
                            />
                          </svg> {attachment.description}
                        </p>
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
                        class="inline-flex items-center px-2 py-1 border border-gray-300 rounded text-xs text-gray-700 dark:text-white hover:bg-gray-50 dark:hover:bg-gray-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
                      >
                        <svg
                          class="w-3 h-3 mr-1"
                          fill="none"
                          stroke="currentColor"
                          viewBox="0 0 24 24"
                        >
                          <path
                            stroke-linecap="round"
                            stroke-linejoin="round"
                            stroke-width="2"
                            d="M11.049 2.927c.3-.921 1.603-.921 1.902 0l1.519 4.674a1 1 0 00.95.69h4.915c.969 0 1.371 1.24.588 1.81l-3.976 2.888a1 1 0 00-.363 1.118l1.518 4.674c.3.922-.755 1.688-1.538 1.118l-3.976-2.888a1 1 0 00-1.176 0l-3.976 2.888c-.783.57-1.838-.197-1.538-1.118l1.518-4.674a1 1 0 00-.363-1.118l-3.976-2.888c-.784-.57-.38-1.81.588-1.81h4.914a1 1 0 00.951-.69l1.519-4.674z"
                          />
                        </svg>
                        Set Primary
                      </button>
                    <% end %>
                    <!-- Download -->
                    <a
                      href={Catalog.get_file_url(attachment)}
                      download={attachment.original_name}
                      class="inline-flex items-center px-2 py-1 border border-gray-300 rounded text-xs text-gray-700 dark:text-white hover:bg-gray-50 dark:hover:bg-gray-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
                    >
                      <svg class="w-3 h-3 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path
                          stroke-linecap="round"
                          stroke-linejoin="round"
                          stroke-width="2"
                          d="M12 10v6m0 0l-3-3m3 3l3-3m2 8H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"
                        />
                      </svg>
                      Download
                    </a>
                    <!-- Delete -->
                    <button
                      type="button"
                      phx-click="delete_attachment"
                      phx-value-id={attachment.id}
                      phx-target={@myself}
                      data-confirm="Are you sure you want to delete this file?"
                      class="inline-flex items-center px-2 py-1 border border-red-300 rounded text-xs text-red-700 dark:text-red-400 hover:bg-red-50 dark:hover:bg-red-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-red-500"
                    >
                      <svg class="w-3 h-3 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path
                          stroke-linecap="round"
                          stroke-linejoin="round"
                          stroke-width="2"
                          d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"
                        />
                      </svg>
                      Delete
                    </button>
                  </div>
                </div>
              <% end %>
            </div>
            <!-- Attachment Stats -->
            <div class="mt-6 pt-4 border-t border-gray-200">
              <div class="grid grid-cols-2 md:grid-cols-4 gap-4">
                <div class="text-center">
                  <p class="text-2xl font-semibold text-indigo-600 dark:text-indigo-200">
                    {length(@attachments)}
                  </p>
                  
                  <p class="text-xs text-gray-500 dark:text-white uppercase tracking-wider">
                    Total Files
                  </p>
                </div>
                
                <div class="text-center">
                  <p class="text-2xl font-semibold text-indigo-600 dark:text-indigo-200">
                    {format_bytes(Enum.sum(Enum.map(@attachments, & &1.file_size)))}
                  </p>
                  
                  <p class="text-xs text-gray-500 dark:text-white uppercase tracking-wider">
                    Total Size
                  </p>
                </div>
                
                <div class="text-center">
                  <p class="text-2xl font-semibold text-indigo-600 dark:text-indigo-200">
                    {@attachments |> Enum.count(&is_recent_upload?(&1.inserted_at))}
                  </p>
                  
                  <p class="text-xs text-gray-500 dark:text-white uppercase tracking-wider">
                    Recent Uploads
                  </p>
                </div>
                
                <div class="text-center">
                  <p class="text-2xl font-semibold text-indigo-600 dark:text-indigo-200">
                    {@attachments |> Enum.count(& &1.is_primary)}
                  </p>
                  
                  <p class="text-xs text-gray-500 dark:text-white uppercase tracking-wider">
                    Primary Set
                  </p>
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
      |> assign(:collection_type, nil)
      |> assign(:entity, nil)
      |> assign(:filter_type, nil)
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
  def update(%{entity: entity} = assigns, socket) do
    attachments = Catalog.list_attachments(entity)
    collection_type = assigns[:collection_type] || get_entity_collection_type(entity)

    # Only configure upload if there are no active entries
    socket =
      if Enum.empty?(socket.assigns.uploads.attachments.entries) do
        configure_upload_for_collection_type(socket, collection_type)
      else
        socket
      end

    socket =
      socket
      |> assign(:entity, entity)
      |> assign(:attachments, attachments)
      |> assign(:collection_type, collection_type)
      |> assign(:allowed_types, get_allowed_file_types(collection_type))
      |> assign(:upload_hints, get_upload_hints(collection_type))

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
  def handle_event("filter_by_type", %{"value" => filter_type}, socket) do
    {:noreply, assign(socket, :filter_type, filter_type)}
  end

  @impl true
  def handle_event("set_primary", %{"id" => attachment_id}, socket) do
    attachment = Enum.find(socket.assigns.attachments, &(&1.id == attachment_id))

    case Catalog.set_primary_attachment(attachment) do
      {:ok, _} ->
        updated_attachments = Catalog.list_attachments(socket.assigns.entity)
        send(self(), {:attachment_updated, :primary_set})

        socket =
          socket
          |> assign(:attachments, updated_attachments)
          |> put_flash(:info, "Primary attachment updated successfully")

        {:noreply, socket}

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

        socket =
          socket
          |> assign(:attachments, updated_attachments)
          |> put_flash(:info, "Attachment deleted successfully")

        {:noreply, socket}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to delete attachment")}
    end
  end

  defp handle_progress(:attachments, entry, socket) when entry.done? do
    case consume_uploaded_entry(socket, entry, fn %{path: path} ->
           # Create a Plug.Upload struct instead of a plain map
           upload = %Plug.Upload{
             path: path,
             filename: entry.client_name,
             content_type: entry.client_type
           }

           case Catalog.create_attachment(socket.assigns.entity, %{
                  upload: upload,
                  description: ""
                }) do
             {:ok, attachment} ->
               send(self(), {:attachment_updated, :uploaded})
               {:ok, attachment}

             {:error, changeset} ->
               {:error, changeset}
           end
         end) do
      # Handle the result of consume_uploaded_entry
      [{:ok, _attachment}] ->
        updated_attachments = Catalog.list_attachments(socket.assigns.entity)
        {:noreply, assign(socket, :attachments, updated_attachments)}

      [{:error, changeset}] ->
        error_message =
          case changeset.errors do
            [attachable_id: {msg, _}] ->
              "This entity already has an attachment. #{msg}"

            _ ->
              "Failed to save attachment"
          end

        {:noreply, put_flash(socket, :error, error_message)}

      _ ->
        {:noreply, put_flash(socket, :error, "Unexpected error during upload")}
    end
  end

  defp handle_progress(:attachments, _entry, socket) do
    {:noreply, socket}
  end

  # Collection type specific functions
  defp get_entity_collection_type(%{collection_type: type}), do: type
  defp get_entity_collection_type(%{collection: %{collection_type: type}}), do: type
  defp get_entity_collection_type(_), do: nil

  defp configure_upload_for_collection_type(socket, collection_type) do
    accepted_types =
      case collection_type do
        "document" -> ~w(.pdf .doc .docx .xls .xlsx .txt .csv .rtf)
        "photo" -> ~w(.jpg .jpeg .png .gif .webp .svg .bmp .tiff)
        "video" -> ~w(.mp4 .mov .avi .mkv .wmv .flv .webm)
        "audio" -> ~w(.mp3 .wav .ogg .flac .aac .m4a)
        "software" -> ~w(.exe .msi .dmg .pkg .deb .rpm .zip .tar.gz)
        _ -> :any
      end

    allow_upload(socket, :attachments,
      accept: accepted_types,
      max_entries: 10,
      max_file_size: 100_000_000,
      progress: &handle_progress/3,
      auto_upload: true
    )
  end

  defp get_allowed_file_types("document"), do: ["PDF", "Word", "Excel", "Text files"]
  defp get_allowed_file_types("photo"), do: ["JPEG", "PNG", "GIF", "WebP", "SVG"]
  defp get_allowed_file_types("video"), do: ["MP4", "MOV", "AVI", "MKV", "WebM"]
  defp get_allowed_file_types("audio"), do: ["MP3", "WAV", "OGG", "FLAC", "AAC"]
  defp get_allowed_file_types("software"), do: ["Executables", "Installers", "Archives"]
  defp get_allowed_file_types(_), do: ["Any file type"]

  defp get_upload_hints("document"),
    do: "Upload documents like PDFs, Word files, spreadsheets, and presentations."

  defp get_upload_hints("photo"),
    do: "Upload high-quality images. JPEG and PNG formats work best."

  defp get_upload_hints("video"),
    do: "Upload video files. MP4 format is recommended for best compatibility."

  defp get_upload_hints("audio"), do: "Upload audio files like music, podcasts, or recordings."

  defp get_upload_hints("software"),
    do: "Upload software packages, executables, or installation files."

  defp get_upload_hints(_), do: "Upload any type of file to this collection."

  defp format_allowed_types(types) do
    case length(types) do
      0 -> "No files allowed"
      1 -> hd(types)
      2 -> Enum.join(types, " and ")
      _ -> "#{Enum.join(Enum.take(types, -1), ", ")} and #{List.last(types)}"
    end
  end

  defp is_file_type_allowed?(mime_type, collection_type) do
    file_type = Attachment.determine_file_type(mime_type)

    allowed_types =
      case collection_type do
        "document" -> ["document"]
        "photo" -> ["image"]
        # Allow images as thumbnails
        "video" -> ["video", "image"]
        # Allow images as album art
        "audio" -> ["audio", "image"]
        "software" -> ["software", "archive", "document"]
        _ -> ["document", "image", "video", "audio", "software", "archive", "other"]
      end

    file_type in allowed_types
  end

  defp determine_file_type_from_name(filename) do
    extension = Path.extname(filename) |> String.downcase()

    case extension do
      ext when ext in [".jpg", ".jpeg", ".png", ".gif", ".webp", ".svg"] -> "image"
      ext when ext in [".mp4", ".mov", ".avi", ".mkv", ".wmv"] -> "video"
      ext when ext in [".mp3", ".wav", ".ogg", ".flac", ".aac"] -> "audio"
      ext when ext in [".pdf", ".doc", ".docx", ".xls", ".xlsx", ".txt"] -> "document"
      ext when ext in [".exe", ".msi", ".dmg", ".pkg", ".deb", ".rpm"] -> "software"
      ext when ext in [".zip", ".rar", ".7z", ".tar", ".gz"] -> "archive"
      _ -> "other"
    end
  end

  defp filter_attachments(attachments, ""), do: attachments

  defp filter_attachments(attachments, filter_type) do
    Enum.filter(attachments, &(&1.file_type == filter_type))
  end

  defp get_file_type_counts(attachments) do
    attachments
    |> Enum.group_by(& &1.file_type)
    |> Enum.map(fn {type, items} -> {type, length(items)} end)
    |> Enum.sort_by(fn {_type, count} -> -count end)
  end

  defp collection_type_icon(collection_type, extra_class \\ "h-12 w-12 text-gray-400")

  defp collection_type_icon(nil, extra_class) do
    assigns = %{extra_class: extra_class}

    ~H"""
    <svg class={@extra_class} fill="none" stroke="currentColor" viewBox="0 0 48 48">
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        stroke-width="2"
        d="M7 21l3-3m-3 3l3 3m-3-3h8m13 0a9 9 0 11-18 0 9 9 0 0118 0z"
      />
    </svg>
    """
  end

  defp collection_type_icon("document", extra_class) do
    assigns = %{extra_class: extra_class}

    ~H"""
    <svg class={@extra_class} fill="currentColor" viewBox="0 0 20 20">
      <path
        fill-rule="evenodd"
        d="M4 4a2 2 0 012-2h4.586A2 2 0 0112 2.586L15.414 6A2 2 0 0116 7.414V16a2 2 0 01-2 2H6a2 2 0 01-2-2V4zm2 6a1 1 0 011-1h6a1 1 0 110 2H7a1 1 0 01-1-1zm1 3a1 1 0 100 2h6a1 1 0 100-2H7z"
        clip-rule="evenodd"
      />
    </svg>
    """
  end

  defp collection_type_icon("photo", extra_class) do
    assigns = %{extra_class: extra_class}

    ~H"""
    <svg class={@extra_class} fill="currentColor" viewBox="0 0 20 20">
      <path
        fill-rule="evenodd"
        d="M4 3a2 2 0 00-2 2v10a2 2 0 002 2h12a2 2 0 002-2V5a2 2 0 00-2-2H4zm12 12H4l4-8 3 6 2-4 3 6z"
        clip-rule="evenodd"
      />
    </svg>
    """
  end

  defp collection_type_icon("video", extra_class) do
    assigns = %{extra_class: extra_class}

    ~H"""
    <svg class={@extra_class} fill="currentColor" viewBox="0 0 20 20">
      <path
        fill-rule="evenodd"
        d="M2 6a2 2 0 012-2h6a2 2 0 012 2v4a2 2 0 01-2 2H4a2 2 0 01-2-2V6zm12.553 1.106A1 1 0 0014 8v4a1 1 0 00.553.894l2 1A1 1 0 0018 13V7a1 1 0 00-1.447-.894l-2 1z"
        clip-rule="evenodd"
      />
    </svg>
    """
  end

  defp collection_type_icon("audio", extra_class) do
    assigns = %{extra_class: extra_class}

    ~H"""
    <svg class={@extra_class} fill="currentColor" viewBox="0 0 20 20" aria-hidden="true">
      <path
        fill-rule="evenodd"
        d="M19.5 3.75a.75.75 0 01.75.75v12.063a4.125 4.125 0 11-1.5-3.188V7.098l-9 2.25v8.465a4.125 4.125 0 11-1.5-3.188V6a.75.75 0 01.576-.73l10.5-2.25a.75.75 0 01.174-.02z"
        clip-rule="evenodd"
      />
    </svg>
    """
  end

  defp collection_type_icon("software", extra_class) do
    assigns = %{extra_class: extra_class}

    ~H"""
    <svg class={@extra_class} fill="currentColor" viewBox="0 0 20 20">
      <path
        fill-rule="evenodd"
        d="M12.316 3.051a1 1 0 01.633 1.265l-4 12a1 1 0 11-1.898-.632l4-12a1 1 0 011.265-.633zM5.707 6.293a1 1 0 010 1.414L3.414 10l2.293 2.293a1 1 0 11-1.414 1.414l-3-3a1 1 0 010-1.414l3-3a1 1 0 011.414 0zm8.586 0a1 1 0 011.414 0l3 3a1 1 0 010 1.414l-3 3a1 1 0 11-1.414-1.414L16.586 10l-2.293-2.293a1 1 0 010-1.414z"
        clip-rule="evenodd"
      />
    </svg>
    """
  end

  defp collection_type_icon(_, extra_class) do
    assigns = %{extra_class: extra_class}

    ~H"""
    <svg class={@extra_class} fill="currentColor" viewBox="0 0 20 20">
      <path
        fill-rule="evenodd"
        d="M3 4a1 1 0 011-1h3a1 1 0 011 1v3a1 1 0 01-1 1H4a1 1 0 01-1-1V4zM3 10a1 1 0 011-1h3a1 1 0 011 1v3a1 1 0 01-1 1H4a1 1 0 01-1-1v-3zM9 4a1 1 0 011-1h3a1 1 0 011 1v3a1 1 0 01-1 1h-3a1 1 0 01-1-1V4zM9 10a1 1 0 011-1h3a1 1 0 011 1v3a1 1 0 01-1 1h-3a1 1 0 01-1-1v-3z"
        clip-rule="evenodd"
      />
    </svg>
    """
  end

  # Helper functions
  defp format_bytes(bytes) when bytes < 1024, do: "#{bytes} B"
  defp format_bytes(bytes) when bytes < 1_048_576, do: "#{Float.round(bytes / 1024, 1)} KB"

  defp format_bytes(bytes) when bytes < 1_073_741_824,
    do: "#{Float.round(bytes / 1_048_576, 1)} MB"

  defp format_bytes(bytes), do: "#{Float.round(bytes / 1_073_741_824, 1)} GB"

  defp format_date(%DateTime{} = datetime) do
    datetime
    |> DateTime.to_date()
    |> Date.to_string()
  end

  defp is_recent_upload?(nil), do: false

  defp is_recent_upload?(inserted_at) do
    # Check if the file was uploaded in the last 7 days
    DateTime.diff(DateTime.utc_now(), inserted_at) < 7 * 24 * 60 * 60
  end

  defp file_type_icon("image") do
    assigns = %{}

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

  defp file_type_icon("document") do
    assigns = %{}

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

  defp file_type_icon("video") do
    assigns = %{}

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

  defp file_type_icon("audio") do
    assigns = %{}

    ~H"""
    <svg class="h-8 w-8 text-yellow-400" fill="currentColor" viewBox="0 0 24 24" aria-hidden="true">
      <path
        fill-rule="evenodd"
        d="M19.5 3.75a.75.75 0 01.75.75v12.063a4.125 4.125 0 11-1.5-3.188V7.098l-9 2.25v8.465a4.125 4.125 0 11-1.5-3.188V6a.75.75 0 01.576-.73l10.5-2.25a.75.75 0 01.174-.02z"
        clip-rule="evenodd"
      />
    </svg>
    """
  end

  defp file_type_icon("software") do
    assigns = %{}

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

  defp file_type_icon("archive") do
    assigns = %{}

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

  defp file_type_icon(_) do
    assigns = %{}

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
