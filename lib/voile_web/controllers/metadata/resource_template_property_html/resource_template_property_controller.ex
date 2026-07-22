defmodule VoileWeb.ResourceTemplatePropertyController do
  use VoileWeb, :controller_dashboard

  alias Voile.Schema.Metadata
  alias Voile.Schema.Metadata.ResourceTemplateProperty

  plug VoileWeb.Plugs.Authorize,
    permissions: %{
      new: ["metadata.manage"],
      create: ["metadata.manage"],
      edit: ["metadata.manage", "metadata.edit"],
      update: ["metadata.manage", "metadata.edit"],
      delete: ["metadata.manage"]
    }

  defp breadcrumb(last) do
    [
      %{label: gettext("Manage"), path: "/manage"},
      %{label: gettext("Metaresource"), path: "/manage/metaresource"},
      %{
        label: gettext("Template property"),
        path: "/manage/metaresource/resource_templ_property"
      },
      %{label: last, path: nil}
    ]
  end

  def index(conn, params) do
    page = Voile.Utils.Pagination.parse_page(Map.get(params, "page"))
    per_page = 10

    {resource_template_property, total_pages, _} =
      Metadata.list_metadata_page(:resource_template_property, page, per_page)

    conn
    |> assign(:breadcrumb, breadcrumb(gettext("All")))
    |> assign(:resource_template_property_collection, resource_template_property)
    |> assign(:page, page)
    |> assign(:total_pages, total_pages)
    |> render(:index)
  end

  def new(conn, _params) do
    changeset = Metadata.change_resource_template_property(%ResourceTemplateProperty{})

    conn
    |> assign(:breadcrumb, breadcrumb(gettext("New")))
    |> assign(:changeset, changeset)
    |> render(:new)
  end

  def create(conn, %{"resource_template_property" => resource_template_property_params}) do
    case Metadata.create_resource_template_property(resource_template_property_params) do
      {:ok, resource_template_property} ->
        conn
        |> put_flash(:info, "Resource template property created successfully.")
        |> redirect(
          to: ~p"/manage/metaresource/resource_templ_property/#{resource_template_property}"
        )

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :new, changeset: changeset)
    end
  end

  def show(conn, %{"id" => id}) do
    resource_template_property = Metadata.get_resource_template_property!(id)

    conn
    |> assign(:breadcrumb, breadcrumb(gettext("Show")))
    |> assign(:resource_template_property, resource_template_property)
    |> render(:show)
  end

  def edit(conn, %{"id" => id}) do
    resource_template_property = Metadata.get_resource_template_property!(id)
    changeset = Metadata.change_resource_template_property(resource_template_property)

    conn
    |> assign(:breadcrumb, breadcrumb(gettext("Edit")))
    |> assign(:resource_template_property, resource_template_property)
    |> assign(:changeset, changeset)
    |> render(:edit)
  end

  def update(conn, %{
        "id" => id,
        "resource_template_property" => resource_template_property_params
      }) do
    resource_template_property = Metadata.get_resource_template_property!(id)

    case Metadata.update_resource_template_property(
           resource_template_property,
           resource_template_property_params
         ) do
      {:ok, resource_template_property} ->
        conn
        |> put_flash(:info, "Resource template property updated successfully.")
        |> redirect(
          to: ~p"/manage/metaresource/resource_templ_property/#{resource_template_property}"
        )

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :edit,
          resource_template_property: resource_template_property,
          changeset: changeset
        )
    end
  end

  def delete(conn, %{"id" => id}) do
    resource_template_property = Metadata.get_resource_template_property!(id)

    {:ok, _resource_template_property} =
      Metadata.delete_resource_template_property(resource_template_property)

    conn
    |> put_flash(:info, "Resource template property deleted successfully.")
    |> redirect(to: ~p"/manage/metaresource/resource_templ_property")
  end
end
