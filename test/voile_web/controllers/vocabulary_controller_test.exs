defmodule VoileWeb.VocabularyControllerTest do
  use VoileWeb.ConnCase

  import Voile.MetadataFixtures

  @create_attrs %{label: "some label", prefix: "some prefix", namespace_url: "some namespace_url", information: "some information"}
  @update_attrs %{label: "some updated label", prefix: "some updated prefix", namespace_url: "some updated namespace_url", information: "some updated information"}
  @invalid_attrs %{label: nil, prefix: nil, namespace_url: nil, information: nil}

  describe "index" do
    test "lists all metadata_vocabularies", %{conn: conn} do
      conn = get(conn, ~p"/metadata_vocabularies")
      assert html_response(conn, 200) =~ "Listing Metadata vocabularies"
    end
  end

  describe "new vocabulary" do
    test "renders form", %{conn: conn} do
      conn = get(conn, ~p"/metadata_vocabularies/new")
      assert html_response(conn, 200) =~ "New Vocabulary"
    end
  end

  describe "create vocabulary" do
    test "redirects to show when data is valid", %{conn: conn} do
      conn = post(conn, ~p"/metadata_vocabularies", vocabulary: @create_attrs)

      assert %{id: id} = redirected_params(conn)
      assert redirected_to(conn) == ~p"/metadata_vocabularies/#{id}"

      conn = get(conn, ~p"/metadata_vocabularies/#{id}")
      assert html_response(conn, 200) =~ "Vocabulary #{id}"
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, ~p"/metadata_vocabularies", vocabulary: @invalid_attrs)
      assert html_response(conn, 200) =~ "New Vocabulary"
    end
  end

  describe "edit vocabulary" do
    setup [:create_vocabulary]

    test "renders form for editing chosen vocabulary", %{conn: conn, vocabulary: vocabulary} do
      conn = get(conn, ~p"/metadata_vocabularies/#{vocabulary}/edit")
      assert html_response(conn, 200) =~ "Edit Vocabulary"
    end
  end

  describe "update vocabulary" do
    setup [:create_vocabulary]

    test "redirects when data is valid", %{conn: conn, vocabulary: vocabulary} do
      conn = put(conn, ~p"/metadata_vocabularies/#{vocabulary}", vocabulary: @update_attrs)
      assert redirected_to(conn) == ~p"/metadata_vocabularies/#{vocabulary}"

      conn = get(conn, ~p"/metadata_vocabularies/#{vocabulary}")
      assert html_response(conn, 200) =~ "some updated label"
    end

    test "renders errors when data is invalid", %{conn: conn, vocabulary: vocabulary} do
      conn = put(conn, ~p"/metadata_vocabularies/#{vocabulary}", vocabulary: @invalid_attrs)
      assert html_response(conn, 200) =~ "Edit Vocabulary"
    end
  end

  describe "delete vocabulary" do
    setup [:create_vocabulary]

    test "deletes chosen vocabulary", %{conn: conn, vocabulary: vocabulary} do
      conn = delete(conn, ~p"/metadata_vocabularies/#{vocabulary}")
      assert redirected_to(conn) == ~p"/metadata_vocabularies"

      assert_error_sent 404, fn ->
        get(conn, ~p"/metadata_vocabularies/#{vocabulary}")
      end
    end
  end

  defp create_vocabulary(_) do
    vocabulary = vocabulary_fixture()
    %{vocabulary: vocabulary}
  end
end
