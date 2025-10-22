defmodule VoileWeb.Dashboard.Catalog.ItemLive.FormComponent do
  use VoileWeb, :live_component

  alias Voile.Schema.Catalog

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-4">
      <.header>
        {@title}
        <:subtitle>Use this form to manage item records in your database.</:subtitle>
      </.header>

      <div class="bg-white dark:bg-gray-800 p-6 rounded-lg shadow-sm">
        <.form
          for={@form}
          id="item-form"
          phx-target={@myself}
          phx-change="validate"
          phx-submit="save"
          class="space-y-6"
        >
          <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
            <.input field={@form[:item_code]} type="text" label="Item code" />
            <.input field={@form[:inventory_code]} type="text" label="Inventory code" />
            <.input field={@form[:barcode]} type="text" label="Barcode" />
            <.input field={@form[:location]} type="text" label="Location" />
            <.input field={@form[:status]} type="text" label="Status" />
            <.input field={@form[:condition]} type="text" label="Condition" />
            <.input
              field={@form[:availability]}
              type="select"
              options={[
                {"Available", "available"},
                {"Loaned", "loaned"},
                {"Reserved", "reserved"},
                {"Maintenance", "maintenance"}
              ]}
              label="Availability"
            />
          </div>

          <div class="flex items-center gap-3 pt-2">
            <.button
              phx-disable-with="Saving..."
              class="success-btn"
            >
              <.icon name="hero-check" class="w-4 h-4" /> Save
            </.button>
            <.link patch={@patch} class="inline-block">
              <.button type="button" class="cancel-btn">Cancel</.button>
            </.link>
            <div class="ml-auto text-sm text-gray-500">
              Tip: edit fields and click Save to persist changes.
            </div>
          </div>
        </.form>
      </div>
    </div>
    """
  end

  @impl true
  def update(%{item: item} = assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:form, fn ->
       to_form(Catalog.change_item(item))
     end)}
  end

  @impl true
  def handle_event("validate", %{"item" => item_params}, socket) do
    changeset = Catalog.change_item(socket.assigns.item, item_params)
    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"item" => item_params}, socket) do
    save_item(socket, socket.assigns.action, item_params)
  end

  defp save_item(socket, :edit, item_params) do
    case Catalog.update_item(socket.assigns.item, item_params) do
      {:ok, item} ->
        notify_parent({:saved, item})

        {:noreply,
         socket
         |> put_flash(:info, "Item updated successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_item(socket, :new, item_params) do
    case Catalog.create_item(item_params) do
      {:ok, item} ->
        notify_parent({:saved, item})

        {:noreply,
         socket
         |> put_flash(:info, "Item created successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
