defmodule Voile.OaiPmh.XmlBuilder do
  @moduledoc """
  Builds XML responses for OAI-PMH protocol requests.
  Follows OAI-PMH v2.0 specification for XML structure.
  """

  import XmlBuilder

  @oai_namespace "http://www.openarchives.org/OAI/2.0/"
  @oai_schema "http://www.openarchives.org/OAI/2.0/OAI-PMH.xsd"
  @dc_namespace "http://purl.org/dc/elements/1.1/"
  @oai_dc_namespace "http://www.openarchives.org/OAI/2.0/oai_dc/"
  @oai_dc_schema "http://www.openarchives.org/OAI/2.0/oai_dc.xsd"
  @marc21_namespace "http://www.loc.gov/MARC21/slim"
  @marc21_schema "http://www.loc.gov/standards/marcxml/schema/MARC21slim.xsd"
  @xsi_namespace "http://www.w3.org/2001/XMLSchema-instance"

  @doc """
  Builds a complete OAI-PMH response XML document.
  """
  def build_response(verb, params, result, base_url) do
    response_date = DateTime.utc_now() |> DateTime.to_iso8601()

    # Check if response contains MARC21 metadata to include MARC21 namespace
    has_marc21 = contains_marc21_metadata?(result)

    namespaces = %{
      xmlns: @oai_namespace,
      "xmlns:xsi": @xsi_namespace,
      "xsi:schemaLocation": "#{@oai_namespace} #{@oai_schema}"
    }

    namespaces =
      if has_marc21 do
        Map.put(namespaces, "xmlns:marc", @marc21_namespace)
      else
        namespaces
      end

    element(
      :OAI_PMH,
      namespaces,
      [
        element(:responseDate, response_date),
        build_request(verb, params, base_url),
        build_verb_response(verb, result)
      ]
    )
    |> generate(format: :indent)
    |> prepend_xml_declaration()
  end

  @doc """
  Builds an OAI-PMH error response.
  """
  def build_error_response(verb, params, error_code, message, base_url) do
    response_date = DateTime.utc_now() |> DateTime.to_iso8601()

    element(
      :OAI_PMH,
      %{
        xmlns: @oai_namespace,
        "xmlns:xsi": @xsi_namespace,
        "xsi:schemaLocation": "#{@oai_namespace} #{@oai_schema}"
      },
      [
        element(:responseDate, response_date),
        build_request(verb, params, base_url),
        element(:error, %{code: error_code}, message)
      ]
    )
    |> generate(format: :indent)
    |> prepend_xml_declaration()
  end

  # Private Functions

  defp prepend_xml_declaration(xml) do
    ~s(<?xml version="1.0" encoding="UTF-8"?>\n#{xml})
  end

  defp build_request(verb, params, base_url) do
    # Whitelist of known OAI-PMH parameters
    known_params = [:identifier, :metadataPrefix, :from, :until, :set, :resumptionToken]

    # Normalize params to atom keys to handle both string and atom keyed maps
    normalized_params =
      params
      |> Enum.filter(fn
        {k, _v} when is_binary(k) ->
          k in ["identifier", "metadataPrefix", "from", "until", "set", "resumptionToken"]

        {k, _v} when is_atom(k) ->
          k in known_params

        _ ->
          false
      end)
      |> Enum.map(fn
        {k, v} when is_binary(k) -> {String.to_atom(k), v}
        {k, v} when is_atom(k) -> {k, v}
      end)
      |> Map.new()

    # Build query string from params, always including verb
    all_params = Map.put(normalized_params, :verb, verb)

    query_params =
      all_params
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)
      |> Enum.map(fn {k, v} -> "#{k}=#{URI.encode_www_form(to_string(v))}" end)
      |> Enum.join("&")

    full_url = if query_params != "", do: "#{base_url}?#{query_params}", else: base_url

    # Build attributes with verb
    attrs = Map.put(normalized_params, :verb, verb)

    element(:request, attrs, full_url)
  end

  defp build_verb_response("Identify", result) do
    element(:Identify, [
      element(:repositoryName, result.repository_name),
      element(:baseURL, result.base_url),
      element(:protocolVersion, result.protocol_version),
      Enum.map(result.admin_emails, fn email ->
        element(:adminEmail, email)
      end),
      element(:earliestDatestamp, result.earliest_datestamp),
      element(:deletedRecord, result.deleted_record),
      element(:granularity, result.granularity),
      Enum.map(result.compression || [], fn comp ->
        element(:compression, comp)
      end),
      Enum.map(result.descriptions || [], &build_description/1)
    ])
  end

  defp build_verb_response("ListMetadataFormats", result) do
    element(
      :ListMetadataFormats,
      Enum.map(result, fn format ->
        element(:metadataFormat, [
          element(:metadataPrefix, format.prefix),
          element(:schema, format.schema),
          element(:metadataNamespace, format.namespace)
        ])
      end)
    )
  end

  defp build_verb_response("ListSets", result) do
    sets_elements = Enum.map(result.sets, &build_set/1)

    resumption_element =
      if Map.has_key?(result, :resumption_token) do
        attrs = %{
          cursor: result.cursor,
          completeListSize: result.complete_list_size
        }

        [element(:resumptionToken, attrs, result.resumption_token)]
      else
        []
      end

    element(:ListSets, sets_elements ++ resumption_element)
  end

  defp build_verb_response("ListIdentifiers", result) do
    identifier_elements = Enum.map(result.identifiers, &build_header/1)

    resumption_element =
      if Map.has_key?(result, :resumption_token) do
        attrs = %{
          cursor: result.cursor,
          completeListSize: result.complete_list_size
        }

        [element(:resumptionToken, attrs, result.resumption_token)]
      else
        []
      end

    element(:ListIdentifiers, identifier_elements ++ resumption_element)
  end

  defp build_verb_response("ListRecords", result) do
    record_elements = Enum.map(result.records, &build_record/1)

    resumption_element =
      if Map.has_key?(result, :resumption_token) do
        attrs = %{
          cursor: result.cursor,
          completeListSize: result.complete_list_size
        }

        [element(:resumptionToken, attrs, result.resumption_token)]
      else
        []
      end

    element(:ListRecords, record_elements ++ resumption_element)
  end

  defp build_verb_response("GetRecord", result) do
    element(:GetRecord, [
      build_record(result)
    ])
  end

  defp build_description(desc) do
    case desc.type do
      "oai-identifier" ->
        element(:description, [
          element(
            :"oai-identifier",
            %{
              xmlns: "http://www.openarchives.org/OAI/2.0/oai-identifier",
              "xmlns:xsi": @xsi_namespace,
              "xsi:schemaLocation":
                "http://www.openarchives.org/OAI/2.0/oai-identifier http://www.openarchives.org/OAI/2.0/oai-identifier.xsd"
            },
            [
              element(:scheme, desc.scheme),
              element(:repositoryIdentifier, desc.repository_identifier),
              element(:delimiter, desc.delimiter),
              element(:sampleIdentifier, desc.sample_identifier)
            ]
          )
        ])

      _ ->
        element(:description, desc.content || "")
    end
  end

  defp build_set(set) do
    children = [
      element(:setSpec, set.set_spec),
      element(:setName, set.set_name)
    ]

    children =
      if set.set_description do
        children ++
          [
            element(:setDescription, [
              build_dc_metadata(%{description: [set.set_description]})
            ])
          ]
      else
        children
      end

    element(:set, children)
  end

  defp build_header(header) do
    attrs = if Map.get(header, :status), do: %{status: header.status}, else: %{}

    set_specs =
      Enum.map(Map.get(header, :set_specs, []), fn spec ->
        element(:setSpec, spec)
      end)

    element(
      :header,
      attrs,
      [
        element(:identifier, header.identifier),
        element(:datestamp, header.datestamp)
      ] ++ set_specs
    )
  end

  defp build_record(record) do
    element(:record, [
      build_header(record.header),
      element(:metadata, [
        build_metadata(record.metadata, Map.get(record, :metadata_prefix, "oai_dc"))
      ])
    ])
  end

  defp build_metadata(metadata, metadata_prefix)

  defp build_metadata(metadata, "marc21") when is_map(metadata) do
    build_marc21_metadata(metadata)
  end

  defp build_metadata(metadata, _metadata_prefix) when is_map(metadata) do
    # Default to Dublin Core format
    build_dc_metadata(metadata)
  end

  defp build_dc_metadata(metadata) do
    dc_elements =
      metadata
      |> Enum.flat_map(fn {field, values} ->
        Enum.map(List.wrap(values), fn value ->
          element(:"dc:#{field}", %{xmlns: @dc_namespace}, value)
        end)
      end)

    element(
      :"oai_dc:dc",
      %{
        "xmlns:oai_dc": @oai_dc_namespace,
        "xmlns:dc": @dc_namespace,
        "xmlns:xsi": @xsi_namespace,
        "xsi:schemaLocation": "#{@oai_dc_namespace} #{@oai_dc_schema}"
      },
      dc_elements
    )
  end

  defp build_marc21_metadata(marc_record) do
    # Build MARC21 XML structure
    marc_elements = []

    # Leader
    marc_elements = marc_elements ++ [element(:"marc:leader", marc_record.leader)]

    # Control fields
    controlfield_elements =
      Enum.map(marc_record.controlfields || [], fn cf ->
        element(:"marc:controlfield", %{tag: cf.tag}, cf.value)
      end)

    marc_elements = marc_elements ++ controlfield_elements

    # Data fields
    datafield_elements =
      Enum.map(marc_record.datafields || [], fn df ->
        subfield_elements =
          Enum.map(df.subfields || [], fn sf ->
            element(:"marc:subfield", %{code: sf.code}, sf.value)
          end)

        element(
          :"marc:datafield",
          %{tag: df.tag, ind1: df.ind1, ind2: df.ind2},
          subfield_elements
        )
      end)

    marc_elements = marc_elements ++ datafield_elements

    element(
      :"marc:record",
      %{
        "xmlns:marc": @marc21_namespace,
        "xmlns:xsi": @xsi_namespace,
        "xsi:schemaLocation": "#{@marc21_namespace} #{@marc21_schema}"
      },
      marc_elements
    )
  end

  # Helper function to check if result contains MARC21 metadata
  defp contains_marc21_metadata?(result) do
    case result do
      %{records: records} when is_list(records) ->
        Enum.any?(records, fn record ->
          Map.get(record, :metadata_prefix) == "marc21" ||
            (is_map(record.metadata) && Map.has_key?(record.metadata, :leader))
        end)

      %{metadata: _metadata, metadata_prefix: "marc21"} ->
        true

      %{metadata: metadata} when is_map(metadata) ->
        Map.has_key?(metadata, :leader)

      _ ->
        false
    end
  end
end
