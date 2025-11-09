defmodule VoileWeb.Frontend.Collections.Show do
  @moduledoc """
  Frontend LiveView for displaying individual collection details to library members
  """

  use VoileWeb, :live_view
  import VoileWeb.VoileComponents

  alias Voile.Schema.Catalog
  alias Voile.Task.Catalog.Collection

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:page_title, "Collection Details")
      |> assign(:collection, nil)
      |> assign(:loading, false)
      |> assign(:items_page, 1)
      |> assign(:items_per_page, 20)
      |> assign(:total_items_pages, 1)
      |> stream_configure(:items, dom_id: &"item-#{&1.id}")

    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _uri, socket) do
    socket = assign(socket, :loading, true)
    send(self(), {:load_collection, id})
    {:noreply, socket}
  end

  @impl true
  def handle_info({:load_collection, id}, socket) do
    # Get collection data for attachments
    attachments_data =
      try do
        Catalog.get_collection!(id)
      rescue
        Ecto.NoResultsError ->
          nil

        e ->
          # Log unexpected errors
          IO.puts("Error getting collection attachments for ID: #{id}: #{Exception.message(e)}")
          nil
      end

    # Safely get the primary ebook attachment
    ebook =
      case attachments_data do
        nil ->
          nil

        %{} ->
          attachments_data.attachments
          |> Enum.filter(fn att -> att.is_primary == true end)
          |> List.first()
      end

    case Collection.load_collection_with_items(id, socket.assigns.items_page) do
      {:ok, collection, items, total_items_pages} ->
        socket =
          socket
          |> assign(:collection, collection)
          |> assign(:total_items_pages, total_items_pages)
          |> assign(:page_title, collection.title)
          |> assign(:loading, false)
          |> stream(:items, items, reset: true)

        # Only assign ebook_id if we have a valid ebook
        socket =
          if ebook && ebook.id do
            assign(socket, :ebook_id, ebook.id)
          else
            socket
          end

        {:noreply, socket}

      {:error, :not_found} ->
        {:noreply,
         socket
         |> put_flash(:error, "Collection not found")
         |> push_navigate(to: ~p"/collections")}

      {:error, :access_denied} ->
        {:noreply,
         socket
         |> put_flash(:error, "You don't have permission to view this collection")
         |> push_navigate(to: ~p"/collections")}
    end
  end

  @impl true
  def handle_event("load_more_items", _params, socket) do
    next_page = socket.assigns.items_page + 1

    case Collection.load_items_for_collection(socket.assigns.collection.id, next_page) do
      {items, _total_pages} ->
        {:noreply,
         socket
         |> assign(:items_page, next_page)
         |> stream(:items, items)}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="min-h-screen bg-gray-50 dark:bg-gray-900">
        <%= if @loading do %>
          <div class="flex justify-center items-center py-12">
            <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
            <span class="ml-2 text-gray-600 dark:text-gray-300">Loading collection...</span>
          </div>
        <% else %>
          <%= if @collection do %>
            <!-- Header -->
            <div class="bg-white dark:bg-gray-800 shadow-sm">
              <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-6">
                <div class="flex items-center gap-4">
                  <.link
                    navigate={~p"/collections"}
                    class="inline-flex items-center text-sm font-medium text-gray-500 dark:text-gray-400 hover:text-gray-700 dark:hover:text-gray-200"
                  >
                    <.icon name="hero-chevron-left-solid" class="w-4 h-4 mr-1" /> Back to Collections
                  </.link>
                </div>
              </div>
            </div>
            <!-- Collection Details -->
            <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
              <div class="lg:grid lg:grid-cols-12 lg:gap-8">
                <!-- Main Content -->
                <div class="lg:col-span-8">
                  <!-- Collection Header -->
                  <div class="bg-white dark:bg-gray-800 rounded-lg shadow-sm border border-voile-light dark:border-voile-dark p-6 mb-6">
                    <div class="flex flex-col sm:flex-row gap-6">
                      <!-- Thumbnail -->
                      <div class="sm:w-48 flex-shrink-0">
                        <%= if @collection.thumbnail do %>
                          <img
                            src={@collection.thumbnail}
                            alt={@collection.title}
                            class="w-full h-64 sm:h-64 object-cover rounded-lg bg-gray-100 dark:bg-gray-700"
                          />
                        <% else %>
                          <div class="w-full h-64 sm:h-64 bg-gray-100 dark:bg-gray-700 rounded-lg flex items-center justify-center">
                            <.icon
                              name="hero-book-open-solid"
                              class="w-16 h-16 text-gray-400 dark:text-gray-500"
                            />
                          </div>
                        <% end %>
                      </div>
                      <!-- Details -->
                      <div class="flex-1 min-w-0">
                        <h1 class="text-2xl sm:text-3xl font-bold text-gray-900 dark:text-white mb-4">
                          {@collection.title}
                        </h1>

                        <%= if @collection.description do %>
                          <p class="text-gray-600 dark:text-gray-300 mb-6 leading-relaxed">
                            {@collection.description}
                          </p>
                        <% end %>
                        <!-- Metadata Grid -->
                        <div class="grid grid-cols-1 sm:grid-cols-2 gap-4 text-sm">
                          <%= if @collection.mst_creator do %>
                            <div class="flex items-center">
                              <.icon
                                name="hero-user-solid"
                                class="w-4 h-4 mr-2 text-gray-400 dark:text-gray-500"
                              /> <span class="text-gray-500 dark:text-gray-400 mr-2">Creator:</span>
                              <span class="font-medium text-gray-900 dark:text-white">
                                {@collection.mst_creator.creator_name}
                              </span>
                            </div>
                          <% end %>

                          <%= if @collection.collection_type do %>
                            <div class="flex items-center">
                              <.icon
                                name="hero-tag-solid"
                                class="w-4 h-4 mr-2 text-gray-400 dark:text-gray-500"
                              /> <span class="text-gray-500 dark:text-gray-400 mr-2">Type:</span>
                              <span class="font-medium text-gray-900 dark:text-white">
                                {String.capitalize(@collection.collection_type)}
                              </span>
                            </div>
                          <% end %>

                          <div class="flex items-center">
                            <.icon
                              name="hero-document-duplicate-solid"
                              class="w-4 h-4 mr-2 text-gray-400 dark:text-gray-500"
                            /> <span class="text-gray-500 dark:text-gray-400 mr-2">Total Items:</span>
                            <span class="font-medium text-gray-900 dark:text-white">
                              {length(@collection.items || [])}
                            </span>
                          </div>

                          <%= if @collection.node do %>
                            <div class="flex items-center">
                              <.icon
                                name="hero-building-library-solid"
                                class="w-4 h-4 mr-2 text-gray-400 dark:text-gray-500"
                              /> <span class="text-gray-500 dark:text-gray-400 mr-2">Location:</span>
                              <span class="font-medium text-gray-900 dark:text-white">
                                {@collection.node.name}
                              </span>
                            </div>
                          <% end %>

                          <div class="flex items-center">
                            <.icon
                              name="hero-calendar-solid"
                              class="w-4 h-4 mr-2 text-gray-400 dark:text-gray-500"
                            /> <span class="text-gray-500 dark:text-gray-400 mr-2">Added:</span>
                            <span class="font-medium text-gray-900 dark:text-white">
                              {Calendar.strftime(@collection.inserted_at, "%B %d, %Y")}
                            </span>
                          </div>

                          <div class="flex items-center">
                            <.icon
                              name="hero-eye-solid"
                              class="w-4 h-4 mr-2 text-gray-400 dark:text-gray-500"
                            /> <span class="text-gray-500 dark:text-gray-400 mr-2">Access:</span>
                            <span class={"px-2 py-1 text-xs rounded-full #{access_level_badge_class(@collection.access_level)}"}>
                              {String.capitalize(@collection.access_level)}
                            </span>
                          </div>
                        </div>
                      </div>
                    </div>
                  </div>
                  <!-- Items Section -->
                  <div class="bg-white dark:bg-gray-800 rounded-lg shadow-sm border border-voile-light dark:border-voile-dark">
                    <div class="px-6 py-4 border-b border-voile-light dark:border-voile-dark">
                      <h2 class="text-lg font-semibold text-gray-900 dark:text-white flex items-center">
                        <.icon name="hero-document-duplicate-solid" class="w-5 h-5 mr-2" />
                        Collection Items
                        <span class="ml-2 text-sm font-normal text-gray-500 dark:text-gray-400">
                          ({length(@collection.items || [])} total)
                        </span>
                      </h2>
                    </div>

                    <div class="divide-y divide-gray-200 dark:divide-gray-700">
                      <div
                        :for={{id, item} <- @streams.items}
                        id={id}
                        class="p-6 hover:bg-gray-50 dark:hover:bg-gray-700"
                      >
                        <.item_card item={item} />
                      </div>
                    </div>
                    <!-- Load More Button -->
                    <%= if @items_page < @total_items_pages do %>
                      <div class="px-6 py-4 border-t border-voile-light dark:border-voile-dark text-center">
                        <button
                          phx-click="load_more_items"
                          class="inline-flex items-center px-4 py-2 border border-voile-muted dark:border-voile-dark rounded-md shadow-sm text-sm font-medium text-voile dark:text-voile-surface bg-white dark:bg-voile-neutral-dark hover:bg-voile-surface dark:hover:bg-voile-surface-dark focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
                        >
                          Load More Items
                        </button>
                      </div>
                    <% end %>
                    <!-- Empty State for Items -->
                    <%= if length(@streams.items.inserts) == 0 do %>
                      <div class="p-12 text-center">
                        <.icon
                          name="hero-document"
                          class="mx-auto h-12 w-12 text-gray-400 dark:text-gray-500"
                        />
                        <h3 class="mt-2 text-sm font-semibold text-gray-900 dark:text-white">
                          No items available
                        </h3>

                        <p class="mt-1 text-sm text-gray-500 dark:text-gray-400">
                          This collection currently has no available items.
                        </p>
                      </div>
                    <% end %>
                  </div>
                </div>
                <!-- Sidebar -->
                <div class="mt-8 lg:mt-0 lg:col-span-4">
                  <div class="sticky top-8 space-y-6">
                    <!-- Quick Actions -->
                    <div class="bg-white dark:bg-gray-800 rounded-lg shadow-sm border border-voile-light dark:border-voile-dark p-6">
                      <h3 class="text-lg font-medium text-gray-900 dark:text-white mb-4">
                        Quick Actions
                      </h3>

                      <div class="space-y-3">
                        <%= if @current_scope && @current_scope.user && @current_scope.user.confirmed_at && assigns[:ebook_id] do %>
                          <.link
                            navigate={~p"/ebooks/view?id=#{@ebook_id}"}
                            class="w-full inline-flex justify-center items-center px-4 py-2 border border-gray-300 dark:border-gray-600 shadow-sm text-sm font-medium rounded-md text-gray-700 dark:text-gray-200 bg-white dark:bg-gray-700 hover:bg-gray-50 dark:hover:bg-gray-600 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
                          >
                            <.icon name="hero-book-open-solid" class="w-4 h-4 mr-2" /> Read E-Book
                          </.link>
                        <% else %>
                          <.button class="disabled-btn w-full" disabled>
                            <.icon name="hero-book-open-solid" class="w-4 h-4 mr-2" /> Read E-Book
                          </.button>
                        <% end %>

                        <.link
                          navigate={~p"/search?q=#{@collection.title}&type=items"}
                          class="w-full inline-flex justify-center items-center px-4 py-2 border border-gray-300 dark:border-gray-600 shadow-sm text-sm font-medium rounded-md text-gray-700 dark:text-gray-200 bg-white dark:bg-gray-700 hover:bg-gray-50 dark:hover:bg-gray-600 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
                        >
                          <.icon name="hero-magnifying-glass-solid" class="w-4 h-4 mr-2" />
                          Search in Collection
                        </.link>
                        <.link
                          navigate={~p"/collections"}
                          class="w-full inline-flex justify-center items-center px-4 py-2 border border-gray-300 dark:border-gray-600 shadow-sm text-sm font-medium rounded-md text-gray-700 dark:text-gray-200 bg-white dark:bg-gray-700 hover:bg-gray-50 dark:hover:bg-gray-600 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
                        >
                          <.icon name="hero-arrow-left-solid" class="w-4 h-4 mr-2" />
                          Browse Collections
                        </.link>
                      </div>
                    </div>
                    <!-- Collection Stats -->
                    <div class="bg-white dark:bg-gray-800 rounded-lg shadow-sm border border-voile-light dark:border-voile-dark p-6">
                      <h3 class="text-lg font-medium text-gray-900 dark:text-white mb-4">
                        Statistics
                      </h3>

                      <div class="space-y-4">
                        <.stat_item
                          icon="document-duplicate"
                          label="Total Items"
                          value={length(@collection.items || [])}
                        />
                        <.stat_item
                          icon="check-circle"
                          label="Available Items"
                          value={available_items_count(@collection.items || [])}
                        />
                        <.stat_item
                          icon="clock"
                          label="On Loan"
                          value={loaned_items_count(@collection.items || [])}
                        />
                      </div>
                    </div>
                    <!-- Related Collections (if any) -->
                    <%= if @collection.mst_creator do %>
                      <div class="bg-white dark:bg-gray-800 rounded-lg shadow-sm border border-voile-light dark:border-voile-dark p-6">
                        <h3 class="text-lg font-medium text-gray-900 dark:text-white mb-4">
                          More by this Creator
                        </h3>

                        <.link
                          navigate={~p"/collections?q=#{@collection.mst_creator.creator_name}"}
                          class="text-sm text-blue-600 dark:text-blue-400 hover:text-blue-800 dark:hover:text-blue-300"
                        >
                          View all collections by {@collection.mst_creator.creator_name} →
                        </.link>
                      </div>
                    <% end %>
                  </div>
                </div>
              </div>
            </div>
          <% end %>
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  # Helper functions for calculating item counts
  defp available_items_count(items) do
    items
    |> Enum.count(&(&1.availability == "available"))
  end

  defp loaned_items_count(items) do
    items
    |> Enum.count(&(&1.availability == "loaned"))
  end
end
