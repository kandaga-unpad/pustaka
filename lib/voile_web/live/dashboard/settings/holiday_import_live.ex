defmodule VoileWeb.Dashboard.Settings.HolidayImportLive do
  use VoileWeb, :live_view_dashboard

  import Ecto.Query, warn: false

  alias Voile.Repo
  alias Voile.Schema.System.{LibHolidays, LibHoliday, Node}
  alias VoileWeb.Auth.Authorization

  @csv_headers_core ~w(name holiday_date holiday_type description is_recurring is_active)
  @csv_headers_super_admin @csv_headers_core ++ ["unit_id"]
  @holiday_types ~w(public library custom)
  @max_file_size 10_000_000

  @impl true
  def mount(_params, _session, socket) do
    authorize!(socket, "system.settings")

    current_user = socket.assigns.current_scope.user
    is_super_admin = Authorization.is_super_admin?(current_user)

    nodes =
      if is_super_admin do
        Repo.all(from(n in Node, order_by: n.name))
      else
        []
      end

    {:ok,
     socket
     |> assign(:page_title, gettext("Import Holidays"))
     |> assign(:is_super_admin, is_super_admin)
     |> assign(:current_user, current_user)
     |> assign(:nodes, nodes)
     |> assign(:parse_error, nil)
     |> assign(:import_errors, [])
     |> assign(:success_count, 0)
     |> assign(:failure_count, 0)
     |> assign(:total_rows, 0)
     |> assign(
       :csv_headers,
       if(is_super_admin, do: @csv_headers_super_admin, else: @csv_headers_core)
     )
     |> assign(:max_file_size, @max_file_size)
     |> allow_upload(:csv_file,
       accept: ~w(.csv),
       max_entries: 1,
       max_file_size: @max_file_size,
       auto_upload: true
     )}
  end

  @impl true
  def handle_event("cancel_upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :csv_file, ref)}
  end

  @impl true
  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("parse_csv", _params, socket) do
    result =
      consume_uploaded_entries(socket, :csv_file, fn %{path: path}, _entry ->
        {:ok, File.read!(path)}
      end)

    case result do
      [] ->
        {:noreply, assign(socket, parse_error: gettext("Please select a CSV file first."))}

      [content] ->
        import_csv(socket, content)
    end
  end

  @impl true
  def handle_event("reset", _params, socket) do
    {:noreply,
     socket
     |> assign(:parse_error, nil)
     |> assign(:import_errors, [])
     |> assign(:success_count, 0)
     |> assign(:failure_count, 0)
     |> assign(:total_rows, 0)}
  end

  @impl true
  def handle_event("download_sample_csv", _params, socket) do
    sample_rows = sample_csv_rows(socket.assigns.is_super_admin)

    csv_content =
      ([socket.assigns.csv_headers] ++ sample_rows)
      |> NimbleCSV.RFC4180.dump_to_iodata()
      |> IO.iodata_to_binary()

    {:noreply,
     push_event(socket, "download", %{
       filename: "holiday_import_sample.csv",
       content: csv_content,
       mime_type: "text/csv"
     })}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-6xl mx-auto px-4 py-8">
      <div class="mb-6 flex flex-col gap-4 lg:flex-row lg:items-center lg:justify-between">
        <div>
          <h1 class="text-2xl font-bold text-gray-900 dark:text-white">
            {gettext("Import Holidays")}
          </h1>
          <p class="mt-1 text-sm text-gray-600 dark:text-gray-300">
            {gettext(
              "Upload a CSV file to bulk-import holiday entries. Duplicate rows are skipped and your node scope is enforced."
            )}
          </p>
        </div>

        <.link
          navigate={~p"/manage/settings/holidays"}
          class="inline-flex items-center gap-2 text-sm font-semibold text-gray-700 bg-white border border-gray-300 rounded-md px-3 py-2 hover:bg-gray-50 dark:bg-gray-700 dark:border-gray-600 dark:text-gray-200 dark:hover:bg-gray-600 transition-colors"
        >
          <.icon name="hero-arrow-left" class="w-4 h-4" />
          {gettext("Back to Holiday Settings")}
        </.link>
      </div>

      <div class="grid gap-6 lg:grid-cols-[minmax(0,1.4fr)_minmax(0,0.8fr)]">
        <div class="space-y-6">
          <div class="bg-white dark:bg-gray-800 rounded-xl border border-gray-200 dark:border-gray-700 p-6 shadow-sm">
            <h2 class="text-lg font-semibold text-gray-900 dark:text-white">
              {gettext("CSV Upload")}
            </h2>
            <p class="mt-2 text-sm text-gray-600 dark:text-gray-300">
              {gettext(
                "The first row must contain headers. Supported holiday types are public, library, and custom."
              )}
            </p>

            <.form
              for={%{}}
              phx-change="validate"
              phx-submit="parse_csv"
              id="holiday-csv-import-form"
              class="space-y-4"
            >
              <div
                phx-drop-target={@uploads.csv_file.ref}
                class="border-2 border-dashed border-gray-300 dark:border-gray-600 rounded-2xl p-8 text-center transition-colors hover:border-blue-400 dark:hover:border-blue-500 hover:bg-blue-50 dark:hover:bg-gray-700/60 cursor-pointer"
              >
                <.icon name="hero-document-arrow-up" class="mx-auto h-10 w-10 text-gray-400" />
                <p class="mt-4 text-sm font-semibold text-gray-900 dark:text-white">
                  {gettext("Drop a CSV file here or click to browse")}
                </p>
                <p class="text-sm text-gray-500 dark:text-gray-400">
                  {gettext("Accepted format: .csv. Maximum file size is %{size} MB.",
                    size: div(@max_file_size, 1_000_000)
                  )}
                </p>
                <label class="mt-4 inline-flex cursor-pointer rounded-md border border-gray-300 bg-white px-4 py-2 text-sm font-medium text-gray-700 shadow-sm hover:bg-gray-50 dark:border-gray-600 dark:bg-gray-800 dark:text-gray-200 dark:hover:bg-gray-700">
                  <span>{gettext("Browse file")}</span>
                  <.live_file_input upload={@uploads.csv_file} class="sr-only" />
                </label>
              </div>

              <%= if Enum.empty?(@uploads.csv_file.entries) do %>
                <div class="rounded-xl border border-dashed border-gray-300 bg-gray-50 p-4 text-sm text-gray-500 dark:border-gray-700 dark:bg-gray-700/10 dark:text-gray-300">
                  {gettext("No CSV file selected yet.")}
                </div>
              <% else %>
                <%= for entry <- @uploads.csv_file.entries do %>
                  <div class="rounded-xl border border-blue-200 bg-blue-50 p-4 text-sm text-blue-700 dark:border-blue-800 dark:bg-blue-900/30 dark:text-blue-200">
                    <p>{entry.client_name}</p>
                    <p class="text-xs text-gray-500 dark:text-gray-400">
                      {gettext("Size: %{size} bytes", size: entry.client_size)}
                    </p>
                  </div>
                <% end %>
              <% end %>

              <%= if @parse_error do %>
                <div class="rounded-xl border border-red-200 bg-red-50 p-4 text-sm text-red-700 dark:border-red-800 dark:bg-red-900/20 dark:text-red-200">
                  {@parse_error}
                </div>
              <% end %>

              <div class="flex flex-wrap gap-3">
                <.button
                  class="inline-flex items-center gap-2 bg-voile-primary text-white px-5 py-3 rounded-md shadow-sm hover:bg-voile-primary/90"
                  type="submit"
                >
                  <.icon name="hero-arrow-up-tray" class="w-5 h-5" />
                  {gettext("Import Holidays")}
                </.button>

                <.button
                  class="inline-flex items-center gap-2 border border-gray-300 bg-white px-5 py-3 text-sm font-semibold text-gray-700 shadow-sm hover:bg-gray-50 dark:border-gray-600 dark:bg-gray-800 dark:text-gray-200 dark:hover:bg-gray-700"
                  phx-click="reset"
                  type="button"
                >
                  {gettext("Reset")}
                </.button>

                <.button
                  class="inline-flex items-center gap-2 border border-gray-300 bg-white px-5 py-3 text-sm font-semibold text-gray-700 shadow-sm hover:bg-gray-50 dark:border-gray-600 dark:bg-gray-800 dark:text-gray-200 dark:hover:bg-gray-700"
                  phx-click="download_sample_csv"
                  type="button"
                >
                  <.icon name="hero-download" class="w-5 h-5" />
                  {gettext("Download sample CSV")}
                </.button>
              </div>
            </.form>
          </div>

          <div class="rounded-xl border border-gray-200 dark:border-gray-700 bg-white dark:bg-gray-800 p-6 shadow-sm">
            <h2 class="text-lg font-semibold text-gray-900 dark:text-white">
              {gettext("CSV Rules")}
            </h2>
            <div class="mt-4 space-y-3 text-sm text-gray-600 dark:text-gray-300">
              <p>{gettext("Each row adds a single holiday record.")}</p>
              <p>{gettext("System-wide holidays use an empty unit_id.")}</p>
              <p>
                {if @is_super_admin,
                  do:
                    gettext(
                      "Super admins may assign each row to a node using unit_id. If unit_id is blank, the row becomes a system-wide holiday."
                    ),
                  else:
                    gettext(
                      "Your assigned node is used automatically for all imported rows, so you do not need to include unit_id in the CSV."
                    )}
              </p>
              <p>
                {gettext(
                  "Duplicate holiday rows are skipped. Same date + type for the same unit is treated as a duplicate."
                )}
              </p>
              <p>
                {gettext(
                  "Recurring holidays are matched by month/day and automatically apply across years."
                )}
              </p>
              <p>
                {gettext(
                  "Date format must be YYYY-MM-DD and holiday_type must be one of public, library, or custom."
                )}
              </p>
            </div>
          </div>
        </div>

        <div class="space-y-6">
          <div class="rounded-xl border border-gray-200 dark:border-gray-700 bg-white dark:bg-gray-800 p-6 shadow-sm">
            <div class="flex items-center justify-between gap-3">
              <h3 class="text-sm font-semibold uppercase tracking-wide text-gray-500 dark:text-gray-400">
                {gettext("CSV headers")}
              </h3>
            </div>
            <div class="mt-3 overflow-x-auto text-sm text-gray-700 dark:text-gray-300">
              <code class="block whitespace-pre-wrap">{Enum.join(@csv_headers, ",")}</code>
            </div>
          </div>

          <div class="rounded-xl border border-gray-200 dark:border-gray-700 bg-white dark:bg-gray-800 p-6 shadow-sm">
            <h2 class="text-lg font-semibold text-gray-900 dark:text-white">
              {gettext("Import summary")}
            </h2>

            <div class="mt-4 space-y-3 text-sm text-gray-600 dark:text-gray-300">
              <p>{gettext("Total rows processed: %{count}", count: @total_rows)}</p>
              <p>{gettext("Successful imports: %{count}", count: @success_count)}</p>
              <p>{gettext("Failed imports: %{count}", count: @failure_count)}</p>
            </div>

            <%= if @import_errors != [] do %>
              <div class="mt-6 rounded-xl border border-red-200 bg-red-50 p-4 text-sm text-red-700 dark:border-red-800 dark:bg-red-900/20 dark:text-red-200">
                <h3 class="font-semibold">{gettext("Errors")}</h3>
                <ul class="mt-2 list-disc space-y-1 pl-5">
                  <%= for {row, reason} <- @import_errors do %>
                    <li>
                      <span class="font-semibold">{gettext("Row %{row}", row: row)}:</span>
                      <span>{reason}</span>
                    </li>
                  <% end %>
                </ul>
              </div>
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp import_csv(socket, content) do
    case parse_csv_content(content, socket) do
      {:error, error} ->
        {:noreply, assign(socket, parse_error: error)}

      {:ok, parsed_rows, parse_errors, total_row_count} ->
        {deduped_rows, duplicate_errors} = deduplicate_rows(parsed_rows)

        {success_count, import_errors} =
          deduped_rows
          |> Enum.with_index(1)
          |> Enum.reduce({0, []}, fn {row, index}, {success, failures} ->
            case LibHolidays.create_holiday(row) do
              {:ok, _holiday} ->
                {success + 1, failures}

              {:error, changeset} ->
                error_message = error_message_from_changeset(changeset)

                {
                  success,
                  [{index, error_message} | failures]
                }
            end
          end)

        import_errors = parse_errors ++ duplicate_errors ++ Enum.reverse(import_errors)

        {:noreply,
         socket
         |> assign(:parse_error, nil)
         |> assign(:success_count, success_count)
         |> assign(:failure_count, length(import_errors))
         |> assign(:total_rows, total_row_count)
         |> assign(:import_errors, import_errors)}
    end
  end

  defp deduplicate_rows(rows) do
    existing_holidays = fetch_existing_holidays(rows)

    {deduped_rows, duplicate_errors} =
      Enum.reduce(rows, {[], []}, fn row, {kept_rows, errors} ->
        row_index = row["__row_number__"]

        cond do
          duplicate_in_rows?(row, kept_rows) ->
            {
              kept_rows,
              [
                {row_index,
                 gettext(
                   "Duplicate holiday row for the same date, type, and unit scope within the uploaded file."
                 )}
                | errors
              ]
            }

          holiday_conflict?(row, existing_holidays) ->
            {
              kept_rows,
              [
                {row_index,
                 gettext(
                   "Duplicate holiday found for the same date and type. System-wide or same-unit entries already exist."
                 )}
                | errors
              ]
            }

          true ->
            {kept_rows ++ [row], errors}
        end
      end)

    {
      Enum.map(deduped_rows, &Map.delete(&1, "__row_number__")),
      Enum.reverse(duplicate_errors)
    }
  end

  defp duplicate_in_rows?(row, rows) do
    Enum.any?(rows, fn existing -> holiday_conflict_between_row_maps?(row, existing) end)
  end

  defp holiday_conflict?(row, existing_holidays) do
    Enum.any?(existing_holidays, fn existing ->
      holiday_conflict_between_row_and_existing?(row, existing)
    end)
  end

  defp holiday_conflict_between_row_maps?(row, existing_row) do
    same_type = row["holiday_type"] == existing_row["holiday_type"]

    same_scope =
      row["unit_id"] == existing_row["unit_id"] or is_nil(row["unit_id"]) or
        is_nil(existing_row["unit_id"])

    if same_type and same_scope do
      row_date = row["holiday_date"]
      existing_date = existing_row["holiday_date"]
      row_recurring = row["is_recurring"]
      existing_recurring = existing_row["is_recurring"]
      same_month_day = row_date.month == existing_date.month and row_date.day == existing_date.day

      same_month_day and (row_recurring or existing_recurring or row_date == existing_date)
    else
      false
    end
  end

  defp holiday_conflict_between_row_and_existing?(row, existing) do
    same_type = row["holiday_type"] == existing.holiday_type

    same_scope =
      row["unit_id"] == existing.unit_id or is_nil(row["unit_id"]) or is_nil(existing.unit_id)

    if same_type and same_scope do
      row_date = row["holiday_date"]
      existing_date = existing.holiday_date
      row_recurring = row["is_recurring"]
      existing_recurring = existing.is_recurring
      same_month_day = row_date.month == existing_date.month and row_date.day == existing_date.day

      same_month_day and (row_recurring or existing_recurring or row_date == existing_date)
    else
      false
    end
  end

  defp fetch_existing_holidays(rows) do
    date_type_pairs =
      rows
      |> Enum.map(fn row -> {row["holiday_date"], row["holiday_type"]} end)
      |> Enum.uniq()

    month_day_type_pairs =
      rows
      |> Enum.map(fn row ->
        {row["holiday_date"].month, row["holiday_date"].day, row["holiday_type"]}
      end)
      |> Enum.uniq()

    node_ids =
      rows
      |> Enum.map(& &1["unit_id"])
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()

    combined_match =
      date_type_pairs
      |> Enum.reduce(dynamic([h], false), fn {date, type}, acc ->
        dynamic([h], ^acc or (h.holiday_date == ^date and h.holiday_type == ^type))
      end)
      |> then(fn acc ->
        Enum.reduce(month_day_type_pairs, acc, fn {month, day, type}, acc ->
          dynamic(
            [h],
            ^acc or
              (h.holiday_type == ^type and h.is_recurring == true and
                 fragment(
                   "EXTRACT(month FROM ?) = ? AND EXTRACT(day FROM ?) = ?",
                   h.holiday_date,
                   ^month,
                   h.holiday_date,
                   ^day
                 ))
          )
        end)
      end)

    query =
      from(h in LibHoliday, where: h.schedule_type == "holiday")
      |> where(^combined_match)

    query =
      if node_ids == [] do
        query
      else
        from(h in query,
          where: is_nil(h.unit_id) or h.unit_id in ^node_ids
        )
      end

    Repo.all(query)
  end

  defp parse_csv_content(content, socket) do
    rows =
      content
      |> String.replace("\r\n", "\n")
      |> NimbleCSV.RFC4180.parse_string(skip_headers: false)
      |> Enum.reject(&(&1 == []))

    case rows do
      [] ->
        {:error, gettext("The CSV file is empty.")}

      [_headers] ->
        {:error, gettext("The CSV file must contain at least one data row.")}

      [headers | data_rows] ->
        headers = Enum.map(headers, &String.trim/1)

        with {:ok, canonical_headers} <- validate_csv_headers(headers, socket) do
          {parsed_rows, parse_errors} =
            data_rows
            |> Enum.with_index(2)
            |> Enum.map_reduce([], fn {row, row_number}, errors ->
              case parse_csv_row(canonical_headers, row, socket) do
                {:ok, row_attrs} ->
                  {Map.put(row_attrs, "__row_number__", row_number), errors}

                {:error, reason} ->
                  {nil, [{row_number, reason} | errors]}
              end
            end)

          valid_rows = Enum.reject(parsed_rows, &is_nil/1)
          total_row_count = length(data_rows)

          if valid_rows == [] do
            {:error,
             gettext("All rows are invalid. %{reason}", reason: format_errors(parse_errors))}
          else
            {:ok, valid_rows, Enum.reverse(parse_errors), total_row_count}
          end
        else
          {:error, reason} -> {:error, reason}
        end
    end
  rescue
    e in NimbleCSV.ParseError ->
      {:error, gettext("CSV parse error: %{message}", message: e.message)}
  end

  defp validate_csv_headers(headers, socket) do
    normalized =
      headers
      |> Enum.map(&String.trim/1)
      |> Enum.map(&String.downcase/1)
      |> Enum.map(&normalize_header/1)

    if socket.assigns.is_super_admin do
      allowed = @csv_headers_super_admin

      if invalid_columns?(normalized, allowed) do
        {:error,
         gettext(
           "CSV headers do not match. Expected headers: %{headers}",
           headers: Enum.join(allowed, ",")
         )}
      else
        {:ok, normalized}
      end
    else
      if normalized == @csv_headers_core or normalized == @csv_headers_super_admin do
        {:ok, normalized}
      else
        {:error,
         gettext(
           "CSV headers do not match. Regular users must use: %{headers}",
           headers: Enum.join(@csv_headers_core, ",")
         )}
      end
    end
  end

  defp normalize_header("node_id"), do: "unit_id"
  defp normalize_header(header), do: header

  defp invalid_columns?(normalized, allowed) do
    extra = normalized -- allowed
    missing = allowed -- normalized
    extra != [] or missing != []
  end

  defp parse_csv_row(headers, row, socket) do
    row_map =
      headers
      |> Enum.zip(row)
      |> Map.new(fn {key, value} -> {key, String.trim(value || "")} end)

    with {:ok, attrs} <- build_holiday_attrs(row_map, socket) do
      {:ok, attrs}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp build_holiday_attrs(row_map, socket) do
    current_user = socket.assigns.current_scope.user
    is_super_admin = socket.assigns.is_super_admin

    with {:ok, name} <- validate_presence(row_map, "name"),
         {:ok, holiday_date} <- parse_date(row_map["holiday_date"]),
         {:ok, holiday_type} <- validate_holiday_type(row_map["holiday_type"]),
         {:ok, is_recurring} <- parse_boolean(row_map["is_recurring"], false),
         {:ok, is_active} <- parse_boolean(row_map["is_active"], true),
         {:ok, unit_id} <- parse_unit_id(row_map, is_super_admin, current_user) do
      {:ok,
       %{
         "name" => name,
         "holiday_date" => holiday_date,
         "holiday_type" => holiday_type,
         "description" => blank_to_nil(row_map["description"]),
         "is_recurring" => is_recurring,
         "is_active" => is_active,
         "unit_id" => unit_id,
         "schedule_type" => "holiday"
       }}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp parse_unit_id(row_map, true, _current_user) do
    case Map.get(row_map, "unit_id") do
      nil ->
        {:ok, nil}

      "" ->
        {:ok, nil}

      value ->
        case Integer.parse(value) do
          {unit_id, ""} -> {:ok, unit_id}
          _ -> {:error, gettext("unit_id must be a valid integer or blank")}
        end
    end
  end

  defp parse_unit_id(row_map, false, current_user) do
    if Map.has_key?(row_map, "unit_id") and row_map["unit_id"] != "" do
      {:error,
       gettext(
         "Only super admins may provide unit_id. Regular users import into their assigned node automatically."
       )}
    else
      {:ok, current_user.node_id}
    end
  end

  defp validate_presence(row_map, key) do
    case Map.get(row_map, key) do
      nil -> {:error, gettext("Missing required field %{field}.", field: key)}
      "" -> {:error, gettext("Missing required field %{field}.", field: key)}
      value -> {:ok, value}
    end
  end

  defp parse_date("") do
    {:error, gettext("holiday_date is required and must be in YYYY-MM-DD format.")}
  end

  defp parse_date(value) when is_binary(value) do
    case Date.from_iso8601(value) do
      {:ok, date} -> {:ok, date}
      {:error, _} -> {:error, gettext("holiday_date must be in YYYY-MM-DD format.")}
    end
  end

  defp parse_date(_), do: {:error, gettext("holiday_date must be in YYYY-MM-DD format.")}

  defp validate_holiday_type(value) when is_binary(value) do
    normalized = String.downcase(String.trim(value))

    if normalized in @holiday_types do
      {:ok, normalized}
    else
      {:error,
       gettext(
         "holiday_type must be one of %{types}.",
         types: Enum.join(@holiday_types, ", ")
       )}
    end
  end

  defp validate_holiday_type(_),
    do:
      {:error,
       gettext("holiday_type must be one of %{types}.", types: Enum.join(@holiday_types, ", "))}

  defp parse_boolean("" = _value, default), do: {:ok, default}

  defp parse_boolean(value, _default) when is_binary(value) do
    case String.downcase(String.trim(value)) do
      "true" -> {:ok, true}
      "false" -> {:ok, false}
      "1" -> {:ok, true}
      "0" -> {:ok, false}
      _ -> {:error, gettext("Boolean values must be true/false or 1/0.")}
    end
  end

  defp parse_boolean(_, default), do: {:ok, default}

  defp blank_to_nil(""), do: nil
  defp blank_to_nil(value), do: value

  defp error_message_from_changeset(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, val}, acc ->
        String.replace(acc, "%{#{key}}", to_string(val))
      end)
    end)
    |> Enum.map_join(", ", fn {field, messages} ->
      "#{field}: #{Enum.join(messages, ", ")}"
    end)
  end

  defp sample_csv_rows(true) do
    [
      ["New Year's Day", "2027-01-01", "public", "System-wide holiday", "true", "true", ""],
      ["Branch Closing", "2027-03-15", "library", "Scheduled maintenance", "false", "true", "2"],
      [
        "Staff Training",
        "2027-08-10",
        "custom",
        "Half-day closure for staff training",
        "false",
        "true",
        "3"
      ]
    ]
  end

  defp sample_csv_rows(false) do
    [
      ["New Year's Day", "2027-01-01", "public", "System-wide holiday", "true", "true"],
      [
        "Library Study Day",
        "2027-04-05",
        "library",
        "Branch closure for inventory",
        "false",
        "true"
      ],
      [
        "Staff Training",
        "2027-08-10",
        "custom",
        "Half-day closure for staff training",
        "false",
        "true"
      ]
    ]
  end

  defp format_errors(errors) do
    errors
    |> Enum.map(fn {row, reason} -> "#{row}: #{reason}" end)
    |> Enum.join("; ")
  end
end
