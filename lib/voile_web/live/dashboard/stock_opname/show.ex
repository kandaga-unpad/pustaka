defmodule VoileWeb.Dashboard.StockOpnameLive.Show do
  use VoileWeb, :live_view_dashboard

  alias Voile.Schema.Catalog
  alias VoileWeb.Auth.StockOpnameAuthorization

  def render(assigns) do
    ~H"""
    <div class="container mx-auto px-4 py-6">
      <%!-- Header --%>
      <div class="mb-6">
        <.link
          navigate={~p"/manage/stock-opname"}
          class="text-blue-600 hover:text-blue-700 flex items-center gap-2 mb-4"
        >
          <.icon name="hero-arrow-left" class="w-4 h-4" /> Back to Sessions
        </.link>
        <div class="flex justify-between items-start">
          <div>
            <h1 class="text-3xl font-bold text-gray-900">{@session.title}</h1>
            
            <p class="text-gray-600 mt-1">Code: {@session.session_code}</p>
            
            <p :if={@session.description} class="text-gray-600 text-sm mt-2">
              {@session.description}
            </p>
          </div>
           <.session_status_badge status={@session.status} />
        </div>
      </div>
       <%!-- Session Info Card --%>
      <div class="bg-white rounded-lg shadow-sm p-6 mb-6">
        <h2 class="text-lg font-semibold text-gray-900 mb-4">Session Information</h2>
        
        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
          <div>
            <p class="text-xs font-medium text-gray-500">Created By</p>
            
            <p class="text-sm mt-1">{@session.created_by.full_name || @session.created_by.email}</p>
          </div>
          
          <div>
            <p class="text-xs font-medium text-gray-500">Created Date</p>
            
            <p class="text-sm mt-1">{format_date(@session.inserted_at)}</p>
          </div>
          
          <div :if={@session.started_at}>
            <p class="text-xs font-medium text-gray-500">Started</p>
            
            <p class="text-sm mt-1">{format_datetime(@session.started_at)}</p>
          </div>
          
          <div :if={@session.completed_at}>
            <p class="text-xs font-medium text-gray-500">Completed</p>
            
            <p class="text-sm mt-1">{format_datetime(@session.completed_at)}</p>
          </div>
        </div>
      </div>
       <%!-- Statistics Cards --%>
      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4 mb-6">
        <div class="bg-white rounded-lg shadow-sm p-6">
          <div class="flex items-center justify-between mb-2">
            <p class="text-sm font-medium text-gray-600">Total Items</p>
             <.icon name="hero-inbox-stack" class="w-6 h-6 text-gray-400" />
          </div>
          
          <p class="text-3xl font-bold text-gray-900">{@session.total_items}</p>
        </div>
        
        <div class="bg-white rounded-lg shadow-sm p-6">
          <div class="flex items-center justify-between mb-2">
            <p class="text-sm font-medium text-gray-600">Checked</p>
             <.icon name="hero-check-circle" class="w-6 h-6 text-green-400" />
          </div>
          
          <p class="text-3xl font-bold text-green-600">{@session.checked_items}</p>
          
          <div class="mt-2 w-full bg-gray-200 rounded-full h-2">
            <div
              class="bg-green-600 h-2 rounded-full"
              style={"width: #{calculate_progress(@session)}%"}
            >
            </div>
          </div>
        </div>
        
        <div class="bg-white rounded-lg shadow-sm p-6">
          <div class="flex items-center justify-between mb-2">
            <p class="text-sm font-medium text-gray-600">Missing</p>
             <.icon name="hero-exclamation-triangle" class="w-6 h-6 text-red-400" />
          </div>
          
          <p class="text-3xl font-bold text-red-600">{@session.missing_items}</p>
        </div>
        
        <div class="bg-white rounded-lg shadow-sm p-6">
          <div class="flex items-center justify-between mb-2">
            <p class="text-sm font-medium text-gray-600">With Changes</p>
             <.icon name="hero-pencil" class="w-6 h-6 text-yellow-400" />
          </div>
          
          <p class="text-3xl font-bold text-yellow-600">{@session.items_with_changes}</p>
        </div>
      </div>
       <%!-- Librarian Progress (Admin Only) --%>
      <div :if={@can_create} class="bg-white rounded-lg shadow-sm p-6 mb-6">
        <h2 class="text-lg font-semibold text-gray-900 mb-4">Librarian Progress</h2>
        
        <div class="space-y-3">
          <div
            :for={assignment <- @session.librarian_assignments}
            class="flex items-center justify-between p-3 bg-gray-50 rounded-lg"
          >
            <div class="flex-1">
              <p class="font-medium text-gray-900">
                {assignment.user.full_name || assignment.user.email}
              </p>
              
              <p class="text-sm text-gray-600">{assignment.user.email}</p>
            </div>
            
            <div class="flex items-center gap-4">
              <div class="text-right">
                <p class="text-sm font-medium text-gray-900">{assignment.items_checked} items</p>
                
                <p class="text-xs text-gray-500">checked</p>
              </div>
               <.work_status_badge status={assignment.work_status} />
            </div>
          </div>
        </div>
      </div>
       <%!-- Actions --%>
      <div class="flex gap-3 mb-6 flex-wrap">
        <.link
          :if={@can_scan and @session.status == "in_progress"}
          navigate={~p"/manage/stock-opname/#{@session.id}/scan"}
          class="px-4 py-2 bg-blue-600 hover:bg-blue-700 text-white font-medium rounded-lg transition-colors"
        >
          <.icon name="hero-qr-code" class="w-5 h-5 inline mr-2" /> Continue Scanning
        </.link>
        <.link
          :if={@can_create and @session.status == "pending_review"}
          navigate={~p"/manage/stock-opname/#{@session.id}/review"}
          class="px-4 py-2 bg-green-600 hover:bg-green-700 text-white font-medium rounded-lg transition-colors"
        >
          <.icon name="hero-clipboard-document-check" class="w-5 h-5 inline mr-2" /> Review & Approve
        </.link>
        <button
          :if={@can_create and @session.status == "in_progress" and @all_librarians_completed}
          phx-click="complete_session"
          class="px-4 py-2 bg-orange-600 hover:bg-orange-700 text-white font-medium rounded-lg transition-colors"
        >
          Complete Session
        </button>
      </div>
       <%!-- Tabs --%>
      <div class="bg-white rounded-lg shadow-sm">
        <div class="border-b border-gray-200">
          <nav class="flex -mb-px">
            <button
              :for={tab <- ["all", "checked", "pending", "missing", "with_changes"]}
              phx-click="change_tab"
              phx-value-tab={tab}
              class={[
                "px-6 py-3 text-sm font-medium border-b-2 transition-colors",
                if(@current_tab == tab,
                  do: "border-blue-600 text-blue-600",
                  else: "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300"
                )
              ]}
            >
              {tab_label(tab)} ({tab_count(tab, @session, @items_by_status)})
            </button>
          </nav>
        </div>
         <%!-- Items List --%>
        <div class="p-6">
          <div class="space-y-2">
            <div
              :for={item <- @displayed_items}
              class="p-4 border border-gray-200 rounded-lg hover:border-gray-300 transition-colors"
            >
              <div class="flex justify-between items-start mb-2">
                <div class="flex-1">
                  <p class="font-medium text-gray-900">{item.item_code}</p>
                  
                  <p class="text-sm text-gray-600">{item.collection_title}</p>
                </div>
                 <.item_check_badge status={item.check_status} />
              </div>
              
              <div class="grid grid-cols-2 md:grid-cols-4 gap-3 text-xs text-gray-600">
                <div><span class="font-medium">Inventory:</span> {item.inventory_code}</div>
                
                <div :if={item.barcode}><span class="font-medium">Barcode:</span> {item.barcode}</div>
                
                <div :if={item.legacy_item_code}>
                  <span class="font-medium">Legacy:</span> {item.legacy_item_code}
                </div>
                
                <div :if={item.checked_by}>
                  <span class="font-medium">Checked by:</span> {item.checked_by.full_name ||
                    item.checked_by.email}
                </div>
              </div>
               <%!-- Show changes if any --%>
              <div :if={item.has_changes} class="mt-3 pt-3 border-t border-gray-200">
                <p class="text-xs font-medium text-yellow-700 mb-2">Changes:</p>
                
                <div class="grid grid-cols-2 gap-2 text-xs">
                  <div :if={item.status_before != item.status_after}>
                    <span class="text-gray-500">Status:</span>
                    <span class="line-through text-gray-400">{item.status_before}</span>
                    → <span class="text-green-600">{item.status_after}</span>
                  </div>
                  
                  <div :if={item.condition_before != item.condition_after}>
                    <span class="text-gray-500">Condition:</span>
                    <span class="line-through text-gray-400">{item.condition_before}</span>
                    → <span class="text-green-600">{item.condition_after}</span>
                  </div>
                  
                  <div :if={item.availability_before != item.availability_after}>
                    <span class="text-gray-500">Availability:</span>
                    <span class="line-through text-gray-400">{item.availability_before}</span>
                    → <span class="text-green-600">{item.availability_after}</span>
                  </div>
                  
                  <div :if={item.location_before != item.location_after}>
                    <span class="text-gray-500">Location:</span>
                    <span class="line-through text-gray-400">{item.location_before}</span>
                    → <span class="text-green-600">{item.location_after}</span>
                  </div>
                </div>
              </div>
              
              <div :if={item.notes} class="mt-2 text-xs text-gray-600">
                <span class="font-medium">Notes:</span> {item.notes}
              </div>
            </div>
          </div>
          
          <div :if={@displayed_items == []} class="text-center py-12">
            <.icon name="hero-inbox" class="w-16 h-16 mx-auto text-gray-400 mb-4" />
            <p class="text-gray-500">No items in this category</p>
          </div>
        </div>
      </div>
    </div>
    """
  end

  def mount(%{"id" => id}, _session, socket) do
    session = Catalog.get_stock_opname_session!(id)
    current_user = socket.assigns.current_scope.user
    can_create = StockOpnameAuthorization.can_create_session?(current_user)
    can_scan = StockOpnameAuthorization.can_scan_items?(current_user, session)

    all_items = Catalog.list_session_items(session)
    items_by_status = Enum.group_by(all_items, & &1.check_status)

    socket =
      socket
      |> assign(:page_title, session.title)
      |> assign(:session, session)
      |> assign(:current_user, current_user)
      |> assign(:can_create, can_create)
      |> assign(:can_scan, can_scan)
      |> assign(:all_items, all_items)
      |> assign(:items_by_status, items_by_status)
      |> assign(:current_tab, "all")
      |> assign(:displayed_items, all_items)
      |> assign(:all_librarians_completed, Catalog.all_librarians_completed?(session))

    {:ok, socket}
  end

  def handle_event("change_tab", %{"tab" => tab}, socket) do
    items =
      case tab do
        "all" -> socket.assigns.all_items
        "checked" -> Map.get(socket.assigns.items_by_status, "checked", [])
        "pending" -> Map.get(socket.assigns.items_by_status, "pending", [])
        "missing" -> Map.get(socket.assigns.items_by_status, "missing", [])
        "with_changes" -> Enum.filter(socket.assigns.all_items, & &1.has_changes)
        _ -> socket.assigns.all_items
      end

    socket =
      socket
      |> assign(:current_tab, tab)
      |> assign(:displayed_items, items)

    {:noreply, socket}
  end

  def handle_event("complete_session", _params, socket) do
    case Catalog.complete_stock_opname_session(
           socket.assigns.session,
           socket.assigns.current_user
         ) do
      {:ok, _session} ->
        socket =
          socket
          |> put_flash(:info, "Session completed and ready for review!")
          |> redirect(to: ~p"/manage/stock-opname")

        {:noreply, socket}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to complete session")}
    end
  end

  defp calculate_progress(session) do
    if session.total_items > 0 do
      Float.round(session.checked_items / session.total_items * 100, 1)
    else
      0
    end
  end

  defp tab_label(tab) do
    case tab do
      "all" -> "All Items"
      "checked" -> "Checked"
      "pending" -> "Pending"
      "missing" -> "Missing"
      "with_changes" -> "With Changes"
      _ -> tab
    end
  end

  defp tab_count(tab, session, _items_by_status) do
    case tab do
      "all" -> session.total_items
      "checked" -> session.checked_items
      "pending" -> session.total_items - session.checked_items - session.missing_items
      "missing" -> session.missing_items
      "with_changes" -> session.items_with_changes
      _ -> 0
    end
  end

  defp session_status_badge(assigns) do
    # Same as in Index
    color =
      case assigns.status do
        "draft" -> "bg-gray-100 text-gray-800"
        "in_progress" -> "bg-blue-100 text-blue-800"
        "completed" -> "bg-yellow-100 text-yellow-800"
        "pending_review" -> "bg-orange-100 text-orange-800"
        "approved" -> "bg-green-100 text-green-800"
        "rejected" -> "bg-red-100 text-red-800"
        _ -> "bg-gray-100 text-gray-800"
      end

    assigns = assign(assigns, :color, color)

    ~H"""
    <span class={"inline-flex items-center px-3 py-1 text-sm font-medium rounded-full #{@color}"}>
      {@status}
    </span>
    """
  end

  defp work_status_badge(assigns) do
    color =
      case assigns.status do
        "pending" -> "bg-gray-100 text-gray-700"
        "in_progress" -> "bg-blue-100 text-blue-700"
        "completed" -> "bg-green-100 text-green-700"
        _ -> "bg-gray-100 text-gray-700"
      end

    assigns = assign(assigns, :color, color)

    ~H"""
    <span class={"inline-flex items-center px-2 py-1 text-xs font-medium rounded #{@color}"}>
      {@status}
    </span>
    """
  end

  defp item_check_badge(assigns) do
    color =
      case assigns.status do
        "pending" -> "bg-gray-100 text-gray-700"
        "checked" -> "bg-green-100 text-green-700"
        "missing" -> "bg-red-100 text-red-700"
        "needs_attention" -> "bg-yellow-100 text-yellow-700"
        _ -> "bg-gray-100 text-gray-700"
      end

    assigns = assign(assigns, :color, color)

    ~H"""
    <span class={"inline-flex items-center px-2 py-1 text-xs font-medium rounded #{@color}"}>
      {@status}
    </span>
    """
  end

  defp format_date(datetime), do: Calendar.strftime(datetime, "%B %d, %Y")
  defp format_datetime(datetime), do: Calendar.strftime(datetime, "%B %d, %Y %I:%M %p")
end
