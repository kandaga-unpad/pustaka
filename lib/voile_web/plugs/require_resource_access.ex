defmodule VoileWeb.Plugs.RequireResourceAccess do
  @moduledoc """
  Plug for checking if user can access any operation on a resource.
  """

  import Plug.Conn
  import Phoenix.Controller

  alias Voile.Schema.Accounts

  def init(opts), do: opts

  def call(conn, opts) do
    resource = Keyword.get(opts, :resource)
    current_user = conn.assigns[:current_user]

    if Accounts.can_access_resource?(current_user, resource) do
      conn
    else
      conn
      |> put_flash(:error, "You don't have access to this resource.")
      |> redirect(to: "/dashboard")
      |> halt()
    end
  end
end
