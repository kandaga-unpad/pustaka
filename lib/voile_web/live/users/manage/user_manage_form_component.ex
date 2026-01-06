defmodule VoileWeb.Users.ManageLive.FormComponent do
  use VoileWeb, :live_component

  alias Voile.Schema.Accounts
  alias Client.Storage
  import VoileWeb.Auth.Authorization, only: [can?: 2]

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        {@title}
        <:subtitle>Use this form to manage user records in your database.</:subtitle>
      </.header>

      <.form
        for={@form}
        id="user-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <div class="grid grid-cols-1 gap-6 sm:grid-cols-2">
          <.input
            field={@form[:username]}
            type="text"
            label="Username"
            disabled={not can?(@current_scope.user, "users.update")}
          /> <.input field={@form[:email]} type="email" label="Email" />
        </div>

        <div class="grid grid-cols-1 gap-6 sm:grid-cols-2">
          <.input field={@form[:fullname]} type="text" label="Full Name" />
          <.input
            field={@form[:identifier]}
            type="text"
            label="Member Identifier"
            placeholder="Member ID or Student Number"
          />
        </div>

        <div class="grid grid-cols-1 gap-6">
          <div>
            <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
              Assign Roles
            </label>
            <div class="space-y-2">
              <%= for role <- @available_roles do %>
                <label class="flex items-center gap-2 p-3 border border-gray-300 dark:border-gray-600 rounded-lg hover:bg-gray-50 dark:hover:bg-gray-600 cursor-pointer">
                  <input
                    type="checkbox"
                    name="user[role_ids][]"
                    value={role.id}
                    checked={role.id in (@selected_role_ids || [])}
                    class="rounded border-gray-300 text-blue-600 focus:ring-blue-500"
                  />
                  <div class="flex-1">
                    <div class="font-medium text-gray-900 dark:text-gray-100 capitalize">
                      {role.name}
                    </div>

                    <%= if role.description do %>
                      <div class="text-sm text-gray-500 dark:text-gray-400">{role.description}</div>
                    <% end %>
                  </div>
                </label>
              <% end %>
            </div>

            <p class="mt-2 text-sm text-gray-500 dark:text-gray-400">
              Users can have multiple roles. Role-specific permissions can be managed in the
              <.link navigate="/manage/settings/roles" class="text-blue-600 hover:underline">
                Role Management
              </.link>
              page.
            </p>
          </div>
        </div>

        <%= if @action == :new do %>
          <.input field={@form[:password]} type="password" label="Password" />
          <.input field={@form[:password_confirmation]} type="password" label="Confirm Password" />
        <% end %>

        <div class="grid grid-cols-1 gap-6 sm:grid-cols-2">
          <.input
            field={@form[:user_type_id]}
            type="select"
            label="User Type"
            options={Enum.map(@user_type_options, &{&1.name, &1.id})}
            prompt="Select a user type"
          />
          <.input
            field={@form[:node_id]}
            type="select"
            options={Enum.map(@node_list, &{&1.name, &1.id})}
            prompt="Select a node"
            label="Node ID"
          />
        </div>
        <!-- User Image upload -->
        <div class="mt-4">
          <label class="block text-sm font-medium text-gray-700 mb-2">User Image</label>
          <div phx-drop-target={@uploads.user_image.ref} class="space-y-2">
            <%= if @form.params["user_image"] && @form.params["user_image"] != "" do %>
              <div class="flex items-center gap-4">
                <img src={@form.params["user_image"]} class="w-20 h-20 rounded-full object-cover" />
                <div class="flex-1">
                  <p class="text-sm text-gray-700">Uploaded</p>

                  <.button
                    type="button"
                    phx-click="delete_user_image"
                    phx-value-image={@form.params["user_image"]}
                    phx-target={@myself}
                    class="cancel-btn"
                    phx-disable-with="Removing..."
                  >
                    Remove
                  </.button>
                </div>
              </div>
            <% else %>
              <div class="border border-dashed rounded p-4 text-center">
                <p class="text-sm text-gray-500">PNG, JPG, GIF up to 10MB</p>
                <.live_file_input upload={@uploads.user_image} class="hidden" />
                <label
                  for={@uploads.user_image.ref}
                  class="inline-flex items-center px-4 py-2 mt-2 bg-gray-800 text-white rounded cursor-pointer"
                >
                  Choose file
                </label>
                <%= for entry <- @uploads.user_image.entries do %>
                  <div class="mt-2 text-sm text-gray-600">Uploading... {entry.progress}%</div>
                <% end %>
              </div>
            <% end %>
          </div>
        </div>

        <fieldset class="border border-gray-300 rounded-lg p-4">
          <legend class="text-sm font-medium text-gray-900 dark:text-gray-100 px-2">
            Social Media
          </legend>

          <div class="grid grid-cols-1 gap-4 sm:grid-cols-2 mt-2">
            <.input field={@form[:twitter]} type="text" label="Twitter" placeholder="@username" />
            <.input field={@form[:facebook]} type="text" label="Facebook" placeholder="profile-url" />
            <.input field={@form[:linkedin]} type="text" label="LinkedIn" placeholder="profile-url" />
            <.input field={@form[:instagram]} type="text" label="Instagram" placeholder="@username" />
          </div>

          <div class="mt-4">
            <.input
              field={@form[:website]}
              type="url"
              label="Website"
              placeholder="https://example.com"
            />
          </div>
        </fieldset>

        <div class="grid grid-cols-1 gap-6 sm:grid-cols-2">
          <.input
            field={@form[:groups]}
            type="text"
            label="Groups (comma-separated)"
            placeholder="group1, group2, group3"
          />
        </div>
        <.button phx-disable-with="Saving...">Save User</.button>
      </.form>
    </div>
    """
  end

  @impl true
  def update(%{user: user} = assigns, socket) do
    changeset = Accounts.change_user(user)

    # Load available roles
    available_roles = VoileWeb.Auth.PermissionManager.list_roles()

    # Get user's current role IDs
    selected_role_ids =
      if user.id do
        user
        |> Voile.Repo.preload(:roles)
        |> Map.get(:roles, [])
        |> Enum.map(& &1.id)
      else
        []
      end

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:available_roles, available_roles)
     |> assign(:selected_role_ids, selected_role_ids)
     |> allow_upload(:user_image,
       accept: ~w(.jpg .jpeg .png .webp),
       max_entries: 1,
       auto_upload: true,
       progress: &handle_progress/3
     )
     |> assign_form(changeset)}
  end

  @impl true
  def handle_event("validate", %{"user" => user_params}, socket) do
    # Convert groups string to array
    user_params = prepare_user_params(user_params)

    # Extract and store role_ids for form state
    # When checkboxes are unchecked, they're not sent in params, so we need to handle this
    role_ids =
      user_params
      |> Map.get("role_ids", [])
      |> Enum.reject(&(&1 == ""))
      |> Enum.map(fn
        id when is_integer(id) -> id
        id when is_binary(id) -> String.to_integer(id)
      end)

    changeset =
      socket.assigns.user
      |> Accounts.change_user(user_params)
      |> Map.put(:action, :validate)

    {:noreply,
     socket
     |> assign(:selected_role_ids, role_ids)
     |> assign_form(changeset)}
  end

  def handle_event("save", %{"user" => user_params}, socket) do
    user_params = prepare_user_params(user_params)

    # Extract role_ids from params
    role_ids = Map.get(user_params, "role_ids", [])

    # Ensure any uploaded user image URL present in the form state is included
    uploaded_image = socket.assigns.form.params && socket.assigns.form.params["user_image"]

    user_params =
      if uploaded_image && uploaded_image != "" do
        Map.put(user_params, "user_image", uploaded_image)
      else
        user_params
      end

    save_user(socket, socket.assigns.action, user_params, role_ids)
  end

  def handle_event("delete_user_image", %{"image" => image}, socket) do
    # Cancel any pending uploads
    uploads = socket.assigns.uploads

    socket =
      Enum.reduce(uploads.user_image.entries, socket, fn entry, sock ->
        cancel_upload(sock, :user_image, entry.ref)
      end)

    case socket.assigns.action do
      :new ->
        # just remove from form params
        form_params = Map.put(socket.assigns.form.params || %{}, "user_image", nil)
        changeset = Accounts.change_user(socket.assigns.user, form_params)

        {:noreply,
         socket
         |> assign(:form, to_form(changeset))
         |> put_flash(:info, "User image removed")}

      :edit ->
        # delete file from storage and update user
        Storage.delete(image)

        case Accounts.update_profile_user(socket.assigns.user, %{"user_image" => nil}) do
          {:ok, user} ->
            changeset = Accounts.change_user(user, %{})

            {:noreply,
             socket
             |> assign(:form, to_form(changeset))
             |> assign(:user, user)
             |> put_flash(:info, "User image deleted successfully")}

          {:error, _changeset} ->
            {:noreply, put_flash(socket, :error, "Failed to delete user image")}
        end

      _ ->
        {:noreply, socket}
    end
  end

  defp handle_progress(:user_image, entry, socket) do
    if entry.done? do
      # If there is an existing image in form params, attempt to delete it
      if socket.assigns.form.params && socket.assigns.form.params["user_image"] do
        Storage.delete(socket.assigns.form.params["user_image"])
      end

      result =
        consume_uploaded_entries(socket, :user_image, fn %{path: path}, entry ->
          upload = %Plug.Upload{
            path: path,
            filename: entry.client_name,
            content_type: entry.client_type
          }

          # Use per-user sharding when user id is present
          user_id = socket.assigns.user && socket.assigns.user.id

          Storage.upload(upload, folder: "user_image", generate_filename: true, unit_id: user_id)
        end)

      case result do
        [{:ok, url}] ->
          form_params = Map.put(socket.assigns.form.params || %{}, "user_image", url)
          changeset = Accounts.change_user(socket.assigns.user, form_params)

          {:noreply,
           socket
           |> assign(:form, to_form(changeset))
           |> assign(:user, Ecto.Changeset.apply_changes(changeset))}

        [url] when is_binary(url) ->
          form_params = Map.put(socket.assigns.form.params || %{}, "user_image", url)
          changeset = Accounts.change_user(socket.assigns.user, form_params)

          {:noreply,
           socket
           |> assign(:form, to_form(changeset))
           |> assign(:user, Ecto.Changeset.apply_changes(changeset))}

        [{:error, err}] ->
          {:noreply, put_flash(socket, :error, err)}

        _ ->
          {:noreply, put_flash(socket, :error, "Unexpected upload result: #{inspect(result)}")}
      end
    else
      {:noreply, socket}
    end
  end

  defp save_user(socket, :edit, user_params, role_ids) do
    case Accounts.admin_update_user(socket.assigns.user, user_params) do
      {:ok, user} ->
        # Update role assignments
        update_user_roles(user, role_ids, socket.assigns.current_scope.user.id)

        notify_parent({:saved, user})

        {:noreply,
         socket
         |> put_flash(:info, "User updated successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to update user. Please check the form for errors.")
         |> assign_form(changeset)}
    end
  end

  defp save_user(socket, :new, user_params, role_ids) do
    case Accounts.register_user(user_params) do
      {:ok, user} ->
        # Assign roles to new user
        update_user_roles(user, role_ids, socket.assigns.current_scope.user.id)

        notify_parent({:saved, user})

        {:noreply,
         socket
         |> put_flash(:info, "User created successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to create user. Please check the form for errors.")
         |> assign_form(changeset)}
    end
  end

  # Helper to update user roles
  defp update_user_roles(user, role_ids, assigned_by_id) do
    alias VoileWeb.Auth.Authorization

    # Get current role IDs
    current_role_ids =
      user
      |> Voile.Repo.preload(:roles)
      |> Map.get(:roles, [])
      |> Enum.map(& &1.id)
      |> MapSet.new()

    # Convert role_ids to integers and create set
    new_role_ids =
      role_ids
      |> Enum.reject(&(&1 == ""))
      |> Enum.map(fn
        id when is_integer(id) -> id
        id when is_binary(id) -> String.to_integer(id)
      end)
      |> MapSet.new()

    # Determine roles to add and remove
    roles_to_add = MapSet.difference(new_role_ids, current_role_ids)
    roles_to_remove = MapSet.difference(current_role_ids, new_role_ids)

    # Add new roles
    Enum.each(roles_to_add, fn role_id ->
      Authorization.assign_role(user.id, role_id, assigned_by_id: assigned_by_id)
    end)

    # Remove old roles
    Enum.each(roles_to_remove, fn role_id ->
      Authorization.revoke_role(user.id, role_id)
    end)

    :ok
  end

  defp prepare_user_params(params) do
    # Convert groups string to array
    groups =
      case params["groups"] do
        nil ->
          []

        "" ->
          []

        groups_string ->
          groups_string
          |> String.split(",")
          |> Enum.map(&String.trim/1)
          |> Enum.reject(&(&1 == ""))
      end

    Map.put(params, "groups", groups)
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset))
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
