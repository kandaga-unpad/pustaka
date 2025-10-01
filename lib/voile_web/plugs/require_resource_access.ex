defmodule VoileWeb.Plugs.RequireResourceAccess do
  @moduledoc """
  Plug for checking if user can access any operation on a resource.
  Note: RBAC system removed - this now allows access for all authenticated users.
  """

  import Plug.Conn
  import Phoenix.Controller

  def init(opts), do: opts

  def call(conn, _opts) do
    current_user = conn.assigns[:current_user]

    if current_user do
      conn
    else
      conn
      |> put_flash(:error, "You must be logged in to access this resource.")
      |> redirect(to: "/dashboard")
      |> halt()
    end
  end
end
