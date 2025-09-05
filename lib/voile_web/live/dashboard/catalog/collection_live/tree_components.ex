defmodule VoileWeb.Dashboard.Catalog.CollectionLive.TreeComponents do
  use VoileWeb, :html

  @doc """
  Renders a collection tree item with its children
  """
  attr :collection, :map, required: true
  attr :level, :integer, default: 0

  def collection_tree_item(assigns) do
    ~H"""
    <div class={"ml-#{@level * 4} border-l-2 border-gray-200 pl-4 mb-4"}>
      <div class="bg-white dark:bg-gray-800 rounded-lg shadow-sm border border-gray-200 p-4 hover:shadow-md transition-shadow">
        <div class="flex items-center justify-between">
          <div class="flex items-center space-x-4">
            <%= if @collection.thumbnail do %>
              <img src={@collection.thumbnail} class="w-12 h-12 object-cover rounded" alt="Thumbnail" />
            <% else %>
              <img src="/images/v.png" class="w-12 h-12 object-cover rounded" alt="No Thumbnail" />
            <% end %>
            
            <div>
              <div class="flex items-center space-x-2">
                <h3 class="font-semibold text-lg">{@collection.title}</h3>
                
                <%= if @collection.collection_type do %>
                  <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-blue-100 text-blue-800 capitalize">
                    {@collection.collection_type}
                  </span>
                <% end %>
                
                <%= if @collection.sort_order do %>
                  <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-gray-100 text-gray-800">
                    #{@collection.sort_order}
                  </span>
                <% end %>
              </div>
              
              <div class="text-sm text-gray-600">
                <span>
                  by {(@collection.mst_creator && @collection.mst_creator.creator_name) || "Unknown"}
                </span> <span class="mx-2">•</span>
                <span class="capitalize">{@collection.status}</span> <span class="mx-2">•</span>
                <span class="capitalize">{@collection.access_level}</span>
              </div>
            </div>
          </div>
          
          <div class="flex items-center space-x-2">
            <.link
              navigate={~p"/manage/catalog/collections/#{@collection.id}"}
              class="text-blue-600 hover:text-blue-800"
            >
              <.icon name="hero-eye" class="w-5 h-5" />
            </.link>
            <.link
              patch={~p"/manage/catalog/collections/#{@collection.id}/edit"}
              class="text-green-600 hover:text-green-800"
            >
              <.icon name="hero-pencil" class="w-5 h-5" />
            </.link>
            <.link
              phx-click={JS.push("delete", value: %{id: @collection.id})}
              data-confirm="Are you sure?"
              class="text-red-600 hover:text-red-800"
            >
              <.icon name="hero-trash" class="w-5 h-5" />
            </.link>
          </div>
        </div>
      </div>
      
      <%= if @collection.children && !Enum.empty?(@collection.children) do %>
        <%= for child <- @collection.children do %>
          <.collection_tree_item collection={child} level={@level + 1} />
        <% end %>
      <% end %>
    </div>
    """
  end
end
