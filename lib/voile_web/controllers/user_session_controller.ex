defmodule VoileWeb.UserSessionController do
  use VoileWeb, :controller

  alias Voile.Schema.Accounts
  alias VoileWeb.UserAuth

  def create(conn, %{"_action" => "registered"} = params) do
    create(conn, params, "Account created successfully!")
  end

  def create(conn, %{"_action" => "password_updated"} = params) do
    conn
    |> put_session(:user_return_to, ~p"/manage/settings")
    |> create(params, "Password updated successfully!")
  end

  def create(conn, params) do
    create(conn, params, "Welcome back!")
  end

  defp create(conn, %{"user" => user_params}, info) do
    %{"email" => login, "password" => password} = user_params

    try do
      if user = Accounts.get_user_by_login_and_password(login, password) do
        # Check if user needs to confirm email
        if is_nil(user.confirmed_at) do
          conn
          |> put_flash(
            :error,
            "Please confirm your email address before logging in. Check your inbox for the confirmation link."
          )
          |> redirect(to: ~p"/users/pending_confirmation?email=#{user.email}")
        else
          # Check if user needs to complete onboarding
          needs_onboarding = UserAuth.needs_onboarding?(user)

          if needs_onboarding do
            conn
            |> put_session(:user_return_to, ~p"/users/onboarding")
            |> put_flash(:info, "Welcome! Please complete your profile to get started.")
            |> UserAuth.log_in_user(user, user_params)
          else
            conn
            |> put_flash(:info, info)
            |> UserAuth.log_in_user(user, user_params)
          end
        end
      else
        # In order to prevent user enumeration attacks, don't disclose whether the login is registered.
        conn
        |> put_flash(:error, "Invalid email/username/identifier or password")
        |> put_flash(:email, String.slice(login, 0, 160))
        |> redirect(to: ~p"/login")
      end
    rescue
      e in MatchError ->
        require Logger

        Logger.error(
          "Password verification failed with MatchError for login: #{login} - #{inspect(e)}"
        )

        conn
        |> put_flash(
          :error,
          "Account authentication error. Please reset your password or contact support."
        )
        |> put_flash(:email, String.slice(login, 0, 160))
        |> redirect(to: ~p"/login")
    end
  end

  def delete(conn, _params) do
    conn
    |> put_flash(:info, "Logged out successfully.")
    |> UserAuth.log_out_user()
  end
end
