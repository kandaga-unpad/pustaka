defmodule VoileWeb.Plugs.Locale do
  @moduledoc """
  Plug for setting the locale based on:
  1. Query parameter (?locale=id)
  2. Session
  3. Accept-Language header
  4. Default locale (id - Indonesian)
  """
  import Plug.Conn

  @supported_locales Gettext.known_locales(VoileWeb.Gettext)
  @default_locale "id"

  def init(_opts), do: nil

  def call(conn, _opts) do
    # Ensure query params are fetched (if not already)
    conn =
      if conn.query_params == %Plug.Conn.Unfetched{},
        do: Plug.Conn.fetch_query_params(conn),
        else: conn

    locale =
      get_locale_from_params(conn) ||
        get_locale_from_session(conn) ||
        get_locale_from_header(conn) ||
        @default_locale

    # Ensure the locale is supported
    locale = if locale in @supported_locales, do: locale, else: @default_locale

    # Set the locale for Gettext
    Gettext.put_locale(VoileWeb.Gettext, locale)

    # Store locale in session for persistence
    conn
    |> put_session(:locale, locale)
    |> assign(:locale, locale)
  end

  # Get locale from query parameter
  defp get_locale_from_params(conn) do
    conn.query_params["locale"] || conn.params["locale"]
  end

  # Get locale from session
  defp get_locale_from_session(conn) do
    get_session(conn, :locale)
  end

  # Get locale from Accept-Language header
  defp get_locale_from_header(conn) do
    case get_req_header(conn, "accept-language") do
      [value | _] ->
        value
        |> String.split(",")
        |> Enum.map(&parse_language_option/1)
        |> Enum.sort(&(&1.quality > &2.quality))
        |> Enum.find(fn %{tag: tag} -> tag in @supported_locales end)
        |> case do
          %{tag: tag} -> tag
          nil -> nil
        end

      _ ->
        nil
    end
  end

  # Parse language option from Accept-Language header
  defp parse_language_option(string) do
    captures =
      ~r/^\s?(?<tag>[\w\-]+)(?:;q=(?<quality>[\d\.]+))?$/i
      |> Regex.named_captures(string)

    quality =
      case Float.parse(captures["quality"] || "1.0") do
        {quality, _} -> quality
        _ -> 1.0
      end

    %{tag: captures["tag"], quality: quality}
  end
end
