defmodule VoileWeb.Users.Permission.ManageLive.FormComponent do
  use VoileWeb, :live_component

  alias VoileWeb.Auth.PermissionManager
  alias Voile.Schema.Accounts.Permission

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        {@title}
        <:subtitle>
          <%= if @action == :new do %>
            {gettext("Create a new permission for access control")}
          <% else %>
            {gettext("Update permission information")}
          <% end %>
        </:subtitle>
      </.header>

      <.form
        for={@form}
        id="permission-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input
          field={@form[:name]}
          type="text"
          label={gettext("Permission Name")}
          placeholder={gettext("e.g., collections.create, users.update")}
          phx-debounce="blur"
        />
        <div class="text-xs text-gray-500 dark:text-gray-400 -mt-2 mb-4">
          {gettext("Format: resource.action (e.g., collections.create)")}
        </div>

        <.input
          field={@form[:resource]}
          type="text"
          label={gettext("Resource")}
          placeholder={gettext("e.g., collections, users, items")}
          phx-debounce="blur"
        />
        <.input
          field={@form[:action]}
          type="text"
          label={gettext("Action")}
          placeholder={gettext("e.g., create, read, update, delete")}
          phx-debounce="blur"
        />
        <.input
          field={@form[:description]}
          type="textarea"
          label={gettext("Description")}
          placeholder={gettext("Describe what this permission allows users to do")}
          rows="3"
        />
        <div class="mt-6 flex items-center justify-end gap-x-3">
          <.button type="button" phx-click={JS.patch(@patch)} class="secondary-btn">
            {gettext("Cancel")}
          </.button>
          <.button type="submit" phx-disable-with={gettext("Saving...")}>
            {if @action == :new, do: gettext("Create Permission"), else: gettext("Update Permission")}
          </.button>
        </div>
      </.form>
    </div>
    """
  end

  @impl true
  def update(%{permission: permission} = assigns, socket) do
    changeset = Permission.changeset(permission, %{})

    {:ok,
     socket
     |> assign(assigns)
     |> assign_form(changeset)}
  end

  @impl true
  def handle_event("validate", %{"permission" => permission_params}, socket) do
    changeset =
      socket.assigns.permission
      |> Permission.changeset(permission_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"permission" => permission_params}, socket) do
    save_permission(socket, socket.assigns.action, permission_params)
  end

  defp save_permission(socket, :new, permission_params) do
    case PermissionManager.create_permission(permission_params) do
      {:ok, permission} ->
        notify_parent({:saved, permission})

        {:noreply,
         socket
         |> put_flash(:info, gettext("Permission created successfully"))
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp save_permission(socket, :edit, permission_params) do
    case PermissionManager.update_permission(socket.assigns.permission, permission_params) do
      {:ok, permission} ->
        notify_parent({:saved, permission})

        {:noreply,
         socket
         |> put_flash(:info, gettext("Permission updated successfully"))
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
