NimbleCSV.define(VoileWeb.VisitorLogsCSV, separator: ",", escape: "\"")

defmodule VoileWeb.Dashboard.Visitor.LogsExportController do
  use VoileWeb, :controller

  alias Voile.Schema.System
  alias VoileWeb.Auth.Authorization
  alias VoileWeb.Utils.FormatIndonesiaTime

  def export(conn, params) do
    current_user = conn.assigns.current_scope.user
    is_super_admin = Authorization.is_super_admin?(current_user)

    from_date = parse_date(params["from_date"], Date.utc_today() |> Date.add(-7))
    to_date = parse_date(params["to_date"], Date.utc_today())

    from_datetime = DateTime.new!(from_date, ~T[00:00:00], "Etc/UTC")
    to_datetime = DateTime.new!(to_date, ~T[23:59:59], "Etc/UTC")

    opts = [
      from_date: from_datetime,
      to_date: to_datetime,
      preload: [:node, :location]
    ]

    # Non-super admins are always restricted to their own node
    opts =
      if is_super_admin do
        case parse_integer(params["node_id"]) do
          nil -> opts
          node_id -> Keyword.put(opts, :node_id, node_id)
        end
      else
        Keyword.put(opts, :node_id, current_user.node_id)
      end

    opts =
      case parse_integer(params["location_id"]) do
        nil -> opts
        location_id -> Keyword.put(opts, :location_id, location_id)
      end

    opts =
      case params["search"] do
        s when is_binary(s) and s != "" -> Keyword.put(opts, :search, String.trim(s))
        _ -> opts
      end

    logs = System.list_visitor_logs(opts)

    filename = "visitor_logs_#{Date.to_string(from_date)}_to_#{Date.to_string(to_date)}.csv"

    csv_content = build_csv(logs)

    conn
    |> put_resp_content_type("text/csv")
    |> put_resp_header("content-disposition", ~s[attachment; filename="#{filename}"])
    |> send_resp(200, csv_content)
  end

  defp build_csv(logs) do
    headers = [
      [
        "Check-In Time (WIB)",
        "Check-Out Time (WIB)",
        "Identifier",
        "Name",
        "Origin",
        "Visit Purpose",
        "Location/Room",
        "Faculty/Node",
        "IP Address"
      ]
    ]

    rows =
      Enum.map(logs, fn log ->
        [
          format_datetime(log.check_in_time),
          format_datetime(log.check_out_time),
          log.visitor_identifier || "",
          log.visitor_name || "",
          log.visitor_origin || "",
          get_in(log.additional_data || %{}, ["visit_purpose"]) || "",
          (log.location && log.location.location_name) || "",
          (log.node && log.node.name) || "",
          log.ip_address || ""
        ]
      end)

    (headers ++ rows)
    |> VoileWeb.VisitorLogsCSV.dump_to_iodata()
    |> IO.iodata_to_binary()
  end

  defp format_datetime(nil), do: ""

  defp format_datetime(%DateTime{} = dt) do
    dt
    |> FormatIndonesiaTime.shift_to_jakarta()
    |> Calendar.strftime("%d/%m/%Y %H:%M:%S WIB")
  end

  defp parse_date(nil, default), do: default
  defp parse_date("", default), do: default

  defp parse_date(date_string, default) do
    case Date.from_iso8601(date_string) do
      {:ok, date} -> date
      _ -> default
    end
  end

  defp parse_integer(nil), do: nil
  defp parse_integer(""), do: nil

  defp parse_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} -> int
      _ -> nil
    end
  end

  defp parse_integer(_), do: nil
end
