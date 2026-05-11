defmodule Voile.PromEx do
  use PromEx, otp_app: :voile

  @impl true
  def plugins do
    [
      {PromEx.Plugins.Phoenix, router: VoileWeb.Router},
      {PromEx.Plugins.Ecto, repos: [Voile.Repo]},
      PromEx.Plugins.Application,
      PromEx.Plugins.Beam
    ]
  end
end
