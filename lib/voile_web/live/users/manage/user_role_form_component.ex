defmodule VoileWeb.Users.Manage.UserRoleFormComponent do
  use VoileWeb, :live_component

  alias Voile.Schema.Accounts

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        {@title}
        <:subtitle>Configure role permissions for different resources.</:subtitle>
      </.header>
      
      <.simple_form
        for={@form}
        id="user_role-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input field={@form[:name]} type="text" label="Role Name" />
        <.input field={@form[:description]} type="textarea" label="Description" rows="3" />
        <div class="mt-6">
          <h3 class="text-lg font-medium text-gray-900 mb-4">Permissions</h3>
          <!-- Add new resource -->
          <div class="mb-6 p-4 border border-gray-200 rounded-lg bg-gray-50">
            <h4 class="text-sm font-medium text-gray-700 mb-3">Add New Resource</h4>
            
            <div class="flex gap-3">
              <input
                type="text"
                id="new-resource"
                placeholder="Resource name (e.g., books, collections)"
                class="flex-1 rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500"
              />
              <button
                type="button"
                phx-target={@myself}
                phx-click="add_resource"
                class="px-4 py-2 bg-indigo-600 text-white rounded-md hover:bg-indigo-700"
              >
                Add
              </button>
            </div>
          </div>
          <!-- Existing permissions -->
          <div class="space-y-4">
            <%= for {resource, permissions} <- @current_permissions do %>
              <div class="border border-gray-200 rounded-lg p-4">
                <div class="flex items-center justify-between mb-3">
                  <h4 class="text-sm font-medium text-gray-900 capitalize">{resource}</h4>
                  
                  <button
                    type="button"
                    phx-target={@myself}
                    phx-click="remove_resource"
                    phx-value-resource={resource}
                    class="text-red-600 hover:text-red-700 text-sm"
                  >
                    Remove Resource
                  </button>
                </div>
                
                <div class="grid grid-cols-2 gap-3 sm:grid-cols-4">
                  <%= for action <- ["create", "read", "update", "delete"] do %>
                    <label class="flex items-center">
                      <input
                        type="checkbox"
                        name={"permissions[#{resource}][#{action}]"}
                        value="true"
                        checked={Map.get(permissions, action, false)}
                        phx-target={@myself}
                        phx-change="update_permission"
                        class="rounded border-gray-300 text-indigo-600 shadow-sm focus:border-indigo-300 focus:ring focus:ring-indigo-200 focus:ring-opacity-50"
                      /> <span class="ml-2 text-sm text-gray-600 capitalize">{action}</span>
                    </label>
                  <% end %>
                </div>
              </div>
            <% end %>
          </div>
          <!-- Suggested resources from existing roles -->
          <%= if @suggested_resources != [] do %>
            <div class="mt-6">
              <h4 class="text-sm font-medium text-gray-700 mb-3">Common Resources</h4>
              
              <div class="flex flex-wrap gap-2">
                <%= for resource <- @suggested_resources do %>
                  <button
                    type="button"
                    phx-target={@myself}
                    phx-click="add_suggested_resource"
                    phx-value-resource={resource}
                    class="px-3 py-1 text-sm bg-blue-100 text-blue-700 rounded-md hover:bg-blue-200"
                  >
                    + {resource}
                  </button>
                <% end %>
              </div>
            </div>
          <% end %>
        </div>
        
        <:actions><.button phx-disable-with="Saving...">Save Role</.button></:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(%{user_role: user_role} = assigns, socket) do
    changeset = Accounts.change_user_role(user_role)
    current_permissions = user_role.permissions || %{}

    # Get suggested resources (resources that exist in other roles but not in current)
    all_resources = assigns.available_resources || []
    current_resource_names = Map.keys(current_permissions)
    suggested_resources = all_resources -- current_resource_names

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:current_permissions, current_permissions)
     |> assign(:suggested_resources, suggested_resources)
     |> assign_form(changeset)}
  end

  @impl true
  def handle_event("validate", %{"user_role" => user_role_params}, socket) do
    changeset =
      socket.assigns.user_role
      |> Accounts.change_user_role(user_role_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"user_role" => user_role_params}, socket) do
    # Merge current permissions with form data
    permissions = prepare_permissions(user_role_params, socket.assigns.current_permissions)
    user_role_params = Map.put(user_role_params, "permissions", permissions)

    save_user_role(socket, socket.assigns.action, user_role_params)
  end

  def handle_event("add_resource", _params, socket) do
    # This will be handled by JavaScript to get the input value
    {:noreply, socket}
  end

  def handle_event("add_suggested_resource", %{"resource" => resource}, socket) do
    current_permissions = socket.assigns.current_permissions

    new_permissions =
      Map.put(current_permissions, resource, %{
        "create" => false,
        "read" => true,
        "update" => false,
        "delete" => false
      })

    suggested_resources = socket.assigns.suggested_resources -- [resource]

    {:noreply,
     socket
     |> assign(:current_permissions, new_permissions)
     |> assign(:suggested_resources, suggested_resources)}
  end

  def handle_event("remove_resource", %{"resource" => resource}, socket) do
    current_permissions = Map.delete(socket.assigns.current_permissions, resource)
    suggested_resources = [resource | socket.assigns.suggested_resources] |> Enum.uniq()

    {:noreply,
     socket
     |> assign(:current_permissions, current_permissions)
     |> assign(:suggested_resources, suggested_resources)}
  end

  def handle_event("update_permission", params, socket) do
    # Extract resource and action from the checkbox name
    case extract_permission_info(params) do
      {resource, action, checked} ->
        current_permissions = socket.assigns.current_permissions
        resource_permissions = Map.get(current_permissions, resource, %{})
        updated_resource_permissions = Map.put(resource_permissions, action, checked)
        updated_permissions = Map.put(current_permissions, resource, updated_resource_permissions)

        {:noreply, assign(socket, :current_permissions, updated_permissions)}

      _ ->
        {:noreply, socket}
    end
  end

  defp extract_permission_info(params) do
    # Find the permission parameter
    permission_param =
      Enum.find(params, fn {key, _value} ->
        String.starts_with?(key, "permissions[")
      end)

    case permission_param do
      {key, value} ->
        # Extract resource and action from key like "permissions[users][create]"
        case Regex.run(~r/permissions\[(.+?)\]\[(.+?)\]/, key) do
          [_, resource, action] ->
            checked = value == "true"
            {resource, action, checked}

          _ ->
            nil
        end

      _ ->
        nil
    end
  end

  defp prepare_permissions(params, current_permissions) do
    # Extract permissions from form params and merge with current
    form_permissions = Map.get(params, "permissions", %{})

    # Convert form permissions format to our expected format
    Enum.reduce(form_permissions, current_permissions, fn {resource, actions}, acc ->
      # Ensure all actions have boolean values
      actions_map =
        Enum.reduce(actions, %{}, fn {action, value}, action_acc ->
          Map.put(action_acc, action, value == "true")
        end)

      Map.put(acc, resource, actions_map)
    end)
  end

  defp save_user_role(socket, :edit, user_role_params) do
    case Accounts.update_user_role(socket.assigns.user_role, user_role_params) do
      {:ok, user_role} ->
        notify_parent({:saved, user_role})

        {:noreply,
         socket
         |> put_flash(:info, "Role updated successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp save_user_role(socket, :new, user_role_params) do
    case Accounts.create_user_role(user_role_params) do
      {:ok, user_role} ->
        notify_parent({:saved, user_role})

        {:noreply,
         socket
         |> put_flash(:info, "Role created successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset))
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
