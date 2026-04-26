defmodule VoileWeb.UserAuth do
  use VoileWeb, :verified_routes

  import Plug.Conn
  import Phoenix.Controller

  alias Voile.Schema.Accounts
  alias Voile.Schema.Accounts.Scope

  # Make the remember me cookie valid for 60 days.
  # If you want bump or reduce this value, also change
  # the token expiry itself in UserToken.
  @max_cookie_age_in_days 14
  @remember_me_cookie "_voile_web_user_remember_me"
  @remember_me_options [
    sign: true,
    max_age: @max_cookie_age_in_days * 24 * 60 * 60,
    same_site: "Lax"
  ]
  # How old the session token should be before a new one is issued. When a request is made
  # with a session token older than this value, then a new session token will be created
  # and the session and remember-me cookies (if set) will be updated with the new token.
  # Lowering this value will result in more tokens being created by active users. Increasing
  # it will result in less time before a session token expires for a user to get issued a new
  # token. This can be set to a value greater than `@max_cookie_age_in_days` to disable
  # the reissuing of tokens completely.
  @session_reissue_age_in_days 7

  @doc """
  Logs the user in.

  Redirects to the session's `:user_return_to` path
  or falls back to the `signed_in_path/1`.
  """
  def log_in_user(conn, user, params \\ %{}) do
    # Check if user is suspended
    if Accounts.is_manually_suspended?(user) do
      reason = user.suspension_reason || "Your account has been suspended"

      conn
      |> put_flash(:error, "Login failed: #{reason}. Please contact support for assistance.")
      |> redirect(to: ~p"/login")
    else
      user_return_to = get_session(conn, :user_return_to)

      # Update last_login and last_login_ip
      ip =
        case Tuple.to_list(conn.remote_ip) do
          [a, b, c, d] -> Enum.join([a, b, c, d], ".")
          _ -> nil
        end

      Accounts.update_user_login(user, %{last_login: DateTime.utc_now(), last_login_ip: ip})

      conn
      |> create_or_extend_session(user, params)
      |> assign(:current_scope, Scope.for_user(user))
      |> redirect(to: user_return_to || signed_in_path(user))
    end
  end

  @doc """
  Logs the user out.

  It clears all session data for safety. See renew_session.
  """
  def log_out_user(conn) do
    user_token = get_session(conn, :user_token)
    user_token && Accounts.delete_user_session_token(user_token)

    if live_socket_id = get_session(conn, :live_socket_id) do
      VoileWeb.Endpoint.broadcast(live_socket_id, "disconnect", %{})
    end

    conn
    |> renew_session(nil)
    |> delete_resp_cookie(@remember_me_cookie)
    |> redirect(to: ~p"/")
  end

  @doc """
  Authenticates the user by looking into the session and remember me token.

  Will reissue the session token if it is older than the configured age.
  Also checks if the user is suspended and logs them out if so.
  """
  def fetch_current_scope_for_user(conn, _opts) do
    with {token, conn} <- ensure_user_token(conn),
         {user, token_inserted_at} <- Accounts.get_user_by_session_token(token) do
      user = Voile.Repo.preload(user, [:user_role_assignments, :node, :roles, :user_type])

      # Check if user is suspended
      if Accounts.is_manually_suspended?(user) do
        conn
        |> put_flash(
          :error,
          "Your account has been suspended: #{user.suspension_reason || "Contact support for details"}"
        )
        |> log_out_user()
      else
        conn
        |> assign(:current_scope, Scope.for_user(user))
        |> maybe_reissue_user_session_token(user, token_inserted_at)
      end
    else
      nil -> assign(conn, :current_scope, Scope.for_user(nil))
    end
  end

  defp ensure_user_token(conn) do
    if token = get_session(conn, :user_token) do
      {token, conn}
    else
      conn = fetch_cookies(conn, signed: [@remember_me_cookie])

      if token = conn.cookies[@remember_me_cookie] do
        {token, conn |> put_token_in_session(token) |> put_session(:user_remember_me, true)}
      else
        nil
      end
    end
  end

  # Reissue the session token if it is older than the configured reissue age.
  defp maybe_reissue_user_session_token(conn, user, token_inserted_at) do
    token_age = DateTime.diff(DateTime.utc_now(:second), token_inserted_at, :day)

    if token_age >= @session_reissue_age_in_days do
      create_or_extend_session(conn, user, %{})
    else
      conn
    end
  end

  # This function is the one responsible for creating session tokens
  # and storing them safely in the session and cookies. It may be called
  # either when logging in, during sudo mode, or to renew a session which
  # will soon expire.
  #
  # When the session is created, rather than extended, the renew_session
  # function will clear the session to avoid fixation attacks. See the
  # renew_session function to customize this behaviour.
  defp create_or_extend_session(conn, user, params) do
    token = Accounts.generate_user_session_token(user)
    remember_me = get_session(conn, :user_remember_me)

    conn
    |> renew_session(user)
    |> put_token_in_session(token)
    |> maybe_write_remember_me_cookie(token, params, remember_me)
  end

  # Do not renew session if the user is already logged in
  # to prevent CSRF errors or data being lost in tabs that are still open
  defp renew_session(conn, user) when is_struct(user) do
    case conn.assigns do
      %{current_scope: %{user: %{id: user_id}}} when user_id == user.id ->
        conn

      _ ->
        do_renew_session(conn)
    end
  end

  defp renew_session(conn, _user), do: do_renew_session(conn)

  # This function renews the session ID and erases the whole
  # session to avoid fixation attacks. If there is any data
  # in the session you may want to preserve after log in/log out,
  # you must explicitly fetch the session data before clearing
  # and then immediately set it after clearing, for example:
  #
  #     defp do_renew_session(conn) do
  #       delete_csrf_token()
  #       preferred_locale = get_session(conn, :preferred_locale)
  #
  #       conn
  #       |> configure_session(renew: true)
  #       |> clear_session()
  #       |> put_session(:preferred_locale, preferred_locale)
  #     end
  #
  defp do_renew_session(conn) do
    delete_csrf_token()

    conn
    |> configure_session(renew: true)
    |> clear_session()
  end

  defp maybe_write_remember_me_cookie(conn, token, %{"remember_me" => "true"}, _),
    do: write_remember_me_cookie(conn, token)

  defp maybe_write_remember_me_cookie(conn, token, _params, true),
    do: write_remember_me_cookie(conn, token)

  defp maybe_write_remember_me_cookie(conn, _token, _params, _), do: conn

  defp write_remember_me_cookie(conn, token) do
    conn
    |> put_session(:user_remember_me, true)
    |> put_resp_cookie(@remember_me_cookie, token, @remember_me_options)
  end

  defp put_token_in_session(conn, token) do
    conn
    |> put_session(:user_token, token)
    |> put_session(:live_socket_id, user_session_topic(token))
  end

  @doc """
  Disconnects existing sockets for the given tokens.
  """
  def disconnect_sessions(tokens) do
    Enum.each(tokens, fn %{token: token} ->
      VoileWeb.Endpoint.broadcast(user_session_topic(token), "disconnect", %{})
    end)
  end

  defp user_session_topic(token), do: "users_sessions:#{Base.url_encode64(token)}"

  @doc """
  Handles mounting and authenticating the current_scope in LiveViews.

  ## `on_mount` arguments

    * `:mount_current_scope` - Assigns current_scope
      to socket assigns based on user_token, or nil if
      there's no user_token or no matching user.

    * `:require_authenticated` - Authenticates the user from the session,
      and assigns the current_scope to socket assigns based
      on user_token.
      Redirects to login page if there's no logged user.

    * `{:require_permission, "permission.name"}` - Requires both authentication
      and a specific permission. Checks RBAC permissions.

    * `{:require_permission, "permission.name", scope: {:collection, :id}}` -
      Requires authentication and a scoped permission.

    * `:require_authenticated_verified_member_organization_or_verified_staff_user` -
      Requires a logged in user who is administrator, staff, or a verified member type (organization or verified individual).

  ## Examples

  Use the `on_mount` lifecycle macro in LiveViews to mount or authenticate
  the `current_scope`:

      defmodule VoileWeb.PageLive do
        use VoileWeb, :live_view

        on_mount {VoileWeb.UserAuth, :mount_current_scope}
        ...
      end

  Or use the `live_session` of your router to invoke the on_mount callback:

      live_session :authenticated, on_mount: [{VoileWeb.UserAuth, :require_authenticated}] do
        live "/profile", ProfileLive, :index
      end

  For permission-based authorization in LiveViews:

      live_session :admin_only,
        on_mount: [
          {VoileWeb.UserAuth, :require_authenticated},
          {VoileWeb.UserAuth, {:require_permission, "system.settings"}}
        ] do
        live "/admin", AdminLive, :index
      end
  """
  def on_mount(:mount_current_scope, _params, session, socket) do
    {:cont, mount_current_scope(socket, session)}
  end

  def on_mount(:require_authenticated, _params, session, socket) do
    socket = mount_current_scope(socket, session)

    if socket.assigns.current_scope && socket.assigns.current_scope.user do
      {:cont, socket}
    else
      socket =
        socket
        |> Phoenix.LiveView.put_flash(:error, "You must log in to access this page.")
        |> Phoenix.LiveView.redirect(to: ~p"/login")

      {:halt, socket}
    end
  end

  def on_mount(:require_onboarding_complete, _params, session, socket) do
    socket = mount_current_scope(socket, session)

    # Attach a hook to check onboarding after params are handled
    socket =
      socket
      |> Phoenix.LiveView.attach_hook(
        :check_onboarding_complete,
        :handle_params,
        &check_onboarding_hook/3
      )

    {:cont, socket}
  end

  def on_mount({:require_permission, permission_name}, params, session, socket) do
    on_mount({:require_permission, permission_name, []}, params, session, socket)
  end

  def on_mount({:require_permission, permission_name, opts}, _params, session, socket) do
    socket = mount_current_scope(socket, session)

    case socket.assigns.current_scope do
      %{user: user} when not is_nil(user) ->
        if VoileWeb.Auth.Authorization.can?(user, permission_name, opts) do
          {:cont, socket}
        else
          if socket.assigns.current_scope.user.user_type.slug in ["administrator", "staff"] do
            socket =
              socket
              |> Phoenix.LiveView.put_flash(
                :error,
                "You don't have permission to access this page."
              )
              |> Phoenix.LiveView.redirect(to: ~p"/manage")

            {:halt, socket}
          else
            socket =
              socket
              |> Phoenix.LiveView.put_flash(
                :error,
                "You don't have permission to access this page."
              )
              |> Phoenix.LiveView.redirect(to: ~p"/")

            {:halt, socket}
          end
        end

      _ ->
        socket =
          socket
          |> Phoenix.LiveView.put_flash(:error, "You must log in to access this page.")
          |> Phoenix.LiveView.redirect(to: ~p"/login")

        {:halt, socket}
    end
  end

  def on_mount(:require_authenticated_and_verified_member, _params, session, socket) do
    socket = mount_current_scope(socket, session)

    if socket.assigns.current_scope && socket.assigns.current_scope.user do
      user = socket.assigns.current_scope.user

      if user.authenticated_at && is_struct(user.authenticated_at, DateTime) do
        {:cont, socket}
      else
        socket =
          socket
          |> Phoenix.LiveView.put_flash(:error, "You must be verified to access this page.")
          |> Phoenix.LiveView.redirect(to: ~p"/login")

        {:halt, socket}
      end
    end
  end

  def on_mount(:require_authenticated_and_verified_staff_user, _params, session, socket) do
    socket = mount_current_scope(socket, session)

    if socket.assigns.current_scope && socket.assigns.current_scope.user do
      user = socket.assigns.current_scope.user

      case user.user_type do
        %{slug: slug} when slug in ["administrator", "staff"] ->
          {:cont, socket}

        nil ->
          socket =
            socket
            |> Phoenix.LiveView.put_flash(
              :error,
              "You must have a valid member type to access this page."
            )
            |> maybe_store_return_to()
            |> Phoenix.LiveView.redirect(to: ~p"/login")

          {:halt, socket}

        _ ->
          socket =
            socket
            |> Phoenix.LiveView.put_flash(
              :error,
              "You must be an Admin or Staff to access this page."
            )
            |> maybe_store_return_to()
            |> Phoenix.LiveView.redirect(to: ~p"/login")

          {:halt, socket}
      end
    else
      socket =
        socket
        |> Phoenix.LiveView.put_flash(:error, "You must be logged in to access this page.")
        |> maybe_store_return_to()
        |> Phoenix.LiveView.redirect(to: ~p"/login")

      {:halt, socket}
    end
  end

  def on_mount(
        :require_authenticated_verified_member_organization_or_verified_staff_user,
        _params,
        session,
        socket
      ) do
    socket = mount_current_scope(socket, session)

    if socket.assigns.current_scope && socket.assigns.current_scope.user do
      user = socket.assigns.current_scope.user

      case user.user_type do
        %{slug: slug} when slug in ["administrator", "staff"] ->
          {:cont, socket}

        %{slug: slug} when slug in ["member_organization", "member_verified", "member_paid"] ->
          if user.authenticated_at && is_struct(user.authenticated_at, DateTime) do
            {:cont, socket}
          else
            socket =
              socket
              |> Phoenix.LiveView.put_flash(
                :error,
                "You must be verified to access this page."
              )
              |> maybe_store_return_to()
              |> Phoenix.LiveView.redirect(to: ~p"/login")

            {:halt, socket}
          end

        nil ->
          socket =
            socket
            |> Phoenix.LiveView.put_flash(
              :error,
              "You must have a valid member type to access this page."
            )
            |> maybe_store_return_to()
            |> Phoenix.LiveView.redirect(to: ~p"/login")

          {:halt, socket}

        _ ->
          socket =
            socket
            |> Phoenix.LiveView.put_flash(
              :error,
              "You must be an Admin, Staff, or verified member to access this page."
            )
            |> maybe_store_return_to()
            |> Phoenix.LiveView.redirect(to: ~p"/login")

          {:halt, socket}
      end
    else
      socket =
        socket
        |> Phoenix.LiveView.put_flash(:error, "You must be logged in to access this page.")
        |> maybe_store_return_to()
        |> Phoenix.LiveView.redirect(to: ~p"/login")

      {:halt, socket}
    end
  end

  def on_mount(:require_sudo_mode, _params, session, socket) do
    socket = mount_current_scope(socket, session)

    if Accounts.sudo_mode?(socket.assigns.current_scope.user, -10) do
      {:cont, socket}
    else
      socket =
        socket
        |> Phoenix.LiveView.put_flash(:error, "You must re-authenticate to access this page.")
        |> Phoenix.LiveView.redirect(to: ~p"/login")

      {:halt, socket}
    end
  end

  defp mount_current_scope(socket, session) do
    {user, _token_inserted_at} =
      if user_token = session["user_token"] do
        Accounts.get_user_by_session_token(user_token)
      else
        {nil, nil}
      end

    user = Voile.Repo.preload(user, [:roles, :user_type, :node])

    current_scope =
      if user && Accounts.is_manually_suspended?(user) do
        # Disconnect the socket
        reason = user.suspension_reason || "Your account has been suspended"

        socket
        |> Phoenix.LiveView.put_flash(:error, "Access denied: #{reason}")
        |> Phoenix.LiveView.redirect(to: ~p"/login")

        Scope.for_user(nil)
      else
        Scope.for_user(user)
      end

    Phoenix.Component.assign(socket, :current_scope, current_scope)
  end

  defp check_onboarding_hook(_params, url, socket) do
    # Get the current path from the URL
    current_path = URI.parse(url).path || ""

    # Skip onboarding check if we're on the onboarding page
    if String.contains?(current_path, "/users/onboarding") do
      {:cont, socket}
    else
      case socket.assigns[:current_scope] do
        %{user: user} when not is_nil(user) ->
          if needs_onboarding?(user) do
            socket =
              socket
              |> Phoenix.LiveView.put_flash(:info, "Please complete your profile to continue.")
              |> Phoenix.LiveView.redirect(to: ~p"/users/onboarding")

            {:halt, socket}
          else
            {:cont, socket}
          end

        _ ->
          {:cont, socket}
      end
    end
  end

  @doc "Returns the path to redirect to after log in."
  # the user was already logged in, redirect to settings
  def signed_in_path(%Plug.Conn{assigns: %{current_scope: %Scope{user: user}}})
      when not is_nil(user),
      do: signed_in_path(user)

  def signed_in_path(%Scope{user: user}) when not is_nil(user), do: signed_in_path(user)

  def signed_in_path(user) when is_map(user) do
    if Map.has_key?(user, :id) do
      user = Voile.Repo.preload(user, [:user_type, :roles])

      cond do
        Enum.any?(user.roles, &(&1.name == "super_admin")) -> ~p"/manage"
        user.user_type && user.user_type.slug in ["administrator", "staff"] -> ~p"/manage"
        user.user_type && String.starts_with?(user.user_type.slug, "member_") -> ~p"/atrium"
        true -> ~p"/"
      end
    else
      ~p"/"
    end
  end

  def signed_in_path(_), do: ~p"/"

  @doc """
  Plug for routes that require the user to be authenticated.
  """
  def require_authenticated_user(conn, _opts) do
    if conn.assigns.current_scope && conn.assigns.current_scope.user do
      conn
    else
      conn
      |> put_flash(:error, "You must log in to access this page.")
      |> maybe_store_return_to()
      |> redirect(to: ~p"/login")
      |> halt()
    end
  end

  @doc """
  Plug that ensures the user has completed onboarding before accessing protected routes.
  This should be used after require_authenticated_user.
  """
  def require_onboarding_complete(conn, _opts) do
    # Skip onboarding check if we're already on the onboarding page
    if String.contains?(conn.request_path, "/users/onboarding") do
      conn
    else
      user = conn.assigns.current_scope.user

      if needs_onboarding?(user) do
        conn
        |> put_flash(:info, "Please complete your profile to continue.")
        |> redirect(to: ~p"/users/onboarding")
        |> halt()
      else
        conn
      end
    end
  end

  @doc """
  Checks if a user needs to complete onboarding.
  Returns true if the user lacks basic profile information.
  Only super_admin users are exempt from onboarding.
  """
  def needs_onboarding?(user) do
    # Preload roles if not already loaded
    user = Voile.Repo.preload(user, :roles)

    # Only super_admin is exempt from onboarding
    is_super_admin? =
      Enum.any?(user.roles, fn role ->
        role.name == "super_admin"
      end)

    # Skip onboarding for super_admin only
    if is_super_admin? do
      false
    else
      # User needs onboarding if they lack basic profile information
      is_nil(user.fullname) or is_nil(user.phone_number)
    end
  end

  defp maybe_store_return_to(%{method: "GET"} = conn) do
    put_session(conn, :user_return_to, current_path(conn))
  end

  defp maybe_store_return_to(conn), do: conn
end
