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

      {:error, {:unconfirmed_with_password, reset_token, _user}} ->
        # If we detect an unconfirmed user who has a password, guide them to
        # set an initial password via the dedicated setup LiveView.
        conn
        |> put_flash(
          :info,
          "We detected an existing password for this account. Please set your password to finish setting up your account."
        )
        |> redirect(to: ~p"/users/set_initial_password/#{reset_token}")

      {:error, :not_found} ->
        conn
        |> put_flash(:error, "Login link is invalid or has expired.")
        |> redirect(to: ~p"/login")
    end
  end
end
