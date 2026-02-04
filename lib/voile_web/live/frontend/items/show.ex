defmodule VoileWeb.Frontend.Items.Show do
  @moduledoc """
  Frontend LiveView for displaying individual item details to library members
  """

  use VoileWeb, :live_view
  import VoileWeb.VoileComponents

  alias Voile.Task.Catalog.Items
  alias Voile.Schema.Library.Circulation

  on_mount {VoileWeb.UserAuth, :mount_current_scope}

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:item, nil)
     |> assign(:loading, false)
     |> assign(:related_items, [])
     |> assign(:show_reservation_form, false)
     |> assign(:reservation_loading, false)}
  end

  @impl true
  def handle_params(%{"id" => id}, _uri, socket) do
    socket = assign(socket, :loading, true)
    send(self(), {:load_item, id})
    {:noreply, socket}
  end

  @impl true
  def handle_info({:load_item, id}, socket) do
    case Items.load_item_with_related(id) do
      {:ok, item, related_items} ->
        {:noreply,
         socket
         |> assign(:item, item)
         |> assign(:related_items, related_items)
         |> assign(
           :page_title,
           "Item - #{if item.collection && item.collection.title, do: item.collection.title, else: ""}"
         )
         |> assign(:loading, false)}

      {:error, :not_found} ->
        {:noreply,
         socket
         |> put_flash(:error, "Item not found")
         |> push_navigate(to: ~p"/items")}

      {:error, :access_denied} ->
        {:noreply,
         socket
         |> put_flash(:error, "You don't have permission to view this item")
         |> push_navigate(to: ~p"/items")}
    end
  end

  @impl true
  def handle_event("show_reservation_form", _params, socket) do
    {:noreply, assign(socket, :show_reservation_form, true)}
  end

  @impl true
  def handle_event("hide_reservation_form", _params, socket) do
    {:noreply, assign(socket, :show_reservation_form, false)}
  end

  @impl true
  def handle_event("submit_reservation", %{"notes" => notes}, socket) do
    current_user = socket.assigns.current_scope && socket.assigns.current_scope.user
    item = socket.assigns.item

    case validate_reservation_request(current_user, item) do
      {:ok, :valid} ->
        socket = assign(socket, :reservation_loading, true)

        reservation_attrs = %{
          notes: String.trim(notes)
        }

        case Circulation.create_reservation(current_user.id, item.id, reservation_attrs) do
          {:ok, _reservation} ->
            {:noreply,
             socket
             |> assign(:show_reservation_form, false)
             |> assign(:reservation_loading, false)
             |> put_flash(
               :info,
               "Reservation request submitted successfully. The library will contact you soon."
             )}

          {:error, reason} when is_binary(reason) ->
            {:noreply,
             socket
             |> assign(:reservation_loading, false)
             |> put_flash(:error, "Failed to create reservation: #{reason}")}

          {:error, %Ecto.Changeset{} = changeset} ->
            errors =
              changeset.errors
              |> Enum.map(fn {field, {message, _}} -> "#{field} #{message}" end)
              |> Enum.join(", ")

            {:noreply,
             socket
             |> assign(:reservation_loading, false)
             |> put_flash(:error, "Failed to create reservation: #{errors}")}

          {:error, _} ->
            {:noreply,
             socket
             |> assign(:reservation_loading, false)
             |> put_flash(:error, "Failed to create reservation. Please try again later.")}
        end

      {:error, reason} ->
        {:noreply,
         socket
         |> put_flash(:error, reason)
         |> assign(:show_reservation_form, false)}
    end
  end

  # Handle form submission without notes parameter (fallback)
  @impl true
  def handle_event("submit_reservation", _params, socket) do
    handle_event("submit_reservation", %{"notes" => ""}, socket)
  end

  # Private helper function to validate reservation eligibility
  defp validate_reservation_request(nil, _item) do
    {:error, "You must be logged in to make a reservation."}
  end

  defp validate_reservation_request(%{confirmed_at: nil}, _item) do
    {:error, "Please verify your email address before making reservations."}
  end

  defp validate_reservation_request(%{user_type: nil}, _item) do
    {:error, "Your account doesn't have a member type assigned. Please contact the library."}
  end

  defp validate_reservation_request(_user, %{availability: availability})
       when availability != "available" do
    case availability do
      "loaned" -> {:error, "This item is currently on loan."}
      "reserved" -> {:error, "This item is already reserved by another member."}
      "maintenance" -> {:error, "This item is currently under maintenance."}
      _ -> {:error, "This item is not available for reservation."}
    end
  end

  defp validate_reservation_request(_user, _item) do
    {:ok, :valid}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="min-h-screen">
        <%= if @loading do %>
          <div class="flex justify-center items-center py-12">
            <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-voile-primary"></div>
            <span class="ml-2 text-gray-600 dark:text-gray-300">Loading item...</span>
          </div>
        <% else %>
          <%= if @item do %>
            <!-- Header -->
            <div class="shadow-sm">
              <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-6">
                <div class="flex items-center gap-4">
                  <.link
                    navigate={~p"/items"}
                    class="inline-flex items-center text-sm font-medium text-gray-500 dark:text-gray-400 hover:text-gray-700 dark:hover:text-gray-200"
                  >
                    <.icon name="hero-chevron-left-solid" class="w-4 h-4 mr-1" /> Back to Items
                  </.link>
                  <span class="text-gray-300 dark:text-gray-600">|</span>
                  <.link
                    navigate={~p"/collections/#{@item.collection.id}"}
                    class="inline-flex items-center text-sm font-medium text-gray-500 dark:text-gray-400 hover:text-gray-700 dark:hover:text-gray-200"
                  >
                    View Collection
                  </.link>
                </div>
              </div>
            </div>
            <!-- Item Details -->
            <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
              <div class="lg:grid lg:grid-cols-12 lg:gap-8">
                <!-- Main Content -->
                <div class="lg:col-span-8">
                  <!-- Item Header -->
                  <div class="bg-white dark:bg-gray-800 rounded-lg shadow-sm border border-voile-light dark:border-voile-dark p-6 mb-6">
                    <div class="flex flex-col">
                      <!-- Item Visual -->
                      <div class="w-full flex flex-col sm:flex-row gap-6">
                        <div class="w-full h-72 sm:w-128 bg-gradient-to-br from-voile-info to-voile-primary dark:from-voile-primary dark:to-voile-dark rounded-lg flex items-center justify-center">
                          <div class="text-center">
                            <.icon
                              name="hero-document-solid"
                              class="w-16 h-16 mx-auto text-white mb-2"
                            />
                            <div class="text-sm font-medium text-white p-3">{@item.item_code}</div>
                          </div>
                        </div>

                        <div class="flex items-start justify-between">
                          <div class="flex-1">
                            <h1 class="text-2xl sm:text-3xl font-bold mb-2">{@item.item_code}</h1>

                            <div class="text-lg mb-4">
                              From:
                              <.link
                                navigate={
                                  if @item.collection,
                                    do: ~p"/collections/#{@item.collection.id}",
                                    else: "#"
                                }
                                class="text-voile-primary dark:text-voile-primary font-medium"
                              >
                                {if @item.collection && @item.collection.title,
                                  do: @item.collection.title,
                                  else: ""}
                              </.link>
                            </div>

                            <%= if @item.collection && @item.collection.mst_creator do %>
                              <div class="mb-6">By: {@item.collection.mst_creator.creator_name}</div>
                            <% end %>
                          </div>
                          <!-- Status Badges -->
                          <div class="flex flex-col gap-2 items-end">
                            <span class={"px-3 py-1 text-sm rounded-full #{VoileWeb.VoileComponents.availability_badge(@item.availability)}"}>
                              {String.capitalize(@item.availability || "Unknown")}
                            </span>
                            <span class={"px-3 py-1 text-sm rounded-full #{VoileWeb.VoileComponents.condition_badge(@item.condition)}"}>
                              {String.capitalize(@item.condition || "Unknown")} condition
                            </span>
                          </div>
                        </div>
                      </div>
                      <!-- Details -->
                      <div class="flex-1 min-w-0">
                        <!-- Item Metadata Grid -->
                        <div class="grid grid-cols-1 sm:grid-cols-2 gap-4 text-xs mt-6">
                          <div class="flex items-center justify-center">
                            <div class="flex items-center">
                              <.icon
                                name="hero-hashtag-solid"
                                class="w-6 h-6 mr-2 text-gray-400 dark:text-gray-500"
                              />
                            </div>

                            <div class="flex flex-col">
                              <span class="text-gray-500 dark:text-gray-400 mr-2">Item Code:</span>
                              <span class="font-medium text-gray-900 dark:text-white">
                                {@item.item_code}
                              </span>
                            </div>
                          </div>

                          <%= if @item.inventory_code do %>
                            <div class="flex items-center">
                              <div class="flex items-center">
                                <.icon
                                  name="hero-identification-solid"
                                  class="w-6 h-6 mr-2 text-gray-400 dark:text-gray-500"
                                />
                              </div>

                              <div class="flex flex-col">
                                <span class="text-gray-500 dark:text-gray-400 mr-2">
                                  Inventory Code:
                                </span>
                                <span class="font-medium text-gray-900 dark:text-white">
                                  {@item.inventory_code}
                                </span>
                              </div>
                            </div>
                          <% end %>

                          <div class="flex items-center">
                            <div class="flex items-center">
                              <.icon
                                name="hero-map-pin-solid"
                                class="w-6 h-6 mr-2 text-gray-400 dark:text-gray-500"
                              />
                            </div>

                            <div class="flex flex-col">
                              <span class="text-gray-500 dark:text-gray-400 mr-2">Location:</span>
                              <span class="font-medium text-gray-900 dark:text-white">
                                {@item.location}
                              </span>
                            </div>
                          </div>

                          <%= if @item.node do %>
                            <div class="flex items-center">
                              <div class="flex items-center">
                                <.icon
                                  name="hero-building-library-solid"
                                  class="w-6 h-6 mr-2 text-gray-400 dark:text-gray-500"
                                />
                              </div>

                              <div class="flex flex-col">
                                <span class="text-gray-500 dark:text-gray-400 mr-2">Library:</span>
                                <span class="font-medium text-gray-900 dark:text-white">
                                  {@item.node.name}
                                </span>
                              </div>
                            </div>
                          <% end %>

                          <%= if @item.price do %>
                            <div class="flex items-center">
                              <div class="flex items-center">
                                <.icon
                                  name="hero-currency-dollar-solid"
                                  class="w-6 h-6 mr-2 text-gray-400 dark:text-gray-500"
                                />
                              </div>
                              <span class="text-gray-500 dark:text-gray-400 mr-2">Price:</span>
                              <div class="flex flex-col">
                                <span class="font-medium text-gray-900 dark:text-white">
                                  ${@item.price}
                                </span>
                              </div>
                            </div>
                          <% end %>

                          <%= if @item.acquisition_date do %>
                            <div class="flex items-center">
                              <div class="flex items-center">
                                <.icon
                                  name="hero-calendar-days-solid"
                                  class="w-6 h-6 mr-2 text-gray-400 dark:text-gray-500"
                                />
                              </div>

                              <div class="flex flex-col">
                                <span class="text-gray-500 dark:text-gray-400 mr-2">Acquired:</span>
                                <span class="font-medium text-gray-900 dark:text-white">
                                  {Calendar.strftime(@item.acquisition_date, "%B %d, %Y")}
                                </span>
                              </div>
                            </div>
                          <% end %>

                          <%= if @item.last_circulated do %>
                            <div class="flex items-center">
                              <div class="flex items-center">
                                <.icon
                                  name="hero-arrow-path-solid"
                                  class="w-6 h-6 mr-2 text-gray-400 dark:text-gray-500"
                                />
                              </div>

                              <div class="flex flex-col">
                                <span class="text-gray-500 dark:text-gray-400 mr-2">
                                  Last Circulated:
                                </span>
                                <span class="font-medium text-gray-900 dark:text-white">
                                  {Calendar.strftime(@item.last_circulated, "%B %d, %Y")}
                                </span>
                              </div>
                            </div>
                          <% end %>

                          <div class="flex items-center">
                            <div class="flex items-center">
                              <.icon
                                name="hero-calendar-solid"
                                class="w-6 h-6 mr-2 text-gray-400 dark:text-gray-500"
                              />
                            </div>

                            <div class="flex flex-col">
                              <span class="text-gray-500 dark:text-gray-400 mr-2">Added:</span>
                              <span class="font-medium text-gray-900 dark:text-white">
                                {Calendar.strftime(@item.inserted_at, "%B %d, %Y")}
                              </span>
                            </div>
                          </div>
                        </div>
                      </div>
                    </div>
                  </div>
                  <!-- Collection Details -->
                  <%= if @item.collection.description do %>
                    <div class="bg-white dark:bg-gray-800 rounded-lg shadow-sm border border-voile-light dark:border-voile-dark p-6 mb-6">
                      <h3 class="text-lg font-medium text-gray-900 dark:text-white mb-4">
                        About this Collection
                      </h3>

                      <p class="text-gray-600 dark:text-gray-300 leading-relaxed">
                        {@item.collection.description}
                      </p>
                    </div>
                  <% end %>
                  <!-- Related Items -->
                  <%= if length(@related_items) > 0 do %>
                    <div class="bg-white dark:bg-gray-800 rounded-lg shadow-sm border border-voile-light dark:border-voile-dark">
                      <div class="px-6 py-4 border-b border-voile-light dark:border-voile-dark">
                        <h3 class="text-lg font-medium text-gray-900 dark:text-white">
                          Other Items in this Collection
                        </h3>
                      </div>

                      <div class="divide-y divide-voile-light dark:divide-voile-dark">
                        <%= for item <- @related_items do %>
                          <div class="p-6 hover:bg-gray-50 dark:hover:bg-gray-700">
                            <.related_item_card item={item} />
                          </div>
                        <% end %>
                      </div>

                      <div class="px-6 py-4 border-t border-voile-light dark:border-voile-dark text-center">
                        <.link
                          navigate={~p"/collections/#{@item.collection.id}"}
                          class="text-sm font-medium text-blue-600 dark:text-blue-400 hover:text-blue-800 dark:hover:text-blue-300"
                        >
                          View all items in this collection →
                        </.link>
                      </div>
                    </div>
                  <% end %>
                </div>
                <!-- Sidebar -->
                <div class="mt-8 lg:mt-0 lg:col-span-4">
                  <div class="sticky top-8 space-y-6">
                    <!-- Actions -->
                    <div class="bg-white dark:bg-gray-800 rounded-lg shadow-sm border border-voile-light dark:border-voile-dark p-6">
                      <h3 class="text-lg font-medium text-gray-900 dark:text-white mb-4">Actions</h3>

                      <div class="space-y-3">
                        <%= if @item.availability == "available" do %>
                          <%= if @current_scope && @current_scope.user do %>
                            <%= if @current_scope.user.confirmed_at && @current_scope.user.user_type do %>
                              <button
                                phx-click="show_reservation_form"
                                class="w-full inline-flex justify-center items-center px-4 py-2 border border-transparent shadow-sm text-sm font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
                              >
                                <.icon name="hero-bookmark-solid" class="w-4 h-4 mr-2" /> Reserve Item
                              </button>
                            <% else %>
                              <div class="w-full px-4 py-2 border border-voile-muted dark:border-voile-dark text-center text-sm font-medium rounded-md text-gray-500 dark:text-gray-400 bg-gray-100 dark:bg-gray-700 cursor-not-allowed">
                                <%= cond do %>
                                  <% !@current_scope.user.confirmed_at -> %>
                                    Please verify your email to reserve items
                                  <% !@current_scope.user.user_type -> %>
                                    Member type not assigned - contact library
                                  <% true -> %>
                                    Reservation unavailable
                                <% end %>
                              </div>
                            <% end %>
                          <% else %>
                            <.link
                              navigate={~p"/login"}
                              class="w-full inline-flex justify-center items-center px-4 py-2 border border-transparent shadow-sm text-sm font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
                            >
                              <.icon name="hero-user-solid" class="w-4 h-4 mr-2" /> Login to Reserve
                            </.link>
                          <% end %>
                        <% else %>
                          <div class="w-full px-4 py-2 border border-voile-muted dark:border-voile-dark text-center text-sm font-medium rounded-md text-gray-500 dark:text-gray-400 bg-gray-100 dark:bg-gray-700 cursor-not-allowed">
                            <%= case @item.availability do %>
                              <% "loaned" -> %>
                                Currently on Loan
                              <% "reserved" -> %>
                                Already Reserved
                              <% "maintenance" -> %>
                                Under Maintenance
                              <% _ -> %>
                                Not Available
                            <% end %>
                          </div>
                        <% end %>

                        <.link
                          navigate={~p"/collections/#{@item.collection.id}"}
                          class="w-full inline-flex justify-center items-center px-4 py-2 border border-voile-muted dark:border-voile-dark shadow-sm text-sm font-medium rounded-md text-gray-700 dark:text-gray-200 bg-white dark:bg-gray-700 hover:bg-gray-50 dark:hover:bg-gray-600 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
                        >
                          <.icon name="hero-rectangle-stack-solid" class="w-4 h-4 mr-2" />
                          View Collection
                        </.link>
                        <.link
                          navigate={~p"/search?q=#{@item.collection.title}"}
                          class="w-full inline-flex justify-center items-center px-4 py-2 border border-voile-muted dark:border-voile-dark shadow-sm text-sm font-medium rounded-md text-gray-700 dark:text-gray-200 bg-white dark:bg-gray-700 hover:bg-gray-50 dark:hover:bg-gray-600 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
                        >
                          <.icon name="hero-magnifying-glass-solid" class="w-4 h-4 mr-2" />
                          Find Similar
                        </.link>
                      </div>
                    </div>
                    <!-- Item Status Details -->
                    <div class="bg-white dark:bg-gray-800 rounded-lg shadow-sm border border-voile-light dark:border-voile-dark p-6">
                      <h3 class="text-lg font-medium text-gray-900 dark:text-white mb-4">
                        Item Status
                      </h3>

                      <div class="space-y-4">
                        <div class="flex items-center justify-between">
                          <span class="text-sm text-gray-500 dark:text-gray-400">Availability:</span>
                          <span class={"px-2 py-1 text-xs rounded-full #{VoileWeb.VoileComponents.availability_badge(@item.availability)}"}>
                            {String.capitalize(@item.availability || "Unknown")}
                          </span>
                        </div>

                        <div class="flex items-center justify-between">
                          <span class="text-sm text-gray-500 dark:text-gray-400">Condition:</span>
                          <span class={"px-2 py-1 text-xs rounded-full #{VoileWeb.VoileComponents.condition_badge(@item.condition)}"}>
                            {String.capitalize(@item.condition || "Unknown")}
                          </span>
                        </div>

                        <div class="flex items-center justify-between">
                          <span class="text-sm text-gray-500 dark:text-gray-400">Status:</span>
                          <span class="text-sm font-medium text-gray-900 dark:text-white">
                            {String.capitalize(@item.status || "Unknown")}
                          </span>
                        </div>
                      </div>
                    </div>
                    <!-- Contact Info -->
                    <div class="bg-white dark:bg-gray-800 rounded-lg shadow-sm border border-voile-light dark:border-voile-dark p-6">
                      <h3 class="text-lg font-medium text-gray-900 dark:text-white mb-4">
                        Need Help?
                      </h3>

                      <p class="text-sm text-gray-600 dark:text-gray-300 mb-4">
                        Contact the library for more information about this item or to make special requests.
                      </p>

                      <div class="space-y-2 text-sm">
                        <div class="flex items-center">
                          <.icon
                            name="hero-phone-solid"
                            class="w-4 h-4 mr-2 text-gray-400 dark:text-gray-500"
                          /> <span class="text-gray-900 dark:text-white">(+62) 815-7371-0645</span>
                        </div>

                        <div class="flex items-center">
                          <.icon
                            name="hero-envelope-solid"
                            class="w-4 h-4 mr-2 text-gray-400 dark:text-gray-500"
                          />
                          <span class="text-gray-900 dark:text-white">perpustakaan@unpad.ac.id</span>
                        </div>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            </div>
            <!-- Reservation Form Modal -->
            <%= if @show_reservation_form do %>
              <div class="fixed inset-0 bg-gray-600/85 bg-opacity-50 flex items-center justify-center p-4 z-50">
                <div class="bg-white dark:bg-gray-800 rounded-lg shadow-xl max-w-md w-full p-6">
                  <div class="flex items-center justify-between mb-4">
                    <h3 class="text-lg font-medium text-gray-900 dark:text-white">Reserve Item</h3>

                    <button
                      phx-click="hide_reservation_form"
                      class="text-gray-400 dark:text-gray-500 hover:text-gray-600 dark:hover:text-gray-300"
                    >
                      <.icon name="hero-x-mark-solid" class="w-5 h-5" />
                    </button>
                  </div>

                  <p class="text-sm text-gray-600 dark:text-gray-300 mb-4">
                    You are requesting to reserve: <strong>{@item.item_code}</strong>
                  </p>

                  <form phx-submit="submit_reservation" class="space-y-4">
                    <div>
                      <label
                        for="reservation_notes"
                        class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1"
                      >
                        Notes (optional)
                      </label>
                      <textarea
                        id="reservation_notes"
                        name="notes"
                        rows="3"
                        class="block w-full border border-voile-muted dark:border-voile-dark rounded-md shadow-sm bg-white dark:bg-gray-700 text-gray-900 dark:text-white focus:ring-blue-500 focus:border-blue-500"
                        placeholder="Any special requests or notes..."
                        disabled={@reservation_loading}
                      ></textarea>
                    </div>

                    <div class="flex justify-end gap-3">
                      <button
                        type="button"
                        phx-click="hide_reservation_form"
                        class="px-4 py-2 text-sm font-medium text-gray-700 dark:text-gray-200 bg_gray-100 dark:bg-gray-600 border border-voile-muted dark:border-voile-dark rounded-md hover:bg-gray-200 dark:hover:bg-gray-500 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
                        disabled={@reservation_loading}
                      >
                        Cancel
                      </button>
                      <button
                        type="submit"
                        class="px-4 py-2 text-sm font-medium text-white bg-blue-600 border border-transparent rounded-md hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500 disabled:opacity-50 disabled:cursor-not-allowed"
                        disabled={@reservation_loading}
                      >
                        <%= if @reservation_loading do %>
                          <.icon name="hero-arrow-path" class="w-4 h-4 mr-2 animate-spin" />
                          Submitting...
                        <% else %>
                          Submit Reservation
                        <% end %>
                      </button>
                    </div>
                  </form>
                </div>
              </div>
            <% end %>
          <% end %>
        <% end %>
      </div>
    </Layouts.app>
    """
  end
end
