defmodule VoileWeb.Plugs.Authorization do
  @moduledoc """
  Plug for authorization in Phoenix controllers.

  This plug checks if the current user has a specific permission before allowing
  access to a controller action. It can handle both global and scoped permissions.

  ## Usage

  ### In a controller pipeline:

      pipeline :require_admin do
        plug VoileWeb.Plugs.Authorization, permission: "system.settings"
      end

  ### In a controller action:

      defmodule VoileWeb.CollectionController do
        use VoileWeb, :controller

        # Check permission for all actions
        plug VoileWeb.Plugs.Authorization, permission: "collections.read"

        # Check permission for specific actions
        plug VoileWeb.Plugs.Authorization,
          permission: "collections.update"
          when action in [:edit, :update]

        # Check scoped permission (gets ID from params)
        plug VoileWeb.Plugs.Authorization,
          permission: "collections.delete",
          scope: {:collection, :id}
          when action in [:delete]

        def index(conn, _params), do: render(conn, :index)
        def edit(conn, _params), do: render(conn, :edit)
        def delete(conn, _params), do: send_resp(conn, :no_content, "")
      end

  ## Options

    * `:permission` (required) - The permission name to check (e.g., "collections.update")
    * `:scope` (optional) - The permission scope, can be:
      - `nil` - Global permission (default)
      - `{:collection, :id}` - Gets collection_id from params[:id]
      - `{:item, :item_id}` - Gets item_id from params[:item_id]
      - Any other tuple that matches your authorization scopes

  ## Responses

    * `401 Unauthorized` - If user is not authenticated
    * `403 Forbidden` - If user doesn't have the required permission
  """

  import Plug.Conn
  import Phoenix.Controller
  alias VoileWeb.Auth.Authorization

  def init(opts), do: opts

  def call(conn, opts) do
    permission = Keyword.fetch!(opts, :permission)
    scope = get_scope(conn, opts)

    case conn.assigns[:current_scope] do
      %{user: user} when not is_nil(user) ->
        if Authorization.can?(user, permission, scope: scope) do
          conn
        else
          conn
          |> put_status(:forbidden)
          |> json(%{error: "Insufficient permissions"})
          |> halt()
        end

      _ ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Authentication required"})
        |> halt()
    end
  end

  defp get_scope(conn, opts) do
    case Keyword.get(opts, :scope) do
      nil ->
        nil

      {resource_type, param_name} when is_atom(param_name) ->
        case conn.params[to_string(param_name)] do
          nil -> nil
          id -> {resource_type, id}
        end

      scope ->
        scope
    end
  end
end
