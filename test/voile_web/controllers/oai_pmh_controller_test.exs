defmodule VoileWeb.OaiPmhControllerTest do
  use VoileWeb.ConnCase

  import Voile.Factory

  import Ecto.Query, only: [from: 2]

  alias Voile.Repo
  alias Voile.Schema.Catalog.{Collection, Item}
  alias Voile.Schema.System.Node

  @dc_ns "http://purl.org/dc/elements/1.1/"

  setup do
    # Create a node
    node = insert(:node, name: "Test Library", abbr: "TL")

    # Create a resource class
    resource_class = insert(:resource_class, label: "Book")

    # Create published collections
    collection1 =
      insert(:collection,
        collection_code: "TEST001",
        title: "Test Collection 1",
        description: "First test collection",
        status: "published",
        type_id: resource_class.id,
        unit_id: node.id
      )

    collection2 =
      insert(:collection,
        collection_code: "TEST002",
        title: "Test Collection 2",
        description: "Second test collection",
        status: "published",
        type_id: resource_class.id,
        unit_id: node.id
      )

    # Create draft collection (should not appear)
    _draft_collection =
      insert(:collection,
        collection_code: "DRAFT001",
        title: "Draft Collection",
        status: "draft",
        type_id: resource_class.id,
        unit_id: node.id
      )

    # Create items
    item1 =
      insert(:item,
        item_code: "ITEM001",
        inventory_code: "INV001",
        barcode: "BARCODE00001",
        collection_id: collection1.id,
        unit_id: node.id,
        status: "active"
      )

    item2 =
      insert(:item,
        item_code: "ITEM002",
        inventory_code: "INV002",
        barcode: "BARCODE00002",
        collection_id: collection2.id,
        unit_id: node.id,
        status: "active"
      )

    {:ok,
     node: node, collection1: collection1, collection2: collection2, item1: item1, item2: item2}
  end

  describe "root element name" do
    test "emits OAI-PMH (dashed) as required by OAI-PMH 2.0", %{conn: conn} do
      conn = get(conn, ~p"/api/oai?verb=Identify")
      body = response(conn, 200)
      assert String.starts_with?(body, "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<OAI-PMH ")
      refute body =~ "<OAI_PMH"
    end

    test "error responses also use OAI-PMH as root element", %{conn: conn} do
      conn = get(conn, ~p"/api/oai?verb=InvalidVerb")
      body = response(conn, 200)
      assert body =~ ~r/<OAI-PMH [^>]*xmlns=/
      refute body =~ "<OAI_PMH"
    end
  end

  describe "Identify verb" do
    test "returns repository information", %{conn: conn} do
      conn = get(conn, ~p"/api/oai?verb=Identify")

      assert response(conn, 200)
      assert get_resp_header(conn, "content-type") |> List.first() =~ "text/xml"

      body = response(conn, 200)
      assert body =~ "<?xml version=\"1.0\" encoding=\"UTF-8\"?>"
      assert body =~ "<OAI-PMH"
      assert body =~ "<Identify>"
      assert body =~ "<repositoryName>Voile"
      assert body =~ "<protocolVersion>2.0</protocolVersion>"
      assert body =~ "<deletedRecord>transient</deletedRecord>"
      assert body =~ "<granularity>YYYY-MM-DDThh:mm:ssZ</granularity>"
    end

    test "returns error with extra arguments", %{conn: conn} do
      conn = get(conn, ~p"/api/oai?verb=Identify&extra=param")

      body = response(conn, 200)
      assert body =~ "<error code=\"badArgument\">"
    end
  end

  describe "ListMetadataFormats verb" do
    test "returns available metadata formats", %{conn: conn} do
      conn = get(conn, ~p"/api/oai?verb=ListMetadataFormats")

      assert response(conn, 200)
      body = response(conn, 200)

      assert body =~ "<ListMetadataFormats>"
      assert body =~ "<metadataPrefix>oai_dc</metadataPrefix>"
      assert body =~ "<schema>http://www.openarchives.org/OAI/2.0/oai_dc.xsd</schema>"

      assert body =~
               "<metadataNamespace>http://www.openarchives.org/OAI/2.0/oai_dc/</metadataNamespace>"
    end

    test "returns formats for specific identifier", %{conn: conn, item1: item1} do
      identifier = "oai:voile.example.com:item:#{item1.id}"
      conn = get(conn, ~p"/api/oai?verb=ListMetadataFormats&identifier=#{identifier}")

      assert response(conn, 200)
      body = response(conn, 200)

      assert body =~ "<ListMetadataFormats>"
      assert body =~ "<metadataPrefix>oai_dc</metadataPrefix>"
    end

    test "returns error for non-existent identifier", %{conn: conn} do
      identifier = "oai:voile.example.com:item:00000000-0000-0000-0000-000000000000"
      conn = get(conn, ~p"/api/oai?verb=ListMetadataFormats&identifier=#{identifier}")

      body = response(conn, 200)
      assert body =~ "<error code=\"idDoesNotExist\">"
    end
  end

  describe "ListSets verb" do
    test "returns published collections as sets", %{conn: conn} do
      conn = get(conn, ~p"/api/oai?verb=ListSets")

      assert response(conn, 200)
      body = response(conn, 200)

      assert body =~ "<ListSets>"
      assert body =~ "<setSpec>collection:TEST001</setSpec>"
      assert body =~ "<setName>Test Collection 1</setName>"
      assert body =~ "<setSpec>collection:TEST002</setSpec>"
      assert body =~ "<setName>Test Collection 2</setName>"
      # Draft collection should not appear
      refute body =~ "DRAFT001"
    end

    test "documents the items and collections setSpec values", %{conn: conn} do
      conn = get(conn, ~p"/api/oai?verb=ListSets")
      body = response(conn, 200)

      assert body =~ "<setSpec>items</setSpec>"
      assert body =~ "<setName>Items (item-level records)</setName>"
      assert body =~ "<setSpec>collections</setSpec>"
      assert body =~ "<setName>Collections (collection-level records)</setName>"
      assert body =~ "items | collections | collection:&lt;COLLECTION_CODE&gt;"
    end
  end

  describe "ListIdentifiers verb" do
    test "returns item identifiers", %{conn: conn, item1: item1, item2: item2} do
      conn = get(conn, ~p"/api/oai?verb=ListIdentifiers&metadataPrefix=oai_dc")

      assert response(conn, 200)
      body = response(conn, 200)

      assert body =~ "<ListIdentifiers>"
      assert body =~ "<header>"
      assert body =~ "<identifier>oai:voile.example.com:item:#{item1.id}</identifier>"
      assert body =~ "<identifier>oai:voile.example.com:item:#{item2.id}</identifier>"
      assert body =~ "<datestamp>"
      assert body =~ "<setSpec>collection:"
    end

    test "returns error without metadataPrefix", %{conn: conn} do
      conn = get(conn, ~p"/api/oai?verb=ListIdentifiers")

      body = response(conn, 200)
      assert body =~ "<error code=\"badArgument\">"
      assert body =~ "Missing required argument: metadataPrefix"
    end

    test "returns error with invalid metadataPrefix", %{conn: conn} do
      conn = get(conn, ~p"/api/oai?verb=ListIdentifiers&metadataPrefix=invalid_format")

      body = response(conn, 200)
      assert body =~ "<error code=\"cannotDisseminateFormat\">"
    end

    test "filters by set", %{conn: conn, item1: item1, item2: item2} do
      conn =
        get(conn, ~p"/api/oai?verb=ListIdentifiers&metadataPrefix=oai_dc&set=collection:TEST001")

      body = response(conn, 200)

      assert body =~ "<identifier>oai:voile.example.com:item:#{item1.id}</identifier>"
      refute body =~ "<identifier>oai:voile.example.com:item:#{item2.id}</identifier>"
    end

    test "accepts set=items (explicit item-level harvesting)", %{conn: conn, item1: item1} do
      conn = get(conn, ~p"/api/oai?verb=ListIdentifiers&metadataPrefix=oai_dc&set=items")

      body = response(conn, 200)
      assert body =~ "<identifier>oai:voile.example.com:item:#{item1.id}</identifier>"
    end

    test "exposes the items setSpec on item headers", %{conn: conn} do
      conn = get(conn, ~p"/api/oai?verb=ListIdentifiers&metadataPrefix=oai_dc")

      body = response(conn, 200)
      assert body =~ "<setSpec>items</setSpec>"
    end

    test "serves collection-level identifiers under set=collections", %{conn: conn} do
      conn = get(conn, ~p"/api/oai?verb=ListIdentifiers&metadataPrefix=oai_dc&set=collections")

      body = response(conn, 200)

      assert body =~
               "<identifier>oai:voile.example.com:collection:TEST001</identifier>"

      assert body =~ "<setSpec>collections</setSpec>"
    end

    test "filters by date range", %{conn: conn} do
      from_date = DateTime.utc_now() |> DateTime.add(-1, :day) |> DateTime.to_iso8601()
      until_date = DateTime.utc_now() |> DateTime.add(1, :day) |> DateTime.to_iso8601()

      conn =
        get(
          conn,
          ~p"/api/oai?verb=ListIdentifiers&metadataPrefix=oai_dc&from=#{from_date}&until=#{until_date}"
        )

      assert response(conn, 200)
      body = response(conn, 200)
      assert body =~ "<ListIdentifiers>"
    end
  end

  describe "ListRecords verb" do
    test "returns full metadata records", %{conn: conn, item1: item1} do
      conn = get(conn, ~p"/api/oai?verb=ListRecords&metadataPrefix=oai_dc")

      assert response(conn, 200)
      body = response(conn, 200)

      assert body =~ "<ListRecords>"
      assert body =~ "<record>"
      assert body =~ "<header>"
      assert body =~ "<identifier>oai:voile.example.com:item:#{item1.id}</identifier>"
      assert body =~ "<metadata>"
      assert body =~ "<oai_dc:dc"
      assert body =~ "<dc:title"
      assert body =~ "<dc:identifier"
    end

    test "returns error without metadataPrefix", %{conn: conn} do
      conn = get(conn, ~p"/api/oai?verb=ListRecords")

      body = response(conn, 200)
      assert body =~ "<error code=\"badArgument\">"
    end

    test "filters by set", %{conn: conn, collection1: collection1} do
      conn = get(conn, ~p"/api/oai?verb=ListRecords&metadataPrefix=oai_dc&set=collection:TEST001")

      body = response(conn, 200)

      assert body =~ "<ListRecords>"
      assert body =~ "<dc:title xmlns=\"#{@dc_ns}\">#{collection1.title}</dc:title>"
    end

    test "emits a clean oai_dc payload: one title, one date, no NULL values, zero-coverage fields mapped",
         %{
           conn: conn,
           collection1: collection1
         } do
      add_collection_field(collection1, "title", "Old Stray Title (re-imported)", "dcterms")
      _stray_null_relation = add_collection_field(collection1, "edition", "NULL", "kandaga_book")
      _kept_relation = add_collection_field(collection1, "edition", "Cet.2", "kandaga_book")
      _date_a = add_collection_field(collection1, "date", "2001", "dcterms")
      _date_b = add_collection_field(collection1, "publishedYear", "2020", "kandaga_book")
      _language = add_collection_field(collection1, "languageType", "id", "kandaga_book")
      add_collection_field(collection1, "creator", "Primary Creator", "dcterms")
      add_collection_field(collection1, "creator", "Additional Creator", "dcterms")

      conn = get(conn, ~p"/api/oai?verb=ListRecords&metadataPrefix=oai_dc&set=collection:TEST001")
      body = response(conn, 200)

      # Single title: the item's own authoritative title, stray re-import titles dropped
      assert body =~ "<dc:title xmlns=\"#{@dc_ns}\">#{collection1.title}</dc:title>"
      refute body =~ "Old Stray Title"
      assert length(Regex.scan(~r/<dc:title[ >]/, body)) == 1

      # Placeholder values never reach the wire
      refute body =~ ">NULL<"
      assert length(Regex.scan(~r/<dc:date[ >]/, body)) == 1

      # Relation keeps meaningful values; the collection link moved to dc:source
      assert body =~ ~r/<dc:relation xmlns="#{@dc_ns}">Cet\.2<\/dc:relation>/
      assert body =~ "<dc:source xmlns=\"#{@dc_ns}\">collection:TEST001</dc:source>"

      # Newly mapped zero-coverage fields
      assert body =~ "<dc:type xmlns=\"#{@dc_ns}\">Book</dc:type>"
      assert body =~ "<dc:rights xmlns=\"#{@dc_ns}\">public</dc:rights>"
      assert body =~ "<dc:language xmlns=\"#{@dc_ns}\">id</dc:language>"
      assert body =~ "<dc:contributor xmlns=\"#{@dc_ns}\">Primary Creator</dc:contributor>"
      assert body =~ "<dc:contributor xmlns=\"#{@dc_ns}\">Additional Creator</dc:contributor>"
    end

    test "continues a list flow with resumptionToken-only requests", %{
      conn: conn,
      collection1: collection1,
      node: node
    } do
      items = insert_list(110, :item, collection_id: collection1.id, unit_id: node.id)

      # Make ordering over updated_at deterministic
      base = DateTime.add(DateTime.utc_now(), -1, :day) |> DateTime.truncate(:second)

      items =
        Enum.with_index(items, 1)
        |> Enum.map(fn {item, i} ->
          from(Item, where: [id: ^item.id])
          |> Repo.update_all(set: [updated_at: DateTime.add(base, i, :minute)])

          %{item | updated_at: DateTime.add(base, i, :minute)}
        end)

      last_item = Enum.at(items, -1)

      # Page 1
      conn = get(conn, ~p"/api/oai?verb=ListRecords&metadataPrefix=oai_dc")
      body = response(conn, 200)
      assert body =~ "<ListRecords>"
      token = extract_resumption_token!(body)
      assert token

      # Page 2: resumptionToken must be the ONLY argument besides verb
      conn2 =
        get(
          build_conn(),
          ~p"/api/oai?verb=ListRecords&resumptionToken=#{URI.encode_www_form(token)}"
        )

      body2 = response(conn2, 200)

      assert body2 =~ "<ListRecords>"
      assert body2 =~ "cursor=\"1\""
      refute body2 =~ "<error"

      # Page 3: final page has no more records; legacy harvesters also resend
      # metadataPrefix together with the token, which must keep working
      token2 = extract_resumption_token!(body2)
      assert token2

      conn3 =
        get(
          build_conn(),
          ~p"/api/oai?verb=ListRecords&metadataPrefix=oai_dc&resumptionToken=#{URI.encode_www_form(token2)}"
        )

      body3 = response(conn3, 200)

      assert body3 =~ "<ListRecords>"
      refute body3 =~ "<resumptionToken "
      assert body3 =~ last_item.item_code
    end

    test "harvests collection-level records under set=collections", %{conn: conn} do
      conn = get(conn, ~p"/api/oai?verb=ListRecords&metadataPrefix=oai_dc&set=collections")
      body = response(conn, 200)

      assert body =~ "<identifier>oai:voile.example.com:collection:TEST001</identifier>"
      assert body =~ "<setSpec>collections</setSpec>"
      assert body =~ "<dc:title xmlns=\"#{@dc_ns}\">Test Collection 1</dc:title>"
      assert body =~ "<dc:rights xmlns=\"#{@dc_ns}\">public</dc:rights>"
      refute body =~ "<error"
    end
  end

  describe "GetRecord verb" do
    test "returns single record by identifier", %{
      conn: conn,
      item1: item1,
      collection1: collection1
    } do
      identifier = "oai:voile.example.com:item:#{item1.id}"

      conn =
        get(conn, ~p"/api/oai?verb=GetRecord&identifier=#{identifier}&metadataPrefix=oai_dc")

      assert response(conn, 200)
      body = response(conn, 200)

      assert body =~ "<GetRecord>"
      assert body =~ "<record>"
      assert body =~ "<identifier>#{identifier}</identifier>"
      assert body =~ "<metadata>"
      assert body =~ "<dc:title xmlns=\"#{@dc_ns}\">#{collection1.title}</dc:title>"
      assert body =~ "<dc:identifier xmlns=\"#{@dc_ns}\">#{item1.item_code}</dc:identifier>"
    end

    test "returns error without identifier", %{conn: conn} do
      conn = get(conn, ~p"/api/oai?verb=GetRecord&metadataPrefix=oai_dc")

      body = response(conn, 200)
      assert body =~ "<error code=\"badArgument\">"
      assert body =~ "Missing required argument: identifier"
    end

    test "returns error without metadataPrefix", %{conn: conn, item1: item1} do
      identifier = "oai:voile.example.com:item:#{item1.id}"
      conn = get(conn, ~p"/api/oai?verb=GetRecord&identifier=#{identifier}")

      body = response(conn, 200)
      assert body =~ "<error code=\"badArgument\">"
      assert body =~ "Missing required argument: metadataPrefix"
    end

    test "returns error for non-existent identifier", %{conn: conn} do
      identifier = "oai:voile.example.com:item:00000000-0000-0000-0000-000000000000"

      conn =
        get(conn, ~p"/api/oai?verb=GetRecord&identifier=#{identifier}&metadataPrefix=oai_dc")

      body = response(conn, 200)
      assert body =~ "<error code=\"idDoesNotExist\">"
    end

    test "returns a collection-level record for collection identifiers", %{conn: conn} do
      identifier = "oai:voile.example.com:collection:TEST001"

      conn =
        get(conn, ~p"/api/oai?verb=GetRecord&identifier=#{identifier}&metadataPrefix=oai_dc")

      body = response(conn, 200)

      assert body =~ "<GetRecord>"
      assert body =~ "<identifier>#{identifier}</identifier>"
      assert body =~ "<setSpec>collections</setSpec>"
      assert body =~ "<dc:title xmlns=\"#{@dc_ns}\">Test Collection 1</dc:title>"
      assert body =~ "<dc:description xmlns=\"#{@dc_ns}\">First test collection</dc:description>"
      assert body =~ "<dc:rights xmlns=\"#{@dc_ns}\">public</dc:rights>"
    end

    test "returns error for unknown collection identifier", %{conn: conn} do
      identifier = "oai:voile.example.com:collection:UNKNOWN"

      conn =
        get(conn, ~p"/api/oai?verb=GetRecord&identifier=#{identifier}&metadataPrefix=oai_dc")

      body = response(conn, 200)
      assert body =~ "<error code=\"idDoesNotExist\">"
    end
  end

  describe "error handling" do
    test "returns error for missing verb", %{conn: conn} do
      conn = get(conn, ~p"/api/oai")

      body = response(conn, 200)
      assert body =~ "<error code=\"badVerb\">"
      assert body =~ "Missing verb argument"
    end

    test "returns error for invalid verb", %{conn: conn} do
      conn = get(conn, ~p"/api/oai?verb=InvalidVerb")

      body = response(conn, 200)
      assert body =~ "<error code=\"badVerb\">"
      assert body =~ "not a legal OAI-PMH verb"
    end
  end

  describe "POST method" do
    test "handles POST requests", %{conn: conn} do
      conn = post(conn, ~p"/api/oai", %{verb: "Identify"})

      assert response(conn, 200)
      body = response(conn, 200)
      assert body =~ "<Identify>"
    end

    test "handles ListRecords via POST", %{conn: conn} do
      conn = post(conn, ~p"/api/oai", %{verb: "ListRecords", metadataPrefix: "oai_dc"})

      assert response(conn, 200)
      body = response(conn, 200)
      assert body =~ "<ListRecords>"
    end
  end

  defp extract_resumption_token!(body) do
    case Regex.run(~r|<resumptionToken[^>]*>([^<]+)</resumptionToken>|, body) do
      [_, token] -> token
      _ -> nil
    end
  end

  defp add_collection_field(collection, local_name, value, vocab_prefix) do
    vocabulary = Voile.MetadataFixtures.vocabulary_fixture(prefix: vocab_prefix)

    property =
      Voile.SchemaMetadataFixtures.property_fixture(
        local_name: local_name,
        vocabulary_id: vocabulary.id
      )

    {:ok, _field} =
      Voile.Schema.Catalog.create_collection_field(%{
        collection_id: collection.id,
        property_id: property.id,
        name: local_name,
        label: local_name,
        value: value,
        value_lang: "en",
        sort_order: 1,
        type_value: "text"
      })
  end
end
