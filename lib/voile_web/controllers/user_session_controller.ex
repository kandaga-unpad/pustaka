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
          needs_onboarding = needs_onboarding?(user)

          conn
          |> put_flash(:info, info)
          |> UserAuth.log_in_user(user, user_params)
          |> maybe_redirect_to_onboarding(needs_onboarding)
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

  defp needs_onboarding?(user) do
    # User needs onboarding if they lack basic profile information
    is_nil(user.fullname) or is_nil(user.phone_number) or
      (not is_nil(user.identifier) and not institutional_email?(user.email))
  end

  defp institutional_email?(email) when is_binary(email) do
    String.ends_with?(email, "@mail.unpad.ac.id") or String.ends_with?(email, "@unpad.ac.id")
  end

  defp institutional_email?(_), do: false

  defp maybe_redirect_to_onboarding(conn, true) do
    conn
    |> put_session(:user_return_to, ~p"/users/onboarding")
    |> redirect(to: ~p"/users/onboarding")
  end

  defp maybe_redirect_to_onboarding(conn, false), do: conn

  def delete(conn, _params) do
    conn
    |> put_flash(:info, "Logged out successfully.")
    |> UserAuth.log_out_user()
  end
end
