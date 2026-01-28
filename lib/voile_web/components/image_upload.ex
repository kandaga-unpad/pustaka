defmodule VoileWeb.Components.ImageUpload do
  use Phoenix.Component

  import VoileWeb.CoreComponents

  # Image Upload Component with multiple sources
  attr :form, :map, required: true
  attr :field, :atom, required: true
  attr :label, :string, default: "Image"
  attr :upload_name, :atom, default: :image
  attr :tab, :string, default: "upload"
  attr :thumbnail_source, :string, default: nil
  attr :thumbnail_url_input, :string, default: ""
  attr :asset_vault_files, :list, default: []
  attr :shown_images_count, :integer, default: 12
  attr :accept, :list, default: ~w(.jpg .jpeg .png .webp)
  attr :max_entries, :integer, default: 1
  attr :target, :any, default: nil
  attr :show_remove, :boolean, default: true
  attr :uploads, :map, required: true

  def image_upload(assigns) do
    ~H"""
    <div class="space-y-6">
      <%= if @form[@field].value == nil or @form[@field].value == "" do %>
        <!-- Enhanced Tabs for image upload options -->
        <div class="mb-6">
          <nav
            class="flex space-x-1 bg-gray-100 dark:bg-gray-800 p-1 rounded-lg"
            aria-label="Image upload options"
          >
            <button
              type="button"
              phx-click="switch_image_tab"
              phx-value-tab="upload"
              phx-target={@target}
              class={"flex-1 py-2.5 px-4 rounded-md text-sm font-medium transition-all duration-200 #{if @tab == "upload", do: "bg-white dark:bg-gray-700 text-voile-primary shadow-sm", else: "text-gray-600 dark:text-gray-400 hover:text-gray-900 dark:hover:text-gray-5000 hover:bg-gray-50 dark:hover:bg-gray-750"}"}
            >
              <svg
                class="w-4 h-4 inline mr-2"
                fill="none"
                stroke="currentColor"
                viewBox="0 0 24 24"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12"
                >
                </path>
              </svg>
              Upload Local
            </button>
            <button
              type="button"
              phx-click="switch_image_tab"
              phx-value-tab="asset_vault"
              phx-target={@target}
              class={"flex-1 py-2.5 px-4 rounded-md text-sm font-medium transition-all duration-200 #{if @tab == "asset_vault", do: "bg-white dark:bg-gray-700 text-voile-primary shadow-sm", else: "text-gray-600 dark:text-gray-400 hover:text-gray-900 dark:hover:text-gray-500 hover:bg-gray-50 dark:hover:bg-gray-750"}"}
            >
              <svg
                class="w-4 h-4 inline mr-2"
                fill="none"
                stroke="currentColor"
                viewBox="0 0 24 24"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10"
                >
                </path>
              </svg>
              Asset Vault
            </button>
            <button
              type="button"
              phx-click="switch_image_tab"
              phx-value-tab="url"
              phx-target={@target}
              class={"flex-1 py-2.5 px-4 rounded-md text-sm font-medium transition-all duration-200 #{if @tab == "url", do: "bg-white dark:bg-gray-700 text-voile-primary shadow-sm", else: "text-gray-600 dark:text-gray-400 hover:text-gray-900 dark:hover:text-gray-5000 hover:bg-gray-50 dark:hover:bg-gray-750"}"}
            >
              <svg
                class="w-4 h-4 inline mr-2"
                fill="none"
                stroke="currentColor"
                viewBox="0 0 24 24"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M13.828 10.172a4 4 0 00-5.656 0l-4 4a4 4 0 105.656 5.656l1.102-1.101m-.758-4.899a4 4 0 005.656 0l4-4a4 4 0 00-5.656-5.656l-1.1 1.1"
                >
                </path>
              </svg>
              From URL
            </button>
          </nav>
        </div>

        <%= if @tab == "upload" do %>
          <!-- Enhanced Upload Area -->
          <div class="relative">
            <div
              class="border-2 border-dashed border-gray-300 dark:border-gray-600 rounded-xl p-12 text-center hover:border-voile-primary hover:bg-voile-primary/5 dark:hover:bg-voile-primary/10 transition-all duration-300 cursor-pointer group"
              phx-drop-target={@uploads[@upload_name].ref}
            >
              <div class="space-y-6">
                <div class="mx-auto w-20 h-20 bg-gradient-to-br from-voile-primary/10 to-voile-info/10 rounded-full flex items-center justify-center group-hover:from-voile-primary/20 group-hover:to-voile-info/20 transition-all duration-300">
                  <svg
                    class="w-10 h-10 text-voile-primary group-hover:text-voile-primary/80 transition-colors"
                    fill="none"
                    stroke="currentColor"
                    viewBox="0 0 24 24"
                  >
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12"
                    >
                    </path>
                  </svg>
                </div>

                <div class="space-y-2">
                  <h3 class="text-lg font-semibold text-gray-900 dark:text-white">
                    Upload {@label}
                  </h3>
                  <p class="text-sm text-gray-600 dark:text-gray-400">
                    Drag and drop your image here, or click to browse
                  </p>
                  <p class="text-xs text-gray-500 dark:text-gray-500">
                    {Enum.join(@accept, ", ")} up to 10MB
                  </p>
                </div>

                <div class="pt-4">
                  <.live_file_input upload={@uploads[@upload_name]} />
                  <label
                    for={@uploads[@upload_name].ref}
                    class="inline-flex items-center px-6 py-3 bg-voile-primary hover:bg-voile-primary/90 text-white font-medium rounded-lg shadow-lg hover:shadow-xl transition-all duration-200 cursor-pointer transform hover:-translate-y-0.5"
                  >
                    <svg
                      class="w-5 h-5 mr-2"
                      fill="none"
                      stroke="currentColor"
                      viewBox="0 0 24 24"
                    >
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        stroke-width="2"
                        d="M12 6v6m0 0v6m0-6h6m-6 0H6"
                      >
                      </path>
                    </svg>
                    Choose File
                  </label>
                </div>
              </div>
            </div>
          </div>
        <% end %>

        <%= if @tab == "asset_vault" do %>
          <!-- Enhanced Asset Vault Selection -->
          <div class="space-y-6">
            <div class="text-center">
              <h3 class="text-lg font-semibold text-gray-900 dark:text-white mb-2">
                Select from Asset Vault
              </h3>
              <p class="text-sm text-gray-600 dark:text-gray-400">
                Choose an existing image from your collection
              </p>
            </div>

            <div class="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4 max-h-96 overflow-y-auto p-4 bg-gray-50 dark:bg-gray-800/50 rounded-lg">
              <%= for attachment <- Enum.take(@asset_vault_files, @shown_images_count) do %>
                <div
                  class="relative group cursor-pointer rounded-lg overflow-hidden shadow-sm hover:shadow-md transition-all duration-200 transform hover:-translate-y-1"
                  phx-click="select_image_from_vault"
                  phx-value-attachment_id={attachment.id}
                  phx-target={@target}
                >
                  <div class="aspect-square bg-gray-200 dark:bg-gray-700">
                    <img
                      src={get_file_url(attachment)}
                      alt={attachment.original_name}
                      class="w-full h-full object-cover"
                    />
                  </div>
                  <div class="absolute inset-0 bg-voile-primary/90 opacity-0 group-hover:opacity-100 transition-opacity duration-200 flex items-center justify-center">
                    <div class="text-center text-white">
                      <svg
                        class="w-8 h-8 mx-auto mb-2"
                        fill="none"
                        stroke="currentColor"
                        viewBox="0 0 24 24"
                      >
                        <path
                          stroke-linecap="round"
                          stroke-linejoin="round"
                          stroke-width="2"
                          d="M5 13l4 4L19 7"
                        >
                        </path>
                      </svg>
                      <span class="text-sm font-medium">Select Image</span>
                    </div>
                  </div>
                  <div class="absolute bottom-0 left-0 right-0 bg-gradient-to-t from-black/60 to-transparent p-2">
                    <p class="text-white text-xs truncate">{attachment.original_name}</p>
                  </div>
                </div>
              <% end %>
            </div>

            <%= if length(@asset_vault_files) > @shown_images_count do %>
              <div class="text-center mt-4">
                <.button
                  type="button"
                  phx-click="load_more_images"
                  phx-target={@target}
                  class="px-4 py-2 bg-voile-primary hover:bg-voile-primary/90 text-white font-medium rounded-lg"
                >
                  Load More Images
                </.button>
              </div>
            <% end %>

            <%= if Enum.empty?(@asset_vault_files) do %>
              <div class="text-center py-12">
                <svg
                  class="w-16 h-16 mx-auto text-gray-400 mb-4"
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"
                  >
                  </path>
                </svg>
                <h3 class="text-lg font-medium text-gray-900 dark:text-white mb-2">
                  No Images Found
                </h3>
                <p class="text-gray-500 dark:text-gray-400">
                  Upload some images to your asset vault first
                </p>
              </div>
            <% end %>
          </div>
        <% end %>

        <%= if @tab == "url" do %>
          <!-- Enhanced URL Input -->
          <div class="space-y-6">
            <div class="text-center">
              <h3 class="text-lg font-semibold text-gray-900 dark:text-white mb-2">
                Add from URL
              </h3>
              <p class="text-sm text-gray-600 dark:text-gray-400">
                Paste an image URL to fetch and save it
              </p>
            </div>

            <div class="bg-gray-50 dark:bg-gray-800/50 rounded-lg p-6">
              <div class="flex gap-3">
                <div class="flex-1">
                  <.input
                    type="url"
                    name="image_url"
                    value={@thumbnail_url_input}
                    placeholder="https://example.com/image.jpg"
                    phx-change="update_image_url"
                    phx-target={@target}
                  />
                </div>
                <.button
                  type="button"
                  phx-click="add_image_from_url"
                  phx-value-url={@thumbnail_url_input}
                  phx-target={@target}
                  class="px-6 py-3 bg-voile-primary hover:bg-voile-primary/90 text-white font-medium rounded-lg shadow-lg hover:shadow-xl transition-all duration-200 transform hover:-translate-y-0.5"
                  phx-disable-with="Adding..."
                >
                  <svg
                    class="w-5 h-5 mr-2 inline"
                    fill="none"
                    stroke="currentColor"
                    viewBox="0 0 24 24"
                  >
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M12 10v6m0 0l-3-3m3 3l3-3m2 8H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"
                    >
                    </path>
                  </svg>
                  Add Image
                </.button>
              </div>

              <div class="mt-4 text-xs text-gray-500 dark:text-gray-400">
                <p>Supported formats: {Enum.join(@accept, ", ")}</p>
              </div>
            </div>
          </div>
        <% end %>
      <% end %>
      
    <!-- Upload Progress -->
      <%= for entry <- @uploads[@upload_name].entries do %>
        <div class="bg-voile-info/5 dark:bg-voile-info/10 border border-voile-info/20 rounded-lg p-4">
          <div class="flex items-center space-x-4">
            <div class="w-12 h-12 bg-voile-primary/10 rounded-lg flex items-center justify-center">
              <svg
                class="w-6 h-6 text-voile-primary animate-pulse"
                fill="none"
                stroke="currentColor"
                viewBox="0 0 24 24"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"
                >
                </path>
              </svg>
            </div>

            <div class="flex-1 min-w-0">
              <p class="text-gray-900 dark:text-white font-medium text-sm truncate">
                {entry.client_name}
              </p>
              <p class="text-gray-600 dark:text-gray-400 text-xs">Uploading image...</p>

              <div class="mt-3">
                <div class="flex justify-between text-xs text-gray-600 dark:text-gray-400 mb-1">
                  <span>Progress</span>
                  <span>{entry.progress}%</span>
                </div>
                <div class="bg-gray-200 dark:bg-gray-700 rounded-full h-2 overflow-hidden">
                  <div
                    class="bg-gradient-to-r from-voile-primary to-voile-info h-full rounded-full transition-all duration-300 ease-out"
                    style={"width: #{entry.progress}%"}
                  >
                  </div>
                </div>
              </div>
            </div>

            <div class="flex-shrink-0">
              <button
                type="button"
                phx-click="cancel_image_upload"
                phx-value-ref={entry.ref}
                phx-target={@target}
                class="text-gray-400 hover:text-red-500 transition-colors"
              >
                <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M6 18L18 6M6 6l12 12"
                  >
                  </path>
                </svg>
              </button>
            </div>
          </div>
        </div>
      <% end %>
      
    <!-- Selected Image Display -->
      <%= if @form[@field].value != nil and @form[@field].value != "" do %>
        <div class="bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded-xl p-6 shadow-sm">
          <div class="flex items-start space-x-6">
            <div class="relative group flex-shrink-0">
              <div class="w-24 h-24 bg-gray-100 dark:bg-gray-700 rounded-lg overflow-hidden">
                <img
                  src={@form[@field].value}
                  alt={@label}
                  class="w-full h-full object-cover"
                />
              </div>
              <div class="absolute inset-0 bg-black/40 opacity-0 group-hover:opacity-100 rounded-lg transition-opacity duration-200 flex items-center justify-center">
                <svg
                  class="w-6 h-6 text-white"
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 000 16zm-2-9a5 5 0 11-10 0 5 5 0 0110 0z"
                  >
                  </path>
                </svg>
              </div>
            </div>

            <div class="flex-1 min-w-0">
              <div class="flex items-center space-x-2 mb-2">
                <svg class="w-5 h-5 text-green-500" fill="currentColor" viewBox="0 0 20 20">
                  <path
                    fill-rule="evenodd"
                    d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z"
                    clip-rule="evenodd"
                  >
                  </path>
                </svg>
                <span class="text-sm font-medium text-gray-900 dark:text-white">
                  {@label} Ready
                </span>
              </div>

              <p class="text-sm text-gray-600 dark:text-gray-400 mb-4">
                Your {String.downcase(@label)} has been successfully uploaded and is ready to use.
              </p>

              <%= if @show_remove do %>
                <div class="flex items-center space-x-3">
                  <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-voile-primary/10 text-voile-primary">
                    <%= case @thumbnail_source do %>
                      <% "local" -> %>
                        Uploaded
                      <% "vault" -> %>
                        From Vault
                      <% "url" -> %>
                        From URL
                      <% _ -> %>
                        Ready
                    <% end %>
                  </span>

                  <.button
                    type="button"
                    phx-click="delete_image"
                    phx-value-image={@form[@field].value}
                    phx-target={@target}
                    class="inline-flex items-center px-3 py-1.5 text-sm font-medium text-red-600 hover:text-red-700 hover:bg-red-50 dark:text-red-400 dark:hover:text-red-300 dark:hover:bg-red-900/20 rounded-lg transition-colors"
                    phx-disable-with="Removing..."
                  >
                    <svg
                      class="w-4 h-4 mr-1.5"
                      fill="none"
                      stroke="currentColor"
                      viewBox="0 0 24 24"
                    >
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        stroke-width="2"
                        d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"
                      >
                      </path>
                    </svg>
                    Remove
                  </.button>
                </div>
              <% end %>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  # Helper function to get file URL (can be overridden)
  defp get_file_url(attachment) do
    # This should be implemented based on your storage system
    # For now, return the file_path directly
    attachment.file_path
  end
end
