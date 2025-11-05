defmodule VoileWeb.UserAuthGoogle do
  import Plug.Conn

  alias Assent.{Strategy.Google}
  alias Voile.Schema.Accounts.User

  # /auth/google
  def request(conn) do
    case Application.get_env(:assent, :google)
         |> Google.authorize_url() do
      {:ok, %{url: url, session_params: session_params}} ->
        # Session params (used for OAuth 2.0 and OIDC strategies) will be
        # retrieved when user returns for the callback phase
        conn = put_session(conn, :session_params, session_params)

        # Redirect end-user to Github to authorize access to their account
        conn
        |> put_resp_header("location", url)
        |> send_resp(302, "Successfully Redirected")

      {:error, error} ->
        conn
        |> put_resp_content_type("text/plain")
        |> send_resp(
          500,
          "Something went wrong on authorization! Here is the reason: #{inspect(error)}"
        )
    end
  end

  # /auth/google/callback
  def callback(conn) do
    # End-user will return to the callback URL with params attached to the
    # request. These must be passed on to the strategy. In this example we only
    # expect GET query params, but the provider could also return the user with
    # a POST request where the params is in the POST body.
    %{params: params} = fetch_query_params(conn)

    # The session params (used for OAuth 2.0 and OIDC Strategies) stored in the
    # request phase will be used in the callback phase
    session_params = get_session(conn, :session_params)

    case Application.get_env(:assent, :google)
         # Session params should be added to the config so the strategi can use them
         |> Keyword.put(:session_params, session_params)
         |> Google.callback(params) do
      {:ok, %{user: user, token: token}} ->
        # Authorization successful
        email = user["email"]
        is_institutional = is_institutional_email?(email)

        user_record = Voile.Schema.Accounts.get_user_by_email_or_register(user)

        # If institutional email and new user, assign verified member type
        user_record = maybe_assign_verified_member(user_record, is_institutional)

        # Check if user needs onboarding
        needs_onboarding = needs_onboarding?(user_record, is_institutional)

        conn
        |> VoileWeb.UserAuth.log_in_user(user_record)
        |> put_session(:google_user, user)
        |> put_session(:google_user_token, token)
        |> maybe_redirect_to_onboarding(needs_onboarding)

      {:error, error} ->
        # Authorization failed
        conn
        |> put_resp_content_type("text/plain")
        |> send_resp(500, inspect(error, pretty: true))
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
