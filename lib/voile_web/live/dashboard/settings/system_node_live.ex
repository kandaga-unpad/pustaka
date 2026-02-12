defmodule VoileWeb.Dashboard.Settings.SystemNodeLive do
  use VoileWeb, :live_view_dashboard

  alias Voile.Schema.System
  alias Voile.Schema.System.Node
  alias Client.Storage
  alias Phoenix.LiveView.JS

  def render(assigns) do
    ~H"""
    <.header>
      {gettext("System Nodes / Units Management")}
      <:subtitle>{gettext("Manage library branches, units, and organizational nodes")}</:subtitle>

      <:actions>
        <.button phx-click="new_node" class="primary-btn">
          <.icon name="hero-plus" class="w-4 h-4 mr-2" /> {gettext("Add Node")}
        </.button>
        <.button
          href={~p"/manage/settings/nodes/rules"}
          class="warning-btn"
        >
          <.icon name="hero-cog-6-tooth" class="w-4 h-4 mr-2" /> {gettext("Configure Rules")}
        </.button>
      </:actions>
    </.header>

    <section class="flex gap-4">
      <div class="w-full max-w-64">
        <.dashboard_settings_sidebar
          current_user={@current_scope.user}
          current_path={@current_path}
        />
      </div>

      <div class="space-y-6 flex-1">
        <!-- Node Stats -->
        <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
          <div class="bg-white dark:bg-gray-700 rounded-lg shadow p-6">
            <div class="flex items-center">
              <div class="flex-shrink-0">
                <.icon name="hero-building-library" class="h-8 w-8 text-voile-primary" />
              </div>

              <div class="ml-4">
                <div class="text-2xl font-bold">{length(@nodes)}</div>

                <div class="text-sm font-medium">{gettext("Total Nodes")}</div>
              </div>
            </div>
          </div>

          <div class="bg-white dark:bg-gray-700 rounded-lg shadow p-6">
            <div class="flex items-center">
              <div class="flex-shrink-0">
                <.icon name="hero-photo" class="h-8 w-8 text-voile-success" />
              </div>

              <div class="ml-4">
                <div class="text-2xl font-bold">{Enum.count(@nodes, &(&1.image != nil))}</div>

                <div class="text-sm font-medium">{gettext("With Images")}</div>
              </div>
            </div>
          </div>

          <div class="bg-white dark:bg-gray-700 rounded-lg shadow p-6">
            <div class="flex items-center">
              <div class="flex-shrink-0">
                <.icon name="hero-check-circle" class="h-8 w-8 text-voile-info" />
              </div>

              <div class="ml-4">
                <div class="text-2xl font-bold">{Enum.count(@nodes, &(&1.abbr != nil))}</div>

                <div class="text-sm font-medium">{gettext("With Abbreviations")}</div>
              </div>
            </div>
          </div>
        </div>
        <!-- Info Panel -->
        <div class="bg-voile-info/10 dark:bg-voile-info/20 border border-voile-info/30 rounded-lg p-4">
          <div class="flex">
            <.icon name="hero-information-circle" class="h-5 w-5 text-voile-info" />
            <div class="ml-3">
              <h3 class="text-sm font-medium text-voile-info">{gettext("About System Nodes")}</h3>

              <p class="mt-2 text-sm text-voile-info">
                {gettext(
                  "Nodes represent organizational units such as library branches, departments, or locations. Each node can have its own logo, abbreviation, and description for better organization."
                )}
              </p>
            </div>
          </div>
        </div>
        <!-- Nodes Grid -->
        <div class="bg-white dark:bg-gray-700 shadow rounded-lg">
          <div class="px-4 py-5 border-b border-gray-200 dark:border-gray-600 sm:px-6">
            <h3 class="text-lg leading-6 font-medium">{gettext("Nodes List")}</h3>

            <div class="mt-1 text-sm">{gettext("Manage and organize your system nodes")}</div>
          </div>

          <div class="px-4 py-5 sm:p-6">
            <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
              <%= for node <- @nodes do %>
                <div class="relative group bg-gray-50 dark:bg-gray-800 rounded-lg border border-gray-200 dark:border-gray-600 hover:border-voile-primary dark:hover:border-voile-primary transition-all duration-200 overflow-hidden">
                  <!-- Node Image -->
                  <div class="aspect-video bg-gradient-to-br from-voile-primary/10 to-voile-secondary/10 relative overflow-hidden">
                    <%= if node.image do %>
                      <img
                        src={node.image}
                        alt={node.name}
                        class="w-full h-full object-cover"
                      />
                    <% else %>
                      <div class="flex items-center justify-center h-full">
                        <.icon
                          name="hero-building-library"
                          class="h-20 w-20 text-gray-300 dark:text-gray-600"
                        />
                      </div>
                    <% end %>
                    <!-- Abbreviation Badge -->
                    <%= if node.abbr do %>
                      <div class="absolute top-2 right-2 bg-voile-primary text-white px-3 py-1 rounded-full text-xs font-bold">
                        {node.abbr}
                      </div>
                    <% end %>
                  </div>
                  <!-- Node Info -->
                  <div class="p-4">
                    <h4 class="text-lg font-semibold mb-2 line-clamp-1">{node.name}</h4>

                    <p class="text-sm text-gray-600 dark:text-gray-400 mb-4 line-clamp-2 min-h-[2.5rem]">
                      {node.description || gettext("No description provided")}
                    </p>
                    <!-- Actions -->
                    <%= if @current_scope.user && VoileWeb.Auth.Authorization.is_super_admin?(@current_scope.user) do %>
                      <div class="flex items-center justify-between gap-2">
                        <div class="text-xs text-gray-500">{gettext("ID: %{id}", id: node.id)}</div>

                        <div class="flex gap-2">
                          <.button
                            phx-click="edit_node"
                            phx-value-id={node.id}
                            class="text-xs !px-3 !py-1.5 info-btn"
                          >
                            <.icon name="hero-pencil" class="w-3 h-3 mr-1" /> {gettext("Edit")}
                          </.button>
                          <.button
                            phx-click="delete_node"
                            phx-value-id={node.id}
                            data-confirm={
                              gettext(
                                "Are you sure you want to delete this node? This action cannot be undone."
                              )
                            }
                            class="text-xs !px-3 !py-1.5 danger-btn"
                          >
                            <.icon name="hero-trash" class="w-3 h-3 mr-1" /> {gettext("Delete")}
                          </.button>
                        </div>
                      </div>
                    <% end %>
                  </div>
                </div>
              <% end %>
              <!-- Empty State -->
              <%= if @nodes == [] do %>
                <div class="col-span-full flex flex-col items-center justify-center py-12 text-center">
                  <.icon
                    name="hero-building-library"
                    class="h-16 w-16 text-gray-300 dark:text-gray-600 mb-4"
                  />
                  <h3 class="text-lg font-medium mb-2">{gettext("No nodes yet")}</h3>

                  <p class="text-sm text-gray-500 mb-4">
                    {gettext("Get started by creating your first system node")}
                  </p>

                  <.button phx-click="new_node" class="primary-btn">
                    <.icon name="hero-plus" class="w-4 h-4 mr-2" /> {gettext("Add First Node")}
                  </.button>
                </div>
              <% end %>
            </div>
          </div>
        </div>
      </div>
    </section>
    <!-- Node Form Modal -->
    <%= if @show_form do %>
      <.modal id="node-form-modal" show={@show_form} on_cancel={JS.push("cancel_form")}>
        <div class="mt-3">
          <h3 class="text-lg font-medium mb-4">
            {if @form_node, do: gettext("Edit Node"), else: gettext("Add New Node")}
          </h3>

          <.form for={@form} id="node-form" phx-submit="save_node" phx-change="validate_node">
            <.input field={@form[:name]} type="text" label={gettext("Node Name")} required />
            <.input
              field={@form[:abbr]}
              type="text"
              label={gettext("Abbreviation")}
              placeholder={gettext("e.g., MAIN, BR1")}
              required
            />
            <.input
              field={@form[:description]}
              type="textarea"
              label={gettext("Description")}
              rows="3"
            />
            <!-- Image Upload Section -->
            <div class="mt-4">
              <label class="block text-sm font-medium mb-2">{gettext("Node Image/Logo")}</label>
              <!-- Current Image Preview -->
              <%= if @image_preview || (@form_node && @form_node.image) do %>
                <div class="mb-3 relative inline-block">
                  <img
                    src={@image_preview || @form_node.image}
                    alt={gettext("Node preview")}
                    class="h-32 w-auto rounded-lg border-2 border-gray-300 dark:border-gray-600 object-cover"
                  />
                  <button
                    type="button"
                    phx-click="remove_image"
                    class="absolute -top-2 -right-2 bg-red-500 text-white rounded-full p-1 hover:bg-red-600 transition-colors"
                  >
                    <.icon name="hero-x-mark" class="w-4 h-4" />
                  </button>
                </div>
              <% end %>
              <!-- Upload Area -->
              <div class="mt-2">
                <div
                  class="border-2 border-dashed border-gray-300 dark:border-gray-600 rounded-lg p-6 text-center hover:border-voile-primary dark:hover:border-voile-primary transition-colors cursor-pointer"
                  phx-drop-target={@uploads.node_image.ref}
                >
                  <.live_file_input upload={@uploads.node_image} class="hidden" />
                  <label
                    for={@uploads.node_image.ref}
                    class="cursor-pointer flex flex-col items-center"
                  >
                    <.icon name="hero-photo" class="h-12 w-12 text-gray-400 mb-2" />
                    <span class="text-sm font-medium">
                      {gettext("Click to upload or drag and drop")}
                    </span>
                    <span class="text-xs text-gray-500 mt-1">
                      {gettext("PNG, JPG, WEBP up to 5MB")}
                    </span>
                  </label>
                </div>
                <!-- Upload Progress -->
                <%= for entry <- @uploads.node_image.entries do %>
                  <div class="mt-2 bg-gray-50 dark:bg-gray-800 rounded-lg p-3">
                    <div class="flex items-center justify-between mb-1">
                      <span class="text-sm font-medium truncate flex-1">{entry.client_name}</span>
                      <button
                        type="button"
                        phx-click="cancel_upload"
                        phx-value-ref={entry.ref}
                        class="text-red-500 hover:text-red-700"
                      >
                        <.icon name="hero-x-mark" class="w-4 h-4" />
                      </button>
                    </div>

                    <div class="w-full bg-gray-200 rounded-full h-2">
                      <div
                        class="bg-voile-primary h-2 rounded-full transition-all duration-300"
                        style={"width: #{entry.progress}%"}
                      >
                      </div>
                    </div>
                    <!-- Upload Errors -->
                    <%= for err <- upload_errors(@uploads.node_image, entry) do %>
                      <p class="text-xs text-red-500 mt-1">{error_to_string(err)}</p>
                    <% end %>
                  </div>
                <% end %>
                <!-- General Upload Errors -->
                <%= for err <- upload_errors(@uploads.node_image) do %>
                  <p class="text-xs text-red-500 mt-2">{error_to_string(err)}</p>
                <% end %>
              </div>
            </div>
            <!-- Hidden field for image URL -->
            <input
              type="hidden"
              name="node[image]"
              value={@image_preview || (@form_node && @form_node.image) || ""}
            />
            <div class="flex items-center justify-end space-x-2 mt-6">
              <.button
                type="button"
                phx-click="cancel_form"
                class="cancel-btn"
              >
                {gettext("Cancel")}
              </.button>
              <.button type="submit" class="success-btn">
                {if @form_node, do: gettext("Update"), else: gettext("Create")} Node
              </.button>
            </div>
          </.form>
        </div>
      </.modal>
    <% end %>
    """
  end

  def mount(_params, _session, socket) do
    handle_mount_errors do
      # Check permission for managing system settings
      authorize!(socket, "system.settings")

      nodes = System.list_nodes()

      socket =
        socket
        |> assign(:nodes, nodes)
        |> assign(:show_form, false)
        |> assign(:form_node, nil)
        |> assign(:image_preview, nil)
        |> assign(:current_path, "/manage/settings/nodes")
        |> assign(:form, to_form(System.change_node(%Node{})))
        |> allow_upload(:node_image,
          accept: ~w(.jpg .jpeg .png .webp),
          max_entries: 1,
          max_file_size: 5_000_000,
          auto_upload: true,
          progress: &handle_progress/3
        )

      {:ok, socket}
    end
  end

  def handle_event("new_node", _params, socket) do
    changeset = System.change_node(%Node{})

    {:noreply,
     socket
     |> assign(:show_form, true)
     |> assign(:form_node, nil)
     |> assign(:image_preview, nil)
     |> assign(:form, to_form(changeset))}
  end

  def handle_event("edit_node", %{"id" => id}, socket) do
    node = System.get_node!(id)
    changeset = System.change_node(node)

    {:noreply,
     socket
     |> assign(:show_form, true)
     |> assign(:form_node, node)
     |> assign(:image_preview, nil)
     |> assign(:form, to_form(changeset))}
  end

  def handle_event("validate_node", %{"node" => node_params}, socket) do
    changeset =
      case socket.assigns.form_node do
        nil -> System.change_node(%Node{}, node_params)
        node -> System.change_node(node, node_params)
      end
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(changeset))}
  end

  def handle_event("save_node", %{"node" => node_params}, socket) do
    # Use the image_preview if available, otherwise keep existing or empty
    node_params =
      if socket.assigns.image_preview do
        Map.put(node_params, "image", socket.assigns.image_preview)
      else
        node_params
      end

    case socket.assigns.form_node do
      nil ->
        case System.create_node(node_params) do
          {:ok, _node} ->
            {:noreply,
             socket
             |> put_flash(:info, gettext("Node created successfully"))
             |> assign(:show_form, false)
             |> assign(:image_preview, nil)
             |> assign(:nodes, System.list_nodes())}

          {:error, changeset} ->
            {:noreply, assign(socket, :form, to_form(changeset))}
        end

      node ->
        case System.update_node(node, node_params) do
          {:ok, _node} ->
            {:noreply,
             socket
             |> put_flash(:info, gettext("Node updated successfully"))
             |> assign(:show_form, false)
             |> assign(:image_preview, nil)
             |> assign(:nodes, System.list_nodes())}

          {:error, changeset} ->
            {:noreply, assign(socket, :form, to_form(changeset))}
        end
    end
  end

  def handle_event("cancel_form", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_form, false)
     |> assign(:image_preview, nil)}
  end

  def handle_event("delete_node", %{"id" => id}, socket) do
    node = System.get_node!(id)

    # Delete the image from storage if it exists
    if node.image do
      Storage.delete(node.image)
    end

    case System.delete_node(node) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Node deleted successfully"))
         |> assign(:nodes, System.list_nodes())}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, gettext("Failed to delete node"))}
    end
  end

  def handle_event("remove_image", _params, socket) do
    # If editing existing node with image, delete from storage
    if socket.assigns.form_node && socket.assigns.form_node.image do
      Storage.delete(socket.assigns.form_node.image)
    end

    {:noreply, assign(socket, :image_preview, nil)}
  end

  def handle_event("cancel_upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :node_image, ref)}
  end

  defp handle_progress(:node_image, _entry, socket) do
    uploaded_files =
      try do
        consume_uploaded_entries(socket, :node_image, fn %{path: path}, entry ->
          upload = %Plug.Upload{
            path: path,
            filename: entry.client_name,
            content_type: entry.client_type
          }

          case Storage.upload(upload, folder: "node_images") do
            {:ok, url} ->
              {:ok, url}

            url when is_binary(url) ->
              {:ok, url}

            _ ->
              {:ok, nil}
          end
        end)
      rescue
        _e in ArgumentError ->
          []
      end

    preview =
      uploaded_files
      |> List.wrap()
      |> Enum.find_value(nil, fn
        {:ok, url} when is_binary(url) -> url
        {:ok, _} -> nil
        url when is_binary(url) -> url
        _ -> nil
      end)

    socket =
      if preview do
        assign(socket, :image_preview, preview)
      else
        socket
      end

    {:noreply, socket}
  end

  defp error_to_string(:too_large), do: gettext("File is too large (max 5MB)")

  defp error_to_string(:not_accepted),
    do: gettext("File type not accepted (use JPG, PNG, or WEBP)")

  defp error_to_string(:too_many_files), do: gettext("Too many files (max 1)")
  defp error_to_string(_), do: gettext("Upload error occurred")
end
