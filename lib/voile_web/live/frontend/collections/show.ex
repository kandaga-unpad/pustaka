defmodule VoileWeb.Frontend.Collections.Show do
  @moduledoc """
  Frontend LiveView for displaying individual collection details to library members
  """

  use VoileWeb, :live_view
  import VoileWeb.VoileComponents

  alias Voile.Schema.Catalog
  alias Voile.Task.Catalog.Collection
  alias VoileWeb.Utils.FormatIndonesiaTime

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:page_title, gettext("Collection Details"))
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
         |> put_flash(:error, gettext("Collection not found"))
         |> push_navigate(to: ~p"/collections")}

      {:error, :access_denied} ->
        {:noreply,
         socket
         |> put_flash(:error, gettext("You don't have permission to view this collection"))
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
            <span class="ml-2 text-gray-600 dark:text-gray-300">
              {gettext("Loading collection...")}
            </span>
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
                    <.icon name="hero-chevron-left-solid" class="w-4 h-4 mr-1" /> {gettext(
                      "Back to Collections"
                    )}
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
                        <%!-- Metadata Grid --%>
                        <div class="grid grid-cols-1 sm:grid-cols-2 gap-4 text-sm">
                          <%!-- Collection Code --%>
                          <%= if @collection.collection_code do %>
                            <div class="flex items-center">
                              <.icon
                                name="hero-hashtag"
                                class="w-4 h-4 mr-2 text-gray-400 dark:text-gray-500"
                              />
                              <span class="text-gray-500 dark:text-gray-400 mr-2">
                                {gettext("Code:")}
                              </span>
                              <span class="font-mono text-xs font-medium text-gray-900 dark:text-white bg-gray-100 dark:bg-gray-700 px-2 py-0.5 rounded">
                                {@collection.collection_code}
                              </span>
                            </div>
                          <% end %>
                          <%!-- Resource Type --%>
                          <%= if @collection.resource_class do %>
                            <div class="flex items-center">
                              <.icon
                                name="hero-squares-2x2"
                                class="w-4 h-4 mr-2 text-gray-400 dark:text-gray-500"
                              />
                              <span class="text-gray-500 dark:text-gray-400 mr-2">
                                {gettext("Resource Type:")}
                              </span>
                              <span class="font-medium text-gray-900 dark:text-white">
                                {@collection.resource_class.label}
                              </span>
                            </div>
                          <% end %>
                          <%!-- Creator --%>
                          <%= if @collection.mst_creator do %>
                            <div class="flex items-center">
                              <.icon
                                name="hero-user-solid"
                                class="w-4 h-4 mr-2 text-gray-400 dark:text-gray-500"
                              />
                              <span class="text-gray-500 dark:text-gray-400 mr-2">
                                {gettext("Creator:")}
                              </span>
                              <span class="font-medium text-gray-900 dark:text-white">
                                {@collection.mst_creator.creator_name}
                              </span>
                            </div>
                          <% end %>
                          <%!-- Collection Type --%>
                          <%= if @collection.collection_type do %>
                            <div class="flex items-center">
                              <.icon
                                name="hero-tag-solid"
                                class="w-4 h-4 mr-2 text-gray-400 dark:text-gray-500"
                              />
                              <span class="text-gray-500 dark:text-gray-400 mr-2">
                                {gettext("Type:")}
                              </span>
                              <span class="font-medium text-gray-900 dark:text-white">
                                {String.capitalize(@collection.collection_type)}
                              </span>
                            </div>
                          <% end %>
                          <%!-- Total Items --%>
                          <div class="flex items-center">
                            <.icon
                              name="hero-document-duplicate-solid"
                              class="w-4 h-4 mr-2 text-gray-400 dark:text-gray-500"
                            />
                            <span class="text-gray-500 dark:text-gray-400 mr-2">
                              {gettext("Total Items:")}
                            </span>
                            <span class="font-medium text-gray-900 dark:text-white">
                              {length(@collection.items || [])}
                            </span>
                          </div>
                          <%!-- Location --%>
                          <%= if @collection.node do %>
                            <div class="flex items-center">
                              <.icon
                                name="hero-building-library-solid"
                                class="w-4 h-4 mr-2 text-gray-400 dark:text-gray-500"
                              />
                              <span class="text-gray-500 dark:text-gray-400 mr-2">
                                {gettext("Location:")}
                              </span>
                              <span class="font-medium text-gray-900 dark:text-white">
                                {@collection.node.name}
                              </span>
                            </div>
                          <% end %>
                          <%!-- Date Added --%>
                          <div class="flex items-center">
                            <.icon
                              name="hero-calendar-solid"
                              class="w-4 h-4 mr-2 text-gray-400 dark:text-gray-500"
                            />
                            <span class="text-gray-500 dark:text-gray-400 mr-2">
                              {gettext("Added:")}
                            </span>
                            <span class="font-medium text-gray-900 dark:text-white">
                              {FormatIndonesiaTime.format_full_indonesian_date(
                                @collection.inserted_at
                              )}
                            </span>
                          </div>
                          <%!-- Last Updated --%>
                          <div class="flex items-center">
                            <.icon
                              name="hero-arrow-path"
                              class="w-4 h-4 mr-2 text-gray-400 dark:text-gray-500"
                            />
                            <span class="text-gray-500 dark:text-gray-400 mr-2">
                              {gettext("Updated:")}
                            </span>
                            <span class="font-medium text-gray-900 dark:text-white">
                              {FormatIndonesiaTime.format_full_indonesian_date(@collection.updated_at)}
                            </span>
                          </div>
                          <%!-- Access Level --%>
                          <div class="flex items-center">
                            <.icon
                              name="hero-eye-solid"
                              class="w-4 h-4 mr-2 text-gray-400 dark:text-gray-500"
                            />
                            <span class="text-gray-500 dark:text-gray-400 mr-2">
                              {gettext("Access:")}
                            </span>
                            <span class={"px-2 py-1 text-xs rounded-full #{access_level_badge_class(@collection.access_level)}"}>
                              {String.capitalize(@collection.access_level)}
                            </span>
                          </div>
                        </div>
                      </div>
                    </div>
                  </div>
                  <%!-- Bibliographic Details from collection_fields --%>
                  <%= if @collection.collection_fields != [] do %>
                    <div class="bg-white dark:bg-gray-800 rounded-lg shadow-sm border border-voile-light dark:border-voile-dark p-6 mb-6">
                      <h2 class="text-lg font-semibold text-gray-900 dark:text-white mb-4 flex items-center">
                        <.icon name="hero-list-bullet" class="w-5 h-5 mr-2" />
                        {gettext("Bibliographic Details")}
                      </h2>

                      <dl class="grid grid-cols-1 sm:grid-cols-2 gap-x-6 gap-y-4 text-sm">
                        <%= for field <- Enum.sort_by(@collection.collection_fields, & &1.sort_order) do %>
                          <%= if field.value && field.value != "" do %>
                            <div>
                              <dt class="text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wide mb-1">
                                {field.label}
                              </dt>
                              <dd class="text-gray-900 dark:text-white break-words">
                                {field.value}
                              </dd>
                            </div>
                          <% end %>
                        <% end %>
                      </dl>
                    </div>
                  <% end %>
                  <!-- Parent and Children Collections Section -->
                  <%= if @collection.parent || length(@collection.children || []) > 0 do %>
                    <div class="bg-white dark:bg-gray-800 rounded-lg shadow-sm border border-voile-light dark:border-voile-dark p-6 mb-6">
                      <h2 class="text-lg font-semibold text-gray-900 dark:text-white mb-4 flex items-center">
                        <.icon name="hero-rectangle-stack-solid" class="w-5 h-5 mr-2" />
                        {gettext("Collection Relationships")}
                      </h2>

                      <div class="space-y-6">
                        <!-- Parent Collection -->
                        <%= if @collection.parent do %>
                          <div>
                            <h3 class="text-sm font-semibold text-gray-700 dark:text-gray-300 mb-3 flex items-center gap-2">
                              <.icon name="hero-arrow-up-circle" class="w-5 h-5 text-blue-500" />
                              {gettext("Parent Collection")}
                            </h3>
                            <div class="bg-gray-50 dark:bg-gray-700 rounded-lg p-4">
                              <div class="flex flex-col sm:flex-row items-start gap-4">
                                <!-- A4-sized cover -->
                                <%= if @collection.parent.thumbnail do %>
                                  <img
                                    src={@collection.parent.thumbnail}
                                    alt={@collection.parent.title}
                                    class="w-full sm:w-48 h-64 sm:h-68 object-cover rounded-lg border border-gray-200 dark:border-gray-600 flex-shrink-0"
                                  />
                                <% else %>
                                  <div class="w-full sm:w-48 h-64 sm:h-68 flex items-center justify-center border rounded-lg border-gray-300 dark:border-gray-500 bg-gray-100 dark:bg-gray-600 flex-shrink-0">
                                    <.icon name="hero-folder" class="w-16 h-16 text-gray-400" />
                                  </div>
                                <% end %>

                                <div class="flex-1 min-w-0 flex flex-col justify-between">
                                  <div>
                                    <h4 class="font-semibold text-gray-900 dark:text-white text-base sm:text-lg">
                                      {@collection.parent.title}
                                    </h4>
                                    <%= if @collection.parent.description do %>
                                      <p class="text-sm text-gray-600 dark:text-gray-300 mt-2 line-clamp-3">
                                        {@collection.parent.description}
                                      </p>
                                    <% end %>
                                    <div class="flex items-center gap-2 mt-3">
                                      <span class="text-xs px-2 py-1 rounded-full bg-blue-100 text-blue-800 dark:bg-blue-900 dark:text-blue-200">
                                        {String.capitalize(@collection.parent.status || "draft")}
                                      </span>
                                    </div>
                                  </div>

                                  <div class="mt-4">
                                    <.link
                                      navigate={~p"/collections/#{@collection.parent.id}"}
                                      class="inline-flex items-center px-4 py-2 border border-blue-600 shadow-sm text-sm font-medium rounded-md text-blue-600 dark:text-blue-400 bg-white dark:bg-gray-800 hover:bg-blue-50 dark:hover:bg-gray-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
                                    >
                                      <.icon name="hero-arrow-right-circle" class="w-4 h-4 mr-2" />
                                      {gettext("View Parent Collection")}
                                    </.link>
                                  </div>
                                </div>
                              </div>
                            </div>
                          </div>
                        <% end %>
                        
    <!-- Children Collections -->
                        <%= if length(@collection.children || []) > 0 do %>
                          <div>
                            <h3 class="text-sm font-semibold text-gray-700 dark:text-gray-300 mb-3 flex items-center gap-2">
                              <.icon name="hero-arrow-down-circle" class="w-5 h-5 text-green-500" />
                              {gettext("Child Collections")} ({length(@collection.children)})
                            </h3>
                            <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
                              <%= for child <- @collection.children do %>
                                <div class="bg-gray-50 dark:bg-gray-700 rounded-lg p-4 flex flex-col">
                                  <!-- A4-sized cover -->
                                  <%= if child.thumbnail do %>
                                    <img
                                      src={child.thumbnail}
                                      alt={child.title}
                                      class="w-full h-80 object-cover rounded-lg border border-gray-200 dark:border-gray-600"
                                    />
                                  <% else %>
                                    <div class="w-full h-80 flex items-center justify-center border rounded-lg border-gray-300 dark:border-gray-500 bg-gray-100 dark:bg-gray-600">
                                      <.icon name="hero-folder" class="w-16 h-16 text-gray-400" />
                                    </div>
                                  <% end %>

                                  <div class="flex-1 flex flex-col mt-3">
                                    <div class="flex-1">
                                      <h4 class="font-semibold text-gray-900 dark:text-white text-sm line-clamp-2">
                                        {child.title}
                                      </h4>
                                      <%= if child.description do %>
                                        <p class="text-xs text-gray-600 dark:text-gray-300 mt-2 line-clamp-2">
                                          {child.description}
                                        </p>
                                      <% end %>
                                      <div class="flex items-center gap-2 mt-2">
                                        <span class="text-xs px-2 py-1 rounded-full bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-200">
                                          {String.capitalize(child.status || "draft")}
                                        </span>
                                      </div>
                                    </div>

                                    <div class="mt-4">
                                      <.link
                                        navigate={~p"/collections/#{child.id}"}
                                        class="inline-flex items-center justify-center w-full px-4 py-2 border border-green-600 shadow-sm text-sm font-medium rounded-md text-green-600 dark:text-green-400 bg-white dark:bg-gray-800 hover:bg-green-50 dark:hover:bg-gray-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-green-500"
                                      >
                                        <.icon name="hero-arrow-right-circle" class="w-4 h-4 mr-2" />
                                        {gettext("View Collection")}
                                      </.link>
                                    </div>
                                  </div>
                                </div>
                              <% end %>
                            </div>
                          </div>
                        <% end %>
                      </div>
                    </div>
                  <% end %>
                  
    <!-- Items Section -->
                  <div class="bg-white dark:bg-gray-800 rounded-lg shadow-sm border border-voile-light dark:border-voile-dark">
                    <div class="px-6 py-4 border-b border-voile-light dark:border-voile-dark">
                      <h2 class="text-lg font-semibold text-gray-900 dark:text-white flex items-center">
                        <.icon name="hero-document-duplicate-solid" class="w-5 h-5 mr-2" />
                        {gettext("Collection Items")}
                        <span class="ml-2 text-sm font-normal text-gray-500 dark:text-gray-400">
                          ({length(@collection.items || [])} {gettext("total")})
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
                          {gettext("Load More Items")}
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
                          {gettext("No items available")}
                        </h3>

                        <p class="mt-1 text-sm text-gray-500 dark:text-gray-400">
                          {gettext("This collection currently has no available items.")}
                        </p>
                      </div>
                    <% end %>
                  </div>
                </div>
                <!-- Sidebar -->
                <div class="mt-8 lg:mt-0 lg:col-span-4">
                  <div class="sticky top-8 space-y-6">
                    <%!-- Catalog Reference --%>
                    <div class="bg-white dark:bg-gray-800 rounded-lg shadow-sm border border-voile-light dark:border-voile-dark p-6">
                      <h3 class="text-lg font-medium text-gray-900 dark:text-white mb-4 flex items-center">
                        <.icon name="hero-identification" class="w-5 h-5 mr-2" />
                        {gettext("Catalog Reference")}
                      </h3>

                      <dl class="space-y-3 text-sm">
                        <%= if @collection.collection_code do %>
                          <div>
                            <dt class="text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wide mb-1">
                              {gettext("Collection Code")}
                            </dt>
                            <dd class="font-mono font-semibold text-gray-900 dark:text-white bg-gray-50 dark:bg-gray-700 px-3 py-1.5 rounded border border-gray-200 dark:border-gray-600 inline-block">
                              {@collection.collection_code}
                            </dd>
                          </div>
                        <% end %>

                        <%= if @collection.resource_class do %>
                          <div>
                            <dt class="text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wide mb-1">
                              {gettext("Resource Type")}
                            </dt>
                            <dd class="text-gray-900 dark:text-white">
                              {@collection.resource_class.label}
                              <%= if @collection.resource_class.glam_type do %>
                                <span class="ml-1 text-xs text-gray-500 dark:text-gray-400">
                                  ({@collection.resource_class.glam_type})
                                </span>
                              <% end %>
                            </dd>
                          </div>
                        <% end %>

                        <%= if @collection.mst_creator do %>
                          <div>
                            <dt class="text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wide mb-1">
                              {gettext("Creator")}
                            </dt>
                            <dd>
                              <.link
                                navigate={~p"/collections?q=#{@collection.mst_creator.creator_name}"}
                                class="text-blue-600 dark:text-blue-400 hover:underline"
                              >
                                {@collection.mst_creator.creator_name}
                              </.link>
                            </dd>
                          </div>
                        <% end %>
                      </dl>
                    </div>
                    <!-- Quick Actions -->
                    <div class="bg-white dark:bg-gray-800 rounded-lg shadow-sm border border-voile-light dark:border-voile-dark p-6">
                      <h3 class="text-lg font-medium text-gray-900 dark:text-white mb-4">
                        {gettext("Quick Actions")}
                      </h3>

                      <div class="space-y-3">
                        <%= if @current_scope && @current_scope.user && @current_scope.user.confirmed_at && assigns[:ebook_id] do %>
                          <.link
                            navigate={~p"/ebooks/view?id=#{@ebook_id}"}
                            class="w-full inline-flex justify-center items-center px-4 py-2 border border-gray-300 dark:border-gray-600 shadow-sm text-sm font-medium rounded-md text-gray-700 dark:text-gray-200 bg-white dark:bg-gray-700 hover:bg-gray-50 dark:hover:bg-gray-600 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
                          >
                            <.icon name="hero-book-open-solid" class="w-4 h-4 mr-2" /> {gettext(
                              "Read E-Book"
                            )}
                          </.link>
                        <% else %>
                          <.button class="disabled-btn w-full" disabled>
                            <.icon name="hero-book-open-solid" class="w-4 h-4 mr-2" /> {gettext(
                              "Read E-Book"
                            )}
                          </.button>
                        <% end %>

                        <.link
                          navigate={~p"/search?q=#{@collection.title}&type=items"}
                          class="w-full inline-flex justify-center items-center px-4 py-2 border border-gray-300 dark:border-gray-600 shadow-sm text-sm font-medium rounded-md text-gray-700 dark:text-gray-200 bg-white dark:bg-gray-700 hover:bg-gray-50 dark:hover:bg-gray-600 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
                        >
                          <.icon name="hero-magnifying-glass-solid" class="w-4 h-4 mr-2" />
                          {gettext("Search in Collection")}
                        </.link>
                        <.link
                          navigate={~p"/collections"}
                          class="w-full inline-flex justify-center items-center px-4 py-2 border border-gray-300 dark:border-gray-600 shadow-sm text-sm font-medium rounded-md text-gray-700 dark:text-gray-200 bg-white dark:bg-gray-700 hover:bg-gray-50 dark:hover:bg-gray-600 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
                        >
                          <.icon name="hero-arrow-left-solid" class="w-4 h-4 mr-2" />
                          {gettext("Browse Collections")}
                        </.link>
                      </div>
                    </div>
                    <!-- Collection Stats -->
                    <div class="bg-white dark:bg-gray-800 rounded-lg shadow-sm border border-voile-light dark:border-voile-dark p-6">
                      <h3 class="text-lg font-medium text-gray-900 dark:text-white mb-4">
                        {gettext("Statistics")}
                      </h3>

                      <div class="space-y-4">
                        <.stat_item
                          icon="document-duplicate"
                          label={gettext("Total Items")}
                          value={length(@collection.items || [])}
                        />
                        <.stat_item
                          icon="check-circle"
                          label={gettext("Available Items")}
                          value={available_items_count(@collection.items || [])}
                        />
                        <.stat_item
                          icon="clock"
                          label={gettext("On Loan")}
                          value={loaned_items_count(@collection.items || [])}
                        />
                      </div>
                    </div>
                    <!-- Related Collections (if any) -->
                    <%= if @collection.mst_creator do %>
                      <div class="bg-white dark:bg-gray-800 rounded-lg shadow-sm border border-voile-light dark:border-voile-dark p-6">
                        <h3 class="text-lg font-medium text-gray-900 dark:text-white mb-4">
                          {gettext("More by this Creator")}
                        </h3>

                        <.link
                          navigate={~p"/collections?q=#{@collection.mst_creator.creator_name}"}
                          class="text-sm text-blue-600 dark:text-blue-400 hover:text-blue-800 dark:hover:text-blue-300"
                        >
                          {gettext("View all collections by")} {@collection.mst_creator.creator_name} →
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
