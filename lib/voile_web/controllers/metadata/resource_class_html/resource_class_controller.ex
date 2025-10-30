defmodule VoileWeb.ResourceClassController do
  use VoileWeb, :controller_dashboard

  alias Voile.Schema.Metadata
  alias Voile.Schema.Metadata.ResourceClass

  plug VoileWeb.Plugs.Authorize,
    permissions: %{
      new: ["metadata.manage"],
      create: ["metadata.manage"],
      edit: ["metadata.manage", "metadata.edit"],
      update: ["metadata.manage", "metadata.edit"],
      delete: ["metadata.manage"]
    }

  def index(conn, _params) do
    page = Map.get(conn.params, "page", "1") |> String.to_integer()
    per_page = 10

    {resource_class_collection, total_pages} =
      Metadata.list_resource_classes_paginated(page, per_page)

    conn
    |> assign(:resource_class_collection, resource_class_collection)
    |> assign(:page, page)
    |> assign(:total_pages, total_pages)
    |> render(:index)
  end

  def new(conn, _params) do
    vocabulary_list = Metadata.list_metadata_vocabularies()
    changeset = Metadata.change_resource_class(%ResourceClass{})

    conn
    |> assign(:vocabulary_list, vocabulary_list)
    |> assign(:changeset, changeset)
    |> render(:new)
  end

  def create(conn, %{"resource_class" => resource_class_params}) do
    case Metadata.create_resource_class(resource_class_params) do
      {:ok, resource_class} ->
        conn
        |> put_flash(:info, "Resource class created successfully.")
        |> redirect(to: ~p"/manage/metaresource/resource_class/#{resource_class}")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :new, changeset: changeset)
    end
  end

  def show(conn, %{"id" => id}) do
    resource_class = Metadata.get_resource_class!(id)
    vocabulary_list = Metadata.list_metadata_vocabularies()

    conn
    |> assign(:vocabulary_list, vocabulary_list)
    |> assign(:resource_class, resource_class)
    |> render(:show)
  end

  def edit(conn, %{"id" => id}) do
    resource_class = Metadata.get_resource_class!(id)
    vocabulary_list = Metadata.list_metadata_vocabularies()
    changeset = Metadata.change_resource_class(resource_class)

    conn
    |> assign(:vocabulary_list, vocabulary_list)
    |> assign(:resource_class, resource_class)
    |> assign(:changeset, changeset)
    |> render(:edit)
  end

  def update(conn, %{"id" => id, "resource_class" => resource_class_params}) do
    resource_class = Metadata.get_resource_class!(id)
    vocabulary_list = Metadata.list_metadata_vocabularies()

    case Metadata.update_resource_class(resource_class, resource_class_params) do
      {:ok, resource_class} ->
        conn
        |> put_flash(:info, "Resource class updated successfully.")
        |> redirect(to: ~p"/manage/metaresource/resource_class/#{resource_class}")

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> assign(:vocabulary_list, vocabulary_list)
        |> assign(:resource_class, resource_class)
        |> assign(:changeset, changeset)
        |> render(:edit)
    end
  end

  def delete(conn, %{"id" => id}) do
    resource_class = Metadata.get_resource_class!(id)
    {:ok, _resource_class} = Metadata.delete_resource_class(resource_class)

    conn
    |> put_flash(:info, "Resource class deleted successfully.")
    |> redirect(to: ~p"/manage/metaresource/resource_class")
  end
end
