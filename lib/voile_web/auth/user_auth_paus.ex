defmodule VoileWeb.UserAuthPaus do
  @moduledoc """
  PAuS (Padjadjaran Authentication System) OAuth 2.0 integration
  Following the same pattern as UserAuthGoogle using Assent
  """

  import Plug.Conn
  import Phoenix.Controller
  import Ecto.Query, warn: false

  require Logger

  # Import verified routes for ~p sigil
  use VoileWeb, :verified_routes

  alias Voile.Repo
  alias Voile.Schema.Accounts
  alias Voile.Schema.Master.MemberType
  alias Voile.Schema.System.Node

  @user_scopes ["user.basic"]

  @authorization_url "https://paus.unpad.ac.id/oauth"
  @access_token_url "https://paus.unpad.ac.id/oauth/access-token"
  @sign_out_url "https://paus.unpad.ac.id/oauth/sign-out"
  @api_url "https://paus.unpad.ac.id/api"

  # Configuration helper
  defp paus_config do
    Application.get_env(:assent, :paus, [])
  end

  @doc """
  Authorization request handler
  Route: GET /auth/paus
  """
  def request(conn) do
    # Generate secure state
    state = generate_state()

    # Build authorization URL
    params = %{
      response_type: "code",
      client_id: paus_config()[:client_id],
      redirect_uri: paus_config()[:redirect_uri],
      scope: Enum.join(@user_scopes, ","),
      state: state
    }

    url = "#{@authorization_url}?#{URI.encode_query(params)}"

    # Store state in session for validation
    conn = put_session(conn, :paus_oauth_state, state)

    # Redirect to PAuS OAuth
    conn
    |> put_resp_header("location", url)
    |> send_resp(302, "Redirecting to PAuS Authentication")
  end

  @doc """
  OAuth callback handler
  Route: GET /auth/paus/callback
  """
  def callback(conn) do
    %{params: params} = fetch_query_params(conn)
    stored_state = get_session(conn, :paus_oauth_state)

    cond do
      # Check for error from OAuth provider
      Map.has_key?(params, "error") ->
        error_message = params["message"] || params["error_description"] || params["error"]

        conn
        |> put_flash(:error, "Authentication failed: #{error_message}")
        |> redirect(to: ~p"/login")

      # Validate state to prevent CSRF
      !Map.has_key?(params, "state") || params["state"] != stored_state ->
        conn
        |> put_flash(:error, "Invalid state parameter. Please try again.")
        |> redirect(to: ~p"/login")

      # Exchange code for token
      Map.has_key?(params, "code") ->
        case exchange_code_for_token(params["code"]) do
          {:ok, token} ->
            # Fetch user profile from PAuS API
            case fetch_user_profile(token) do
              {:ok, paus_user} ->
                # Get or create user in your system
                user_record = get_or_create_user_from_paus(paus_user)

                conn
                |> delete_session(:paus_oauth_state)
                |> put_session(:paus_user_token, token)
                |> put_session(:paus_user, paus_user)
                |> VoileWeb.UserAuth.log_in_user(user_record)
                |> put_flash(:info, "Welcome, #{paus_user["name"] || paus_user["email"]}!")
                |> redirect(to: ~p"/")

              {:error, reason} ->
                conn
                |> put_flash(:error, "Failed to fetch user profile: #{inspect(reason)}")
                |> redirect(to: ~p"/login")
            end

          {:error, reason} ->
            conn
            |> put_flash(:error, "Token exchange failed: #{inspect(reason)}")
            |> redirect(to: ~p"/login")
        end

      true ->
        conn
        |> put_flash(:error, "Invalid callback parameters")
        |> redirect(to: ~p"/login")
    end
  end

  @doc """
  Sign out from PAuS and clear session
  Route: GET /auth/paus/logout
  """
  def sign_out(conn) do
    # Build sign out URL
    params = %{
      client_id: paus_config()[:client_id],
      redirect_uri: paus_config()[:redirect_uri]
    }

    sign_out_url = "#{@sign_out_url}?#{URI.encode_query(params)}"

    # Clear PAuS session data
    conn
    |> delete_session(:paus_user_token)
    |> delete_session(:paus_user)
    |> delete_session(:paus_oauth_state)
    # Also log out from your app
    |> VoileWeb.UserAuth.log_out_user()
    |> redirect(external: sign_out_url)
  end

  @doc """
  Make API call to PAuS
  Can be used in controllers or LiveViews

  ## Examples

      # GET request
      {:ok, profile} = VoileWeb.UserAuthPaus.api(conn, "/user/profile")

      # POST request
      {:ok, result} = VoileWeb.UserAuthPaus.api(conn, "/user/update", %{name: "New Name"})
  """
  def api(conn, path, params \\ %{}) do
    token = get_session(conn, :paus_user_token)

    case token do
      %{access_token: access_token} ->
        make_api_request(path, access_token, params)

      _ ->
        {:error, :no_token}
    end
  end

  @doc """
  Fetch current PAuS user from session
  """
  def fetch_paus_user(conn, _opts) do
    with user when is_map(user) <- get_session(conn, :paus_user) do
      assign(conn, :paus_user, user)
    else
      _ -> conn
    end
  end

  @doc """
  LiveView on_mount callback for mounting PAuS user
  """
  def on_mount(:mount_paus_user, _params, session, socket) do
    {:cont, mount_paus_user(session, socket)}
  end

  # Private functions

  defp exchange_code_for_token(code) do
    config = paus_config()

    params = %{
      grant_type: "authorization_code",
      client_id: config[:client_id],
      client_secret: config[:client_secret],
      redirect_uri: config[:redirect_uri],
      code: code
    }

    headers = [
      {"content-type", "application/x-www-form-urlencoded"},
      {"user-agent", "Voile PAuS Client/1.0"}
    ]

    body = URI.encode_query(params)

    case Req.post(@access_token_url,
           body: body,
           headers: headers,
           receive_timeout: 30_000
         ) do
      {:ok, %Req.Response{status: 200, body: response_body}} ->
        case decode_body(response_body) do
          {:ok, %{"access_token" => access_token, "expires_in" => expires_in} = token_data} ->
            expires_in_int =
              if is_binary(expires_in), do: String.to_integer(expires_in), else: expires_in

            token = %{
              access_token: access_token,
              expires_at: :os.system_time(:second) + expires_in_int,
              refresh_token: Map.get(token_data, "refresh_token"),
              token_type: Map.get(token_data, "token_type", "Bearer")
            }

            {:ok, token}

          {:ok, %{"error" => error}} ->
            {:error, error}

          {:error, reason} ->
            {:error, {:json_decode_error, reason}}
        end

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, {:http_error, status, body}}

      {:error, reason} ->
        {:error, {:request_failed, reason}}
    end
  end

  defp fetch_user_profile(token) do
    url = "#{@api_url}/accounts?access_token=#{token.access_token}"

    headers = [
      {"user-agent", "Voile PAuS Client/1.0"},
      {"accept", "application/json"}
    ]

    case Req.get(url, headers: headers, receive_timeout: 30_000) do
      {:ok, %Req.Response{status: 200, body: body}} ->
        case decode_body(body) do
          {:ok, user_data} -> {:ok, user_data}
          {:error, reason} -> {:error, {:json_decode_error, reason}}
        end

      {:ok, %Req.Response{status: 401}} ->
        {:error, :unauthorized}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, {:http_error, status, body}}

      {:error, reason} ->
        {:error, {:request_failed, reason}}
    end
  end

  defp make_api_request(path, access_token, params) when map_size(params) == 0 do
    # GET request
    url = "#{@api_url}#{path}?access_token=#{access_token}"

    case Req.get(url, receive_timeout: 30_000) do
      {:ok, %Req.Response{status: 200, body: body}} ->
        case decode_body(body) do
          {:ok, data} -> {:ok, data}
          {:error, reason} -> {:error, {:json_decode_error, reason}}
        end

      {:ok, %Req.Response{status: status}} ->
        {:error, {:http_error, status}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp make_api_request(path, access_token, params) do
    # POST request
    url = "#{@api_url}#{path}?access_token=#{access_token}"
    body = URI.encode_query(params)
    headers = [{"content-type", "application/x-www-form-urlencoded"}]

    case Req.post(url, body: body, headers: headers, receive_timeout: 30_000) do
      {:ok, %Req.Response{status: 200, body: response_body}} ->
        case decode_body(response_body) do
          {:ok, data} -> {:ok, data}
          {:error, reason} -> {:error, {:json_decode_error, reason}}
        end

      {:ok, %Req.Response{status: status}} ->
        {:error, {:http_error, status}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp get_or_create_user_from_paus(paus_user) do
    # Top-level PAuS fields
    email = paus_user["email"]
    username = paus_user["username"]
    image_url = paus_user["image_url"]

    # PAuS returns a list of accounts — pick the first active one
    accounts = paus_user["accounts"] || []
    account = Enum.find(accounts, &(&1["is_active"] == true)) || List.first(accounts) || %{}

    fullname = account["name"] || paus_user["name"]
    identifier = account["number"]
    group_name = account["group_name"]
    faculty_name = account["faculty_name"]
    unit_name = account["unit_name"]

    now = DateTime.utc_now() |> DateTime.truncate(:second)

    case Accounts.get_user_by_email(email) do
      nil ->
        user_attrs = %{
          email: email,
          username: username,
          fullname: fullname,
          identifier: identifier,
          user_image: image_url,
          user_type_id: resolve_paus_user_type(group_name),
          node_id: resolve_paus_node(group_name, faculty_name, unit_name),
          birth_date: parse_paus_date(account["birthdate"]),
          gender: map_paus_gender(account["gender"]),
          confirmed_at: now,
          registration_date: Date.utc_today(),
          last_login: now
        }

        case Accounts.create_user_from_oauth(user_attrs) do
          {:ok, user} ->
            user

          {:error, changeset} ->
            Logger.error("[PAuS] Failed to create user: #{inspect(changeset.errors)}")
            # Race-condition fallback
            Accounts.get_user_by_email(email)
        end

      user ->
        {:ok, updated} = Accounts.update_user_login(user, %{last_login: now})
        updated
    end
  end

  # ---------------------------------------------------------------------------
  # PAuS field resolvers
  # ---------------------------------------------------------------------------

  # Maps PAuS group_name to the corresponding MemberType id via slug.
  # "Mahasiswa" (student)  → member_verified
  # "Staf"     (staff)     → member_organization
  defp resolve_paus_user_type(group_name) do
    slug =
      case group_name do
        "Mahasiswa" -> "member_verified"
        "Staf" -> "member_organization"
        _ -> nil
      end

    with s when is_binary(s) <- slug,
         %{id: id} <- Repo.get_by(MemberType, slug: s) do
      id
    else
      _ ->
        Logger.warning("[PAuS] No MemberType found for group_name: #{inspect(group_name)}")
        nil
    end
  end

  # Staff always land on the default node (configured in system settings).
  defp resolve_paus_node("Staf", _faculty, _unit), do: get_paus_default_node_id()

  # Students: match faculty_name against node.name with a substring search.
  # e.g. faculty_name "Ilmu Komunikasi" matches node.name "Fakultas Ilmu Komunikasi".
  defp resolve_paus_node("Mahasiswa", faculty_name, _unit) when is_binary(faculty_name) do
    node =
      Repo.one(
        from n in Node,
          where: ilike(n.name, ^("%" <> faculty_name <> "%")),
          limit: 1
      )

    case node do
      %{id: id} ->
        id

      nil ->
        Logger.debug("[PAuS] No node matched faculty '#{faculty_name}', using default")
        get_paus_default_node_id()
    end
  end

  defp resolve_paus_node(_group, _faculty, _unit), do: get_paus_default_node_id()

  # Reads the default_node_id system setting and returns the matching Node id.
  defp get_paus_default_node_id do
    case Voile.Schema.System.get_setting_value("default_node_id", nil) do
      nil ->
        nil

      value when is_binary(value) ->
        case Integer.parse(value) do
          {int_id, ""} ->
            case Repo.get(Node, int_id) do
              %{id: id} -> id
              nil -> nil
            end

          _ ->
            nil
        end

      int when is_integer(int) ->
        case Repo.get(Node, int) do
          %{id: id} -> id
          nil -> nil
        end

      _ ->
        nil
    end
  end

  # Parses an ISO-8601 date string ("YYYY-MM-DD") into a Date struct.
  defp parse_paus_date(nil), do: nil

  defp parse_paus_date(date_str) when is_binary(date_str) do
    case Date.from_iso8601(date_str) do
      {:ok, date} -> date
      _ -> nil
    end
  end

  # Maps PAuS gender codes to display strings.
  # "L" = Laki-laki (Male), "P" = Perempuan (Female)
  defp map_paus_gender("L"), do: "male"
  defp map_paus_gender("P"), do: "female"
  defp map_paus_gender(_), do: nil

  defp mount_paus_user(session, socket) do
    Phoenix.Component.assign_new(socket, :paus_user, fn ->
      case session["paus_user"] do
        user when is_map(user) -> user
        _ -> nil
      end
    end)
  end

  # Req automatically JSON-decodes responses when Content-Type is application/json,
  # so the body arrives as a map. Fall back to Jason.decode/1 for plain binary bodies.
  defp decode_body(body) when is_map(body), do: {:ok, body}
  defp decode_body(body) when is_binary(body), do: Jason.decode(body)
  defp decode_body(_), do: {:error, :invalid_body}

  defp generate_state do
    :crypto.strong_rand_bytes(32)
    |> Base.url_encode64(padding: false)
  end
end
