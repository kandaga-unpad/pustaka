defmodule VoileWeb.Dashboard.Master.CreatorLive.FormComponent do
  use VoileWeb, :live_component

  alias Voile.Schema.Master
  # alias Voile.Schema.Master.Creator

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        {@title}
        <:subtitle>Use this form to manage item records in your database.</:subtitle>
      </.header>

      <.form
        for={@form}
        id="item-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input field={@form[:creator_name]} type="text" label="Name" />
        <.input field={@form[:creator_contact]} type="text" label="Contact" />
        <.input field={@form[:type]} type="text" label="Type" />
        <.input field={@form[:affiliation]} type="text" label="Affiliation" />
        <.button phx-disable-with="Saving...">Save Item</.button>
      </.form>
    </div>
    """
  end

  @impl true
  def update(%{creator: creator} = assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:form, fn ->
       to_form(Master.change_creator(creator))
     end)}
  end

  @impl true
  def handle_event("validate", %{"creator" => creator_params}, socket) do
    changeset = Master.change_creator(socket.assigns.creator, creator_params)
    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"creator" => creator_params}, socket) do
    save_item(socket, socket.assigns.action, creator_params)
  end

  defp save_item(socket, :edit, creator_params) do
    case Master.update_creator(socket.assigns.creator, creator_params) do
      {:ok, creator} ->
        notify_parent({:saved, creator})

        {:noreply,
         socket
         |> put_flash(:info, "Creator updated successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_item(socket, :new, creator_params) do
    case Master.get_or_create_creator(creator_params) do
      {:ok, creator} ->
        notify_parent({:saved, creator})

        {:noreply,
         socket
         |> put_flash(:info, "Creator created successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
