defmodule VoileWeb.Dashboard.Settings.AppProfileSettingsLive do
  use VoileWeb, :live_view_dashboard

  alias Voile.Schema.System
  alias Client.Storage

  @impl true
  def mount(_params, _session, socket) do
    handle_mount_errors do
      # Only super_admin may access this LiveView. Non-super-admins will be
      # treated as unauthorized and handled by `handle_mount_errors`.
      unless VoileWeb.Auth.Authorization.is_super_admin?(socket) do
        # Raise the same UnauthorizedError so the mount wrapper converts it to a
        # friendly flash + redirect.
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
        <.form for={%{}} phx-submit="save">
          <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div class="md:col-span-2">
              <label class="block text-sm font-medium text-gray-700 mb-2">Application Logo</label>
              <div phx-drop-target={@uploads.app_logo.ref} class="flex items-center gap-4">
                <%= if @app_logo_preview do %>
                  <img src={@app_logo_preview} class="w-20 h-20 rounded object-cover" />
                <% else %>
                  <div class="w-20 h-20 bg-gray-100 rounded flex items-center justify-center text-sm text-gray-500">
                    No logo
                  </div>
                <% end %>

                <div>
                  <.live_file_input upload={@uploads.app_logo} class="hidden" />
                  <label
                    for={@uploads.app_logo.ref}
                    class="inline-flex items-center px-3 py-2 bg-white border rounded cursor-pointer"
                  >
                    Choose logo
                  </label>
                  <%= for entry <- @uploads.app_logo.entries do %>
                    <div class="mt-2 text-sm text-voile-muted">Uploading... {entry.progress}%</div>
                  <% end %>
                </div>

                <div>
                  <.button type="button" phx-click="delete_app_logo" phx-disable-with="Removing...">
                    Remove
                  </.button>
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
  def handle_event("save", params, socket) do
    # expected params: map of form fields
    keys = [
      "app_name",
      "app_description",
      "app_main_color",
      "app_secondary_color",
      "app_website",
      "app_contact_email",
      "app_address",
      "storage_adapter",
      "app_logo_url"
    ]

    # Persist each setting and collect results keyed by setting name
    results =
      Enum.map(keys, fn key ->
        value = Map.get(params, key, "")
        {key, System.upsert_setting(key, value)}
      end)

    # Find any failures
    failures =
      Enum.filter(results, fn
        {_k, {:error, _}} -> true
        _ -> false
      end)

    if failures != [] do
      # Build a helpful error message for debugging — include key and changeset errors
      messages =
        Enum.map(failures, fn {key, {:error, changeset}} ->
          err = inspect(changeset.errors || changeset)
          "#{key}: #{err}"
        end)

      {:noreply, socket |> put_flash(:error, "Failed to save: #{Enum.join(messages, "; ")}")}
    else
      {:noreply, socket |> put_flash(:info, "Application profile settings saved successfully")}
    end
  end

  def handle_event("delete_app_logo", _params, socket) do
    case System.get_setting_by_name("app_logo_url") do
      nil ->
        {:noreply, put_flash(socket, :error, "No app logo to delete")}

      %Voile.Schema.System.Setting{setting_value: url} = setting ->
        # Attempt to delete in storage, ignore errors
        case Storage.delete(url) do
          {:ok, _} -> :ok
          _ -> :ok
        end

        case System.delete_setting(setting) do
          {:ok, _} ->
            {:noreply,
             socket
             |> assign(:app_logo_preview, nil)
             |> put_flash(:info, "Application logo removed")}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Failed to remove application logo")}
        end
    end
  end

  # Live upload progress handler
  defp handle_progress(:app_logo, _entry, socket) do
    uploaded_files =
      try do
        consume_uploaded_entries(socket, :app_logo, fn %{path: path}, entry ->
          upload = %Plug.Upload{
            path: path,
            filename: entry.client_name,
            content_type: entry.client_type
          }

          # Choose adapter based on persisted setting (fallback to local)
          adapter =
            case System.get_setting_value("storage_adapter", "local") do
              "s3" -> Client.Storage.S3
              _ -> Client.Storage.Local
            end

          case Storage.upload(upload, folder: "app_logo", adapter: adapter) do
            {:ok, url} ->
              # Persist the app logo URL immediately so layout can pick it up
              System.upsert_setting("app_logo_url", url)
              {:ok, url}

            url when is_binary(url) ->
              System.upsert_setting("app_logo_url", url)
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
        socket
        |> assign(:app_logo_preview, preview)
      else
        socket
      end

    {:noreply, socket}
  end
end
