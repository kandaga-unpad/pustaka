defmodule VoileWeb.Dashboard.StockOpnameLive.Scan do
  use VoileWeb, :live_view_dashboard

  alias Voile.Schema.Catalog.Item
  alias Voile.Schema.StockOpname
  alias Voile.Schema.Master.Location
  alias VoileWeb.Auth.StockOpnameAuthorization
  import Ecto.Query

  def render(assigns) do
    ~H"""
    <div class="container mx-auto px-4 py-6">
      <%!-- Header --%>
      <div class="mb-6">
        <.link
          navigate={~p"/manage/stock_opname/#{@session.id}"}
          class="text-blue-600 hover:text-blue-700 dark:text-blue-400 dark:hover:text-blue-300 flex items-center gap-2 mb-4"
        >
          <.icon name="hero-arrow-left" class="w-4 h-4" /> Back to Session
        </.link>
        <div class="flex justify-between items-start">
          <div>
            <h1 class="text-3xl font-bold text-gray-900 dark:text-gray-100">{@session.title}</h1>

            <p class="text-gray-600 dark:text-gray-400">Session Code: {@session.session_code}</p>
          </div>
          <.session_status_badge status={@session.status} />
        </div>
      </div>
      <%!-- Progress Bar --%>
      <div class="bg-white dark:bg-gray-800 rounded-lg shadow-sm p-6 mb-6">
        <div class="flex justify-between items-center mb-2">
          <h2 class="text-lg font-semibold text-gray-900 dark:text-gray-100">Your Progress</h2>

          <span class="text-sm text-gray-600 dark:text-gray-400">
            {@librarian_progress.items_checked} / {@session.total_items} items
          </span>
        </div>

        <div class="w-full bg-gray-200 dark:bg-gray-700 rounded-full h-3 mb-4">
          <div
            class="bg-blue-600 dark:bg-blue-500 h-3 rounded-full transition-all duration-500"
            style={"width: #{calculate_progress(@librarian_progress.items_checked, @session.total_items)}%"}
          >
          </div>
        </div>
        <%!-- Statistics --%>
        <div class="grid grid-cols-2 md:grid-cols-4 gap-4">
          <div class="text-center">
            <p class="text-2xl font-bold text-blue-600 dark:text-blue-500">
              {@session.checked_items}
            </p>

            <p class="text-xs text-gray-500 dark:text-gray-400">Total Checked</p>
          </div>

          <div class="text-center">
            <p class="text-2xl font-bold text-gray-600 dark:text-gray-400">
              {@session.total_items - @session.checked_items}
            </p>

            <p class="text-xs text-gray-500 dark:text-gray-400">Remaining</p>
          </div>

          <div class="text-center">
            <p class="text-2xl font-bold text-yellow-600 dark:text-yellow-500">
              {@session.items_with_changes}
            </p>

            <p class="text-xs text-gray-500 dark:text-gray-400">With Changes</p>
          </div>

          <div class="text-center">
            <p class="text-2xl font-bold text-green-600 dark:text-green-500">
              {@librarian_progress.items_checked}
            </p>

            <p class="text-xs text-gray-500 dark:text-gray-400">Your Checks</p>
          </div>
        </div>
      </div>
      <%!-- Scanner Interface --%>
      <div class="bg-white dark:bg-gray-800 rounded-lg shadow-sm p-6 mb-6">
        <h2 class="text-lg font-semibold text-gray-900 dark:text-gray-100 mb-4">Scan Item</h2>

        <form phx-submit="scan_item" class="mb-4">
          <div class="flex gap-2">
            <div class="flex-1">
              <input
                type="text"
                name="search_term"
                value={@search_term}
                placeholder="Scan barcode or enter item code..."
                autofocus
                id="scan-input"
                phx-change="update_search_term"
                phx-keydown="scan_input_keydown"
                class="w-full px-4 py-3 text-lg border-2 border-gray-300 dark:border-gray-600 rounded-lg focus:border-blue-500 focus:ring-2 focus:ring-blue-200 dark:bg-gray-700 dark:text-gray-100"
              />
            </div>

            <button
              type="submit"
              class="px-6 py-3 bg-blue-600 hover:bg-blue-700 text-white font-medium rounded-lg transition-colors"
            >
              <.icon name="hero-magnifying-glass" class="w-6 h-6" />
            </button>
          </div>

          <p class="text-xs text-gray-500 dark:text-gray-400 mt-2">
            Supports barcode, legacy item code, or item code search
          </p>
        </form>
      </div>
      <%!-- Duplicate Results (if multiple items found) --%>
      <div
        :if={@duplicate_items != []}
        class="bg-yellow-50 dark:bg-yellow-900/20 border border-yellow-200 dark:border-yellow-800 rounded-lg p-6 mb-6"
      >
        <h3 class="text-lg font-semibold text-yellow-900 dark:text-yellow-300 mb-4">
          Multiple Items Found - Select One
        </h3>

        <div class="space-y-3">
          <button
            :for={opname_item <- @duplicate_items}
            type="button"
            phx-click="select_item"
            phx-value-id={opname_item.id}
            class="w-full text-left p-4 bg-white dark:bg-gray-800 border-2 border-yellow-300 dark:border-yellow-600 hover:border-yellow-500 dark:hover:border-yellow-500 rounded-lg transition-colors"
          >
            <div class="flex justify-between items-start">
              <div class="flex-1">
                <p class="font-semibold text-gray-900 dark:text-gray-100">{opname_item.item_code}</p>

                <p class="text-sm text-gray-600 dark:text-gray-400">{opname_item.collection_title}</p>

                <div class="flex gap-4 mt-2 text-xs text-gray-500 dark:text-gray-500">
                  <span>Inventory: {opname_item.inventory_code}</span>
                  <span :if={opname_item.barcode}>Barcode: {opname_item.barcode}</span>
                  <span :if={opname_item.legacy_item_code}>
                    Legacy: {opname_item.legacy_item_code}
                  </span>
                </div>
              </div>
              <.item_check_badge status={opname_item.check_status} />
            </div>
          </button>
        </div>
      </div>
      <%!-- Current Item Detail Card --%>
      <div
        :if={@current_item}
        class="bg-white dark:bg-gray-800 rounded-lg shadow-lg p-6 mb-6"
        phx-window-keydown="keyboard_shortcut"
        phx-key="Enter"
      >
        <div class="flex justify-between items-start mb-4">
          <h3 class="text-xl font-semibold text-gray-900 dark:text-gray-100">Item Details</h3>

          <button
            type="button"
            phx-click="clear_item"
            class="text-gray-400 dark:text-gray-500 hover:text-gray-600 dark:hover:text-gray-400"
          >
            <.icon name="hero-x-mark" class="w-6 h-6" />
          </button>
        </div>
        <%!-- Actions at Top --%>
        <div class="flex gap-3 mb-6 pb-4 border-b border-gray-200 dark:border-gray-700">
          <button
            type="button"
            phx-click="check_item"
            class="flex-1 px-4 py-3 bg-green-600 hover:bg-green-700 text-white font-medium rounded-lg transition-colors"
          >
            <.icon name="hero-check-circle" class="w-5 h-5 inline mr-2" /> Mark as Checked
          </button>
          <button
            type="button"
            phx-click="clear_item"
            class="px-4 py-3 bg-gray-200 hover:bg-gray-300 dark:bg-gray-600 dark:hover:bg-gray-500 text-gray-700 dark:text-gray-200 font-medium rounded-lg transition-colors"
          >
            Cancel
          </button>
        </div>

        <div class="space-y-6">
          <%!-- Identification Section --%>
          <div class="bg-gradient-to-r from-blue-50 to-indigo-50 dark:from-blue-900/20 dark:to-indigo-900/20 rounded-lg p-6">
            <h4 class="font-semibold text-gray-800 dark:text-gray-200 mb-4 flex items-center gap-2">
              <.icon name="hero-identification" class="w-5 h-5 text-blue-600 dark:text-blue-400" />
              Item Identification
            </h4>

            <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                  Item Code <span class="text-gray-400 dark:text-gray-500 text-xs">(Read-only)</span>
                </label>
                <div class="bg-white dark:bg-gray-700 px-4 py-3 rounded-lg border border-gray-200 dark:border-gray-600 font-mono text-sm text-gray-700 dark:text-gray-300">
                  {@current_item.item.item_code}
                </div>
              </div>

              <div>
                <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                  Inventory Code
                  <span class="text-gray-400 dark:text-gray-500 text-xs">(Read-only)</span>
                </label>
                <div class="bg-white dark:bg-gray-700 px-4 py-3 rounded-lg border border-gray-200 dark:border-gray-600 font-mono text-sm text-gray-700 dark:text-gray-300">
                  {@current_item.item.inventory_code}
                </div>
              </div>

              <div>
                <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                  Barcode <span class="text-gray-400 dark:text-gray-500 text-xs">(Read-only)</span>
                </label>
                <div class="bg-white dark:bg-gray-700 px-4 py-3 rounded-lg border border-gray-200 dark:border-gray-600 font-mono text-sm text-gray-700 dark:text-gray-300">
                  {@current_item.item.barcode || "N/A"}
                </div>
              </div>

              <div>
                <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                  Legacy Item Code
                  <span class="text-gray-400 dark:text-gray-500 text-xs">(Read-only)</span>
                </label>
                <div class="bg-white dark:bg-gray-700 px-4 py-3 rounded-lg border border-gray-200 dark:border-gray-600 font-mono text-sm text-gray-700 dark:text-gray-300">
                  {@current_item.item.legacy_item_code || "N/A"}
                </div>
              </div>
            </div>

            <div class="mt-4">
              <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                Collection <span class="text-gray-400 dark:text-gray-500 text-xs">(Read-only)</span>
              </label>
              <div class="bg-white dark:bg-gray-700 px-4 py-3 rounded-lg border border-gray-200 dark:border-gray-600 text-sm text-gray-700 dark:text-gray-300">
                {@current_item.collection.title}
              </div>
            </div>
          </div>
          <%!-- Status & Condition Section --%>
          <div class="bg-gradient-to-r from-green-50 to-emerald-50 dark:from-green-900/20 dark:to-emerald-900/20 rounded-lg p-6">
            <h4 class="font-semibold text-gray-800 dark:text-gray-200 mb-4 flex items-center gap-2">
              <.icon
                name="hero-clipboard-document-check"
                class="w-5 h-5 text-green-600 dark:text-green-400"
              /> Status & Condition
            </h4>

            <form phx-change="update_field">
              <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
                <div>
                  <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                    Status
                  </label>
                  <select
                    name="status"
                    phx-change="update_field"
                    class="w-full px-4 py-3 rounded-lg border-2 border-gray-200 dark:border-gray-600 focus:border-green-500 focus:ring-2 focus:ring-green-200 transition-all text-sm bg-white dark:bg-gray-700 dark:text-gray-200"
                  >
                    <option
                      :for={{label, value} <- Item.status_options()}
                      value={value}
                      selected={value == @updated_values.status}
                    >
                      {label}
                    </option>
                  </select>
                </div>

                <div>
                  <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                    Condition
                  </label>
                  <select
                    name="condition"
                    phx-change="update_field"
                    class="w-full px-4 py-3 rounded-lg border-2 border-gray-200 dark:border-gray-600 focus:border-green-500 focus:ring-2 focus:ring-green-200 transition-all text-sm bg-white dark:bg-gray-700 dark:text-gray-200"
                  >
                    <option
                      :for={{label, value} <- Item.condition_options()}
                      value={value}
                      selected={value == @updated_values.condition}
                    >
                      {label}
                    </option>
                  </select>
                </div>

                <div>
                  <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                    Availability
                  </label>
                  <select
                    name="availability"
                    phx-change="update_field"
                    class="w-full px-4 py-3 rounded-lg border-2 border-gray-200 dark:border-gray-600 focus:border-green-500 focus:ring-2 focus:ring-green-200 transition-all text-sm bg-white dark:bg-gray-700 dark:text-gray-200"
                  >
                    <option
                      :for={{label, value} <- Item.availability_options()}
                      value={value}
                      selected={value == @updated_values.availability}
                    >
                      {label}
                    </option>
                  </select>
                </div>
              </div>
            </form>
          </div>
          <%!-- Location & Notes Section --%>
          <div class="bg-gradient-to-r from-purple-50 to-pink-50 dark:from-purple-900/20 dark:to-pink-900/20 rounded-lg p-6">
            <h4 class="font-semibold text-gray-800 dark:text-gray-200 mb-4 flex items-center gap-2">
              <.icon name="hero-map-pin" class="w-5 h-5 text-purple-600 dark:text-purple-400" />
              Location & Notes
            </h4>

            <div class="space-y-4">
              <div>
                <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                  Predefined Location (Room)
                </label>
                <form phx-change="update_field">
                  <select
                    name="item_location_id"
                    class="w-full px-4 py-3 rounded-lg border-2 border-gray-200 dark:border-gray-600 focus:border-purple-500 focus:ring-2 focus:ring-purple-200 transition-all text-sm dark:bg-gray-700 dark:text-gray-200"
                  >
                    <option value="">-- Select Room (Optional) --</option>
                    <option
                      :for={location <- @locations}
                      value={location.id}
                      selected={
                        to_string(@updated_values[:item_location_id]) == to_string(location.id)
                      }
                    >
                      {location.location_name} - {location.location_place}
                    </option>
                  </select>
                </form>
              </div>

              <div>
                <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                  Free-text Location
                </label>
                <form phx-change="update_field">
                  <input
                    type="text"
                    name="location"
                    value={@updated_values.location}
                    phx-debounce="300"
                    placeholder="Enter any location description"
                    class="w-full px-4 py-3 rounded-lg border-2 border-gray-200 dark:border-gray-600 focus:border-purple-500 focus:ring-2 focus:ring-purple-200 transition-all text-sm dark:bg-gray-700 dark:text-gray-200"
                  />
                </form>
              </div>

              <div>
                <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                  Notes
                </label>
                <form phx-change="update_field">
                  <textarea
                    name="notes"
                    phx-debounce="300"
                    rows="4"
                    placeholder="Add any observations or remarks..."
                    class="w-full px-4 py-3 rounded-lg border-2 border-gray-200 dark:border-gray-600 focus:border-purple-500 focus:ring-2 focus:ring-purple-200 transition-all text-sm resize-none dark:bg-gray-700 dark:text-gray-200"
                  >{@updated_values.notes}</textarea>
                </form>
              </div>
            </div>
          </div>
        </div>
      </div>
      <%!-- Recently Scanned Items --%>
      <div class="bg-white dark:bg-gray-800 rounded-lg shadow-sm p-6">
        <h3 class="text-lg font-semibold text-gray-900 dark:text-gray-100 mb-4">Recently Scanned</h3>

        <div id="recently-scanned" phx-update="stream" class="space-y-2">
          <div
            id="empty-state"
            class="hidden only:block text-center text-gray-500 dark:text-gray-400 py-8"
          >
            <.icon name="hero-inbox" class="w-12 h-12 mx-auto mb-2 text-gray-400 dark:text-gray-500" />
            <p>No items scanned yet. Start scanning to see items here.</p>
          </div>

          <div
            :for={{dom_id, opname_item} <- @streams.recent_items}
            id={dom_id}
            class="p-3 bg-gray-50 dark:bg-gray-700 rounded-lg hover:bg-gray-100 dark:hover:bg-gray-600 transition-colors"
          >
            <div class="flex justify-between items-center">
              <div class="flex-1">
                <p class="font-medium text-gray-900 dark:text-gray-100">
                  {if opname_item.item, do: opname_item.item.item_code, else: "N/A"}
                </p>

                <p class="text-sm text-gray-600 dark:text-gray-400">
                  {if opname_item.collection, do: opname_item.collection.title, else: "N/A"}
                </p>
              </div>

              <div class="flex items-center gap-3">
                <.item_check_badge status={opname_item.check_status} />
                <span
                  :if={opname_item.has_changes}
                  class="text-xs text-yellow-600 dark:text-yellow-500"
                >
                  <.icon name="hero-pencil" class="w-4 h-4 inline" /> Modified
                </span>
                <span class="text-xs text-gray-500 dark:text-gray-400">
                  {format_time(opname_item.scanned_at || opname_item.updated_at)}
                </span>
              </div>
            </div>
          </div>
        </div>
      </div>
      <%!-- Complete Work Button --%>
      <div class="mt-6 bg-blue-50 dark:bg-blue-900/20 border border-blue-200 dark:border-blue-800 rounded-lg p-6">
        <div class="flex justify-between items-center">
          <div>
            <h3 class="font-semibold text-blue-900 dark:text-blue-300 mb-1">
              Finished checking items?
            </h3>

            <p class="text-sm text-blue-700 dark:text-blue-400">
              Mark your work session as completed when you're done.
            </p>
          </div>

          <button
            type="button"
            phx-click="complete_work"
            disabled={@librarian_progress.items_checked == 0}
            class="px-6 py-3 bg-blue-600 hover:bg-blue-700 disabled:bg-gray-300 dark:disabled:bg-gray-700 disabled:cursor-not-allowed text-white font-medium rounded-lg transition-colors"
          >
            Complete My Work
          </button>
        </div>
      </div>
    </div>
    """
  end

  def mount(%{"id" => id}, _session, socket) do
    session = StockOpname.get_session_without_items!(id)
    current_user = socket.assigns.current_scope.user

    # Verify permission
    case StockOpnameAuthorization.can_scan_items?(current_user, session) do
      true ->
        # Get librarian progress (handles super admins gracefully)
        case StockOpname.get_librarian_progress(session, current_user) do
          {:ok, librarian_progress} ->
            # Load recent items (database query with LIMIT for efficiency)
            recent_items =
              StockOpname.list_recent_checked_items_by_user(session, current_user, 10)

            # Load locations for the user's node
            locations = load_locations_for_user(current_user)

            socket =
              socket
              |> assign(:page_title, "Scan Items - #{session.title}")
              |> assign(:session, session)
              |> assign(:current_user, current_user)
              |> assign(:librarian_progress, librarian_progress)
              |> assign(:search_term, "")
              |> assign(:current_item, nil)
              |> assign(:duplicate_items, [])
              |> assign(:updated_values, %{})
              |> assign(:locations, locations)
              |> assign(:recent_items_count, length(recent_items))
              |> stream(:recent_items, recent_items)

            {:ok, socket}

          {:error, :not_assigned} ->
            socket =
              socket
              |> put_flash(:error, "You are not assigned to this session.")
              |> redirect(to: ~p"/manage/stock_opname")

            {:ok, socket}
        end

      false ->
        socket =
          socket
          |> put_flash(:error, "You don't have permission to scan items in this session.")
          |> redirect(to: ~p"/manage/stock_opname")

        {:ok, socket}
    end
  end

  def handle_event("scan_item", %{"search_term" => term}, socket) do
    term = String.trim(term)

    if term == "" do
      {:noreply, assign(socket, :search_term, "")}
    else
      items = StockOpname.find_items_for_scanning(socket.assigns.session, term)

      socket =
        case length(items) do
          0 ->
            socket
            |> put_flash(:error, "Item not found: #{term}")
            |> assign(:search_term, "")

          1 ->
            [opname_item] = items
            load_item_for_checking(socket, opname_item)

          _ ->
            socket
            |> assign(:duplicate_items, items)
            |> assign(:search_term, "")
            |> put_flash(:info, "Multiple items found. Please select one.")
        end

      {:noreply, socket}
    end
  end

  def handle_event("select_item", %{"id" => id}, socket) do
    opname_item =
      Enum.find(socket.assigns.duplicate_items, fn item -> item.id == id end)

    socket =
      socket
      |> load_item_for_checking(opname_item)
      |> assign(:duplicate_items, [])

    {:noreply, socket}
  end

  def handle_event("update_field", params, socket) do
    require Logger
    Logger.debug("update_field params: #{inspect(params)}")

    # Get field name from _target
    field =
      case params["_target"] do
        [field_name] -> field_name
        [field_name | _] -> field_name
        _ -> nil
      end

    if field && Map.has_key?(params, field) do
      value = params[field]
      updated_values = Map.put(socket.assigns.updated_values, String.to_atom(field), value)

      Logger.debug("Field updated: #{field} = #{value}")
      Logger.debug("Updated values: #{inspect(updated_values)}")

      {:noreply, assign(socket, :updated_values, updated_values)}
    else
      Logger.debug("Could not extract field from params")
      {:noreply, socket}
    end
  end

  def handle_event("check_item", _params, socket) do
    opname_item = socket.assigns.current_item
    updated = socket.assigns.updated_values
    original_item = opname_item.item

    # Build changes map - only include fields that actually changed
    changes = %{}

    changes =
      if Map.has_key?(updated, :status) && updated.status != original_item.status,
        do: Map.put(changes, "status", updated.status),
        else: changes

    changes =
      if Map.has_key?(updated, :condition) && updated.condition != original_item.condition,
        do: Map.put(changes, "condition", updated.condition),
        else: changes

    changes =
      if Map.has_key?(updated, :availability) &&
           updated.availability != original_item.availability,
         do: Map.put(changes, "availability", updated.availability),
         else: changes

    changes =
      if Map.has_key?(updated, :location) && updated.location != original_item.location,
        do: Map.put(changes, "location", updated.location),
        else: changes

    # Handle item_location_id (convert empty string to nil for comparison)
    updated_location_id =
      case Map.get(updated, :item_location_id) do
        "" -> nil
        nil -> nil
        id when is_binary(id) -> String.to_integer(id)
        id -> id
      end

    changes =
      if Map.has_key?(updated, :item_location_id) &&
           updated_location_id != original_item.item_location_id,
         do: Map.put(changes, "item_location_id", updated_location_id),
         else: changes

    require Logger
    Logger.debug("=== CHECK ITEM DEBUG ===")
    Logger.debug("Updated values: #{inspect(updated)}")

    Logger.debug(
      "Original item: status=#{original_item.status}, condition=#{original_item.condition}, availability=#{original_item.availability}"
    )

    Logger.debug("Changes map: #{inspect(changes)}")
    Logger.debug("Notes: #{inspect(updated.notes)}")

    case StockOpname.check_item(
           socket.assigns.session,
           opname_item.id,
           changes,
           updated.notes,
           socket.assigns.current_user
         ) do
      {:ok, checked_item} ->
        # Refresh session and progress
        session = StockOpname.get_session!(socket.assigns.session.id)

        {:ok, librarian_progress} =
          StockOpname.get_librarian_progress(session, socket.assigns.current_user)

        # Limit stream to 10 items - if we have 10, we need to remove the oldest before adding new
        socket =
          if socket.assigns.recent_items_count >= 10 do
            # Get the 9 most recent items (database will handle filtering and limiting)
            recent =
              StockOpname.list_recent_checked_items_by_user(
                session,
                socket.assigns.current_user,
                9
              )

            socket
            |> stream(:recent_items, [checked_item | recent], reset: true)
            |> assign(:recent_items_count, 10)
          else
            socket
            |> stream_insert(:recent_items, checked_item, at: 0)
            |> assign(:recent_items_count, socket.assigns.recent_items_count + 1)
          end

        socket =
          socket
          |> assign(:session, session)
          |> assign(:librarian_progress, librarian_progress)
          |> assign(:current_item, nil)
          |> assign(:search_term, "")
          |> assign(:updated_values, %{})
          |> put_flash(:info, "Item checked successfully!")

        {:noreply, socket}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to check item")}
    end
  end

  def handle_event("clear_item", _params, socket) do
    socket =
      socket
      |> assign(:current_item, nil)
      |> assign(:search_term, "")
      |> assign(:updated_values, %{})
      |> assign(:duplicate_items, [])

    {:noreply, socket}
  end

  def handle_event("keyboard_shortcut", %{"key" => "Enter", "ctrlKey" => true}, socket) do
    # Ctrl+Enter pressed - trigger check_item if current_item exists
    if socket.assigns.current_item do
      handle_event("check_item", %{}, socket)
    else
      {:noreply, socket}
    end
  end

  def handle_event("keyboard_shortcut", _params, socket) do
    # Other key combinations - ignore
    {:noreply, socket}
  end

  def handle_event("scan_input_keydown", %{"key" => "Enter", "ctrlKey" => true}, socket) do
    # Ctrl+Enter in scan input - if item is loaded, check it
    if socket.assigns.current_item do
      handle_event("check_item", %{}, socket)
    else
      # Otherwise submit the form
      term = String.trim(socket.assigns.search_term)

      if term != "" do
        handle_event("scan_item", %{"search_term" => term}, socket)
      else
        {:noreply, socket}
      end
    end
  end

  def handle_event("scan_input_keydown", %{"key" => "Escape"}, socket) do
    # Escape key - clear the input
    {:noreply, assign(socket, :search_term, "")}
  end

  def handle_event("scan_input_keydown", _params, socket) do
    # Other keys - ignore
    {:noreply, socket}
  end

  def handle_event("update_search_term", %{"search_term" => term}, socket) do
    {:noreply, assign(socket, :search_term, term)}
  end

  def handle_event("complete_work", _params, socket) do
    case StockOpname.complete_librarian_work(
           socket.assigns.session,
           socket.assigns.current_user,
           nil
         ) do
      {:ok, _} ->
        socket =
          socket
          |> put_flash(:info, "Your work session has been completed!")
          |> redirect(to: ~p"/manage/stock_opname/#{socket.assigns.session.id}")

        {:noreply, socket}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to complete work session")}
    end
  end

  defp load_item_for_checking(socket, opname_item) do
    # Check if already checked
    if opname_item.check_status == "checked" do
      socket
      |> put_flash(:warning, "This item has already been checked.")
      |> assign(:search_term, "")
    else
      # Load the current values from the actual item
      # Initialize updated_values with current item values
      updated_values = %{
        status: opname_item.item.status,
        condition: opname_item.item.condition,
        availability: opname_item.item.availability,
        location: opname_item.item.location,
        item_location_id: opname_item.item.item_location_id,
        notes: opname_item.notes || ""
      }

      socket
      |> assign(:current_item, opname_item)
      |> assign(:updated_values, updated_values)
      |> assign(:search_term, "")
    end
  end

  defp calculate_progress(checked, total) do
    if total > 0, do: Float.round(checked / total * 100, 1), else: 0
  end

  defp session_status_badge(assigns) do
    color =
      case assigns.status do
        "in_progress" -> "bg-blue-100 text-blue-800"
        "completed" -> "bg-yellow-100 text-yellow-800"
        _ -> "bg-gray-100 text-gray-800"
      end

    label =
      case assigns.status do
        "in_progress" -> "In Progress"
        "completed" -> "Completed"
        _ -> assigns.status
      end

    assigns = assign(assigns, :color, color) |> assign(:label, label)

    ~H"""
    <span class={"inline-flex items-center px-3 py-1 text-sm font-medium rounded-full #{@color}"}>
      {@label}
    </span>
    """
  end

  defp item_check_badge(assigns) do
    {color, label} =
      case assigns.status do
        "pending" -> {"bg-gray-100 text-gray-700", "Pending"}
        "checked" -> {"bg-green-100 text-green-700", "Checked"}
        "missing" -> {"bg-red-100 text-red-700", "Missing"}
        "needs_attention" -> {"bg-yellow-100 text-yellow-700", "Attention"}
        _ -> {"bg-gray-100 text-gray-700", assigns.status}
      end

    assigns = assign(assigns, :color, color) |> assign(:label, label)

    ~H"""
    <span class={"inline-flex items-center px-2 py-1 text-xs font-medium rounded #{@color}"}>
      {@label}
    </span>
    """
  end

  defp format_time(nil), do: ""

  defp format_time(datetime) do
    Calendar.strftime(datetime, "%H:%M:%S")
  end

  defp load_locations_for_user(user) do
    # Get user's node_id from their roles or default node
    node_id = get_user_node_id(user)

    from(l in Location,
      where: l.is_active == true,
      where: l.node_id == ^node_id,
      order_by: [asc: l.location_name]
    )
    |> Voile.Repo.all()
  end

  defp get_user_node_id(user) do
    # Try to get node_id from user's roles, otherwise use a default
    # This assumes you have a way to determine user's node
    # Adjust based on your actual implementation
    case user do
      %{roles: [%{node_id: node_id} | _]} when not is_nil(node_id) -> node_id
      # Default node if none found
      _ -> 1
    end
  end
end
