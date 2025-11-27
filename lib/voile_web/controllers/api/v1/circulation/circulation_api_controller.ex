defmodule VoileWeb.API.V1.Circulation.CirculationApiController do
  use VoileWeb, :controller

  alias Voile.Schema.Library.Circulation
  alias Voile.Schema.Accounts

  action_fallback VoileWeb.API.FallbackController

  def show(conn, %{"identifier" => identifier}) do
    with {:ok, user} <- get_user_by_identifier(identifier) do
      # Get active transactions for the user
      active_transactions = Circulation.list_member_active_transactions(user.id)

      # Get circulation history for the user
      circulation_history = Circulation.get_member_history(user.id)

      # Get unpaid fines for the user
      unpaid_fines = Circulation.list_member_unpaid_fines(user.id)

      conn
      |> put_status(:ok)
      |> render(:show, %{
        user: user,
        active_transactions: active_transactions,
        circulation_history: circulation_history,
        unpaid_fines: unpaid_fines
      })
    else
      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> put_view(VoileWeb.API.ErrorJSON)
        |> render(:"404")
    end
  end

  def transactions(conn, %{"identifier" => identifier}) do
    page = Map.get(conn.params, "page", "1") |> String.to_integer()
    per_page = Map.get(conn.params, "per_page", "10") |> String.to_integer()

    with {:ok, user} <- get_user_by_identifier(identifier) do
      {transactions, total_pages} =
        Circulation.list_member_active_transactions_paginated(user.id, page, per_page)

      pagination = %{
        page_number: page,
        page_size: per_page,
        total_pages: total_pages
      }

      conn
      |> put_status(:ok)
      |> render(:transactions, %{
        user: user,
        transactions: transactions,
        pagination: pagination
      })
    else
      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> put_view(VoileWeb.API.ErrorJSON)
        |> render(:"404")
    end
  end

  def history(conn, %{"identifier" => identifier}) do
    page = Map.get(conn.params, "page", "1") |> String.to_integer()
    per_page = Map.get(conn.params, "per_page", "10") |> String.to_integer()

    with {:ok, user} <- get_user_by_identifier(identifier) do
      {history, total_pages} =
        Circulation.list_circulation_history_paginated_with_filters_by_member(
          user.id,
          page,
          per_page
        )

      pagination = %{
        page_number: page,
        page_size: per_page,
        total_pages: total_pages
      }

      conn
      |> put_status(:ok)
      |> render(:history, %{
        user: user,
        history: history,
        pagination: pagination
      })
    else
      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> put_view(VoileWeb.API.ErrorJSON)
        |> render(:"404")
    end
  end

  def fines(conn, %{"identifier" => identifier}) do
    page = Map.get(conn.params, "page", "1") |> String.to_integer()
    per_page = Map.get(conn.params, "per_page", "10") |> String.to_integer()

    with {:ok, user} <- get_user_by_identifier(identifier) do
      {fines, total_pages} =
        Circulation.list_member_unpaid_fines_paginated(user.id, page, per_page)

      pagination = %{
        page_number: page,
        page_size: per_page,
        total_pages: total_pages
      }

      conn
      |> put_status(:ok)
      |> render(:fines, %{
        user: user,
        fines: fines,
        pagination: pagination
      })
    else
      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> put_view(VoileWeb.API.ErrorJSON)
        |> render(:"404")
    end
  end

  defp get_user_by_identifier(identifier) do
    case Accounts.get_user_by_identifier(identifier) do
      nil -> {:error, :not_found}
      user -> {:ok, user}
    end
  end
end
