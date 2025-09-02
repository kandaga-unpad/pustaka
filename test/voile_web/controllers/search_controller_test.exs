defmodule VoileWeb.SearchControllerTest do
  use VoileWeb.ConnCase

  describe "GET /search" do
    test "renders search page", %{conn: conn} do
      conn = get(conn, ~p"/search")
      assert html_response(conn, 200) =~ "Search Library Catalog"
    end

    test "performs search with query parameter", %{conn: conn} do
      conn = get(conn, ~p"/search?q=science")
      assert html_response(conn, 200) =~ "science"
    end

    test "handles different search types", %{conn: conn} do
      conn = get(conn, ~p"/search?q=test&type=collections")
      assert html_response(conn, 200) =~ "test"

      conn = get(conn, ~p"/search?q=test&type=items")
      assert html_response(conn, 200) =~ "test"
    end
  end

  describe "GET /search/advanced" do
    test "renders advanced search page", %{conn: conn} do
      conn = get(conn, ~p"/search/advanced")
      assert html_response(conn, 200) =~ "Advanced Search"
    end

    test "processes advanced search parameters", %{conn: conn} do
      search_params = %{
        "search" => %{
          "title" => "science",
          "creator" => "author"
        },
        "type" => "collections"
      }

      conn = get(conn, ~p"/search/advanced", search_params)
      assert html_response(conn, 200) =~ "Advanced Search"
    end
  end

  describe "GET /search/suggestions" do
    test "returns JSON suggestions for valid query", %{conn: conn} do
      conn = get(conn, ~p"/search/suggestions?q=te")
      assert json_response(conn, 200)["suggestions"]
    end

    test "returns empty suggestions for short query", %{conn: conn} do
      conn = get(conn, ~p"/search/suggestions?q=t")
      assert json_response(conn, 200)["suggestions"] == []
    end
  end

  describe "GET /api/search" do
    test "returns JSON search results", %{conn: conn} do
      conn = get(conn, ~p"/api/search?q=test")
      response = json_response(conn, 200)

      assert response["success"]
      assert Map.has_key?(response, "results")
      assert response["query"] == "test"
    end

    test "handles different search types in API", %{conn: conn} do
      conn = get(conn, ~p"/api/search?q=test&type=collections")
      response = json_response(conn, 200)

      assert response["search_type"] == "collections"
    end
  end
end
