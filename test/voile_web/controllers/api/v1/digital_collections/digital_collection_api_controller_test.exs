defmodule VoileWeb.API.V1.DigitalCollections.DigitalCollectionApiControllerTest do
  # async: false — the tests share the API rate limiter (ETS counters keyed by
  # IP) and assert on exact result sets, so parallel runs would interfere.
  use VoileWeb.ConnCase, async: false

  import Voile.AccountsFixtures
  import Voile.CatalogFixtures
  import Voile.Factory
  import Voile.SystemFixtures
  import Ecto.Query

  alias Voile.Repo
  alias Voile.Schema.System

  setup do
    user = user_fixture()

    {:ok, _token, plain_token} =
      System.create_api_token(user, %{"name" => "digital-collections-test", "scopes" => ["read"]})

    conn = put_req_header(build_conn(), "authorization", "Bearer #{plain_token}")

    %{conn: conn}
  end

  describe "GET /api/v1/digital-collections" do
    test "lists published collections that carry document attachments", %{conn: conn} do
      {collection, attachment} = create_digital_collection()
      # Noise that must NOT be listed: a draft with an attachment and a
      # published collection whose only attachment is an image.
      create_digital_collection(%{status: "draft"})
      create_digital_collection(%{attachment_file_type: "image"})

      conn = get(conn, ~p"/api/v1/digital-collections")

      assert %{"data" => data, "pagination" => pagination} = json_response(conn, 200)
      assert is_map(pagination)
      assert pagination["page_size"] > 0

      titles = Enum.map(data, & &1["title"])
      assert collection.title in titles

      listed = Enum.find(data, &(&1["id"] == collection.id))
      assert listed["attachments_count"] >= 1
      assert listed["primary_attachment"]["id"] == attachment.id
      assert listed["primary_attachment"]["reader_url"] == "/ebooks/view?id=#{attachment.id}"

      assert listed["primary_attachment"]["download_url"] ==
               "/attachments/#{attachment.id}/download"
    end

    test "searches by title", %{conn: conn} do
      title = unique_title()
      {collection, _attachment} = create_digital_collection(%{title: title})
      create_digital_collection()

      conn = get(conn, ~p"/api/v1/digital-collections?search=#{title}")

      assert %{"data" => [%{"id" => id}]} = json_response(conn, 200)
      assert id == collection.id
    end

    test "filters by unit_id", %{conn: conn} do
      node = node_fixture()
      {collection, _attachment} = create_digital_collection(%{unit_id: node.id})
      create_digital_collection()

      conn = get(conn, ~p"/api/v1/digital-collections?unit_id=#{node.id}")

      assert %{"data" => [%{"id" => id, "unit" => %{"id" => unit_id}}]} = json_response(conn, 200)
      assert id == collection.id
      assert unit_id == node.id
    end

    test "file_type=all includes collections that only carry non-document files", %{conn: conn} do
      {collection, _attachment} = create_digital_collection(%{attachment_file_type: "image"})

      conn = get(conn, ~p"/api/v1/digital-collections?file_type=all")

      assert %{"data" => data} = json_response(conn, 200)
      assert Enum.any?(data, &(&1["id"] == collection.id))
    end

    test "excludes embargoed attachments from the list", %{conn: conn} do
      {collection, _attachment} = create_digital_collection()

      # A second, currently-embargoed document does not change the count
      embargoed_until =
        DateTime.add(DateTime.utc_now(), -86_400, :second) |> DateTime.truncate(:second)

      insert(:attachment, %{
        attachable_id: collection.id,
        attachable_type: "collection",
        file_name: "embargoed.pdf",
        embargo_end_date: embargoed_until
      })

      conn = get(conn, ~p"/api/v1/digital-collections?search=#{collection.title}")

      assert %{"data" => [%{"attachments_count" => 1}]} = json_response(conn, 200)
    end
  end

  describe "GET /api/v1/digital-collections/:id" do
    test "returns the collection with full attachments and metadata", %{conn: conn} do
      {collection, attachment} = create_digital_collection()

      conn = get(conn, ~p"/api/v1/digital-collections/#{collection.id}")

      assert %{"data" => data} = json_response(conn, 200)
      assert data["id"] == collection.id
      assert data["status"] == "published"
      assert [%{"id" => attachment_id}] = data["attachments"]
      assert attachment_id == attachment.id
      assert data["attachments_count"] == 1
      assert data["primary_attachment"]["reader_url"] == "/ebooks/view?id=#{attachment.id}"
      assert is_list(data["metadata"])
      assert data["collection_url"] == "/collections/#{collection.id}"
    end

    test "returns 404 for an unknown id", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/digital-collections/#{Ecto.UUID.generate()}")

      assert conn.status == 404
    end

    test "returns 404 for an unpublished collection", %{conn: conn} do
      {collection, _attachment} = create_digital_collection(%{status: "draft"})

      conn = get(conn, ~p"/api/v1/digital-collections/#{collection.id}")

      assert conn.status == 404
    end

    test "returns 404 for a collection without document attachments", %{conn: conn} do
      collection = collection_fixture(%{status: "published"})

      insert(:attachment, %{
        attachable_id: collection.id,
        attachable_type: "collection",
        file_type: "image",
        mime_type: "image/jpeg",
        file_name: "cover.jpg",
        original_name: "cover.jpg"
      })

      conn = get(conn, ~p"/api/v1/digital-collections/#{collection.id}")

      assert conn.status == 404
    end
  end

  # -- Fixtures -------------------------------------------------------------

  defp unique_title, do: "Ebook Digital #{Elixir.System.unique_integer([:positive])}"

  defp create_digital_collection(attrs \\ %{}) do
    # Keyword.split/2 returns {taken, rest} — the attachment file type is the
    # "taken" side; everything else belongs to the collection fixture.
    {attachment_attrs, collection_attrs} =
      Keyword.split(Enum.to_list(attrs), [:attachment_file_type])

    attachment_file_type = Keyword.get(attachment_attrs, :attachment_file_type, "document")

    collection =
      collection_fixture(
        %{status: "published", title: unique_title()}
        |> Map.merge(Map.new(collection_attrs))
      )

    attachment =
      insert(:attachment, %{
        attachable_id: collection.id,
        attachable_type: "collection",
        is_primary: true,
        file_type: attachment_file_type,
        mime_type: "application/pdf"
      })

    {collection, attachment}
  end
end
