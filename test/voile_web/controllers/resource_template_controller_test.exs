defmodule VoileWeb.ResourceTemplateControllerTest do
  use VoileWeb.ConnCase

  import Voile.MetadataFixtures

  @create_attrs %{label: "some label"}
  @update_attrs %{label: "some updated label"}
  @invalid_attrs %{label: nil}

  describe "index" do
    test "lists all resource_template", %{conn: conn} do
      conn = get(conn, ~p"/resource_template")
      assert html_response(conn, 200) =~ "Listing Resource template"
    end
  end

  describe "new resource_template" do
    test "renders form", %{conn: conn} do
      conn = get(conn, ~p"/resource_template/new")
      assert html_response(conn, 200) =~ "New Resource template"
    end
  end

  describe "create resource_template" do
    test "redirects to show when data is valid", %{conn: conn} do
      conn = post(conn, ~p"/resource_template", resource_template: @create_attrs)

      assert %{id: id} = redirected_params(conn)
      assert redirected_to(conn) == ~p"/resource_template/#{id}"

      conn = get(conn, ~p"/resource_template/#{id}")
      assert html_response(conn, 200) =~ "Resource template #{id}"
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, ~p"/resource_template", resource_template: @invalid_attrs)
      assert html_response(conn, 200) =~ "New Resource template"
    end
  end

  describe "edit resource_template" do
    setup [:create_resource_template]

    test "renders form for editing chosen resource_template", %{conn: conn, resource_template: resource_template} do
      conn = get(conn, ~p"/resource_template/#{resource_template}/edit")
      assert html_response(conn, 200) =~ "Edit Resource template"
    end
  end

  describe "update resource_template" do
    setup [:create_resource_template]

    test "redirects when data is valid", %{conn: conn, resource_template: resource_template} do
      conn = put(conn, ~p"/resource_template/#{resource_template}", resource_template: @update_attrs)
      assert redirected_to(conn) == ~p"/resource_template/#{resource_template}"

      conn = get(conn, ~p"/resource_template/#{resource_template}")
      assert html_response(conn, 200) =~ "some updated label"
    end

    test "renders errors when data is invalid", %{conn: conn, resource_template: resource_template} do
      conn = put(conn, ~p"/resource_template/#{resource_template}", resource_template: @invalid_attrs)
      assert html_response(conn, 200) =~ "Edit Resource template"
    end
  end

  describe "delete resource_template" do
    setup [:create_resource_template]

    test "deletes chosen resource_template", %{conn: conn, resource_template: resource_template} do
      conn = delete(conn, ~p"/resource_template/#{resource_template}")
      assert redirected_to(conn) == ~p"/resource_template"

      assert_error_sent 404, fn ->
        get(conn, ~p"/resource_template/#{resource_template}")
      end
    end
  end

  defp create_resource_template(_) do
    resource_template = resource_template_fixture()
    %{resource_template: resource_template}
  end
end
