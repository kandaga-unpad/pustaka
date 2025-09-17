defmodule VoileWeb.Dashboard.Master.FrequencyLive.FormComponent do
  use VoileWeb, :live_component

  alias Voile.Schema.Master

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        {@title}
        <:subtitle>Manage frequency records.</:subtitle>
      </.header>
      
      <.form
        for={@form}
        id="frequency-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input field={@form[:frequency]} type="text" label="Frequency" />
        <.input field={@form[:time_increment]} type="number" label="Time Increment" />
        <.input field={@form[:time_unit]} type="text" label="Time Unit" />
        <div class="mt-4 flex gap-3">
          <.button phx-disable-with="Saving...">Save Frequency</.button>
          <.link patch={@patch} class="btn">Cancel</.link>
        </div>
      </.form>
    </div>
    """
  end

  @impl true
  def update(%{frequency: frequency} = assigns, socket) do
    changeset = Master.change_frequency(frequency)

    socket =
      socket
      |> assign(assigns)
      |> assign_new(:form, fn -> to_form(changeset) end)

    {:ok, socket}
  end

  @impl true
  def handle_event("validate", %{"frequency" => params}, socket) do
    changeset = Master.change_frequency(socket.assigns.frequency, params)
    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"frequency" => params}, socket) do
    save_item(socket, socket.assigns.action, params)
  end

  defp save_item(socket, :edit, params) do
    case Master.update_frequency(socket.assigns.frequency, params) do
      {:ok, frequency} ->
        notify_parent({:saved, frequency})

        {:noreply,
         socket
         |> put_flash(:info, "Frequency updated successfully.")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_item(socket, :new, params) do
    case Master.create_frequency(params) do
      {:ok, frequency} ->
        notify_parent({:saved, frequency})

        {:noreply,
         socket
         |> put_flash(:info, "Frequency created successfully.")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
