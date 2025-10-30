defmodule VoileWeb.PropertyController do
  use VoileWeb, :controller_dashboard

  alias Voile.Schema.Metadata
  alias Voile.Schema.Metadata.Property

  plug VoileWeb.Plugs.Authorize,
    permissions: %{
      new: ["metadata.manage"],
      create: ["metadata.manage"],
      edit: ["metadata.manage", "metadata.edit"],
      update: ["metadata.manage", "metadata.edit"],
      delete: ["metadata.manage"]
    }

  def index(conn, params) do
    page = Map.get(params, "page", "1") |> String.to_integer()
    vocabulary_id = Map.get(params, "vocabulary_id", nil)
    per_page = 10

    {metadata_properties, total_pages} =
      case vocabulary_id do
        nil ->
          Metadata.list_metadata_properties_paginated(page, per_page)

        _ ->
          Metadata.list_metadata_properties_by_vocabulary_paginated(vocabulary_id, page, per_page)
      end

    conn
    |> assign(:metadata_properties, metadata_properties)
    |> assign(:page, page)
    |> assign(:total_pages, total_pages)
    |> render(:index)
  end

  def new(conn, _params) do
    vocabulary_list = Metadata.list_metadata_vocabularies()
    changeset = Metadata.change_property(%Property{})

    conn
    |> assign(:vocabulary_list, vocabulary_list)
    |> assign(:changeset, changeset)
    |> render(:new)
  end

  def create(conn, %{"property" => property_params}) do
    case Metadata.create_property(property_params) do
      {:ok, property} ->
        conn
        |> put_flash(:info, "Property created successfully.")
        |> redirect(to: ~p"/manage/metaresource/metadata_properties/#{property}")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :new, changeset: changeset)
    end
  end

  def show(conn, %{"id" => id}) do
    property = Metadata.get_property!(id)
    vocabulary_list = Metadata.list_metadata_vocabularies()

    conn
    |> assign(:vocabulary_list, vocabulary_list)
    |> assign(:property, property)
    |> render(:show)
  end

  def edit(conn, %{"id" => id}) do
    property = Metadata.get_property!(id)
    vocabulary_list = Metadata.list_metadata_vocabularies()
    changeset = Metadata.change_property(property)

    dbg(changeset)

    conn
    |> assign(:vocabulary_list, vocabulary_list)
    |> assign(:property, property)
    |> assign(:changeset, changeset)
    |> render(:edit)
  end

  def update(conn, %{"id" => id, "property" => property_params}) do
    property = Metadata.get_property!(id)
    vocabulary_list = Metadata.list_metadata_vocabularies()

    case Metadata.update_property(property, property_params) do
      {:ok, property} ->
        conn
        |> put_flash(:info, "Property updated successfully.")
        |> redirect(to: ~p"/manage/metaresource/metadata_properties/#{property}")

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> assign(:vocabulary_list, vocabulary_list)
        |> assign(:property, property)
        |> assign(:changeset, changeset)
        |> render(:edit)
    end
  end

  def delete(conn, %{"id" => id}) do
    property = Metadata.get_property!(id)
    {:ok, _property} = Metadata.delete_property(property)

    conn
    |> put_flash(:info, "Property deleted successfully.")
    |> redirect(to: ~p"/manage/metaresource/metadata_properties")
  end
end
