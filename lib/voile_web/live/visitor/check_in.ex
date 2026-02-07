defmodule VoileWeb.Visitor.CheckIn do
  use VoileWeb, :live_view

  alias Voile.Schema.System
  alias Voile.Schema.Master
  alias VoileWeb.Components.VirtualKeyboard

  @impl true
  def mount(_params, _session, socket) do
    nodes = System.list_nodes()

    # Get IP and user agent during mount
    ip_address = get_connect_info(socket, :peer_data) |> get_ip_address()
    user_agent = get_connect_info(socket, :user_agent)

    socket =
      socket
      |> assign(:page_title, "Visitor Check-In & Survey")
      |> assign(:step, :select_location)
      |> assign(:nodes, nodes)
      |> assign(:selected_node, nil)
      |> assign(:locations, [])
      |> assign(:selected_location, nil)
      |> assign(:visitor_identifier, "")
      |> assign(:visitor_name, nil)
      |> assign(:visitor_origin_options, get_origin_options())
      |> assign(:selected_origin, "")
      |> assign(:form, to_form(%{}, as: :visitor))
      |> assign(:show_success_modal, false)
      |> assign(:error_message, nil)
      |> assign(:ip_address, ip_address)
      |> assign(:user_agent, user_agent)
      |> assign(:rating, 0)
      |> assign(:comment, "")
      |> assign(:show_survey_success, false)
      |> assign(:survey_error_message, nil)
      |> assign(:keyboard_shift_active, false)

    {:ok, socket}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event(
        "restore_from_storage",
        %{"node_id" => node_id, "location_id" => location_id},
        socket
      ) do
    with {node_id, ""} <- Integer.parse(node_id),
         {location_id, ""} <- Integer.parse(location_id),
         locations <- Master.list_locations(node_id: node_id, is_active: true),
         location when not is_nil(location) <- Enum.find(locations, &(&1.id == location_id)) do
      socket =
        socket
        |> assign(:selected_node, node_id)
        |> assign(:locations, locations)
        |> assign(:selected_location, location)
        |> assign(:step, :show_forms)

      {:noreply, socket}
    else
      _ -> {:noreply, socket}
    end
  end

  def handle_event("restore_from_storage", _params, socket) do
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
      |> assign(:step, :show_forms)

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

    {:noreply, push_event(socket, "clear_location_storage", %{})}
  end

  @impl true
  def handle_event("change_location", _params, socket) do
    socket =
      socket
      |> assign(:step, :select_location)
      |> assign(:selected_node, nil)
      |> assign(:locations, [])
      |> assign(:selected_location, nil)
      |> assign(:visitor_identifier, "")
      |> assign(:selected_origin, "")
      |> assign(:error_message, nil)

    {:noreply, push_event(socket, "clear_check_in_storage", %{})}
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
  def handle_event("keyboard_toggle_shift", _params, socket) do
    {:noreply, assign(socket, :keyboard_shift_active, !socket.assigns.keyboard_shift_active)}
  end

  @impl true
  def handle_event("select_origin", %{"origin" => origin}, socket) do
    {:noreply, assign(socket, :selected_origin, origin)}
  end

  @impl true
  def handle_event("submit_check_in", %{"identifier" => identifier} = _params, socket) do
    %{
      selected_origin: origin,
      selected_location: location,
      selected_node: node_id,
      ip_address: ip_address,
      user_agent: user_agent
    } = socket.assigns

    identifier = String.trim(identifier)

    if identifier == "" do
      {:noreply, assign(socket, :error_message, "Please enter your identifier")}
    else
      # Try to find user by identifier to get their full name
      alias Voile.Schema.Accounts

      visitor_name =
        case Accounts.get_user_by_identifier(identifier) do
          nil -> identifier
          user -> user.fullname || identifier
        end

      attrs = %{
        "visitor_identifier" => identifier,
        "visitor_name" => visitor_name,
        "visitor_origin" => origin,
        "location_id" => location.id,
        "node_id" => node_id,
        "ip_address" => ip_address,
        "user_agent" => user_agent
      }

      case System.create_visitor_log(attrs) do
        {:ok, visitor_log} ->
          socket =
            socket
            |> assign(:show_success_modal, true)
            |> assign(:visitor_name, visitor_log.visitor_name || identifier)
            |> assign(:visitor_identifier, "")
            |> assign(:error_message, nil)

          # Auto-close modal after 4 seconds
          Process.send_after(self(), :close_modal, 4000)

          {:noreply, socket}

        {:error, _changeset} ->
          {:noreply, assign(socket, :error_message, "Failed to check in. Please try again.")}
      end
    end
  end

  @impl true
  def handle_event("set_rating", %{"rating" => rating}, socket) do
    rating = String.to_integer(rating)
    {:noreply, assign(socket, :rating, rating)}
  end

  @impl true
  def handle_event("update_comment", %{"comment" => comment}, socket) do
    {:noreply, assign(socket, :comment, comment)}
  end

  @impl true
  def handle_event("submit_survey", _params, socket) do
    %{
      rating: rating,
      comment: comment,
      selected_location: location,
      selected_node: node_id,
      ip_address: ip_address,
      user_agent: user_agent
    } = socket.assigns

    if rating == 0 do
      {:noreply, assign(socket, :survey_error_message, "Please select a rating")}
    else
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
            |> assign(:show_survey_success, true)
            |> assign(:survey_error_message, nil)

          # Auto-reset after 3 seconds
          Process.send_after(self(), :reset_survey, 3000)

          {:noreply, socket}

        {:error, _changeset} ->
          {:noreply,
           assign(socket, :survey_error_message, "Failed to submit survey. Please try again.")}
      end
    end
  end

  @impl true
  def handle_event("close_survey_success", _params, socket) do
    socket =
      socket
      |> assign(:show_survey_success, false)
      |> assign(:rating, 0)
      |> assign(:comment, "")
      |> assign(:survey_error_message, nil)

    {:noreply, socket}
  end

  @impl true
  def handle_event("close_modal", _params, socket) do
    socket =
      socket
      |> assign(:show_success_modal, false)
      |> assign(:visitor_identifier, "")
      |> assign(:selected_origin, "")
      |> assign(:visitor_name, nil)
      |> assign(:error_message, nil)
      |> push_event("focus_identifier", %{})

    {:noreply, socket}
  end

  @impl true
  def handle_info(:close_modal, socket) do
    socket =
      socket
      |> assign(:show_success_modal, false)
      |> assign(:visitor_identifier, "")
      |> assign(:selected_origin, "")
      |> assign(:visitor_name, nil)
      |> assign(:error_message, nil)
      |> push_event("focus_identifier", %{})

    {:noreply, socket}
  end

  @impl true
  def handle_info(:reset_survey, socket) do
    socket =
      socket
      |> assign(:rating, 0)
      |> assign(:comment, "")
      |> assign(:show_survey_success, false)
      |> assign(:survey_error_message, nil)

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
  @spec render(any()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <div
      class="min-h-screen bg-gradient-to-br from-blue-50 to-indigo-100 dark:from-gray-900 dark:to-blue-900 py-8 px-4"
      phx-hook="CheckInStorage"
      id="check-in-container"
      data-node-id={@selected_node}
      data-location-id={if @selected_location, do: @selected_location.id, else: nil}
    >
      <div class="max-w-7xl mx-auto">
        <!-- Header -->
        <div class="text-center mb-8">
          <h1 class="text-4xl font-bold text-gray-800 dark:text-white mb-2">Visitor Services</h1>
          <p class="text-gray-600 dark:text-gray-300">Check in or share your feedback</p>
        </div>

        <%= if @step == :select_location do %>
          <!-- Node Selection -->
          <div class="bg-white dark:bg-gray-800 rounded-lg shadow-lg p-8">
            <h2 class="text-2xl font-semibold text-gray-800 dark:text-white mb-6 text-center">
              Select Your Location
            </h2>
            <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
              <button
                :for={node <- @nodes}
                type="button"
                phx-click="select_node"
                phx-value-node_id={node.id}
                class="p-6 border-2 border-gray-200 dark:border-gray-600 rounded-lg hover:border-blue-500 dark:hover:border-blue-400 hover:bg-blue-50 dark:hover:bg-blue-900/30 transition-all duration-200 text-left"
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
                    <h3 class="text-lg font-semibold text-gray-800 dark:text-white">{node.name}</h3>
                    <%= if node.description do %>
                      <p class="text-sm text-gray-600 dark:text-gray-300">{node.description}</p>
                    <% end %>
                  </div>
                </div>
              </button>
            </div>
          </div>
        <% end %>

        <%= if @step == :select_room do %>
          <!-- Room Selection -->
          <div class="bg-white dark:bg-gray-800 rounded-lg shadow-lg p-8">
            <div class="mb-6 flex items-center justify-between">
              <button
                type="button"
                phx-click="back_to_nodes"
                class="text-blue-600 dark:text-blue-400 hover:text-blue-800 dark:hover:text-blue-300 flex items-center"
              >
                <.icon name="hero-arrow-left" class="w-5 h-5 mr-2" /> Back to Locations
              </button>

              <button
                type="button"
                phx-click="change_location"
                class="px-4 py-2 text-sm bg-gray-100 dark:bg-gray-700 hover:bg-gray-200 dark:hover:bg-gray-600 text-gray-700 dark:text-gray-300 rounded-lg transition-colors flex items-center"
              >
                <.icon name="hero-arrow-path" class="w-4 h-4 mr-2" /> Change Location
              </button>
            </div>

            <h2 class="text-2xl font-semibold text-gray-800 dark:text-white mb-6 text-center">
              Select Room
            </h2>

            <%= if @locations == [] do %>
              <div class="text-center py-8">
                <p class="text-gray-600 dark:text-gray-300">No rooms available at this location.</p>
              </div>
            <% else %>
              <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
                <button
                  :for={location <- @locations}
                  type="button"
                  phx-click="select_room"
                  phx-value-location_id={location.id}
                  class="p-6 border-2 border-gray-200 dark:border-gray-600 rounded-lg hover:border-blue-500 dark:hover:border-blue-400 hover:bg-blue-50 dark:hover:bg-blue-900/30 transition-all duration-200"
                >
                  <h3 class="text-lg font-semibold text-gray-800 dark:text-white mb-2">
                    {location.location_name}
                  </h3>
                  <%= if location.description do %>
                    <p class="text-sm text-gray-600 dark:text-gray-300">{location.description}</p>
                  <% end %>
                </button>
              </div>
            <% end %>
          </div>
        <% end %>

        <%= if @step == :show_forms do %>
          <!-- Navigation Header -->
          <div class="mb-6 flex items-center justify-between bg-white dark:bg-gray-800 rounded-lg shadow p-4">
            <button
              type="button"
              phx-click="back_to_rooms"
              class="text-blue-600 dark:text-blue-400 hover:text-blue-800 dark:hover:text-blue-300 flex items-center"
            >
              <.icon name="hero-arrow-left" class="w-5 h-5 mr-2" /> Back to Rooms
            </button>

            <div class="text-center">
              <h2 class="text-xl font-semibold text-gray-800 dark:text-white">
                {if @selected_location, do: @selected_location.location_name, else: "Services"}
              </h2>
            </div>

            <button
              type="button"
              phx-click="change_location"
              class="px-4 py-2 text-sm bg-gray-100 dark:bg-gray-700 hover:bg-gray-200 dark:hover:bg-gray-600 text-gray-700 dark:text-gray-300 rounded-lg transition-colors flex items-center"
            >
              <.icon name="hero-arrow-path" class="w-4 h-4 mr-2" /> Change Location
            </button>
          </div>
          
    <!-- Two Column Layout -->
          <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
            <!-- Check-in Form -->
            <div class="bg-white dark:bg-gray-800 rounded-lg shadow-lg p-6">
              <div class="mb-4">
                <h3 class="text-2xl font-semibold text-blue-600 dark:text-blue-400 mb-2">
                  <.icon name="hero-clipboard-document-check" class="w-6 h-6 inline-block" /> Check In
                </h3>
                <p class="text-sm text-gray-600 dark:text-gray-300">
                  Register your visit
                </p>
              </div>

              <%= if @error_message do %>
                <div class="mb-4 p-3 bg-red-100 dark:bg-red-900/30 border border-red-400 dark:border-red-600 text-red-700 dark:text-red-300 rounded-lg text-sm">
                  {@error_message}
                </div>
              <% end %>

              <form phx-submit="submit_check_in" class="space-y-4">
                <div>
                  <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                    ID / Student Number <span class="text-red-500">*</span>
                  </label>
                  <input
                    type="text"
                    id="visitor_identifier"
                    name="identifier"
                    value={@visitor_identifier}
                    phx-hook="IdentifierInput"
                    autocomplete="off"
                    class="w-full px-4 py-3 text-lg border border-gray-300 dark:border-gray-600 dark:bg-gray-700 dark:text-white rounded-lg focus:ring-2 focus:ring-blue-500 dark:focus:ring-blue-400"
                    placeholder="Scan or enter ID"
                  />
                </div>

                <div>
                  <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                    Visitor Type
                  </label>
                  <select
                    phx-change="select_origin"
                    class="w-full px-4 py-2 border border-gray-300 dark:border-gray-600 dark:bg-gray-700 dark:text-white rounded-lg focus:ring-2 focus:ring-blue-500"
                  >
                    <option value="">Select type</option>
                    <option
                      :for={origin <- @visitor_origin_options}
                      value={origin}
                      selected={@selected_origin == origin}
                    >
                      {origin}
                    </option>
                  </select>
                </div>

                <div class="mt-4">
                  <VirtualKeyboard.virtual_keyboard
                    target="visitor_identifier"
                    shift_active={@keyboard_shift_active}
                  />
                </div>

                <button
                  type="submit"
                  class="w-full py-3 px-6 bg-blue-600 hover:bg-blue-700 dark:bg-blue-700 dark:hover:bg-blue-600 text-white font-bold rounded-lg transition-colors shadow-lg"
                >
                  Check In Now
                </button>
              </form>
            </div>
            
    <!-- Survey Form -->
            <div class="bg-white dark:bg-gray-800 rounded-lg shadow-lg p-6">
              <div class="mb-4">
                <h3 class="text-2xl font-semibold text-purple-600 dark:text-purple-400 mb-2">
                  <.icon name="hero-chat-bubble-left-right" class="w-6 h-6 inline-block" /> Feedback
                </h3>
                <p class="text-sm text-gray-600 dark:text-gray-300">
                  Share your experience
                </p>
              </div>

              <%= if @survey_error_message do %>
                <div class="mb-4 p-3 bg-red-100 dark:bg-red-900/30 border border-red-400 dark:border-red-600 text-red-700 dark:text-red-300 rounded-lg text-sm">
                  {@survey_error_message}
                </div>
              <% end %>

              <form phx-submit="submit_survey" class="space-y-4">
                <div>
                  <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2 text-center">
                    Rate your experience <span class="text-red-500">*</span>
                  </label>
                  <div class="flex justify-center space-x-1">
                    <%= for star <- 1..5 do %>
                      <button
                        type="button"
                        phx-click="set_rating"
                        phx-value-rating={star}
                        class="focus:outline-none transition-transform hover:scale-110"
                      >
                        <%= if star <= @rating do %>
                          <svg
                            class="w-12 h-12 text-yellow-400 dark:text-yellow-500 fill-current"
                            xmlns="http://www.w3.org/2000/svg"
                            viewBox="0 0 24 24"
                          >
                            <path d="M12 2l3.09 6.26L22 9.27l-5 4.87 1.18 6.88L12 17.77l-6.18 3.25L7 14.14 2 9.27l6.91-1.01L12 2z" />
                          </svg>
                        <% else %>
                          <svg
                            class="w-12 h-12 text-gray-300 dark:text-gray-600 fill-current"
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
                    <p class="text-center text-xs text-gray-600 dark:text-gray-400 mt-2">
                      {@rating} {if @rating == 1, do: "star", else: "stars"}
                    </p>
                  <% end %>
                </div>

                <div>
                  <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                    Comments (Optional)
                  </label>
                  <textarea
                    name="comment"
                    phx-change="update_comment"
                    rows="3"
                    class="w-full px-4 py-2 border border-gray-300 dark:border-gray-600 dark:bg-gray-700 dark:text-white rounded-lg focus:ring-2 focus:ring-purple-500"
                    placeholder="Share your thoughts..."
                  >{@comment}</textarea>
                  <p class="text-xs text-gray-500 dark:text-gray-400 mt-1">
                    {String.length(@comment)}/500
                  </p>
                </div>

                <button
                  type="submit"
                  class="w-full py-3 px-6 bg-purple-600 hover:bg-purple-700 dark:bg-purple-700 dark:hover:bg-purple-600 text-white font-bold rounded-lg transition-colors shadow-lg"
                >
                  Submit Feedback
                </button>
              </form>
            </div>
          </div>
        <% end %>
      </div>
      
    <!-- Check-In Success Modal -->
      <%= if @show_success_modal do %>
        <div
          class="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4"
          phx-click="close_modal"
        >
          <div
            class="bg-white dark:bg-gray-800 rounded-2xl shadow-2xl max-w-xl w-full p-8 transform transition-all animate-[scale-in_0.3s_ease-out]"
            phx-click={JS.exec("phx-remove", to: "#success-modal")}
          >
            <!-- Success Icon -->
            <div class="flex justify-center mb-6">
              <div class="w-20 h-20 bg-green-100 dark:bg-green-900/30 rounded-full flex items-center justify-center">
                <.icon name="hero-check-circle" class="w-12 h-12 text-green-600 dark:text-green-400" />
              </div>
            </div>
            
    <!-- Welcome Message -->
            <div class="text-center space-y-4">
              <h3 class="text-2xl font-bold text-gray-900 dark:text-white">
                Welcome, {@visitor_name}!
              </h3>

              <p class="text-lg text-gray-700 dark:text-gray-300">
                Enjoy your stay at
              </p>

              <p class="text-xl font-semibold text-blue-600 dark:text-blue-400">
                {if @selected_location, do: @selected_location.location_name, else: "our facility"}
              </p>

              <div class="pt-4 border-t border-gray-200 dark:border-gray-700">
                <p class="text-sm text-gray-500 dark:text-gray-400">
                  Have a productive visit! 📚
                </p>
              </div>
            </div>
            
    <!-- Close Button -->
            <button
              type="button"
              phx-click="close_modal"
              class="mt-6 w-full py-3 bg-blue-600 hover:bg-blue-700 dark:bg-blue-700 dark:hover:bg-blue-600 text-white font-medium rounded-lg transition-colors"
            >
              Continue
            </button>
          </div>
        </div>
      <% end %>
      
    <!-- Survey Success Modal -->
      <%= if @show_survey_success do %>
        <div
          class="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4"
          phx-click="close_survey_success"
        >
          <div class="bg-white dark:bg-gray-800 rounded-2xl shadow-2xl max-w-xl w-full p-8 transform transition-all animate-[scale-in_0.3s_ease-out]">
            <!-- Success Icon -->
            <div class="flex justify-center mb-6">
              <div class="w-20 h-20 bg-purple-100 dark:bg-purple-900/30 rounded-full flex items-center justify-center">
                <.icon name="hero-heart" class="w-12 h-12 text-purple-600 dark:text-purple-400" />
              </div>
            </div>
            
    <!-- Thank You Message -->
            <div class="text-center space-y-4">
              <h3 class="text-2xl font-bold text-gray-900 dark:text-white">
                Thank You for Your Feedback!
              </h3>

              <p class="text-lg text-gray-700 dark:text-gray-300">
                Your {@rating}-star rating has been recorded
              </p>

              <div class="pt-4 border-t border-gray-200 dark:border-gray-700">
                <p class="text-sm text-gray-500 dark:text-gray-400">
                  We appreciate you taking the time to help us improve! 💜
                </p>
              </div>
            </div>
            
    <!-- Close Button -->
            <button
              type="button"
              phx-click="close_survey_success"
              class="mt-6 w-full py-3 bg-purple-600 hover:bg-purple-700 dark:bg-purple-700 dark:hover:bg-purple-600 text-white font-medium rounded-lg transition-colors"
            >
              Done
            </button>
          </div>
        </div>
      <% end %>
    </div>
    """
  end
end
