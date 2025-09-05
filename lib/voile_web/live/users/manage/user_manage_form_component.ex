defmodule VoileWeb.Users.ManageLive.FormComponent do
  use VoileWeb, :live_component

  alias Voile.Schema.Accounts

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
    save_user(socket, socket.assigns.action, user_params)
  end

  defp save_user(socket, :edit, user_params) do
    case Accounts.update_profile_user(socket.assigns.user, user_params) do
      {:ok, user} ->
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
