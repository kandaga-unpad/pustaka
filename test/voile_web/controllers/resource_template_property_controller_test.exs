defmodule VoileWeb.ResourceTemplatePropertyControllerTest do
  use VoileWeb.ConnCase

  import Voile.MetadataFixtures

  @create_attrs %{position: 42, data_type: ["option1", "option2"], alternate_label: "some alternate_label", alternate_information: "some alternate_information", is_required: true, permission: "some permission"}
  @update_attrs %{position: 43, data_type: ["option1"], alternate_label: "some updated alternate_label", alternate_information: "some updated alternate_information", is_required: false, permission: "some updated permission"}
  @invalid_attrs %{position: nil, data_type: nil, alternate_label: nil, alternate_information: nil, is_required: nil, permission: nil}

  describe "index" do
    test "lists all resource_template_property", %{conn: conn} do
      conn = get(conn, ~p"/resource_template_property")
      assert html_response(conn, 200) =~ "Listing Resource template property"
    end
  end

  describe "new resource_template_property" do
    test "renders form", %{conn: conn} do
      conn = get(conn, ~p"/resource_template_property/new")
      assert html_response(conn, 200) =~ "New Resource template property"
    end
  end

  describe "create resource_template_property" do
    test "redirects to show when data is valid", %{conn: conn} do
      conn = post(conn, ~p"/resource_template_property", resource_template_property: @create_attrs)

      assert %{id: id} = redirected_params(conn)
      assert redirected_to(conn) == ~p"/resource_template_property/#{id}"

      conn = get(conn, ~p"/resource_template_property/#{id}")
      assert html_response(conn, 200) =~ "Resource template property #{id}"
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, ~p"/resource_template_property", resource_template_property: @invalid_attrs)
      assert html_response(conn, 200) =~ "New Resource template property"
    end
  end

  describe "edit resource_template_property" do
    setup [:create_resource_template_property]

    test "renders form for editing chosen resource_template_property", %{conn: conn, resource_template_property: resource_template_property} do
      conn = get(conn, ~p"/resource_template_property/#{resource_template_property}/edit")
      assert html_response(conn, 200) =~ "Edit Resource template property"
    end
  end

  describe "update resource_template_property" do
    setup [:create_resource_template_property]

    test "redirects when data is valid", %{conn: conn, resource_template_property: resource_template_property} do
      conn = put(conn, ~p"/resource_template_property/#{resource_template_property}", resource_template_property: @update_attrs)
      assert redirected_to(conn) == ~p"/resource_template_property/#{resource_template_property}"

      conn = get(conn, ~p"/resource_template_property/#{resource_template_property}")
      assert html_response(conn, 200) =~ "some updated alternate_label"
    end

    test "renders errors when data is invalid", %{conn: conn, resource_template_property: resource_template_property} do
      conn = put(conn, ~p"/resource_template_property/#{resource_template_property}", resource_template_property: @invalid_attrs)
      assert html_response(conn, 200) =~ "Edit Resource template property"
    end
  end

  describe "delete resource_template_property" do
    setup [:create_resource_template_property]

    test "deletes chosen resource_template_property", %{conn: conn, resource_template_property: resource_template_property} do
      conn = delete(conn, ~p"/resource_template_property/#{resource_template_property}")
      assert redirected_to(conn) == ~p"/resource_template_property"

      assert_error_sent 404, fn ->
        get(conn, ~p"/resource_template_property/#{resource_template_property}")
      end
    end
  end

  defp create_resource_template_property(_) do
    resource_template_property = resource_template_property_fixture()
    %{resource_template_property: resource_template_property}
  end
end
