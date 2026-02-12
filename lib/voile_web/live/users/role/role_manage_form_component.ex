defmodule VoileWeb.Users.Role.ManageLive.FormComponent do
  use VoileWeb, :live_component

  alias VoileWeb.Auth.PermissionManager
  alias Voile.Schema.Accounts.Role

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        {@title}
        <:subtitle>
          <%= if @action == :new do %>
            {gettext("Create a new role with specific permissions")}
          <% else %>
            {gettext("Update role information")}
          <% end %>
        </:subtitle>
      </.header>

      <.form
        for={@form}
        id="role-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input
          field={@form[:name]}
          type="text"
          label={gettext("Role Name")}
          placeholder={gettext("e.g., Content Manager, Moderator")}
          disabled={@role.is_system_role}
        />
        <.input
          field={@form[:description]}
          type="textarea"
          label={gettext("Description")}
          placeholder={gettext("Describe what this role can do...")}
          rows="3"
        />
        <%= if @action == :new do %>
          <div class="mt-4">
            <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
              {gettext("Permissions")}
            </label>
            <div class="space-y-2 max-h-96 overflow-y-auto p-4 bg-gray-50 dark:bg-gray-800 rounded-lg">
              <%= for permission <- @all_permissions do %>
                <label class="flex items-start gap-3 p-2 hover:bg-white dark:hover:bg-gray-700 rounded cursor-pointer">
                  <input
                    type="checkbox"
                    name="role[permission_ids][]"
                    value={permission.id}
                    class="mt-1"
                  />
                  <div class="flex-1">
                    <div class="text-sm font-medium text-gray-900 dark:text-white">
                      {permission.name}
                    </div>

                    <%= if permission.description do %>
                      <div class="text-xs text-gray-500 dark:text-gray-400">
                        {permission.description}
                      </div>
                    <% end %>

                    <div class="mt-1 flex items-center gap-2">
                      <span class="text-xs px-2 py-0.5 bg-voile-info/10 text-voile-info rounded">
                        {permission.resource}
                      </span>
                      <span class="text-xs px-2 py-0.5 bg-voile-primary/10 text-voile-primary rounded">
                        {permission.action}
                      </span>
                    </div>
                  </div>
                </label>
              <% end %>
            </div>
          </div>
        <% end %>

        <div class="mt-6 flex items-center justify-end gap-x-4">
          <.button
            type="button"
            phx-click={JS.navigate(@patch)}
            class="cancel-btn"
          >
            {gettext("Cancel")}
          </.button>
          <.button phx-disable-with={gettext("Saving...")} disabled={not @form.source.valid?}>
            {gettext("Save Role")}
          </.button>
        </div>
      </.form>
    </div>
    """
  end

  @impl true
  def update(%{role: role} = assigns, socket) do
    changeset = Role.changeset(role, %{})

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:all_permissions, PermissionManager.list_permissions())
     |> assign_form(changeset)}
  end

  @impl true
  def handle_event("validate", %{"role" => role_params}, socket) do
    changeset =
      socket.assigns.role
      |> Role.changeset(role_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  @impl true
  def handle_event("save", %{"role" => role_params}, socket) do
    save_role(socket, socket.assigns.action, role_params)
  end

  defp save_role(socket, :edit, role_params) do
    case PermissionManager.update_role(socket.assigns.role, role_params) do
      {:ok, role} ->
        notify_parent({:saved, role})

        {:noreply,
         socket
         |> put_flash(:info, gettext("Role updated successfully"))
         |> push_navigate(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp save_role(socket, :new, role_params) do
    # Extract permission_ids from params
    permission_ids = Map.get(role_params, "permission_ids", [])
    role_params = Map.delete(role_params, "permission_ids")

    case PermissionManager.create_role(role_params) do
      {:ok, role} ->
        # Assign permissions to the new role
        if length(permission_ids) > 0 do
          permission_ids
          |> Enum.map(&String.to_integer/1)
          |> Enum.each(fn permission_id ->
            PermissionManager.add_permission_to_role(role.id, permission_id)
          end)
        end

        # Reload role with permissions
        role = PermissionManager.get_role(role.id)
        notify_parent({:saved, role})

        {:noreply,
         socket
         |> put_flash(:info, gettext("Role created successfully"))
         |> push_navigate(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset))
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
