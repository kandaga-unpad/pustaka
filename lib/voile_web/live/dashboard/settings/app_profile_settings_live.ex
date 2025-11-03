defmodule VoileWeb.Dashboard.Settings.AppProfileSettingsLive do
  use VoileWeb, :live_view_dashboard

  require Logger

  alias Voile.Schema.System
  alias Client.Storage

  @impl true
  def mount(_params, _session, socket) do
    handle_mount_errors do
      unless VoileWeb.Auth.Authorization.is_super_admin?(socket) do
        user_id =
          case socket.assigns[:current_scope] do
            %{user: %{id: id}} -> id
            _ -> nil
          end

        raise VoileWeb.Auth.Authorization.UnauthorizedError,
          permission: "system.settings",
          user_id: user_id
      end

      current_user = socket.assigns.current_scope.user

      socket =
        socket
        |> assign(:current_user, current_user)
        |> assign(:app_logo_preview, System.get_setting_value("app_logo_url", nil))
        |> assign(:current_path, "/manage/settings/app_profile")
        |> allow_upload(:app_logo,
          accept: ~w(.jpg .jpeg .png .webp .svg),
          max_entries: 1,
          max_file_size: 10_000_000,
          auto_upload: true,
          progress: &handle_progress/3
        )

      {:ok, socket}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      <h4>App Profile Settings</h4>

      <:subtitle>Manage the application profile</:subtitle>
    </.header>

    <div class="flex gap-4">
      <div class="w-full max-w-64"><.dashboard_settings_sidebar current_user={@current_user} /></div>

      <div class="w-full bg-white dark:bg-gray-700 p-4 rounded-lg">
        <.form for={%{}} phx-submit="save" phx-change="validate">
          <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div class="md:col-span-2">
              <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                Application Logo
              </label>
              <div phx-drop-target={@uploads.app_logo.ref} class="flex items-center gap-4">
                <div class="flex-shrink-0">
                  <%= if @app_logo_preview do %>
                    <img
                      src={@app_logo_preview}
                      class="w-20 h-20 rounded object-cover border border-gray-200 dark:border-gray-600"
                      alt="App logo"
                    />
                  <% else %>
                    <div class="w-20 h-20 bg-gray-100 dark:bg-gray-600 rounded flex items-center justify-center text-sm text-gray-500 dark:text-gray-400 border border-gray-200 dark:border-gray-500">
                      No logo
                    </div>
                  <% end %>
                </div>

                <div class="flex-1 min-w-0">
                  <div class="flex items-center gap-2 mb-2">
                    <.live_file_input upload={@uploads.app_logo} class="sr-only" />
                    <label
                      for={@uploads.app_logo.ref}
                      class="inline-flex items-center px-3 py-2 border border-gray-300 dark:border-gray-600 rounded text-sm font-medium text-gray-700 dark:text-gray-200 bg-white dark:bg-gray-800 hover:bg-gray-50 dark:hover:bg-gray-700 cursor-pointer transition-colors"
                    >
                      {if @app_logo_preview, do: "Change Logo", else: "Choose Logo"}
                    </label>
                    <%= if @app_logo_preview do %>
                      <button
                        type="button"
                        phx-click="delete_app_logo"
                        class="inline-flex items-center px-3 py-2 border border-red-300 dark:border-red-600 rounded text-sm font-medium text-red-700 dark:text-red-400 bg-white dark:bg-gray-800 hover:bg-red-50 dark:hover:bg-red-900/20 transition-colors"
                      >
                        Remove
                      </button>
                    <% end %>
                  </div>

                  <p class="text-xs text-gray-500 dark:text-gray-400 mb-2">
                    PNG, JPG, WebP or SVG. Max 10MB.
                  </p>

                  <div :for={entry <- @uploads.app_logo.entries} class="flex items-center gap-2 mt-2">
                    <.live_img_preview entry={entry} class="w-10 h-10 rounded object-cover border" />
                    <div class="flex-1 min-w-0">
                      <div class="text-sm text-gray-700 dark:text-gray-300 truncate">
                        {entry.client_name}
                      </div>

                      <div class="w-full bg-gray-200 dark:bg-gray-600 rounded-full h-1.5 mt-1">
                        <div
                          class="bg-blue-600 dark:bg-blue-500 h-1.5 rounded-full transition-all"
                          style={"width: #{entry.progress}%"}
                        >
                        </div>
                      </div>
                    </div>

                    <button
                      type="button"
                      phx-click="cancel-upload"
                      phx-value-ref={entry.ref}
                      class="text-sm text-gray-400 hover:text-red-600 dark:hover:text-red-400 transition-colors"
                    >
                      Cancel
                    </button>
                  </div>

                  <p
                    :for={err <- upload_errors(@uploads.app_logo)}
                    class="mt-2 text-sm text-red-600 dark:text-red-400"
                  >
                    {error_to_string(err)}
                  </p>
                </div>
              </div>
            </div>

            <div>
              <.input
                name="app_name"
                label="Application Name"
                value={System.get_setting_value("app_name", "")}
              />
            </div>

            <div>
              <.input
                name="app_contact_email"
                type="email"
                label="Contact Email"
                value={System.get_setting_value("app_contact_email", "")}
              />
            </div>

            <div class="md:col-span-2">
              <.input
                type="textarea"
                name="app_description"
                label="Description"
                rows="3"
                value={System.get_setting_value("app_description", "")}
              />
            </div>

            <div class="md:col-span-2">
              <.input
                name="app_home_title"
                label="Homepage Title"
                value={System.get_setting_value("app_home_title", "Voile, the Magic Library")}
                placeholder="Voile, the Magic Library"
              />
            </div>

            <div class="md:col-span-2">
              <.input
                type="textarea"
                name="app_home_description"
                label="Homepage Description"
                rows="4"
                value={
                  System.get_setting_value(
                    "app_home_description",
                    "Voile is your gateway to a world of cultural treasures. Imagine stepping into a digital sanctuary where libraries, museums, and archives converge into one intuitive space. Whether you're seeking your next great read, exploring rare artworks, or diving into historical archives, Voile offers a beautifully curated collection at your fingertips. Simply browse through diverse collections, uncover hidden gems, and let your curiosity lead you on a journey of discovery. With Voile, every click opens a door to inspiration and learning in an inviting, user-friendly environment."
                  )
                }
                placeholder="Describe your digital library's mission and purpose..."
              />
            </div>

            <div>
              <.input
                type="color"
                name="app_main_color"
                label="Main Color"
                value={System.get_setting_value("app_main_color", "#1d4ed8")}
              />
            </div>

            <div>
              <.input
                type="color"
                name="app_secondary_color"
                label="Secondary Color"
                value={System.get_setting_value("app_secondary_color", "#06b6d4")}
              />
            </div>

            <div class="md:col-span-2">
              <.input
                name="app_website"
                label="Website"
                value={System.get_setting_value("app_website", "")}
              />
            </div>

            <div>
              <.input
                type="select"
                name="storage_adapter"
                label="Storage Adapter"
                options={[{"Local Filesystem", "local"}, {"S3 Compatible", "s3"}]}
                value={System.get_setting_value("storage_adapter", "local")}
              />
            </div>

            <div class="md:col-span-2">
              <.input
                name="app_address"
                label="Address"
                value={System.get_setting_value("app_address", "")}
              />
            </div>
          </div>

          <div class="mt-6 flex items-center gap-3">
            <button type="submit" class="btn btn-primary">Save Settings</button>
            <span class="text-sm text-gray-500">
              Your changes will be applied to the application profile.
            </span>
          </div>
        </.form>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :app_logo, ref)}
  end

  @impl true
  def handle_event("save", params, socket) do
    keys = [
      "app_name",
      "app_description",
      "app_home_title",
      "app_home_description",
      "app_main_color",
      "app_secondary_color",
      "app_website",
      "app_contact_email",
      "app_address",
      "storage_adapter"
    ]

    results =
      Enum.map(keys, fn key ->
        value = Map.get(params, key, "")
        {key, System.upsert_setting(key, value)}
      end)

    failures =
      Enum.filter(results, fn
        {_k, {:error, _}} -> true
        _ -> false
      end)

    socket =
      if failures != [] do
        messages =
          Enum.map(failures, fn {key, {:error, changeset}} ->
            err = inspect(changeset.errors || changeset)
            "#{key}: #{err}"
          end)

        put_flash(socket, :error, "Failed to save: #{Enum.join(messages, "; ")}")
      else
        put_flash(socket, :info, "Application profile settings saved successfully")
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("delete_app_logo", _params, socket) do
    case System.get_setting_by_name("app_logo_url") do
      nil ->
        {:noreply, put_flash(socket, :error, "No app logo to delete")}

      %Voile.Schema.System.Setting{setting_value: url} = setting ->
        # Attempt to delete from storage
        case Storage.delete(url) do
          {:ok, _} -> :ok
          error -> Logger.warning("Storage delete error: #{inspect(error)}")
        end

        # Delete the setting
        case System.delete_setting(setting) do
          {:ok, _} ->
            {:noreply,
             socket
             |> assign(:app_logo_preview, nil)
             |> put_flash(:info, "Application logo removed")}

          {:error, error} ->
            Logger.error("Setting delete error: #{inspect(error)}")
            {:noreply, put_flash(socket, :error, "Failed to remove application logo")}
        end
    end
  end

  # Handle progress for auto-upload
  # This gets called when the upload completes
  def handle_progress(:app_logo, entry, socket) when entry.done? do
    Logger.debug("Upload completed for entry: #{inspect(entry.client_name)}")

    uploaded_files =
      consume_uploaded_entries(socket, :app_logo, fn meta, entry ->
        Logger.debug("Processing file: #{entry.client_name} at path: #{meta.path}")

        upload = %Plug.Upload{
          path: meta.path,
          filename: entry.client_name,
          content_type: entry.client_type
        }

        adapter =
          case System.get_setting_value("storage_adapter", "local") do
            "s3" -> Client.Storage.S3
            _ -> Client.Storage.Local
          end

        Logger.debug("Using storage adapter: #{inspect(adapter)}")

        case Storage.upload(upload, folder: "app_logo", adapter: adapter) do
          {:ok, url} when is_binary(url) ->
            Logger.info("Upload successful: #{url}")
            # Save to database immediately
            case System.upsert_setting("app_logo_url", url) do
              {:ok, _} ->
                Logger.info("Saved app_logo_url setting: #{url}")
                {:ok, url}

              {:error, error} ->
                Logger.error("Failed to save app_logo_url: #{inspect(error)}")
                {:error, :database_error}
            end

          url when is_binary(url) ->
            Logger.info("Upload returned URL: #{url}")

            case System.upsert_setting("app_logo_url", url) do
              {:ok, _} ->
                Logger.info("Saved app_logo_url setting: #{url}")
                {:ok, url}

              {:error, error} ->
                Logger.error("Failed to save app_logo_url: #{inspect(error)}")
                {:error, :database_error}
            end

          error ->
            Logger.error("Upload failed: #{inspect(error)}")
            {:error, :upload_failed}
        end
      end)

    Logger.debug("All uploaded files result: #{inspect(uploaded_files)}")

    socket =
      socket
      |> assign(:app_logo_preview, System.get_setting_value("app_logo_url", nil))
      |> put_flash(:info, "Logo uploaded successfully!")

    {:noreply, socket}
  end

  # Handle progress updates (not done yet)
  def handle_progress(:app_logo, _entry, socket) do
    {:noreply, socket}
  end

  # Helper to convert upload errors to human-readable strings
  defp error_to_string(:too_large), do: "File is too large (max 10MB)"
  defp error_to_string(:not_accepted), do: "File type not accepted (use PNG, JPG, WebP, or SVG)"
  defp error_to_string(:too_many_files), do: "Only one file allowed"
  defp error_to_string(:external_client_failure), do: "Upload failed. Please try again."
  defp error_to_string(error), do: "Upload error: #{inspect(error)}"
end
