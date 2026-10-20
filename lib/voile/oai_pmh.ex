defmodule Voile.OaiPmh do
  @moduledoc """
  Context module for OAI-PMH (Open Archives Initiative Protocol for Metadata Harvesting) v2.0.

  Implements the six OAI-PMH verbs:
  - Identify: Repository identification and configuration
  - ListMetadataFormats: Available metadata formats
  - ListSets: Collection hierarchy (sets)
  - ListIdentifiers: Item identifiers with datestamps
  - ListRecords: Full metadata records
  - GetRecord: Single record retrieval

  Follows the guidelines at: https://www.openarchives.org/OAI/2.0/guidelines.htm
  """

  import Ecto.Query
  alias Voile.Repo
  alias Voile.Schema.Catalog.{Collection, Item}
  alias Voile.Schema.System

  @repository_name "Voile - Virtual Organized Information & Library Ecosystem"
  @protocol_version "2.0"
  @granularity "YYYY-MM-DDThh:mm:ssZ"
  @deleted_record "transient"
  @earliest_datestamp "2024-01-01T00:00:00Z"

  # Placeholder contacts observed in harvested environments; never expose them.
  @placeholder_admin_emails ["some.one@contact.com", "admin@voile.example.com"]

  # Metadata format specifications
  @metadata_formats %{
    "oai_dc" => %{
      prefix: "oai_dc",
      schema: "http://www.openarchives.org/OAI/2.0/oai_dc.xsd",
      namespace: "http://www.openarchives.org/OAI/2.0/oai_dc/"
    },
    "marc21" => %{
      prefix: "marc21",
      schema: "http://www.loc.gov/standards/marcxml/schema/MARC21slim.xsd",
      namespace: "http://www.loc.gov/MARC21/slim"
    }
  }

  @doc """
  Handles the Identify verb.
  Returns repository identification information.
  """
  def identify(base_url) do
    %{
      repository_name: @repository_name,
      base_url: base_url,
      protocol_version: @protocol_version,
      admin_emails: admin_emails(),
      earliest_datestamp: earliest_datestamp(),
      deleted_record: @deleted_record,
      granularity: @granularity,
      compression: ["gzip", "deflate"],
      descriptions: repository_descriptions()
    }
  end

  @doc """
  Handles the ListMetadataFormats verb.
  Returns available metadata formats, optionally for a specific identifier.
  """
  def list_metadata_formats(identifier \\ nil) do
    if identifier do
      case resolve_record_target(identifier) do
        {:ok, {:item, item_id}} ->
          if Repo.get(Item, item_id) do
            {:ok, Map.values(@metadata_formats)}
          else
            {:error, :id_does_not_exist}
          end

        {:ok, {:collection, collection_code}} ->
          if Repo.get_by(Collection, collection_code: collection_code) do
            {:ok, Map.values(@metadata_formats)}
          else
            {:error, :id_does_not_exist}
          end

        {:error, _} ->
          {:error, :id_does_not_exist}
      end
    else
      {:ok, Map.values(@metadata_formats)}
    end
  end

  @doc """
  Handles the ListSets verb.
  Returns the set structure (collections hierarchy).
  Supports resumption tokens for pagination.
  """
  def list_sets(resumption_token \\ nil) do
    token = decode_resumption_token(resumption_token)
    offset = token.offset
    cursor = token.cursor
    limit = 100

    query =
      from c in Collection,
        where: c.status == "published",
        order_by: [asc: c.id],
        offset: ^offset,
        limit: ^(limit + 1),
        preload: [:resource_class, :node]

    sets = Repo.all(query)
    has_more = length(sets) > limit
    sets = Enum.take(sets, limit)

    sets =
      if cursor == 0 do
        [documented_set("items"), documented_set("collections")] ++ Enum.map(sets, &format_set/1)
      else
        Enum.map(sets, &format_set/1)
      end

    result = %{sets: sets}

    if has_more do
      new_token = encode_resumption_token(offset + limit, cursor + 1, nil, nil, nil, nil)

      result
      |> Map.put(:resumption_token, new_token)
      |> Map.put(:cursor, cursor)
      |> Map.put(:complete_list_size, count_total_sets() + 2)
    else
      result
    end
    |> then(&{:ok, &1})
  end

  # Virtual top-level sets so consumers can harvest each record granularity.
  @doc false
  def documented_set_spec_values do
    "items | collections | collection:<COLLECTION_CODE>"
  end

  defp documented_set("items") do
    %{
      set_spec: "items",
      set_name: "Items (item-level records)",
      set_description:
        "All item-level records. This is the default set harvested when no set " <>
          "argument is given. Documented setSpec values: #{documented_set_spec_values()}"
    }
  end

  defp documented_set("collections") do
    %{
      set_spec: "collections",
      set_name: "Collections (collection-level records)",
      set_description:
        "All collection-level records, one per bibliographic record. Harvest this set " <>
          "with ListRecords/ListIdentifiers set=collections and GetRecord with identifier " <>
          "oai:<repository>:collection:<COLLECTION_CODE>. " <>
          "Documented setSpec values: #{documented_set_spec_values()}"
    }
  end

  @doc """
  Handles the ListIdentifiers verb.
  Returns item identifiers with datestamps and set membership.
  Supports selective harvesting by date and set.
  """
  def list_identifiers(opts \\ []) do
    token = decode_resumption_token(Keyword.get(opts, :resumption_token))

    metadata_prefix = Keyword.get(opts, :metadata_prefix) || token.metadata_prefix
    from_date = Keyword.get(opts, :from) || token.from
    until_date = Keyword.get(opts, :until) || token.until
    set_spec = Keyword.get(opts, :set) || token.set

    with :ok <- validate_metadata_prefix(metadata_prefix),
         :ok <- validate_dates(from_date, until_date) do
      offset = token.offset
      cursor = token.cursor
      limit = 100

      if set_spec == "collections" do
        query = build_collections_query(from_date, until_date, offset, limit)
        collections = Repo.all(query)
        has_more = length(collections) > limit
        collections = Enum.take(collections, limit)

        result = %{identifiers: Enum.map(collections, &format_collection_identifier/1)}

        paginate_result(
          result,
          has_more,
          offset,
          cursor,
          limit,
          metadata_prefix,
          from_date,
          until_date,
          set_spec
        )
      else
        query = build_items_query(from_date, until_date, set_spec, offset, limit)
        items = query |> preload(:collection) |> Repo.all()
        has_more = length(items) > limit
        items = Enum.take(items, limit)

        result = %{identifiers: Enum.map(items, &format_identifier/1)}

        paginate_result(
          result,
          has_more,
          offset,
          cursor,
          limit,
          metadata_prefix,
          from_date,
          until_date,
          set_spec
        )
      end
    end
    |> case do
      {:ok, _} = success -> success
      error -> error
    end
  end

  @doc """
  Handles the ListRecords verb.
  Returns full metadata records for items (default or set=items / set=collection:<CODE>)
  and for collections (set=collections).
  Supports selective harvesting by date and set.
  """
  def list_records(opts \\ []) do
    token = decode_resumption_token(Keyword.get(opts, :resumption_token))

    metadata_prefix = Keyword.get(opts, :metadata_prefix) || token.metadata_prefix
    from_date = Keyword.get(opts, :from) || token.from
    until_date = Keyword.get(opts, :until) || token.until
    set_spec = Keyword.get(opts, :set) || token.set

    with :ok <- validate_metadata_prefix(metadata_prefix),
         :ok <- validate_dates(from_date, until_date) do
      offset = token.offset
      cursor = token.cursor
      limit = 50

      if set_spec == "collections" do
        query = build_collections_query(from_date, until_date, offset, limit)

        collections =
          query
          |> preload([
            :mst_creator,
            :resource_class,
            collection_fields: [metadata_properties: :vocabulary]
          ])
          |> Repo.all()

        has_more = length(collections) > limit
        collections = Enum.take(collections, limit)

        result = %{records: Enum.map(collections, &format_collection_record(&1, metadata_prefix))}

        paginate_result(
          result,
          has_more,
          offset,
          cursor,
          limit,
          metadata_prefix,
          from_date,
          until_date,
          set_spec
        )
      else
        query = build_items_query(from_date, until_date, set_spec, offset, limit)

        items =
          query
          |> preload([
            :node,
            collection: [
              :mst_creator,
              :resource_class,
              collection_fields: [metadata_properties: :vocabulary]
            ]
          ])
          |> Repo.all()

        has_more = length(items) > limit
        items = Enum.take(items, limit)

        result = %{records: Enum.map(items, &format_record(&1, metadata_prefix))}

        paginate_result(
          result,
          has_more,
          offset,
          cursor,
          limit,
          metadata_prefix,
          from_date,
          until_date,
          set_spec
        )
      end
    end
    |> case do
      {:ok, _} = success -> success
      error -> error
    end
  end

  @doc """
  Handles the GetRecord verb.
  Returns a single metadata record by identifier.
  """
  def get_record(identifier, metadata_prefix) do
    with :ok <- validate_metadata_prefix(metadata_prefix),
         {:ok, target} <- resolve_record_target(identifier) do
      case target do
        {:item, item_id} ->
          case Repo.get(Item, item_id) do
            nil ->
              {:error, :id_does_not_exist}

            item ->
              item = preload_collection_metadata([item]) |> List.first()
              {:ok, format_record(item, metadata_prefix)}
          end

        {:collection, collection_code} ->
          case Repo.get_by(Collection, collection_code: collection_code) do
            nil ->
              {:error, :id_does_not_exist}

            collection ->
              collection =
                Repo.preload(collection, [
                  :mst_creator,
                  :resource_class,
                  collection_fields: [metadata_properties: :vocabulary]
                ])

              {:ok, format_collection_record(collection, metadata_prefix)}
          end
      end
    end
    |> case do
      {:ok, _} = success -> success
      error -> error
    end
  end

  # Private Functions

  defp admin_emails do
    email = System.get_setting_value("app_contact_email", nil)
    fallback = Application.get_env(:voile, :oai_pmh_admin_email, "chrisnaadhip@gmail.com")

    if is_binary(email) and email != "" and email not in @placeholder_admin_emails do
      [email]
    else
      [fallback]
    end
  end

  defp earliest_datestamp do
    # Must mirror the datestamp source (item.updated_at) so from/until filtering
    # never excludes records the earliestDatestamp claims are available.
    query =
      from i in Item,
        select: min(i.updated_at),
        limit: 1

    case Repo.one(query) do
      nil -> @earliest_datestamp
      datetime -> format_datetime(datetime)
    end
  end

  defp repository_descriptions do
    [
      %{
        type: "oai-identifier",
        scheme: "oai",
        repository_identifier: repository_identifier(),
        delimiter: ":",
        sample_identifier: "oai:#{repository_identifier()}:item:#{generate_sample_id()}"
      }
    ]
  end

  defp repository_identifier do
    Application.get_env(:voile, :oai_pmh_repository_id, "voile.example.com")
  end

  defp generate_sample_id do
    query = from i in Item, select: i.id, limit: 1
    Repo.one(query) || "00000000-0000-0000-0000-000000000000"
  end

  defp format_set(set) do
    %{
      set_spec: "collection:#{set.collection_code}",
      set_name: set.title,
      set_description: set.description
    }
  end

  defp count_total_sets do
    Repo.one(from c in Collection, where: c.status == "published", select: count(c.id))
  end

  defp build_items_query(from_date, until_date, set_spec, offset, limit) do
    query =
      from i in Item,
        join: c in Collection,
        on: i.collection_id == c.id,
        where: c.status == "published",
        order_by: [asc: i.updated_at],
        offset: ^offset,
        limit: ^(limit + 1)

    query = apply_date_filters(query, from_date, until_date)
    query = apply_set_filter(query, set_spec)

    query
  end

  defp apply_date_filters(query, nil, nil), do: query

  defp apply_date_filters(query, from_date, nil) when not is_nil(from_date) do
    from_datetime = parse_datetime(from_date)
    from [i, c] in query, where: i.updated_at >= ^from_datetime
  end

  defp apply_date_filters(query, nil, until_date) when not is_nil(until_date) do
    until_datetime = parse_datetime(until_date)
    from [i, c] in query, where: i.updated_at <= ^until_datetime
  end

  defp apply_date_filters(query, from_date, until_date) do
    from_datetime = parse_datetime(from_date)
    until_datetime = parse_datetime(until_date)

    from [i, c] in query,
      where: i.updated_at >= ^from_datetime and i.updated_at <= ^until_datetime
  end

  defp build_collections_query(from_date, until_date, offset, limit) do
    query =
      from c in Collection,
        where: c.status == "published",
        order_by: [asc: c.updated_at],
        offset: ^offset,
        limit: ^(limit + 1)

    apply_collection_date_filters(query, from_date, until_date)
  end

  defp apply_collection_date_filters(query, nil, nil), do: query

  defp apply_collection_date_filters(query, from_date, until_date) do
    from_datetime = parse_datetime(from_date)
    until_datetime = parse_datetime(until_date)

    case {from_datetime, until_datetime} do
      {nil, nil} ->
        query

      {%DateTime{} = from_dt, nil} ->
        from c in query, where: c.updated_at >= ^from_dt

      {nil, %DateTime{} = until_dt} ->
        from c in query, where: c.updated_at <= ^until_dt

      {%DateTime{} = from_dt, %DateTime{} = until_dt} ->
        from c in query, where: c.updated_at >= ^from_dt and c.updated_at <= ^until_dt
    end
  end

  defp apply_set_filter(query, nil), do: query

  defp apply_set_filter(query, "items"), do: query

  defp apply_set_filter(query, set_spec) do
    # Extract collection code from set_spec (format: "collection:CODE")
    collection_code = String.replace_prefix(set_spec, "collection:", "")
    from [i, c] in query, where: c.collection_code == ^collection_code
  end

  defp count_total_items(from_date, until_date, set_spec) do
    query =
      from i in Item,
        join: c in Collection,
        on: i.collection_id == c.id,
        where: c.status == "published",
        select: count(i.id)

    query = apply_date_filters(query, from_date, until_date)
    query = apply_set_filter(query, set_spec)

    Repo.one(query)
  end

  defp count_total_collections(from_date, until_date) do
    query =
      from c in Collection,
        where: c.status == "published",
        select: count(c.id)

    query = apply_collection_date_filters(query, from_date, until_date)

    Repo.one(query)
  end

  defp paginate_result(result, false, _offset, _cursor, _limit, _prefix, _from, _until, _spec),
    do: {:ok, result}

  defp paginate_result(result, true, offset, cursor, limit, metadata_prefix, from, until, spec) do
    new_token =
      encode_resumption_token(offset + limit, cursor + 1, metadata_prefix, from, until, spec)

    complete_list_size =
      if spec == "collections",
        do: count_total_collections(from, until),
        else: count_total_items(from, until, spec)

    {:ok,
     result
     |> Map.put(:resumption_token, new_token)
     |> Map.put(:cursor, cursor)
     |> Map.put(:complete_list_size, complete_list_size)}
  end

  defp format_identifier(item) do
    %{
      identifier: build_oai_identifier(item.id),
      datestamp: format_datetime(item.updated_at),
      set_specs: item_set_specs(item),
      status: if(item.status == "active", do: nil, else: "deleted")
    }
  end

  defp format_record(item, metadata_prefix) do
    status = if(item.status == "active", do: nil, else: "deleted")

    header =
      %{
        identifier: build_oai_identifier(item.id),
        datestamp: format_datetime(item.updated_at),
        set_specs: item_set_specs(item)
      }
      |> then(fn header ->
        if status, do: Map.put(header, :status, status), else: header
      end)

    %{
      header: header,
      metadata: format_metadata(item, metadata_prefix),
      metadata_prefix: metadata_prefix
    }
  end

  defp item_set_specs(item) do
    ["items", "collection:#{item.collection.collection_code}"]
  end

  defp build_collection_identifier(collection_code) do
    "oai:#{repository_identifier()}:collection:#{collection_code}"
  end

  defp format_collection_identifier(collection) do
    %{
      identifier: build_collection_identifier(collection.collection_code),
      datestamp: format_datetime(collection.updated_at),
      set_specs: ["collections"]
    }
  end

  defp format_collection_record(collection, metadata_prefix) do
    %{
      header: %{
        identifier: build_collection_identifier(collection.collection_code),
        datestamp: format_datetime(collection.updated_at),
        set_specs: ["collections"]
      },
      metadata: format_collection_metadata(collection, metadata_prefix),
      metadata_prefix: metadata_prefix
    }
  end

  defp format_collection_metadata(collection, _metadata_prefix) do
    dc =
      %{
        title: List.wrap(collection.title),
        description: List.wrap(collection.description)
      }
      |> put_non_nullish(:rights, collection.access_level)

    dc =
      case collection.mst_creator do
        %{creator_name: name} when is_binary(name) and name != "" ->
          Map.put(dc, :creator, [name])

        _ ->
          dc
      end

    dc =
      case collection.resource_class do
        %{label: label} when is_binary(label) and label != "" ->
          Map.put(dc, :type, [label])

        _ ->
          dc
      end

    dc = put_non_nullish(dc, :source, "collection:#{collection.collection_code}")

    dc
    |> drop_null_and_empty_values()
    |> normalize_title(collection)
  end

  defp put_non_nullish(map, key, value) do
    if nullish_value?(value), do: map, else: Map.put(map, key, [String.trim(to_string(value))])
  end

  # MARC21 Helper Functions

  defp build_marc_leader(_dc_metadata) do
    # MARC21 leader: 24 characters
    # Position 06: Type of record (a = language material)
    # Position 07: Bibliographic level (m = monograph)
    # Position 17: Encoding level (# = unknown)
    # Position 18: Descriptive cataloging form (a = AACR2)
    # Position 19: Multipart resource record level (# = not specified)
    "00000nam a2200000   4500"
  end

  defp build_marc_controlfields(dc_metadata) do
    _controlfields = []

    # 001 - Control number (use identifier if available)
    # 005 - Date and time of latest transaction (use current timestamp)
    # 008 - Fixed-length data elements
    case dc_metadata[:identifier] do
      [id | _] -> [%{tag: "001", value: id}]
      _ -> []
    end ++
      [
        %{
          tag: "005",
          value:
            DateTime.utc_now()
            |> DateTime.to_iso8601()
            |> String.replace(["-", ":", "T", "Z"], "")
        }
      ] ++
      [%{tag: "008", value: build_marc_008_field(dc_metadata)}]
  end

  defp build_marc_008_field(dc_metadata) do
    # MARC21 008 field: 40 characters for books
    now = DateTime.utc_now()

    date_entered =
      String.slice(DateTime.to_iso8601(now), 2, 6) <> String.slice(DateTime.to_iso8601(now), 8, 2)

    # Type of date/Publication status (s = single known date)
    type_of_date = "s"

    # Date 1 (publication date)
    date1 =
      case dc_metadata[:date] do
        [date | _] when is_binary(date) ->
          # Extract year from date string
          case Regex.run(~r/(\d{4})/, date) do
            [_, year] -> year
            _ -> String.slice(date_entered, 0, 4)
          end

        _ ->
          String.slice(date_entered, 0, 4)
      end

    # Date 2 (leave blank for single date)
    date2 = "    "

    # Publication place (xx = unknown)
    pub_place = "xx"

    # Language (extract from language field or default to eng)
    language =
      case dc_metadata[:language] do
        [lang | _] when is_binary(lang) -> String.slice(lang, 0, 3)
        _ -> "eng"
      end

    # Build the 008 field
    date_entered <>
      type_of_date <>
      date1 <>
      date2 <> pub_place <> String.duplicate(" ", 31) <> language <> String.duplicate(" ", 2)
  end

  defp build_marc_datafields(dc_metadata) do
    datafields = []

    # 020 - ISBN
    datafields = datafields ++ build_marc_isbn_fields(dc_metadata)

    # 100/700 - Personal name (creator)
    datafields = datafields ++ build_marc_creator_fields(dc_metadata)

    # 245 - Title statement
    datafields = datafields ++ build_marc_title_field(dc_metadata)

    # 250 - Edition statement
    datafields = datafields ++ build_marc_edition_field(dc_metadata)

    # 260 - Publication, distribution, etc.
    datafields = datafields ++ build_marc_publication_field(dc_metadata)

    # 300 - Physical description
    datafields = datafields ++ build_marc_physical_field(dc_metadata)

    # 500 - General note (description)
    datafields = datafields ++ build_marc_description_fields(dc_metadata)

    # 650 - Subject added entry - topical term
    datafields = datafields ++ build_marc_subject_fields(dc_metadata)

    # 700 - Added entry - personal name (contributors)
    datafields = datafields ++ build_marc_contributor_fields(dc_metadata)

    # 856 - Electronic location and access
    datafields = datafields ++ build_marc_identifier_fields(dc_metadata)

    datafields
  end

  defp build_marc_isbn_fields(dc_metadata) do
    case dc_metadata[:identifier] do
      identifiers when is_list(identifiers) ->
        identifiers
        |> Enum.filter(&String.contains?(&1, "ISBN"))
        |> Enum.map(fn isbn ->
          # Extract ISBN number
          isbn_number = Regex.replace(~r/.*ISBN[:\s]*/, isbn, "")
          %{tag: "020", ind1: " ", ind2: " ", subfields: [%{code: "a", value: isbn_number}]}
        end)

      _ ->
        []
    end
  end

  defp build_marc_creator_fields(dc_metadata) do
    case dc_metadata[:creator] do
      [creator | _] when is_binary(creator) ->
        [%{tag: "100", ind1: "1", ind2: " ", subfields: [%{code: "a", value: creator}]}]

      _ ->
        []
    end
  end

  defp build_marc_title_field(dc_metadata) do
    case dc_metadata[:title] do
      [title | _] when is_binary(title) ->
        [%{tag: "245", ind1: "1", ind2: "0", subfields: [%{code: "a", value: title}]}]

      _ ->
        []
    end
  end

  defp build_marc_edition_field(dc_metadata) do
    # Look for edition information in relation field
    case dc_metadata[:relation] do
      relations when is_list(relations) ->
        relations
        |> Enum.filter(&String.contains?(&1, "edition"))
        |> Enum.map(fn edition ->
          %{tag: "250", ind1: " ", ind2: " ", subfields: [%{code: "a", value: edition}]}
        end)
        |> case do
          [] -> []
          [field] -> [field]
        end

      _ ->
        []
    end
  end

  defp build_marc_publication_field(dc_metadata) do
    pub_info = %{}

    # Publisher
    pub_info =
      case dc_metadata[:publisher] do
        [publisher | _] -> Map.put(pub_info, :publisher, publisher)
        _ -> pub_info
      end

    # Date
    pub_info =
      case dc_metadata[:date] do
        [date | _] -> Map.put(pub_info, :date, date)
        _ -> pub_info
      end

    # Place
    pub_info =
      case dc_metadata[:coverage] do
        [place | _] -> Map.put(pub_info, :place, place)
        _ -> pub_info
      end

    if map_size(pub_info) > 0 do
      subfields = []

      subfields =
        if pub_info[:place],
          do: subfields ++ [%{code: "a", value: pub_info.place}],
          else: subfields

      subfields =
        if pub_info[:publisher],
          do: subfields ++ [%{code: "b", value: pub_info.publisher}],
          else: subfields

      subfields =
        if pub_info[:date], do: subfields ++ [%{code: "c", value: pub_info.date}], else: subfields

      [%{tag: "260", ind1: " ", ind2: " ", subfields: subfields}]
    else
      []
    end
  end

  defp build_marc_physical_field(dc_metadata) do
    case dc_metadata[:format] do
      [format | _] when is_binary(format) ->
        [%{tag: "300", ind1: " ", ind2: " ", subfields: [%{code: "a", value: format}]}]

      _ ->
        []
    end
  end

  defp build_marc_description_fields(dc_metadata) do
    case dc_metadata[:description] do
      descriptions when is_list(descriptions) ->
        descriptions
        # Limit to 3 description fields
        |> Enum.take(3)
        |> Enum.map(fn desc ->
          %{tag: "500", ind1: " ", ind2: " ", subfields: [%{code: "a", value: desc}]}
        end)

      _ ->
        []
    end
  end

  defp build_marc_subject_fields(dc_metadata) do
    case dc_metadata[:subject] do
      subjects when is_list(subjects) ->
        subjects
        # Limit to 5 subject fields
        |> Enum.take(5)
        |> Enum.map(fn subject ->
          %{tag: "650", ind1: " ", ind2: "0", subfields: [%{code: "a", value: subject}]}
        end)

      _ ->
        []
    end
  end

  defp build_marc_contributor_fields(dc_metadata) do
    case dc_metadata[:contributor] do
      [contributor | _] when is_binary(contributor) ->
        [%{tag: "700", ind1: "1", ind2: " ", subfields: [%{code: "a", value: contributor}]}]

      _ ->
        []
    end
  end

  defp build_marc_identifier_fields(dc_metadata) do
    case dc_metadata[:identifier] do
      identifiers when is_list(identifiers) ->
        identifiers
        |> Enum.filter(fn id -> String.contains?(id, "http") end)
        # Limit to 3 identifier fields
        |> Enum.take(3)
        |> Enum.map(fn url ->
          %{tag: "856", ind1: "4", ind2: " ", subfields: [%{code: "u", value: url}]}
        end)

      _ ->
        []
    end
  end

  defp format_metadata(item, "oai_dc") do
    collection = item.collection

    base_metadata =
      %{
        identifier: [item.item_code, item.inventory_code, item.barcode] |> Enum.reject(&is_nil/1),
        coverage: List.wrap(item.location)
      }
      |> put_non_nullish(:source, "collection:#{collection.collection_code}")

    base_metadata =
      case collection.resource_class do
        %{label: label} when is_binary(label) and label != "" ->
          Map.put(base_metadata, :type, [String.trim(label)])

        _ ->
          base_metadata
      end

    base_metadata = put_non_nullish(base_metadata, :rights, collection.access_level)

    base_metadata =
      case collection.mst_creator do
        %{creator_name: name} when is_binary(name) and name != "" ->
          Map.put(base_metadata, :creator, [String.trim(name)])

        _ ->
          base_metadata
      end

    field_metadata = extract_dublin_core_from_collection_fields(collection)

    merge_metadata(base_metadata, field_metadata)
    |> drop_null_and_empty_values()
    |> normalize_title(collection)
    |> normalize_date()
    |> split_creators()
  end

  defp format_metadata(item, "marc21") do
    # Convert Dublin Core metadata to MARC21 XML structure
    dc_metadata = format_metadata(item, "oai_dc")

    # Build MARC21 record structure
    marc_record = %{
      leader: build_marc_leader(dc_metadata),
      controlfields: build_marc_controlfields(dc_metadata),
      datafields: build_marc_datafields(dc_metadata)
    }

    marc_record
  end

  defp merge_metadata(base, fields) do
    Map.merge(base, fields, fn _k, v1, v2 ->
      Enum.uniq(List.wrap(v1) ++ List.wrap(v2))
    end)
  end

  # Keep exactly one title: the item's own record title (its parent collection's
  # authoritative title column), falling back to the first harvested title field.
  defp normalize_title(metadata, collection) do
    title =
      if nullish_value?(collection.title) do
        case metadata[:title] do
          values when is_list(values) and values != [] -> [List.first(values)]
          _ -> nil
        end
      else
        [String.trim(collection.title)]
      end

    case title do
      nil -> metadata
      t -> Map.put(metadata, :title, t)
    end
  end

  # Keep exactly one dc:date (the record's publication year); drop the rest.
  defp normalize_date(metadata) do
    case metadata[:date] do
      values when is_list(values) and values != [] ->
        Map.put(metadata, :date, [List.first(values)])

      _ ->
        metadata
    end
  end

  # Primary creator stays dc:creator (first); the rest become dc:contributor.
  defp split_creators(metadata) do
    case metadata[:creator] do
      [primary | rest] when rest != [] ->
        metadata
        |> Map.put(:creator, [primary])
        |> Map.update(:contributor, rest, fn existing ->
          Enum.uniq(List.wrap(existing) ++ rest)
        end)

      _ ->
        metadata
    end
  end

  defp drop_null_and_empty_values(metadata) do
    metadata
    |> Enum.map(fn {key, values} -> {key, List.wrap(values)} end)
    |> Enum.map(fn {key, values} ->
      {key, values |> Enum.reject(&nullish_value?/1) |> Enum.map(&String.trim(&1))}
    end)
    |> Enum.reject(fn {_key, values} -> values == [] end)
    |> Map.new()
  end

  defp nullish_value?(nil), do: true

  defp nullish_value?(value) when is_binary(value) do
    trimmed = String.trim(value)

    trimmed == "" or
      trimmed in [
        "\\N",
        "NULL",
        "null",
        "None",
        "NONE",
        "none",
        "N/A",
        "n/a"
      ]
  end

  defp nullish_value?(_), do: false

  defp build_oai_identifier(item_id) do
    "oai:#{repository_identifier()}:item:#{item_id}"
  end

  defp resolve_record_target(identifier) do
    case parse_oai_identifier(identifier) do
      {:ok, {:item, item_id}} ->
        {:ok, {:item, item_id}}

      {:ok, {:collection, collection_code}} ->
        {:ok, {:collection, collection_code}}

      {:error, _} ->
        {:error, :id_does_not_exist}
    end
  end

  defp parse_oai_identifier("oai:" <> rest) do
    # Find the last occurrence of ":item:" / ":collection:" to handle
    # repository IDs containing colons
    expected_repo = repository_identifier()

    cond do
      String.contains?(rest, ":item:") ->
        case String.split(rest, ":item:") do
          [repo_part, item_id] ->
            if String.ends_with?(repo_part, expected_repo) do
              {:ok, {:item, item_id}}
            else
              {:error, :invalid_format}
            end

          _ ->
            {:error, :invalid_format}
        end

      String.contains?(rest, ":collection:") ->
        case String.split(rest, ":collection:") do
          [repo_part, collection_code] ->
            if String.ends_with?(repo_part, expected_repo) and collection_code != "" do
              {:ok, {:collection, collection_code}}
            else
              {:error, :invalid_format}
            end

          _ ->
            {:error, :invalid_format}
        end

      true ->
        {:error, :invalid_format}
    end
  end

  defp parse_oai_identifier(_), do: {:error, :invalid_format}

  defp validate_metadata_prefix(nil), do: {:error, :bad_argument}

  defp validate_metadata_prefix(prefix) do
    if Map.has_key?(@metadata_formats, prefix) do
      :ok
    else
      {:error, :cannot_disseminate_format}
    end
  end

  defp validate_dates(nil, nil), do: :ok

  defp validate_dates(from_date, until_date) do
    with {:ok, _} <- parse_datetime_safe(from_date),
         {:ok, _} <- parse_datetime_safe(until_date) do
      :ok
    else
      _ -> {:error, :bad_argument}
    end
  end

  defp parse_datetime_safe(nil), do: {:ok, nil}

  defp parse_datetime_safe(date_string) do
    case DateTime.from_iso8601(date_string) do
      {:ok, datetime, _} -> {:ok, datetime}
      _ -> {:error, :invalid_format}
    end
  end

  defp preload_collection_metadata(items) do
    Repo.preload(items, [
      :node,
      collection: [
        :mst_creator,
        collection_fields: [
          metadata_properties: :vocabulary
        ]
      ]
    ])
  end

  defp extract_dublin_core_from_collection_fields(collection) do
    collection.collection_fields
    # Harvest in field insertion order so "first value" choices (dc:date)
    # reflect the original import, not unordered UUID primary keys.
    |> Enum.sort_by(& &1.inserted_at, {:asc, DateTime})
    |> Enum.reduce(%{}, fn field, acc ->
      case map_collection_field_to_dublin_core(field) do
        {dc_field, value} when not is_nil(value) and value != "" ->
          Map.update(acc, dc_field, [value], fn existing -> existing ++ [value] end)

        _ ->
          acc
      end
    end)
  end

  defp map_collection_field_to_dublin_core(field) do
    property = field.metadata_properties
    vocabulary = property.vocabulary

    # Map based on vocabulary prefix and local_name to Dublin Core elements
    dc_field =
      case {vocabulary.prefix, property.local_name} do
        # Dublin Core Terms mapping
        {"dcterms", "title"} -> :title
        {"dcterms", "creator"} -> :creator
        {"dcterms", "subject"} -> :subject
        {"dcterms", "description"} -> :description
        {"dcterms", "publisher"} -> :publisher
        {"dcterms", "contributor"} -> :contributor
        {"dcterms", "date"} -> :date
        {"dcterms", "type"} -> :type
        {"dcterms", "format"} -> :format
        {"dcterms", "identifier"} -> :identifier
        {"dcterms", "source"} -> :source
        {"dcterms", "language"} -> :language
        {"dcterms", "relation"} -> :relation
        {"dcterms", "coverage"} -> :coverage
        {"dcterms", "rights"} -> :rights
        {"dcterms", "audience"} -> :audience
        {"dcterms", "alternative"} -> :title
        {"dcterms", "tableOfContents"} -> :description
        {"dcterms", "abstract"} -> :description
        {"dcterms", "created"} -> :date
        {"dcterms", "valid"} -> :date
        {"dcterms", "available"} -> :date
        {"dcterms", "issued"} -> :date
        {"dcterms", "modified"} -> :date
        {"dcterms", "extent"} -> :format
        {"dcterms", "medium"} -> :format
        {"dcterms", "isVersionOf"} -> :relation
        {"dcterms", "hasVersion"} -> :relation
        {"dcterms", "isReplacedBy"} -> :relation
        {"dcterms", "replaces"} -> :relation
        {"dcterms", "isRequiredBy"} -> :relation
        {"dcterms", "requires"} -> :relation
        {"dcterms", "isPartOf"} -> :relation
        {"dcterms", "hasPart"} -> :relation
        {"dcterms", "isReferencedBy"} -> :relation
        {"dcterms", "references"} -> :relation
        {"dcterms", "isFormatOf"} -> :relation
        {"dcterms", "hasFormat"} -> :relation
        # BIBO (Bibliographic Ontology) mapping
        {"bibo", "isbn"} -> :identifier
        {"bibo", "issn"} -> :identifier
        {"bibo", "doi"} -> :identifier
        {"bibo", "author"} -> :creator
        {"bibo", "editor"} -> :contributor
        {"bibo", "abstract"} -> :description
        {"bibo", "pages"} -> :format
        {"bibo", "volume"} -> :relation
        {"bibo", "issue"} -> :relation
        # FOAF (Friend of a Friend) mapping
        {"foaf", "name"} -> :creator
        {"foaf", "title"} -> :title
        {"foaf", "homepage"} -> :source
        # Custom vocabularies and Kandaga fields - map common fields by local_name
        {_prefix, "title"} -> :title
        {_prefix, "creator"} -> :creator
        {_prefix, "author"} -> :creator
        {_prefix, "description"} -> :description
        {_prefix, "abstract"} -> :description
        {_prefix, "notes"} -> :description
        {_prefix, "publisher"} -> :publisher
        {_prefix, "date"} -> :date
        {_prefix, "publishedYear"} -> :date
        {_prefix, "subject"} -> :subject
        {_prefix, "keywords"} -> :subject
        {_prefix, "classification"} -> :subject
        {_prefix, "language"} -> :language
        {_prefix, "languageType"} -> :language
        {_prefix, "identifier"} -> :identifier
        {_prefix, "isbn"} -> :identifier
        {_prefix, "issn"} -> :identifier
        {_prefix, "callNumber"} -> :identifier
        {_prefix, "format"} -> :format
        {_prefix, "collation"} -> :format
        {_prefix, "extent"} -> :format
        {_prefix, "edition"} -> :relation
        {_prefix, "seriesTitle"} -> :relation
        {_prefix, "location"} -> :coverage
        # Unmapped fields
        _ -> nil
      end

    if dc_field do
      {dc_field, field.value}
    else
      nil
    end
  end

  defp parse_datetime(nil), do: nil

  defp parse_datetime(date_string) do
    case DateTime.from_iso8601(date_string) do
      {:ok, datetime, _} -> datetime
      _ -> nil
    end
  end

  defp format_datetime(nil), do: nil

  defp format_datetime(%DateTime{} = datetime) do
    DateTime.to_iso8601(datetime)
  end

  defp format_datetime(%NaiveDateTime{} = naive) do
    naive
    |> DateTime.from_naive!("Etc/UTC")
    |> DateTime.to_iso8601()
  end

  # Resumption Token Management

  @token_expiry_minutes 60

  # Tokens carry the metadataPrefix plus any selective-harvest arguments so a
  # request carrying only resumptionToken (no metadataPrefix) can continue the
  # list exactly as the original request specified (OAI-PMH spec 3.1.5.3).
  defp encode_resumption_token(offset, cursor, metadata_prefix, from, until, set_spec) do
    %{
      offset: offset,
      cursor: cursor,
      timestamp: :erlang.system_time(:second)
    }
    |> maybe_put_token_value(:metadataPrefix, metadata_prefix)
    |> maybe_put_token_value(:from, from)
    |> maybe_put_token_value(:until, until)
    |> maybe_put_token_value(:set, set_spec)
    |> Jason.encode!()
    |> Base.url_encode64(padding: false)
  end

  defp maybe_put_token_value(token_data, _key, nil), do: token_data
  defp maybe_put_token_value(token_data, key, value), do: Map.put(token_data, key, value)

  defp decode_resumption_token(nil), do: fresh_token()

  defp decode_resumption_token(token) when is_binary(token) do
    with {:ok, json} <- Base.url_decode64(token, padding: false),
         {:ok, data} <- Jason.decode(json),
         true <- token_expired?(data["timestamp"] || 0) == false,
         offset when is_integer(offset) <- data["offset"] do
      %{
        offset: offset,
        cursor: data["cursor"] || 0,
        metadata_prefix: data["metadataPrefix"],
        from: data["from"],
        until: data["until"],
        set: data["set"]
      }
    else
      _ -> fresh_token()
    end
  end

  defp fresh_token,
    do: %{offset: 0, cursor: 0, metadata_prefix: nil, from: nil, until: nil, set: nil}

  defp token_expired?(timestamp) do
    now = :erlang.system_time(:second)
    expiry_seconds = @token_expiry_minutes * 60
    now - timestamp > expiry_seconds
  end
end
