defmodule VoileWeb.API.V1.UserApiTokenController do
  use VoileWeb, :controller

  alias Voile.Schema.System

  action_fallback VoileWeb.API.FallbackController

  def index(conn, _params) do
    current_user = conn.assigns.current_scope.user

    tokens = System.list_user_api_tokens(current_user)
    render(conn, :index, tokens: tokens)
  end

  def create(conn, %{"token" => token_params}) do
    current_user = conn.assigns.current_scope.user

    with {:ok, token, plain_token} <-
           System.create_api_token(current_user, token_params) do
      conn
      |> put_status(:created)
      |> render(:show, token: token, plain_token: plain_token)
    end
  end

  def show(conn, %{"id" => id}) do
    current_user = conn.assigns.current_user

    with token <- System.get_api_token(id),
         true <- token && token.user_id == current_user.id do
      render(conn, :show, token: token)
    else
      _ -> {:error, :not_found}
    end
  end

  def update(conn, %{"id" => id, "token" => token_params}) do
    current_user = conn.assigns.current_scope.user

    with token <- System.get_api_token(id),
         true <- token && token.user_id == current_user.id,
         {:ok, token} <- System.update_api_token(token, token_params) do
      render(conn, :show, token: token)
    else
      false -> {:error, :not_found}
      {:error, changeset} -> {:error, changeset}
    end
  end

  def delete(conn, %{"id" => id}) do
    current_user = conn.assigns.current_scope.user

    with token <- System.get_api_token(id),
         true <- token && token.user_id == current_user.id,
         {:ok, _token} <- System.revoke_api_token(token) do
      send_resp(conn, :no_content, "")
    else
      _ -> {:error, :not_found}
    end
  end

  def rotate(conn, %{"id" => id}) do
    current_user = conn.assigns.current_scope.user

    with token <- System.get_api_token(id),
         true <- token && token.user_id == current_user.id,
         {:ok, {new_token, plain_token}} <- System.rotate_api_token(token) do
      render(conn, :show, token: new_token, plain_token: plain_token)
    else
      _ -> {:error, :not_found}
    end
  end
end
