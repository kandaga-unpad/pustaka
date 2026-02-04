defmodule VoileWeb.Dashboard.StockOpnameLive.Scan do
  use VoileWeb, :live_view_dashboard

  alias Voile.Repo
  alias Voile.Schema.Catalog.Item
  alias Voile.Schema.StockOpname
  alias VoileWeb.Auth.StockOpnameAuthorization
  alias VoileWeb.Utils.FormatIndonesiaTime

  def render(assigns) do
    ~H"""
    <%!-- Load html5-qrcode library from CDN --%>
    <script
      src="https://unpkg.com/html5-qrcode@2.3.8/html5-qrcode.min.js"
      phx-track-static
    >
    </script>

    <style>
      /* Ensure scanner video is visible */
      #scanner-video video {
        width: 100% !important;
        height: auto !important;
        display: block !important;
      }

      #scanner-video canvas {
        width: 100% !important;
        height: auto !important;
      }

      #scanner-video {
        position: relative !important;
      }
    </style>

    <div class="container mx-auto px-2 sm:px-4 py-3 sm:py-6 max-w-7xl">
      <%!-- Header --%>
      <div class="mb-4 sm:mb-6">
        <.link
          navigate={~p"/manage/stock_opname/#{@session.id}"}
          class="text-blue-600 hover:text-blue-700 dark:text-blue-400 dark:hover:text-blue-300 flex items-center gap-2 mb-3 sm:mb-4 text-sm sm:text-base"
        >
          <.icon name="hero-arrow-left" class="w-4 h-4" /> Back to Session
        </.link>
        <div class="flex flex-col sm:flex-row sm:justify-between sm:items-start gap-2">
          <div class="flex-1">
            <h1 class="text-xl sm:text-2xl lg:text-3xl font-bold text-gray-900 dark:text-gray-100 break-words">
              {@session.title}
            </h1>

            <p class="text-sm sm:text-base text-gray-600 dark:text-gray-400 mt-1">
              Code: {@session.session_code}
            </p>
          </div>
          <.session_status_badge status={@session.status} />
        </div>
      </div>
      <%!-- Progress Bar --%>
      <div class="bg-white dark:bg-gray-800 rounded-lg shadow-sm p-3 sm:p-6 mb-4 sm:mb-6">
        <div class="flex flex-col sm:flex-row sm:justify-between sm:items-center gap-1 sm:gap-2 mb-2">
          <h2 class="text-base sm:text-lg font-semibold text-gray-900 dark:text-gray-100">
            Your Progress
          </h2>

          <span class="text-xs sm:text-sm text-gray-600 dark:text-gray-400">
            {@librarian_progress.items_checked} / {@session.total_items} items
          </span>
        </div>

        <div class="w-full bg-gray-200 dark:bg-gray-700 rounded-full h-2 sm:h-3 mb-3 sm:mb-4">
          <div
            class="bg-blue-600 dark:bg-blue-500 h-2 sm:h-3 rounded-full transition-all duration-500"
            style={"width: #{calculate_progress(@librarian_progress.items_checked, @session.total_items)}%"}
          >
          </div>
        </div>
        <%!-- Statistics --%>
        <div class="grid grid-cols-2 sm:grid-cols-4 gap-2 sm:gap-4">
          <div class="text-center p-2 sm:p-0">
            <p class="text-xl sm:text-2xl font-bold text-blue-600 dark:text-blue-500">
              {@session.checked_items}
            </p>

            <p class="text-xs text-gray-500 dark:text-gray-400">Total Checked</p>
          </div>

          <div class="text-center p-2 sm:p-0">
            <p class="text-xl sm:text-2xl font-bold text-gray-600 dark:text-gray-400">
              {@session.total_items - @session.checked_items}
            </p>

            <p class="text-xs text-gray-500 dark:text-gray-400">Remaining</p>
          </div>

          <div class="text-center p-2 sm:p-0">
            <p class="text-xl sm:text-2xl font-bold text-yellow-600 dark:text-yellow-500">
              {@session.items_with_changes}
            </p>

            <p class="text-xs text-gray-500 dark:text-gray-400">With Changes</p>
          </div>

          <div class="text-center p-2 sm:p-0">
            <p class="text-xl sm:text-2xl font-bold text-green-600 dark:text-green-500">
              {@librarian_progress.items_checked}
            </p>

            <p class="text-xs text-gray-500 dark:text-gray-400">Your Checks</p>
          </div>
        </div>
      </div>
      <%!-- Scanner Interface --%>
      <div class="bg-white dark:bg-gray-800 rounded-lg shadow-sm p-3 sm:p-6 mb-4 sm:mb-6">
        <h2 class="text-base sm:text-lg font-semibold text-gray-900 dark:text-gray-100 mb-3 sm:mb-4">
          Scan Item
        </h2>
        <%!-- Camera Scanner Section --%>
        <div class="mb-4 sm:mb-6">
          <div class="flex flex-col sm:flex-row sm:justify-between sm:items-center gap-2 sm:gap-0 mb-3">
            <h3 class="text-sm sm:text-md font-medium text-gray-700 dark:text-gray-300">
              Camera Scanner
            </h3>

            <button
              type="button"
              phx-click="toggle_scanner_mode"
              class="text-xs sm:text-sm px-3 py-2 sm:px-0 sm:py-0 bg-blue-50 sm:bg-transparent dark:bg-blue-900/20 sm:dark:bg-transparent rounded-lg sm:rounded-none text-blue-600 hover:text-blue-700 dark:text-blue-400 dark:hover:text-blue-300 font-medium sm:font-normal text-center"
            >
              {if @scanner_mode == "camera", do: "📝 Use Manual Input", else: "📷 Use Camera"}
            </button>
          </div>
          <%!-- Camera Scanner UI --%>
          <div
            :if={@scanner_mode == "camera"}
            id="barcode-scanner"
            phx-hook="BarcodeScanner"
            phx-update="ignore"
            class="space-y-3"
          >
            <%!-- Video Container --%>
            <div
              id="scanner-video"
              class="w-full bg-gray-900 rounded-lg overflow-hidden relative"
              style="min-height: 250px; max-width: 100%; margin: 0 auto;"
            >
            </div>
            <%!-- Scanner Controls --%>
            <div class="flex gap-2">
              <button
                id="start-scanner-btn"
                type="button"
                class="flex-1 px-3 sm:px-4 py-3 sm:py-3 bg-green-600 hover:bg-green-700 active:bg-green-800 text-white font-medium rounded-lg transition-colors flex items-center justify-center gap-2 text-sm sm:text-base touch-manipulation"
              >
                <.icon name="hero-camera" class="w-5 h-5" />
                <span class="hidden sm:inline">Start Camera</span><span class="sm:hidden">Start</span>
              </button>
              <button
                id="stop-scanner-btn"
                type="button"
                style="display: none;"
                class="flex-1 px-3 sm:px-4 py-3 sm:py-3 bg-red-600 hover:bg-red-700 active:bg-red-800 text-white font-medium rounded-lg transition-colors flex items-center justify-center gap-2 text-sm sm:text-base touch-manipulation"
              >
                <.icon name="hero-x-mark" class="w-5 h-5" />
                <span class="hidden sm:inline">Stop Camera</span><span class="sm:hidden">Stop</span>
              </button>
              <button
                id="switch-camera-btn"
                type="button"
                style="display: none;"
                class="px-3 sm:px-4 py-3 bg-blue-600 hover:bg-blue-700 active:bg-blue-800 text-white font-medium rounded-lg transition-colors touch-manipulation"
                title="Switch Camera"
              >
                <.icon name="hero-arrow-path" class="w-5 h-5" />
              </button>
            </div>

            <p class="text-xs sm:text-sm text-gray-500 dark:text-gray-400 px-1">
              <.icon name="hero-information-circle" class="w-4 h-4 inline" />
              Position the barcode in the scanning area. Auto-scans when detected.
            </p>
            <%!-- Troubleshooting Tips --%>
            <details class="text-xs text-gray-600 dark:text-gray-400">
              <summary class="cursor-pointer hover:text-gray-800 dark:hover:text-gray-200">
                Camera not working? Click for help
              </summary>

              <ul class="mt-2 ml-4 list-disc space-y-1">
                <li>Make sure no other app is using your camera</li>

                <li>Check browser permissions and allow camera access</li>

                <li>Try refreshing the page</li>

                <li>Try switching to manual input mode</li>

                <li>On mobile, ensure your browser has camera permissions in system settings</li>
              </ul>
            </details>
          </div>
        </div>
        <%!-- Manual Input Form --%>
        <form
          :if={@scanner_mode == "manual"}
          phx-submit="scan_item"
          class="mb-4"
        >
          <div class="flex gap-2">
            <div class="flex-1">
              <input
                type="text"
                name="search_term"
                value={@search_term}
                placeholder="Barcode or item code..."
                autofocus
                id="scan-input"
                phx-change="update_search_term"
                phx-keydown="scan_input_keydown"
                class="w-full px-3 sm:px-4 py-3 text-base sm:text-lg border-2 border-gray-300 dark:border-gray-600 rounded-lg focus:border-blue-500 focus:ring-2 focus:ring-blue-200 dark:bg-gray-700 dark:text-gray-100 touch-manipulation"
              />
            </div>

            <button
              type="submit"
              class="px-4 sm:px-6 py-3 bg-blue-600 hover:bg-blue-700 active:bg-blue-800 text-white font-medium rounded-lg transition-colors touch-manipulation"
            >
              <.icon name="hero-magnifying-glass" class="w-5 h-5 sm:w-6 sm:h-6" />
            </button>
          </div>

          <p class="text-xs sm:text-sm text-gray-500 dark:text-gray-400 mt-2 px-1">
            Barcode, legacy code, or item code
          </p>
        </form>
      </div>
      <%!-- Duplicate Results (if multiple items found) --%>
      <div
        :if={@duplicate_items != []}
        class="bg-yellow-50 dark:bg-yellow-900/20 border border-yellow-200 dark:border-yellow-800 rounded-lg p-3 sm:p-6 mb-4 sm:mb-6"
      >
        <h3 class="text-base sm:text-lg font-semibold text-yellow-900 dark:text-yellow-300 mb-3 sm:mb-4">
          Multiple Items - Select One
        </h3>

        <div class="space-y-2 sm:space-y-3">
          <button
            :for={opname_item <- @duplicate_items}
            type="button"
            phx-click="select_item"
            phx-value-id={opname_item.id}
            class="w-full text-left p-3 sm:p-4 bg-white dark:bg-gray-800 border-2 border-yellow-300 dark:border-yellow-600 hover:border-yellow-500 active:border-yellow-600 dark:hover:border-yellow-500 rounded-lg transition-colors touch-manipulation"
          >
            <div class="flex flex-col sm:flex-row sm:justify-between sm:items-start gap-2">
              <div class="flex-1">
                <p class="font-semibold text-sm sm:text-base text-gray-900 dark:text-gray-100">
                  {opname_item.item_code}
                </p>

                <p class="text-xs sm:text-sm text-gray-600 dark:text-gray-400">
                  {opname_item.collection_title}
                </p>

                <div class="flex flex-wrap gap-2 sm:gap-4 mt-2 text-xs text-gray-500 dark:text-gray-500">
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
        class="bg-white dark:bg-gray-800 rounded-lg shadow-lg p-3 sm:p-6 mb-4 sm:mb-6"
        phx-window-keydown="keyboard_shortcut"
        phx-key="Enter"
      >
        <div class="flex justify-between items-start mb-3 sm:mb-4">
          <h3 class="text-lg sm:text-xl font-semibold text-gray-900 dark:text-gray-100">
            Item Details
          </h3>

          <button
            type="button"
            phx-click="clear_item"
            class="text-gray-400 dark:text-gray-500 hover:text-gray-600 dark:hover:text-gray-400 p-1 touch-manipulation"
          >
            <.icon name="hero-x-mark" class="w-6 h-6" />
          </button>
        </div>
        <%!-- Actions at Top --%>
        <div class="flex gap-2 sm:gap-3 mb-4 sm:mb-6 pb-3 sm:pb-4 border-b border-gray-200 dark:border-gray-700">
          <button
            type="button"
            phx-click="check_item"
            class="flex-1 px-3 sm:px-4 py-3 bg-green-600 hover:bg-green-700 active:bg-green-800 text-white font-medium rounded-lg transition-colors text-sm sm:text-base touch-manipulation"
          >
            <.icon name="hero-check-circle" class="w-5 h-5 inline mr-1 sm:mr-2" /> <span class="hidden sm:inline">Mark as </span>Checked
          </button>
          <button
            type="button"
            phx-click="clear_item"
            class="px-3 sm:px-4 py-3 bg-gray-200 hover:bg-gray-300 active:bg-gray-400 dark:bg-gray-600 dark:hover:bg-gray-500 text-gray-700 dark:text-gray-200 font-medium rounded-lg transition-colors text-sm sm:text-base touch-manipulation"
          >
            Cancel
          </button>
        </div>

        <div class="space-y-3 sm:space-y-6">
          <%!-- Collection Information Section --%>
          <div class="bg-gradient-to-r from-purple-50 to-pink-50 dark:from-purple-900/20 dark:to-pink-900/20 rounded-lg p-3 sm:p-6">
            <h4 class="text-sm sm:text-base font-semibold text-gray-800 dark:text-gray-200 mb-3 sm:mb-4 flex items-center gap-2">
              <.icon
                name="hero-book-open"
                class="w-4 h-4 sm:w-5 sm:h-5 text-purple-600 dark:text-purple-400"
              /> Collection Information
            </h4>

            <form phx-change="update_field">
              <div class="space-y-3 sm:space-y-4">
                <div>
                  <label class="block text-xs sm:text-sm font-medium text-gray-700 dark:text-gray-300 mb-1 sm:mb-2">
                    Title <span class="text-xs text-blue-600 dark:text-blue-400">(Editable)</span>
                  </label>
                  <input
                    type="text"
                    name="collection_title"
                    value={@updated_values.collection_title}
                    phx-debounce="300"
                    class="w-full px-3 sm:px-4 py-2 sm:py-3 rounded-lg border-2 border-gray-200 dark:border-gray-600 focus:border-purple-500 focus:ring-2 focus:ring-purple-200 transition-all text-xs sm:text-sm bg-white dark:bg-gray-700 dark:text-gray-200 touch-manipulation"
                  />
                </div>
                <%!-- Creator/Author Search with Dropdown --%>
                <div class="relative">
                  <label class="block text-xs sm:text-sm font-medium text-gray-700 dark:text-gray-300 mb-1 sm:mb-2">
                    Author/Creator
                    <span class="text-xs text-blue-600 dark:text-blue-400">(Searchable)</span>
                  </label>
                  <div class="relative">
                    <input
                      type="text"
                      value={@creator_input}
                      phx-keyup="search_creator"
                      phx-debounce="300"
                      placeholder="Type to search creators..."
                      class="w-full px-3 sm:px-4 py-2 sm:py-3 rounded-lg border-2 border-gray-200 dark:border-gray-600 focus:border-purple-500 focus:ring-2 focus:ring-purple-200 transition-all text-xs sm:text-sm bg-white dark:bg-gray-700 dark:text-gray-200 touch-manipulation"
                    /> <%!-- Creator Suggestions Dropdown --%>
                    <div
                      :if={@creator_suggestions != []}
                      class="absolute z-50 w-full mt-1 bg-white dark:bg-gray-700 border border-gray-200 dark:border-gray-600 rounded-lg shadow-lg max-h-60 overflow-y-auto"
                    >
                      <button
                        :for={creator <- @creator_suggestions}
                        type="button"
                        phx-click="select_creator"
                        phx-value-id={creator.id}
                        class="w-full text-left px-3 py-2 hover:bg-purple-50 dark:hover:bg-purple-900/20 text-xs sm:text-sm text-gray-700 dark:text-gray-200 border-b last:border-b-0 border-gray-100 dark:border-gray-600"
                      >
                        {creator.creator_name}
                      </button>
                      <%!-- Load More Button --%>
                      <div
                        :if={not @creator_suggestions_done}
                        class="border-t border-gray-200 dark:border-gray-600"
                      >
                        <button
                          type="button"
                          phx-click="load_more_creator_suggestions"
                          class="w-full text-left px-3 py-2 text-xs sm:text-sm text-blue-600 hover:bg-purple-50 dark:hover:bg-purple-900/20 dark:text-blue-400"
                        >
                          Load More...
                        </button>
                      </div>
                    </div>
                  </div>
                  <%!-- Selected Creator Display --%>
                  <div :if={@updated_values[:creator_id]} class="mt-2 flex items-center gap-2">
                    <span class="text-xs text-green-600 dark:text-green-400">
                      <.icon name="hero-check-circle" class="w-4 h-4 inline" />
                      Selected: {@creator_input}
                    </span>
                    <button
                      type="button"
                      phx-click="clear_creator"
                      class="text-xs text-red-600 hover:text-red-700 dark:text-red-400"
                    >
                      Clear
                    </button>
                  </div>

                  <p class="text-xs text-gray-500 dark:text-gray-400 mt-1">
                    Start typing to search existing creators from database
                  </p>
                </div>
                <%!-- Display and edit collection fields --%>
                <div class="pt-2 border-t border-purple-200 dark:border-purple-800">
                  <div class="flex justify-between items-center mb-2">
                    <p class="text-xs font-medium text-gray-600 dark:text-gray-400">
                      Additional Metadata:
                    </p>
                    <!-- Add Field button removed -->
                  </div>
                  <!-- Add new field dropdown removed -->
                  <div class="space-y-2">
                    <%!-- Existing collection fields (editable) --%>
                    <div
                      :for={
                        field <-
                          Enum.filter(@current_item.collection.collection_fields, fn f ->
                            f.name not in ["creator", "author", "dcterms:creator"]
                          end)
                      }
                      class="bg-white dark:bg-gray-700/50 rounded p-2"
                    >
                      <div class="flex items-start gap-2">
                        <div class="flex-1">
                          <label class="block text-xs font-medium text-gray-600 dark:text-gray-400 mb-1">
                            {field.label || field.name}
                          </label>
                          <input
                            type="text"
                            name={"collection_field_#{field.id}"}
                            value={Map.get(@collection_field_edits, field.id, field.value)}
                            phx-change="update_collection_field"
                            phx-value-field-id={field.id}
                            phx-debounce="300"
                            class="w-full px-2 py-1 text-xs rounded border border-gray-300 dark:border-gray-600 dark:bg-gray-700 dark:text-gray-200"
                          />
                        </div>

                        <button
                          type="button"
                          phx-click="remove_collection_field"
                          phx-value-field-id={field.id}
                          class="text-red-600 hover:text-red-700 dark:text-red-400 mt-5"
                          title="Remove field"
                        >
                          <.icon name="hero-x-mark" class="w-4 h-4" />
                        </button>
                      </div>
                    </div>
                    <%!-- New fields being added --%>
                    <div
                      :for={
                        {field_key, field_data} <- Map.get(@collection_field_edits, :new_fields, %{})
                      }
                      class="bg-green-50 dark:bg-green-900/20 rounded p-2 border border-green-300 dark:border-green-700"
                    >
                      <div class="flex items-start gap-2">
                        <div class="flex-1">
                          <label class="block text-xs font-medium text-green-700 dark:text-green-400 mb-1">
                            {field_data.label} <span class="text-xs">(New)</span>
                          </label>
                          <input
                            type="text"
                            name={"new_collection_field_#{field_key}"}
                            value={field_data.value}
                            phx-change="update_new_collection_field"
                            phx-value-field-key={field_key}
                            phx-debounce="300"
                            class="w-full px-2 py-1 text-xs rounded border border-green-300 dark:border-green-600 dark:bg-gray-700 dark:text-gray-200"
                          />
                        </div>

                        <button
                          type="button"
                          phx-click="cancel_new_collection_field"
                          phx-value-field-key={field_key}
                          class="text-red-600 hover:text-red-700 dark:text-red-400 mt-5"
                          title="Cancel adding field"
                        >
                          <.icon name="hero-x-mark" class="w-4 h-4" />
                        </button>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            </form>
          </div>
          <%!-- Identification Section --%>
          <div class="bg-gradient-to-r from-blue-50 to-indigo-50 dark:from-blue-900/20 dark:to-indigo-900/20 rounded-lg p-3 sm:p-6">
            <h4 class="text-sm sm:text-base font-semibold text-gray-800 dark:text-gray-200 mb-3 sm:mb-4 flex items-center gap-2">
              <.icon
                name="hero-identification"
                class="w-4 h-4 sm:w-5 sm:h-5 text-blue-600 dark:text-blue-400"
              /> Item Identification
            </h4>

            <div class="grid grid-cols-1 sm:grid-cols-2 gap-3 sm:gap-4">
              <div>
                <label class="block text-xs sm:text-sm font-medium text-gray-700 dark:text-gray-300 mb-1 sm:mb-2">
                  Item Code <span class="text-gray-400 dark:text-gray-500 text-xs">(Read-only)</span>
                </label>
                <div class="bg-white dark:bg-gray-700 px-3 sm:px-4 py-2 sm:py-3 rounded-lg border border-gray-200 dark:border-gray-600 font-mono text-xs sm:text-sm text-gray-700 dark:text-gray-300 break-all">
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
          </div>
          <%!-- Status & Condition Section --%>
          <div class="bg-gradient-to-r from-green-50 to-emerald-50 dark:from-green-900/20 dark:to-emerald-900/20 rounded-lg p-3 sm:p-6">
            <h4 class="text-sm sm:text-base font-semibold text-gray-800 dark:text-gray-200 mb-3 sm:mb-4 flex items-center gap-2">
              <.icon
                name="hero-clipboard-document-check"
                class="w-4 h-4 sm:w-5 sm:h-5 text-green-600 dark:text-green-400"
              /> Status & Condition
            </h4>

            <form phx-change="update_field">
              <div class="grid grid-cols-1 sm:grid-cols-3 gap-3 sm:gap-4">
                <div>
                  <label class="block text-xs sm:text-sm font-medium text-gray-700 dark:text-gray-300 mb-1 sm:mb-2">
                    Status
                  </label>
                  <select
                    name="status"
                    phx-change="update_field"
                    class="w-full px-3 sm:px-4 py-2 sm:py-3 rounded-lg border-2 border-gray-200 dark:border-gray-600 focus:border-green-500 focus:ring-2 focus:ring-green-200 transition-all text-sm bg-white dark:bg-gray-700 dark:text-gray-200 touch-manipulation"
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
          <div class="bg-gradient-to-r from-purple-50 to-pink-50 dark:from-purple-900/20 dark:to-pink-900/20 rounded-lg p-3 sm:p-6">
            <h4 class="text-sm sm:text-base font-semibold text-gray-800 dark:text-gray-200 mb-3 sm:mb-4 flex items-center gap-2">
              <.icon
                name="hero-map-pin"
                class="w-4 h-4 sm:w-5 sm:h-5 text-purple-600 dark:text-purple-400"
              /> Location & Notes
            </h4>

            <div class="space-y-4">
              <div>
                <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                  Location <span class="text-xs text-gray-500">(from master locations)</span>
                </label>
                <form phx-change="update_field">
                  <select
                    name="item_location_id"
                    class="w-full px-4 py-3 rounded-lg border-2 border-gray-200 dark:border-gray-600 focus:border-purple-500 focus:ring-2 focus:ring-purple-200 transition-all text-sm dark:bg-gray-700 dark:text-gray-200"
                  >
                    <option value="">-- Select Location (Optional) --</option>

                    <option
                      :for={location <- @filtered_locations}
                      value={location.id}
                      selected={@updated_values[:item_location_id] == location.id}
                    >
                      {location.location_name} ({location.location_code})
                    </option>
                  </select>
                </form>

                <%= if @filtered_locations == [] do %>
                  <p class="text-xs text-gray-500 dark:text-gray-400 mt-1">
                    No locations available for this item's node.
                  </p>
                <% else %>
                  <p class="text-xs text-gray-500 dark:text-gray-400 mt-1">
                    Standardized locations for node: {@current_item.item.node.name}
                  </p>
                <% end %>
              </div>

              <div>
                <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                  Detailed Location <span class="text-xs text-gray-500">(free text)</span>
                </label>
                <form phx-change="update_field">
                  <input
                    type="text"
                    name="location"
                    value={@updated_values.location}
                    phx-debounce="300"
                    placeholder="e.g., Shelf 3A, Row 5, Box 12..."
                    class="w-full px-4 py-3 rounded-lg border-2 border-gray-200 dark:border-gray-600 focus:border-purple-500 focus:ring-2 focus:ring-purple-200 transition-all text-sm dark:bg-gray-700 dark:text-gray-200"
                  />
                </form>

                <p class="text-xs text-gray-500 dark:text-gray-400 mt-1">
                  Add specific details about the item's location
                </p>
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
      <div class="bg-white dark:bg-gray-800 rounded-lg shadow-sm p-3 sm:p-6">
        <h3 class="text-base sm:text-lg font-semibold text-gray-900 dark:text-gray-100 mb-3 sm:mb-4">
          Recently Scanned
        </h3>

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
            class="p-2 sm:p-3 bg-gray-50 dark:bg-gray-700 rounded-lg hover:bg-gray-100 dark:hover:bg-gray-600 transition-colors"
          >
            <div class="flex flex-col sm:flex-row sm:justify-between gap-2 sm:gap-0 sm:items-center">
              <div class="flex-1">
                <p class="text-sm sm:text-base font-medium text-gray-900 dark:text-gray-100 break-all">
                  {if opname_item.item, do: opname_item.item.item_code, else: "N/A"}
                </p>

                <p class="text-xs sm:text-sm text-gray-600 dark:text-gray-400 truncate">
                  {if opname_item.collection, do: opname_item.collection.title, else: "N/A"}
                </p>
              </div>

              <div class="flex items-center gap-2 sm:gap-3 flex-wrap">
                <.item_check_badge status={opname_item.check_status} />
                <span
                  :if={opname_item.has_changes}
                  class="text-xs text-yellow-600 dark:text-yellow-500 whitespace-nowrap"
                >
                  <.icon name="hero-pencil" class="w-3 h-3 sm:w-4 sm:h-4 inline" />
                  <span class="hidden sm:inline">Modified</span>
                </span>
                <span class="text-xs text-gray-500 dark:text-gray-400 whitespace-nowrap">
                  {FormatIndonesiaTime.format_utc_to_jakarta(
                    opname_item.scanned_at || opname_item.updated_at
                  )}
                </span>
              </div>
            </div>
          </div>
        </div>
      </div>
      <%!-- Complete Work Button --%>
      <div class="mt-4 sm:mt-6 bg-blue-50 dark:bg-blue-900/20 border border-blue-200 dark:border-blue-800 rounded-lg p-3 sm:p-6">
        <div class="flex flex-col sm:flex-row sm:justify-between gap-3 sm:gap-0 sm:items-center">
          <div class="flex-1">
            <h3 class="text-sm sm:text-base font-semibold text-blue-900 dark:text-blue-300 mb-1">
              Finished checking items?
            </h3>

            <p class="text-xs sm:text-sm text-blue-700 dark:text-blue-400">
              Mark your work session as completed.
            </p>
          </div>

          <button
            type="button"
            phx-click={show_modal("complete-work-modal")}
            class="px-4 sm:px-6 py-2 sm:py-3 bg-blue-600 hover:bg-blue-700 text-white font-medium rounded-lg transition-colors touch-manipulation"
          >
            <.icon name="hero-check-circle" class="w-5 h-5 inline mr-1 sm:mr-2" /> Complete Work
          </button>
        </div>
      </div>
      <%!-- Confirmation Modal --%>
      <.modal id="complete-work-modal" show={false} on_cancel={hide_modal("complete-work-modal")}>
        <div class="flex items-start gap-4">
          <div class="flex-shrink-0">
            <.icon name="hero-exclamation-triangle" class="w-12 h-12 text-yellow-500" />
          </div>

          <div class="flex-1">
            <h3
              id="complete-work-modal-title"
              class="text-lg font-semibold text-gray-900 dark:text-gray-100 mb-2"
            >
              Complete Your Work?
            </h3>

            <p
              id="complete-work-modal-description"
              class="text-sm text-gray-600 dark:text-gray-400 mb-4"
            >
              Are you sure you want to mark your work as completed? Once completed, you won't be able to scan more items unless an admin reopens your session.
            </p>

            <div class="flex gap-3 justify-end">
              <button
                type="button"
                phx-click={hide_modal("complete-work-modal")}
                class="px-4 py-2 bg-gray-200 hover:bg-gray-300 dark:bg-gray-700 dark:hover:bg-gray-600 text-gray-800 dark:text-gray-200 font-medium rounded-lg transition-colors"
              >
                Cancel
              </button>

              <button
                type="button"
                phx-click="confirm_complete_work"
                class="px-4 py-2 bg-blue-600 hover:bg-blue-700 text-white font-medium rounded-lg transition-colors"
              >
                Yes, Complete Work
              </button>
            </div>
          </div>
        </div>
      </.modal>
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
            # Check if work is already completed
            if librarian_progress.work_status == "completed" do
              socket =
                socket
                |> put_flash(
                  :error,
                  "Your work session is already completed. Contact an admin to reopen it."
                )
                |> redirect(to: ~p"/manage/stock_opname/#{session.id}")

              {:ok, socket}
            else
              # Load recent items (database query with LIMIT for efficiency)
              recent_items =
                StockOpname.list_recent_checked_items_by_user(session, current_user, 10)

              # Load locations from mst_locations for location dropdown
              locations = Voile.Schema.Master.list_mst_locations()

              socket =
                socket
                |> assign(:page_title, "Scan Items - #{session.title}")
                |> assign(:session, session)
                |> assign(:current_user, current_user)
                |> assign(:librarian_progress, librarian_progress)
                |> assign(:search_term, "")
                |> assign(:scanner_mode, "manual")
                |> assign(:current_item, nil)
                |> assign(:duplicate_items, [])
                |> assign(:updated_values, %{})
                |> assign(:places, locations)
                |> assign(:recent_items_count, length(recent_items))
                |> assign(:creator_input, "")
                |> assign(:creator_suggestions, [])
                |> assign(:creator_suggestions_offset, 0)
                |> assign(:creator_suggestions_done, false)
                |> assign(:available_metadata_properties, [])
                |> assign(:collection_field_edits, %{})
                |> assign(:show_add_field_dropdown, false)
                |> stream(:recent_items, recent_items)

              {:ok, socket}
            end

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
    original_collection = opname_item.collection
    collection_field_edits = socket.assigns.collection_field_edits

    # Build item changes map - only include fields that actually changed
    item_changes = %{}

    item_changes =
      if Map.has_key?(updated, :status) && updated.status != original_item.status,
        do: Map.put(item_changes, "status", updated.status),
        else: item_changes

    item_changes =
      if Map.has_key?(updated, :condition) && updated.condition != original_item.condition,
        do: Map.put(item_changes, "condition", updated.condition),
        else: item_changes

    item_changes =
      if Map.has_key?(updated, :availability) &&
           updated.availability != original_item.availability,
         do: Map.put(item_changes, "availability", updated.availability),
         else: item_changes

    item_changes =
      if Map.has_key?(updated, :location) && updated.location != original_item.location,
        do: Map.put(item_changes, "location", updated.location),
        else: item_changes

    # Handle item_location_id (convert empty string to nil for comparison)
    updated_location_id =
      case Map.get(updated, :item_location_id) do
        "" -> nil
        nil -> nil
        id when is_binary(id) -> String.to_integer(id)
        id -> id
      end

    item_changes =
      if Map.has_key?(updated, :item_location_id) &&
           updated_location_id != original_item.item_location_id,
         do: Map.put(item_changes, "item_location_id", updated_location_id),
         else: item_changes

    # Build collection changes map
    collection_changes = %{}

    collection_changes =
      if Map.has_key?(updated, :collection_title) &&
           updated.collection_title != original_collection.title,
         do: Map.put(collection_changes, "title", updated.collection_title),
         else: collection_changes

    # Handle creator_id changes (proper reference to mst_creator)
    collection_changes =
      if Map.has_key?(updated, :creator_id) &&
           updated.creator_id != original_collection.creator_id,
         do: Map.put(collection_changes, "creator_id", updated.creator_id),
         else: collection_changes

    # Handle collection_field changes
    collection_field_changes =
      build_collection_field_changes(
        original_collection.collection_fields,
        collection_field_edits
      )

    # Add collection_field_changes to collection_changes if there are any
    collection_changes =
      if collection_field_changes != %{} do
        Map.put(collection_changes, "collection_field_changes", collection_field_changes)
      else
        collection_changes
      end

    require Logger
    Logger.debug("=== CHECK ITEM DEBUG ===")
    Logger.debug("Updated values: #{inspect(updated)}")
    Logger.debug("Item changes: #{inspect(item_changes)}")
    Logger.debug("Collection changes: #{inspect(collection_changes)}")
    Logger.debug("Collection field edits: #{inspect(collection_field_edits)}")
    Logger.debug("Notes: #{inspect(updated.notes)}")

    case StockOpname.check_item_with_collection(
           socket.assigns.session,
           opname_item.id,
           item_changes,
           collection_changes,
           updated.notes,
           socket.assigns.current_user
         ) do
      {:ok, checked_item} ->
        # Efficient: do NOT preload all items, just reload session meta
        session = StockOpname.get_session_without_items!(socket.assigns.session.id)

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

  def handle_event("toggle_scanner_mode", _params, socket) do
    new_mode = if socket.assigns.scanner_mode == "camera", do: "manual", else: "camera"
    {:noreply, assign(socket, :scanner_mode, new_mode)}
  end

  def handle_event("barcode_scanned", %{"barcode" => barcode}, socket) do
    # Automatically search for the scanned barcode
    items = StockOpname.find_items_for_scanning(socket.assigns.session, barcode)

    socket =
      case length(items) do
        0 ->
          socket
          |> put_flash(:error, "Item not found: #{barcode}")

        1 ->
          [opname_item] = items
          load_item_for_checking(socket, opname_item)

        _ ->
          socket
          |> assign(:duplicate_items, items)
          |> put_flash(:info, "Multiple items found. Please select one.")
      end

    {:noreply, socket}
  end

  def handle_event("scanner_error", %{"error" => error}, socket) do
    {:noreply, put_flash(socket, :error, "Scanner error: #{error}")}
  end

  def handle_event("scanner_started", _params, socket) do
    {:noreply, put_flash(socket, :info, "Camera started. Position barcode in view.")}
  end

  def handle_event("scanner_stopped", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("search_creator", %{"value" => query}, socket) do
    trimmed = String.trim(query)

    if trimmed == "" or String.length(trimmed) < 2 do
      {:noreply,
       assign(socket,
         creator_input: query,
         creator_suggestions: [],
         creator_suggestions_offset: 0,
         creator_suggestions_done: false
       )}
    else
      suggestions = Voile.Schema.Master.search_mst_creator_names(trimmed, 20, 0)
      done = length(suggestions) < 20

      {:noreply,
       assign(socket,
         creator_input: query,
         creator_suggestions: suggestions,
         creator_suggestions_offset: 20,
         creator_suggestions_done: done
       )}
    end
  end

  def handle_event("load_more_creator_suggestions", _params, socket) do
    trimmed = String.trim(socket.assigns.creator_input || "")
    offset = socket.assigns.creator_suggestions_offset || 0

    if trimmed == "" or String.length(trimmed) < 2 or socket.assigns.creator_suggestions_done do
      {:noreply, socket}
    else
      more = Voile.Schema.Master.search_mst_creator_names(trimmed, 20, offset)
      done = length(more) < 20

      {:noreply,
       socket
       |> assign(:creator_suggestions, socket.assigns.creator_suggestions ++ more)
       |> assign(:creator_suggestions_offset, offset + 20)
       |> assign(:creator_suggestions_done, done)}
    end
  end

  def handle_event("select_creator", %{"id" => creator_id}, socket) do
    creator =
      Enum.find(socket.assigns.creator_suggestions, fn c -> to_string(c.id) == creator_id end)

    if creator do
      updated_values =
        socket.assigns.updated_values
        |> Map.put(:creator_id, creator.id)
        |> Map.put(:collection_author, creator.creator_name)

      {:noreply,
       socket
       |> assign(:creator_input, creator.creator_name)
       |> assign(:creator_suggestions, [])
       |> assign(:creator_suggestions_offset, 0)
       |> assign(:creator_suggestions_done, false)
       |> assign(:updated_values, updated_values)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("clear_creator", _params, socket) do
    updated_values =
      socket.assigns.updated_values
      |> Map.delete(:creator_id)
      |> Map.put(:collection_author, "")

    {:noreply,
     socket
     |> assign(:creator_input, "")
     |> assign(:creator_suggestions, [])
     |> assign(:creator_suggestions_offset, 0)
     |> assign(:creator_suggestions_done, false)
     |> assign(:updated_values, updated_values)}
  end

  def handle_event("update_collection_field", params, socket) do
    require Logger
    Logger.debug("update_collection_field params: #{inspect(params)}")

    # Get field name from _target
    field_name =
      case params["_target"] do
        [field_name] -> field_name
        [field_name | _] -> field_name
        _ -> nil
      end

    # Extract field_id from the field name
    field_id =
      if field_name && String.starts_with?(field_name, "collection_field_") do
        String.replace(field_name, "collection_field_", "")
      else
        params["field-id"]
      end

    if field_name && Map.has_key?(params, field_name) && field_id do
      value = params[field_name]

      collection_field_edits =
        Map.put(socket.assigns.collection_field_edits, field_id, value)

      Logger.debug("Collection field updated: #{field_id} = #{value}")

      {:noreply, assign(socket, :collection_field_edits, collection_field_edits)}
    else
      Logger.debug("Could not extract collection field from params")
      {:noreply, socket}
    end
  end

  def handle_event("update_new_collection_field", params, socket) do
    require Logger
    Logger.debug("update_new_collection_field params: #{inspect(params)}")

    # Get field name from _target
    field_name =
      case params["_target"] do
        [field_name] -> field_name
        [field_name | _] -> field_name
        _ -> nil
      end

    # Extract field_key from the field name
    field_key =
      if field_name && String.starts_with?(field_name, "new_collection_field_") do
        String.replace(field_name, "new_collection_field_", "")
      else
        params["field-key"]
      end

    if field_name && Map.has_key?(params, field_name) && field_key do
      value = params[field_name]

      collection_field_edits =
        update_in(
          socket.assigns.collection_field_edits,
          [:new_fields, field_key],
          fn field_data ->
            Map.put(field_data, :value, value)
          end
        )

      Logger.debug("New collection field updated: #{field_key} = #{value}")

      {:noreply, assign(socket, :collection_field_edits, collection_field_edits)}
    else
      Logger.debug("Could not extract new collection field from params")
      {:noreply, socket}
    end
  end

  def handle_event("remove_collection_field", %{"field-id" => field_id}, socket) do
    # Mark field for deletion
    collection_field_edits =
      Map.update(
        socket.assigns.collection_field_edits,
        :deleted_fields,
        [field_id],
        fn deleted -> [field_id | deleted] end
      )

    {:noreply, assign(socket, :collection_field_edits, collection_field_edits)}
  end

  def handle_event("cancel_new_collection_field", %{"field-key" => field_key}, socket) do
    # Get the property to add back to available list
    new_field_data = get_in(socket.assigns.collection_field_edits, [:new_fields, field_key])

    property =
      if new_field_data do
        # Find the property from the original list by using the collection template
        opname_item = socket.assigns.current_item

        if opname_item.collection.resource_template do
          opname_item.collection.resource_template.template_properties
          |> Enum.find(fn tp -> tp.property.id == new_field_data.property_id end)
          |> case do
            nil -> nil
            tp -> tp.property
          end
        end
      end

    # Remove from new_fields
    collection_field_edits =
      update_in(socket.assigns.collection_field_edits, [:new_fields], fn fields ->
        Map.delete(fields || %{}, field_key)
      end)

    # Add property back to available list if found
    socket =
      if property do
        available_properties = [property | socket.assigns.available_metadata_properties]
        assign(socket, :available_metadata_properties, available_properties)
      else
        socket
      end

    {:noreply, assign(socket, :collection_field_edits, collection_field_edits)}
  end

  def handle_event("complete_work", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("cancel_complete_work", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("confirm_complete_work", _params, socket) do
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
      |> put_flash(:error, "This item has already been checked.")
      |> assign(:search_term, "")
      |> assign(:metadata_search, "")
      |> assign(:filtered_metadata_properties, [])
    else
      # Preload collection with creator, collection_fields, resource_template, and item with node
      opname_item =
        Repo.preload(opname_item,
          collection: [
            :mst_creator,
            :collection_fields,
            resource_template: [template_properties: :property]
          ],
          item: :node
        )

      # Get available metadata properties from the collection's template
      available_properties =
        if opname_item.collection.resource_template do
          opname_item.collection.resource_template.template_properties
          |> Enum.map(& &1.property)
          |> Enum.filter(fn prop ->
            # Exclude properties already in collection_fields and creator-related fields
            !Enum.any?(opname_item.collection.collection_fields, fn field ->
              field.name == prop.name
            end) and
              prop.name not in ["creator", "author", "dcterms:creator"]
          end)
        else
          []
        end

      # Filter locations by item's node - get the node_id from the item
      item_node_id = opname_item.item.unit_id

      # Filter locations to only show those belonging to the item's node
      filtered_locations =
        if item_node_id do
          Enum.filter(socket.assigns.places, fn location -> location.node_id == item_node_id end)
        else
          []
        end

      # Load the current values from the actual item
      # Initialize updated_values with current item values
      author_name = get_collection_author(opname_item.collection) || ""

      updated_values = %{
        status: opname_item.item.status,
        condition: opname_item.item.condition,
        availability: opname_item.item.availability,
        # Free text field
        location: opname_item.item.location || "",
        item_location_id: opname_item.item.item_location_id,
        notes: opname_item.notes || "",
        # Collection fields
        collection_title: opname_item.collection.title || "",
        collection_author: author_name,
        creator_id: opname_item.collection.creator_id
      }

      # Always assign :metadata_search and :filtered_metadata_properties
      socket
      |> assign(:current_item, opname_item)
      |> assign(:updated_values, updated_values)
      |> assign(:creator_input, author_name)
      |> assign(:creator_suggestions, [])
      |> assign(:creator_suggestions_offset, 0)
      |> assign(:creator_suggestions_done, false)
      |> assign(:available_metadata_properties, available_properties)
      |> assign(:filtered_metadata_properties, available_properties)
      |> assign(:filtered_locations, filtered_locations)
      |> assign(:metadata_search, "")
      |> assign(:collection_field_edits, %{})
      |> assign(:show_add_field_dropdown, false)
      |> assign(:search_term, "")
    end
  end

  defp build_collection_field_changes(original_fields, edits) do
    changes = %{}

    # Handle updated fields
    updated_fields =
      original_fields
      |> Enum.filter(fn field ->
        edited_value = Map.get(edits, field.id)
        edited_value && edited_value != field.value
      end)
      |> Enum.map(fn field ->
        %{
          id: field.id,
          value: Map.get(edits, field.id)
        }
      end)

    changes =
      if updated_fields != [] do
        Map.put(changes, :updated, updated_fields)
      else
        changes
      end

    # Handle new fields
    new_fields =
      edits
      |> Map.get(:new_fields, %{})
      |> Enum.map(fn {_key, field_data} ->
        %{
          property_id: field_data.property_id,
          name: field_data.name,
          label: field_data.label,
          value: field_data.value
        }
      end)

    changes =
      if new_fields != [] do
        Map.put(changes, :new, new_fields)
      else
        changes
      end

    # Handle deleted fields
    deleted_fields = Map.get(edits, :deleted_fields, [])

    changes =
      if deleted_fields != [] do
        Map.put(changes, :deleted, deleted_fields)
      else
        changes
      end

    changes
  end

  defp get_collection_author(collection) do
    cond do
      collection.mst_creator && collection.mst_creator.creator_name ->
        collection.mst_creator.creator_name

      true ->
        # Try to find author from collection_fields
        author_field =
          Enum.find(collection.collection_fields || [], fn field ->
            field.name in ["creator", "author", "dcterms:creator"]
          end)

        if author_field, do: author_field.value, else: ""
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
    <span class={["inline-flex items-center px-3 py-1 text-sm font-medium rounded-full", @color]}>
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
    <span class={["inline-flex items-center px-2 py-1 text-xs font-medium rounded", @color]}>
      {@label}
    </span>
    """
  end
end
