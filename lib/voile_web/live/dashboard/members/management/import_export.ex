defmodule VoileWeb.Dashboard.Members.Management.ImportExport do
  @moduledoc """
  Import members from CSV.

  The CSV format uses the following headers:
  fullname, email, username, identifier, member_type, node, user_image,
  groups, registration_date, expiry_date, manually_suspended,
  suspension_reason, address, phone_number, birth_date, birth_place,
  gender, organization, department, position, password
  """

  use VoileWeb, :live_view_dashboard

  import Ecto.Query, warn: false

  alias Voile.Repo
  alias Voile.Schema.Accounts
  alias Voile.Schema.Master.MemberType
  alias Voile.Schema.System.Node
  alias VoileWeb.Auth.Authorization

  @csv_headers ~w(
    fullname email username identifier member_type node user_image groups
    registration_date expiry_date manually_suspended suspension_reason
    address phone_number birth_date birth_place gender organization
    department position password
  )

  @max_file_size 10_000_000

  @impl true
  def mount(_params, _session, socket) do
    authorize!(socket, "users.create")

    current_user = socket.assigns.current_scope.user
    is_super_admin = Authorization.is_super_admin?(current_user)

    nodes =
      if is_super_admin do
        Repo.all(from(n in Node, order_by: n.name))
      else
        case current_user.node_id && Repo.get(Node, current_user.node_id) do
          %Node{} = node -> [node]
          _ -> []
        end
      end

    import_node_id =
      if is_super_admin,
        do: nodes |> List.first() |> then(&if(&1, do: &1.id, else: nil)),
        else: current_user.node_id

    {:ok,
     socket
     |> assign(:page_title, "Import Members")
     |> assign(:step, :upload)
     |> assign(:parse_error, nil)
     |> assign(:import_errors, [])
     |> assign(:success_count, 0)
     |> assign(:failure_count, 0)
     |> assign(:total_rows, 0)
     |> assign(:nodes, nodes)
     |> assign(:import_node_id, import_node_id)
     |> assign(:is_super_admin, is_super_admin)
     |> assign(:csv_headers, @csv_headers)
     |> allow_upload(:csv_file,
       accept: ~w(.csv text/csv),
       max_entries: 1,
       max_file_size: @max_file_size
     )}
  end

  @impl true
  def handle_event("cancel_upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :csv_file, ref)}
  end

  @impl true
  def handle_event("set_import_node", %{"node_id" => node_id}, socket) do
    if socket.assigns.is_super_admin do
      {:noreply, assign(socket, :import_node_id, parse_integer(node_id))}
    else
      {:noreply, socket}
    end
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
        import_members(socket, content)
    end
  end

  @impl true
  def handle_event("back_to_upload", _params, socket) do
    {:noreply,
     socket
     |> assign(:step, :upload)
     |> assign(:parse_error, nil)
     |> assign(:import_errors, [])
     |> assign(:success_count, 0)
     |> assign(:failure_count, 0)
     |> assign(:total_rows, 0)}
  end

  @impl true
  def handle_event("download_sample_csv", _params, socket) do
    sample_row = [
      "Jane Doe",
      "jane.doe@example.com",
      "jane.doe",
      "123456",
      "Student",
      "Main Library",
      "https://example.com/avatar.jpg",
      "group-a,group-b",
      "2026-01-01",
      "2027-01-01",
      "false",
      "",
      "123 Main St",
      "+62-812-3456-7890",
      "1990-02-15",
      "Jakarta",
      "Female",
      "Example University",
      "Science",
      "Research Assistant",
      "changeme123"
    ]

    csv_content =
      ([@csv_headers] ++ [sample_row])
      |> NimbleCSV.RFC4180.dump_to_iodata()
      |> IO.iodata_to_binary()

    {:noreply,
     push_event(socket, "download", %{
       filename: "member_sample.csv",
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
            {gettext("Import Members")}
          </h1>
          <p class="mt-1 text-sm text-gray-600 dark:text-gray-300">
            {gettext(
              "Upload a CSV file to bulk-import member profiles. Password is optional; blank passwords will default to changeme123."
            )}
          </p>
        </div>

        <.link
          navigate={~p"/manage/members/management"}
          class="inline-flex items-center gap-2 text-sm font-semibold text-gray-700 bg-white border border-gray-300 rounded-md px-3 py-2 hover:bg-gray-50 dark:bg-gray-700 dark:border-gray-600 dark:text-gray-200 dark:hover:bg-gray-600 transition-colors"
        >
          <.icon name="hero-arrow-left" class="w-4 h-4" />
          {gettext("Back to Members")}
        </.link>
      </div>

      <div class="grid gap-6 lg:grid-cols-[minmax(0,1.4fr)_minmax(0,0.8fr)]">
        <div class="space-y-6">
          <div class="bg-white dark:bg-gray-800 rounded-xl border border-gray-200 dark:border-gray-700 p-6 shadow-sm">
            <h2 class="text-lg font-semibold text-gray-900 dark:text-white">
              {gettext("CSV Upload")}
            </h2>
            <p class="mt-2 text-sm text-gray-600 dark:text-gray-300">
              {gettext("The first row must contain headers and the file size must not exceed 10 MB.")}
            </p>

            <.form for={%{}} phx-submit="parse_csv" id="member-import-form" class="space-y-4">
              <%= if @is_super_admin do %>
                <.input
                  name="node_id"
                  type="select"
                  label={gettext("Import to Node")}
                  options={Enum.map(@nodes, &{&1.name, to_string(&1.id)})}
                  value={to_string(@import_node_id || "")}
                  phx-change="set_import_node"
                />
              <% end %>

              <div
                phx-drop-target={@uploads.csv_file.ref}
                class="border-2 border-dashed border-gray-300 dark:border-gray-600 rounded-2xl p-8 text-center transition-colors hover:border-blue-400 dark:hover:border-blue-500 hover:bg-blue-50 dark:hover:bg-gray-700/60 cursor-pointer"
              >
                <.icon name="hero-document-arrow-up" class="mx-auto h-10 w-10 text-gray-400" />
                <p class="mt-4 text-sm font-semibold text-gray-900 dark:text-white">
                  {gettext("Drop a CSV file here or click to browse")}
                </p>
                <p class="text-sm text-gray-500 dark:text-gray-400">
                  {gettext("Accepted format: .csv")}
                </p>
                <label class="mt-4 inline-flex cursor-pointer rounded-md border border-gray-300 bg-white px-4 py-2 text-sm font-medium text-gray-700 shadow-sm hover:bg-gray-50 dark:border-gray-600 dark:bg-gray-800 dark:text-gray-200 dark:hover:bg-gray-700">
                  <span>{gettext("Browse file")}</span>
                  <.live_file_input upload={@uploads.csv_file} class="sr-only" />
                </label>
              </div>

              <%= for entry <- @uploads.csv_file.entries do %>
                <div class="rounded-xl border border-blue-200 bg-blue-50 p-4 text-sm text-blue-700 dark:border-blue-800 dark:bg-blue-900/30 dark:text-blue-200">
                  <p>{entry.client_name}</p>
                  <p class="text-xs text-gray-500 dark:text-gray-400">
                    {gettext("Size: %{size} bytes", size: entry.client_size)}
                  </p>
                </div>
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
                  {gettext("Import Members")}
                </.button>

                <.button
                  class="inline-flex items-center gap-2 border border-gray-300 bg-white px-5 py-3 text-sm font-semibold text-gray-700 shadow-sm hover:bg-gray-50 dark:border-gray-600 dark:bg-gray-800 dark:text-gray-200 dark:hover:bg-gray-700"
                  phx-click="back_to_upload"
                  type="button"
                >
                  {gettext("Reset")}
                </.button>
              </div>
            </.form>
          </div>

          <div class="rounded-xl border border-gray-200 dark:border-gray-700 bg-white dark:bg-gray-800 p-6 shadow-sm">
            <div class="flex items-center justify-between gap-3">
              <h3 class="text-sm font-semibold uppercase tracking-wide text-gray-500 dark:text-gray-400">
                {gettext("CSV headers")}
              </h3>
              <.button
                class="inline-flex items-center gap-2 rounded-md border border-gray-300 bg-white px-3 py-2 text-xs font-semibold text-gray-700 shadow-sm hover:bg-gray-50 dark:border-gray-600 dark:bg-gray-800 dark:text-gray-200 dark:hover:bg-gray-700"
                phx-click="download_sample_csv"
                type="button"
              >
                <.icon name="hero-download" class="w-4 h-4" />
                {gettext("Download sample CSV")}
              </.button>
            </div>
            <div class="mt-3 overflow-x-auto text-sm text-gray-700 dark:text-gray-300">
              <code class="block whitespace-pre-wrap">{Enum.join(@csv_headers, ",")}</code>
            </div>
          </div>
        </div>

        <div class="space-y-6">
          <div class="rounded-xl border border-gray-200 dark:border-gray-700 bg-white dark:bg-gray-800 p-6 shadow-sm">
            <h2 class="text-lg font-semibold text-gray-900 dark:text-white">
              {gettext("Import summary")}
            </h2>

            <div class="mt-4 space-y-3 text-sm text-gray-600 dark:text-gray-300">
              <p>{gettext("Total rows processed: %{count}", count: @total_rows)}</p>
              <p>{gettext("Successful imports: %{count}", count: @success_count)}</p>
              <p>{gettext("Failed imports: %{count}", count: @failure_count)}</p>
            </div>

            <%= if @failure_count > 0 do %>
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

  defp import_members(socket, content) do
    case parse_csv_content(content) do
      {:error, error} ->
        {:noreply, assign(socket, parse_error: error)}

      {:ok, rows} ->
        {success_count, failed_rows} =
          rows
          |> Enum.with_index(1)
          |> Enum.reduce({0, []}, fn {row, idx}, {success, failures} ->
            case import_csv_row(row, socket) do
              {:ok, _user} -> {success + 1, failures}
              {:error, reason} -> {success, [{idx, reason} | failures]}
            end
          end)

        {:noreply,
         socket
         |> assign(:step, :done)
         |> assign(:parse_error, nil)
         |> assign(:total_rows, length(rows))
         |> assign(:success_count, success_count)
         |> assign(:failure_count, length(failed_rows))
         |> assign(:import_errors, Enum.reverse(failed_rows))}
    end
  end

  defp parse_csv_content(content) do
    rows =
      content
      |> String.replace("\r\n", "\n")
      |> NimbleCSV.RFC4180.parse_string(skip_headers: false)
      |> Enum.reject(&(&1 == []))

    case rows do
      [] ->
        {:error, gettext("The CSV file is empty.")}

      [_headers | data_rows] when data_rows == [] ->
        {:error, gettext("The CSV file must contain at least one data row.")}

      [headers | data_rows] ->
        headers = Enum.map(headers, &String.trim/1)
        expected = Enum.map(@csv_headers, &String.downcase/1)

        if Enum.map(headers, &String.downcase/1) != expected do
          {:error,
           gettext("CSV headers do not match. Expected: %{headers}",
             headers: Enum.join(@csv_headers, ",")
           )}
        else
          {:ok, Enum.map(data_rows, &map_csv_row(headers, &1))}
        end
    end
  rescue
    e in NimbleCSV.ParseError ->
      {:error, gettext("Invalid CSV format: %{message}", message: e.message)}
  end

  defp map_csv_row(headers, row) do
    headers
    |> Enum.with_index()
    |> Enum.reduce(%{}, fn {header, idx}, acc ->
      value = row |> Enum.at(idx, "") |> to_string() |> String.trim()
      Map.put(acc, header, value)
    end)
  end

  defp import_csv_row(row, socket) do
    attrs = build_import_attrs(row, socket)
    password = Map.get(attrs, "password", "changeme1234")
    attrs = Map.put_new(attrs, "password", password)

    case Accounts.register_user(attrs) do
      {:ok, user} ->
        case maybe_apply_suspension(user, row) do
          {:ok, _} -> {:ok, user}
          {:error, reason} -> {:error, reason}
        end

      {:error, changeset} ->
        {:error, format_changeset_errors(changeset)}
    end
  end

  @doc false
  def build_import_attrs(row, socket) do
    node_id =
      if socket.assigns.is_super_admin do
        parse_node_id(row["node"]) || socket.assigns.import_node_id
      else
        socket.assigns.current_scope.user.node_id
      end

    %{
      "fullname" => row["fullname"],
      "email" => row["email"],
      "username" => row["username"],
      "identifier" => parse_identifier(row["identifier"]),
      "user_type_id" => resolve_member_type_id(row["member_type"]),
      "node_id" => node_id,
      "user_image" => row["user_image"],
      "groups" => parse_groups(row["groups"]),
      "registration_date" => parse_date(row["registration_date"]),
      "expiry_date" => parse_date(row["expiry_date"]),
      "address" => row["address"],
      "phone_number" => row["phone_number"],
      "birth_date" => parse_date(row["birth_date"]),
      "birth_place" => row["birth_place"],
      "gender" => row["gender"],
      "organization" => row["organization"],
      "department" => row["department"],
      "position" => row["position"],
      "password" => row["password"]
    }
  end

  defp maybe_apply_suspension(user, row) do
    attrs = %{
      "manually_suspended" => parse_boolean(row["manually_suspended"]),
      "suspension_reason" => row["suspension_reason"]
    }

    if attrs["manually_suspended"] || attrs["suspension_reason"] != "" do
      case Accounts.admin_update_user(user, attrs) do
        {:ok, updated} -> {:ok, updated}
        {:error, changeset} -> {:error, format_changeset_errors(changeset)}
      end
    else
      {:ok, user}
    end
  end

  defp resolve_member_type_id(value) when value in [nil, ""], do: nil

  defp resolve_member_type_id(value) do
    case Ecto.UUID.cast(value) do
      {:ok, uuid} ->
        case Repo.get(MemberType, uuid) do
          %MemberType{} = type -> type.id
          _ -> resolve_member_type_name(value)
        end

      :error ->
        resolve_member_type_name(value)
    end
  end

  defp resolve_member_type_name(value) do
    Repo.get_by(MemberType, name: value)
    |> case do
      %MemberType{} = type -> type.id
      _ -> nil
    end
  end

  defp parse_node_id(value) when value in [nil, ""], do: nil

  defp parse_node_id(value) do
    value = String.trim(value)

    case Repo.get(Node, value) do
      %Node{} = node ->
        node.id

      _ ->
        Repo.get_by(Node, name: value)
        |> case do
          %Node{} = node -> node.id
          _ -> nil
        end
    end
  end

  defp parse_identifier(value) when value in [nil, ""], do: nil

  defp parse_identifier(value) do
    value = String.trim(to_string(value))

    cond do
      value == "" ->
        nil

      true ->
        try do
          Decimal.new(value)
        rescue
          _ -> nil
        end
    end
  rescue
    _ -> nil
  end

  defp parse_groups(value) when value in [nil, ""], do: []

  defp parse_groups(value) do
    value
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp parse_date(value) when value in [nil, ""], do: nil

  defp parse_date(value) do
    case Date.from_iso8601(String.trim(value)) do
      {:ok, date} -> date
      _ -> nil
    end
  end

  defp parse_boolean(value) when value in [nil, ""], do: false

  defp parse_boolean(value) do
    case String.downcase(String.trim(to_string(value))) do
      "true" -> true
      "1" -> true
      "yes" -> true
      "y" -> true
      _ -> false
    end
  end

  defp format_changeset_errors(%Ecto.Changeset{} = changeset) do
    changeset
    |> Ecto.Changeset.traverse_errors(fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
    |> Enum.map(fn {field, messages} ->
      "#{field}: #{Enum.join(messages, ", ")}"
    end)
    |> Enum.join("; ")
  end

  defp parse_integer(nil), do: nil
  defp parse_integer(""), do: nil

  defp parse_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, _} -> int
      _ -> nil
    end
  end

  defp parse_integer(value) when is_integer(value), do: value
  defp parse_integer(_), do: nil
end
