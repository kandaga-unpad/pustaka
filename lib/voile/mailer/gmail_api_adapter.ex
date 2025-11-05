defmodule Voile.Mailer.GmailApiAdapter do
  @moduledoc """
  Custom Swoosh adapter for Gmail API using OAuth2 authentication.

  This adapter uses the Gmail API v1 with OAuth2 tokens instead of SMTP with app passwords.

  ## Configuration

      config :voile, Voile.Mailer,
        adapter: Voile.Mailer.GmailApiAdapter,
        access_token: System.get_env("VOILE_GMAIL_ACCESS_TOKEN"),
        # Optional: for token refresh
        refresh_token: System.get_env("VOILE_GMAIL_REFRESH_TOKEN"),
        client_id: System.get_env("VOILE_GMAIL_CLIENT_ID"),
        client_secret: System.get_env("VOILE_GMAIL_CLIENT_SECRET")

  ## Getting Initial Tokens

  You can get tokens using the GmailAuth module:

      # Get authorization URL
      url = Voile.Mailer.GmailAuth.authorization_url()

      # After user authorizes, exchange code for tokens
      {:ok, tokens} = Voile.Mailer.GmailAuth.get_tokens(code)

  Store the access_token and refresh_token in your environment variables.
  """

  use Swoosh.Adapter

  alias Swoosh.Email
  require Logger

  @gmail_api_url "https://gmail.googleapis.com/gmail/v1/users/me/messages/send"

  @impl Swoosh.Adapter
  def deliver(%Email{} = email, config) do
    access_token = get_access_token(config)

    case build_message(email) do
      {:ok, raw_message} ->
        send_via_api(raw_message, access_token)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp get_access_token(config) do
    # First check if we have a valid access token
    case Keyword.get(config, :access_token) do
      nil ->
        # Try to refresh token
        refresh_access_token(config)

      token ->
        token
    end
  end

  defp refresh_access_token(config) do
    refresh_token = Keyword.get(config, :refresh_token)
    client_id = Keyword.get(config, :client_id)
    client_secret = Keyword.get(config, :client_secret)

    if refresh_token && client_id && client_secret do
      case Voile.Mailer.GmailAuth.refresh_token(refresh_token, client_id, client_secret) do
        {:ok, new_access_token} ->
          Logger.info("Gmail access token refreshed successfully")
          new_access_token

        {:error, reason} ->
          Logger.error("Failed to refresh Gmail token: #{inspect(reason)}")
          raise "Gmail token refresh failed: #{inspect(reason)}"
      end
    else
      raise "No valid access token or refresh token configuration found"
    end
  end

  defp build_message(%Email{} = email) do
    # Build RFC 2822 message
    message = """
    From: #{format_email(email.from)}
    To: #{format_recipients(email.to)}
    #{if email.cc && email.cc != [], do: "Cc: #{format_recipients(email.cc)}\n", else: ""}Subject: #{email.subject}
    MIME-Version: 1.0
    Content-Type: #{content_type(email)}

    #{email_body(email)}
    """

    # Base64url encode the message
    encoded = message |> Base.url_encode64(padding: false)
    {:ok, encoded}
  rescue
    e ->
      Logger.error("Failed to build email message: #{inspect(e)}")
      {:error, "Failed to build message: #{Exception.message(e)}"}
  end

  defp format_email({name, email}) when is_binary(name) and name != "" do
    ~s("#{name}" <#{email}>)
  end

  defp format_email({_name, email}), do: email
  defp format_email(email) when is_binary(email), do: email

  defp format_recipients(recipients) when is_list(recipients) do
    recipients
    |> Enum.map(&format_email/1)
    |> Enum.join(", ")
  end

  defp content_type(%Email{html_body: html, text_body: text})
       when not is_nil(html) and not is_nil(text) do
    "multipart/alternative; boundary=\"boundary-string\""
  end

  defp content_type(%Email{html_body: html}) when not is_nil(html) do
    "text/html; charset=UTF-8"
  end

  defp content_type(_email) do
    "text/plain; charset=UTF-8"
  end

  defp email_body(%Email{html_body: html, text_body: text})
       when not is_nil(html) and not is_nil(text) do
    """
    --boundary-string
    Content-Type: text/plain; charset=UTF-8

    #{text}

    --boundary-string
    Content-Type: text/html; charset=UTF-8

    #{html}

    --boundary-string--
    """
  end

  defp email_body(%Email{html_body: html}) when not is_nil(html), do: html
  defp email_body(%Email{text_body: text}) when not is_nil(text), do: text
  defp email_body(_email), do: ""

  defp send_via_api(raw_message, access_token) do
    body = Jason.encode!(%{raw: raw_message})

    headers = [
      {"Authorization", "Bearer #{access_token}"},
      {"Content-Type", "application/json"}
    ]

    case Req.post(@gmail_api_url, body: body, headers: headers) do
      {:ok, %{status: 200, body: response}} ->
        Logger.info("Email sent successfully via Gmail API: #{inspect(response)}")
        {:ok, %{id: response["id"]}}

      {:ok, %{status: status, body: body}} ->
        Logger.error("Gmail API error (#{status}): #{inspect(body)}")
        {:error, "Gmail API returned status #{status}: #{inspect(body)}"}

      {:error, reason} ->
        Logger.error("Failed to send email via Gmail API: #{inspect(reason)}")
        {:error, reason}
    end
  end
end
