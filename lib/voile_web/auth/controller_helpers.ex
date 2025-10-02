defmodule VoileWeb.Auth.ControllerHelpers do
  @moduledoc """
  Helper functions for authorization in Phoenix controllers.
  """

  alias VoileWeb.Auth.Authorization

  @doc """
  Authorize a user in a controller action.
  Raises UnauthorizedError if the user doesn't have permission.

  ## Examples

      def delete(conn, %{"id" => id}) do
        authorize!(conn, "collections.delete", scope: {:collection, id})
        # ... rest of the action
      end
  """
  def authorize!(conn, permission, opts \\ []) do
    user = conn.assigns[:current_user]

    if user do
      Authorization.authorize!(user, permission, opts)
      conn
    else
      raise Authorization.UnauthorizedError,
        permission: permission,
        user_id: nil
    end
  end

  @doc """
  Check if the current user has a permission.

  ## Examples

      if can?(conn, "collections.update", scope: {:collection, id}) do
        # Show edit button
      end
  """
  def can?(conn, permission, opts \\ []) do
    case conn.assigns[:current_user] do
      nil -> false
      user -> Authorization.can?(user, permission, opts)
    end
  end
end
