defmodule VoileWeb.UserSettingsLive do
  use VoileWeb, :live_view_dashboard

  alias Voile.Schema.Accounts
  alias Client.Storage
  require Logger

  def render(assigns) do
    ~H"""
    <.header>
      <h4>Account Settings</h4>
      
      <:subtitle>Manage your account email address and password settings</:subtitle>
    </.header>

    <div class="flex gap-4">
      <div class="w-full max-w-64">
        <.dashboard_settings_sidebar current_user={@current_scope.user} current_path={@current_path} />
      </div>
      
      <div class="w-full space-y-12 divide-y">
        <div class="bg-white dark:bg-gray-700 rounded-lg p-4">
          <.form
            for={@email_form}
            id="email_form"
            phx-submit="update_email"
            phx-change="validate_email"
          >
            <.input field={@email_form[:email]} type="email" label="Email" required />
            <.input
              field={@email_form[:current_password]}
              name="current_password"
              id="current_password_for_email"
              type="password"
              label="Current password"
              value={@email_form_current_password}
              required
            /> <.button phx-disable-with="Changing...">Change Email</.button>
          </.form>
        </div>
        
        <div class="bg-white dark:bg-gray-700 rounded-lg p-4">
          <.form
            for={@password_form}
            id="password_form"
            action={~p"/users/log_in?_action=password_updated"}
            method="post"
            phx-change="validate_password"
            phx-submit="update_password"
            phx-trigger-action={@trigger_submit}
          >
            <input
              name={@password_form[:email].name}
              type="hidden"
              id="hidden_user_email"
              value={@current_email}
            />
            <.input field={@password_form[:password]} type="password" label="New password" required />
            <.input
              field={@password_form[:password_confirmation]}
              type="password"
              label="Confirm new password"
            />
            <.input
              field={@password_form[:current_password]}
              name="current_password"
              type="password"
              label="Current password"
              id="current_password_for_password"
              value={@current_password}
              required
            /> <.button phx-disable-with="Changing...">Change Password</.button>
          </.form>
        </div>
        
        <div class="bg-white dark:bg-gray-700 rounded-lg p-4">
          <h4 class="text-lg font-semibold mb-4">Profile & Member Details</h4>
          
          <.form
            for={@profile_form}
            id="profile_form"
            phx-submit="save_profile"
            phx-change="validate_profile"
          >
            <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
              <.input field={@profile_form[:fullname]} type="text" label="Full name" />
              <.input field={@profile_form[:username]} type="text" label="Username" />
            </div>
             <.input field={@profile_form[:email]} type="email" label="Email" disabled />
            <label class="block text-sm font-medium text-gray-700 mb-2">Profile image</label>
            <div phx-drop-target={@uploads.user_image.ref} class="space-y-2">
              <%= if @profile_image_preview || @current_scope.user.user_image do %>
                <div class="flex items-center gap-4">
                  <img
                    src={@profile_image_preview || @current_scope.user.user_image}
                    class="w-20 h-20 rounded-full object-cover"
                  />
                  <div class="flex-1">
                    <p class="text-sm text-voile-muted">Uploaded</p>
                    
                    <.button
                      type="button"
                      phx-click="delete_user_image"
                      phx-value-image={@profile_image_preview || @current_scope.user.user_image}
                      phx-disable-with="Removing..."
                    >
                      Remove
                    </.button>
                  </div>
                </div>
              <% else %>
                <div class="border border-dashed rounded p-4 text-center">
                  <p class="text-sm text-voile-muted">PNG, JPG, GIF up to 10MB</p>
                   <.live_file_input upload={@uploads.user_image} class="hidden" />
                  <label
                    for={@uploads.user_image.ref}
                    class="inline-flex items-center px-4 py-2 mt-2 bg-indigo-600 text-white rounded cursor-pointer"
                  >
                    Choose file
                  </label>
                  <%= for entry <- @uploads.user_image.entries do %>
                    <div class="mt-2 text-sm text-voile-muted">Uploading... {entry.progress}%</div>
                  <% end %>
                </div>
              <% end %>
            </div>
            
            <fieldset class="border border-gray-300 rounded-lg p-4 mt-4">
              <legend class="text-sm font-medium text-gray-900 dark:text-gray-100 px-2">
                Contact Information
              </legend>
              
              <div class="grid grid-cols-1 sm:grid-cols-2 gap-3 mt-2">
                <.input field={@profile_form[:phone_number]} type="text" label="Phone number" />
                <.input field={@profile_form[:website]} type="url" label="Website" />
              </div>
              
              <div class="mt-3">
                <.input field={@profile_form[:address]} type="text" label="Address" />
              </div>
            </fieldset>
            
            <fieldset class="border border-gray-300 rounded-lg p-4 mt-4">
              <legend class="text-sm font-medium text-gray-900 dark:text-gray-100 px-2">
                Social Media
              </legend>
              
              <div class="grid grid-cols-1 sm:grid-cols-2 gap-3 mt-2">
                <.input
                  field={@profile_form[:twitter]}
                  type="text"
                  label="Twitter"
                  placeholder="@username"
                />
                <.input
                  field={@profile_form[:facebook]}
                  type="text"
                  label="Facebook"
                  placeholder="profile-url"
                />
                <.input
                  field={@profile_form[:linkedin]}
                  type="text"
                  label="LinkedIn"
                  placeholder="profile-url"
                />
                <.input
                  field={@profile_form[:instagram]}
                  type="text"
                  label="Instagram"
                  placeholder="@username"
                />
              </div>
            </fieldset>
            
            <fieldset class="border border-gray-300 rounded-lg p-4 mt-4">
              <legend class="text-sm font-medium text-gray-900 dark:text-gray-100 px-2">
                Personal Information
              </legend>
              
              <div class="grid grid-cols-1 sm:grid-cols-2 gap-3 mt-2">
                <.input field={@profile_form[:birth_date]} type="date" label="Birth date" />
                <.input field={@profile_form[:birth_place]} type="text" label="Birth place" />
              </div>
              
              <div class="mt-3">
                <.input
                  field={@profile_form[:gender]}
                  type="select"
                  label="Gender"
                  options={[{"Male", "male"}, {"Female", "female"}, {"Other", "other"}]}
                  prompt="Select gender"
                />
              </div>
            </fieldset>
            
            <fieldset class="border border-gray-300 rounded-lg p-4 mt-4">
              <legend class="text-sm font-medium text-gray-900 dark:text-gray-100 px-2">
                Organization Details
              </legend>
              
              <div class="grid grid-cols-1 sm:grid-cols-2 gap-3 mt-2">
                <.input field={@profile_form[:organization]} type="text" label="Organization" />
                <.input field={@profile_form[:department]} type="text" label="Department" />
              </div>
              
              <div class="mt-3">
                <.input field={@profile_form[:position]} type="text" label="Position" />
              </div>
            </fieldset>
             <hr class="my-4" />
            <div class="mt-3 grid grid-cols-1 gap-2">
              <.button phx-disable-with="Saving...">Save Profile</.button>
            </div>
          </.form>
        </div>
      </div>
    </div>
    """
  end

  def mount(%{"token" => token}, _session, socket) do
    socket =
      case Accounts.update_user_email(socket.assigns.current_scope.user, token) do
        :ok ->
          put_flash(socket, :info, "Email changed successfully.")

        :error ->
          put_flash(socket, :error, "Email change link is invalid or it has expired.")
      end

    {:ok, push_navigate(socket, to: ~p"/manage/settings")}
  end

  def mount(_params, _session, socket) do
    # Use the persisted user from the database to build the changeset.
    # The socket's `current_scope.user` may have been temporarily mutated
    # to show a preview (profile_image_preview) which can prevent Ecto
    # from detecting changes. Loading the persisted user ensures the
    # update changeset sees the difference and an UPDATE is issued.
    user = Accounts.get_user!(socket.assigns.current_scope.user.id)
    email_changeset = Accounts.change_user_email(user)
    password_changeset = Accounts.change_user_password(user)

    profile_changeset = Accounts.change_user(user)

    socket =
      socket
      |> assign(:current_password, nil)
      |> assign(:email_form_current_password, nil)
      |> assign(:current_email, user.email)
      |> assign(:email_form, to_form(email_changeset))
      |> assign(:password_form, to_form(password_changeset))
      |> assign(:profile_form, to_form(profile_changeset))
      |> assign(:profile_image_preview, nil)
      |> assign(:current_path, "/manage/settings/user_profile")
      |> allow_upload(:user_image,
        accept: ~w(.jpg .jpeg .png .webp),
        max_entries: 1,
        auto_upload: true,
        progress: &handle_progress/3
      )
      |> assign(:trigger_submit, false)

    {:ok, socket}
  end

  # Grouped LiveView events ---------------------------------------------------
  def handle_event("validate_email", params, socket) do
    %{"current_password" => password, "user" => user_params} = params

    email_form =
      socket.assigns.current_scope.user
      |> Accounts.change_user_email(user_params)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, email_form: email_form, email_form_current_password: password)}
  end

  def handle_event("update_email", params, socket) do
    %{"current_password" => password, "user" => user_params} = params
    user = socket.assigns.current_scope.user

    case Accounts.apply_user_email(user, password, user_params) do
      {:ok, applied_user} ->
        Accounts.deliver_user_update_email_instructions(
          applied_user,
          user.email,
          &url(~p"/manage/settings/confirm_email/#{&1}")
        )

        info = "A link to confirm your email change has been sent to the new address."
        {:noreply, socket |> put_flash(:info, info) |> assign(email_form_current_password: nil)}

      {:error, changeset} ->
        {:noreply, assign(socket, :email_form, to_form(Map.put(changeset, :action, :insert)))}
    end
  end

  def handle_event("validate_profile", %{"user" => user_params}, socket) do
    user = socket.assigns.current_scope.user

    profile_changeset = Accounts.change_user(user, user_params)

    {:noreply, assign(socket, :profile_form, to_form(profile_changeset))}
  end

  def handle_event("save_profile", %{"user" => user_params} = _params, socket) do
    preview = socket.assigns.profile_image_preview

    # Prefer preview, fall back to form param. Only accept a binary URL.
    photo_value =
      case preview || get_in(user_params || %{}, ["user_image"]) do
        v when is_binary(v) and v != "" -> v
        _ -> nil
      end

    user_params =
      if photo_value, do: Map.put(user_params, "user_image", photo_value), else: user_params

    # Always use persisted user when building the update changeset.
    user = Accounts.get_user!(socket.assigns.current_scope.user.id)

    # Keep the previous user_image so we can remove the file from storage
    old_image = user.user_image

    case Accounts.update_profile_user(user, user_params) do
      {:ok, _user} ->
        persisted_user = Accounts.get_user!(user.id)

        # If we changed the image and the old image looks like an upload path,
        # attempt to delete the old file. Ignore any errors from Storage.
        new_image = persisted_user.user_image

        if old_image && is_binary(old_image) && old_image != new_image &&
             String.starts_with?(old_image, "/uploads") do
          case Storage.delete(old_image) do
            {:ok, _} -> :ok
            _ -> :ok
          end
        end

        current_scope = Map.put(socket.assigns.current_scope, :user, persisted_user)

        {:noreply,
         socket
         |> assign(:profile_image_preview, nil)
         |> assign(:current_scope, current_scope)
         |> assign(
           :profile_form,
           to_form(
             Accounts.change_user(persisted_user, %{"user_image" => persisted_user.user_image})
           )
         )
         |> put_flash(:info, "Profile updated")}

      {:error, changeset} ->
        {:noreply, assign(socket, :profile_form, to_form(changeset))}
    end
  end

  def handle_event("delete_user_image", %{"image" => image}, socket) do
    # If we have a preview (image uploaded but not yet persisted), just
    # clear the preview and update the UI without calling Storage or DB.
    if socket.assigns.profile_image_preview do
      current_user = Map.put(socket.assigns.current_scope.user, :user_image, nil)
      current_scope = Map.put(socket.assigns.current_scope, :user, current_user)

      {:noreply,
       socket
       |> assign(:profile_image_preview, nil)
       |> assign(:current_scope, current_scope)
       |> put_flash(:info, "Image removed")}
    else
      case Storage.delete(image) do
        {:ok, _} -> :ok
        _ -> :ok
      end

      user = socket.assigns.current_scope.user

      case Accounts.update_profile_user(user, %{"user_image" => nil}) do
        {:ok, updated_user} ->
          current_scope = Map.put(socket.assigns.current_scope, :user, updated_user)
          profile_changeset = Accounts.change_user(updated_user)

          {:noreply,
           socket
           |> assign(:current_scope, current_scope)
           |> assign(:profile_form, to_form(profile_changeset))
           |> put_flash(:info, "Profile image deleted successfully")}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to delete image")}
      end
    end
  end

  def handle_event("validate_password", params, socket) do
    %{"current_password" => password, "user" => user_params} = params

    password_form =
      socket.assigns.current_scope.user
      |> Accounts.change_user_password(user_params)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, password_form: password_form, current_password: password)}
  end

  def handle_event("update_password", params, socket) do
    %{"current_password" => password, "user" => user_params} = params
    user = socket.assigns.current_scope.user

    case Accounts.update_user_password(user, password, user_params) do
      {:ok, user} ->
        password_form =
          user
          |> Accounts.change_user_password(user_params)
          |> to_form()

        {:noreply, assign(socket, trigger_submit: true, password_form: password_form)}

      {:error, changeset} ->
        {:noreply, assign(socket, password_form: to_form(changeset))}
    end
  end

  defp handle_progress(:user_image, _entry, socket) do
    uploaded_files =
      try do
        consume_uploaded_entries(socket, :user_image, fn %{path: path}, entry ->
          upload = %Plug.Upload{
            path: path,
            filename: entry.client_name,
            content_type: entry.client_type
          }

          case Storage.upload(upload, folder: "user_image") do
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
          # If uploads are no longer allowed for this socket/entry, just skip
          []
      end

    # consume_uploaded_entries returns a list of results from the callback.
    # Our callback returns {:ok, url} or {:ok, nil}, so normalize to extract
    # the url string (or nil) so we don't accidentally store a tuple in
    # assigns or persist it to the DB.
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
        # Keep the preview in a dedicated assign to avoid embedding maps into
        # template attributes. Also update the current_scope user for immediate
        # UI feedback.
        current_user = Map.put(socket.assigns.current_scope.user, :user_image, preview)
        current_scope = Map.put(socket.assigns.current_scope, :user, current_user)

        socket
        |> assign(:profile_image_preview, preview)
        |> assign(:current_scope, current_scope)
      else
        socket
      end

    {:noreply, socket}
  end
end
