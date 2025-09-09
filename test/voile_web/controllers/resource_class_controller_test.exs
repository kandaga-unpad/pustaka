defmodule VoileWeb.ResourceClassControllerTest do
  use VoileWeb.ConnCase

  import Voile.MetadataFixtures

  @create_attrs %{label: "some label", local_name: "some local_name", information: "some information"}
  @update_attrs %{label: "some updated label", local_name: "some updated local_name", information: "some updated information"}
  @invalid_attrs %{label: nil, local_name: nil, information: nil}

  describe "index" do
    test "lists all resource_class", %{conn: conn} do
      conn = get(conn, ~p"/resource_class")
      assert html_response(conn, 200) =~ "Listing Resource class"
    end
  end

  describe "new resource_class" do
    test "renders form", %{conn: conn} do
      conn = get(conn, ~p"/resource_class/new")
      assert html_response(conn, 200) =~ "New Resource class"
    end
  end

  describe "create resource_class" do
    test "redirects to show when data is valid", %{conn: conn} do
      conn = post(conn, ~p"/resource_class", resource_class: @create_attrs)

      assert %{id: id} = redirected_params(conn)
      assert redirected_to(conn) == ~p"/resource_class/#{id}"

      conn = get(conn, ~p"/resource_class/#{id}")
      assert html_response(conn, 200) =~ "Resource class #{id}"
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, ~p"/resource_class", resource_class: @invalid_attrs)
      assert html_response(conn, 200) =~ "New Resource class"
    end
  end

  describe "edit resource_class" do
    setup [:create_resource_class]

    test "renders form for editing chosen resource_class", %{conn: conn, resource_class: resource_class} do
      conn = get(conn, ~p"/resource_class/#{resource_class}/edit")
      assert html_response(conn, 200) =~ "Edit Resource class"
    end
  end

  describe "update resource_class" do
    setup [:create_resource_class]

    test "redirects when data is valid", %{conn: conn, resource_class: resource_class} do
      conn = put(conn, ~p"/resource_class/#{resource_class}", resource_class: @update_attrs)
      assert redirected_to(conn) == ~p"/resource_class/#{resource_class}"

      conn = get(conn, ~p"/resource_class/#{resource_class}")
      assert html_response(conn, 200) =~ "some updated label"
    end

    test "renders errors when data is invalid", %{conn: conn, resource_class: resource_class} do
      conn = put(conn, ~p"/resource_class/#{resource_class}", resource_class: @invalid_attrs)
      assert html_response(conn, 200) =~ "Edit Resource class"
    end
  end

  describe "delete resource_class" do
    setup [:create_resource_class]

    test "deletes chosen resource_class", %{conn: conn, resource_class: resource_class} do
      conn = delete(conn, ~p"/resource_class/#{resource_class}")
      assert redirected_to(conn) == ~p"/resource_class"

      assert_error_sent 404, fn ->
        get(conn, ~p"/resource_class/#{resource_class}")
      end
    end
  end

  defp create_resource_class(_) do
    resource_class = resource_class_fixture()
    %{resource_class: resource_class}
  end
end
