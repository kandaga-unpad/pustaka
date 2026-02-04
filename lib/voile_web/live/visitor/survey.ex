defmodule VoileWeb.Visitor.Survey do
  use VoileWeb, :live_view

  alias Voile.Schema.System
  alias Voile.Schema.Master

  @impl true
  def mount(_params, _session, socket) do
    nodes = System.list_nodes()

    socket =
      socket
      |> assign(:page_title, "Visitor Survey")
      |> assign(:step, :select_location)
      |> assign(:nodes, nodes)
      |> assign(:selected_node, nil)
      |> assign(:locations, [])
      |> assign(:selected_location, nil)
      |> assign(:rating, 0)
      |> assign(:comment, "")
      |> assign(:show_success, false)
      |> assign(:error_message, nil)

    {:ok, socket}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("select_node", %{"node_id" => node_id}, socket) do
    node_id = String.to_integer(node_id)
    locations = Master.list_locations(node_id: node_id, is_active: true)

    socket =
      socket
      |> assign(:selected_node, node_id)
      |> assign(:locations, locations)
      |> assign(:selected_location, nil)
      |> assign(:step, :select_room)

    {:noreply, socket}
  end

  @impl true
  def handle_event("select_room", %{"location_id" => location_id}, socket) do
    location_id = String.to_integer(location_id)
    location = Enum.find(socket.assigns.locations, &(&1.id == location_id))

    socket =
      socket
      |> assign(:selected_location, location)
      |> assign(:step, :survey_form)

    {:noreply, socket}
  end

  @impl true
  def handle_event("back_to_nodes", _params, socket) do
    socket =
      socket
      |> assign(:step, :select_location)
      |> assign(:selected_node, nil)
      |> assign(:locations, [])
      |> assign(:selected_location, nil)
      |> assign(:rating, 0)
      |> assign(:comment, "")
      |> assign(:error_message, nil)

    {:noreply, socket}
  end

  @impl true
  def handle_event("back_to_rooms", _params, socket) do
    socket =
      socket
      |> assign(:step, :select_room)
      |> assign(:selected_location, nil)
      |> assign(:rating, 0)
      |> assign(:comment, "")
      |> assign(:error_message, nil)

    {:noreply, socket}
  end

  @impl true
  def handle_event("set_rating", %{"rating" => rating}, socket) do
    rating = String.to_integer(rating)
    {:noreply, assign(socket, :rating, rating)}
  end

  @impl true
  def handle_event("update_comment", %{"value" => comment}, socket) do
    {:noreply, assign(socket, :comment, comment)}
  end

  @impl true
  def handle_event("submit_survey", _params, socket) do
    %{
      rating: rating,
      comment: comment,
      selected_location: location,
      selected_node: node_id
    } = socket.assigns

    if rating == 0 do
      {:noreply, assign(socket, :error_message, "Please select a rating")}
    else
      # Get IP and user agent from socket
      ip_address = get_connect_info(socket, :peer_data) |> get_ip_address()
      user_agent = get_connect_info(socket, :user_agent)

      attrs = %{
        "rating" => rating,
        "comment" => if(comment == "", do: nil, else: comment),
        "location_id" => location.id,
        "node_id" => node_id,
        "ip_address" => ip_address,
        "user_agent" => user_agent,
        "survey_type" => "general"
      }

      case System.create_visitor_survey(attrs) do
        {:ok, _survey} ->
          socket =
            socket
            |> assign(:show_success, true)
            |> assign(:error_message, nil)

          # Auto-reset after 3 seconds
          Process.send_after(self(), :reset_form, 3000)

          {:noreply, socket}

        {:error, _changeset} ->
          {:noreply, assign(socket, :error_message, "Failed to submit survey. Please try again.")}
      end
    end
  end

  @impl true
  def handle_info(:reset_form, socket) do
    socket =
      socket
      |> assign(:rating, 0)
      |> assign(:comment, "")
      |> assign(:show_success, false)
      |> assign(:error_message, nil)
      |> assign(:step, :select_room)

    {:noreply, socket}
  end

  defp get_ip_address(nil), do: nil

  defp get_ip_address(%{address: address}) when is_tuple(address) do
    address
    |> Tuple.to_list()
    |> Enum.join(".")
  end

  defp get_ip_address(_), do: nil

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gradient-to-br from-purple-50 to-pink-100 py-8 px-4">
      <div class="max-w-4xl mx-auto">
        <!-- Header -->
        <div class="text-center mb-8">
          <h1 class="text-4xl font-bold text-gray-800 mb-2">Visitor Survey</h1>
          <p class="text-gray-600">We value your feedback!</p>
        </div>

        <%= if @step == :select_location do %>
          <!-- Node Selection -->
          <div class="bg-white rounded-lg shadow-lg p-8">
            <h2 class="text-2xl font-semibold text-gray-800 mb-6 text-center">
              Select Your Location
            </h2>
            <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
              <button
                :for={node <- @nodes}
                type="button"
                phx-click="select_node"
                phx-value-node_id={node.id}
                class="p-6 border-2 border-gray-200 rounded-lg hover:border-purple-500 hover:bg-purple-50 transition-all duration-200 text-left"
              >
                <div class="flex items-center space-x-4">
                  <%= if node.image do %>
                    <img src={node.image} alt={node.name} class="w-16 h-16 rounded-lg object-cover" />
                  <% else %>
                    <div class="w-16 h-16 bg-purple-500 rounded-lg flex items-center justify-center">
                      <span class="text-white text-2xl font-bold">{String.first(node.name)}</span>
                    </div>
                  <% end %>
                  <div>
                    <h3 class="text-lg font-semibold text-gray-800">{node.name}</h3>
                    <%= if node.description do %>
                      <p class="text-sm text-gray-600">{node.description}</p>
                    <% end %>
                  </div>
                </div>
              </button>
            </div>
          </div>
        <% end %>

        <%= if @step == :select_room do %>
          <!-- Room Selection -->
          <div class="bg-white rounded-lg shadow-lg p-8">
            <div class="mb-6">
              <button
                type="button"
                phx-click="back_to_nodes"
                class="text-purple-600 hover:text-purple-800 flex items-center"
              >
                <.icon name="hero-arrow-left" class="w-5 h-5 mr-2" /> Back to Locations
              </button>
            </div>

            <h2 class="text-2xl font-semibold text-gray-800 mb-6 text-center">Select Room</h2>

            <%= if @locations == [] do %>
              <div class="text-center py-8">
                <p class="text-gray-600">No rooms available at this location.</p>
              </div>
            <% else %>
              <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
                <button
                  :for={location <- @locations}
                  type="button"
                  phx-click="select_room"
                  phx-value-location_id={location.id}
                  class="p-6 border-2 border-gray-200 rounded-lg hover:border-purple-500 hover:bg-purple-50 transition-all duration-200"
                >
                  <h3 class="text-lg font-semibold text-gray-800 mb-2">{location.location_name}</h3>
                  <%= if location.description do %>
                    <p class="text-sm text-gray-600">{location.description}</p>
                  <% end %>
                </button>
              </div>
            <% end %>
          </div>
        <% end %>

        <%= if @step == :survey_form do %>
          <!-- Survey Form -->
          <div class="bg-white rounded-lg shadow-lg p-8">
            <div class="mb-6">
              <button
                type="button"
                phx-click="back_to_rooms"
                class="text-purple-600 hover:text-purple-800 flex items-center"
              >
                <.icon name="hero-arrow-left" class="w-5 h-5 mr-2" /> Back to Rooms
              </button>
            </div>

            <%= if @show_success do %>
              <div class="mb-6 p-4 bg-green-100 border border-green-400 text-green-700 rounded-lg">
                <div class="flex items-center">
                  <.icon name="hero-check-circle" class="w-6 h-6 mr-2" />
                  <span class="font-semibold">Thank you for your feedback!</span>
                </div>
              </div>
            <% else %>
              <h2 class="text-2xl font-semibold text-gray-800 mb-2 text-center">
                {if @selected_location, do: @selected_location.location_name, else: "Survey"}
              </h2>
              <p class="text-gray-600 mb-6 text-center">Please rate your experience</p>

              <%= if @error_message do %>
                <div class="mb-4 p-4 bg-red-100 border border-red-400 text-red-700 rounded-lg">
                  {@error_message}
                </div>
              <% end %>

              <form phx-submit="submit_survey" class="space-y-6">
                <!-- Star Rating -->
                <div>
                  <label class="block text-sm font-medium text-gray-700 mb-3 text-center">
                    How would you rate your experience? <span class="text-red-500">*</span>
                  </label>
                  <div class="flex justify-center space-x-2">
                    <%= for star <- 1..5 do %>
                      <button
                        type="button"
                        phx-click="set_rating"
                        phx-value-rating={star}
                        class="focus:outline-none transition-transform hover:scale-110"
                      >
                        <%= if star <= @rating do %>
                          <svg
                            class="w-16 h-16 text-yellow-400 fill-current"
                            xmlns="http://www.w3.org/2000/svg"
                            viewBox="0 0 24 24"
                          >
                            <path d="M12 2l3.09 6.26L22 9.27l-5 4.87 1.18 6.88L12 17.77l-6.18 3.25L7 14.14 2 9.27l6.91-1.01L12 2z" />
                          </svg>
                        <% else %>
                          <svg
                            class="w-16 h-16 text-gray-300 fill-current"
                            xmlns="http://www.w3.org/2000/svg"
                            viewBox="0 0 24 24"
                          >
                            <path d="M12 2l3.09 6.26L22 9.27l-5 4.87 1.18 6.88L12 17.77l-6.18 3.25L7 14.14 2 9.27l6.91-1.01L12 2z" />
                          </svg>
                        <% end %>
                      </button>
                    <% end %>
                  </div>
                  <%= if @rating > 0 do %>
                    <p class="text-center text-sm text-gray-600 mt-2">
                      You rated: {@rating} {if @rating == 1, do: "star", else: "stars"}
                    </p>
                  <% end %>
                </div>
                
    <!-- Comment/Suggestion (Optional) -->
                <div>
                  <label class="block text-sm font-medium text-gray-700 mb-2">
                    Comments or Suggestions (Optional)
                  </label>
                  <textarea
                    phx-change="update_comment"
                    rows="4"
                    class="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-purple-500 focus:border-purple-500"
                    placeholder="Share your thoughts, suggestions, or feedback..."
                  >{@comment}</textarea>
                  <p class="text-sm text-gray-500 mt-1">
                    {String.length(@comment)}/2000 characters
                  </p>
                </div>
                
    <!-- Submit Button -->
                <div class="pt-4">
                  <button
                    type="submit"
                    class="w-full py-4 px-6 bg-purple-600 hover:bg-purple-700 text-white font-bold text-lg rounded-lg transition-colors shadow-lg"
                  >
                    Submit Survey
                  </button>
                </div>
              </form>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>
    """
  end
end
