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

  def index(conn, _params) do
    resource_template_property = Metadata.list_resource_template_property()
    render(conn, :index, resource_template_property_collection: resource_template_property)
  end

  def new(conn, _params) do
    changeset = Metadata.change_resource_template_property(%ResourceTemplateProperty{})
    render(conn, :new, changeset: changeset)
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
    render(conn, :show, resource_template_property: resource_template_property)
  end

  def edit(conn, %{"id" => id}) do
    resource_template_property = Metadata.get_resource_template_property!(id)
    changeset = Metadata.change_resource_template_property(resource_template_property)

    render(conn, :edit,
      resource_template_property: resource_template_property,
      changeset: changeset
    )
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
