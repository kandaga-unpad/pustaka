defmodule VoileWeb.Visitor.CheckOut do
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

    # Get app logo and name from system settings
    app_logo = System.get_setting_value("app_logo_url", nil)
    app_name = System.get_setting_value("app_name", "GLAM System")
    app_website = System.get_setting_value("app_website", nil)

    socket =
      socket
      |> assign(:page_title, "Visitor Check-Out")
      |> assign(:step, :select_location)
      |> assign(:nodes, nodes)
      |> assign(:selected_node, nil)
      |> assign(:locations, [])
      |> assign(:selected_location, nil)
      |> assign(:visitor_identifier, "")
      |> assign(:visitor_name, nil)
      |> assign(:show_success_modal, false)
      |> assign(:error_message, nil)
      |> assign(:ip_address, ip_address)
      |> assign(:user_agent, user_agent)
      |> assign(:keyboard_shift_active, false)
      |> assign(:app_logo, app_logo)
      |> assign(:app_name, app_name)
      |> assign(:app_website, app_website)
      |> assign(:rating, 0)
      |> assign(:comment, "")
      |> assign(:staff_rating, 0)
      |> assign(:show_survey_success, false)
      |> assign(:survey_error_message, nil)

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
        |> assign(:step, :show_form)

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
      |> assign(:step, :show_form)

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
      |> assign(:error_message, nil)

    {:noreply, push_event(socket, "clear_check_out_storage", %{})}
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
  def handle_event("submit_check_out", %{"identifier" => identifier} = _params, socket) do
    %{
      selected_location: location,
      selected_node: node_id,
      ip_address: ip_address,
      user_agent: user_agent
    } = socket.assigns

    identifier = String.trim(identifier)

    if identifier == "" do
      {:noreply, assign(socket, :error_message, "Please enter your identifier")}
    else
      case process_check_out(identifier, location.id, node_id, ip_address, user_agent) do
        {:ok, visitor_name} ->
          socket =
            socket
            |> assign(:show_success_modal, true)
            |> assign(:visitor_name, visitor_name)
            |> assign(:visitor_identifier, "")
            |> assign(:error_message, nil)

          # Auto-close modal after 2 seconds
          Process.send_after(self(), :close_modal, 2000)

          {:noreply, socket}

        {:error, :not_found} ->
          {:noreply,
           assign(socket, :error_message, "No check-in record found for this identifier today.")}

        {:error, message} when is_binary(message) ->
          {:noreply, assign(socket, :error_message, message)}

        {:error, _changeset} ->
          {:noreply, assign(socket, :error_message, "Failed to check out. Please try again.")}
      end
    end
  end

  @impl true
  def handle_event("close_modal", _params, socket) do
    socket =
      socket
      |> assign(:show_success_modal, false)
      |> assign(:visitor_identifier, "")
      |> assign(:visitor_name, nil)
      |> assign(:error_message, nil)
      |> push_event("focus_identifier", %{})

    {:noreply, socket}
  end

  @impl true
  def handle_event("set_rating", %{"rating" => rating}, socket) do
    rating = String.to_integer(rating)
    {:noreply, assign(socket, :rating, rating)}
  end

  @impl true
  def handle_event("set_staff_rating", %{"rating" => rating}, socket) do
    rating = String.to_integer(rating)
    {:noreply, assign(socket, :staff_rating, rating)}
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
      staff_rating: staff_rating,
      selected_location: location,
      selected_node: node_id,
      ip_address: ip_address,
      user_agent: user_agent
    } = socket.assigns

    if rating == 0 do
      {:noreply, assign(socket, :survey_error_message, "Please select a rating")}
    else
      additional_data =
        if staff_rating > 0 do
          %{"staff_rating" => staff_rating}
        else
          nil
        end

      attrs = %{
        "rating" => rating,
        "comment" => if(comment == "", do: nil, else: comment),
        "location_id" => location.id,
        "node_id" => node_id,
        "ip_address" => ip_address,
        "user_agent" => user_agent,
        "survey_type" => "checkout",
        "additional_data" => additional_data
      }

      case System.create_visitor_survey(attrs) do
        {:ok, _survey} ->
          socket =
            socket
            |> assign(:show_survey_success, true)
            |> assign(:survey_error_message, nil)

          # Auto-reset after 2 seconds
          Process.send_after(self(), :reset_survey, 2000)

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
      |> assign(:staff_rating, 0)
      |> assign(:comment, "")
      |> assign(:survey_error_message, nil)

    {:noreply, socket}
  end

  @impl true
  def handle_info(:close_modal, socket) do
    socket =
      socket
      |> assign(:show_success_modal, false)
      |> assign(:visitor_identifier, "")
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
      |> assign(:staff_rating, 0)
      |> assign(:comment, "")
      |> assign(:show_survey_success, false)
      |> assign(:survey_error_message, nil)

    {:noreply, socket}
  end

  defp get_ip_address(nil), do: nil

  defp get_ip_address(%{address: address}) when is_tuple(address) do
    address
    |> Tuple.to_list()
    |> Enum.join(".")
  end

  defp get_ip_address(_), do: nil

  # Process check-out logic
  defp process_check_out(identifier, location_id, node_id, ip_address, user_agent) do
    today = Date.utc_today()
    start_of_today = DateTime.new!(today, ~T[00:00:00], "Etc/UTC")
    end_of_today = DateTime.new!(today, ~T[23:59:59], "Etc/UTC")

    # Search for today's check-in log without check-out
    opts = [
      from_date: start_of_today,
      to_date: end_of_today,
      location_id: location_id,
      node_id: node_id,
      search: identifier,
      limit: 1
    ]

    logs = System.list_visitor_logs(opts)

    case logs do
      [log | _] when is_nil(log.check_out_time) ->
        # Found today's log without check-out, update it
        case System.update_visitor_log(log, %{"check_out_time" => DateTime.utc_now()}) do
          {:ok, updated_log} ->
            {:ok, updated_log.visitor_name || identifier}

          error ->
            error
        end

      [log | _] ->
        # Found today's log but already checked out
        {:error,
         "You have already checked out today. #{log.check_out_time |> DateTime.to_string()}"}

      [] ->
        # No log found for today, check if there's any previous check-in
        previous_opts = [
          to_date: start_of_today,
          location_id: location_id,
          node_id: node_id,
          search: identifier,
          limit: 1
        ]

        previous_logs = System.list_visitor_logs(previous_opts)

        case previous_logs do
          [previous_log | _] ->
            # Found previous check-in, create new entry copying the previous check-in time
            # Get visitor info from the node
            node = System.get_node!(node_id)

            attrs = %{
              "visitor_identifier" => identifier,
              "visitor_name" => previous_log.visitor_name,
              "visitor_origin" => node.name,
              "check_in_time" => previous_log.check_in_time,
              "check_out_time" => DateTime.utc_now(),
              "location_id" => location_id,
              "node_id" => node_id,
              "ip_address" => ip_address,
              "user_agent" => user_agent
            }

            case System.create_visitor_log(attrs) do
              {:ok, _log} ->
                {:ok, previous_log.visitor_name || identifier}

              error ->
                error
            end

          [] ->
            # No previous check-in found at all
            {:error, :not_found}
        end
    end
  end

  @impl true
  @spec render(any()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <div
      class="min-h-screen bg-gradient-to-br from-orange-50 to-red-100 dark:from-gray-900 dark:to-red-900 py-8 px-4 pb-32"
      phx-hook="CheckInStorage"
      id="check-out-container"
      data-node-id={@selected_node}
      data-location-id={if @selected_location, do: @selected_location.id, else: nil}
    >
      <div class="max-w-7xl mx-auto">
        <!-- Header -->
        <div class="mb-8">
          <div class="flex flex-col sm:flex-row items-center justify-center gap-4 sm:gap-6">
            <%= if @app_logo do %>
              <img
                src={@app_logo}
                alt={@app_name}
                class="h-16 sm:h-20 w-auto object-contain flex-shrink-0"
              />
            <% end %>
            <div class="text-center sm:text-left">
              <h1 class="text-3xl sm:text-4xl font-bold text-gray-800 dark:text-white mb-1">
                {@app_name}
              </h1>
              <p class="text-base sm:text-lg text-gray-600 dark:text-gray-300">
                {gettext("Visitor Check-Out")}
              </p>
              <p class="text-xs sm:text-sm text-gray-500 dark:text-gray-400">
                {gettext("Thank you for visiting us")}
              </p>
            </div>
          </div>
        </div>

        <%= if @step == :select_location do %>
          <!-- Node Selection -->
          <div class="bg-white dark:bg-gray-800 rounded-lg shadow-lg p-8">
            <h2 class="text-2xl font-semibold text-gray-800 dark:text-white mb-6 text-center">
              {gettext("Select Your Location")}
            </h2>
            <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
              <button
                :for={node <- @nodes}
                type="button"
                phx-click="select_node"
                phx-value-node_id={node.id}
                class="p-6 border-2 border-gray-200 dark:border-gray-600 rounded-lg hover:border-orange-500 dark:hover:border-orange-400 hover:bg-orange-50 dark:hover:bg-orange-900/30 transition-all duration-200 text-left"
              >
                <div class="flex items-center space-x-4">
                  <%= if node.image do %>
                    <img src={node.image} alt={node.name} class="w-16 h-16 rounded-lg object-cover" />
                  <% else %>
                    <div class="w-16 h-16 bg-orange-500 rounded-lg flex items-center justify-center">
                      <span class="text-white text-2xl font-bold">{String.first(node.name)}</span>
                    </div>
                  <% end %>
                  <div>
                    <h3 class="text-lg font-semibold text-gray-800 dark:text-white">{node.name}</h3>
                    <%= if node.description do %>
                      <p class="text-sm text-gray-600 dark:text-gray-300">
                        {node.description}
                      </p>
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
                class="text-orange-600 dark:text-orange-400 hover:text-orange-800 dark:hover:text-orange-300 flex items-center"
              >
                <.icon name="hero-arrow-left" class="w-5 h-5 mr-2" /> {gettext("Back to Locations")}
              </button>

              <button
                type="button"
                phx-click="change_location"
                class="px-4 py-2 text-sm bg-gray-100 dark:bg-gray-700 hover:bg-gray-200 dark:hover:bg-gray-600 text-gray-700 dark:text-gray-300 rounded-lg transition-colors flex items-center"
              >
                <.icon name="hero-arrow-path" class="w-4 h-4 mr-2" /> {gettext("Change Location")}
              </button>
            </div>

            <h2 class="text-2xl font-semibold text-gray-800 dark:text-white mb-6 text-center">
              {gettext("Select Room")}
            </h2>

            <%= if @locations == [] do %>
              <div class="text-center py-8">
                <p class="text-gray-600 dark:text-gray-300">
                  {gettext("No rooms available at this location.")}
                </p>
              </div>
            <% else %>
              <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
                <button
                  :for={location <- @locations}
                  type="button"
                  phx-click="select_room"
                  phx-value-location_id={location.id}
                  class="p-6 border-2 border-gray-200 dark:border-gray-600 rounded-lg hover:border-orange-500 dark:hover:border-orange-400 hover:bg-orange-50 dark:hover:bg-orange-900/30 transition-all duration-200"
                >
                  <h3 class="text-lg font-semibold text-gray-800 dark:text-white mb-2">
                    {location.location_name}
                  </h3>
                  <%= if location.description do %>
                    <p class="text-sm text-gray-600 dark:text-gray-300">
                      {location.description}
                    </p>
                  <% end %>
                </button>
              </div>
            <% end %>
          </div>
        <% end %>

        <%= if @step == :show_form do %>
          <!-- Navigation Header -->
          <div class="mb-6 flex items-center justify-between bg-white dark:bg-gray-800 rounded-lg shadow p-4">
            <button
              type="button"
              phx-click="back_to_rooms"
              class="text-orange-600 dark:text-orange-400 hover:text-orange-800 dark:hover:text-orange-300 flex items-center"
            >
              <.icon name="hero-arrow-left" class="w-5 h-5 mr-2" /> {gettext("Back to Rooms")}
            </button>

            <div class="text-center">
              <h2 class="text-xl font-semibold text-gray-800 dark:text-white">
                {if @selected_location,
                  do: @selected_location.location_name,
                  else: gettext("Check Out")}
              </h2>
            </div>

            <button
              type="button"
              phx-click="change_location"
              class="px-4 py-2 text-sm bg-gray-100 dark:bg-gray-700 hover:bg-gray-200 dark:hover:bg-gray-600 text-gray-700 dark:text-gray-300 rounded-lg transition-colors flex items-center"
            >
              <.icon name="hero-arrow-path" class="w-4 h-4 mr-2" /> {gettext("Change Location")}
            </button>
          </div>
          
    <!-- Two Column Layout -->
          <div class="flex flex-col lg:flex-row gap-6">
            <!-- Check-out Form -->
            <div class="flex-1 bg-white dark:bg-gray-800 rounded-lg shadow-lg p-6">
              <div class="mb-4">
                <h3 class="text-2xl font-semibold text-orange-600 dark:text-orange-400 mb-2">
                  <.icon name="hero-arrow-right-on-rectangle" class="w-6 h-6 inline-block" />
                  {gettext("Check Out")}
                </h3>
                <p class="text-sm text-gray-600 dark:text-gray-300">
                  {gettext("Complete your visit")}
                </p>
              </div>

              <%= if @error_message do %>
                <div class="mb-4 p-3 bg-red-100 dark:bg-red-900/30 border border-red-400 dark:border-red-600 text-red-700 dark:text-red-300 rounded-lg text-sm">
                  {@error_message}
                </div>
              <% end %>

              <form phx-submit="submit_check_out" class="space-y-4">
                <div>
                  <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                    {gettext("ID / Student Number")} <span class="text-red-500">*</span>
                  </label>
                  <input
                    type="text"
                    id="visitor_identifier"
                    name="identifier"
                    value={@visitor_identifier}
                    phx-hook="IdentifierInput"
                    autocomplete="off"
                    class="w-full px-4 py-3 text-lg border border-gray-300 dark:border-gray-600 dark:bg-gray-700 dark:text-white rounded-lg focus:ring-2 focus:ring-orange-500 dark:focus:ring-orange-400"
                    placeholder={gettext("Scan or enter your ID")}
                  />
                </div>

                <div class="mt-4">
                  <VirtualKeyboard.virtual_keyboard
                    target="visitor_identifier"
                    shift_active={@keyboard_shift_active}
                  />
                </div>

                <button
                  type="submit"
                  class="w-full py-3 px-6 bg-orange-600 hover:bg-orange-700 dark:bg-orange-700 dark:hover:bg-orange-600 text-white font-bold rounded-lg transition-colors shadow-lg"
                >
                  {gettext("Check Out Now")}
                </button>
              </form>

              <div class="mt-6 p-4 bg-blue-50 dark:bg-blue-900/20 border border-blue-200 dark:border-blue-800 rounded-lg">
                <div class="flex items-start gap-3">
                  <.icon
                    name="hero-information-circle"
                    class="w-5 h-5 text-blue-600 dark:text-blue-400 flex-shrink-0 mt-0.5"
                  />
                  <div class="text-sm text-blue-800 dark:text-blue-300">
                    <p class="font-medium mb-1">{gettext("Important:")}</p>
                    <p>
                      {gettext(
                        "Please check out when leaving to help us maintain accurate visitor records."
                      )}
                    </p>
                  </div>
                </div>
              </div>
            </div>
            
    <!-- Survey Form -->
            <div class="flex-1 bg-white dark:bg-gray-800 rounded-lg shadow-lg p-6">
              <div class="mb-4">
                <h3 class="text-2xl font-semibold text-purple-600 dark:text-purple-400 mb-2">
                  <.icon name="hero-chat-bubble-left-right" class="w-6 h-6 inline-block" /> {gettext(
                    "Feedback"
                  )}
                </h3>
                <p class="text-sm text-gray-600 dark:text-gray-300">
                  {gettext("Share your experience")}
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
                    {gettext("Rate your experience")} <span class="text-red-500">*</span>
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
                            class="w-10 h-10 text-yellow-400"
                            fill="currentColor"
                            viewBox="0 0 20 20"
                          >
                            <path d="M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.07 3.292a1 1 0 00.95.69h3.462c.969 0 1.371 1.24.588 1.81l-2.8 2.034a1 1 0 00-.364 1.118l1.07 3.292c.3.921-.755 1.688-1.54 1.118l-2.8-2.034a1 1 0 00-1.175 0l-2.8 2.034c-.784.57-1.838-.197-1.539-1.118l1.07-3.292a1 1 0 00-.364-1.118L2.98 8.72c-.783-.57-.38-1.81.588-1.81h3.461a1 1 0 00.951-.69l1.07-3.292z" />
                          </svg>
                        <% else %>
                          <svg
                            class="w-10 h-10 text-gray-300 dark:text-gray-600"
                            fill="currentColor"
                            viewBox="0 0 20 20"
                          >
                            <path d="M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.07 3.292a1 1 0 00.95.69h3.462c.969 0 1.371 1.24.588 1.81l-2.8 2.034a1 1 0 00-.364 1.118l1.07 3.292c.3.921-.755 1.688-1.54 1.118l-2.8-2.034a1 1 0 00-1.175 0l-2.8 2.034c-.784.57-1.838-.197-1.539-1.118l1.07-3.292a1 1 0 00-.364-1.118L2.98 8.72c-.783-.57-.38-1.81.588-1.81h3.461a1 1 0 00.951-.69l1.07-3.292z" />
                          </svg>
                        <% end %>
                      </button>
                    <% end %>
                  </div>
                  <%= if @rating > 0 do %>
                    <p class="text-center text-xs text-gray-600 dark:text-gray-400 mt-2">
                      {@rating} {if @rating == 1, do: gettext("star"), else: gettext("stars")}
                    </p>
                  <% end %>
                </div>

                <%= if @rating > 0 do %>
                  <div class="pt-4 border-t border-gray-200 dark:border-gray-700">
                    <label class="block text-xs font-medium text-gray-700 dark:text-gray-300 mb-2 text-center">
                      {gettext("Rate our staff (Optional)")}
                    </label>
                    <div class="flex justify-center space-x-0.5">
                      <%= for star <- 1..5 do %>
                        <button
                          type="button"
                          phx-click="set_staff_rating"
                          phx-value-rating={star}
                          class="focus:outline-none transition-transform hover:scale-110"
                        >
                          <%= if star <= @staff_rating do %>
                            <svg
                              class="w-6 h-6 text-yellow-400"
                              fill="currentColor"
                              viewBox="0 0 20 20"
                            >
                              <path d="M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.07 3.292a1 1 0 00.95.69h3.462c.969 0 1.371 1.24.588 1.81l-2.8 2.034a1 1 0 00-.364 1.118l1.07 3.292c.3.921-.755 1.688-1.54 1.118l-2.8-2.034a1 1 0 00-1.175 0l-2.8 2.034c-.784.57-1.838-.197-1.539-1.118l1.07-3.292a1 1 0 00-.364-1.118L2.98 8.72c-.783-.57-.38-1.81.588-1.81h3.461a1 1 0 00.951-.69l1.07-3.292z" />
                            </svg>
                          <% else %>
                            <svg
                              class="w-6 h-6 text-gray-300 dark:text-gray-600"
                              fill="currentColor"
                              viewBox="0 0 20 20"
                            >
                              <path d="M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.07 3.292a1 1 0 00.95.69h3.462c.969 0 1.371 1.24.588 1.81l-2.8 2.034a1 1 0 00-.364 1.118l1.07 3.292c.3.921-.755 1.688-1.54 1.118l-2.8-2.034a1 1 0 00-1.175 0l-2.8 2.034c-.784.57-1.838-.197-1.539-1.118l1.07-3.292a1 1 0 00-.364-1.118L2.98 8.72c-.783-.57-.38-1.81.588-1.81h3.461a1 1 0 00.951-.69l1.07-3.292z" />
                            </svg>
                          <% end %>
                        </button>
                      <% end %>
                    </div>
                    <%= if @staff_rating > 0 do %>
                      <p class="text-center text-xs text-gray-600 dark:text-gray-400 mt-1">
                        {@staff_rating} {if @staff_rating == 1,
                          do: gettext("star"),
                          else: gettext("stars")}
                      </p>
                    <% end %>
                  </div>
                <% end %>

                <div>
                  <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                    {gettext("Comments (Optional)")}
                  </label>
                  <textarea
                    name="comment"
                    phx-change="update_comment"
                    rows="3"
                    class="w-full px-4 py-2 border border-gray-300 dark:border-gray-600 dark:bg-gray-700 dark:text-white rounded-lg focus:ring-2 focus:ring-purple-500"
                    placeholder={gettext("Share your thoughts...")}
                  >{@comment}</textarea>
                  <p class="text-xs text-gray-500 dark:text-gray-400 mt-1">
                    {String.length(@comment)}/500
                  </p>
                </div>

                <button
                  type="submit"
                  class="w-full py-3 px-6 bg-purple-600 hover:bg-purple-700 dark:bg-purple-700 dark:hover:bg-purple-600 text-white font-bold rounded-lg transition-colors shadow-lg"
                >
                  {gettext("Submit Feedback")}
                </button>
              </form>
              
    <!-- Thank You Note -->
              <div class="mt-6 pt-6 border-t border-gray-200 dark:border-gray-700">
                <div class="flex items-start gap-3">
                  <div class="p-2 bg-orange-100 dark:bg-orange-900/30 rounded-lg">
                    <.icon name="hero-heart" class="w-5 h-5 text-orange-600 dark:text-orange-400" />
                  </div>
                  <div class="flex-1">
                    <h5 class="text-sm font-semibold text-gray-900 dark:text-white mb-1">
                      {gettext("Thank you for visiting!")}
                    </h5>
                    <p class="text-xs text-gray-600 dark:text-gray-400">
                      {gettext("Your feedback helps us improve our services.")}
                    </p>
                  </div>
                </div>
              </div>
            </div>
          </div>
        <% end %>
      </div>
      
    <!-- Check-Out Success Modal -->
      <%= if @show_success_modal do %>
        <div
          class="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4"
          phx-click="close_modal"
        >
          <div class="bg-white dark:bg-gray-800 rounded-2xl shadow-2xl max-w-xl w-full p-8 transform transition-all animate-[scale-in_0.3s_ease-out]">
            <!-- Success Icon -->
            <div class="flex justify-center mb-6">
              <div class="w-20 h-20 bg-green-100 dark:bg-green-900/30 rounded-full flex items-center justify-center">
                <.icon name="hero-check-circle" class="w-12 h-12 text-green-600 dark:text-green-400" />
              </div>
            </div>
            
    <!-- Goodbye Message -->
            <div class="text-center space-y-4">
              <h3 class="text-2xl font-bold text-gray-900 dark:text-white">
                {gettext("Thank You, %{name}!", name: @visitor_name)}
              </h3>

              <p class="text-lg text-gray-700 dark:text-gray-300">
                {gettext("You have successfully checked out from")}
              </p>

              <p class="text-xl font-semibold text-orange-600 dark:text-orange-400">
                {if @selected_location,
                  do: @selected_location.location_name,
                  else: gettext("our facility")}
              </p>

              <div class="pt-4 border-t border-gray-200 dark:border-gray-700">
                <p class="text-sm text-gray-500 dark:text-gray-400">
                  {gettext("We hope to see you again soon! 👋")}
                </p>
              </div>
            </div>
            
    <!-- Close Button -->
            <button
              type="button"
              phx-click="close_modal"
              class="mt-6 w-full py-3 bg-orange-600 hover:bg-orange-700 dark:bg-orange-700 dark:hover:bg-orange-600 text-white font-medium rounded-lg transition-colors"
            >
              {gettext("Done")}
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
                {gettext("Thank You for Your Feedback!")}
              </h3>

              <p class="text-lg text-gray-700 dark:text-gray-300">
                {gettext("Your %{rating}-star rating has been recorded", rating: @rating)}
              </p>

              <div class="pt-4 border-t border-gray-200 dark:border-gray-700">
                <p class="text-sm text-gray-500 dark:text-gray-400">
                  {gettext("We appreciate you taking the time to help us improve! 💜")}
                </p>
              </div>
            </div>
            
    <!-- Close Button -->
            <button
              type="button"
              phx-click="close_survey_success"
              class="mt-6 w-full py-3 bg-purple-600 hover:bg-purple-700 dark:bg-purple-700 dark:hover:bg-purple-600 text-white font-medium rounded-lg transition-colors"
            >
              {gettext("Done")}
            </button>
          </div>
        </div>
      <% end %>
      
    <!-- Footer -->
      <footer class="fixed bottom-0 left-0 right-0 bg-white dark:bg-gray-800 border-t border-gray-200 dark:border-gray-700 shadow-lg z-40">
        <div class="max-w-7xl mx-auto px-4 py-3">
          <div class="flex flex-col md:flex-row items-center justify-between gap-4">
            <!-- Clock and Date -->
            <div class="flex items-center gap-3" phx-hook="RealtimeClock" id="realtime-clock">
              <.icon
                name="hero-clock"
                class="w-6 h-6 text-orange-600 dark:text-orange-400 flex-shrink-0"
              />
              <div class="flex flex-col">
                <span
                  class="font-mono text-3xl font-bold text-gray-900 dark:text-white leading-tight"
                  data-clock-time
                >
                  00:00:00
                </span>
                <span class="text-sm text-gray-600 dark:text-gray-400 font-medium" data-clock-date>
                  Sunday, 01 Jan 2026
                </span>
              </div>
            </div>
            
    <!-- Software Info -->
            <div class="flex items-center gap-3 text-center md:text-right">
              <div class="text-xs text-gray-600 dark:text-gray-400">
                <div class="font-semibold">{@app_name}</div>
                <div class="flex items-center gap-1 justify-center md:justify-end">
                  <span>{gettext("Powered by Voile Framework")}</span>
                  <span class="text-gray-400 dark:text-gray-500">v1.0</span>
                </div>
              </div>
            </div>
          </div>
        </div>
      </footer>
    </div>
    """
  end
end
