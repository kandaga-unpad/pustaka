defmodule VoileWeb.Users.ManageLive.FormComponent do
  use VoileWeb, :live_component

  alias Voile.Schema.Accounts
  alias Client.Storage

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
          <.input field={@form[:username]} type="text" label="Username" disabled />
          <.input field={@form[:email]} type="email" label="Email" />
        </div>
        
        <div class="grid grid-cols-1 gap-6 sm:grid-cols-2">
          <.input field={@form[:fullname]} type="text" label="Full Name" />
          <.input
            field={@form[:user_role_id]}
            type="select"
            label="Role"
            options={@role_options}
            prompt="Select a role"
          />
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
    role_options = Accounts.list_user_roles() |> Enum.map(&{&1.name, &1.id})

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:role_options, role_options)
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

    changeset =
      socket.assigns.user
      |> Accounts.change_user(user_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"user" => user_params}, socket) do
    user_params = prepare_user_params(user_params)
    # Ensure any uploaded user image URL present in the form state is included
    uploaded_image = socket.assigns.form.params && socket.assigns.form.params["user_image"]

    user_params =
      if uploaded_image && uploaded_image != "" do
        Map.put(user_params, "user_image", uploaded_image)
      else
        user_params
      end

    save_user(socket, socket.assigns.action, user_params)
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

  defp save_user(socket, :edit, user_params) do
    case Accounts.update_profile_user(socket.assigns.user, user_params) do
      {:ok, user} ->
        dbg(user)
        notify_parent({:saved, user})

        {:noreply,
         socket
         |> put_flash(:info, "User updated successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        dbg(changeset)
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp save_user(socket, :new, user_params) do
    case Accounts.register_user(user_params) do
      {:ok, user} ->
        notify_parent({:saved, user})

        {:noreply,
         socket
         |> put_flash(:info, "User created successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        dbg(changeset)
        {:noreply, assign_form(socket, changeset)}
    end
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
