defmodule VoileWeb.API.V1.Collections.CollectionApiController do
  use VoileWeb, :controller

  alias Voile.Schema.Catalog
  alias Voile.Schema.Catalog.Collection

  action_fallback VoileWeb.API.FallbackController

  def index(conn, params) do
    page = Map.get(params, "page", "1") |> String.to_integer()
    search_keyword = Map.get(params, "search", "")

    {collections, total_pages} =
      Catalog.list_collections_paginated(page, 10, search_keyword)

    pagination = %{
      page_number: page,
      page_size: 10,
      total_pages: total_pages
    }

    conn
    |> put_status(:ok)
    |> render(:index, collections: collections, pagination: pagination)
  end

  def create(conn, %{"collection" => collection_params}) do
    case Catalog.create_collection(collection_params) do
      {:ok, %Collection{} = collection} ->
        conn
        |> put_status(:created)
        |> render(:show, collection: collection)

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> put_view(VoileWeb.API.FallbackController)
        |> render(:error, changeset: changeset)
    end
  end

  def show(conn, %{"id" => id}) do
    case Catalog.get_collection!(id) do
      nil ->
        {:error, :not_found}

      %Collection{} = collection ->
        conn
        |> put_status(:ok)
        |> render(:show, collection: collection)
    end
  end

  def update(conn, %{"id" => id, "collection" => collection_params}) do
    case Catalog.get_collection!(id) do
      nil ->
        {:error, :not_found}

      %Collection{} = collection ->
        case Catalog.update_collection(collection, collection_params) do
          {:ok, %Collection{} = updated_collection} ->
            conn
            |> put_status(:ok)
            |> render(:show, collection: updated_collection)

          {:error, changeset} ->
            conn
            |> put_status(:unprocessable_entity)
            |> put_view(VoileWeb.API.FallbackController)
            |> render(:error, changeset: changeset)
        end
    end
  end

  def delete(conn, %{"id" => id}) do
    case Catalog.get_collection!(id) do
      nil ->
        {:error, :not_found}

      %Collection{} = collection ->
        case Catalog.delete_collection(collection) do
          {:ok, %Collection{}} ->
            conn
            |> send_resp(:no_content, "")

          {:error, changeset} ->
            conn
            |> put_status(:unprocessable_entity)
            |> put_view(VoileWeb.API.FallbackController)
            |> render(:error, changeset: changeset)
        end
    end
  end
end
