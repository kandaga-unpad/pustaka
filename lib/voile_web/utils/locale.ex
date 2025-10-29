defmodule VoileWeb.Utils.Locale do
  @moduledoc """
  Helper functions for locale management
  """

  @supported_locales Gettext.known_locales(VoileWeb.Gettext)
  @default_locale "id"

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
  end

  def put_locale(_locale), do: Gettext.put_locale(VoileWeb.Gettext, @default_locale)

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
