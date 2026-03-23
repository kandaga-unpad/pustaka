defmodule VoileWeb.Live.Hooks.LocaleHook do
  @moduledoc """
  LiveView hook to maintain locale across LiveView mount/remount cycles.
  This ensures the locale set by the Locale plug persists during LiveView updates.
  """

  import Phoenix.Component

  @doc """
  on_mount callback to set the locale from session or conn assigns.
  This should be added to all live_session blocks in the router.
  """
  def on_mount(:set_locale, _params, session, socket) do
    # Get locale from session (set by the Locale plug)
    locale = session["locale"] || Gettext.get_locale(VoileWeb.Gettext)

    # Set the locale for this LiveView process and ensure application locale sync
    VoileWeb.Utils.Locale.put_locale(locale)

    {:cont, assign(socket, locale: locale)}
  end
end
