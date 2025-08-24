defmodule VoileWeb.Dashboard.Catalog.CollectionLive.Attachments do
  use VoileWeb, :live_view_dashboard

  alias Voile.Repo
  alias Voile.Schema.Catalog
  alias VoileWeb.Dashboard.Catalog.Components.AttachmentUpload

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <h3>Upload Attachments</h3>
      
      <div class="mt-8 border-t pt-8">
        <h5>Attachments List</h5>
        
        <div>
          <.live_component
            module={AttachmentUpload}
            id="collection-attachments"
            entity={@collection}
            collection_type={@collection.collection_type}
          />
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    {:noreply,
     socket
     |> assign(:collection, Catalog.get_collection!(id))}
  end

  @impl true
  def handle_info({:attachment_updated, _}, socket) do
    collection = Repo.preload(socket.assigns.collection, :attachments, force: true)
    {:noreply, assign(socket, :collection, collection)}
  end
end
