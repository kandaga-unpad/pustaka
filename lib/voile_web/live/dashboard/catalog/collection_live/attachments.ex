defmodule VoileWeb.Dashboard.Catalog.CollectionLive.Attachments do
  use VoileWeb, :live_view_dashboard

  alias Voile.Repo
  alias Voile.Schema.Catalog
  alias VoileWeb.Dashboard.Catalog.Components.AttachmentUpload

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <h3>Attachments Data</h3>
      
      <div class="flex">
        <h6 class="text-orange-500">{@collection.title}</h6>
        
        <h6>'s Attachments Details</h6>
      </div>
      
      <div>
        <.back navigate={~p"/manage/catalog/collections/#{@collection.id}"}>Kembali</.back>
      </div>
      
      <div class="flex gap-4 w-full my-5">
        <div class="flex items-start justify-center w-96">
          <%= if @collection.thumbnail do %>
            <img
              src={@collection.thumbnail}
              class="object-cover w-96 h-96 border border-1 border-gray-50"
            />
          <% else %>
            <div class="w-full min-h-96 flex items-center justify-center border-1 border rounded border-voile-primary dark:border-gray-200">
              <p>No thumbnail available</p>
            </div>
          <% end %>
        </div>
        
        <.list>
          <:item title="Title">{@collection.title || "-"}</:item>
          
          <:item title="Creator">
            {(@collection.mst_creator && @collection.mst_creator.creator_name) || "No creator"}
          </:item>
          
          <:item title="Description">{@collection.description || "-"}</:item>
          
          <:item title="Status">{@collection.status || "-"}</:item>
          
          <:item title="Thumbnail">
            <.link
              navigate={@collection.thumbnail}
              target="_blank"
              class="text-voile-primary hover:underline"
            >
              View
            </.link>
          </:item>
          
          <:item title="Access Level">{@collection.access_level || "-"}</:item>
        </.list>
      </div>
      
      <div class="mt-8 border-t pt-8">
        <h5 class="my-5">Attachments List</h5>
        
        <div>
          <.live_component
            module={AttachmentUpload}
            id="collection-attachments"
            entity={@collection}
            collection_type={@collection.collection_type}
          />
        </div>
      </div>
      
      <div class="flex items-center justify-center">
        <.back navigate={~p"/manage/catalog/collections/#{@collection.id}"}>Kembali</.back>
      </div>
    </div>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    # Check read permission for viewing collection attachments
    authorize!(socket, "collections.read")

    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    collection = Catalog.get_collection!(id)
    current_user = socket.assigns.current_scope.user

    # Verify user has access to this collection's unit
    if Catalog.is_user_admin?(current_user) or collection.unit_id == current_user.node_id do
      {:noreply,
       socket
       |> assign(:collection, collection)}
    else
      {:noreply,
       socket
       |> put_flash(:error, "Access Denied: You don't have permission to view this collection")
       |> push_navigate(to: ~p"/manage/catalog/collections")}
    end
  end

  @impl true
  def handle_info({:attachment_updated, _}, socket) do
    collection = Repo.preload(socket.assigns.collection, :attachments, force: true)
    {:noreply, assign(socket, :collection, collection)}
  end
end
