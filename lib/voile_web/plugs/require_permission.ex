defmodule VoileWeb.Plugs.RequirePermission do
  @moduledoc """
  Plug for checking user permission
  """

  import Plug.Conn
  import Phoenix.Controller

  alias Voile.Schema.Accounts

  def init(opts), do: opts

  def call(conn, opts) do
    resource = Keyword.get(opts, :resource)
    action = Keyword.get(opts, :action)

    current_user = conn.assigns[:current_user]

    if Accounts.has_permission?(current_user, resource, action) do
      conn
    else
      conn
      |> put_flash(:error, "You don't have permission to access this resource.")
      |> redirect(to: "/dashboard")
      |> halt()
    end
  end
end
