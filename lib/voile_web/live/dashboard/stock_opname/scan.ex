defmodule VoileWeb.Dashboard.StockOpnameLive.Scan do
  use VoileWeb, :live_view_dashboard

  alias Voile.Schema.Catalog.Item
  alias Voile.Schema.StockOpname
  alias VoileWeb.Auth.StockOpnameAuthorization

  def render(assigns) do
    ~H"""
    <div class="container mx-auto px-4 py-6">
      <%!-- Header --%>
      <div class="mb-6">
        <.link
          navigate={~p"/manage/stock-opname/#{@session.id}"}
          class="text-blue-600 hover:text-blue-700 flex items-center gap-2 mb-4"
        >
          <.icon name="hero-arrow-left" class="w-4 h-4" /> Back to Session
        </.link>
        <div class="flex justify-between items-start">
          <div>
            <h1 class="text-3xl font-bold text-gray-900">{@session.title}</h1>
            
            <p class="text-gray-600">Session Code: {@session.session_code}</p>
          </div>
           <.session_status_badge status={@session.status} />
        </div>
      </div>
       <%!-- Progress Bar --%>
      <div class="bg-white rounded-lg shadow-sm p-6 mb-6">
        <div class="flex justify-between items-center mb-2">
          <h2 class="text-lg font-semibold text-gray-900">Your Progress</h2>
          
          <span class="text-sm text-gray-600">
            {@librarian_progress.items_checked} / {@session.total_items} items
          </span>
        </div>
        
        <div class="w-full bg-gray-200 rounded-full h-3 mb-4">
          <div
            class="bg-blue-600 h-3 rounded-full transition-all duration-500"
            style={"width: #{calculate_progress(@librarian_progress.items_checked, @session.total_items)}%"}
          >
          </div>
        </div>
         <%!-- Statistics --%>
        <div class="grid grid-cols-2 md:grid-cols-4 gap-4">
          <div class="text-center">
            <p class="text-2xl font-bold text-blue-600">{@session.checked_items}</p>
            
            <p class="text-xs text-gray-500">Total Checked</p>
          </div>
          
          <div class="text-center">
            <p class="text-2xl font-bold text-gray-600">
              {@session.total_items - @session.checked_items}
            </p>
            
            <p class="text-xs text-gray-500">Remaining</p>
          </div>
          
          <div class="text-center">
            <p class="text-2xl font-bold text-yellow-600">{@session.items_with_changes}</p>
            
            <p class="text-xs text-gray-500">With Changes</p>
          </div>
          
          <div class="text-center">
            <p class="text-2xl font-bold text-green-600">{@librarian_progress.items_checked}</p>
            
            <p class="text-xs text-gray-500">Your Checks</p>
          </div>
        </div>
      </div>
       <%!-- Scanner Interface --%>
      <div class="bg-white rounded-lg shadow-sm p-6 mb-6">
        <h2 class="text-lg font-semibold text-gray-900 mb-4">Scan Item</h2>
        
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
                class="w-full px-4 py-3 text-lg border-2 border-gray-300 rounded-lg focus:border-blue-500 focus:ring-2 focus:ring-blue-200"
              />
            </div>
            
            <button
              type="submit"
              class="px-6 py-3 bg-blue-600 hover:bg-blue-700 text-white font-medium rounded-lg transition-colors"
            >
              <.icon name="hero-magnifying-glass" class="w-6 h-6" />
            </button>
          </div>
          
          <p class="text-xs text-gray-500 mt-2">
            Supports barcode, legacy item code, or item code search
          </p>
        </form>
      </div>
       <%!-- Duplicate Results (if multiple items found) --%>
      <div
        :if={@duplicate_items != []}
        class="bg-yellow-50 border border-yellow-200 rounded-lg p-6 mb-6"
      >
        <h3 class="text-lg font-semibold text-yellow-900 mb-4">Multiple Items Found - Select One</h3>
        
        <div class="space-y-3">
          <button
            :for={opname_item <- @duplicate_items}
            type="button"
            phx-click="select_item"
            phx-value-id={opname_item.id}
            class="w-full text-left p-4 bg-white border-2 border-yellow-300 hover:border-yellow-500 rounded-lg transition-colors"
          >
            <div class="flex justify-between items-start">
              <div class="flex-1">
                <p class="font-semibold text-gray-900">{opname_item.item_code}</p>
                
                <p class="text-sm text-gray-600">{opname_item.collection_title}</p>
                
                <div class="flex gap-4 mt-2 text-xs text-gray-500">
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
        class="bg-white rounded-lg shadow-lg p-6 mb-6"
        phx-window-keydown="keyboard_shortcut"
        phx-key="Enter"
      >
        <div class="flex justify-between items-start mb-4">
          <h3 class="text-xl font-semibold text-gray-900">Item Details</h3>
          
          <button
            type="button"
            phx-click="clear_item"
            class="text-gray-400 hover:text-gray-600"
          >
            <.icon name="hero-x-mark" class="w-6 h-6" />
          </button>
        </div>
         <%!-- Actions at Top --%>
        <div class="flex gap-3 mb-6 pb-4 border-b border-gray-200">
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
            class="px-4 py-3 bg-gray-200 hover:bg-gray-300 text-gray-700 font-medium rounded-lg transition-colors"
          >
            Cancel
          </button>
        </div>
        
        <div class="space-y-6">
          <%!-- Identification Section --%>
          <div class="bg-gradient-to-r from-blue-50 to-indigo-50 rounded-lg p-6">
            <h4 class="font-semibold text-gray-800 mb-4 flex items-center gap-2">
              <.icon name="hero-identification" class="w-5 h-5 text-blue-600" /> Item Identification
            </h4>
            
            <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-2">
                  Item Code <span class="text-gray-400 text-xs">(Read-only)</span>
                </label>
                <div class="bg-white px-4 py-3 rounded-lg border border-gray-200 font-mono text-sm text-gray-700">
                  {@current_item.item.item_code}
                </div>
              </div>
              
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-2">
                  Inventory Code <span class="text-gray-400 text-xs">(Read-only)</span>
                </label>
                <div class="bg-white px-4 py-3 rounded-lg border border-gray-200 font-mono text-sm text-gray-700">
                  {@current_item.item.inventory_code}
                </div>
              </div>
              
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-2">
                  Barcode <span class="text-gray-400 text-xs">(Read-only)</span>
                </label>
                <div class="bg-white px-4 py-3 rounded-lg border border-gray-200 font-mono text-sm text-gray-700">
                  {@current_item.item.barcode || "N/A"}
                </div>
              </div>
              
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-2">
                  Legacy Item Code <span class="text-gray-400 text-xs">(Read-only)</span>
                </label>
                <div class="bg-white px-4 py-3 rounded-lg border border-gray-200 font-mono text-sm text-gray-700">
                  {@current_item.item.legacy_item_code || "N/A"}
                </div>
              </div>
            </div>
            
            <div class="mt-4">
              <label class="block text-sm font-medium text-gray-700 mb-2">
                Collection <span class="text-gray-400 text-xs">(Read-only)</span>
              </label>
              <div class="bg-white px-4 py-3 rounded-lg border border-gray-200 text-sm text-gray-700">
                {@current_item.collection.title}
              </div>
            </div>
          </div>
           <%!-- Status & Condition Section --%>
          <div class="bg-gradient-to-r from-green-50 to-emerald-50 rounded-lg p-6">
            <h4 class="font-semibold text-gray-800 mb-4 flex items-center gap-2">
              <.icon name="hero-clipboard-document-check" class="w-5 h-5 text-green-600" />
              Status & Condition
            </h4>
            
            <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-2">Status</label>
                <select
                  name="status"
                  phx-change="update_field"
                  class="w-full px-4 py-3 rounded-lg border-2 border-gray-200 focus:border-green-500 focus:ring-2 focus:ring-green-200 transition-all text-sm bg-white"
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
                <label class="block text-sm font-medium text-gray-700 mb-2">Condition</label>
                <select
                  name="condition"
                  phx-change="update_field"
                  class="w-full px-4 py-3 rounded-lg border-2 border-gray-200 focus:border-green-500 focus:ring-2 focus:ring-green-200 transition-all text-sm bg-white"
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
                <label class="block text-sm font-medium text-gray-700 mb-2">Availability</label>
                <select
                  name="availability"
                  phx-change="update_field"
                  class="w-full px-4 py-3 rounded-lg border-2 border-gray-200 focus:border-green-500 focus:ring-2 focus:ring-green-200 transition-all text-sm bg-white"
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
          </div>
           <%!-- Location & Notes Section --%>
          <div class="bg-gradient-to-r from-purple-50 to-pink-50 rounded-lg p-6">
            <h4 class="font-semibold text-gray-800 mb-4 flex items-center gap-2">
              <.icon name="hero-map-pin" class="w-5 h-5 text-purple-600" /> Location & Notes
            </h4>
            
            <div class="space-y-4">
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-2">Location</label>
                <input
                  type="text"
                  name="location"
                  value={@updated_values.location}
                  phx-change="update_field"
                  phx-debounce="300"
                  placeholder="Enter item location"
                  class="w-full px-4 py-3 rounded-lg border-2 border-gray-200 focus:border-purple-500 focus:ring-2 focus:ring-purple-200 transition-all text-sm"
                />
              </div>
              
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-2">Notes</label> <textarea
                  name="notes"
                  phx-change="update_field"
                  phx-debounce="300"
                  rows="4"
                  placeholder="Add any observations or remarks..."
                  class="w-full px-4 py-3 rounded-lg border-2 border-gray-200 focus:border-purple-500 focus:ring-2 focus:ring-purple-200 transition-all text-sm resize-none"
                >{@updated_values.notes}</textarea>
              </div>
            </div>
          </div>
        </div>
      </div>
       <%!-- Recently Scanned Items --%>
      <div class="bg-white rounded-lg shadow-sm p-6">
        <h3 class="text-lg font-semibold text-gray-900 mb-4">Recently Scanned</h3>
        
        <div id="recently-scanned" phx-update="stream" class="space-y-2">
          <div id="empty-state" class="hidden only:block text-center text-gray-500 py-8">
            <.icon name="hero-inbox" class="w-12 h-12 mx-auto mb-2 text-gray-400" />
            <p>No items scanned yet. Start scanning to see items here.</p>
          </div>
          
          <div
            :for={{dom_id, opname_item} <- @streams.recent_items}
            id={dom_id}
            class="p-3 bg-gray-50 rounded-lg hover:bg-gray-100 transition-colors"
          >
            <div class="flex justify-between items-center">
              <div class="flex-1">
                <p class="font-medium text-gray-900">
                  {if opname_item.item, do: opname_item.item.item_code, else: "N/A"}
                </p>
                
                <p class="text-sm text-gray-600">
                  {if opname_item.collection, do: opname_item.collection.title, else: "N/A"}
                </p>
              </div>
              
              <div class="flex items-center gap-3">
                <.item_check_badge status={opname_item.check_status} />
                <span :if={opname_item.has_changes} class="text-xs text-yellow-600">
                  <.icon name="hero-pencil" class="w-4 h-4 inline" /> Modified
                </span>
                <span class="text-xs text-gray-500">
                  {format_time(opname_item.scanned_at || opname_item.updated_at)}
                </span>
              </div>
            </div>
          </div>
        </div>
      </div>
       <%!-- Complete Work Button --%>
      <div class="mt-6 bg-blue-50 border border-blue-200 rounded-lg p-6">
        <div class="flex justify-between items-center">
          <div>
            <h3 class="font-semibold text-blue-900 mb-1">Finished checking items?</h3>
            
            <p class="text-sm text-blue-700">Mark your work session as completed when you're done.</p>
          </div>
          
          <button
            type="button"
            phx-click="complete_work"
            disabled={@librarian_progress.items_checked == 0}
            class="px-6 py-3 bg-blue-600 hover:bg-blue-700 disabled:bg-gray-300 disabled:cursor-not-allowed text-white font-medium rounded-lg transition-colors"
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
              |> assign(:recent_items_count, length(recent_items))
              |> stream(:recent_items, recent_items)

            {:ok, socket}

          {:error, :not_assigned} ->
            socket =
              socket
              |> put_flash(:error, "You are not assigned to this session.")
              |> redirect(to: ~p"/manage/stock-opname")

            {:ok, socket}
        end

      false ->
        socket =
          socket
          |> put_flash(:error, "You don't have permission to scan items in this session.")
          |> redirect(to: ~p"/manage/stock-opname")

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
    field = elem(Enum.at(params, 0), 0)
    value = elem(Enum.at(params, 0), 1)

    updated_values = Map.put(socket.assigns.updated_values, String.to_atom(field), value)

    {:noreply, assign(socket, :updated_values, updated_values)}
  end

  def handle_event("check_item", _params, socket) do
    opname_item = socket.assigns.current_item
    updated = socket.assigns.updated_values
    original_item = opname_item.item

    # Build changes map - only include fields that actually changed
    changes = %{}

    changes =
      if updated.status && updated.status != original_item.status,
        do: Map.put(changes, "status", updated.status),
        else: changes

    changes =
      if updated.condition && updated.condition != original_item.condition,
        do: Map.put(changes, "condition", updated.condition),
        else: changes

    changes =
      if updated.availability && updated.availability != original_item.availability,
        do: Map.put(changes, "availability", updated.availability),
        else: changes

    changes =
      if updated.location && updated.location != original_item.location,
        do: Map.put(changes, "location", updated.location),
        else: changes

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
    # Ctrl+Enter in scan input - submit the form
    term = String.trim(socket.assigns.search_term)

    if term != "" do
      handle_event("scan_item", %{"search_term" => term}, socket)
    else
      {:noreply, socket}
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
          |> redirect(to: ~p"/manage/stock-opname/#{socket.assigns.session.id}")

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
end
