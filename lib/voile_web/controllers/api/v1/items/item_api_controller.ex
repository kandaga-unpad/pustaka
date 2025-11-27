defmodule VoileWeb.API.V1.Items.ItemApiController do
  use VoileWeb, :controller

  alias Voile.Schema.Catalog
  alias Voile.Schema.Catalog.Item

  action_fallback VoileWeb.API.FallbackController

  def index(conn, params) do
    page = Map.get(params, "page", "1") |> String.to_integer()
    search_keyword = Map.get(params, "search", "")

    {items, total_pages} =
      Catalog.list_items_paginated(page, 10, search_keyword)

    pagination = %{
      page_number: page,
      page_size: 10,
      total_pages: total_pages
    }

    conn
    |> put_status(:ok)
    |> render(:index, items: items, pagination: pagination)
  end

  def create(conn, %{"item" => item_params}) do
    case Catalog.create_item(item_params) do
      {:ok, %Item{} = item} ->
        conn
        |> put_status(:created)
        |> render(:show, item: item)

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> put_view(VoileWeb.API.FallbackController)
        |> render(:error, changeset: changeset)
    end
  end

  def show(conn, %{"id" => id}) do
    case Catalog.get_item!(id) do
      nil ->
        {:error, :not_found}

      %Item{} = item ->
        conn
        |> put_status(:ok)
        |> render(:show, item: item)
    end
  end

  def update(conn, %{"id" => id, "item" => item_params}) do
    case Catalog.get_item!(id) do
      nil ->
        {:error, :not_found}

      %Item{} = item ->
        case Catalog.update_item(item, item_params) do
          {:ok, %Item{} = updated_item} ->
            conn
            |> put_status(:ok)
            |> render(:show, item: updated_item)

          {:error, changeset} ->
            conn
            |> put_status(:unprocessable_entity)
            |> put_view(VoileWeb.API.FallbackController)
            |> render(:error, changeset: changeset)
        end
    end
  end

  def delete(conn, %{"id" => id}) do
    case Catalog.get_item!(id) do
      nil ->
        {:error, :not_found}

      %Item{} = item ->
        case Catalog.delete_item(item) do
          {:ok, %Item{}} ->
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
