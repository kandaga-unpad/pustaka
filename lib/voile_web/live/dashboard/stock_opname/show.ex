defmodule VoileWeb.Dashboard.StockOpnameLive.Show do
  use VoileWeb, :live_view_dashboard

  alias Voile.Schema.StockOpname
  alias VoileWeb.Auth.StockOpnameAuthorization
  alias VoileWeb.Utils.FormatIndonesiaTime

  def render(assigns) do
    ~H"""
    <div class="container mx-auto px-4 py-6">
      <%!-- Header --%>
      <div class="mb-6">
        <.link
          navigate={~p"/manage/stock_opname"}
          class="text-blue-600 hover:text-blue-700 dark:text-blue-400 dark:hover:text-blue-300 flex items-center gap-2 mb-4"
        >
          <.icon name="hero-arrow-left" class="w-4 h-4" /> Back to Sessions
        </.link>
        <div class="flex justify-between items-start">
          <div>
            <h1 class="text-3xl font-bold text-gray-900 dark:text-gray-100">{@session.title}</h1>

            <p class="text-gray-600 dark:text-gray-400 mt-1">Code: {@session.session_code}</p>

            <p :if={@session.description} class="text-gray-600 dark:text-gray-400 text-sm mt-2">
              {@session.description}
            </p>
          </div>
          <.session_status_badge status={@session.status} />
        </div>
      </div>
      <%!-- Initialization Progress Banner --%>
      <div
        :if={@session.status == "initializing"}
        class="bg-purple-50 dark:bg-purple-900/20 border border-purple-200 dark:border-purple-800 rounded-lg p-6 mb-6"
      >
        <div class="flex items-center justify-between mb-4">
          <div class="flex items-center gap-3">
            <div class="animate-spin">
              <.icon name="hero-arrow-path" class="w-6 h-6 text-purple-600 dark:text-purple-400" />
            </div>

            <div>
              <h3 class="text-lg font-semibold text-purple-900 dark:text-purple-300">
                Initializing Session Items...
              </h3>

              <p class="text-sm text-purple-700 dark:text-purple-400">
                Adding items to stock opname session. This may take a moment for large collections.
              </p>
            </div>
          </div>
        </div>

        <div class="mt-4">
          <div class="flex justify-between text-sm mb-2">
            <span class="text-purple-700 dark:text-purple-400">
              Items Added: <span class="font-bold">{@items_added}</span>
              / {if @session.total_items > 0, do: @session.total_items, else: "calculating..."}
            </span>
            <span :if={@session.total_items > 0} class="text-purple-700 dark:text-purple-400">
              {calculate_init_progress(@items_added, @session.total_items)}%
            </span>
          </div>

          <div class="w-full bg-purple-200 dark:bg-purple-800 rounded-full h-3">
            <div
              class="bg-purple-600 dark:bg-purple-500 h-3 rounded-full transition-all duration-300"
              style={"width: #{calculate_init_progress(@items_added, @session.total_items)}%"}
            >
            </div>
          </div>
        </div>
      </div>
      <%!-- Session Info Card --%>
      <div class="bg-white dark:bg-gray-800 rounded-lg shadow-sm p-6 mb-6">
        <h2 class="text-lg font-semibold text-gray-900 dark:text-gray-100 mb-4">
          Session Information
        </h2>

        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
          <div>
            <p class="text-xs font-medium text-gray-500 dark:text-gray-400">Created By</p>

            <p class="text-sm mt-1 dark:text-gray-300">
              {@session.created_by.fullname || @session.created_by.email}
            </p>
          </div>

          <div>
            <p class="text-xs font-medium text-gray-500 dark:text-gray-400">Created Date</p>

            <p class="text-sm mt-1 dark:text-gray-300">{format_date(@session.inserted_at)}</p>
          </div>

          <div :if={@session.started_at}>
            <p class="text-xs font-medium text-gray-500 dark:text-gray-400">Started</p>

            <p class="text-sm mt-1 dark:text-gray-300">{format_datetime(@session.started_at)}</p>
          </div>

          <div :if={@session.completed_at}>
            <p class="text-xs font-medium text-gray-500 dark:text-gray-400">Completed</p>

            <p class="text-sm mt-1 dark:text-gray-300">{format_datetime(@session.completed_at)}</p>
          </div>
        </div>
      </div>
      <%!-- Statistics Cards --%>
      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4 mb-6">
        <div class="bg-white dark:bg-gray-800 rounded-lg shadow-sm p-6">
          <div class="flex items-center justify-between mb-2">
            <p class="text-sm font-medium text-gray-600 dark:text-gray-400">
              {if @session.status == "initializing", do: "Expected Items", else: "Total Items"}
            </p>
            <.icon name="hero-inbox-stack" class="w-6 h-6 text-gray-400 dark:text-gray-500" />
          </div>

          <p class="text-3xl font-bold text-gray-900 dark:text-gray-100">{@session.total_items}</p>
        </div>

        <div class="bg-white dark:bg-gray-800 rounded-lg shadow-sm p-6">
          <div class="flex items-center justify-between mb-2">
            <p class="text-sm font-medium text-gray-600 dark:text-gray-400">Checked</p>
            <.icon name="hero-check-circle" class="w-6 h-6 text-green-400" />
          </div>

          <p class="text-3xl font-bold text-green-600 dark:text-green-500">
            {@session.checked_items}
          </p>

          <div class="mt-2 w-full bg-gray-200 dark:bg-gray-700 rounded-full h-2">
            <div
              class="bg-green-600 dark:bg-green-500 h-2 rounded-full"
              style={"width: #{calculate_progress(@session)}%"}
            >
            </div>
          </div>
        </div>

        <div class="bg-white dark:bg-gray-800 rounded-lg shadow-sm p-6">
          <div class="flex items-center justify-between mb-2">
            <p class="text-sm font-medium text-gray-600 dark:text-gray-400">Missing</p>
            <.icon name="hero-exclamation-triangle" class="w-6 h-6 text-red-400" />
          </div>

          <p class="text-3xl font-bold text-red-600 dark:text-red-500">{@session.missing_items}</p>
        </div>

        <div class="bg-white dark:bg-gray-800 rounded-lg shadow-sm p-6">
          <div class="flex items-center justify-between mb-2">
            <p class="text-sm font-medium text-gray-600 dark:text-gray-400">With Changes</p>
            <.icon name="hero-pencil" class="w-6 h-6 text-yellow-400" />
          </div>

          <p class="text-3xl font-bold text-yellow-600 dark:text-yellow-500">
            {@session.items_with_changes}
          </p>
        </div>
      </div>
      <%!-- Librarian Progress (Admin Only) --%>
      <div :if={@can_create} class="bg-white dark:bg-gray-800 rounded-lg shadow-sm p-6 mb-6">
        <h2 class="text-lg font-semibold text-gray-900 dark:text-gray-100 mb-4">
          Librarian Progress
        </h2>

        <div class="space-y-3">
          <div
            :for={assignment <- @librarian_pagination.items}
            class="flex items-center justify-between p-3 bg-gray-50 dark:bg-gray-700 rounded-lg"
          >
            <div class="flex-1">
              <p class="font-medium text-gray-900 dark:text-gray-100">
                {assignment.user.fullname || assignment.user.email}
              </p>

              <p class="text-sm text-gray-600 dark:text-gray-400">{assignment.user.email}</p>
            </div>

            <div class="flex items-center gap-4">
              <div class="text-right">
                <p class="text-sm font-medium text-gray-900 dark:text-gray-100">
                  {assignment.items_checked} items
                </p>

                <p class="text-xs text-gray-500 dark:text-gray-400">checked</p>
              </div>
              <.work_status_badge status={assignment.work_status} />
            </div>
          </div>
        </div>
        <%!-- Librarian Pagination Controls --%>
        <div
          :if={@librarian_pagination.total_pages > 1}
          class="flex items-center justify-between mt-6 pt-4 border-t border-gray-200 dark:border-gray-700"
        >
          <div class="text-sm text-gray-700 dark:text-gray-300">
            Showing {@librarian_pagination.page * @librarian_pagination.per_page -
              @librarian_pagination.per_page + 1} to {min(
              @librarian_pagination.page * @librarian_pagination.per_page,
              @librarian_pagination.total_count
            )} of {@librarian_pagination.total_count} librarians
          </div>

          <div class="flex gap-2">
            <button
              :if={@librarian_pagination.has_prev}
              phx-click="paginate_librarians"
              phx-value-page={@librarian_pagination.page - 1}
              class="px-3 py-2 text-sm font-medium text-gray-700 dark:text-gray-300 bg-white dark:bg-gray-700 border border-gray-300 dark:border-gray-600 rounded-md hover:bg-gray-50 dark:hover:bg-gray-600"
            >
              Previous
            </button>
            <span class="px-3 py-2 text-sm text-gray-700 dark:text-gray-300">
              Page {@librarian_pagination.page} of {@librarian_pagination.total_pages}
            </span>
            <button
              :if={@librarian_pagination.has_next}
              phx-click="paginate_librarians"
              phx-value-page={@librarian_pagination.page + 1}
              class="px-3 py-2 text-sm font-medium text-gray-700 dark:text-gray-300 bg-white dark:bg-gray-700 border border-gray-300 dark:border-gray-600 rounded-md hover:bg-gray-50 dark:hover:bg-gray-600"
            >
              Next
            </button>
          </div>
        </div>
      </div>
      <%!-- Actions --%>
      <div class="flex gap-3 mb-6 flex-wrap">
        <.link
          :if={@can_scan and @session.status == "in_progress"}
          navigate={~p"/manage/stock_opname/#{@session.id}/scan"}
          class="px-4 py-2 bg-blue-600 hover:bg-blue-700 text-white font-medium rounded-lg transition-colors"
        >
          <.icon name="hero-qr-code" class="w-5 h-5 inline mr-2" /> Continue Scanning
        </.link>
        <.link
          :if={@can_create and @session.status == "pending_review"}
          navigate={~p"/manage/stock_opname/#{@session.id}/review"}
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
        <button
          :if={@can_delete}
          phx-click="delete_session"
          data-confirm="Are you sure you want to delete this session? This action cannot be undone."
          class="px-4 py-2 bg-red-600 hover:bg-red-700 text-white font-medium rounded-lg transition-colors"
        >
          <.icon name="hero-trash" class="w-5 h-5 inline mr-2" /> Delete Session
        </button>
      </div>
      <%!-- Tabs --%>
      <div class="bg-white dark:bg-gray-800 rounded-lg shadow-sm">
        <div class="border-b border-gray-200 dark:border-gray-700">
          <nav class="flex -mb-px">
            <button
              :for={tab <- ["all", "checked", "pending", "missing", "with_changes", "librarians"]}
              phx-click="change_tab"
              phx-value-tab={tab}
              class={[
                "px-6 py-3 text-sm font-medium border-b-2 transition-colors",
                if(@current_tab == tab,
                  do: "border-blue-600 text-blue-600 dark:text-blue-400",
                  else:
                    "border-transparent text-gray-500 dark:text-gray-400 hover:text-gray-700 dark:hover:text-gray-300 hover:border-gray-300 dark:hover:border-gray-600"
                )
              ]}
            >
              {tab_label(tab)} {if tab != "librarians",
                do: "(#{tab_count(tab, @session, @pagination)})",
                else: ""}
            </button>
          </nav>
        </div>
        <%!-- Librarians Tab Content --%>
        <div :if={@current_tab == "librarians"} class="p-6">
          <div class="space-y-4">
            <div
              :for={assignment <- @displayed_items}
              class="p-4 border border-gray-200 dark:border-gray-700 rounded-lg hover:border-gray-300 dark:hover:border-gray-600 transition-colors"
            >
              <div class="flex justify-between items-start">
                <div class="flex-1">
                  <p class="font-medium text-gray-900 dark:text-gray-100">
                    {assignment.user.fullname || assignment.user.email}
                  </p>

                  <p class="text-sm text-gray-600 dark:text-gray-400">{assignment.user.email}</p>

                  <p
                    :if={assignment.user.department}
                    class="text-xs text-gray-500 dark:text-gray-500 mt-1"
                  >
                    {assignment.user.department}
                  </p>
                </div>
                <.work_status_badge status={assignment.work_status} />
              </div>

              <div class="grid grid-cols-2 md:grid-cols-4 gap-4 mt-4 pt-4 border-t border-gray-200 dark:border-gray-700">
                <div>
                  <p class="text-xs text-gray-500 dark:text-gray-400">Items Checked</p>

                  <p class="text-lg font-semibold text-gray-900 dark:text-gray-100">
                    {assignment.items_checked}
                  </p>
                </div>

                <div :if={assignment.started_at}>
                  <p class="text-xs text-gray-500 dark:text-gray-400">Started At</p>

                  <p class="text-sm text-gray-700 dark:text-gray-300">
                    {format_datetime(assignment.started_at)}
                  </p>
                </div>

                <div :if={assignment.completed_at}>
                  <p class="text-xs text-gray-500 dark:text-gray-400">Completed At</p>

                  <p class="text-sm text-gray-700 dark:text-gray-300">
                    {format_datetime(assignment.completed_at)}
                  </p>
                </div>

                <div :if={!is_nil(assignment.completed_at) && !is_nil(assignment.started_at)}>
                  <p class="text-xs text-gray-500 dark:text-gray-400">Duration</p>

                  <p class="text-sm text-gray-700 dark:text-gray-300">
                    {calculate_duration(assignment.started_at, assignment.completed_at)}
                  </p>
                </div>
              </div>

              <div :if={assignment.notes} class="mt-3 text-sm text-gray-600 dark:text-gray-400">
                <p class="text-xs font-medium text-gray-500 dark:text-gray-400 mb-1">Notes:</p>

                <p>{assignment.notes}</p>
              </div>
            </div>
          </div>

          <div :if={@displayed_items == []} class="text-center py-12">
            <.icon
              name="hero-user-group"
              class="w-16 h-16 mx-auto text-gray-400 dark:text-gray-500 mb-4"
            />
            <p class="text-gray-500 dark:text-gray-400">No librarians assigned to this session</p>
          </div>
        </div>
        <%!-- Items List --%>
        <div :if={@current_tab != "librarians"} class="p-6">
          <div class="space-y-2">
            <div
              :for={item <- @displayed_items}
              class="p-4 border border-gray-200 dark:border-gray-700 rounded-lg hover:border-gray-300 dark:hover:border-gray-600 transition-colors"
            >
              <div class="flex justify-between items-start mb-2">
                <div class="flex-1">
                  <p class="font-medium text-gray-900 dark:text-gray-100">
                    {if item.item, do: item.item.item_code, else: "N/A"}
                  </p>

                  <p class="text-sm text-gray-600 dark:text-gray-400">
                    {if item.collection, do: item.collection.title, else: "N/A"}
                  </p>
                </div>
                <.item_check_badge status={item.check_status} />
              </div>

              <div class="grid grid-cols-2 md:grid-cols-4 gap-3 text-xs text-gray-600 dark:text-gray-400">
                <div>
                  <span class="font-medium">Inventory:</span> {if item.item,
                    do: item.item.inventory_code,
                    else: "N/A"}
                </div>

                <div :if={item.item && item.item.barcode}>
                  <span class="font-medium">Barcode:</span> {item.item.barcode}
                </div>

                <div :if={item.scanned_barcode}>
                  <span class="font-medium">Scanned:</span> {item.scanned_barcode}
                </div>

                <div :if={item.checked_by}>
                  <div>
                    <span class="font-medium">Checked by:</span> {item.checked_by.fullname ||
                      item.checked_by.email}
                  </div>

                  <div>
                    <span class="font-medium">Checked at:</span> {FormatIndonesiaTime.format_utc_to_jakarta(
                      item.scanned_at
                    )}
                  </div>
                </div>
              </div>
              <%!-- Show changes from JSONB if any --%>
              <div
                :if={item.has_changes && item.changes}
                class="mt-3 pt-3 border-t border-gray-200 dark:border-gray-700"
              >
                <p class="text-xs font-medium text-yellow-700 dark:text-yellow-500 mb-2">
                  Changes Found:
                </p>

                <div class="grid grid-cols-2 gap-2 text-xs">
                  <div :for={{field, new_value} <- item.changes} class="col-span-2">
                    <span class="text-gray-500 dark:text-gray-400">{String.capitalize(field)}:</span>
                    <span class="text-green-600 dark:text-green-400 font-medium">
                      {format_change_value(new_value)}
                    </span>
                  </div>
                </div>
              </div>

              <div :if={item.notes} class="mt-2 text-xs text-gray-600 dark:text-gray-400">
                <span class="font-medium">Notes:</span> {item.notes}
              </div>
            </div>
          </div>

          <div :if={@displayed_items == []} class="text-center py-12">
            <.icon name="hero-inbox" class="w-16 h-16 mx-auto text-gray-400 dark:text-gray-500 mb-4" />
            <p class="text-gray-500 dark:text-gray-400">No items in this category</p>
          </div>
          <%!-- Pagination Controls --%>
          <div
            :if={@pagination.total_pages > 1}
            class="flex items-center justify-between mt-6 pt-4 border-t border-gray-200 dark:border-gray-700"
          >
            <div class="text-sm text-gray-700 dark:text-gray-300">
              Showing {@pagination.page * @pagination.per_page - @pagination.per_page + 1} to {min(
                @pagination.page * @pagination.per_page,
                @pagination.total_count
              )} of {@pagination.total_count} items
            </div>

            <div class="flex gap-2">
              <button
                :if={@pagination.has_prev}
                phx-click="paginate"
                phx-value-page={@pagination.page - 1}
                class="px-3 py-2 text-sm font-medium text-gray-700 dark:text-gray-300 bg-white dark:bg-gray-700 border border-gray-300 dark:border-gray-600 rounded-md hover:bg-gray-50 dark:hover:bg-gray-600"
              >
                Previous
              </button>
              <span class="px-3 py-2 text-sm text-gray-700 dark:text-gray-300">
                Page {@pagination.page} of {@pagination.total_pages}
              </span>
              <button
                :if={@pagination.has_next}
                phx-click="paginate"
                phx-value-page={@pagination.page + 1}
                class="px-3 py-2 text-sm font-medium text-gray-700 dark:text-gray-300 bg-white dark:bg-gray-700 border border-gray-300 dark:border-gray-600 rounded-md hover:bg-gray-50 dark:hover:bg-gray-600"
              >
                Next
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  def mount(%{"id" => id}, _session, socket) do
    session = StockOpname.get_session_without_items!(id)
    current_user = socket.assigns.current_scope.user

    # Check if user can view this session
    if StockOpnameAuthorization.can_view_session?(current_user, session) do
      can_create = StockOpnameAuthorization.can_create_session?(current_user)
      can_scan = StockOpnameAuthorization.can_scan_items?(current_user, session)
      can_delete = StockOpnameAuthorization.can_delete_session?(current_user, session)

      # Get current item count for initialization progress
      items_added =
        if session.status == "initializing" do
          StockOpname.count_session_items(session)
        else
          0
        end

      # Don't load items during initialization - they're not ready yet
      pagination =
        if session.status == "initializing" do
          %{
            items: [],
            page: 1,
            per_page: 50,
            total_count: 0,
            total_pages: 0,
            has_prev: false,
            has_next: false
          }
        else
          StockOpname.list_session_items_paginated(session, 1, 50)
        end

      # Initialize librarian pagination
      librarian_assignments = session.librarian_assignments
      total_librarians = length(librarian_assignments)

      librarian_pagination = %{
        items: Enum.take(librarian_assignments, 3),
        page: 1,
        per_page: 3,
        total_count: total_librarians,
        total_pages:
          if(total_librarians > 0, do: Float.ceil(total_librarians / 3) |> trunc(), else: 0),
        has_prev: false,
        has_next: total_librarians > 3
      }

      # Schedule refresh if still initializing (only on connected mount to avoid duplicate timers)
      if connected?(socket) and session.status == "initializing" do
        Process.send_after(self(), :refresh_session, 1000)
      end

      socket =
        socket
        |> assign(:page_title, session.title)
        |> assign(:session, session)
        |> assign(:current_user, current_user)
        |> assign(:can_create, can_create)
        |> assign(:can_scan, can_scan)
        |> assign(:can_delete, can_delete)
        |> assign(:pagination, pagination)
        |> assign(:displayed_items, pagination.items)
        |> assign(:current_tab, "all")
        |> assign(:items_added, items_added)
        |> assign(:all_librarians_completed, StockOpname.all_librarians_completed?(session))
        |> assign(:librarian_pagination, librarian_pagination)

      {:ok, socket}
    else
      socket =
        socket
        |> put_flash(:error, "You don't have permission to view this session")
        |> redirect(to: ~p"/manage/stock_opname")

      {:ok, socket}
    end
  end

  def handle_event("change_tab", %{"tab" => tab}, socket) do
    session = socket.assigns.session

    pagination =
      case tab do
        "librarians" ->
          total_count = length(session.librarian_assignments)
          per_page = 3
          total_pages = ceil(total_count / per_page)
          page = 1
          start_index = (page - 1) * per_page
          _end_index = min(start_index + per_page, total_count)
          items = Enum.slice(session.librarian_assignments, start_index, per_page)

          %{
            items: items,
            page: page,
            per_page: per_page,
            total_count: total_count,
            total_pages: total_pages,
            has_prev: page > 1,
            has_next: page < total_pages
          }

        "all" ->
          StockOpname.list_session_items_paginated(session, 1, 50)

        "checked" ->
          StockOpname.list_session_items_paginated(session, 1, 50, %{check_status: "checked"})

        "pending" ->
          StockOpname.list_session_items_paginated(session, 1, 50, %{check_status: "pending"})

        "missing" ->
          StockOpname.list_session_items_paginated(session, 1, 50, %{check_status: "missing"})

        "with_changes" ->
          StockOpname.list_session_items_paginated(session, 1, 50, %{has_changes: true})

        _ ->
          StockOpname.list_session_items_paginated(session, 1, 50)
      end

    socket =
      socket
      |> assign(:current_tab, tab)
      |> assign(:pagination, pagination)
      |> assign(:displayed_items, pagination.items)

    {:noreply, socket}
  end

  def handle_event("paginate", %{"page" => page}, socket) do
    session = socket.assigns.session
    page = String.to_integer(page)

    pagination =
      case socket.assigns.current_tab do
        "librarians" ->
          total_count = length(session.librarian_assignments)
          per_page = 3
          total_pages = ceil(total_count / per_page)
          start_index = (page - 1) * per_page
          _end_index = min(start_index + per_page, total_count)
          items = Enum.slice(session.librarian_assignments, start_index, per_page)

          %{
            items: items,
            page: page,
            per_page: per_page,
            total_count: total_count,
            total_pages: total_pages,
            has_prev: page > 1,
            has_next: page < total_pages
          }

        _ ->
          filters =
            case socket.assigns.current_tab do
              "checked" -> %{check_status: "checked"}
              "pending" -> %{check_status: "pending"}
              "missing" -> %{check_status: "missing"}
              "with_changes" -> %{has_changes: true}
              _ -> %{}
            end

          StockOpname.list_session_items_paginated(session, page, 50, filters)
      end

    socket =
      socket
      |> assign(:pagination, pagination)
      |> assign(:displayed_items, pagination.items)

    {:noreply, socket}
  end

  def handle_event("paginate_librarians", %{"page" => page}, socket) do
    session = socket.assigns.session
    page = String.to_integer(page)
    librarian_assignments = session.librarian_assignments
    total_count = length(librarian_assignments)
    per_page = 3
    total_pages = if(total_count > 0, do: Float.ceil(total_count / 3) |> trunc(), else: 0)
    start_index = (page - 1) * per_page
    items = Enum.slice(librarian_assignments, start_index, per_page)

    librarian_pagination = %{
      items: items,
      page: page,
      per_page: per_page,
      total_count: total_count,
      total_pages: total_pages,
      has_prev: page > 1,
      has_next: page < total_pages
    }

    socket =
      socket
      |> assign(:librarian_pagination, librarian_pagination)

    {:noreply, socket}
  end

  def handle_event("complete_session", _params, socket) do
    case StockOpname.complete_session(
           socket.assigns.session,
           socket.assigns.current_user
         ) do
      {:ok, _session} ->
        socket =
          socket
          |> put_flash(:info, "Session completed and ready for review!")
          |> redirect(to: ~p"/manage/stock_opname")

        {:noreply, socket}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to complete session")}
    end
  end

  def handle_event("delete_session", _params, socket) do
    case StockOpname.delete_session(
           socket.assigns.session,
           socket.assigns.current_user
         ) do
      {:ok, _session} ->
        socket =
          socket
          |> put_flash(:info, "Session deleted successfully!")
          |> redirect(to: ~p"/manage/stock_opname")

        {:noreply, socket}

      {:error, :invalid_status_for_deletion} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           "Only approved or cancelled sessions can be deleted"
         )}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete session")}
    end
  end

  def handle_info(:refresh_session, socket) do
    session = StockOpname.get_session_without_items!(socket.assigns.session.id)
    items_added = StockOpname.count_session_items(session)

    socket =
      if session.status == "initializing" do
        # Still initializing - schedule next refresh
        Process.send_after(self(), :refresh_session, 1000)

        socket
        |> assign(:session, session)
        |> assign(:items_added, items_added)
      else
        # Initialization complete - load first page of items and stop refreshing
        pagination = StockOpname.list_session_items_paginated(session, 1, 50)

        # Update librarian pagination
        librarian_assignments = session.librarian_assignments
        total_librarians = length(librarian_assignments)

        librarian_pagination = %{
          items: Enum.take(librarian_assignments, 3),
          page: 1,
          per_page: 3,
          total_count: total_librarians,
          total_pages:
            if(total_librarians > 0, do: Float.ceil(total_librarians / 3) |> trunc(), else: 0),
          has_prev: false,
          has_next: total_librarians > 3
        }

        socket
        |> assign(:session, session)
        |> assign(:items_added, 0)
        |> assign(:pagination, pagination)
        |> assign(:displayed_items, pagination.items)
        |> assign(:librarian_pagination, librarian_pagination)
        |> assign(:all_librarians_completed, StockOpname.all_librarians_completed?(session))
      end

    {:noreply, socket}
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
      "librarians" -> "Librarians"
      _ -> tab
    end
  end

  defp tab_count(tab, session, _pagination) do
    case tab do
      "all" -> session.total_items
      "checked" -> session.checked_items
      "pending" -> session.total_items - session.checked_items - session.missing_items
      "missing" -> session.missing_items
      "with_changes" -> session.items_with_changes
      "librarians" -> length(session.librarian_assignments)
      _ -> 0
    end
  end

  defp session_status_badge(assigns) do
    # Same as in Index
    color =
      case assigns.status do
        "draft" -> "bg-gray-100 text-gray-800"
        "initializing" -> "bg-purple-100 text-purple-800 animate-pulse"
        "in_progress" -> "bg-blue-100 text-blue-800"
        "completed" -> "bg-yellow-100 text-yellow-800"
        "pending_review" -> "bg-orange-100 text-orange-800"
        "approved" -> "bg-green-100 text-green-800"
        "rejected" -> "bg-red-100 text-red-800"
        _ -> "bg-gray-100 text-gray-800"
      end

    label =
      case assigns.status do
        "initializing" -> "Initializing Items..."
        _ -> assigns.status
      end

    assigns = assign(assigns, :color, color) |> assign(:label, label)

    ~H"""
    <span class={"inline-flex items-center px-3 py-1 text-sm font-medium rounded-full #{@color}"}>
      {@label}
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

  defp calculate_duration(started_at, completed_at) do
    diff_seconds = DateTime.diff(completed_at, started_at, :second)
    hours = div(diff_seconds, 3600)
    minutes = div(rem(diff_seconds, 3600), 60)

    cond do
      hours > 0 -> "#{hours}h #{minutes}m"
      minutes > 0 -> "#{minutes}m"
      true -> "< 1m"
    end
  end

  defp calculate_init_progress(items_added, total_items) when total_items > 0 do
    Float.round(items_added / total_items * 100, 1)
  end

  defp calculate_init_progress(_items_added, _total_items), do: 0.0

  defp format_change_value(%{"updated" => updates}) when is_list(updates) do
    pairs = for %{"id" => id, "value" => value} <- updates, do: "#{id}: #{value}"
    "Updated fields - #{Enum.join(pairs, ", ")}"
  end

  defp format_change_value(other) do
    inspect(other)
  end
end
