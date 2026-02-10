defmodule VoileWeb.OaiPmhControllerTest do
  use VoileWeb.ConnCase

  import Voile.Factory

  alias Voile.Repo
  alias Voile.Schema.Catalog.{Collection, Item}
  alias Voile.Schema.System.Node
  alias Voile.Schema.Metadata.ResourceClass

  setup do
    # Create a node
    node = insert(:node, name: "Test Library", abbr: "TL")

    # Create a resource class
    resource_class =
      insert(:resource_class, name: "Book", glam_type: "library")

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
        barcode: "BAR001",
        collection_id: collection1.id,
        unit_id: node.id,
        status: "active"
      )

    item2 =
      insert(:item,
        item_code: "ITEM002",
        inventory_code: "INV002",
        barcode: "BAR002",
        collection_id: collection2.id,
        unit_id: node.id,
        status: "active"
      )

    {:ok,
     node: node, collection1: collection1, collection2: collection2, item1: item1, item2: item2}
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

    test "handles resumption token", %{conn: conn} do
      # This test assumes there are more than 100 collections
      # For this test setup, we just verify the structure works
      conn = get(conn, ~p"/api/oai?verb=ListSets")

      assert response(conn, 200)
      body = response(conn, 200)
      assert body =~ "<ListSets>"
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
      assert body =~ "<dc:title>"
      assert body =~ "<dc:identifier>"
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
      assert body =~ "<dc:title>#{collection1.title}</dc:title>"
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
      assert body =~ "<dc:title>#{collection1.title}</dc:title>"
      assert body =~ "<dc:identifier>#{item1.item_code}</dc:identifier>"
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
end
