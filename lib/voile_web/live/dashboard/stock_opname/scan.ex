defmodule VoileWeb.Dashboard.StockOpnameLive.Scan do
  use VoileWeb, :live_view_dashboard

  alias Voile.Schema.Catalog
  alias Voile.Schema.Catalog.Item
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
                phx-hook="AutoFocus"
                id="scan-input"
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
         <%!-- Keyboard Shortcuts Help --%>
        <div class="text-xs text-gray-500 flex gap-4">
          <span>
            <kbd class="px-2 py-1 bg-gray-100 rounded">Ctrl+Enter</kbd> Quick check (no changes)
          </span> <span><kbd class="px-2 py-1 bg-gray-100 rounded">Esc</kbd> Clear input</span>
        </div>
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
      <div :if={@current_item} class="bg-white rounded-lg shadow-lg p-6 mb-6">
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
        
        <div class="grid grid-cols-1 md:grid-cols-2 gap-6 mb-6">
          <%!-- Current Values (Before) --%>
          <div class="space-y-3">
            <h4 class="font-medium text-gray-700 border-b pb-2">Current Information</h4>
            
            <div>
              <label class="text-xs font-medium text-gray-500">Item Code</label>
              <p class="text-sm font-mono">{@current_item.item_code}</p>
            </div>
            
            <div>
              <label class="text-xs font-medium text-gray-500">Inventory Code</label>
              <p class="text-sm font-mono">{@current_item.inventory_code}</p>
            </div>
            
            <div :if={@current_item.barcode}>
              <label class="text-xs font-medium text-gray-500">Barcode</label>
              <p class="text-sm font-mono">{@current_item.barcode}</p>
            </div>
            
            <div :if={@current_item.legacy_item_code}>
              <label class="text-xs font-medium text-gray-500">Legacy Item Code</label>
              <p class="text-sm font-mono">{@current_item.legacy_item_code}</p>
            </div>
            
            <div>
              <label class="text-xs font-medium text-gray-500">Collection</label>
              <p class="text-sm">{@current_item.collection_title}</p>
            </div>
          </div>
           <%!-- Update Form --%>
          <div class="space-y-3">
            <h4 class="font-medium text-gray-700 border-b pb-2">Update Information</h4>
            
            <div>
              <label class="block text-xs font-medium text-gray-700 mb-1">Status</label>
              <select
                name="status"
                phx-change="update_field"
                class="w-full rounded-lg border-gray-300 text-sm"
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
              <label class="block text-xs font-medium text-gray-700 mb-1">Condition</label>
              <select
                name="condition"
                phx-change="update_field"
                class="w-full rounded-lg border-gray-300 text-sm"
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
              <label class="block text-xs font-medium text-gray-700 mb-1">Availability</label>
              <select
                name="availability"
                phx-change="update_field"
                class="w-full rounded-lg border-gray-300 text-sm"
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
            
            <div>
              <label class="block text-xs font-medium text-gray-700 mb-1">Location</label>
              <input
                type="text"
                name="location"
                value={@updated_values.location}
                phx-change="update_field"
                phx-debounce="300"
                class="w-full rounded-lg border-gray-300 text-sm"
              />
            </div>
            
            <div>
              <label class="block text-xs font-medium text-gray-700 mb-1">Notes</label> <textarea
                name="notes"
                phx-change="update_field"
                phx-debounce="300"
                rows="3"
                class="w-full rounded-lg border-gray-300 text-sm"
              >{@updated_values.notes}</textarea>
            </div>
          </div>
        </div>
         <%!-- Actions --%>
        <div class="flex gap-3 pt-4 border-t border-gray-200">
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
      </div>
       <%!-- Recently Scanned Items --%>
      <div class="bg-white rounded-lg shadow-sm p-6">
        <h3 class="text-lg font-semibold text-gray-900 mb-4">Recently Scanned</h3>
        
        <div id="recently-scanned" phx-update="stream" class="space-y-2">
          <div
            :for={{dom_id, opname_item} <- @streams.recent_items}
            id={dom_id}
            class="p-3 bg-gray-50 rounded-lg hover:bg-gray-100 transition-colors"
          >
            <div class="flex justify-between items-center">
              <div class="flex-1">
                <p class="font-medium text-gray-900">{opname_item.item_code}</p>
                
                <p class="text-sm text-gray-600">{opname_item.collection_title}</p>
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
        
        <div :if={length(@streams.recent_items) == 0} class="text-center text-gray-500 py-8">
          <.icon name="hero-inbox" class="w-12 h-12 mx-auto mb-2 text-gray-400" />
          <p>No items scanned yet. Start scanning to see items here.</p>
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
    session = Catalog.get_stock_opname_session!(id)
    current_user = socket.assigns.current_scope.user

    # Verify permission
    case StockOpnameAuthorization.can_scan_items?(current_user, session) do
      true ->
        {:ok, librarian_progress} = Catalog.get_librarian_progress(session, current_user)

        # Load recent items
        recent_items =
          Catalog.list_session_items(session, "checked")
          |> Enum.filter(fn item -> item.checked_by_id == current_user.id end)
          |> Enum.take(10)

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
          |> stream(:recent_items, recent_items)

        {:ok, socket}

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
      items = Catalog.find_items_for_scanning(socket.assigns.session, term)

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

    attrs = %{
      "status_after" => updated.status,
      "condition_after" => updated.condition,
      "availability_after" => updated.availability,
      "location_after" => updated.location,
      "notes" => updated.notes
    }

    case Catalog.check_item_in_session(
           socket.assigns.session,
           opname_item.id,
           attrs,
           socket.assigns.current_user
         ) do
      {:ok, checked_item} ->
        # Refresh session and progress
        session = Catalog.get_stock_opname_session!(socket.assigns.session.id)

        {:ok, librarian_progress} =
          Catalog.get_librarian_progress(session, socket.assigns.current_user)

        socket =
          socket
          |> assign(:session, session)
          |> assign(:librarian_progress, librarian_progress)
          |> assign(:current_item, nil)
          |> assign(:search_term, "")
          |> assign(:updated_values, %{})
          |> stream_insert(:recent_items, checked_item, at: 0)
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

  def handle_event("complete_work", _params, socket) do
    case Catalog.complete_librarian_work(
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
      updated_values = %{
        status: opname_item.status_before,
        condition: opname_item.condition_before,
        availability: opname_item.availability_before,
        location: opname_item.location_before,
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
