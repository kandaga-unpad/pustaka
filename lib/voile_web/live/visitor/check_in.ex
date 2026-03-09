defmodule VoileWeb.Visitor.CheckIn do
  use VoileWeb, :live_view

  import VoileWeb.Utils.UnpadNodeList, only: [get_node_by_id: 1]

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
      |> assign(:page_title, "Visitor Check-In & Survey")
      |> assign(:step, :select_location)
      |> assign(:nodes, nodes)
      |> assign(:selected_node, nil)
      |> assign(:locations, [])
      |> assign(:selected_location, nil)
      |> assign(:visitor_identifier, "")
      |> assign(:visitor_name, nil)
      |> assign(:visit_purpose, "")
      |> assign(:visitor_origin_options, get_origin_options())
      |> assign(:selected_origin, "")
      |> assign(:form, to_form(%{}, as: :visitor))
      |> assign(:show_success_modal, false)
      |> assign(:error_message, nil)
      |> assign(:ip_address, ip_address)
      |> assign(:user_agent, user_agent)
      |> assign(:rating, 0)
      |> assign(:comment, "")
      |> assign(:staff_rating, 0)
      |> assign(:show_survey_success, false)
      |> assign(:survey_error_message, nil)
      |> assign(:keyboard_shift_active, false)
      |> assign(:app_logo, app_logo)
      |> assign(:app_name, app_name)
      |> assign(:app_website, app_website)
      |> assign(:gender, nil)
      |> assign(:study_program, nil)

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

    # Get node name to auto-fill visitor_origin
    node = Enum.find(socket.assigns.nodes, &(&1.id == node_id))
    visitor_origin = if node, do: node.name, else: ""

    socket =
      socket
      |> assign(:selected_node, node_id)
      |> assign(:locations, locations)
      |> assign(:selected_location, nil)
      |> assign(:selected_origin, visitor_origin)
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
  def handle_event("update_visit_purpose", %{"visit_purpose" => value}, socket) do
    {:noreply, assign(socket, :visit_purpose, value)}
  end

  @impl true
  def handle_event("update_identifier", %{"identifier" => value}, socket) do
    {:noreply, assign(socket, :visitor_identifier, value)}
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
      user_agent: user_agent,
      visit_purpose: visit_purpose
    } = socket.assigns

    identifier = String.trim(identifier)

    if identifier == "" do
      {:noreply, assign(socket, :error_message, "Please enter your identifier")}
    else
      # Gather visitor info (name, gender, study program)
      visitor_info = lookup_visitor_information(identifier)
      visitor_name = visitor_info.fullname
      gender = visitor_info.gender
      study_program = visitor_info.study_program

      # Derive origin from identifier prefix (always takes precedence over auto-filled node selection)
      prefix = String.slice(identifier, 0, 3)

      derived_origin =
        case Integer.parse(prefix) do
          {int_prefix, ""} ->
            case get_node_by_id(int_prefix) do
              nil -> ""
              node when is_map(node) -> node[:namaFakultas] || node[:singkatan] || ""
            end

          _ ->
            ""
        end

      # Identifier-derived origin takes precedence; fall back to user-selected origin only when
      # the identifier prefix yields nothing (e.g. non-numeric / guest identifiers)
      origin =
        if derived_origin != "",
          do: derived_origin,
          else: if(is_nil(origin), do: "", else: origin)

      # build additional data map
      base_add = if(visit_purpose != "", do: %{"visit_purpose" => visit_purpose}, else: %{})
      extra_add = %{}
      extra_add = if gender, do: Map.put(extra_add, "gender", gender), else: extra_add

      extra_add =
        if study_program, do: Map.put(extra_add, "study_program", study_program), else: extra_add

      additional_data = Map.merge(base_add, extra_add)

      attrs = %{
        "visitor_identifier" => identifier,
        "visitor_name" => visitor_name,
        "visitor_origin" => origin,
        "location_id" => location.id,
        "node_id" => node_id,
        "ip_address" => ip_address,
        "user_agent" => user_agent,
        "additional_data" => additional_data
      }

      case System.create_visitor_log(attrs) do
        {:ok, visitor_log} ->
          socket =
            socket
            |> assign(:show_success_modal, true)
            |> assign(:visitor_name, visitor_log.visitor_name || identifier)
            |> assign(:visitor_identifier, "")
            |> assign(:visit_purpose, "")
            |> assign(:error_message, nil)
            |> assign(:gender, gender)
            |> assign(:study_program, study_program)

          # Auto-close modal after 4 seconds
          Process.send_after(self(), :close_modal, 1000)

          {:noreply, socket}

          socket
          |> assign(:show_success_modal, true)
          |> assign(:visitor_name, visitor_log.visitor_name || identifier)
          |> assign(:visitor_identifier, "")
          |> assign(:visit_purpose, "")
          |> assign(:error_message, nil)

          # Auto-close modal after 4 seconds
          Process.send_after(self(), :close_modal, 1000)

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
        "survey_type" => "general",
        "additional_data" => additional_data
      }

      case System.create_visitor_survey(attrs) do
        {:ok, _survey} ->
          socket =
            socket
            |> assign(:show_survey_success, true)
            |> assign(:survey_error_message, nil)

          # Auto-reset after 3 seconds
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
  def handle_event("close_modal", _params, socket) do
    socket =
      socket
      |> assign(:show_success_modal, false)
      |> assign(:visitor_identifier, "")
      |> assign(:visit_purpose, "")
      |> assign(:selected_origin, "")
      |> assign(:visitor_name, nil)
      |> assign(:gender, nil)
      |> assign(:study_program, nil)
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
      |> assign(:visit_purpose, "")
      |> assign(:selected_origin, "")
      |> assign(:visitor_name, nil)
      |> assign(:gender, nil)
      |> assign(:study_program, nil)
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

  defp get_origin_options do
    [
      "Student",
      "Faculty/Staff",
      "Alumni",
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

  # returns map with keys :fullname, :gender, :study_program
  defp lookup_visitor_information(identifier) do
    case Decimal.parse(identifier) do
      {_decimal, ""} ->
        # Identifier is numeric, try local database first
        alias Voile.Schema.Accounts

        case Accounts.get_user_by_identifier(identifier) do
          nil ->
            # Not found locally, try external API if configured
            lookup_from_external_api(identifier)

          user ->
            %{
              fullname: user.fullname || identifier,
              gender: user.gender,
              study_program: nil
            }
        end

      _ ->
        # Identifier is not numeric; treat as guest
        %{fullname: identifier, gender: nil, study_program: nil}
    end
  end

  # Fetch user data from external API
  defp lookup_from_external_api(identifier) do
    api_url = get_external_api_url()

    # Return fallback map if no API URL configured
    if api_url == "" do
      %{fullname: identifier, gender: nil, study_program: nil}
    else
      # Build URL safely (avoid double slashes)
      url =
        if String.ends_with?(api_url, "/"),
          do: api_url <> identifier,
          else: api_url <> "/" <> identifier

      case Req.get(url, receive_timeout: 5_000) do
        {:ok, %{status: 200, body: body}} ->
          # Ensure we have a map (Req may return decoded JSON or raw string)
          body_map =
            cond do
              is_map(body) ->
                body

              is_binary(body) ->
                case Jason.decode(body) do
                  {:ok, m} when is_map(m) -> m
                  _ -> %{}
                end

              true ->
                %{}
            end

          %{
            fullname: extract_fullname_from_response(body_map, identifier),
            gender: extract_gender_from_response(body_map),
            study_program: extract_study_program_from_response(body_map)
          }

        _ ->
          # API request failed, use identifier as-is
          %{fullname: identifier, gender: nil, study_program: nil}
      end
    end
  end

  # Get external API URL from config or environment variable
  # Priority: 1. Environment variable, 2. Application config, 3. Default
  defp get_external_api_url do
    raw =
      Elixir.System.get_env("VOILE_UNPAD_VISITOR_SOURCE") ||
        Application.get_env(:voile, :external_user_api_url)

    case raw do
      nil -> "https://voile.id/user"
      "" -> "https://voile.id/user"
      url -> String.trim_trailing(url, "/")
    end
  end

  # Extract fullname from API response
  defp extract_fullname_from_response(body, fallback) when is_map(body) do
    # Try common field names for fullname including the Unpad API field `MhsNama`
    # Try nested `data` key if present
    body["MhsNama"] || body["mhsnama"] || body["fullname"] || body["full_name"] ||
      body["name"] ||
      case body["data"] do
        d when is_map(d) -> extract_fullname_from_response(d, fallback)
        _ -> fallback
      end
  end

  defp extract_fullname_from_response(_body, fallback), do: fallback

  defp extract_gender_from_response(body) when is_map(body) do
    val =
      body["MhsKelamin"] || body["kelamin"] || body["gender"] ||
        case body["data"] do
          d when is_map(d) -> extract_gender_from_response(d)
          _ -> nil
        end

    case val do
      "L" -> "Male"
      "P" -> "Female"
      v when is_binary(v) -> v
      _ -> nil
    end
  end

  defp extract_gender_from_response(_), do: nil

  defp extract_study_program_from_response(body) when is_map(body) do
    body["MhsProdi"] || body["study_program"] || body["prodi"] ||
      case body["data"] do
        d when is_map(d) -> extract_study_program_from_response(d)
        _ -> nil
      end
  end

  defp extract_study_program_from_response(_), do: nil

  # Get Node Name
  defp get_node_name(node_id, nodes) do
    case Enum.find(nodes, &(&1.id == node_id)) do
      nil -> "Unknown Node"
      node -> node.name
    end
  end

  @impl true
  @spec render(any()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <div
      class="min-h-screen bg-gradient-to-br from-blue-50 to-indigo-100 dark:from-gray-900 dark:to-blue-900 py-8 px-4 pb-32"
      phx-hook="CheckInStorage"
      id="check-in-container"
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
                {gettext("Visitor Services")}
              </p>
              <p class="text-xs sm:text-sm text-gray-500 dark:text-gray-400">
                {gettext("Check in or share your feedback")}
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
                class="text-blue-600 dark:text-blue-400 hover:text-blue-800 dark:hover:text-blue-300 flex items-center"
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
              <.icon name="hero-arrow-left" class="w-5 h-5 mr-2" /> {gettext("Back to Rooms")}
            </button>

            <div class="text-center">
              <h2 class="text-xl font-semibold text-gray-800 dark:text-white">
                {if @selected_location,
                  do: @selected_location.location_name,
                  else: gettext("Services")}
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
            <!-- Check-in Form -->
            <div class="flex-1 bg-white dark:bg-gray-800 rounded-lg shadow-lg p-6">
              <div class="mb-4">
                <h3 class="text-2xl font-semibold text-blue-600 dark:text-blue-400 mb-2">
                  <.icon name="hero-clipboard-document-check" class="w-6 h-6 inline-block" /> {gettext(
                    "Check In"
                  )}
                </h3>
                <p class="text-sm text-gray-600 dark:text-gray-300">
                  {gettext("Register your visit")}
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
                    {gettext("ID / Student Number")} <span class="text-red-500">*</span>
                  </label>
                  <input
                    type="text"
                    id="visitor_identifier"
                    name="identifier"
                    value={@visitor_identifier}
                    phx-hook="IdentifierInput"
                    phx-change="update_identifier"
                    autocomplete="off"
                    class="w-full px-4 py-3 text-lg border border-gray-300 dark:border-gray-600 dark:bg-gray-700 dark:text-white rounded-lg focus:ring-2 focus:ring-blue-500 dark:focus:ring-blue-400"
                    placeholder={gettext("Scan or enter ID or Your Name")}
                  />
                </div>

                <div>
                  <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                    {gettext("Visit Purpose")}
                    <span class="text-gray-400 dark:text-gray-500 font-normal ml-1">
                      {gettext("(Optional)")}
                    </span>
                  </label>
                  <input
                    type="text"
                    name="visit_purpose"
                    value={@visit_purpose}
                    phx-change="update_visit_purpose"
                    autocomplete="off"
                    maxlength="255"
                    class="w-full px-4 py-3 text-lg border border-gray-300 dark:border-gray-600 dark:bg-gray-700 dark:text-white rounded-lg focus:ring-2 focus:ring-blue-500 dark:focus:ring-blue-400"
                    placeholder={gettext("e.g. Reading, Research, Borrowing books...")}
                  />
                </div>

                <div>
                  <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                    {gettext("Visitor Type")}
                  </label>
                  <select
                    name="origin"
                    phx-change="select_origin"
                    class="w-full px-4 py-2 border border-gray-300 dark:border-gray-600 dark:bg-gray-700 dark:text-white rounded-lg focus:ring-2 focus:ring-blue-500"
                  >
                    <option value="">{gettext("Select type")}</option>
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
                  {gettext("Check In Now")}
                </button>
              </form>
            </div>
            
    <!-- Survey Form -->
            <div class="flex-1 bg-white dark:bg-gray-800 rounded-lg shadow-lg p-6">
              <div class="mb-4">
                <h3 class="text-2xl font-semibold text-purple-600 dark:text-purple-400 mb-2">
                  <.icon name="hero-chat-bubble-left-right" class="w-6 h-6 inline-block" /> {gettext(
                    "Feedback"
                  )}
                </h3>
                <p class="text-sm text-gray-600 dark:text-gray-300 mb-3">
                  {gettext("Share your experience")}
                </p>
                <div class="flex items-center justify-center">
                  <span class="font-bold bg-violet-100 dark:bg-purple-700 px-3 py-1 rounded-xl text-center">
                    {@selected_location.location_name} | {get_node_name(@selected_node, @nodes)}
                  </span>
                </div>
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
              
    <!-- Registration Info -->
              <%= if @app_website do %>
                <div class="mt-6 pt-6 border-t border-gray-200 dark:border-gray-700">
                  <div class="flex items-start gap-3">
                    <div class="p-2 bg-blue-100 dark:bg-blue-900/30 rounded-lg">
                      <.icon name="hero-user-plus" class="w-5 h-5 text-blue-600 dark:text-blue-400" />
                    </div>
                    <div class="flex-1">
                      <h5 class="text-sm font-semibold text-gray-900 dark:text-white mb-1">
                        {gettext("New to our system?")}
                      </h5>
                      <p class="text-xs text-gray-600 dark:text-gray-400 mb-2">
                        {gettext("Register for a member account to access more features.")}
                      </p>
                      <a
                        href={"#{@app_website}/register"}
                        target="_blank"
                        class="inline-flex items-center gap-1 px-3 py-1.5 bg-blue-600 hover:bg-blue-700 dark:bg-blue-700 dark:hover:bg-blue-600 text-white text-xs font-medium rounded-lg transition-colors"
                      >
                        {gettext("Register Now")}
                        <.icon name="hero-arrow-top-right-on-square" class="w-3 h-3" />
                      </a>
                    </div>
                  </div>
                </div>
              <% end %>
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
                {gettext("Welcome, %{name}!", name: @visitor_name)}
              </h3>

              <%= if @gender do %>
                <p class="text-sm text-gray-600 dark:text-gray-300">
                  {gettext("Gender: %{gender}", gender: @gender)}
                </p>
              <% end %>

              <%= if @study_program do %>
                <p class="text-sm text-gray-600 dark:text-gray-300">
                  {gettext("Program: %{program}", program: @study_program)}
                </p>
              <% end %>

              <p class="text-lg text-gray-700 dark:text-gray-300">
                {gettext("Enjoy your stay at")}
              </p>

              <p class="text-xl font-semibold text-blue-600 dark:text-blue-400">
                {if @selected_location,
                  do: @selected_location.location_name,
                  else: gettext("our facility")}
              </p>

              <div class="pt-4 border-t border-gray-200 dark:border-gray-700">
                <p class="text-sm text-gray-500 dark:text-gray-400">
                  {gettext("Have a productive visit! 📚")}
                </p>
              </div>
            </div>
            
    <!-- Close Button -->
            <button
              type="button"
              phx-click="close_modal"
              class="mt-6 w-full py-3 bg-blue-600 hover:bg-blue-700 dark:bg-blue-700 dark:hover:bg-blue-600 text-white font-medium rounded-lg transition-colors"
            >
              {gettext("Continue")}
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
            <div
              class="flex items-center gap-3"
              phx-hook="RealtimeClock"
              phx-update="ignore"
              id="realtime-clock"
            >
              <.icon name="hero-clock" class="w-6 h-6 text-blue-600 dark:text-blue-400 flex-shrink-0" />
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
                  <span>{gettext("Powered by Voile")}</span>
                  <span class="text-gray-400 dark:text-gray-500">v0.1.0</span>
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
