defmodule VoileWeb.API.V1.Fines.FineApiController do
  use VoileWeb, :controller

  alias Voile.Schema.Library.Circulation
  alias Voile.Schema.Library.Fine

  action_fallback VoileWeb.API.FallbackController

  def index(conn, params) do
    page = Map.get(params, "page", "1") |> String.to_integer()

    {fines, total_pages} =
      Circulation.list_fines_paginated(page, 10)

    pagination = %{
      page_number: page,
      page_size: 10,
      total_pages: total_pages
    }

    conn
    |> put_status(:ok)
    |> render(:index, fines: fines, pagination: pagination)
  end

  def show(conn, %{"id" => id}) do
    case Circulation.get_fine!(id) do
      nil ->
        {:error, :not_found}

      %Fine{} = fine ->
        conn
        |> put_status(:ok)
        |> render(:show, fine: fine)
    end
  end

  def create(conn, %{"fine" => fine_params}) do
    case Circulation.create_fine(fine_params) do
      {:ok, %Fine{} = fine} ->
        conn
        |> put_status(:created)
        |> render(:show, fine: fine)

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> put_view(VoileWeb.API.FallbackController)
        |> render(:error, changeset: changeset)
    end
  end

  def update(conn, %{"id" => id, "fine" => fine_params}) do
    case Circulation.get_fine!(id) do
      nil ->
        {:error, :not_found}

      %Fine{} = fine ->
        case Circulation.update_fine(fine, fine_params) do
          {:ok, %Fine{} = updated_fine} ->
            conn
            |> put_status(:ok)
            |> render(:show, fine: updated_fine)

          {:error, changeset} ->
            conn
            |> put_status(:unprocessable_entity)
            |> put_view(VoileWeb.API.FallbackController)
            |> render(:error, changeset: changeset)
        end
    end
  end

  def delete(conn, %{"id" => id}) do
    case Circulation.get_fine!(id) do
      nil ->
        {:error, :not_found}

      %Fine{} = fine ->
        case Circulation.delete_fine(fine) do
          {:ok, %Fine{}} ->
            send_resp(conn, :no_content, "")

          {:error, changeset} ->
            conn
            |> put_status(:unprocessable_entity)
            |> put_view(VoileWeb.API.FallbackController)
            |> render(:error, changeset: changeset)
        end
    end
  end
end
