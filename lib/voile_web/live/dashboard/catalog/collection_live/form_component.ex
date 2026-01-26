defmodule VoileWeb.Dashboard.Catalog.CollectionLive.FormComponent do
  use VoileWeb, :live_component

  alias Voile.Schema.Catalog
  alias Voile.Schema.Catalog.Item
  alias Ecto.Changeset

  import VoileWeb.Dashboard.Catalog.CollectionLive.FormCollectionHelper

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <%= if msg = @flash["error"] do %>
        <.flash kind={:error} class="mb-4">{msg}</.flash>
      <% end %>

      <%= if msg = @flash["info"] do %>
        <.flash kind={:info} class="mb-4">{msg}</.flash>
      <% end %>

      <.modal id="col_field_delete_confirmation">
        <div class="text-center">
          <h5>Are you sure want to delete this field ?</h5>

          <p class="text-sm text-voile-dark">
            This action cannot be undone. Please confirm your action.
          </p>

          <p class="text-sm italic font-semibold text-voile-error">You will delete this property :</p>

          <div class="my-4">
            <h6 class="text-voile-primary">
              {(@chosen_collection_field && @chosen_collection_field.label) || ""}
            </h6>

            <p class="text-xs">with value :</p>

            <h5 class="font-bold text-voile-dark dark:text-voile">
              {(@chosen_collection_field && @chosen_collection_field.value) || ""}
            </h5>

            <p class="text-xs">from this collection :</p>

            <h6 class="text-voile-warning">{@collection.title}</h6>
          </div>

          <div class="flex items-center w-full my-5 gap-5">
            <.button
              class="w-full cancel-btn"
              phx-click={
                JS.push("delete_existed_field") |> hide_modal("col_field_delete_confirmation")
              }
              phx-value-id={@delete_field_confirmation_id}
              phx-target={@myself}
            >
              Delete
            </.button>
            <.button
              class="w-full warning-btn"
              phx-click={hide_modal("col_field_delete_confirmation")}
              phx-target={@myself}
            >
              Cancel
            </.button>
          </div>
        </div>
      </.modal>

      <.modal id="item_delete_confirmation">
        <div class="text-center">
          <h5>Are you sure want to delete this item data?</h5>

          <p class="text-sm text-voile-dark">
            This action cannot be undone. Please confirm your action and make sure this item is not in use.
          </p>

          <div class="my-4">
            <p class="text-xs">Item Code :</p>

            <h6 class="text-voile-primary">
              {(@chosen_item_field && @chosen_item_field.item_code) || ""}
            </h6>
          </div>

          <p class="text-sm">will be deleted forever from this collection :</p>

          <h6 class="text-voile-warning">{@collection.title}</h6>
        </div>

        <div class="flex items-center w-full my-5 gap-5">
          <.button
            class="w-full cancel-btn"
            phx-click={JS.push("delete_existing_item") |> hide_modal("item_delete_confirmation")}
            phx-value-id={@delete_item_confirmation_id}
            phx-target={@myself}
          >
            Delete
          </.button>
          <.button
            class="w-full warning-btn"
            phx-click={hide_modal("item_delete_confirmation")}
            phx-target={@myself}
          >
            Cancel
          </.button>
        </div>
      </.modal>

      <.header>
        {@title}
        <:subtitle>Use this form to manage collection records in your database.</:subtitle>
      </.header>

      <div class="text-xs italic">
        {if @action == :edit, do: "Edit Collection", else: "New Collection"} - Step {@step} of 3
      </div>

      <div class="mb-12">
        <%= case @step do %>
          <% 1 -> %>
            <p class="font-bold">Step 1: <span class="text-voile-primary">Basic Information</span></p>
          <% 2 -> %>
            <p class="font-bold">
              Step 2: <span class="text-voile-primary">Additional Collection Fields</span>
            </p>
          <% 3 -> %>
            <p class="font-bold">
              Step 3: <span class="text-voile-primary">Item Data and Attachments</span>
            </p>
        <% end %>
      </div>

      <.form
        for={@form}
        id="collection-form-1"
        phx-target={@myself}
        phx-change="validate"
        phx-debounce="300"
        phx-submit="save"
      >
        <%= if @step == 1 do %>
          <.input field={@form[:id]} type="hidden" />
          <.input
            field={@form[:type_id]}
            label="Resource Type"
            type="select"
            options={
              @collection_type
              |> Enum.group_by(& &1.glam_type)
              |> Enum.sort_by(fn {group, _} -> group end)
              |> Enum.map(fn {group, items} ->
                sorted_items =
                  items |> Enum.sort_by(& &1.label) |> Enum.map(fn ct -> {ct.label, ct.id} end)

                {group, sorted_items}
              end)
            }
            prompt="Select Collection Type"
            required_value={true}
          />
          <!-- Hierarchical Fields - Searchable Parent Collection -->
          <div class="mb-4">
            <label class="block text-sm font-medium mb-2 label">Parent Collection (Optional)</label>
            <div class="relative">
              <.input
                type="text"
                name="parent_search"
                value={@parent_search || ""}
                placeholder="Search for parent collection..."
                class="block w-full px-3 py-2 border border-voile-muted rounded-md shadow-sm focus:outline-none focus:ring-voile-primary focus:border-voile-primary"
                phx-change="search_parent"
                phx-target={@myself}
                phx-debounce="300"
                autocomplete="off"
              />
              <input
                type="hidden"
                name="collection[parent_id]"
                value={@form.params["parent_id"] || ""}
              />
              <%= if @parent_search_results && length(@parent_search_results) > 0 do %>
                <div class="absolute z-10 w-full mt-1 bg-voile-surface border border-voile-muted rounded-md shadow-lg max-h-60 overflow-auto">
                  <%= for collection <- @parent_search_results do %>
                    <div
                      class="px-4 py-2 hover:bg-voile-surface cursor-pointer border-b border-voile-light last:border-b-0"
                      phx-click="select_parent"
                      phx-target={@myself}
                      phx-value-id={collection.id}
                      phx-value-title={collection.title}
                    >
                      <div class="font-medium text-voile">{collection.title}</div>

                      <div class="text-sm text-voile-muted">
                        by {(collection.mst_creator && collection.mst_creator.creator_name) ||
                          "Unknown"}
                      </div>
                    </div>
                  <% end %>
                </div>
              <% end %>

              <%= if @form.params["parent_id"] && @form.params["parent_id"] != "" do %>
                <div class="mt-2 px-3 py-2 bg-voile-info border border-voile-light rounded-md flex items-center justify-between">
                  <span class="text-sm text-voile-primary">
                    Selected: {@selected_parent_title || "Loading..."}
                  </span>
                  <button
                    type="button"
                    class="text-voile-primary hover:text-voile"
                    phx-click="clear_parent"
                    phx-target={@myself}
                  >
                    ✕
                  </button>
                </div>
              <% end %>
            </div>
          </div>

          <.input
            field={@form[:collection_type]}
            label="Collection Type"
            type="select"
            options={Voile.Schema.Catalog.Collection.collection_type_options()}
            prompt="Select collection type"
          />
          <.input
            field={@form[:sort_order]}
            label="Sort Order"
            type="number"
            placeholder="1"
          />
          <%= if can_select_unit?(@current_scope) do %>
            <.input
              field={@form[:unit_id]}
              label="Collection Location"
              type="select"
              options={Enum.map(@node_list, fn node -> {node.name, node.id} end)}
              prompt="Select Collection Location"
              required_value={true}
            />
          <% else %>
            <input type="hidden" name={@form[:unit_id].name} value={@current_scope.user.node_id} />
            <.input
              field={@form[:unit_id]}
              label="Collection Location (Your Unit)"
              type="select"
              options={Enum.map(@node_list, fn node -> {node.name, node.id} end)}
              prompt="Select Collection Location"
              required_value={true}
              disabled={true}
            />
          <% end %>
          <.input field={@form[:title]} type="text" label="Title" required_value={true} />
          <div class="relative" phx-hook="SearchDropdown" id={"creator-search-#{@form[:id].value}"}>
            <.input
              type="text"
              name="creator"
              value={@creator_input || ""}
              label="Creator"
              disabled={@creator_input not in [nil, ""] and @form[:creator_id].value not in [nil, ""]}
              required_value={true}
              autocomplete="off"
              phx-change="search_creator"
              phx-debounce="300"
              phx-target={@myself}
            />
            <input
              type="hidden"
              name={@form[:creator_id].name}
              value={@form[:creator_id].value || ""}
            />
            <%= if @creator_searching do %>
              <div
                class="absolute right-3 top-10"
                aria-label="Searching creators"
                role="status"
              >
                <svg
                  class="animate-spin h-5 w-5 text-voile-dark"
                  xmlns="http://www.w3.org/2000/svg"
                  fill="none"
                  viewBox="0 0 24 24"
                >
                  <circle
                    class="opacity-25"
                    cx="12"
                    cy="12"
                    r="10"
                    stroke="currentColor"
                    stroke-width="4"
                  >
                  </circle>

                  <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8v4a4 4 0 00-4 4H4z">
                  </path>
                </svg>
              </div>
            <% end %>

            <%= if @creator_input not in [nil, ""] and @creator_suggestions != [] and (@form[:creator_id].value == nil or @form[:creator_id].value == "") do %>
              <div class="absolute z-10 w-full mt-1 bg-voile-surface border border-voile-muted rounded-md shadow-lg max-h-60 overflow-auto">
                <ul role="listbox" aria-label="Creator suggestions">
                  <%= for creator <- @creator_suggestions do %>
                    <li
                      role="option"
                      class="px-4 py-2 hover:bg-gray-400 cursor-pointer border-b border-voile-light last:border-b-0"
                      phx-click="select_creator"
                      phx-target={@myself}
                      phx-value-id={creator.id}
                    >
                      <div class="font-medium">{creator.creator_name}</div>

                      <div class="text-xs">{Map.get(creator, :affiliation, "")}</div>
                    </li>
                  <% end %>
                </ul>
              </div>
            <% end %>

            <%= if @creator_input not in [nil, ""] and @creator_suggestions == [] and (@form[:creator_id].value == nil or @form[:creator_id].value == "") do %>
              <div class="mt-2 flex items-center gap-3">
                <.button
                  type="button"
                  phx-click="create_new_creator"
                  phx-value-creator={@creator_input}
                  phx-target={@myself}
                  class="primary-btn"
                >
                  Create "{@creator_input}"
                </.button>
                <%= for {_msg, _opts} <- Keyword.get_values(@form.errors, :creator_id) do %>
                  <p class="text-red-500 text-sm mt-2">Please choose Creator or click Create!</p>
                <% end %>
              </div>
            <% end %>
          </div>

          <%= if @form[:creator_id].value not in [nil, ""] do %>
            <.button type="button" phx-click="delete_creator" phx-target={@myself} class="cancel-btn">
              Delete Author
            </.button>
          <% end %>

          <.input
            field={@form[:description]}
            type="textarea"
            label="Description"
            required_value={true}
          />
          <%= if is_super_admin?(@current_scope.user) do %>
            <.input
              field={@form[:status]}
              type="select"
              label="Status"
              options={get_status_options(@current_scope)}
              required_value={true}
            />
            <.input
              field={@form[:access_level]}
              type="select"
              label="Access Level"
              options={[
                {"Public", "public"},
                {"Private", "private"},
                {"Restricted", "restricted"}
              ]}
              required_value={true}
            />
          <% else %>
            <input type="hidden" name={@form[:status].name} value={@form[:status].value || "pending"} />
            <p class="text-sm text-gray-600 dark:text-gray-400 mb-4">
              <strong>Note:</strong>
              Click "Save Collection" to submit for review (pending), or "Save as Draft" to save without submitting.
            </p>
            <input type="hidden" name={@form[:access_level].name} value="private" />
            <.input
              field={@form[:access_level]}
              type="select"
              label="Access Level (Auto-set to Private)"
              options={[{"Private", "private"}]}
              required_value={true}
              disabled={true}
            />
          <% end %>
          <.input field={@form[:thumbnail]} type="text" label="Thumbnail" readonly />
          <input
            name={@form[:creator_id].name}
            value={@form[:creator_id].value || @current_scope.user.id}
            type="hidden"
            disabled
          />
          <input
            name={@form[:id].name}
            value={@form[:id].value || Ecto.UUID.generate()}
            type="hidden"
            disabled
          />
          <div class="p-6">
            <%= if @form[:thumbnail].value == nil or @form[:thumbnail].value == "" do %>
              <!-- Enhanced Tabs for thumbnail upload options -->
              <div class="mb-6">
                <nav
                  class="flex space-x-1 bg-gray-100 dark:bg-gray-800 p-1 rounded-lg"
                  aria-label="Thumbnail upload options"
                >
                  <button
                    type="button"
                    phx-click="switch_thumbnail_tab"
                    phx-value-tab="upload"
                    phx-target={@myself}
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
                    phx-click="switch_thumbnail_tab"
                    phx-value-tab="asset_vault"
                    phx-target={@myself}
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
                    phx-click="switch_thumbnail_tab"
                    phx-value-tab="url"
                    phx-target={@myself}
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
                    phx-drop-target={@uploads.thumbnail.ref}
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
                          Upload Thumbnail
                        </h3>
                        <p class="text-sm text-gray-600 dark:text-gray-400">
                          Drag and drop your image here, or click to browse
                        </p>
                        <p class="text-xs text-gray-500 dark:text-gray-500">
                          PNG, JPG, GIF up to 10MB
                        </p>
                      </div>

                      <div class="pt-4">
                        <.live_file_input upload={@uploads.thumbnail} />
                        <label
                          for={@uploads.thumbnail.ref}
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
                    <%= for attachment <- @asset_vault_files do %>
                      <%= if attachment.file_type in ["image"] do %>
                        <div
                          class="relative group cursor-pointer rounded-lg overflow-hidden shadow-sm hover:shadow-md transition-all duration-200 transform hover:-translate-y-1"
                          phx-click="select_thumbnail_from_vault"
                          phx-value-attachment_id={attachment.id}
                          phx-target={@myself}
                        >
                          <div class="aspect-square bg-gray-200 dark:bg-gray-700">
                            <img
                              src={Catalog.get_file_url(attachment)}
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
                    <% end %>
                  </div>

                  <%= if Enum.empty?(Enum.filter(@asset_vault_files, &(&1.file_type == "image"))) do %>
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
                          name="thumbnail_url"
                          value={@thumbnail_url_input}
                          placeholder="https://example.com/image.jpg"
                          phx-change="update_thumbnail_url"
                          phx-target={@myself}
                        />
                      </div>
                      <.button
                        type="button"
                        phx-click="add_thumbnail_from_url"
                        phx-value-url={@thumbnail_url_input}
                        phx-target={@myself}
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
                      <p>Supported formats: PNG, JPG, GIF, WebP</p>
                    </div>
                  </div>
                </div>
              <% end %>
            <% end %>

            <%= for entry <- @uploads.thumbnail.entries do %>
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
                      phx-click="cancel-upload"
                      phx-value-ref={entry.ref}
                      phx-target={@myself}
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

            <%= if @form[:thumbnail].value != nil and @form[:thumbnail].value != "" do %>
              <div class="bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded-xl p-6 shadow-sm">
                <div class="flex items-start space-x-6">
                  <div class="relative group flex-shrink-0">
                    <div class="w-24 h-24 bg-gray-100 dark:bg-gray-700 rounded-lg overflow-hidden">
                      <img
                        src={@form[:thumbnail].value}
                        alt="Collection thumbnail"
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
                          d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"
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
                        Thumbnail Ready
                      </span>
                    </div>

                    <p class="text-sm text-gray-600 dark:text-gray-400 mb-4">
                      Your collection thumbnail has been successfully uploaded and is ready to use.
                    </p>

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
                        phx-click="delete_thumbnail"
                        phx-value-thumbnail={@form[:thumbnail].value}
                        phx-target={@myself}
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
                  </div>
                </div>
              </div>
            <% end %>
          </div>
        <% end %>

        <%= if @step == 2 do %>
          <div class="flex items-start gap-5">
            <div class="sticky top-0 w-full h-full max-w-72">
              <h5>Collection Properties</h5>

              <div class="w-full h-full max-h-screen border border-1 border-voile-muted overflow-y-auto overflow-x-hidden rounded-xl mt-2 p-4">
                <p class="text-xs italic mb-4 max-w-48">
                  You can click each category below and pick any necessary property for your collection.
                </p>

                <div>
                  <.input
                    type="text"
                    name="property_search"
                    label="Search Property"
                    value={@property_search}
                    placeholder="Search property..."
                    phx-keyup="search_properties"
                    phx-target={@myself}
                    phx-debounce="300"
                  />
                </div>

                <%= if Enum.empty?(@filtered_properties) do %>
                  <p class="text-red-500 text-sm mt-2">No property found.</p>
                <% else %>
                  <%= for {id, props} <- @filtered_properties do %>
                    <div class="my-5">
                      <h6
                        class="mb-4 border border-1 border-voile-muted rounded-xl p-2 hover:text-voile-primary cursor-pointer transition-all duration-1000"
                        phx-click={
                          JS.toggle(
                            to: "##{id |> String.downcase() |> String.replace(" ", "-")}",
                            in: "block scale-y-100 transition transform duration-300 ease-out",
                            out: "hidden scale-y-0 transition transform duration-300 ease-in",
                            display: "block"
                          )
                        }
                      >
                        {id}
                        <%= if length(props) > 0 do %>
                          (<span class="text-brand">{length(props)}</span>)
                        <% end %>
                      </h6>

                      <div
                        id={id |> String.downcase() |> String.replace(" ", "-")}
                        class={
                          if @property_search != "",
                            do:
                              "block scale-y-100 origin-top overflow-hidden transition-transform duration-300",
                            else:
                              "hidden scale-y-0 origin-top overflow-hidden transition-transform duration-300"
                        }
                      >
                        <div class="flex flex-col gap-3">
                          <%= for prop <- props do %>
                            <button
                              type="button"
                              phx-click="select_props"
                              phx-value-id={prop.id}
                              phx-target={@myself}
                              class="btn hover-btn py-5 ml-3"
                            >
                              {prop.label}
                            </button>
                          <% end %>
                        </div>
                      </div>
                    </div>
                  <% end %>
                <% end %>
              </div>
            </div>

            <div class="w-full">
              <%= if @form[:collection_fields] == nil or Enum.empty?(@form[:collection_fields].value || []) do %>
                <p class="text-red-500 text-sm mt-2">No collection fields added yet.</p>
              <% else %>
                <div>
                  <.inputs_for :let={col_field} field={@form[:collection_fields]}>
                    <h6 class="bg-voile-primary px-4 py-1 rounded-t-xl text-white">
                      {col_field[:label].value}
                    </h6>

                    <div class="flex flex-col w-full bg-gray-100 dark:bg-gray-600 p-4 rounded-b-xl mb-4">
                      <p class="text-gray-500 dark:text-white italic pb-4">
                        <% mp = Map.get(col_field.data, :metadata_properties) %> {cond do
                          col_field[:information].value not in [nil, ""] ->
                            col_field[:information].value

                          mp && not match?(%Ecto.Association.NotLoaded{}, mp) ->
                            mp.information

                          true ->
                            ""
                        end}
                      </p>

                      <input
                        type="hidden"
                        name={col_field[:label].name}
                        value={col_field[:label].value}
                      />
                      <input
                        type="hidden"
                        name={col_field[:property_id].name}
                        value={col_field[:property_id].value}
                      />
                      <input
                        type="hidden"
                        name={col_field[:name].name}
                        value={col_field[:name].value}
                      />
                      <input
                        type="hidden"
                        name={col_field[:information].name}
                        value={col_field[:information].value}
                      />
                      <input
                        type="hidden"
                        name={col_field[:sort_order].name}
                        value={col_field[:sort_order].value || col_field.index + 1}
                      />
                      <input
                        type="hidden"
                        name={col_field[:type_value].name}
                        value={col_field[:type_value].value}
                      />
                      <div class="grid grid-cols-5 items-start gap-2">
                        <.input
                          field={col_field[:value_lang]}
                          type="select"
                          label="Language"
                          options={[
                            {"Indonesia", "id"},
                            {"English", "en"}
                          ]}
                        />
                        <div class="col-span-4">
                          <.input
                            field={col_field[:value]}
                            type={col_field[:type_value].value}
                            label="Value"
                          />
                        </div>
                      </div>

                      <div class="w-full flex items-center gap-3 mt-2">
                        <%= if col_field[:id].value != nil do %>
                          <.button
                            type="button"
                            phx-click={
                              JS.push("delete_field_confirmation")
                              |> show_modal("col_field_delete_confirmation")
                            }
                            phx-target={@myself}
                            phx-value-id={col_field[:id].value}
                            class="cancel-btn w-full"
                          >
                            <.icon name="hero-trash-solid" class="w-4 h-4" /> Delete Property
                          </.button>
                        <% else %>
                          <.button
                            type="button"
                            phx-click="delete_unsaved_field"
                            phx-target={@myself}
                            phx-value-index={col_field.index}
                            class="warning-btn w-full"
                          >
                            <.icon name="hero-x-circle-solid" class="w-4 h-4" /> Remove Field
                          </.button>
                        <% end %>
                      </div>
                    </div>
                  </.inputs_for>
                </div>
              <% end %>
            </div>
          </div>
        <% end %>

        <%= if @step == 3 do %>
          <div class="flex items-center justify-between mb-5">
            <h5>The Items Data</h5>

            <div class="flex items-center gap-5">
              <.button
                type="button"
                phx-click="add_item_data"
                phx-target={@myself}
                class="primary-btn"
              >
                <.icon name="hero-plus-circle-solid" class="w-4 h-4" /> Add Item Data
              </.button>
            </div>
          </div>

          <div class="">
            <%= if @form[:items] == nil or Enum.empty?(@form[:items].value || []) do %>
              <p class="text-red-500 text-sm mt-2">
                No items is added yet. Create at least 1 item for each collection.
              </p>
            <% else %>
              <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-5 my-10">
                <.inputs_for :let={item_field} field={@form[:items]}>
                  <div class="bg-gray-200 dark:bg-gray-600 rounded-lg p-5">
                    <div class="w-full flex items-center gap-3 mt-2">
                      <%= if item_field[:id].value != nil do %>
                        <.button
                          type="button"
                          phx-click={
                            JS.push("delete_item_confirmation")
                            |> show_modal("item_delete_confirmation")
                          }
                          phx-target={@myself}
                          phx-value-id={item_field[:id].value}
                          class="cancel-btn w-full"
                        >
                          <.icon name="hero-trash-solid" class="w-4 h-4" /> Delete Item
                        </.button>
                      <% else %>
                        <.button
                          type="button"
                          phx-click="delete_unsaved_item"
                          phx-target={@myself}
                          phx-value-index={item_field.index}
                          class="warning-btn w-full"
                        >
                          <.icon name="hero-x-circle-solid" class="w-4 h-4" /> Remove Item
                        </.button>
                      <% end %>
                    </div>

                    <.input
                      field={item_field[:item_code]}
                      type="text"
                      label="Item Code"
                      required_value={true}
                    />
                    <.input
                      field={item_field[:inventory_code]}
                      type="text"
                      label="Inventory Code"
                      required_value={true}
                    />
                    <input
                      type="hidden"
                      name={item_field[:barcode].name}
                      value={item_field[:barcode].value}
                    />
                    <.input
                      field={item_field[:barcode]}
                      type="text"
                      label="Barcode"
                      required_value={true}
                      disabled
                    />
                    <.input
                      field={item_field[:legacy_item_code]}
                      type="text"
                      label="Legacy Item Code"
                    />
                    <.input
                      field={item_field[:location]}
                      type="text"
                      label="Location"
                      required_value={true}
                    />
                    <input
                      type="hidden"
                      name={item_field[:unit_id].name}
                      value={item_field[:unit_id].value}
                    />
                    <.input
                      field={item_field[:unit_id]}
                      type="select"
                      label="Unit Location"
                      required_value={true}
                      options={Enum.map(@node_list, fn node -> {node.name, node.id} end)}
                      disabled={true}
                    />
                    <.input
                      field={item_field[:status]}
                      type="select"
                      label="Status"
                      required_value={true}
                      options={[
                        {"Active", "active"},
                        {"Inactive", "inactive"},
                        {"Lost", "lost"},
                        {"Damaged", "damaged"},
                        {"Discarded", "discarded"}
                      ]}
                    />
                    <.input
                      field={item_field[:condition]}
                      type="select"
                      label="Condition"
                      required_value={true}
                      options={[
                        {"Excellent", "excellent"},
                        {"Good", "good"},
                        {"Fair", "fair"},
                        {"Poor", "poor"},
                        {"Damaged", "damaged"}
                      ]}
                    />
                    <.input
                      field={item_field[:availability]}
                      type="select"
                      label="Availability"
                      required_value={true}
                      options={Item.availability_options()}
                    />
                  </div>
                </.inputs_for>
              </div>
            <% end %>
          </div>
        <% end %>

        <div class="mt-12 w-full flex justify-between items-center gap-5">
          <%= if @step > 1 do %>
            <.button
              type="button"
              phx-click="prev_step"
              phx-target={@myself}
              class="primary-btn w-full"
            >
              &leftarrow; Back
            </.button>
          <% end %>

          <%= if @step == 3 do %>
            <.button
              type="button"
              phx-click="save_as_draft"
              phx-target={@myself}
              phx-disable-with="Saving as draft..."
              class="warning-btn w-full"
            >
              <.icon name="hero-document-text-solid" class="w-4 h-4" /> Save as Draft
            </.button>
            <.button type="submit" phx-disable-with="Saving..." class="success-btn w-full">
              <.icon name="hero-check-circle-solid" class="w-4 h-4" /> Save
            </.button>
          <% else %>
            <.button
              type="button"
              phx-click="save_as_draft"
              phx-target={@myself}
              phx-disable-with="Saving as draft..."
              class="warning-btn w-full"
            >
              <.icon name="hero-document-text-solid" class="w-4 h-4" /> Save as Draft
            </.button>
            <.button
              type="button"
              phx-click="next_step"
              phx-target={@myself}
              class="primary-btn w-full"
            >
              Next &rightarrow;
            </.button>
          <% end %>
        </div>
      </.form>
    </div>
    """
  end

  @impl true
  def update(%{collection: collection} = assigns, socket) do
    type_options =
      assigns.collection_type
      |> Enum.map(fn type -> {type.label, type.id} end)

    # Don't load all potential parents on mount to avoid performance issues
    # Instead, we'll load them on search

    {original_collection, _changeset} =
      case assigns.action do
        :edit ->
          # Fetch fresh collection with preloads
          coll =
            Catalog.get_collection!(collection.id)
            |> Voile.Repo.preload([:mst_creator, collection_fields: [:metadata_properties]])

          {coll, Catalog.change_collection(coll)}

        :new ->
          coll =
            collection
            |> Catalog.change_collection(%{})

          {nil, coll}
      end

    seed_source = if assigns.action == :edit, do: original_collection, else: collection

    # Initialize creator_input based on existing data
    initial_creator_input =
      case assigns.action do
        :edit when not is_nil(original_collection.mst_creator) ->
          original_collection.mst_creator.creator_name

        _ ->
          nil
      end

    seed_params =
      (seed_source.collection_fields || [])
      |> Enum.with_index()
      |> Enum.into(%{}, fn {field, idx} ->
        {to_string(idx),
         %{
           "id" => field.id,
           "label" => field.label,
           "information" =>
             case Map.get(field, :metadata_properties) do
               %Ecto.Association.NotLoaded{} -> ""
               nil -> ""
               mp -> mp.information
             end,
           "type_value" => field.type_value,
           "value_lang" => field.value_lang,
           "value" => field.value,
           "sort_order" => field.sort_order
         }}
      end)

    item_params =
      (seed_source.items || [])
      |> Enum.with_index()
      |> Enum.into(%{}, fn {item, idx} ->
        {to_string(idx),
         %{
           "id" => item.id,
           "item_code" => item.item_code,
           "inventory_code" => item.inventory_code,
           "location" => item.location,
           "unit_id" => item.unit_id,
           "status" => item.status,
           "condition" => item.condition,
           "availability" => item.availability,
           "legacy_item_code" => item.legacy_item_code
         }}
      end)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:original_collection, original_collection)
     |> assign(:parent_search, "")
     |> assign(:parent_search_results, [])
     |> assign(:selected_parent_title, get_selected_parent_title(collection))
     |> assign(:creator_input, initial_creator_input)
     |> assign(:creator_list, assigns.creator_list)
     |> assign(:creator_suggestions, [])
     |> assign(:creator_searching, false)
     |> assign(:step2_params, nil)
     |> assign(:step3_params, nil)
     |> assign(:type_options, type_options)
     |> assign(:uploaded_files, [])
     |> assign(:delete_field_confirmation_id, nil)
     |> assign(:delete_item_confirmation_id, nil)
     |> assign(:chosen_collection_field, nil)
     |> assign(:chosen_item_field, nil)
     |> assign(:property_search, "")
     |> assign(:filtered_properties, assigns.collection_properties)
     |> assign(:tab, "upload")
     |> assign(:thumbnail_source, nil)
     |> assign(:thumbnail_attachment_id, nil)
     |> assign(:thumbnail_url_input, "")
     |> assign(:asset_vault_files, Catalog.list_all_attachments())
     |> allow_upload(:thumbnail,
       accept: ~w(.jpg .jpeg .png .webp),
       max_entries: 1,
       auto_upload: true,
       progress: &handle_progress/3
     )
     |> assign_new(:form, fn ->
       # Build form with all initial params
       # For new collections by non-super_admin, force their unit_id
       unit_id =
         case assigns.action do
           :new ->
             get_allowed_unit_id(assigns.current_scope, collection)

           :edit ->
             collection.unit_id
         end

       # RBAC: Default status - pending for librarians (submit for review), super_admin can choose
       default_status =
         if is_super_admin?(assigns.current_scope.user) do
           collection.status || "draft"
         else
           # For librarians, default to pending (will be set to draft if they click "Save as Draft")
           collection.status || "pending"
         end

       default_access_level =
         if is_super_admin?(assigns.current_scope.user) do
           collection.access_level || "public"
         else
           "private"
         end

       initial_params =
         Map.merge(
           %{"collection_fields" => seed_params, "items" => item_params},
           %{
             "id" => collection.id || Ecto.UUID.generate(),
             "title" => collection.title || "",
             "description" => collection.description || "",
             "status" => default_status,
             "access_level" => default_access_level,
             "type_id" => collection.type_id || nil,
             "unit_id" => unit_id,
             "creator_id" => collection.creator_id || nil,
             "thumbnail" => collection.thumbnail || "",
             "thumbnail_source" => nil,
             "thumbnail_attachment_id" => nil,
             "parent_id" => collection.parent_id || nil,
             "collection_type" => collection.collection_type || nil,
             "sort_order" => collection.sort_order || 1
           }
         )

       to_form(Catalog.change_collection(collection, initial_params))
     end)}
  end

  @impl true
  def handle_event(
        "validate",
        %{"collection" => collection_params, "creator" => creator_input},
        socket
      ) do
    # Keep validate focused on form validation only; suggestions are fetched via `search_creator`
    suggestions = socket.assigns.creator_suggestions || []

    current_params = socket.assigns.form.params || %{}
    updated_params = Map.merge(current_params, collection_params)

    # RBAC: Force unit_id for non-super_admin users
    updated_params =
      if can_select_unit?(socket.assigns.current_scope) do
        updated_params
      else
        Map.put(updated_params, "unit_id", socket.assigns.current_scope.user.node_id)
      end

    # RBAC: Force status and access_level for non-super admin users
    updated_params =
      if is_super_admin?(socket.assigns.current_scope.user) do
        updated_params
      else
        updated_params
        |> Map.put("status", "draft")
        |> Map.put("access_level", "private")
      end

    changeset =
      Catalog.change_collection(socket.assigns.collection, updated_params)

    socket =
      socket
      |> assign(:creator_input, creator_input)
      |> assign(:creator_suggestions, suggestions)
      |> assign(:form, to_form(changeset, action: :validate))

    {:noreply, socket}
  end

  def handle_event("validate", %{"collection" => collection_params}, socket) do
    current_params = socket.assigns.form.params || %{}
    updated_params = Map.merge(current_params, collection_params)

    # RBAC: Force unit_id for non-super_admin users
    updated_params =
      if can_select_unit?(socket.assigns.current_scope) do
        updated_params
      else
        Map.put(updated_params, "unit_id", socket.assigns.current_scope.user.node_id)
      end

    # RBAC: Force access_level for non-super admin users, but allow draft/pending status
    updated_params =
      if is_super_admin?(socket.assigns.current_scope.user) do
        updated_params
      else
        updated_params
        |> Map.put("access_level", "private")
      end

    changeset =
      Catalog.change_collection(socket.assigns.collection, updated_params)

    # Preserve creator_input if creator_id is set (creator was already selected)
    # We rely on creator_input since mst_creator is not always loaded
    creator_input =
      if updated_params["creator_id"] && updated_params["creator_id"] != "" &&
           socket.assigns.creator_input do
        socket.assigns.creator_input
      else
        socket.assigns.creator_input
      end

    socket =
      socket
      |> assign(:creator_input, creator_input)
      |> assign(:form, to_form(changeset, action: :validate))

    {:noreply, socket}
  end

  def handle_event("validate", %{"property_search" => _value}, socket) do
    # Update assigns or do something with `value`
    {:noreply, socket}
  end

  def handle_event("search_creator", %{"value" => query}, socket) do
    # Don't search if a creator has already been selected
    creator_id = socket.assigns.form[:creator_id].value

    if creator_id not in [nil, ""] do
      {:noreply, socket}
    else
      # Mark searching true so UI can show a loading indicator
      socket = assign(socket, :creator_searching, true)

      suggestions =
        try do
          Voile.Schema.Master.search_mst_creator_names(query, 10)
        rescue
          _ ->
            # Fallback to in-memory filtering
            Enum.filter(socket.assigns.creator_list || [], fn creator ->
              String.contains?(String.downcase(creator.creator_name), String.downcase(query))
            end)
        end

      socket =
        socket
        |> assign(:creator_searching, false)
        |> assign(:creator_input, query)
        |> assign(:creator_suggestions, suggestions)

      {:noreply, socket}
    end
  end

  # Accept `creator` param name (from phx-change on input) and forward to the same logic
  def handle_event("search_creator", %{"creator" => query}, socket) do
    handle_event("search_creator", %{"value" => query}, socket)
  end

  def handle_event("select_creator", %{"id" => id}, socket) do
    {:noreply, assign_selected_creator(id, socket)}
  end

  def handle_event("create_new_creator", %{"creator" => creator}, socket) do
    case create_or_select_creator(creator, socket) do
      {:ok, socket} -> {:noreply, socket}
      {:error, socket} -> {:noreply, socket}
    end
  end

  def handle_event("delete_creator", _params, socket) do
    {:noreply, clear_selected_creator(socket)}
  end

  def handle_event("next_step", _params, socket) do
    current_params = socket.assigns.form.params

    changeset =
      socket.assigns.collection
      |> Catalog.change_collection(current_params)
      |> Map.put(:action, :validate)

    if changeset.valid? do
      collection = Changeset.apply_changes(changeset)

      socket =
        socket
        |> assign(:step, socket.assigns.step + 1)
        |> assign(:collection, collection)
        |> assign(:changeset, changeset)
        |> assign(:form, to_form(changeset))

      {:noreply, socket}
    else
      socket =
        socket
        |> put_flash(:error, "Please fill in all required fields.")
        |> assign(:form, to_form(changeset, action: :validate))

      {:noreply, socket}
    end
  end

  def handle_event("prev_step", _params, socket) do
    socket =
      socket
      |> assign(:step, socket.assigns.step - 1)

    {:noreply, socket}
  end

  def handle_event("select_props", %{"id" => prop_id}, socket) do
    {:noreply, add_property_to_form(prop_id, socket)}
  end

  def handle_event("add_item_data", _params, socket) do
    {:noreply, add_item_to_form(socket)}
  end

  def handle_event("delete_unsaved_field", %{"index" => idx_str}, socket) do
    {:noreply, delete_unsaved_field_at(idx_str, socket)}
  end

  def handle_event("delete_existed_field", %{"id" => id}, socket) do
    {:noreply, delete_existing_field(id, socket)}
  end

  def handle_event("delete_unsaved_item", %{"index" => idx_str}, socket) do
    {:noreply, delete_unsaved_item_at(idx_str, socket)}
  end

  def handle_event("delete_existing_item", %{"id" => id}, socket) do
    {:noreply, delete_existing_item(id, socket)}
  end

  def handle_event("delete_field_confirmation", %{"id" => id}, socket) do
    {:noreply, confirm_field_deletion(id, socket)}
  end

  def handle_event("delete_item_confirmation", %{"id" => id}, socket) do
    {:noreply, confirm_item_deletion(id, socket)}
  end

  def handle_event("search_properties", %{"value" => query}, socket) do
    {:noreply, search_properties(query, socket)}
  end

  def handle_event("save", _params, socket) do
    collection_params = socket.assigns.form.params

    # RBAC: For librarians, save button submits for review (pending status)
    collection_params =
      if is_super_admin?(socket.assigns.current_scope.user) do
        collection_params
      else
        collection_params
        |> Map.put("status", "pending")
        |> Map.put("access_level", "private")
      end

    cond do
      # Check if collection fields are empty
      is_nil(collection_params["collection_fields"]) ||
        collection_params["collection_fields"] == %{} ||
          Enum.empty?(collection_params["collection_fields"]) ->
        {:noreply,
         socket
         |> clear_flash(:error)
         |> assign(:step, 2)
         |> put_flash(:error, "Please add at least one collection property.")
         |> assign(:form, to_form(socket.assigns.form, action: :validate))}

      # Check if items are empty
      is_nil(collection_params["items"]) ||
        collection_params["items"] == %{} ||
          Enum.empty?(collection_params["items"]) ->
        {:noreply,
         socket
         |> clear_flash(:error)
         |> assign(:step, 3)
         |> put_flash(:error, "Please add at least one item to the collection.")
         |> assign(:form, to_form(socket.assigns.form, action: :validate))}

      # Proceed with save if all checks pass
      true ->
        save_collection(socket, socket.assigns.action, collection_params)
    end
  end

  def handle_event("save_as_draft", _params, socket) do
    collection_params = socket.assigns.form.params

    # RBAC: Force status to draft and access_level to private for non-super admin users
    collection_params =
      if is_super_admin?(socket.assigns.current_scope.user) do
        Map.put(collection_params, "status", "draft")
      else
        collection_params
        |> Map.put("status", "draft")
        |> Map.put("access_level", "private")
      end

    save_collection_as_draft(socket, socket.assigns.action, collection_params)
  end

  def handle_event("delete_thumbnail", %{"thumbnail" => thumbnail_path}, socket) do
    handle_delete_thumbnail(%{"thumbnail" => thumbnail_path}, socket)
  end

  def handle_event("switch_thumbnail_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :tab, tab)}
  end

  def handle_event("add_thumbnail_from_url", %{"url" => url}, socket) do
    handle_add_thumbnail_from_url(url, socket)
  end

  def handle_event("update_thumbnail_url", %{"thumbnail_url" => url}, socket) do
    {:noreply, assign(socket, :thumbnail_url_input, url)}
  end

  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :thumbnail, ref)}
  end

  def handle_event("select_thumbnail_from_vault", %{"attachment_id" => attachment_id}, socket) do
    attachment = Catalog.get_attachment!(attachment_id)

    form_params =
      (socket.assigns.form.params || %{})
      |> Map.put("thumbnail", attachment.file_path)
      |> Map.put("thumbnail_source", "vault")
      |> Map.put("thumbnail_attachment_id", attachment.id)

    socket =
      socket
      |> assign(:form, %{socket.assigns.form | params: form_params})
      |> assign(:collection, %{socket.assigns.collection | thumbnail: attachment.file_path})
      |> assign(:thumbnail_source, "vault")
      |> assign(:thumbnail_attachment_id, attachment.id)

    {:noreply, socket}
  end

  def handle_event("progress", %{"upload_config" => "thumbnail"}, socket) do
    case socket.assigns.uploads.thumbnail.entries do
      [entry] when entry.done? ->
        handle_thumbnail_progress(:thumbnail, entry, socket)

      _ ->
        {:noreply, socket}
    end
  end

  # Parent collection search events
  def handle_event("search_parent", %{"parent_search" => search_term}, socket) do
    results =
      if String.trim(search_term) != "" do
        collection_id = socket.assigns.collection.id
        Catalog.search_potential_parent_collections(search_term, collection_id, 10)
      else
        []
      end

    {:noreply,
     socket
     |> assign(:parent_search, search_term)
     |> assign(:parent_search_results, results)}
  end

  def handle_event("select_parent", %{"id" => parent_id, "title" => title}, socket) do
    current_params = socket.assigns.form.params || %{}
    updated_params = Map.put(current_params, "parent_id", parent_id)
    changeset = Catalog.change_collection(socket.assigns.collection, updated_params)

    {:noreply,
     socket
     |> assign(:form, to_form(changeset, action: :validate))
     |> assign(:parent_search, "")
     |> assign(:parent_search_results, [])
     |> assign(:selected_parent_title, title)}
  end

  def handle_event("clear_parent", _params, socket) do
    current_params = socket.assigns.form.params || %{}
    updated_params = Map.put(current_params, "parent_id", nil)
    changeset = Catalog.change_collection(socket.assigns.collection, updated_params)

    {:noreply,
     socket
     |> assign(:form, to_form(changeset, action: :validate))
     |> assign(:selected_parent_title, nil)}
  end

  defp handle_progress(:thumbnail, entry, socket) do
    handle_thumbnail_progress(:thumbnail, entry, socket)
  end

  defp get_selected_parent_title(collection) do
    case collection do
      %{parent_id: parent_id} when not is_nil(parent_id) ->
        try do
          parent = Catalog.get_collection!(parent_id)
          parent.title
        rescue
          _ -> nil
        end

      _ ->
        nil
    end
  end

  # RBAC: Get status options for super admin
  defp get_status_options(_current_scope) do
    [
      {"Draft", "draft"},
      {"Pending", "pending"},
      {"Published", "published"},
      {"Archived", "archived"}
    ]
  end

  # RBAC: Check if user can select any unit (only super_admin)
  defp can_select_unit?(current_scope) do
    is_super_admin?(current_scope.user)
  end

  # RBAC: Get the unit_id that should be used for the collection
  defp get_allowed_unit_id(current_scope, collection) do
    cond do
      # Super admin can use any unit (from collection or nil)
      can_select_unit?(current_scope) ->
        collection.unit_id

      # Other users must use their own unit_id (from node_id field)
      true ->
        current_scope.user.node_id
    end
  end
end
