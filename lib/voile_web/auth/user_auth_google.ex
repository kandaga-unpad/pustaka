defmodule VoileWeb.UserAuthGoogle do
  @moduledoc """
  Google OAuth 2.0 login integration via Assent.

  Assent's OAuth2 strategy generates and validates a CSRF `state` token
  internally (stored in `session_params`).  This module enforces that
  `session_params` must be present on callback — if the session cookie is
  missing (e.g. a forged/forwarded callback URL), the request is rejected.
  """

  import Plug.Conn

  require Logger

  alias Assent.{Strategy.Google}
  alias Voile.Schema.Accounts.User

  # /auth/google
  def request(conn) do
    case Application.get_env(:assent, :google, [])
         |> Google.authorize_url() do
      {:ok, %{url: url, session_params: session_params}} ->
        # Session params carry the CSRF state; they are validated by Assent
        # during callback to prevent login-CSRF / account-linking attacks.
        conn
        |> put_session(:session_params, session_params)
        |> put_resp_header("location", url)
        |> send_resp(302, "Redirecting to Google")

      {:error, error} ->
        Logger.warning("Google authorize_url failed: #{inspect(error)}")

        conn
        |> Phoenix.Controller.put_flash(
          :error,
          "Unable to connect to Google. Please try again."
        )
        |> Phoenix.Controller.redirect(to: "/login")
    end
  end

  # /auth/google/callback
  def callback(conn) do
    %{params: params} = fetch_query_params(conn)
    session_params = get_session(conn, :session_params)

    if is_nil(session_params) do
      # No session_params means no prior authorize_url request was made in this
      # session — the callback is either forged or forwarded.  Reject it to
      # prevent login-CSRF attacks.
      Logger.warning("Google callback rejected: missing session_params")

      conn
      |> Phoenix.Controller.put_flash(
        :error,
        "Authentication session expired. Please try again."
      )
      |> Phoenix.Controller.redirect(to: "/login")
    else
      do_callback(conn, params, session_params)
    end
  end

  defp do_callback(conn, params, session_params) do
    case Application.get_env(:assent, :google, [])
         |> Keyword.put(:session_params, session_params)
         |> Google.callback(params) do
      {:ok, %{user: user, token: token}} ->
        # Clear the one-time session params so they can't be replayed.
        conn = delete_session(conn, :session_params)

        email = user["email"]
        is_institutional = is_institutional_email?(email)

        user_record = Voile.Schema.Accounts.get_user_by_email_or_register(user)

        case user_record do
          {:error, :domain_not_allowed} ->
            Logger.warning("Google registration rejected for domain: #{email}")

            conn
            |> Phoenix.Controller.put_flash(
              :error,
              "Registration is restricted to authorized email domains. Please contact an administrator."
            )
            |> Phoenix.Controller.redirect(to: "/login")

          user_record ->
            do_google_login(conn, user_record, user, token, is_institutional)
        end

      {:error, error} ->
        Logger.warning("Google callback failed: #{inspect(error)}")

        conn
        |> delete_session(:session_params)
        |> Phoenix.Controller.put_flash(
          :error,
          "Google authentication failed. Please try again."
        )
        |> Phoenix.Controller.redirect(to: "/login")
    end
  end

  defp do_google_login(conn, user_record, google_user, token, is_institutional) do
    # If institutional email and new user, assign verified member type
    user_record = maybe_assign_verified_member(user_record, is_institutional)

    # Check if user needs onboarding
    needs_onboarding = needs_onboarding?(user_record, is_institutional)

    # Block suspended users before creating a session
    if Voile.Schema.Accounts.is_manually_suspended?(user_record) do
      reason = user_record.suspension_reason || "Your account has been suspended"

      conn
      |> Phoenix.Controller.put_flash(
        :error,
        "Login failed: #{reason}. Please contact support for assistance."
      )
      |> Phoenix.Controller.redirect(to: "/login")
    else
      conn
      |> put_session(:google_user, google_user)
      |> put_session(:google_user_token, token)
      |> VoileWeb.UserAuth.log_in_user(user_record)
      |> maybe_redirect_to_onboarding(needs_onboarding)
    end
  end

  defp is_institutional_email?(email) when is_binary(email) do
    String.ends_with?(email, "@mail.unpad.ac.id") or String.ends_with?(email, "@unpad.ac.id")
  end

  defp is_institutional_email?(_), do: false

  defp maybe_assign_verified_member(user, true = _is_institutional) do
    # Get or create verified member type
    case Voile.Schema.Master.get_member_type_by_slug("verified_member") do
      nil ->
        user

      member_type ->
        if is_nil(user.user_type_id) do
          {:ok, updated_user} =
            Voile.Schema.Accounts.update_user(user, %{user_type_id: member_type.id})

          updated_user
        else
          user
        end
    end
  end

  defp maybe_assign_verified_member(user, false), do: user

  defp needs_onboarding?(user, is_institutional) do
    # User needs onboarding if:
    # 1. Lacks basic profile information (fullname or phone)
    # 2. Is institutional user (@unpad email) and doesn't have identifier (NPM/NIP) yet
    is_nil(user.fullname) or
      is_nil(user.phone_number) or
      (is_institutional and is_nil(user.identifier))
  end

  defp maybe_redirect_to_onboarding(conn, true) do
    Phoenix.Controller.redirect(conn, to: "/users/onboarding")
  end

  defp maybe_redirect_to_onboarding(conn, false) do
    Phoenix.Controller.redirect(conn, to: "/")
  end

  def fetch_google_user(conn, _opts) do
    with user when is_map(user) <- get_session(conn, :google_user) do
      assign(conn, :current_user, %User{email: user["email"]})
    else
      _ -> conn
    end
  end

  def on_mount(:mount_current_user, _params, session, socket) do
    {:cont, mount_current_user(session, socket)}
  end

  defp mount_current_user(socket, session) do
    Phoenix.Component.assign_new(socket, :current_user, fn ->
      if user = session["google_user"] do
        %User{email: user["email"]}
      else
        nil
      end
    end)
  end
end
