defmodule VoileWeb.Plugs.Authorize do
  @moduledoc """
  Controller plug to authorize actions based on permissions.

  Usage in a controller:

      plug VoileWeb.Plugs.Authorize, permissions: %{
        new: ["metadata.manage"],
        create: ["metadata.manage"],
        edit: ["metadata.manage", "metadata.edit"],
        update: ["metadata.manage", "metadata.edit"],
        delete: ["metadata.manage"]
      }

  If an action is not present in the permissions map, the plug is a no-op.
  The plug logs authorization attempts (user id, action, required permissions,
  and whether the attempt was allowed).
  """

  require Logger
  import Plug.Conn

  alias VoileWeb.Auth.Authorization

  def init(opts), do: opts

  def call(conn, opts) do
    perms_map = Keyword.get(opts, :permissions, %{})
    action = conn.private[:phoenix_action]

    required_perms = Map.get(perms_map, action)

    # If no permissions configured for this action, allow through
    if is_nil(required_perms) do
      conn
    else
      user_id =
        conn.assigns[:current_scope] && conn.assigns[:current_scope].user &&
          conn.assigns[:current_scope].user.id

      allowed = Authorization.authorize_any?(conn, required_perms)

      Logger.metadata(user_id: user_id, action: action)

      Logger.info("authorization_attempt", %{
        user_id: user_id,
        action: action,
        required: required_perms,
        allowed: allowed
      })

      if allowed do
        conn
      else
        Logger.warning("authorization_denied", %{
          user_id: user_id,
          action: action,
          required: required_perms
        })

        # Return a 403 Forbidden response rather than raising
        conn = put_status(conn, :forbidden)

        format = Phoenix.Controller.get_format(conn) || "html"

        case format do
          "json" ->
            body = VoileWeb.ErrorJSON.render("403.json", %{})
            json = Jason.encode!(body)

            conn
            |> put_resp_content_type("application/json")
            |> send_resp(403, json)

          _ ->
            message = VoileWeb.ErrorHTML.render("403.html", %{})

            conn
            |> put_resp_content_type("text/plain; charset=utf-8")
            |> send_resp(403, to_string(message))
        end
      end
    end
  end
end
