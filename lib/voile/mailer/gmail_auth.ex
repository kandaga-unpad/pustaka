defmodule Voile.Mailer.GmailAuth do
  @moduledoc """
  Helper module for Gmail OAuth2 authentication flow.

  This module helps you obtain and refresh OAuth2 tokens for Gmail API.

  ## Getting Initial Tokens

  1. Get the authorization URL and visit it in a browser:

      iex> Voile.Mailer.GmailAuth.authorization_url()

  2. After user authorizes, you'll get a code in the redirect URL

  3. Exchange the code for tokens:

      iex> {:ok, tokens} = Voile.Mailer.GmailAuth.get_tokens("YOUR_CODE_HERE")
      iex> IO.inspect(tokens)
      %{
        "access_token" => "...",
        "refresh_token" => "...",
        "expires_in" => 3599,
        "scope" => "https://www.googleapis.com/auth/gmail.send",
        "token_type" => "Bearer"
      }

  4. Store these in your environment variables:

      export GMAIL_ACCESS_TOKEN="..."
      export GMAIL_REFRESH_TOKEN="..."
  """

  require Logger

  @auth_url "https://accounts.google.com/o/oauth2/v2/auth"
  @token_url "https://oauth2.googleapis.com/token"
  @scope "https://www.googleapis.com/auth/gmail.send"

  @doc """
  Get the client ID from environment or config.
  """
  def client_id do
    System.get_env("VOILE_GMAIL_CLIENT_ID") ||
      Application.get_env(:voile, Voile.Mailer)[:client_id] ||
      raise "VOILE_GMAIL_CLIENT_ID not configured"
  end

  @doc """
  Get the client secret from environment or config.
  """
  def client_secret do
    System.get_env("VOILE_GMAIL_CLIENT_SECRET") ||
      Application.get_env(:voile, Voile.Mailer)[:client_secret] ||
      raise "VOILE_GMAIL_CLIENT_SECRET not configured"
  end

  @doc """
  Get the redirect URI from environment or config.
  Defaults to http://localhost:4000/auth/gmail/callback for development.
  Note: This is different from the Google OAuth login callback (/auth/google/callback)
  """
  def redirect_uri do
    System.get_env("VOILE_GMAIL_REDIRECT_URI") ||
      Application.get_env(:voile, Voile.Mailer)[:redirect_uri] ||
      "http://localhost:4000/auth/gmail/callback"
  end

  @doc """
  Generate the OAuth2 authorization URL.

  Visit this URL in a browser to authorize the application.
  After authorization, you'll be redirected with a code parameter.
  """
  def authorization_url do
    params =
      URI.encode_query(%{
        client_id: client_id(),
        redirect_uri: redirect_uri(),
        scope: @scope,
        response_type: "code",
        access_type: "offline",
        prompt: "consent"
      })

    "#{@auth_url}?#{params}"
  end

  @doc """
  Exchange an authorization code for access and refresh tokens.

  ## Example

      {:ok, tokens} = Voile.Mailer.GmailAuth.get_tokens("4/0AeanS...")

  Returns:

      {:ok, %{
        "access_token" => "...",
        "refresh_token" => "...",
        "expires_in" => 3599,
        "scope" => "...",
        "token_type" => "Bearer"
      }}
  """
  def get_tokens(code) do
    body = %{
      code: code,
      client_id: client_id(),
      client_secret: client_secret(),
      redirect_uri: redirect_uri(),
      grant_type: "authorization_code"
    }

    case Req.post(@token_url, form: body) do
      {:ok, %{status: 200, body: tokens}} ->
        {:ok, tokens}

      {:ok, %{status: status, body: body}} ->
        Logger.error("Failed to get tokens (#{status}): #{inspect(body)}")
        {:error, "Token request failed: #{inspect(body)}"}

      {:error, reason} ->
        Logger.error("Failed to request tokens: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Refresh an access token using a refresh token.

  ## Example

      {:ok, new_access_token} = Voile.Mailer.GmailAuth.refresh_token(
        refresh_token,
        client_id,
        client_secret
      )
  """
  def refresh_token(refresh_token, client_id \\ nil, client_secret \\ nil) do
    client_id = client_id || client_id()
    client_secret = client_secret || client_secret()

    body = %{
      refresh_token: refresh_token,
      client_id: client_id,
      client_secret: client_secret,
      grant_type: "refresh_token"
    }

    case Req.post(@token_url, form: body) do
      {:ok, %{status: 200, body: %{"access_token" => access_token}}} ->
        {:ok, access_token}

      {:ok, %{status: status, body: body}} ->
        Logger.error("Failed to refresh token (#{status}): #{inspect(body)}")
        {:error, "Token refresh failed: #{inspect(body)}"}

      {:error, reason} ->
        Logger.error("Failed to refresh token: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Interactive helper to walk through the OAuth2 flow in IEx.

  ## Usage

      iex> Voile.Mailer.GmailAuth.interactive_setup()
  """
  def interactive_setup do
    IO.puts("\n=== Gmail API OAuth2 Setup ===\n")
    IO.puts("Step 1: Visit this URL in your browser:\n")
    url = authorization_url()
    IO.puts(url)
    IO.puts("\n")
    IO.puts("Step 2: After authorizing, copy the 'code' parameter from the redirect URL")
    code = IO.gets("Paste the code here: ") |> String.trim()

    IO.puts("\nStep 3: Exchanging code for tokens...")

    case get_tokens(code) do
      {:ok, tokens} ->
        IO.puts("\n✓ Success! Here are your tokens:\n")
        IO.puts("Access Token: #{tokens["access_token"]}")
        IO.puts("Refresh Token: #{tokens["refresh_token"]}")
        IO.puts("\nStep 4: Add these to your environment (.env or config):\n")
        IO.puts("export GMAIL_ACCESS_TOKEN=\"#{tokens["access_token"]}\"")
        IO.puts("export GMAIL_REFRESH_TOKEN=\"#{tokens["refresh_token"]}\"")
        IO.puts("export GMAIL_CLIENT_ID=\"#{client_id()}\"")
        IO.puts("export GMAIL_CLIENT_SECRET=\"#{client_secret()}\"")
        IO.puts("\nOr for production, set these environment variables in your deployment.\n")
        {:ok, tokens}

      {:error, reason} ->
        IO.puts("\n✗ Failed to get tokens: #{inspect(reason)}")
        {:error, reason}
    end
  end
end
