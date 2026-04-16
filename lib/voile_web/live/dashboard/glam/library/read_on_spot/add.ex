defmodule VoileWeb.Dashboard.Glam.Library.ReadOnSpotLive.Add do
  use VoileWeb, :live_view_dashboard

  alias Voile.Schema.Library.Feats
  alias VoileWeb.Utils.FormatIndonesiaTime

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_scope.user
    is_super_admin = is_super_admin?(current_user)

    nodes =
      if is_super_admin do
        Feats.list_nodes()
      else
        []
      end

    default_node_id =
      if is_super_admin do
        nil
      else
        current_user.node_id
      end

    locations =
      if default_node_id do
        Feats.list_locations_by_node(default_node_id)
      else
        []
      end

    socket =
      socket
      |> assign(:page_title, "Read On Spot — Scan Items")
      |> assign(:is_super_admin, is_super_admin)
      |> assign(:current_user, current_user)
      |> assign(:nodes, nodes)
      |> assign(:selected_node_id, default_node_id)
      |> assign(:locations, locations)
      |> assign(:selected_location_id, nil)
      |> assign(:scanner_mode, "manual")
      |> assign(:search_term, "")
      |> assign(:found_items, [])
      |> assign(:scan_error, nil)
      |> assign(:scan_count, 0)
      |> assign(:read_at_input, "")
      |> stream(:scanned_records, [])

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <%!-- Load html5-qrcode from CDN for camera scanning --%>
    <script src="https://unpkg.com/html5-qrcode@2.3.8/html5-qrcode.min.js" phx-track-static>
    </script>

    <div class="container mx-auto px-2 sm:px-4 py-4 max-w-4xl">
      <%!-- Header --%>
      <div class="mb-6">
        <.breadcrumb items={[
          %{label: "Manage", path: ~p"/manage"},
          %{label: "GLAM", path: ~p"/manage/glam"},
          %{label: "Library", path: ~p"/manage/glam/library"},
          %{label: "Read On Spot", path: ~p"/manage/glam/library/read_on_spot"},
          %{label: "Scan Items", path: nil}
        ]} />
        <h1 class="text-2xl font-bold text-gray-800 dark:text-white mt-3">
          Read On Spot — Scan Items
        </h1>
        <p class="text-gray-500 dark:text-gray-400 text-sm mt-1">
          Scan or enter item barcodes to record items being read or used in-library.
        </p>
      </div>
      <%!-- Context Selection (Node + Location + optional read_at) --%>
      <div class="bg-white dark:bg-gray-800 rounded-lg shadow-sm p-4 mb-5">
        <h2 class="text-sm font-semibold text-gray-700 dark:text-gray-300 mb-3 uppercase tracking-wide">
          Scanning Context
        </h2>
        <div class={[
          "grid gap-4",
          if(@is_super_admin, do: "grid-cols-1 sm:grid-cols-2", else: "grid-cols-1 sm:grid-cols-2")
        ]}>
          <%= if @is_super_admin do %>
            <div>
              <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                Node / Branch
              </label>
              <select
                id="node-select"
                phx-change="select_node"
                name="node_id"
                class="w-full rounded-lg border border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-700 text-gray-900 dark:text-white px-3 py-2 text-sm focus:ring-2 focus:ring-blue-500"
              >
                <option value="">— Select Node —</option>
                <%= for node <- @nodes do %>
                  <option
                    value={node.id}
                    selected={to_string(node.id) == to_string(@selected_node_id)}
                  >
                    {node.name}
                  </option>
                <% end %>
              </select>
            </div>
          <% end %>
          <div>
            <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
              Room / Location <span class="text-gray-400 font-normal text-xs">(optional)</span>
            </label>
            <select
              id="location-select"
              phx-change="select_location"
              name="location_id"
              class="w-full rounded-lg border border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-700 text-gray-900 dark:text-white px-3 py-2 text-sm focus:ring-2 focus:ring-blue-500"
              disabled={@locations == []}
            >
              <option value="">— Select Room —</option>
              <%= for loc <- @locations do %>
                <option
                  value={loc.id}
                  selected={to_string(loc.id) == to_string(@selected_location_id)}
                >
                  {loc.location_name}
                </option>
              <% end %>
            </select>
            <%= if @locations == [] && @selected_node_id == nil && @is_super_admin do %>
              <p class="text-xs text-gray-400 mt-1">Select a node first.</p>
            <% end %>
            <%= if @locations == [] && @selected_node_id != nil do %>
              <p class="text-xs text-yellow-500 mt-1">No active locations for this node.</p>
            <% end %>
          </div>
          <div class={if(@is_super_admin, do: "sm:col-span-2 sm:max-w-xs", else: "")}>
            <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
              Time Read
              <span class="text-gray-400 font-normal text-xs">(optional — defaults to now)</span>
            </label>
            <input
              id="read-at-input"
              type="datetime-local"
              name="read_at"
              value={@read_at_input}
              phx-change="update_read_at"
              class="w-full rounded-lg border border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-700 text-gray-900 dark:text-white px-3 py-2 text-sm focus:ring-2 focus:ring-blue-500"
            />
          </div>
        </div>
      </div>
      <%!-- Scanner Interface --%>
      <div class="bg-white dark:bg-gray-800 rounded-lg shadow-sm p-4 mb-5">
        <div class="flex items-center justify-between mb-3">
          <h2 class="text-sm font-semibold text-gray-700 dark:text-gray-300 uppercase tracking-wide">
            Barcode Scanner
          </h2>
          <button
            type="button"
            phx-click="toggle_scanner_mode"
            class="text-xs px-3 py-1.5 rounded-full bg-gray-100 dark:bg-gray-700 text-gray-700 dark:text-gray-300 hover:bg-gray-200 dark:hover:bg-gray-600 transition"
          >
            <%= if @scanner_mode == "camera" do %>
              <.icon name="hero-pencil" class="w-3.5 h-3.5 inline mr-1" /> Switch to Manual
            <% else %>
              <.icon name="hero-camera" class="w-3.5 h-3.5 inline mr-1" /> Switch to Camera
            <% end %>
          </button>
        </div>
        <%!-- Camera Mode --%>
        <%= if @scanner_mode == "camera" do %>
          <div
            id="barcode-scanner-container"
            phx-hook="BarcodeScanner"
            phx-update="ignore"
            class="space-y-3"
          >
            <div
              id="scanner-video"
              class="w-full bg-gray-900 rounded-lg overflow-hidden"
              style="min-height: 250px;"
            >
            </div>
            <div class="flex gap-2">
              <button
                id="start-scanner-btn"
                type="button"
                class="flex-1 px-4 py-2.5 bg-green-600 hover:bg-green-700 text-white text-sm font-medium rounded-lg transition flex items-center justify-center gap-2"
              >
                <.icon name="hero-camera" class="w-4 h-4" /> Start Camera
              </button>
              <button
                id="stop-scanner-btn"
                type="button"
                style="display: none;"
                class="flex-1 px-4 py-2.5 bg-red-600 hover:bg-red-700 text-white text-sm font-medium rounded-lg transition flex items-center justify-center gap-2"
              >
                <.icon name="hero-x-mark" class="w-4 h-4" /> Stop Camera
              </button>
              <button
                id="switch-camera-btn"
                type="button"
                style="display: none;"
                class="px-4 py-2.5 bg-blue-600 hover:bg-blue-700 text-white rounded-lg transition"
                title="Switch Camera"
              >
                <.icon name="hero-arrow-path" class="w-4 h-4" />
              </button>
            </div>
            <p class="text-xs text-gray-400">
              <.icon name="hero-information-circle" class="w-3.5 h-3.5 inline" />
              Press Start Camera, then point at a barcode — it scans automatically.
            </p>
          </div>
        <% end %>
        <%!-- Manual Input Mode --%>
        <%= if @scanner_mode == "manual" do %>
          <form id="scan-form" phx-submit="scan_item" class="flex gap-2">
            <input
              id="barcode-input"
              type="text"
              name="search_term"
              value={@search_term}
              placeholder="Enter barcode, item code, or inventory code…"
              phx-keydown="scan_input_keydown"
              autocomplete="off"
              class="flex-1 rounded-lg border border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-700 text-gray-900 dark:text-white px-3 py-2 text-sm focus:ring-2 focus:ring-blue-500"
            />
            <button
              type="submit"
              class="px-4 py-2 bg-blue-600 text-white text-sm rounded-lg hover:bg-blue-700 transition"
            >
              {gettext("Scan")}
            </button>
          </form>
        <% end %>
        <%!-- Scan Error --%>
        <%= if @scan_error do %>
          <div
            id="scan-error"
            class="mt-3 p-3 rounded-lg bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800 text-red-700 dark:text-red-300 text-sm flex items-center gap-2"
          >
            <.icon name="hero-exclamation-circle" class="w-4 h-4 shrink-0" />
            {@scan_error}
          </div>
        <% end %>
      </div>
      <%!-- Found Items (picker when multiple, auto-confirm when one) --%>
      <%= if @found_items != [] do %>
        <div class="bg-blue-50 dark:bg-blue-900/20 border border-blue-200 dark:border-blue-800 rounded-lg p-4 mb-5">
          <h3 class="text-sm font-semibold text-blue-800 dark:text-blue-200 mb-3">
            <%= if length(@found_items) == 1 do %>
              Item Found — Confirm to Record
            <% else %>
              Multiple items matched — Select one:
            <% end %>
          </h3>
          <div class="space-y-2">
            <%= for item <- @found_items do %>
              <div class="bg-white dark:bg-gray-800 rounded-lg p-3 flex items-start justify-between gap-3 shadow-sm">
                <div class="flex-1 min-w-0">
                  <p class="font-medium text-gray-900 dark:text-white text-sm truncate">
                    {if item.collection, do: item.collection.title, else: "Unknown Title"}
                  </p>
                  <div class="flex flex-wrap gap-x-3 gap-y-0.5 mt-1">
                    <span class="text-xs text-gray-500">Code: {item.item_code}</span>
                    <%= if item.barcode do %>
                      <span class="text-xs text-gray-500">Barcode: {item.barcode}</span>
                    <% end %>
                    <%= if item.item_location do %>
                      <span class="text-xs text-gray-500">{item.item_location.location_name}</span>
                    <% end %>
                  </div>
                </div>
                <button
                  type="button"
                  phx-click="record_item"
                  phx-value-item-id={item.id}
                  class="shrink-0 px-3 py-1.5 bg-green-600 text-white text-xs rounded-lg hover:bg-green-700 transition"
                >
                  <.icon name="hero-check" class="w-3.5 h-3.5 inline mr-1" /> Record
                </button>
              </div>
            <% end %>
          </div>
          <button
            type="button"
            phx-click="clear_found"
            class="mt-2 text-xs text-gray-500 hover:text-gray-700 dark:hover:text-gray-300"
          >
            Cancel
          </button>
        </div>
      <% end %>
      <%!-- Scan Summary --%>
      <div class="flex items-center justify-between mb-3">
        <span class="inline-flex items-center px-3 py-1 rounded-full bg-green-100 dark:bg-green-900/30 text-green-800 dark:text-green-200 text-sm font-medium">
          <.icon name="hero-check-circle" class="w-4 h-4 mr-1.5" />
          {@scan_count} recorded this session
        </span>
        <.link
          navigate={~p"/manage/glam/library/read_on_spot"}
          class="text-sm text-blue-600 hover:underline"
        >
          View Overview
        </.link>
      </div>
      <%!-- Recent Records Stream --%>
      <div class="bg-white dark:bg-gray-800 rounded-lg shadow-sm p-4">
        <h2 class="text-sm font-semibold text-gray-700 dark:text-gray-300 uppercase tracking-wide mb-3">
          Recently Scanned (This Session)
        </h2>
        <div id="scanned-records" phx-update="stream">
          <div class="text-gray-400 text-sm italic only:block hidden">
            No items scanned yet.
          </div>
          <%= for {dom_id, record} <- @streams.scanned_records do %>
            <div
              id={dom_id}
              class="flex items-start gap-3 py-2 border-b border-gray-100 dark:border-gray-700 last:border-0"
            >
              <div class="w-8 h-8 rounded-full bg-green-100 dark:bg-green-900/30 flex items-center justify-center shrink-0">
                <.icon name="hero-book-open" class="w-4 h-4 text-green-700 dark:text-green-300" />
              </div>
              <div class="flex-1 min-w-0">
                <p class="text-sm font-medium text-gray-900 dark:text-white truncate">
                  {record.title}
                </p>
                <div class="flex flex-wrap gap-x-3 text-xs text-gray-500 mt-0.5">
                  <span>{record.item_code}</span>
                  <%= if record.location_name do %>
                    <span>{record.location_name}</span>
                  <% end %>
                  <span>{record.recorded_at}</span>
                </div>
              </div>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("select_node", %{"node_id" => node_id}, socket) do
    node_id = if node_id == "", do: nil, else: String.to_integer(node_id)

    locations =
      if node_id do
        Feats.list_locations_by_node(node_id)
      else
        []
      end

    socket =
      socket
      |> assign(:selected_node_id, node_id)
      |> assign(:locations, locations)
      |> assign(:selected_location_id, nil)
      |> assign(:found_items, [])
      |> assign(:scan_error, nil)

    {:noreply, socket}
  end

  @impl true
  def handle_event("select_location", %{"location_id" => location_id}, socket) do
    location_id = if location_id == "", do: nil, else: String.to_integer(location_id)
    {:noreply, assign(socket, :selected_location_id, location_id)}
  end

  @impl true
  def handle_event("update_read_at", %{"read_at" => value}, socket) do
    {:noreply, assign(socket, :read_at_input, value)}
  end

  @impl true
  def handle_event("toggle_scanner_mode", _params, socket) do
    new_mode = if socket.assigns.scanner_mode == "camera", do: "manual", else: "camera"
    {:noreply, assign(socket, :scanner_mode, new_mode)}
  end

  @impl true
  def handle_event("scan_item", %{"search_term" => term}, socket) do
    term = String.trim(term)

    socket =
      if term == "" do
        socket
      else
        do_search(socket, term)
      end

    {:noreply, assign(socket, :search_term, "")}
  end

  @impl true
  def handle_event("barcode_scanned", %{"barcode" => barcode}, socket) do
    {:noreply, do_search(socket, barcode)}
  end

  @impl true
  def handle_event("scanner_error", %{"error" => error}, socket) do
    {:noreply, put_flash(socket, :error, "Scanner error: #{error}")}
  end

  @impl true
  def handle_event("scanner_started", _params, socket) do
    {:noreply, put_flash(socket, :info, "Camera started. Point at a barcode.")}
  end

  @impl true
  def handle_event("scanner_stopped", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("scan_input_keydown", %{"key" => "Escape"}, socket) do
    {:noreply, assign(socket, search_term: "", found_items: [], scan_error: nil)}
  end

  @impl true
  def handle_event("scan_input_keydown", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("record_item", %{"item-id" => item_id}, socket) do
    {:noreply, do_record(socket, item_id)}
  end

  @impl true
  def handle_event("clear_found", _params, socket) do
    {:noreply, assign(socket, found_items: [], scan_error: nil)}
  end

  # -----------------------------------------------------------------------
  # Private helpers
  # -----------------------------------------------------------------------

  defp do_search(socket, term) do
    cond do
      socket.assigns.selected_node_id == nil && socket.assigns.is_super_admin ->
        assign(socket, scan_error: "Please select a node before scanning.", found_items: [])

      true ->
        items = Feats.find_item_by_barcode(term)

        cond do
          items == [] ->
            assign(socket, scan_error: "No item found for: #{term}", found_items: [])

          true ->
            socket
            |> assign(:scan_error, nil)
            |> assign(:found_items, items)
        end
    end
  end

  defp do_record(socket, item_id) do
    node_id = socket.assigns.selected_node_id
    location_id = socket.assigns.selected_location_id
    recorded_by_id = socket.assigns.current_user.id

    read_at =
      case socket.assigns.read_at_input do
        "" ->
          nil

        value ->
          case NaiveDateTime.from_iso8601(value <> ":00") do
            {:ok, ndt} -> DateTime.from_naive!(ndt, "Etc/UTC")
            _ -> nil
          end
      end

    attrs =
      %{
        item_id: item_id,
        node_id: node_id,
        recorded_by_id: recorded_by_id
      }
      |> maybe_put(:location_id, location_id)
      |> maybe_put(:read_at, read_at)

    case Feats.record_read_on_spot(attrs) do
      {:ok, _record} ->
        item = Enum.find(socket.assigns.found_items, fn i -> to_string(i.id) == item_id end)
        location = Enum.find(socket.assigns.locations, fn l -> l.id == location_id end)

        recorded_at_label =
          cond do
            read_at != nil ->
              Calendar.strftime(FormatIndonesiaTime.shift_to_jakarta(read_at), "%d/%m %H:%M")

            true ->
              Calendar.strftime(
                FormatIndonesiaTime.shift_to_jakarta(DateTime.utc_now()),
                "%H:%M:%S"
              )
          end

        stream_item = %{
          id: "rec-#{System.unique_integer([:positive])}",
          title: if(item && item.collection, do: item.collection.title, else: "Unknown"),
          item_code: if(item, do: item.item_code, else: "—"),
          location_name: if(location, do: location.location_name, else: nil),
          recorded_at: recorded_at_label
        }

        socket
        |> stream_insert(:scanned_records, stream_item, at: 0)
        |> assign(:found_items, [])
        |> assign(:scan_error, nil)
        |> assign(:scan_count, socket.assigns.scan_count + 1)
        |> put_flash(:info, "Item recorded successfully.")

      {:error, changeset} ->
        errors = Ecto.Changeset.traverse_errors(changeset, fn {msg, _} -> msg end)

        socket
        |> assign(:found_items, [])
        |> assign(:scan_error, "Failed to record item: #{inspect(errors)}")
    end
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
