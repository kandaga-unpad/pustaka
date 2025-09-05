defmodule VoileWeb.Dashboard.Master.PublisherLive.FormComponent do
  use VoileWeb, :live_component

  alias Voile.Schema.Master

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        {@title}
        <:subtitle>Use this form to manage publishers records in your database.</:subtitle>
      </.header>
      
      <.form
        for={@form}
        id="publishers-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input field={@form[:name]} type="text" label="Name" />
        <.input field={@form[:address]} type="textarea" label="Address" />
        <.input field={@form[:city]} type="text" label="City" />
        <.input field={@form[:contact]} type="text" label="Contact" />
        <.button phx-disable-with="Saving...">Save Publisher</.button>
      </.form>
    </div>
    """
  end

  @impl true
  def update(%{publisher: publisher} = assigns, socket) do
    changeset = Master.change_publishers(publisher)

    socket =
      socket
      |> assign(assigns)
      |> assign_new(:form, fn -> to_form(changeset) end)

    {:ok, socket}
  end

  @impl true
  def handle_event("validate", %{"publisher" => publisher_params}, socket) do
    changeset = Master.change_publishers(socket.assigns.publisher, publisher_params)
    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"publisher" => publisher_params}, socket) do
    save_item(socket, socket.assigns.action, publisher_params)
  end

  defp save_item(socket, :edit, publisher_params) do
    case Master.update_publishers(socket.assigns.publisher, publisher_params) do
      {:ok, publisher} ->
        notify_parent({:saved, publisher})

        {:noreply,
         socket
         |> put_flash(:info, "Publisher updated successfully.")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_item(socket, :new, publisher_params) do
    case Master.create_publishers(publisher_params) do
      {:ok, publisher} ->
        notify_parent({:saved, publisher})

        {:noreply,
         socket
         |> put_flash(:info, "Publisher created successfully.")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
