defmodule VoileWeb.Dashboard.Catalog.TransferRequestLive.FormComponent do
  use VoileWeb, :live_component

  alias Voile.Schema.Catalog
  alias Voile.Schema.System

  @impl true
  def update(%{item: item} = assigns, socket) do
    nodes = System.list_nodes()

    # Pre-fill from current item location
    changeset =
      Catalog.change_transfer_request(
        %Catalog.TransferRequest{},
        %{
          item_id: item.id,
          from_node_id: item.unit_id,
          from_location: item.location
        }
      )

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:form, to_form(changeset))
     |> assign(:nodes, nodes)}
  end

  @impl true
  def handle_event("validate", %{"transfer_request" => transfer_params}, socket) do
    changeset =
      %Catalog.TransferRequest{}
      |> Catalog.change_transfer_request(transfer_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, form: to_form(changeset))}
  end

  @impl true
  def handle_event("save", %{"transfer_request" => transfer_params}, socket) do
    transfer_params =
      transfer_params
      |> Map.put("item_id", socket.assigns.item.id)
      |> Map.put("from_node_id", socket.assigns.item.unit_id)
      |> Map.put("from_location", socket.assigns.item.location)
      |> Map.put("requested_by_id", socket.assigns.current_scope.user.id)

    case Catalog.create_transfer_request(transfer_params) do
      {:ok, _transfer_request} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Transfer request created successfully"))
         |> push_navigate(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end
end
