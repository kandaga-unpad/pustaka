defmodule VoileWeb.Visitor.CheckIn do
  use VoileWeb, :live_view

  alias Voile.Schema.System
  alias Voile.Schema.Master
  alias VoileWeb.Components.VirtualKeyboard

  @impl true
  def mount(_params, _session, socket) do
    nodes = System.list_nodes()

    socket =
      socket
      |> assign(:page_title, "Visitor Check-In")
      |> assign(:step, :select_location)
      |> assign(:nodes, nodes)
      |> assign(:selected_node, nil)
      |> assign(:locations, [])
      |> assign(:selected_location, nil)
      |> assign(:visitor_identifier, "")
      |> assign(:visitor_origin_options, get_origin_options())
      |> assign(:selected_origin, "")
      |> assign(:form, to_form(%{}, as: :visitor))
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
      |> assign(:step, :check_in_form)

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
      |> assign(:visitor_identifier, "")
      |> assign(:selected_origin, "")
      |> assign(:error_message, nil)

    {:noreply, socket}
  end

  @impl true
  def handle_event("back_to_rooms", _params, socket) do
    socket =
      socket
      |> assign(:step, :select_room)
      |> assign(:selected_location, nil)
      |> assign(:visitor_identifier, "")
      |> assign(:selected_origin, "")
      |> assign(:error_message, nil)

    {:noreply, socket}
  end

  @impl true
  def handle_event("keyboard_input", %{"key" => key, "target" => "visitor_identifier"}, socket) do
    current_value = socket.assigns.visitor_identifier
    new_value = current_value <> key

    {:noreply, assign(socket, :visitor_identifier, new_value)}
  end

  @impl true
  def handle_event("keyboard_backspace", %{"target" => "visitor_identifier"}, socket) do
    current_value = socket.assigns.visitor_identifier
    new_value = String.slice(current_value, 0..-2//1)

    {:noreply, assign(socket, :visitor_identifier, new_value)}
  end

  @impl true
  def handle_event("keyboard_clear", %{"target" => "visitor_identifier"}, socket) do
    {:noreply, assign(socket, :visitor_identifier, "")}
  end

  @impl true
  def handle_event("update_identifier", %{"value" => value}, socket) do
    {:noreply, assign(socket, :visitor_identifier, value)}
  end

  @impl true
  def handle_event("select_origin", %{"origin" => origin}, socket) do
    {:noreply, assign(socket, :selected_origin, origin)}
  end

  @impl true
  def handle_event("submit_check_in", _params, socket) do
    %{
      visitor_identifier: identifier,
      selected_origin: origin,
      selected_location: location,
      selected_node: node_id
    } = socket.assigns

    if identifier == "" do
      {:noreply, assign(socket, :error_message, "Please enter your identifier")}
    else
      # Get IP and user agent from socket
      ip_address = get_connect_info(socket, :peer_data) |> get_ip_address()
      user_agent = get_connect_info(socket, :user_agent)

      attrs = %{
        "visitor_identifier" => identifier,
        "visitor_origin" => origin,
        "location_id" => location.id,
        "node_id" => node_id,
        "ip_address" => ip_address,
        "user_agent" => user_agent
      }

      case System.create_visitor_log(attrs) do
        {:ok, _visitor_log} ->
          socket =
            socket
            |> assign(:show_success, true)
            |> assign(:error_message, nil)

          # Auto-reset after 3 seconds
          Process.send_after(self(), :reset_form, 3000)

          {:noreply, socket}

        {:error, _changeset} ->
          {:noreply, assign(socket, :error_message, "Failed to check in. Please try again.")}
      end
    end
  end

  @impl true
  def handle_info(:reset_form, socket) do
    socket =
      socket
      |> assign(:visitor_identifier, "")
      |> assign(:selected_origin, "")
      |> assign(:show_success, false)
      |> assign(:error_message, nil)
      |> assign(:step, :select_room)

    {:noreply, socket}
  end

  defp get_origin_options do
    [
      "Student",
      "Faculty/Staff",
      "Alumni",
      "Public/Guest",
      "Researcher",
      "Other University",
      "Other"
    ]
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
    <div class="min-h-screen bg-gradient-to-br from-blue-50 to-indigo-100 py-8 px-4">
      <div class="max-w-4xl mx-auto">
        <!-- Header -->
        <div class="text-center mb-8">
          <h1 class="text-4xl font-bold text-gray-800 mb-2">Visitor Check-In</h1>
          <p class="text-gray-600">Welcome! Please register your visit</p>
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
                class="p-6 border-2 border-gray-200 rounded-lg hover:border-blue-500 hover:bg-blue-50 transition-all duration-200 text-left"
              >
                <div class="flex items-center space-x-4">
                  <%= if node.image do %>
                    <img src={node.image} alt={node.name} class="w-16 h-16 rounded-lg object-cover" />
                  <% else %>
                    <div class="w-16 h-16 bg-blue-500 rounded-lg flex items-center justify-center">
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
                class="text-blue-600 hover:text-blue-800 flex items-center"
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
                  class="p-6 border-2 border-gray-200 rounded-lg hover:border-blue-500 hover:bg-blue-50 transition-all duration-200"
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

        <%= if @step == :check_in_form do %>
          <!-- Check-in Form -->
          <div class="bg-white rounded-lg shadow-lg p-8">
            <div class="mb-6">
              <button
                type="button"
                phx-click="back_to_rooms"
                class="text-blue-600 hover:text-blue-800 flex items-center"
              >
                <.icon name="hero-arrow-left" class="w-5 h-5 mr-2" /> Back to Rooms
              </button>
            </div>

            <%= if @show_success do %>
              <div class="mb-6 p-4 bg-green-100 border border-green-400 text-green-700 rounded-lg">
                <div class="flex items-center">
                  <.icon name="hero-check-circle" class="w-6 h-6 mr-2" />
                  <span class="font-semibold">Check-in successful! Thank you for visiting.</span>
                </div>
              </div>
            <% else %>
              <h2 class="text-2xl font-semibold text-gray-800 mb-2 text-center">
                {if @selected_location, do: @selected_location.location_name, else: "Check In"}
              </h2>
              <p class="text-gray-600 mb-6 text-center">Please provide your information</p>

              <%= if @error_message do %>
                <div class="mb-4 p-4 bg-red-100 border border-red-400 text-red-700 rounded-lg">
                  {@error_message}
                </div>
              <% end %>

              <form phx-submit="submit_check_in" class="space-y-6">
                <!-- Visitor Identifier Input -->
                <div>
                  <label class="block text-sm font-medium text-gray-700 mb-2">
                    ID / Student Number / Name <span class="text-red-500">*</span>
                  </label>
                  <input
                    type="text"
                    id="visitor_identifier"
                    value={@visitor_identifier}
                    phx-change="update_identifier"
                    class="w-full px-4 py-3 text-lg border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                    placeholder="Enter your identifier"
                    readonly
                  />
                </div>
                
    <!-- Origin Selection -->
                <div>
                  <label class="block text-sm font-medium text-gray-700 mb-2">
                    I am from / Visitor Type
                  </label>
                  <select
                    phx-change="select_origin"
                    class="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                  >
                    <option value="">Select your affiliation</option>
                    <option
                      :for={origin <- @visitor_origin_options}
                      value={origin}
                      selected={@selected_origin == origin}
                    >
                      {origin}
                    </option>
                  </select>
                </div>
                
    <!-- Virtual Keyboard -->
                <div class="mt-6">
                  <VirtualKeyboard.virtual_keyboard target="visitor_identifier" layout="qwerty" />
                </div>
                
    <!-- Submit Button -->
                <div class="pt-4">
                  <button
                    type="submit"
                    class="w-full py-4 px-6 bg-blue-600 hover:bg-blue-700 text-white font-bold text-lg rounded-lg transition-colors shadow-lg"
                  >
                    Check In
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
