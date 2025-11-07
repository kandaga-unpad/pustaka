defmodule VoileWeb.Dashboard.Master.TopicLive.FormComponent do
  use VoileWeb, :live_component

  alias Voile.Schema.Master

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        {@title}
        <:subtitle>Manage topic records.</:subtitle>
      </.header>

      <.form for={@form} id="topic-form" phx-target={@myself} phx-change="validate" phx-submit="save">
        <.input field={@form[:name]} type="text" label="Name" />
        <.input field={@form[:type]} type="text" label="Type" />
        <.input field={@form[:description]} type="text" label="Description" />
        <div class="mt-4 flex gap-3">
          <.button phx-disable-with="Saving...">Save Topic</.button>
          <.link patch={@patch} class="btn">Cancel</.link>
        </div>
      </.form>
    </div>
    """
  end

  @impl true
  def update(%{topic: topic} = assigns, socket) do
    changeset = Master.change_topic(topic)

    socket =
      socket
      |> assign(assigns)
      |> assign_new(:form, fn -> to_form(changeset) end)

    {:ok, socket}
  end

  @impl true
  def handle_event("validate", %{"topic" => params}, socket) do
    changeset = Master.change_topic(socket.assigns.topic, params)
    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"topic" => params}, socket) do
    save_item(socket, socket.assigns.action, params)
  end

  defp save_item(socket, :edit, params) do
    case Master.update_topic(socket.assigns.topic, params) do
      {:ok, topic} ->
        notify_parent({:saved, topic})

        {:noreply,
         socket
         |> put_flash(:info, "Topic updated successfully.")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_item(socket, :new, params) do
    case Master.create_topic(params) do
      {:ok, topic} ->
        notify_parent({:saved, topic})

        {:noreply,
         socket
         |> put_flash(:info, "Topic created successfully.")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
