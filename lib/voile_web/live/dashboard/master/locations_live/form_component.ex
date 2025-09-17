defmodule VoileWeb.Dashboard.Master.LocationsLive.FormComponent do
  use VoileWeb, :live_component

  alias Voile.Schema.Master

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        {@title}
        <:subtitle>Manage location records.</:subtitle>
      </.header>
      
      <.form
        for={@form}
        id="location-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input field={@form[:location_code]} type="text" label="Code" />
        <.input field={@form[:location_name]} type="text" label="Name" />
        <.input field={@form[:location_place]} type="text" label="Place" />
        <div class="mt-4 flex gap-3">
          <.button phx-disable-with="Saving...">Save Location</.button>
          <.link patch={@patch} class="btn">Cancel</.link>
        </div>
      </.form>
    </div>
    """
  end

  @impl true
  def update(%{location: location} = assigns, socket) do
    changeset = Master.change_locations(location)

    socket =
      socket
      |> assign(assigns)
      |> assign_new(:form, fn -> to_form(changeset) end)

    {:ok, socket}
  end

  @impl true
  def handle_event("validate", %{"locations" => params}, socket) do
    changeset = Master.change_locations(socket.assigns.location, params)
    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"locations" => params}, socket) do
    save_item(socket, socket.assigns.action, params)
  end

  defp save_item(socket, :edit, params) do
    case Master.update_locations(socket.assigns.location, params) do
      {:ok, location} ->
        notify_parent({:saved, location})

        {:noreply,
         socket
         |> put_flash(:info, "Location updated successfully.")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_item(socket, :new, params) do
    case Master.create_locations(params) do
      {:ok, location} ->
        notify_parent({:saved, location})

        {:noreply,
         socket
         |> put_flash(:info, "Location created successfully.")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
