defmodule VoileWeb.PausAuthController do
  use VoileWeb, :controller
  alias VoileWeb.UserAuthPaus

  def request(conn, _params) do
    UserAuthPaus.request(conn)
  end

  def callback(conn, _params) do
    UserAuthPaus.callback(conn)
  end
end
