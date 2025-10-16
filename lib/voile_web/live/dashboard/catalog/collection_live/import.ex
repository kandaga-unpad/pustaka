defmodule VoileWeb.Dashboard.Catalog.CollectionLive.Import do
  use VoileWeb, :live_view_dashboard

  alias Voile.Catalog.CollectionCsvImporter

  @impl true
  def mount(_params, _session, socket) do
    authorize!(socket, "collections.create")

    {:ok,
     socket
     |> assign(:import_results, nil)
     |> assign(:show_preview, false)
     |> assign(:preview_data, nil)
     |> assign(:available_properties, CollectionCsvImporter.list_available_properties())
     |> assign(:page_title, "Import Collections")
     |> allow_upload(:csv_file,
       accept: ~w(.csv),
       max_entries: 1,
       max_file_size: 10_000_000,
       auto_upload: true
     )}
  end

  @impl true
  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("download_template", _params, socket) do
    {headers, properties} = CollectionCsvImporter.generate_template()

    # Create sample row
    sample_row =
      [
        "COL001",
        "Sample Collection Title",
        "This is a sample description",
        "published",
        "public",
        "https://via.placeholder.com/300",
        "1",
        "book",
        "1"
      ] ++
        Enum.map(properties, fn _ -> "Sample Value" end) ++
        ["ITEM001", "INV001", "Library Section A", "active", "excellent", "available", "100000"]

    csv_content =
      [headers, sample_row]
      |> NimbleCSV.RFC4180.dump_to_iodata()
      |> IO.iodata_to_binary()

    {:noreply,
     socket
     |> push_event("download", %{
       filename: "collection_import_simple_template.csv",
       content: csv_content,
       mime_type: "text/csv"
     })}
  end

  @impl true
  def handle_event("cancel_upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :csv_file, ref)}
  end

  @impl true
  def handle_event("import_csv", %{"skip_errors" => skip_errors}, socket) do
    skip_errors_bool = skip_errors == "true"

    uploaded_files =
      consume_uploaded_entries(socket, :csv_file, fn %{path: path}, _entry ->
        case File.read(path) do
          {:ok, content} ->
            {:ok, content}

          error ->
            error
        end
      end)

    case uploaded_files do
      [content | _] ->
        # Import the CSV
        case CollectionCsvImporter.import_from_upload(content,
               skip_errors: skip_errors_bool,
               current_user: socket.assigns.current_scope.user
             ) do
          {:ok, results} ->
            {:noreply,
             socket
             |> assign(:import_results, results)
             |> assign(:show_preview, false)
             |> put_flash(
               :info,
               "Import completed: #{results.success} successful, #{results.failed} failed"
             )}

          {:error, results} when is_map(results) ->
            {:noreply,
             socket
             |> assign(:import_results, results)
             |> assign(:show_preview, false)
             |> put_flash(:error, "Import failed: #{results.failed} errors occurred")}

          {:error, reason} ->
            {:noreply,
             socket
             |> put_flash(:error, "Import failed: #{reason}")}
        end

      [] ->
        {:noreply,
         socket
         |> put_flash(:error, "No file uploaded")}
    end
  end

  @impl true
  def handle_event("preview_csv", _params, socket) do
    uploaded_files =
      consume_uploaded_entries(socket, :csv_file, fn %{path: path}, _entry ->
        case File.read(path) do
          {:ok, content} ->
            {:ok, content}

          error ->
            error
        end
      end)

    case uploaded_files do
      [content | _] ->
        preview_data = parse_preview(content)

        {:noreply,
         socket
         |> assign(:show_preview, true)
         |> assign(:preview_data, preview_data)}

      [] ->
        {:noreply,
         socket
         |> put_flash(:error, "No file uploaded")}
    end
  end

  @impl true
  def handle_event("clear_results", _params, socket) do
    {:noreply,
     socket
     |> assign(:import_results, nil)
     |> assign(:show_preview, false)
     |> assign(:preview_data, nil)}
  end

  defp parse_preview(content) do
    lines =
      content
      |> String.split("\n")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))
      |> Enum.take(6)

    case NimbleCSV.RFC4180.parse_string(lines |> Enum.join("\n"), skip_headers: false) do
      [headers | rows] ->
        %{
          headers: headers,
          rows: rows,
          total_rows: length(rows)
        }

      _ ->
        nil
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="container mx-auto px-4 py-8">
      <!-- Header -->
      <div class="mb-8">
        <div class="flex items-center justify-between">
          <div>
            <h1 class="text-3xl font-bold text-gray-900">Import Collections</h1>
            
            <p class="mt-2 text-gray-600">Upload a CSV file to import collections in bulk</p>
          </div>
          
          <.link
            navigate={~p"/manage/catalog/collections"}
            class="btn btn-ghost btn-sm"
          >
            <.icon name="hero-arrow-left" class="w-5 h-5 mr-2" /> Back to Collections
          </.link>
        </div>
      </div>
      
      <div class="grid grid-cols-1 lg:grid-cols-3 gap-8">
        <!-- Upload Section -->
        <div class="lg:col-span-2">
          <div class="card bg-base-100 shadow-xl">
            <div class="card-body">
              <h2 class="card-title">
                <.icon name="hero-arrow-up-tray" class="w-6 h-6" /> Upload CSV File
              </h2>
              <!-- Upload Area -->
              <div class="mt-4">
                <form phx-submit="import_csv" phx-change="validate" id="upload-form">
                  <div
                    class="border-2 border-dashed border-gray-300 rounded-lg p-8 text-center hover:border-blue-500 transition"
                    phx-drop-target={@uploads.csv_file.ref}
                  >
                    <.icon name="hero-document-arrow-up" class="w-16 h-16 mx-auto text-gray-400" />
                    <div class="mt-4">
                      <label for={@uploads.csv_file.ref} class="btn btn-primary">
                        <.icon name="hero-folder-open" class="w-5 h-5 mr-2" /> Choose File
                      </label> <.live_file_input upload={@uploads.csv_file} class="hidden" />
                    </div>
                    
                    <p class="mt-2 text-sm text-gray-500">or drag and drop CSV file here</p>
                    
                    <p class="mt-1 text-xs text-gray-400">Maximum file size: 10MB</p>
                  </div>
                  <!-- Uploaded Files -->
                  <%= for entry <- @uploads.csv_file.entries do %>
                    <div class="mt-4 p-4 bg-blue-50 rounded-lg flex items-center justify-between">
                      <div class="flex items-center">
                        <.icon name="hero-document-text" class="w-5 h-5 text-blue-600 mr-3" />
                        <div>
                          <p class="font-medium text-gray-900">{entry.client_name}</p>
                          
                          <p class="text-sm text-gray-500">
                            {Float.round(entry.client_size / 1024, 2)} KB
                          </p>
                        </div>
                      </div>
                      
                      <button
                        type="button"
                        phx-click="cancel_upload"
                        phx-value-ref={entry.ref}
                        class="btn btn-ghost btn-sm btn-circle"
                      >
                        <.icon name="hero-x-mark" class="w-5 h-5" />
                      </button>
                    </div>
                    <!-- Progress Bar -->
                    <progress
                      class="progress progress-primary w-full mt-2"
                      value={entry.progress}
                      max="100"
                    >
                      {entry.progress}%
                    </progress>
                    <!-- Errors -->
                    <%= for err <- upload_errors(@uploads.csv_file, entry) do %>
                      <div class="alert alert-error mt-2">
                        <.icon name="hero-exclamation-triangle" class="w-5 h-5" />
                        <span>{error_to_string(err)}</span>
                      </div>
                    <% end %>
                  <% end %>
                  <!-- Import Options -->
                  <%= if @uploads.csv_file.entries != [] do %>
                    <div class="mt-6 space-y-4">
                      <div class="form-control">
                        <label class="label cursor-pointer">
                          <span class="label-text">Skip rows with errors and continue importing</span>
                          <input
                            type="checkbox"
                            name="skip_errors"
                            value="true"
                            class="checkbox checkbox-primary"
                          />
                        </label>
                      </div>
                      
                      <div class="flex gap-2">
                        <button type="submit" class="btn btn-primary flex-1">
                          <.icon name="hero-arrow-up-tray" class="w-5 h-5 mr-2" /> Import Now
                        </button>
                        <button
                          type="button"
                          phx-click="preview_csv"
                          class="btn btn-outline flex-1"
                        >
                          <.icon name="hero-eye" class="w-5 h-5 mr-2" /> Preview First 5 Rows
                        </button>
                      </div>
                    </div>
                  <% end %>
                </form>
              </div>
            </div>
          </div>
          <!-- Preview Section -->
          <%= if @show_preview && @preview_data do %>
            <div class="card bg-base-100 shadow-xl mt-6">
              <div class="card-body">
                <h2 class="card-title"><.icon name="hero-eye" class="w-6 h-6" /> CSV Preview</h2>
                
                <p class="text-sm text-gray-600">Showing first {length(@preview_data.rows)} rows</p>
                
                <div class="overflow-x-auto mt-4">
                  <table class="table table-zebra table-xs">
                    <thead>
                      <tr>
                        <th class="bg-primary text-primary-content">#</th>
                        
                        <%= for header <- @preview_data.headers do %>
                          <th class="bg-primary text-primary-content">{header}</th>
                        <% end %>
                      </tr>
                    </thead>
                    
                    <tbody>
                      <%= for {row, idx} <- Enum.with_index(@preview_data.rows, 1) do %>
                        <tr>
                          <td class="font-bold">{idx}</td>
                          
                          <%= for cell <- row do %>
                            <td class="max-w-xs truncate" title={cell}>{cell}</td>
                          <% end %>
                        </tr>
                      <% end %>
                    </tbody>
                  </table>
                </div>
              </div>
            </div>
          <% end %>
          <!-- Results Section -->
          <%= if @import_results do %>
            <div class="card bg-base-100 shadow-xl mt-6">
              <div class="card-body">
                <div class="flex items-center justify-between">
                  <h2 class="card-title">
                    <.icon name="hero-chart-bar" class="w-6 h-6" /> Import Results
                  </h2>
                  
                  <button phx-click="clear_results" class="btn btn-ghost btn-sm">
                    <.icon name="hero-x-mark" class="w-5 h-5" />
                  </button>
                </div>
                
                <div class="stats stats-vertical lg:stats-horizontal shadow mt-4">
                  <div class="stat">
                    <div class="stat-title">Total Rows</div>
                    
                    <div class="stat-value">{@import_results.total}</div>
                  </div>
                  
                  <div class="stat">
                    <div class="stat-title">Successful</div>
                    
                    <div class="stat-value text-success">{@import_results.success}</div>
                  </div>
                  
                  <div class="stat">
                    <div class="stat-title">Failed</div>
                    
                    <div class="stat-value text-error">{@import_results.failed}</div>
                  </div>
                </div>
                
                <%= if @import_results.warnings != [] do %>
                  <div class="alert alert-warning mt-4">
                    <.icon name="hero-exclamation-triangle" class="w-5 h-5" />
                    <div>
                      <h3 class="font-bold">Warnings</h3>
                      
                      <ul class="list-disc list-inside mt-2">
                        <%= for warning <- @import_results.warnings do %>
                          <li class="text-sm">{warning}</li>
                        <% end %>
                      </ul>
                    </div>
                  </div>
                <% end %>
                
                <%= if @import_results.errors != [] do %>
                  <div class="mt-4">
                    <h3 class="font-bold text-error mb-2">Errors:</h3>
                    
                    <div class="space-y-2 max-h-96 overflow-y-auto">
                      <%= for error <- Enum.take(@import_results.errors, 20) do %>
                        <div class="alert alert-error">
                          <div>
                            <div class="font-bold">Row {error.row}</div>
                            
                            <div class="text-sm">{error.reason}</div>
                          </div>
                        </div>
                      <% end %>
                      
                      <%= if length(@import_results.errors) > 20 do %>
                        <p class="text-sm text-gray-500 text-center py-2">
                          ... and {length(@import_results.errors) - 20} more errors
                        </p>
                      <% end %>
                    </div>
                  </div>
                <% end %>
                
                <%= if @import_results.success > 0 do %>
                  <div class="mt-4">
                    <.link navigate={~p"/manage/catalog/collections"} class="btn btn-primary w-full">
                      <.icon name="hero-check-circle" class="w-5 h-5 mr-2" />
                      View Imported Collections
                    </.link>
                  </div>
                <% end %>
              </div>
            </div>
          <% end %>
        </div>
        <!-- Instructions Sidebar -->
        <div class="lg:col-span-1">
          <div class="card bg-base-100 shadow-xl sticky top-4">
            <div class="card-body">
              <h2 class="card-title">
                <.icon name="hero-information-circle" class="w-6 h-6" /> Quick Guide
              </h2>
              
              <div class="space-y-4 text-sm">
                <div>
                  <h5 class="font-bold mb-2">1. Download Template</h5>
                  
                  <p class="text-gray-600 mb-2">
                    Start with our template that includes all available property columns.
                  </p>
                  
                  <button phx-click="download_template" class="btn btn-sm btn-outline w-full">
                    <.icon name="hero-arrow-down-tray" class="w-4 h-4 mr-2" /> Download Template
                  </button>
                </div>
                
                <div class="divider"></div>
                
                <div>
                  <h5 class="font-bold mb-2">2. Required Columns</h5>
                  
                  <ul class="list-disc list-inside text-gray-600 space-y-1">
                    <li>title</li>
                    
                    <li>description</li>
                    
                    <li>status</li>
                    
                    <li>access_level</li>
                    
                    <li>thumbnail</li>
                    
                    <li>creator_id</li>
                  </ul>
                </div>
                
                <div class="divider"></div>
                
                <div>
                  <h5 class="font-bold mb-2">3. Status Values</h5>
                  
                  <div class="space-y-1">
                    <span class="badge badge-sm">draft</span>
                    <span class="badge badge-sm">pending</span>
                    <span class="badge badge-sm">published</span>
                    <span class="badge badge-sm">archived</span>
                  </div>
                </div>
                
                <div class="divider"></div>
                
                <div>
                  <h5 class="font-bold mb-2">4. Access Levels</h5>
                  
                  <div class="space-y-1">
                    <span class="badge badge-sm">public</span>
                    <span class="badge badge-sm">private</span>
                    <span class="badge badge-sm">restricted</span>
                  </div>
                </div>
                
                <div class="divider"></div>
                
                <div>
                  <h5 class="font-bold mb-2">5. Available Properties</h5>
                  
                  <p class="text-gray-600 mb-2">Add columns using these property names:</p>
                  
                  <div class="max-h-48 overflow-y-auto space-y-1">
                    <%= for prop <- @available_properties do %>
                      <div class="badge badge-outline badge-sm">{prop.local_name}</div>
                    <% end %>
                  </div>
                </div>
                
                <div class="divider"></div>
                
                <div>
                  <h5 class="font-bold mb-2">6. Items (Optional)</h5>
                  
                  <p class="text-gray-600">
                    Add item columns: item_1_item_code, item_1_inventory_code, item_1_location, etc.
                  </p>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp error_to_string(:too_large), do: "File is too large (max 10MB)"
  defp error_to_string(:not_accepted), do: "File type not accepted (only .csv files)"
  defp error_to_string(:too_many_files), do: "Too many files (max 1 file)"
  defp error_to_string(err), do: "Upload error: #{inspect(err)}"
end
