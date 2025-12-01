defmodule VoileWeb.API.V1.UserApiTokenController do
  use VoileWeb, :controller
  use PhoenixSwagger

  alias Voile.Schema.System
  alias VoileWeb.Auth.Authorization

  action_fallback VoileWeb.API.FallbackController

  # Helper function to get current user from either web or API authentication
  defp get_current_user(conn) do
    # Try API authentication first (conn.assigns.current_user)
    # Fall back to web authentication (conn.assigns.current_scope.user)
    conn.assigns[:current_user] || conn.assigns.current_scope.user
  end

  swagger_path :index do
    get("/v1/tokens")
    summary("List API tokens")
    description("Returns a list of API tokens for the authenticated user")
    produces("application/json")
    tag("API Tokens")
    security([%{Bearer: []}])

    response(200, "OK", Schema.ref(:UserApiTokensResponse))
    response(401, "Unauthorized")
    response(500, "Internal Server Error")
  end

  def index(conn, _params) do
    current_user = get_current_user(conn)

    tokens = System.list_user_api_tokens(current_user)

    conn
    |> put_view(VoileWeb.API.V1.UserApiTokenJson)
    |> render(:index, tokens: tokens)
  end

  swagger_path :create do
    post("/v1/tokens")
    summary("Create API token")
    description("Creates a new API token for the authenticated user")
    produces("application/json")
    consumes("application/json")
    tag("API Tokens")
    security([%{Bearer: []}])

    parameters do
      token(:body, Schema.ref(:UserApiTokenInput), "Token parameters", required: true)
    end

    response(201, "Created", Schema.ref(:UserApiTokenResponse))
    response(400, "Bad Request")
    response(401, "Unauthorized")
    response(422, "Unprocessable Entity", Schema.ref(:ErrorResponse))
    response(500, "Internal Server Error")
  end

  def create(conn, %{"token" => token_params}) do
    current_user = get_current_user(conn)

    with {:ok, token, plain_token} <-
           System.create_api_token(current_user, token_params) do
      conn
      |> put_view(VoileWeb.API.V1.UserApiTokenJson)
      |> put_status(:created)
      |> render(:show, token: token, plain_token: plain_token)
    end
  end

  swagger_path :show do
    get("/v1/tokens/{id}")
    summary("Get API token")

    description(
      "Returns details of a specific API token. Only the token creator or super admins can view token details."
    )

    produces("application/json")
    tag("API Tokens")
    security([%{Bearer: []}])

    parameters do
      id(:path, :string, "Token ID", required: true, format: "uuid")
    end

    response(200, "OK", Schema.ref(:UserApiTokenResponse))
    response(401, "Unauthorized")
    response(404, "Not Found")
    response(500, "Internal Server Error")
  end

  def show(conn, %{"id" => id}) do
    current_user = get_current_user(conn)

    with token <- System.get_api_token(id),
         true <-
           token &&
             (token.user_id == current_user.id || Authorization.is_super_admin?(current_user)) do
      conn
      |> put_view(VoileWeb.API.V1.UserApiTokenJson)
      |> render(:show, token: token)
    else
      _ -> {:error, :not_found}
    end
  end

  swagger_path :update do
    put("/v1/tokens/{id}")
    summary("Update API token")

    description(
      "Updates an existing API token. Only the token creator or super admins can perform this action."
    )

    produces("application/json")
    consumes("application/json")
    tag("API Tokens")
    security([%{Bearer: []}])

    parameters do
      id(:path, :string, "Token ID", required: true, format: "uuid")

      token(:body, Schema.ref(:UserApiTokenUpdateInput), "Token update parameters",
        required: true
      )
    end

    response(200, "OK", Schema.ref(:UserApiTokenResponse))
    response(400, "Bad Request")
    response(401, "Unauthorized")
    response(404, "Not Found")
    response(422, "Unprocessable Entity", Schema.ref(:ErrorResponse))
    response(500, "Internal Server Error")
  end

  def update(conn, %{"id" => id, "token" => token_params}) do
    current_user = get_current_user(conn)

    with token <- System.get_api_token(id),
         true <-
           token &&
             (token.user_id == current_user.id || Authorization.is_super_admin?(current_user)),
         {:ok, token} <- System.update_api_token(token, token_params) do
      conn
      |> put_view(VoileWeb.API.V1.UserApiTokenJson)
      |> render(:show, token: token)
    else
      false -> {:error, :not_found}
      {:error, changeset} -> {:error, changeset}
    end
  end

  swagger_path :delete do
    PhoenixSwagger.Path.delete("/v1/tokens/{id}")
    summary("Revoke API token")

    description(
      "Revokes (deletes) an API token. Only the token creator or super admins can perform this action."
    )

    produces("application/json")
    tag("API Tokens")
    security([%{Bearer: []}])

    parameters do
      id(:path, :string, "Token ID", required: true, format: "uuid")
    end

    response(204, "No Content")
    response(401, "Unauthorized")
    response(404, "Not Found")
    response(500, "Internal Server Error")
  end

  def delete(conn, %{"id" => id}) do
    current_user = get_current_user(conn)

    with token <- System.get_api_token(id),
         true <-
           token &&
             (token.user_id == current_user.id || Authorization.is_super_admin?(current_user)),
         {:ok, _token} <- System.revoke_api_token(token) do
      send_resp(conn, :no_content, "")
    else
      _ -> {:error, :not_found}
    end
  end

  swagger_path :rotate do
    post("/v1/tokens/{user_api_token_id}/rotate")
    summary("Rotate API token")

    description(
      "Rotates an API token, generating a new token value while keeping the same ID and settings. Only the token creator or super admins can perform this action."
    )

    produces("application/json")
    tag("API Tokens")
    security([%{Bearer: []}])

    parameters do
      user_api_token_id(:path, :string, "Token ID", required: true, format: "uuid")
    end

    response(200, "OK", Schema.ref(:UserApiTokenResponse))
    response(401, "Unauthorized")
    response(404, "Not Found")
    response(500, "Internal Server Error")
  end

  def rotate(conn, %{"user_api_token_id" => id}) do
    current_user = get_current_user(conn)

    with token <- System.get_api_token(id),
         true <-
           token &&
             (token.user_id == current_user.id || Authorization.is_super_admin?(current_user)),
         {:ok, {new_token, plain_token}} <- System.rotate_api_token(token) do
      conn
      |> put_view(VoileWeb.API.V1.UserApiTokenJson)
      |> render(:show, token: new_token, plain_token: plain_token)
    else
      _ -> {:error, :not_found}
    end
  end

  def swagger_definitions do
    %{
      UserApiToken:
        swagger_schema do
          title("UserApiToken")
          description("An API token for user authentication")

          properties do
            id(:string, "Unique identifier (UUID)", required: true, format: "uuid")
            name(:string, "Token name", required: true)
            description(:string, "Token description")

            scopes(
              :array,
              "Token scopes - available options: read, write, delete, admin, users:read, users:write",
              items: %{type: :string},
              required: true,
              enum: ["read", "write", "delete", "admin", "users:read", "users:write"]
            )

            last_used_at(:string, "Last used timestamp", format: "date-time")
            last_used_ip(:string, "Last used IP address")
            expires_at(:string, "Expiration timestamp", format: "date-time")
            revoked_at(:string, "Revocation timestamp", format: "date-time")
            is_active(:boolean, "Whether the token is active", required: true)
            inserted_at(:string, "Creation timestamp", format: "date-time", required: true)
            updated_at(:string, "Last update timestamp", format: "date-time", required: true)
          end
        end,
      UserApiTokenInput:
        swagger_schema do
          title("UserApiTokenInput")
          description("Input schema for creating a new API token")

          properties do
            name(:string, "Token name", required: true)
            description(:string, "Token description")

            scopes(
              :array,
              "Token scopes - available options: read, write, delete, admin, users:read, users:write",
              items: %{type: :string},
              required: true,
              enum: ["read", "write", "delete", "admin", "users:read", "users:write"]
            )

            expires_at(:string, "Expiration timestamp", format: "date-time")
            ip_whitelist(:array, "IP whitelist", items: %{type: :string})
          end
        end,
      UserApiTokenUpdateInput:
        swagger_schema do
          title("UserApiTokenUpdateInput")
          description("Input schema for updating an API token")

          properties do
            name(:string, "Token name")
            description(:string, "Token description")

            scopes(
              :array,
              "Token scopes - available options: read, write, delete, admin, users:read, users:write",
              items: %{type: :string},
              enum: ["read", "write", "delete", "admin", "users:read", "users:write"]
            )

            expires_at(:string, "Expiration timestamp", format: "date-time")
            ip_whitelist(:array, "IP whitelist", items: %{type: :string})
          end
        end,
      UserApiTokenResponse:
        swagger_schema do
          title("UserApiTokenResponse")
          description("Response containing a single API token")

          properties do
            data(Schema.ref(:UserApiToken), "Token data", required: true)
            token(:string, "Plain token value (only returned on creation/rotation)")
            warning(:string, "Warning message about token security")
          end
        end,
      UserApiTokensResponse:
        swagger_schema do
          title("UserApiTokensResponse")
          description("Response containing a list of API tokens")

          properties do
            data(:array, "List of tokens", items: Schema.ref(:UserApiToken), required: true)
          end
        end
    }
  end
end
