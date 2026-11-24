defmodule VoileWeb.Utils.Locale do
  @moduledoc """
  Helper functions for locale management
  """

  require Logger

  @supported_locales Gettext.known_locales(VoileWeb.Gettext)
  @default_locale "id"
  @plugin_backends_key {__MODULE__, :plugin_backends}

  @doc """
  Returns the list of supported locales
  """
  def supported_locales, do: @supported_locales

  @doc """
  Returns the default locale
  """
  def default_locale, do: @default_locale

  @doc """
  Returns the current locale
  """
  def get_locale do
    Gettext.get_locale(VoileWeb.Gettext)
  end

  @doc """
  Sets the locale
  """
  def put_locale(locale) when locale in @supported_locales do
    Gettext.put_locale(VoileWeb.Gettext, locale)

    if Code.ensure_loaded?(AtriumWeb.Gettext) do
      Gettext.put_locale(AtriumWeb.Gettext, locale)
    end

    plugin_gettext_backends()
    |> Enum.each(&Gettext.put_locale(&1, locale))

    :ok
  end

  def put_locale(_locale), do: put_locale(@default_locale)

  # ── Plugin Gettext registry ─────────────────────────────────────────────────

  @doc """
  Registers a plugin's Gettext backend so its locale stays in sync with the
  application locale. Idempotent per `{owner, backend}` pair. Backed by
  `:persistent_term`; writes only happen from the serialized plugin lifecycle
  calls, reads are concurrent.

  Locales the plugin ships that Voile does not support are ignored with a
  warning — a plugin proposes new locales in its pull request and they become
  live once the locale is added to Voile's `priv/gettext/` and
  `VoileWeb.Utils.Locale`.
  """
  def register_plugin_gettext(owner_module, backend)
      when is_atom(owner_module) and is_atom(backend) do
    unless Voile.Plugin.Gettext.plugin_backend?(backend) do
      raise ArgumentError,
            "#{inspect(backend)} is not a Voile plugin Gettext backend. " <>
              "It must be generated with `use Voile.Plugin.Gettext, otp_app: :<plugin_app>`."
    end

    ignored = Gettext.known_locales(backend) -- supported_locales()

    if ignored != [] do
      Logger.warning(
        "[Locale] #{inspect(backend)} ships locales Voile does not support " <>
          "(ignored until the community adds them): #{Enum.join(ignored, ", ")}"
      )
    end

    entry = %{owner: owner_module, backend: backend}

    :persistent_term.get(@plugin_backends_key, [])
    |> Enum.reject(&(&1.owner == owner_module and &1.backend == backend))
    |> List.insert_at(0, entry)
    |> then(&:persistent_term.put(@plugin_backends_key, &1))

    :ok
  end

  @doc "Removes all Gettext backends registered by a plugin module."
  def unregister_plugin_gettext(owner_module) when is_atom(owner_module) do
    :persistent_term.get(@plugin_backends_key, [])
    |> Enum.reject(&(&1.owner == owner_module))
    |> then(&:persistent_term.put(@plugin_backends_key, &1))

    :ok
  end

  @doc "Returns the Gettext backends of all active plugins with translations."
  def plugin_gettext_backends do
    :persistent_term.get(@plugin_backends_key, [])
    |> Enum.map(& &1.backend)
  end

  @doc """
  Returns locale display name
  """
  def locale_name("id"), do: "Bahasa Indonesia"
  def locale_name("en"), do: "English"
  def locale_name(_), do: "Unknown"

  @doc """
  Returns locale flag emoji
  """
  def locale_flag("id"), do: "🇮🇩"
  def locale_flag("en"), do: "🇬🇧"
  def locale_flag(_), do: "🌐"

  @doc """
  Returns all locales with their display names
  """
  def all_locales do
    @supported_locales
    |> Enum.map(fn locale ->
      %{
        code: locale,
        name: locale_name(locale),
        flag: locale_flag(locale)
      }
    end)
  end
end
