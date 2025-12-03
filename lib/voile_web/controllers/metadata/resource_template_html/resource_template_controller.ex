defmodule VoileWeb.ResourceTemplateController do
  use VoileWeb, :controller_dashboard

  alias Voile.Schema.Metadata

  plug VoileWeb.Plugs.Authorize,
    permissions: %{
      delete: ["metadata.manage"]
    }

  def index(conn, _params) do
    page = Map.get(conn.params, "page", "1") |> String.to_integer()
    per_page = 10

    {resource_template_collection, total_pages, _} =
      Metadata.list_resource_templates_paginated(page, per_page)

    conn
    |> assign(:resource_template_collection, resource_template_collection)
    |> assign(:page, page)
    |> assign(:total_pages, total_pages)
    |> render(:index)
  end

  def show(conn, %{"id" => id}) do
    resource_class = Metadata.list_resource_class()
    resource_template = Metadata.get_resource_template!(id)

    conn
    |> assign(:resource_class, resource_class)
    |> assign(:resource_template, resource_template)
    |> render(:show)
  end

  def delete(conn, %{"id" => id}) do
    resource_template = Metadata.get_resource_template!(id)
    {:ok, _resource_template} = Metadata.delete_resource_template(resource_template)

    conn
    |> put_flash(:info, "Resource template deleted successfully.")
    |> redirect(to: ~p"/manage/metaresource/resource_template")
  end
end
