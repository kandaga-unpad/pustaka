defmodule VoileWeb.Dashboard.StockOpnameLive.Review do
  use VoileWeb, :live_view_dashboard

  alias Voile.Schema.StockOpname
  alias VoileWeb.Auth.StockOpnameAuthorization

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
        <h1 class="text-3xl font-bold text-gray-900 dark:text-gray-100">Review Stock Opname</h1>

        <p class="text-gray-600 dark:text-gray-400 mt-1">
          {@session.title} - {@session.session_code}
        </p>
      </div>
      <%!-- Summary Cards --%>
      <div class="grid grid-cols-1 md:grid-cols-4 gap-4 mb-6">
        <div class="bg-white dark:bg-gray-800 rounded-lg shadow-sm p-6">
          <div class="flex items-center justify-between mb-2">
            <p class="text-sm font-medium text-gray-600 dark:text-gray-400">Total Items</p>
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

          <p class="text-xs text-gray-500 dark:text-gray-400 mt-1">
            {Float.round(@session.checked_items / max(@session.total_items, 1) * 100, 1)}%
          </p>
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
            <p class="text-sm font-medium text-gray-600 dark:text-gray-400">Changes to Apply</p>
            <.icon name="hero-pencil" class="w-6 h-6 text-yellow-400" />
          </div>

          <p class="text-3xl font-bold text-yellow-600 dark:text-yellow-500">
            {@session.items_with_changes}
          </p>
        </div>
      </div>
      <%!-- Session Scope Info --%>
      <div class="bg-white dark:bg-gray-800 rounded-lg shadow-sm p-6 mb-6">
        <h2 class="text-lg font-semibold text-gray-900 dark:text-gray-100 mb-4">Session Scope</h2>

        <div class="grid grid-cols-1 md:grid-cols-2 gap-4 text-sm">
          <div>
            <p class="font-medium text-gray-700 dark:text-gray-300">Nodes:</p>

            <p class="text-gray-600 dark:text-gray-400">
              {Enum.count(@session.node_ids)} node(s) included
            </p>
          </div>

          <div>
            <p class="font-medium text-gray-700 dark:text-gray-300">Collection Types:</p>

            <p class="text-gray-600 dark:text-gray-400">
              {Enum.join(@session.collection_types, ", ")}
            </p>
          </div>

          <div>
            <p class="font-medium text-gray-700 dark:text-gray-300">Scope Type:</p>

            <p class="text-gray-600 dark:text-gray-400">{@session.scope_type}</p>
          </div>

          <div :if={@session.scope_type == "collection" and @session.collection_id}>
            <p class="font-medium text-gray-700 dark:text-gray-300">Target Collection:</p>

            <p class="text-gray-600 dark:text-gray-400">{@session.collection.title}</p>
          </div>

          <div :if={@session.scope_type == "location" and @session.location_id}>
            <p class="font-medium text-gray-700 dark:text-gray-300">Target Location:</p>

            <p class="text-gray-600 dark:text-gray-400">{@session.location.name}</p>
          </div>
        </div>
      </div>
      <%!-- Tabs Navigation --%>
      <div class="bg-white dark:bg-gray-800 rounded-lg shadow-sm mb-6">
        <div class="border-b border-gray-200 dark:border-gray-700">
          <nav class="flex -mb-px">
            <button
              phx-click="switch_tab"
              phx-value-tab="summary"
              class={[
                "px-6 py-4 text-sm font-medium border-b-2 transition-colors",
                if(@current_tab == "summary",
                  do: "border-blue-500 text-blue-600 dark:text-blue-400",
                  else:
                    "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300 dark:text-gray-400 dark:hover:text-gray-300"
                )
              ]}
            >
              <.icon name="hero-users" class="w-4 h-4 inline mr-2" /> Librarian Work Summary
            </button>
            <button
              phx-click="switch_tab"
              phx-value-tab="changes"
              class={[
                "px-6 py-4 text-sm font-medium border-b-2 transition-colors",
                if(@current_tab == "changes",
                  do: "border-blue-500 text-blue-600 dark:text-blue-400",
                  else:
                    "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300 dark:text-gray-400 dark:hover:text-gray-300"
                )
              ]}
            >
              <.icon name="hero-pencil" class="w-4 h-4 inline mr-2" />
              Items with Changes ({@session.items_with_changes})
            </button>
            <button
              phx-click="switch_tab"
              phx-value-tab="missing"
              class={[
                "px-6 py-4 text-sm font-medium border-b-2 transition-colors",
                if(@current_tab == "missing",
                  do: "border-blue-500 text-blue-600 dark:text-blue-400",
                  else:
                    "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300 dark:text-gray-400 dark:hover:text-gray-300"
                )
              ]}
            >
              <.icon name="hero-exclamation-triangle" class="w-4 h-4 inline mr-2" />
              Missing Items ({@session.missing_items})
            </button>
          </nav>
        </div>
        <%!-- Tab Content --%>
        <div class="p-6">
          <%!-- Librarian Work Summary Tab --%>
          <div :if={@current_tab == "summary"}>
            <div class="space-y-3">
              <div
                :for={assignment <- @session.librarian_assignments}
                class="flex items-center justify-between p-3 bg-gray-50 dark:bg-gray-700 rounded-lg"
              >
                <div class="flex-1">
                  <p class="font-medium text-gray-900 dark:text-gray-100">
                    {assignment.user.fullname || assignment.user.email}
                  </p>

                  <div class="flex items-center gap-4 mt-1 text-sm text-gray-600 dark:text-gray-400">
                    <span>
                      <.icon name="hero-check-circle" class="w-4 h-4 inline" /> {assignment.items_checked} items
                    </span>
                    <span :if={assignment.completed_at}>
                      <.icon name="hero-clock" class="w-4 h-4 inline" />
                      Completed {format_datetime(assignment.completed_at)}
                    </span>
                  </div>
                </div>
                <.work_status_badge status={assignment.work_status} />
              </div>
            </div>
          </div>
          <%!-- Items with Changes Tab --%>
          <div :if={@current_tab == "changes"}>
            <div :if={@items_with_changes_page.total_count == 0} class="text-center py-8">
              <.icon
                name="hero-inbox"
                class="w-16 h-16 mx-auto text-gray-300 dark:text-gray-600 mb-4"
              />
              <p class="text-gray-500 dark:text-gray-400">No items with changes</p>
            </div>

            <div :if={@items_with_changes_page.total_count > 0} class="space-y-3">
              <div
                :for={item <- @items_with_changes_page.items}
                class="p-4 border border-yellow-200 dark:border-yellow-800 bg-yellow-50 dark:bg-yellow-900/20 rounded-lg"
              >
                <div class="flex justify-between items-start mb-3">
                  <div>
                    <p class="font-medium text-gray-900 dark:text-gray-100">
                      {item.item.item_code}
                    </p>

                    <p class="text-sm text-gray-600 dark:text-gray-400">{item.collection.title}</p>

                    <p class="text-xs text-gray-500 dark:text-gray-500 mt-1">
                      Inventory: {item.item.inventory_code}
                      <span :if={item.item.barcode}> • Barcode:    {item.item.barcode}</span>
                    </p>
                  </div>

                  <p class="text-xs text-gray-600 dark:text-gray-400">
                    Checked by: {item.checked_by.fullname || item.checked_by.email}
                  </p>
                </div>

                <div class="grid grid-cols-1 md:grid-cols-2 gap-3 text-sm">
                  <div
                    :if={Map.has_key?(item.changes, "status")}
                    class="p-2 bg-white dark:bg-gray-800 rounded"
                  >
                    <p class="text-xs font-medium text-gray-700 dark:text-gray-300 mb-1">
                      Status Change
                    </p>

                    <div class="flex items-center gap-2">
                      <span class="px-2 py-1 bg-gray-100 dark:bg-gray-700 text-gray-700 dark:text-gray-300 rounded text-xs line-through">
                        {item.item.status}
                      </span>
                      <.icon name="hero-arrow-right" class="w-4 h-4 text-gray-400" />
                      <span class="px-2 py-1 bg-green-100 dark:bg-green-900/50 text-green-700 dark:text-green-400 rounded text-xs font-medium">
                        {item.changes["status"]}
                      </span>
                    </div>
                  </div>

                  <div
                    :if={Map.has_key?(item.changes, "condition")}
                    class="p-2 bg-white dark:bg-gray-800 rounded"
                  >
                    <p class="text-xs font-medium text-gray-700 dark:text-gray-300 mb-1">
                      Condition Change
                    </p>

                    <div class="flex items-center gap-2">
                      <span class="px-2 py-1 bg-gray-100 dark:bg-gray-700 text-gray-700 dark:text-gray-300 rounded text-xs line-through">
                        {item.item.condition}
                      </span>
                      <.icon name="hero-arrow-right" class="w-4 h-4 text-gray-400" />
                      <span class="px-2 py-1 bg-green-100 dark:bg-green-900/50 text-green-700 dark:text-green-400 rounded text-xs font-medium">
                        {item.changes["condition"]}
                      </span>
                    </div>
                  </div>

                  <div
                    :if={Map.has_key?(item.changes, "availability")}
                    class="p-2 bg-white dark:bg-gray-800 rounded"
                  >
                    <p class="text-xs font-medium text-gray-700 dark:text-gray-300 mb-1">
                      Availability Change
                    </p>

                    <div class="flex items-center gap-2">
                      <span class="px-2 py-1 bg-gray-100 dark:bg-gray-700 text-gray-700 dark:text-gray-300 rounded text-xs line-through">
                        {item.item.availability}
                      </span>
                      <.icon name="hero-arrow-right" class="w-4 h-4 text-gray-400" />
                      <span class="px-2 py-1 bg-green-100 dark:bg-green-900/50 text-green-700 dark:text-green-400 rounded text-xs font-medium">
                        {item.changes["availability"]}
                      </span>
                    </div>
                  </div>

                  <div
                    :if={Map.has_key?(item.changes, "location")}
                    class="p-2 bg-white dark:bg-gray-800 rounded"
                  >
                    <p class="text-xs font-medium text-gray-700 dark:text-gray-300 mb-1">
                      Location Change
                    </p>

                    <div class="flex items-center gap-2">
                      <span class="px-2 py-1 bg-gray-100 dark:bg-gray-700 text-gray-700 dark:text-gray-300 rounded text-xs line-through">
                        {item.item.location || "None"}
                      </span>
                      <.icon name="hero-arrow-right" class="w-4 h-4 text-gray-400" />
                      <span class="px-2 py-1 bg-green-100 dark:bg-green-900/50 text-green-700 dark:text-green-400 rounded text-xs font-medium">
                        {item.changes["location"] || "None"}
                      </span>
                    </div>
                  </div>
                </div>

                <div
                  :if={item.notes}
                  class="mt-3 pt-3 border-t border-yellow-300 dark:border-yellow-800"
                >
                  <p class="text-xs font-medium text-gray-700 dark:text-gray-300">Checker Notes:</p>

                  <p class="text-sm text-gray-600 dark:text-gray-400 mt-1">{item.notes}</p>
                </div>
              </div>
              <%!-- Pagination for Changes --%>
              <.pagination_controls
                page={@items_with_changes_page.page}
                total_pages={@items_with_changes_page.total_pages}
                has_prev={@items_with_changes_page.has_prev}
                has_next={@items_with_changes_page.has_next}
                event="paginate_changes"
              />
            </div>
          </div>
          <%!-- Missing Items Tab --%>
          <div :if={@current_tab == "missing"}>
            <div :if={@missing_items_page.total_count == 0} class="text-center py-8">
              <.icon
                name="hero-check-circle"
                class="w-16 h-16 mx-auto text-green-300 dark:text-green-600 mb-4"
              />
              <p class="text-gray-500 dark:text-gray-400">No missing items</p>
            </div>

            <div :if={@missing_items_page.total_count > 0} class="space-y-2">
              <div
                :for={item <- @missing_items_page.items}
                class="p-3 border border-red-200 dark:border-red-800 bg-red-50 dark:bg-red-900/20 rounded-lg"
              >
                <div class="flex justify-between items-start">
                  <div>
                    <p class="font-medium text-gray-900 dark:text-gray-100">
                      {item.item.item_code}
                    </p>

                    <p class="text-sm text-gray-600 dark:text-gray-400">{item.collection.title}</p>

                    <p class="text-xs text-gray-500 dark:text-gray-500 mt-1">
                      Inventory: {item.item.inventory_code}
                      <span :if={item.item.barcode}> • Barcode:    {item.item.barcode}</span>
                    </p>
                  </div>

                  <span class="inline-flex items-center px-2 py-1 text-xs font-medium rounded bg-red-100 dark:bg-red-900/50 text-red-700 dark:text-red-400">
                    Missing
                  </span>
                </div>
              </div>
              <%!-- Pagination for Missing Items --%>
              <.pagination_controls
                page={@missing_items_page.page}
                total_pages={@missing_items_page.total_pages}
                has_prev={@missing_items_page.has_prev}
                has_next={@missing_items_page.has_next}
                event="paginate_missing"
              />
            </div>
          </div>
        </div>
      </div>
      <%!-- Actions --%>
      <div class="bg-white dark:bg-gray-800 rounded-lg shadow-sm p-6">
        <h2 class="text-lg font-semibold text-gray-900 dark:text-gray-100 mb-4">Review Actions</h2>

        <div class="space-y-4">
          <%!-- Approve --%>
          <div class="border border-gray-200 dark:border-gray-700 rounded-lg p-4">
            <h3 class="font-medium text-gray-900 dark:text-gray-100 mb-2">
              <.icon
                name="hero-check-circle"
                class="w-5 h-5 inline text-green-600 dark:text-green-500"
              /> Approve Session
            </h3>

            <p class="text-sm text-gray-600 dark:text-gray-400 mb-4">
              This will apply all changes ({@session.items_with_changes} items) and mark {@session.missing_items} items as missing in the system.
            </p>

            <.form :let={f} for={@approve_form} phx-submit="approve" class="space-y-3">
              <.input
                field={f[:approved_notes]}
                type="textarea"
                label="Approval Notes (optional)"
                placeholder="Add any notes about this approval..."
                rows={3}
              />
              <button
                type="submit"
                class="w-full px-4 py-3 bg-green-600 hover:bg-green-700 text-white font-medium rounded-lg transition-colors"
              >
                <.icon name="hero-check-circle" class="w-5 h-5 inline mr-2" /> Approve & Apply Changes
              </button>
            </.form>
          </div>
          <%!-- Request Revision --%>
          <div class="border border-gray-200 dark:border-gray-700 rounded-lg p-4">
            <h3 class="font-medium text-gray-900 dark:text-gray-100 mb-2">
              <.icon
                name="hero-arrow-uturn-left"
                class="w-5 h-5 inline text-yellow-600 dark:text-yellow-500"
              /> Request Revision
            </h3>

            <p class="text-sm text-gray-600 dark:text-gray-400 mb-4">
              Send the session back to librarians with notes for correction or additional checking.
            </p>

            <.form :let={f} for={@revision_form} phx-submit="request_revision" class="space-y-3">
              <.input
                field={f[:revision_notes]}
                type="textarea"
                label="Revision Notes (required)"
                placeholder="Explain what needs to be reviewed or corrected..."
                rows={3}
                required
              />
              <button
                type="submit"
                class="w-full px-4 py-3 bg-yellow-600 hover:bg-yellow-700 text-white font-medium rounded-lg transition-colors"
              >
                <.icon name="hero-arrow-uturn-left" class="w-5 h-5 inline mr-2" /> Request Revision
              </button>
            </.form>
          </div>
          <%!-- Reject --%>
          <div class="border border-gray-200 dark:border-gray-700 rounded-lg p-4">
            <h3 class="font-medium text-gray-900 dark:text-gray-100 mb-2">
              <.icon name="hero-x-circle" class="w-5 h-5 inline text-red-600 dark:text-red-500" />
              Reject Session
            </h3>

            <p class="text-sm text-gray-600 dark:text-gray-400 mb-4">
              Reject this session if the results are invalid. No changes will be applied.
            </p>

            <.form :let={f} for={@reject_form} phx-submit="reject" class="space-y-3">
              <.input
                field={f[:rejection_reason]}
                type="textarea"
                label="Rejection Reason (required)"
                placeholder="Explain why this session is being rejected..."
                rows={3}
                required
              />
              <button
                type="submit"
                class="w-full px-4 py-3 bg-red-600 hover:bg-red-700 text-white font-medium rounded-lg transition-colors"
              >
                <.icon name="hero-x-circle" class="w-5 h-5 inline mr-2" /> Reject Session
              </button>
            </.form>
          </div>
        </div>
      </div>
    </div>
    """
  end

  def mount(%{"id" => id}, _session, socket) do
    session = StockOpname.get_session_without_items!(id)
    current_user = socket.assigns.current_scope.user

    # Verify permission
    unless StockOpnameAuthorization.can_approve_session?(current_user, session) do
      socket =
        socket
        |> put_flash(:error, "You don't have permission to review this session")
        |> redirect(to: ~p"/manage/stock_opname")

      {:ok, socket}
    else
      # Verify status
      unless session.status == "pending_review" do
        socket =
          socket
          |> put_flash(:error, "This session is not pending review")
          |> redirect(to: ~p"/manage/stock_opname/#{session.id}")

        {:ok, socket}
      else
        # Recalculate counters to ensure they're up to date
        {:ok, session} = StockOpname.recalculate_session_counters(session)

        # Load initial pagination data for items with changes tab
        items_with_changes_page = StockOpname.list_items_with_changes_paginated(session, 1, 20)
        missing_items_page = StockOpname.list_missing_items_paginated(session, 1, 20)

        socket =
          socket
          |> assign(:page_title, "Review - #{session.title}")
          |> assign(:session, session)
          |> assign(:current_user, current_user)
          |> assign(:current_tab, "summary")
          |> assign(:items_with_changes_page, items_with_changes_page)
          |> assign(:missing_items_page, missing_items_page)
          |> assign(:approve_form, to_form(%{}))
          |> assign(:revision_form, to_form(%{}))
          |> assign(:reject_form, to_form(%{}))

        {:ok, socket}
      end
    end
  end

  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :current_tab, tab)}
  end

  def handle_event("paginate_changes", %{"page" => page}, socket) do
    page = String.to_integer(page)

    items_with_changes_page =
      StockOpname.list_items_with_changes_paginated(socket.assigns.session, page, 20)

    {:noreply, assign(socket, :items_with_changes_page, items_with_changes_page)}
  end

  def handle_event("paginate_missing", %{"page" => page}, socket) do
    page = String.to_integer(page)

    missing_items_page =
      StockOpname.list_missing_items_paginated(socket.assigns.session, page, 20)

    {:noreply, assign(socket, :missing_items_page, missing_items_page)}
  end

  def handle_event("approve", %{"approved_notes" => notes}, socket) do
    case StockOpname.approve_session(
           socket.assigns.session,
           socket.assigns.current_user,
           notes
         ) do
      {:ok, _session} ->
        socket =
          socket
          |> put_flash(:info, "Session approved! All changes have been applied.")
          |> redirect(to: ~p"/manage/stock_opname")

        {:noreply, socket}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to approve session")}
    end
  end

  def handle_event("request_revision", %{"revision_notes" => notes}, socket) do
    if String.trim(notes) == "" do
      {:noreply, put_flash(socket, :error, "Revision notes are required")}
    else
      case StockOpname.request_session_revision(
             socket.assigns.session,
             socket.assigns.current_user,
             notes
           ) do
        {:ok, _session} ->
          socket =
            socket
            |> put_flash(:info, "Revision requested. Librarians have been notified.")
            |> redirect(to: ~p"/manage/stock_opname")

          {:noreply, socket}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to request revision")}
      end
    end
  end

  def handle_event("reject", %{"rejection_reason" => reason}, socket) do
    if String.trim(reason) == "" do
      {:noreply, put_flash(socket, :error, "Rejection reason is required")}
    else
      case StockOpname.reject_session(
             socket.assigns.session,
             socket.assigns.current_user,
             reason
           ) do
        {:ok, _session} ->
          socket =
            socket
            |> put_flash(:info, "Session rejected.")
            |> redirect(to: ~p"/manage/stock_opname")

          {:noreply, socket}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to reject session")}
      end
    end
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

  defp format_datetime(datetime), do: Calendar.strftime(datetime, "%B %d, %Y %I:%M %p")

  defp pagination_controls(assigns) do
    ~H"""
    <div class="flex items-center justify-between border-t border-gray-200 dark:border-gray-700 pt-4 mt-4">
      <div class="flex items-center gap-2">
        <button
          :if={@has_prev}
          phx-click={@event}
          phx-value-page={@page - 1}
          class="px-3 py-2 text-sm font-medium text-gray-700 dark:text-gray-300 bg-white dark:bg-gray-800 border border-gray-300 dark:border-gray-600 rounded-md hover:bg-gray-50 dark:hover:bg-gray-700 transition-colors"
        >
          <.icon name="hero-chevron-left" class="w-4 h-4" />
        </button>
        <button
          :if={!@has_prev}
          disabled
          class="px-3 py-2 text-sm font-medium text-gray-400 dark:text-gray-600 bg-gray-100 dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded-md cursor-not-allowed"
        >
          <.icon name="hero-chevron-left" class="w-4 h-4" />
        </button>
      </div>

      <span class="text-sm text-gray-700 dark:text-gray-300">
        Page {@page} of {@total_pages}
      </span>

      <div class="flex items-center gap-2">
        <button
          :if={@has_next}
          phx-click={@event}
          phx-value-page={@page + 1}
          class="px-3 py-2 text-sm font-medium text-gray-700 dark:text-gray-300 bg-white dark:bg-gray-800 border border-gray-300 dark:border-gray-600 rounded-md hover:bg-gray-50 dark:hover:bg-gray-700 transition-colors"
        >
          <.icon name="hero-chevron-right" class="w-4 h-4" />
        </button>
        <button
          :if={!@has_next}
          disabled
          class="px-3 py-2 text-sm font-medium text-gray-400 dark:text-gray-600 bg-gray-100 dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded-md cursor-not-allowed"
        >
          <.icon name="hero-chevron-right" class="w-4 h-4" />
        </button>
      </div>
    </div>
    """
  end
end
