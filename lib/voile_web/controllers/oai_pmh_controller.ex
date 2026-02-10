defmodule VoileWeb.OaiPmhController do
  use VoileWeb, :controller

  alias Voile.OaiPmh
  alias Voile.OaiPmh.XmlBuilder

  @moduledoc """
  Controller for handling OAI-PMH (Open Archives Initiative Protocol for Metadata Harvesting) requests.

  Implements the six OAI-PMH verbs as defined in the protocol specification v2.0:
  - Identify
  - ListMetadataFormats
  - ListSets
  - ListIdentifiers
  - ListRecords
  - GetRecord

  All responses are returned as XML following the OAI-PMH schema.
  """

  @doc """
  Main endpoint for OAI-PMH requests.
  Handles both GET and POST requests as per OAI-PMH specification.
  """
  def index(conn, params) do
    verb = params["verb"]
    base_url = get_base_url(conn)

    case verb do
      "Identify" ->
        handle_identify(conn, params, base_url)

      "ListMetadataFormats" ->
        handle_list_metadata_formats(conn, params, base_url)

      "ListSets" ->
        handle_list_sets(conn, params, base_url)

      "ListIdentifiers" ->
        handle_list_identifiers(conn, params, base_url)

      "ListRecords" ->
        handle_list_records(conn, params, base_url)

      "GetRecord" ->
        handle_get_record(conn, params, base_url)

      nil ->
        send_error(conn, "badVerb", "Missing verb argument", params, base_url)

      _ ->
        send_error(
          conn,
          "badVerb",
          "Value of the verb argument is not a legal OAI-PMH verb",
          params,
          base_url
        )
    end
  end

  # Identify Verb Handler
  defp handle_identify(conn, params, base_url) do
    # Identify should not have any extra arguments except verb
    if map_size(params) > 1 do
      send_error(
        conn,
        "badArgument",
        "The request includes illegal arguments or is missing required arguments",
        params,
        base_url
      )
    else
      result = OaiPmh.identify(base_url)
      xml = XmlBuilder.build_response("Identify", %{verb: "Identify"}, result, base_url)
      send_xml_response(conn, xml)
    end
  end

  # ListMetadataFormats Verb Handler
  defp handle_list_metadata_formats(conn, params, base_url) do
    identifier = params["identifier"]

    # Check for illegal arguments
    allowed_args = ["verb", "identifier"]
    illegal_args = Map.keys(params) -- allowed_args

    if illegal_args != [] do
      send_error(
        conn,
        "badArgument",
        "The request includes illegal arguments",
        params,
        base_url
      )
    else
      case OaiPmh.list_metadata_formats(identifier) do
        {:ok, formats} ->
          request_params = if identifier, do: %{identifier: identifier}, else: %{}

          xml =
            XmlBuilder.build_response(
              "ListMetadataFormats",
              request_params,
              formats,
              base_url
            )

          send_xml_response(conn, xml)

        {:error, :id_does_not_exist} ->
          send_error(
            conn,
            "idDoesNotExist",
            "The value of the identifier argument is unknown or illegal",
            params,
            base_url
          )
      end
    end
  end

  # ListSets Verb Handler
  defp handle_list_sets(conn, params, base_url) do
    resumption_token = params["resumptionToken"]

    # If resumptionToken is present, it should be the only argument besides verb
    if resumption_token && map_size(params) > 2 do
      send_error(
        conn,
        "badArgument",
        "The resumptionToken argument should be used alone",
        params,
        base_url
      )
    else
      {:ok, result} = OaiPmh.list_sets(resumption_token)

      request_params =
        if resumption_token, do: %{resumptionToken: resumption_token}, else: %{}

      xml = XmlBuilder.build_response("ListSets", request_params, result, base_url)
      send_xml_response(conn, xml)
    end
  end

  # ListIdentifiers Verb Handler
  defp handle_list_identifiers(conn, params, base_url) do
    metadata_prefix = params["metadataPrefix"]
    from = params["from"]
    until_param = params["until"]
    set = params["set"]
    resumption_token = params["resumptionToken"]

    cond do
      # If resumptionToken is present, it should be the only argument besides verb
      resumption_token && map_size(params) > 2 ->
        send_error(
          conn,
          "badArgument",
          "The resumptionToken argument should be used alone",
          params,
          base_url
        )

      # metadataPrefix is required unless resumptionToken is present
      !resumption_token && is_nil(metadata_prefix) ->
        send_error(
          conn,
          "badArgument",
          "Missing required argument: metadataPrefix",
          params,
          base_url
        )

      true ->
        opts = [
          metadata_prefix: metadata_prefix || resumption_token,
          from: from,
          until: until_param,
          set: set,
          resumption_token: resumption_token
        ]

        case OaiPmh.list_identifiers(opts) do
          {:ok, result} ->
            request_params =
              %{}
              |> maybe_put(:metadataPrefix, metadata_prefix)
              |> maybe_put(:from, from)
              |> maybe_put(:until, until_param)
              |> maybe_put(:set, set)
              |> maybe_put(:resumptionToken, resumption_token)

            xml =
              XmlBuilder.build_response("ListIdentifiers", request_params, result, base_url)

            send_xml_response(conn, xml)

          {:error, :cannot_disseminate_format} ->
            send_error(
              conn,
              "cannotDisseminateFormat",
              "The metadata format identified by the value given for the metadataPrefix argument is not supported",
              params,
              base_url
            )

          {:error, :bad_argument} ->
            send_error(
              conn,
              "badArgument",
              "The request includes illegal arguments or arguments with illegal values",
              params,
              base_url
            )
        end
    end
  end

  # ListRecords Verb Handler
  defp handle_list_records(conn, params, base_url) do
    metadata_prefix = params["metadataPrefix"]
    from = params["from"]
    until_param = params["until"]
    set = params["set"]
    resumption_token = params["resumptionToken"]

    cond do
      # If resumptionToken is present, it should be the only argument besides verb
      resumption_token && map_size(params) > 2 ->
        send_error(
          conn,
          "badArgument",
          "The resumptionToken argument should be used alone",
          params,
          base_url
        )

      # metadataPrefix is required unless resumptionToken is present
      !resumption_token && is_nil(metadata_prefix) ->
        send_error(
          conn,
          "badArgument",
          "Missing required argument: metadataPrefix",
          params,
          base_url
        )

      true ->
        opts = [
          metadata_prefix: metadata_prefix || resumption_token,
          from: from,
          until: until_param,
          set: set,
          resumption_token: resumption_token
        ]

        case OaiPmh.list_records(opts) do
          {:ok, result} ->
            request_params =
              %{}
              |> maybe_put(:metadataPrefix, metadata_prefix)
              |> maybe_put(:from, from)
              |> maybe_put(:until, until_param)
              |> maybe_put(:set, set)
              |> maybe_put(:resumptionToken, resumption_token)

            xml = XmlBuilder.build_response("ListRecords", request_params, result, base_url)
            send_xml_response(conn, xml)

          {:error, :cannot_disseminate_format} ->
            send_error(
              conn,
              "cannotDisseminateFormat",
              "The metadata format identified by the value given for the metadataPrefix argument is not supported",
              params,
              base_url
            )

          {:error, :bad_argument} ->
            send_error(
              conn,
              "badArgument",
              "The request includes illegal arguments or arguments with illegal values",
              params,
              base_url
            )
        end
    end
  end

  # GetRecord Verb Handler
  defp handle_get_record(conn, params, base_url) do
    identifier = params["identifier"]
    metadata_prefix = params["metadataPrefix"]

    cond do
      is_nil(identifier) ->
        send_error(
          conn,
          "badArgument",
          "Missing required argument: identifier",
          params,
          base_url
        )

      is_nil(metadata_prefix) ->
        send_error(
          conn,
          "badArgument",
          "Missing required argument: metadataPrefix",
          params,
          base_url
        )

      map_size(params) > 3 ->
        send_error(
          conn,
          "badArgument",
          "The request includes illegal arguments",
          params,
          base_url
        )

      true ->
        case OaiPmh.get_record(identifier, metadata_prefix) do
          {:ok, result} ->
            request_params = %{identifier: identifier, metadataPrefix: metadata_prefix}
            xml = XmlBuilder.build_response("GetRecord", request_params, result, base_url)
            send_xml_response(conn, xml)

          {:error, :id_does_not_exist} ->
            send_error(
              conn,
              "idDoesNotExist",
              "The value of the identifier argument is unknown or illegal",
              params,
              base_url
            )

          {:error, :cannot_disseminate_format} ->
            send_error(
              conn,
              "cannotDisseminateFormat",
              "The metadata format identified by the value given for the metadataPrefix argument is not supported",
              params,
              base_url
            )
        end
    end
  end

  # Helper Functions

  defp send_xml_response(conn, xml) do
    conn
    |> put_resp_content_type("text/xml", "utf-8")
    |> send_resp(200, xml)
  end

  defp send_error(conn, error_code, message, params, base_url) do
    verb = params["verb"]
    # Remove sensitive or non-request params
    request_params =
      Map.take(params, [
        "verb",
        "identifier",
        "metadataPrefix",
        "from",
        "until",
        "set",
        "resumptionToken"
      ])

    xml = XmlBuilder.build_error_response(verb, request_params, error_code, message, base_url)
    send_xml_response(conn, xml)
  end

  defp get_base_url(conn) do
    scheme = if conn.scheme == :https, do: "https", else: "http"
    host = conn.host
    port = conn.port
    path = conn.request_path

    port_part =
      case {scheme, port} do
        {"https", 443} -> ""
        {"http", 80} -> ""
        {_, port} -> ":#{port}"
      end

    "#{scheme}://#{host}#{port_part}#{path}"
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
