defmodule VoileWeb.API.InfoController do
  use VoileWeb, :controller

  action_fallback VoileWeb.API.FallbackController

  def info(conn, _params) do
    info = %{
      app_name: "Voile",
      version: "0.1.0",
      description: "Voile API Information",
      url: "https://github.com/curatorian/voile"
    }

    json(conn, info)
  end
end
