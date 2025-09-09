defmodule VoileWeb.PropertyControllerTest do
  use VoileWeb.ConnCase

  import Voile.SchemaMetadataFixtures

  @create_attrs %{label: "some label", local_name: "some local_name", information: "some information"}
  @update_attrs %{label: "some updated label", local_name: "some updated local_name", information: "some updated information"}
  @invalid_attrs %{label: nil, local_name: nil, information: nil}

  describe "index" do
    test "lists all metadata_properties", %{conn: conn} do
      conn = get(conn, ~p"/metadata_properties")
      assert html_response(conn, 200) =~ "Listing Metadata properties"
    end
  end

  describe "new property" do
    test "renders form", %{conn: conn} do
      conn = get(conn, ~p"/metadata_properties/new")
      assert html_response(conn, 200) =~ "New Property"
    end
  end

  describe "create property" do
    test "redirects to show when data is valid", %{conn: conn} do
      conn = post(conn, ~p"/metadata_properties", property: @create_attrs)

      assert %{id: id} = redirected_params(conn)
      assert redirected_to(conn) == ~p"/metadata_properties/#{id}"

      conn = get(conn, ~p"/metadata_properties/#{id}")
      assert html_response(conn, 200) =~ "Property #{id}"
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, ~p"/metadata_properties", property: @invalid_attrs)
      assert html_response(conn, 200) =~ "New Property"
    end
  end

  describe "edit property" do
    setup [:create_property]

    test "renders form for editing chosen property", %{conn: conn, property: property} do
      conn = get(conn, ~p"/metadata_properties/#{property}/edit")
      assert html_response(conn, 200) =~ "Edit Property"
    end
  end

  describe "update property" do
    setup [:create_property]

    test "redirects when data is valid", %{conn: conn, property: property} do
      conn = put(conn, ~p"/metadata_properties/#{property}", property: @update_attrs)
      assert redirected_to(conn) == ~p"/metadata_properties/#{property}"

      conn = get(conn, ~p"/metadata_properties/#{property}")
      assert html_response(conn, 200) =~ "some updated label"
    end

    test "renders errors when data is invalid", %{conn: conn, property: property} do
      conn = put(conn, ~p"/metadata_properties/#{property}", property: @invalid_attrs)
      assert html_response(conn, 200) =~ "Edit Property"
    end
  end

  describe "delete property" do
    setup [:create_property]

    test "deletes chosen property", %{conn: conn, property: property} do
      conn = delete(conn, ~p"/metadata_properties/#{property}")
      assert redirected_to(conn) == ~p"/metadata_properties"

      assert_error_sent 404, fn ->
        get(conn, ~p"/metadata_properties/#{property}")
      end
    end
  end

  defp create_property(_) do
    property = property_fixture()
    %{property: property}
  end
end
