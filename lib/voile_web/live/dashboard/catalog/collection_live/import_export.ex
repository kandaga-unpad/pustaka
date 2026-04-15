defmodule VoileWeb.Dashboard.Catalog.CollectionLive.ImportExport do
  @moduledoc """
  Combined import / export LiveView for collections.

  Import: three-step flow — upload → preview → done.
  Export: download all (or per-node) collections as CSV.

  CSV format mirrors the Atrium simple format:
    title, description, thumbnail, collection_type, access_level, status,
    creator_name, resource_class, language, publisher, date_published,
    isbn, subject, location, condition, availability, total_items, metadata
  """

  use VoileWeb, :live_view_dashboard

  import Ecto.Query, warn: false

  alias Voile.Repo
  alias Voile.Schema.Catalog.Collection
  alias Voile.Schema.Master.Creator
  alias Voile.Schema.Metadata.{Property, ResourceClass}
  alias Voile.Schema.System.Node

  alias VoileWeb.Auth.Authorization

  @csv_headers ~w(
    title description thumbnail collection_type access_level status
    creator_name resource_class language publisher date_published
    isbn subject location condition availability total_items metadata
  )

  # Columns that map directly to a collection_field via property local_name
  @field_columns ~w(language publisher isbn subject)

  @max_rows 500

  @impl true
  def mount(_params, _session, socket) do
    authorize!(socket, "collections.create")

    is_super_admin = Authorization.is_super_admin?(socket)
    user = socket.assigns.current_scope.user

    nodes =
      if is_super_admin do
        Repo.all(from n in Node, order_by: n.name)
      else
        case user.node_id && Repo.get(Node, user.node_id) do
          %Node{} = node -> [node]
          _ -> []
        end
      end

    import_node_id =
      if is_super_admin,
        do: nodes |> List.first() |> then(&if(&1, do: &1.id, else: nil)),
        else: user.node_id

    {:ok,
     socket
     |> assign(:page_title, "Import & Export Collections")
     |> assign(:step, :upload)
     |> assign(:parsed_rows, [])
     |> assign(:row_count, 0)
     |> assign(:parse_error, nil)
     |> assign(:import_results, [])
     |> assign(:import_errors, [])
     |> assign(:dedup_count, 0)
     |> assign(:skipped_count, 0)
     |> assign(:nodes, nodes)
     |> assign(:export_node_id, if(is_super_admin, do: "all", else: to_string(user.node_id)))
     |> assign(:import_node_id, import_node_id)
     |> assign(:is_super_admin, is_super_admin)
     |> assign(:export_loading, false)
     |> assign(:csv_headers, @csv_headers)
     |> assign(:max_rows, @max_rows)
     |> allow_upload(:csv_file,
       accept: ~w(.csv text/csv),
       max_entries: 1,
       max_file_size: 5_000_000
     )}
  end

  @impl true
  def handle_params(_params, _uri, socket), do: {:noreply, socket}

  # ── Import events ─────────────────────────────────────────────────────────────

  @impl true
  def handle_event("validate_upload", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("cancel_upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :csv_file, ref)}
  end

  @impl true
  def handle_event("parse_csv", _params, socket) do
    result =
      consume_uploaded_entries(socket, :csv_file, fn %{path: path}, _entry ->
        {:ok, File.read!(path)}
      end)

    case result do
      [] ->
        {:noreply, assign(socket, parse_error: "Please select a CSV file first.")}

      [content] ->
        parse_and_preview(socket, content)
    end
  end

  @impl true
  def handle_event("set_import_node", %{"node_id" => node_id}, socket) do
    if socket.assigns.is_super_admin do
      {:noreply, assign(socket, :import_node_id, String.to_integer(node_id))}
    else
      {:noreply, socket}
    end
  end

  def handle_event("back_to_upload", _, socket) do
    {:noreply,
     socket
     |> assign(:step, :upload)
     |> assign(:parsed_rows, [])
     |> assign(:row_count, 0)
     |> assign(:parse_error, nil)
     |> assign(:dedup_count, 0)
     |> assign(:skipped_count, 0)
     |> assign(:import_results, [])
     |> assign(:import_errors, [])}
  end

  @impl true
  def handle_event("confirm_import", _, socket) do
    rows = socket.assigns.parsed_rows
    user = socket.assigns.current_scope.user

    node = Repo.get(Node, socket.assigns.import_node_id)
    properties = load_properties_map()
    rc_map = load_resource_class_map()

    {results, errors, skipped} =
      Enum.reduce(rows, {[], [], 0}, fn row, {ok_acc, err_acc, skip_acc} ->
        case import_row(row, user, properties, rc_map, node) do
          {:ok, col} -> {[col | ok_acc], err_acc, skip_acc}
          {:skipped, _col} -> {ok_acc, err_acc, skip_acc + 1}
          {:error, reason} -> {ok_acc, [reason | err_acc], skip_acc}
        end
      end)

    {:noreply,
     socket
     |> assign(:step, :done)
     |> assign(:import_results, Enum.reverse(results))
     |> assign(:import_errors, Enum.reverse(errors))
     |> assign(:skipped_count, skipped)}
  end

  # ── Export events ─────────────────────────────────────────────────────────────

  @impl true
  def handle_event("set_export_node", %{"node_id" => node_id}, socket) do
    if socket.assigns.is_super_admin do
      {:noreply, assign(socket, :export_node_id, node_id)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("export_csv", _params, socket) do
    node_id = socket.assigns.export_node_id
    csv_content = build_export_csv(node_id)

    filename =
      case node_id do
        "all" -> "collections_export_all.csv"
        id -> "collections_export_node_#{id}.csv"
      end

    {:noreply,
     push_event(socket, "download", %{
       filename: filename,
       content: csv_content,
       mime_type: "text/csv"
     })}
  end

  # ── Render ────────────────────────────────────────────────────────────────────

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-7xl mx-auto px-4 py-8">
      <%!-- Header --%>
      <div class="mb-6 flex items-start justify-between gap-4">
        <div>
          <h1 class="text-2xl font-bold text-gray-900 dark:text-white">
            Import & Export Collections
          </h1>
          <p class="mt-1 text-sm text-gray-500 dark:text-gray-400">
            Bulk import collections from CSV or export your catalog for backup / transfer.
          </p>
        </div>
        <.link
          navigate={~p"/manage/catalog/collections"}
          class="inline-flex items-center gap-1.5 text-sm text-gray-500 hover:text-gray-700 dark:text-gray-400 dark:hover:text-gray-200"
        >
          <.icon name="hero-arrow-left" class="size-4" /> Back to Collections
        </.link>
      </div>

      <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <%!-- Left: Import panel --%>
        <div class="lg:col-span-2 space-y-5">
          <%!-- ── Step indicator --%>
          <div class="flex items-center gap-2 text-xs font-medium">
            <span class={step_dot(@step in [:upload])}>1 Upload</span>
            <.icon name="hero-chevron-right" class="size-3 text-gray-400" />
            <span class={step_dot(@step == :preview)}>2 Preview</span>
            <.icon name="hero-chevron-right" class="size-3 text-gray-400" />
            <span class={step_dot(@step == :done)}>3 Done</span>
          </div>

          <%!-- ── Step 1: Upload --%>
          <%= if @step == :upload do %>
            <div class="bg-white dark:bg-gray-800 rounded-lg border border-gray-200 dark:border-gray-700 p-6 space-y-5">
              <h2 class="text-sm font-semibold text-gray-700 dark:text-gray-300 uppercase tracking-wide">
                Upload CSV
              </h2>

              <form
                phx-submit="parse_csv"
                phx-change="validate_upload"
                id="csv-upload-form"
                class="space-y-4"
              >
                <div
                  phx-drop-target={@uploads.csv_file.ref}
                  class="border-2 border-dashed border-gray-300 dark:border-gray-600 rounded-xl p-8 flex flex-col items-center gap-3 text-center hover:border-blue-400 hover:bg-blue-50 dark:hover:border-blue-500 dark:hover:bg-blue-900/20 transition-all cursor-pointer"
                >
                  <.icon name="hero-document-arrow-up" class="size-10 text-gray-400" />
                  <div>
                    <p class="text-sm font-medium text-gray-700 dark:text-gray-300">
                      Drop a CSV file here, or click to select
                    </p>
                    <p class="text-xs text-gray-400 mt-1">CSV files only, max 5 MB</p>
                  </div>
                  <label class="cursor-pointer px-4 py-1.5 text-sm rounded-md border border-gray-300 dark:border-gray-600 hover:bg-gray-50 dark:hover:bg-gray-700 text-gray-700 dark:text-gray-300">
                    Browse <.live_file_input upload={@uploads.csv_file} class="sr-only" />
                  </label>
                </div>

                <%= for entry <- @uploads.csv_file.entries do %>
                  <div class="flex items-center gap-3 p-3 rounded-lg bg-blue-50 dark:bg-blue-900/20 border border-blue-200 dark:border-blue-700">
                    <.icon name="hero-document-text" class="size-5 text-blue-500 shrink-0" />
                    <div class="flex-1 min-w-0">
                      <p class="text-sm font-medium truncate text-gray-900 dark:text-white">
                        {entry.client_name}
                      </p>
                      <p class="text-xs text-gray-500">
                        {Float.round(entry.client_size / 1024, 1)} KB
                      </p>
                    </div>
                    <button
                      type="button"
                      phx-click="cancel_upload"
                      phx-value-ref={entry.ref}
                      class="text-gray-400 hover:text-red-500"
                    >
                      <.icon name="hero-x-mark" class="size-4" />
                    </button>
                  </div>
                  <%= for err <- upload_errors(@uploads.csv_file, entry) do %>
                    <p class="text-xs text-red-500">{upload_error_to_string(err)}</p>
                  <% end %>
                <% end %>

                <%= if @parse_error do %>
                  <p class="text-sm text-red-500 flex items-center gap-1.5">
                    <.icon name="hero-exclamation-circle" class="size-4 shrink-0" />
                    {@parse_error}
                  </p>
                <% end %>

                <div class="space-y-1">
                  <label class="block text-xs font-medium text-gray-600 dark:text-gray-400">
                    Import into node <span class="text-red-500">*</span>
                  </label>
                  <%= if @is_super_admin do %>
                    <select
                      phx-change="set_import_node"
                      name="node_id"
                      id="import-node-select"
                      class="block w-full rounded-md border border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-700 text-sm text-gray-900 dark:text-white px-3 py-2 focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                    >
                      <%= for node <- @nodes do %>
                        <option value={node.id} selected={@import_node_id == node.id}>
                          {node.name} ({node.abbr})
                        </option>
                      <% end %>
                    </select>
                  <% else %>
                    <div class="flex items-center gap-2 px-3 py-2 rounded-md border border-gray-200 dark:border-gray-700 bg-gray-50 dark:bg-gray-900 text-sm text-gray-700 dark:text-gray-300">
                      <.icon name="hero-building-library" class="size-4 text-gray-400 shrink-0" />
                      {Enum.find(@nodes, &(&1.id == @import_node_id))
                      |> then(&if(&1, do: "#{&1.name} (#{&1.abbr})", else: "—"))}
                    </div>
                  <% end %>
                </div>

                <button
                  type="submit"
                  disabled={@uploads.csv_file.entries == [] or is_nil(@import_node_id)}
                  class="inline-flex items-center gap-1.5 px-4 py-2 text-sm font-medium rounded-md bg-blue-600 text-white hover:bg-blue-700 disabled:opacity-40 disabled:cursor-not-allowed"
                >
                  <.icon name="hero-table-cells" class="size-4" /> Preview Rows
                </button>
              </form>
            </div>
          <% end %>

          <%!-- ── Step 2: Preview --%>
          <%= if @step == :preview do %>
            <div class="bg-white dark:bg-gray-800 rounded-lg border border-gray-200 dark:border-gray-700 p-6 space-y-4">
              <div class="flex items-center justify-between">
                <h2 class="text-sm font-semibold text-gray-700 dark:text-gray-300 uppercase tracking-wide">
                  Preview
                </h2>
                <div class="flex items-center gap-3">
                  <span class="text-xs text-gray-500">
                    {length(@parsed_rows)} / {@row_count} rows (max {@max_rows})
                  </span>
                  <%= if @dedup_count > 0 do %>
                    <span class="inline-flex items-center gap-1 text-xs font-medium px-2 py-0.5 rounded-full bg-amber-100 text-amber-700 dark:bg-amber-900/30 dark:text-amber-400">
                      <.icon name="hero-arrow-path" class="size-3" />
                      {@dedup_count} {if @dedup_count == 1, do: "duplicate", else: "duplicates"} merged
                    </span>
                  <% end %>
                </div>
              </div>

              <p class="text-sm text-gray-600 dark:text-gray-400">
                Review your data before importing. Only the first 5 rows are shown below.
              </p>

              <div class="overflow-x-auto rounded-lg border border-gray-200 dark:border-gray-700">
                <table class="min-w-full text-xs">
                  <thead class="bg-gray-50 dark:bg-gray-700">
                    <tr>
                      <th class="px-3 py-2 text-left font-medium text-gray-500 dark:text-gray-400 whitespace-nowrap">
                        #
                      </th>
                      <%= for col <- ["title", "creator_name", "resource_class", "status", "access_level", "total_items"] do %>
                        <th class="px-3 py-2 text-left font-medium text-gray-500 dark:text-gray-400 whitespace-nowrap">
                          {col}
                        </th>
                      <% end %>
                    </tr>
                  </thead>
                  <tbody class="divide-y divide-gray-200 dark:divide-gray-700">
                    <%= for {row, i} <- Enum.with_index(Enum.take(@parsed_rows, 5), 1) do %>
                      <tr class="hover:bg-gray-50 dark:hover:bg-gray-700/50">
                        <td class="px-3 py-2 font-mono text-gray-400">{i}</td>
                        <%= for col <- ["title", "creator_name", "resource_class", "status", "access_level", "total_items"] do %>
                          <td
                            class="px-3 py-2 max-w-[180px] truncate text-gray-900 dark:text-white"
                            title={row[col]}
                          >
                            {row[col] || "—"}
                          </td>
                        <% end %>
                      </tr>
                    <% end %>
                  </tbody>
                </table>
              </div>

              <div class="flex gap-3">
                <button
                  phx-click="confirm_import"
                  class="inline-flex items-center gap-1.5 px-4 py-2 text-sm font-medium rounded-md bg-blue-600 text-white hover:bg-blue-700"
                >
                  <.icon name="hero-arrow-up-tray" class="size-4" />
                  Import {length(@parsed_rows)} {if length(@parsed_rows) == 1,
                    do: "Collection",
                    else: "Collections"}
                </button>
                <button
                  phx-click="back_to_upload"
                  class="px-4 py-2 text-sm font-medium rounded-md text-gray-600 dark:text-gray-400 hover:bg-gray-100 dark:hover:bg-gray-700"
                >
                  Back
                </button>
              </div>
            </div>
          <% end %>

          <%!-- ── Step 3: Done --%>
          <%= if @step == :done do %>
            <% successes = length(@import_results) %>
            <% failures = @import_errors %>
            <div class={[
              "rounded-lg border p-6 space-y-4",
              failures == [] &&
                "border-green-200 bg-green-50 dark:border-green-800 dark:bg-green-900/20",
              failures != [] &&
                "border-yellow-200 bg-yellow-50 dark:border-yellow-800 dark:bg-yellow-900/20"
            ]}>
              <div class="flex items-center gap-3">
                <.icon
                  name={if failures == [], do: "hero-check-circle", else: "hero-exclamation-triangle"}
                  class={
                    if failures == [],
                      do: "size-8 shrink-0 text-green-500",
                      else: "size-8 shrink-0 text-yellow-500"
                  }
                />
                <div>
                  <p class="font-semibold text-gray-900 dark:text-white">
                    {successes} {if successes == 1, do: "collection", else: "collections"} imported successfully.
                  </p>
                  <%= if @skipped_count > 0 do %>
                    <p class="text-sm text-gray-600 dark:text-gray-400 mt-0.5">
                      {@skipped_count} {if @skipped_count == 1, do: "row", else: "rows"} skipped — already exists in the catalog.
                    </p>
                  <% end %>
                  <%= if failures != [] do %>
                    <p class="text-sm text-gray-600 dark:text-gray-400 mt-0.5">
                      {length(failures)} {if length(failures) == 1, do: "row", else: "rows"} failed — see details below.
                    </p>
                  <% end %>
                </div>
              </div>

              <%= if failures != [] do %>
                <div class="rounded-lg border border-red-200 dark:border-red-800 bg-white dark:bg-gray-800 p-4 space-y-2">
                  <p class="text-xs font-semibold text-gray-500 dark:text-gray-400 uppercase tracking-wide">
                    Failed rows
                  </p>
                  <%= for reason <- failures do %>
                    <div class="flex items-start gap-2 text-sm text-red-600 dark:text-red-400">
                      <.icon name="hero-x-circle" class="size-4 shrink-0 mt-0.5" />
                      <span>{reason}</span>
                    </div>
                  <% end %>
                </div>
              <% end %>

              <div class="flex gap-3">
                <.link
                  navigate={~p"/manage/catalog/collections"}
                  class="inline-flex items-center gap-1.5 px-4 py-2 text-sm font-medium rounded-md bg-blue-600 text-white hover:bg-blue-700"
                >
                  <.icon name="hero-rectangle-stack" class="size-4" /> View Collections
                </.link>
                <button
                  phx-click="back_to_upload"
                  class="px-4 py-2 text-sm font-medium rounded-md text-gray-600 dark:text-gray-400 hover:bg-gray-100 dark:hover:bg-gray-700"
                >
                  Import More
                </button>
              </div>
            </div>
          <% end %>
        </div>

        <%!-- Right: Guide + Export --%>
        <div class="space-y-5">
          <%!-- Export panel --%>
          <div class="bg-white dark:bg-gray-800 rounded-lg border border-gray-200 dark:border-gray-700 p-5 space-y-4">
            <h2 class="text-sm font-semibold text-gray-700 dark:text-gray-300 uppercase tracking-wide">
              Export
            </h2>

            <p class="text-xs text-gray-500 dark:text-gray-400">
              Download all collections (or filter by node) as a CSV file in the same format used for import.
            </p>

            <div class="space-y-3">
              <form phx-change="set_export_node">
                <label class="block text-xs font-medium text-gray-600 dark:text-gray-400 mb-1">
                  Node / Branch
                </label>
                <%= if @is_super_admin do %>
                  <select
                    name="node_id"
                    class="block w-full text-sm px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-md bg-white dark:bg-gray-700 text-gray-900 dark:text-white focus:ring-blue-500 focus:border-blue-500"
                  >
                    <option value="all" selected={@export_node_id == "all"}>All nodes</option>
                    <%= for node <- @nodes do %>
                      <option
                        value={node.id}
                        selected={@export_node_id == to_string(node.id)}
                      >
                        {node.name}{if node.abbr, do: " (#{node.abbr})", else: ""}
                      </option>
                    <% end %>
                  </select>
                <% else %>
                  <div class="flex items-center gap-2 px-3 py-2 rounded-md border border-gray-200 dark:border-gray-700 bg-gray-50 dark:bg-gray-900 text-sm text-gray-700 dark:text-gray-300">
                    <.icon name="hero-building-library" class="size-4 text-gray-400 shrink-0" />
                    {List.first(@nodes) |> then(&if(&1, do: "#{&1.name} (#{&1.abbr})", else: "—"))}
                  </div>
                <% end %>
              </form>

              <button
                phx-click="export_csv"
                class="w-full inline-flex justify-center items-center gap-1.5 px-4 py-2 text-sm font-medium rounded-md border border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-700 text-gray-700 dark:text-gray-200 hover:bg-gray-50 dark:hover:bg-gray-600"
              >
                <.icon name="hero-arrow-down-tray" class="size-4" /> Download CSV
              </button>
            </div>
          </div>

          <%!-- Format guide --%>
          <div class="bg-white dark:bg-gray-800 rounded-lg border border-gray-200 dark:border-gray-700 p-5 space-y-4">
            <h2 class="text-sm font-semibold text-gray-700 dark:text-gray-300 uppercase tracking-wide">
              CSV Format
            </h2>

            <p class="text-xs text-gray-500 dark:text-gray-400">
              Required: <span class="font-medium text-gray-700 dark:text-gray-300">title, description, creator_name, resource_class</span>. All others are optional.
            </p>

            <div class="flex flex-wrap gap-1">
              <%= for col <- @csv_headers do %>
                <span class={[
                  "px-1.5 py-0.5 rounded text-xs font-mono",
                  col in ~w(title description creator_name resource_class) &&
                    "bg-blue-100 text-blue-700 dark:bg-blue-900/40 dark:text-blue-300",
                  col not in ~w(title description creator_name resource_class) &&
                    "bg-gray-100 text-gray-500 dark:bg-gray-700 dark:text-gray-400"
                ]}>
                  {col}
                </span>
              <% end %>
            </div>

            <div class="text-xs text-gray-500 dark:text-gray-400 space-y-1">
              <p>
                <span class="font-medium">status:</span> draft · pending · published · archived
              </p>
              <p>
                <span class="font-medium">access_level:</span> public · private · restricted
              </p>
              <p>
                <span class="font-medium">date_published:</span> YYYY or YYYY-MM-DD
              </p>
              <p>
                <span class="font-medium">total_items:</span> integer (default 1)
              </p>
              <p phx-no-curly-interpolation>
                <span class="font-medium">metadata:</span> optional JSON, e.g. {"source":"Archive"}
              </p>
            </div>

            <a
              href="/sample_collection_import.csv"
              download
              class="inline-flex items-center gap-1.5 text-xs text-blue-600 dark:text-blue-400 hover:underline"
            >
              <.icon name="hero-arrow-down-tray" class="size-3" /> Download sample CSV
            </a>
          </div>
        </div>
      </div>
    </div>

    <script :type={Phoenix.LiveView.ColocatedHook} name=".CsvDownload">
      export default {
        mounted() {
          this.handleEvent("download", ({ filename, content, mime_type }) => {
            const blob = new Blob([content], { type: mime_type });
            const url = URL.createObjectURL(blob);
            const a = document.createElement("a");
            a.href = url;
            a.download = filename;
            a.click();
            URL.revokeObjectURL(url);
          });
        }
      }
    </script>
    <div id="csv-downloader" phx-hook=".CsvDownload" phx-update="ignore"></div>
    """
  end

  # ── Private: parse & preview ──────────────────────────────────────────────────

  defp parse_and_preview(socket, content) do
    try do
      rows =
        content
        |> String.replace("\r\n", "\n")
        |> String.replace("\r", "\n")
        |> String.trim()
        |> NimbleCSV.RFC4180.parse_string(skip_headers: false)

      case rows do
        [] ->
          {:noreply, assign(socket, parse_error: "The file appears to be empty.", step: :upload)}

        [headers | data_rows] ->
          parsed_all = Enum.map(data_rows, &(Enum.zip(headers, &1) |> Map.new()))
          row_count = length(parsed_all)
          capped = Enum.take(parsed_all, @max_rows)
          {deduped, dedup_count} = deduplicate_rows(capped)

          parse_error =
            if row_count > @max_rows,
              do:
                "Your CSV has #{row_count} rows; only the first #{@max_rows} will be imported. Split the file for the rest.",
              else: nil

          {:noreply,
           socket
           |> assign(:step, :preview)
           |> assign(:parsed_rows, deduped)
           |> assign(:row_count, row_count)
           |> assign(:dedup_count, dedup_count)
           |> assign(:parse_error, parse_error)}
      end
    rescue
      e ->
        {:noreply,
         assign(socket,
           parse_error: "Could not parse CSV: #{Exception.message(e)}",
           step: :upload
         )}
    end
  end

  # ── Private: import a single row ──────────────────────────────────────────────

  defp load_properties_map do
    Property
    |> Repo.all()
    |> Map.new(fn p -> {p.local_name, p} end)
  end

  defp load_resource_class_map do
    ResourceClass
    |> Repo.all()
    |> Map.new(fn rc -> {String.downcase(rc.label), rc} end)
  end

  defp generate_collection_code(unit_abbr, collection_type) do
    timestamp = :os.system_time(:second)
    random_suffix = :crypto.strong_rand_bytes(3) |> Base.encode16(case: :lower)
    abbr = (unit_abbr || "UNK") |> String.upcase()
    type = (collection_type || "std") |> String.upcase() |> String.slice(0, 8)
    "#{abbr}-#{type}-#{timestamp}-#{random_suffix}"
  end

  defp import_row(row, user, properties, rc_map, node) do
    title = trim(row["title"])
    description = trim(row["description"])
    creator_name = trim(row["creator_name"])
    resource_class_name = trim(row["resource_class"])

    missing =
      [
        {"title", title},
        {"description", description},
        {"creator_name", creator_name},
        {"resource_class", resource_class_name}
      ]
      |> Enum.filter(fn {_, v} -> v == "" end)
      |> Enum.map(fn {k, _} -> k end)

    if missing != [] do
      {:error,
       "Row skipped — please fill required columns: #{Enum.join(missing, ", ")} (title: #{title})"}
    else
      rc_key = String.downcase(resource_class_name)
      resource_class = Map.get(rc_map, rc_key) || Map.get(rc_map, "book")
      type_id = resource_class && resource_class.id

      creator_id =
        case get_or_create_creator(creator_name) do
          {:ok, c} -> c.id
          _ -> nil
        end

      collection_type = trim(row["collection_type"]) || "standard"

      # Check DB for an existing collection with the same title + creator + type + node
      # before inserting — avoids creating duplicates on repeated imports.
      case find_existing_collection(title, creator_id, type_id, collection_type, node && node.id) do
        %Collection{} = existing ->
          {:skipped, existing}

        nil ->
          collection_fields = build_collection_fields(row, properties)
          collection_code = generate_collection_code(node && node.abbr, collection_type)

          attrs = %{
            title: title,
            description: description,
            thumbnail: trim(row["thumbnail"]) || "",
            collection_type: collection_type,
            access_level: trim(row["access_level"]) || "public",
            status: trim(row["status"]) || "draft",
            collection_code: collection_code,
            unit_id: node && node.id,
            creator_id: creator_id,
            type_id: type_id,
            created_by_id: user.id,
            collection_fields: collection_fields
          }

          %Collection{}
          |> Collection.changeset(attrs)
          |> Repo.insert()
          |> case do
            {:ok, col} ->
              {:ok, col}

            {:error, changeset} ->
              errors =
                Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
                  Enum.reduce(opts, msg, fn {k, v}, acc ->
                    String.replace(acc, "%{#{k}}", to_string(v))
                  end)
                end)
                |> Enum.map_join("; ", fn {f, errs} -> "#{f}: #{Enum.join(errs, ", ")}" end)

              {:error, "Failed to import \"#{title}\": #{errors}"}
          end
      end
    end
  end

  defp build_collection_fields(row, properties) do
    @field_columns
    |> Enum.with_index(1)
    |> Enum.flat_map(fn {col, idx} ->
      value = trim(row[col])
      prop = Map.get(properties, col)

      if value != "" && prop do
        [
          %{
            name: prop.local_name,
            label: prop.label,
            value: value,
            value_lang: "en",
            type_value: prop.type_value || "text",
            property_id: prop.id,
            sort_order: idx
          }
        ]
      else
        []
      end
    end)
  end

  defp get_or_create_creator(name) do
    case Repo.get_by(Creator, creator_name: name) do
      %Creator{} = creator ->
        {:ok, creator}

      nil ->
        %Creator{}
        |> Creator.changeset(%{
          creator_name: name,
          type: "Person"
        })
        |> Repo.insert()
    end
  end

  # ── Private: export ───────────────────────────────────────────────────────────

  defp build_export_csv(node_filter) do
    query =
      from c in Collection,
        preload: [:mst_creator, :node, :collection_fields, :items, resource_class: []]

    query =
      case node_filter do
        "all" ->
          query

        id ->
          case Integer.parse(id) do
            {int_id, _} -> where(query, [c], c.unit_id == ^int_id)
            :error -> query
          end
      end

    rows = Repo.all(query)

    header_row = @csv_headers
    data_rows = Enum.map(rows, &collection_to_csv_row/1)

    ([header_row] ++ data_rows)
    |> NimbleCSV.RFC4180.dump_to_iodata()
    |> IO.iodata_to_binary()
  end

  defp collection_to_csv_row(c) do
    fields = Map.new(c.collection_fields || [], fn f -> {f.name, f.value} end)

    metadata =
      case Jason.encode(
             %{
               source: fields["source"],
               coverage: fields["coverage"],
               contributor: fields["contributor"],
               rights: fields["rights"]
             }
             |> Enum.reject(fn {_, v} -> is_nil(v) or v == "" end)
             |> Map.new()
           ) do
        {:ok, "{}"} -> ""
        {:ok, json} -> json
        _ -> ""
      end

    [
      c.title || "",
      c.description || "",
      c.thumbnail || "",
      c.collection_type || "",
      c.access_level || "",
      c.status || "",
      (c.mst_creator && c.mst_creator.creator_name) || "",
      (c.resource_class && c.resource_class.label) || "",
      fields["language"] || "",
      fields["publisher"] || "",
      fields["date"] || "",
      fields["identifier"] || fields["isbn"] || "",
      fields["subject"] || "",
      (c.node && c.node.name) || "",
      "",
      "",
      to_string(length(c.items || [])),
      metadata
    ]
  end

  # ── Private: helpers ──────────────────────────────────────────────────────────

  defp find_existing_collection(title, creator_id, type_id, collection_type, node_id) do
    query =
      from c in Collection,
        where: fragment("lower(?)", c.title) == ^String.downcase(title),
        where: c.collection_type == ^collection_type

    query =
      if node_id, do: from(c in query, where: c.unit_id == ^node_id), else: query

    query =
      if type_id, do: from(c in query, where: c.type_id == ^type_id), else: query

    query =
      if creator_id, do: from(c in query, where: c.creator_id == ^creator_id), else: query

    Repo.one(query)
  end

  defp parse_total_items(val) do
    case Integer.parse(to_string(val || "1")) do
      {n, _} when n > 0 -> n
      _ -> 1
    end
  end

  # Groups rows by {title, creator_name} (case-insensitive). Duplicate groups have
  # their `total_items` summed and the first row's other fields kept.
  # Returns {deduped_rows, number_of_rows_removed}.
  defp deduplicate_rows(rows) do
    grouped =
      Enum.group_by(rows, fn row ->
        {
          row["title"] |> to_string() |> String.trim() |> String.downcase(),
          row["creator_name"] |> to_string() |> String.trim() |> String.downcase()
        }
      end)

    deduped =
      grouped
      |> Enum.map(fn {_key, [first | _rest] = group} ->
        total = Enum.reduce(group, 0, fn r, acc -> acc + parse_total_items(r["total_items"]) end)
        Map.put(first, "total_items", to_string(total))
      end)

    removed = length(rows) - length(deduped)
    {deduped, removed}
  end

  defp trim(nil), do: ""
  defp trim(s), do: String.trim(s)

  defp step_dot(active) do
    if active,
      do: "px-2 py-0.5 rounded-full bg-blue-600 text-white text-xs",
      else:
        "px-2 py-0.5 rounded-full bg-gray-200 dark:bg-gray-700 text-gray-500 dark:text-gray-400 text-xs"
  end

  defp upload_error_to_string(:too_large), do: "File is too large (max 5 MB)."
  defp upload_error_to_string(:not_accepted), do: "Only .csv files are accepted."
  defp upload_error_to_string(:too_many_files), do: "Only one file at a time."
  defp upload_error_to_string(err), do: "Upload error: #{inspect(err)}"
end
