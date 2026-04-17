defmodule VoileWeb.Dashboard.StockOpnameLive.Show do
  use VoileWeb, :live_view_dashboard

  alias Voile.Schema.StockOpname
  alias VoileWeb.Auth.StockOpnameAuthorization
  alias VoileWeb.Auth.Authorization
  alias VoileWeb.Utils.FormatIndonesiaTime

  def render(assigns) do
    ~H"""
    <div class="container mx-auto px-4 py-6">
      <%!-- Header --%>
      <div class="mb-6">
        <.link
          navigate={~p"/manage/catalog/stock_opname"}
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
      <%!-- Review Notes Banner (revision requested) --%>
      <div
        :if={@session.review_notes not in [nil, ""] and @session.status == "in_progress"}
        id="review-notes-banner"
        class="bg-amber-50 dark:bg-amber-900/20 border border-amber-200 dark:border-amber-800 rounded-lg p-4 mb-6"
      >
        <div class="flex items-start gap-3">
          <.icon
            name="hero-arrow-uturn-left"
            class="w-5 h-5 text-amber-600 dark:text-amber-400 mt-0.5 shrink-0"
          />
          <div>
            <h3 class="text-sm font-semibold text-amber-900 dark:text-amber-300">
              Revision Requested
            </h3>
            <p class="text-sm text-amber-800 dark:text-amber-400 mt-1 whitespace-pre-wrap">
              {@session.review_notes}
            </p>
          </div>
        </div>
      </div>
      <%!-- Rejection Reason Banner --%>
      <div
        :if={@session.rejection_reason not in [nil, ""] and @session.status == "rejected"}
        id="rejection-reason-banner"
        class="bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800 rounded-lg p-4 mb-6"
      >
        <div class="flex items-start gap-3">
          <.icon
            name="hero-x-circle"
            class="w-5 h-5 text-red-600 dark:text-red-400 mt-0.5 shrink-0"
          />
          <div>
            <h3 class="text-sm font-semibold text-red-900 dark:text-red-300">
              Session Rejected
            </h3>
            <p class="text-sm text-red-800 dark:text-red-400 mt-1 whitespace-pre-wrap">
              {@session.rejection_reason}
            </p>
          </div>
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

        <%!-- Assign New Librarian Form --%>
        <div
          :if={
            @session.status in ["draft", "initializing", "in_progress"] and
              @available_librarians != []
          }
          class="mb-6 p-4 bg-blue-50 dark:bg-blue-900/20 rounded-lg border border-blue-200 dark:border-blue-800"
        >
          <h3 class="text-sm font-medium text-blue-900 dark:text-blue-300 mb-3">
            Assign New Librarian
          </h3>
          <.form for={%{}} phx-submit="assign_librarian" class="relative">
            <div class="flex gap-3 items-end">
              <div class="flex-1 relative">
                <label class="block text-sm font-medium text-blue-800 dark:text-blue-200 mb-1">
                  Search Librarian
                </label>
                <input
                  type="text"
                  name="search_term"
                  value={@search_term}
                  phx-change="search_librarians"
                  phx-debounce="300"
                  placeholder="Type to search librarians..."
                  autocomplete="off"
                  class="w-full rounded-md border-blue-300 dark:border-blue-600 bg-white dark:bg-gray-700 text-gray-900 dark:text-gray-100 focus:border-blue-500 focus:ring-blue-500 px-3 py-2"
                />
                <input type="hidden" name="librarian_id" value={@selected_librarian_id} />

                <%!-- Dropdown Results --%>
                <div
                  :if={@filtered_librarians != [] and @search_term != ""}
                  class="absolute z-10 w-full mt-1 bg-white dark:bg-gray-700 border border-blue-300 dark:border-blue-600 rounded-md shadow-lg max-h-60 overflow-y-auto"
                >
                  <div
                    :for={librarian <- @filtered_librarians}
                    phx-click="select_librarian"
                    phx-value-id={librarian.id}
                    class="px-3 py-2 hover:bg-blue-50 dark:hover:bg-blue-900/30 cursor-pointer border-b border-gray-100 dark:border-gray-600 last:border-b-0"
                  >
                    <div class="font-medium text-gray-900 dark:text-gray-100">
                      {librarian.fullname}
                    </div>
                    <div class="text-sm text-gray-600 dark:text-gray-400">
                      {librarian.email}
                    </div>
                  </div>
                </div>

                <%!-- Selected Librarian Display --%>
                <div
                  :if={@selected_librarian}
                  class="mt-2 p-2 bg-blue-100 dark:bg-blue-900/50 rounded-md border border-blue-300 dark:border-blue-600"
                >
                  <div class="flex items-center justify-between">
                    <div>
                      <div class="font-medium text-blue-900 dark:text-blue-100">
                        {@selected_librarian.fullname}
                      </div>
                      <div class="text-sm text-blue-700 dark:text-blue-300">
                        {@selected_librarian.email}
                      </div>
                    </div>
                    <button
                      type="button"
                      phx-click="clear_selection"
                      class="text-blue-600 hover:text-blue-800 dark:text-blue-400 dark:hover:text-blue-200"
                    >
                      <.icon name="hero-x-mark" class="w-4 h-4" />
                    </button>
                  </div>
                </div>
              </div>
              <button
                type="submit"
                disabled={@selected_librarian_id == nil}
                class="px-4 py-2 bg-blue-600 hover:bg-blue-700 disabled:bg-gray-400 disabled:cursor-not-allowed text-white font-medium rounded-md shadow-sm transition-colors"
              >
                <.icon name="hero-user-plus" class="w-4 h-4 mr-2" /> Assign
              </button>
            </div>
          </.form>
        </div>

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
              <button
                :if={
                  @session.status in ["draft", "initializing", "in_progress"] and
                    @can_assign_librarians
                }
                phx-click="remove_librarian"
                phx-value-assignment-id={assignment.id}
                data-confirm="Are you sure you want to remove this librarian from the session?"
                class="text-red-600 hover:text-red-800 dark:text-red-400 dark:hover:text-red-300 p-1 rounded"
                title="Remove librarian"
              >
                <.icon name="hero-user-minus" class="w-4 h-4" />
              </button>
              <button
                :if={
                  assignment.work_status != "completed" and
                    @session.status in ["draft", "initializing", "in_progress"] and
                    @can_assign_librarians
                }
                phx-click="open_complete_modal"
                phx-value-assignment-id={assignment.id}
                class="text-green-600 hover:text-green-800 dark:text-green-400 dark:hover:text-green-300 p-1 rounded"
                title="Mark as completed"
              >
                <.icon name="hero-check-circle" class="w-4 h-4" />
              </button>
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
          navigate={~p"/manage/catalog/stock_opname/#{@session.id}/scan"}
          class="px-4 py-2 bg-blue-600 hover:bg-blue-700 text-white font-medium rounded-lg transition-colors"
        >
          <.icon name="hero-qr-code" class="w-5 h-5 inline mr-2" /> Continue Scanning
        </.link>
        <.link
          :if={@can_create and @session.status == "pending_review"}
          navigate={~p"/manage/catalog/stock_opname/#{@session.id}/review"}
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
              :for={tab <- ["all", "checked", "pending", "missing", "with_changes"]}
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

    <%!-- Complete Librarian Modal --%>
    <%= if @show_complete_modal do %>
      <.modal id="complete-librarian-modal" show={true} on_cancel={JS.push("cancel_complete_modal")}>
        <div class="flex items-start gap-4">
          <div class="flex-none">
            <.icon name="hero-exclamation-triangle-solid" class="h-8 w-8 text-red-600" />
          </div>
          <div class="flex-1">
            <h3 class="text-lg font-semibold">Mark Librarian as Completed</h3>
            <p class="mt-2 text-sm text-gray-600 dark:text-gray-400">
              Are you sure you want to mark this librarian's work as completed? This action cannot be undone.
            </p>
            <div class="mt-6 flex justify-end gap-3">
              <button
                type="button"
                phx-click="cancel_complete_modal"
                class="px-4 py-2 text-sm font-medium text-gray-700 dark:text-gray-300 bg-white dark:bg-gray-700 border border-gray-300 dark:border-gray-600 rounded-md hover:bg-gray-50 dark:hover:bg-gray-600"
              >
                Cancel
              </button>
              <button
                type="button"
                phx-click="confirm_complete_librarian"
                class="px-4 py-2 text-sm font-medium text-white bg-green-600 hover:bg-green-700 rounded-md"
              >
                Mark as Completed
              </button>
            </div>
          </div>
        </div>
      </.modal>
    <% end %>
    """
  end

  @spec mount(map(), any(), Phoenix.LiveView.Socket.t()) :: {:ok, map()}
  def mount(%{"id" => id}, _session, socket) do
    session = StockOpname.get_session_without_items!(id)
    current_user = socket.assigns.current_scope.user

    # Check if user can view this session
    if StockOpnameAuthorization.can_view_session?(current_user, session) do
      can_create = StockOpnameAuthorization.can_create_session?(current_user)
      can_scan = StockOpnameAuthorization.can_scan_items?(current_user, session)
      can_delete = StockOpnameAuthorization.can_delete_session?(current_user, session)
      can_assign_librarians = Authorization.is_super_admin?(current_user)

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

      # Get available librarians for assignment
      available_librarians = StockOpname.list_available_librarians(session, current_user)

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
        |> assign(:can_assign_librarians, can_assign_librarians)
        |> assign(:pagination, pagination)
        |> assign(:displayed_items, pagination.items)
        |> assign(:current_tab, "all")
        |> assign(:items_added, items_added)
        |> assign(:all_librarians_completed, StockOpname.all_librarians_completed?(session))
        |> assign(:librarian_pagination, librarian_pagination)
        |> assign(:available_librarians, available_librarians)
        |> assign(:search_term, "")
        |> assign(:filtered_librarians, [])
        |> assign(:selected_librarian_id, nil)
        |> assign(:selected_librarian, nil)
        |> assign(:show_complete_modal, false)
        |> assign(:selected_assignment_id, nil)

      {:ok, socket}
    else
      socket =
        socket
        |> put_flash(:error, "You don't have permission to view this session")
        |> redirect(to: ~p"/manage/catalog/stock_opname")

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
          |> redirect(to: ~p"/manage/catalog/stock_opname")

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
          |> redirect(to: ~p"/manage/catalog/stock_opname")

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

  def handle_event("assign_librarian", _params, socket) do
    librarian_id = socket.assigns.selected_librarian_id

    if librarian_id do
      case StockOpname.assign_librarian(
             socket.assigns.session,
             librarian_id,
             socket.assigns.current_user
           ) do
        {:ok, _assignment} ->
          # Reload session and available librarians
          session = StockOpname.get_session_without_items!(socket.assigns.session.id)

          available_librarians =
            StockOpname.list_available_librarians(session, socket.assigns.current_user)

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

          socket =
            socket
            |> assign(:session, session)
            |> assign(:available_librarians, available_librarians)
            |> assign(:librarian_pagination, librarian_pagination)
            |> assign(:all_librarians_completed, StockOpname.all_librarians_completed?(session))
            |> assign(:search_term, "")
            |> assign(:filtered_librarians, [])
            |> assign(:selected_librarian_id, nil)
            |> assign(:selected_librarian, nil)
            |> put_flash(:info, "Librarian assigned successfully!")

          {:noreply, socket}

        {:error, :librarian_already_assigned} ->
          {:noreply,
           put_flash(socket, :error, "This librarian is already assigned to the session")}

        {:error, :invalid_session_status} ->
          {:noreply,
           put_flash(socket, :error, "Cannot assign librarians to sessions in this status")}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to assign librarian")}
      end
    else
      {:noreply, put_flash(socket, :error, "Please select a librarian first")}
    end
  end

  def handle_event("remove_librarian", %{"assignment-id" => assignment_id}, socket) do
    case StockOpname.remove_librarian(assignment_id, socket.assigns.current_user) do
      {:ok, _assignment} ->
        # Reload session and available librarians
        session = StockOpname.get_session_without_items!(socket.assigns.session.id)

        available_librarians =
          StockOpname.list_available_librarians(session, socket.assigns.current_user)

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

        socket =
          socket
          |> assign(:session, session)
          |> assign(:available_librarians, available_librarians)
          |> assign(:librarian_pagination, librarian_pagination)
          |> assign(:all_librarians_completed, StockOpname.all_librarians_completed?(session))
          |> put_flash(:info, "Librarian removed successfully!")

        {:noreply, socket}

      {:error, :assignment_not_found} ->
        {:noreply, put_flash(socket, :error, "Librarian assignment not found")}

      {:error, :cannot_remove_completed_assignment} ->
        {:noreply,
         put_flash(socket, :error, "Cannot remove librarians who have completed their work")}

      {:error, :invalid_session_status} ->
        {:noreply,
         put_flash(socket, :error, "Cannot remove librarians from sessions in this status")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to remove librarian")}
    end
  end

  def handle_event("open_complete_modal", %{"assignment-id" => assignment_id}, socket) do
    socket =
      socket
      |> assign(:show_complete_modal, true)
      |> assign(:selected_assignment_id, assignment_id)

    {:noreply, socket}
  end

  def handle_event("cancel_complete_modal", _params, socket) do
    socket =
      socket
      |> assign(:show_complete_modal, false)
      |> assign(:selected_assignment_id, nil)

    {:noreply, socket}
  end

  def handle_event("confirm_complete_librarian", _params, socket) do
    assignment_id = socket.assigns.selected_assignment_id

    if assignment_id do
      case StockOpname.admin_complete_librarian_assignment(
             assignment_id,
             socket.assigns.current_user
           ) do
        {:ok, _assignment} ->
          # Reload session and available librarians
          session = StockOpname.get_session_without_items!(socket.assigns.session.id)

          available_librarians =
            StockOpname.list_available_librarians(session, socket.assigns.current_user)

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

          socket =
            socket
            |> assign(:session, session)
            |> assign(:available_librarians, available_librarians)
            |> assign(:librarian_pagination, librarian_pagination)
            |> assign(:all_librarians_completed, StockOpname.all_librarians_completed?(session))
            |> assign(:show_complete_modal, false)
            |> assign(:selected_assignment_id, nil)
            |> put_flash(:info, "Librarian's work marked as completed!")

          {:noreply, socket}

        {:error, :assignment_not_found} ->
          {:noreply,
           socket
           |> assign(:show_complete_modal, false)
           |> assign(:selected_assignment_id, nil)
           |> put_flash(:error, "Librarian assignment not found")}

        {:error, :already_completed} ->
          {:noreply,
           socket
           |> assign(:show_complete_modal, false)
           |> assign(:selected_assignment_id, nil)
           |> put_flash(:error, "This librarian's work is already completed")}

        {:error, :invalid_session_status} ->
          {:noreply,
           socket
           |> assign(:show_complete_modal, false)
           |> assign(:selected_assignment_id, nil)
           |> put_flash(:error, "Cannot complete assignments for sessions in this status")}

        {:error, _} ->
          {:noreply,
           socket
           |> assign(:show_complete_modal, false)
           |> assign(:selected_assignment_id, nil)
           |> put_flash(:error, "Failed to complete librarian's work")}
      end
    else
      {:noreply,
       socket
       |> assign(:show_complete_modal, false)
       |> assign(:selected_assignment_id, nil)
       |> put_flash(:error, "No assignment selected")}
    end
  end

  def handle_event("search_librarians", %{"search_term" => search_term}, socket) do
    filtered_librarians =
      if String.trim(search_term) == "" do
        []
      else
        socket.assigns.available_librarians
        |> Enum.filter(fn librarian ->
          fullname_match =
            librarian.fullname &&
              String.contains?(String.downcase(librarian.fullname), String.downcase(search_term))

          email_match =
            librarian.email &&
              String.contains?(String.downcase(librarian.email), String.downcase(search_term))

          !!fullname_match or !!email_match
        end)
        # Limit results for performance
        |> Enum.take(10)
      end

    socket =
      socket
      |> assign(:search_term, search_term)
      |> assign(:filtered_librarians, filtered_librarians)

    {:noreply, socket}
  end

  def handle_event("select_librarian", %{"id" => librarian_id}, socket) do
    selected_librarian = Enum.find(socket.assigns.available_librarians, &(&1.id == librarian_id))

    socket =
      socket
      |> assign(:selected_librarian_id, librarian_id)
      |> assign(:selected_librarian, selected_librarian)
      |> assign(:search_term, "")
      |> assign(:filtered_librarians, [])

    {:noreply, socket}
  end

  def handle_event("clear_selection", _params, socket) do
    socket =
      socket
      |> assign(:selected_librarian_id, nil)
      |> assign(:selected_librarian, nil)
      |> assign(:search_term, "")
      |> assign(:filtered_librarians, [])

    {:noreply, socket}
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
        |> assign(
          :available_librarians,
          StockOpname.list_available_librarians(session, socket.assigns.current_user)
        )
        |> assign(:search_term, "")
        |> assign(:filtered_librarians, [])
        |> assign(:selected_librarian_id, nil)
        |> assign(:selected_librarian, nil)
        |> assign(:show_complete_modal, false)
        |> assign(:selected_assignment_id, nil)
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
