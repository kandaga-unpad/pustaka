defmodule Voile.Plugin.Gettext do
  @moduledoc """
  Generates a Gettext backend for a Voile plugin.

  Plugins localize their UI by shipping standard Gettext translation files
  under `priv/gettext/<locale>/LC_MESSAGES/` in their own OTP application,
  plus this one-line backend module:

      defmodule VoileLockerLuggage.Gettext do
        use Voile.Plugin.Gettext, otp_app: :voile_locker_luggage
      end

  Voile discovers the backend by convention (`<PluginModule>.Gettext`) when
  the plugin is activated and keeps its locale in sync with the application
  locale managed by `VoileWeb.Utils.Locale`. Only locales supported by Voile
  are used; a plugin may propose additional locales in its pull request and
  they become live once added to Voile's `priv/gettext/` and
  `VoileWeb.Utils.Locale`.

  In plugin LiveViews and components:

      use Gettext, backend: VoileLockerLuggage.Gettext
  """

  defmacro __using__(opts) do
    otp_app = Keyword.fetch!(opts, :otp_app)

    quote do
      use Gettext.Backend, otp_app: unquote(otp_app)

      @doc "Marker: this backend is a Voile plugin backend."
      def __voile_plugin_gettext__, do: true
    end
  end

  @doc """
  Checks whether `module` is a backend generated via `use Voile.Plugin.Gettext`.
  """
  def plugin_backend?(module) when is_atom(module) do
    Code.ensure_loaded?(module) and
      function_exported?(module, :__voile_plugin_gettext__, 0) and
      module.__voile_plugin_gettext__()
  end

  def plugin_backend?(nil), do: false
end
