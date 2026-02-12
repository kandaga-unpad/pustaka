defmodule VoileWeb.Dashboard.Master.PlacesLive.FormComponent do
  use VoileWeb, :live_component

  alias Voile.Schema.Master

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        {@title}
        <:subtitle>{gettext("Manage place records.")}</:subtitle>
      </.header>

      <.form for={@form} id="place-form" phx-target={@myself} phx-change="validate" phx-submit="save">
        <.input field={@form[:name]} type="text" label={gettext("Name")} />
        <div class="mt-4 flex gap-3">
          <.button phx-disable-with={gettext("Saving...")}>{gettext("Save Place")}</.button>
          <.link patch={@patch} class="btn">{gettext("Cancel")}</.link>
        </div>
      </.form>
    </div>
    """
  end

  @impl true
  def update(%{place: place} = assigns, socket) do
    changeset = Master.change_places(place)

    socket =
      socket
      |> assign(assigns)
      |> assign_new(:form, fn -> to_form(changeset) end)

    {:ok, socket}
  end

  @impl true
  def handle_event("validate", %{"places" => params}, socket) do
    changeset = Master.change_places(socket.assigns.place, params)
    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"places" => params}, socket) do
    save_item(socket, socket.assigns.action, params)
  end

  defp save_item(socket, :edit, params) do
    case Master.update_places(socket.assigns.place, params) do
      {:ok, place} ->
        notify_parent({:saved, place})

        {:noreply,
         socket
         |> put_flash(:info, gettext("Place updated successfully."))
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_item(socket, :new, params) do
    case Master.create_places(params) do
      {:ok, place} ->
        notify_parent({:saved, place})

        {:noreply,
         socket
         |> put_flash(:info, gettext("Place created successfully."))
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
