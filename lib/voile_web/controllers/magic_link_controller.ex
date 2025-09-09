defmodule VoileWeb.MagicLinkController do
  use VoileWeb, :controller

  alias Voile.Schema.Accounts
  alias VoileWeb.UserAuth

  def login(conn, %{"token" => token}) do
    case Accounts.login_user_by_magic_link(token) do
      {:ok, {user, _expired_tokens}} ->
        conn
        |> put_flash(:info, "Welcome! You have been successfully logged in.")
        |> UserAuth.log_in_user(user)

      {:error, :not_found} ->
        conn
        |> put_flash(:error, "Login link is invalid or has expired.")
        |> redirect(to: ~p"/login")
    end
  end
end
