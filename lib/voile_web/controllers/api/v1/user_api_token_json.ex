defmodule VoileWeb.API.V1.UserApiTokenJson do
  alias Voile.Schema.System.UserApiToken

  def index(%{tokens: tokens}) do
    %{
      data: for(token <- tokens, do: data(token))
    }
  end

  def show(%{token: token, plain_token: plain_token}) do
    %{
      data: data(token),
      token: plain_token,
      warning: "This is the only time the token will be shown. Please store it securely."
    }
  end

  def show(%{token: token}) do
    %{data: data(token)}
  end

  defp data(%UserApiToken{} = token) do
    %{
      id: token.id,
      name: token.name,
      description: token.description,
      scopes: token.scopes,
      last_used_at: token.last_used_at,
      last_used_ip: token.last_used_ip,
      expires_at: token.expires_at,
      revoked_at: token.revoked_at,
      is_active: UserApiToken.valid?(token),
      inserted_at: token.inserted_at,
      updated_at: token.updated_at
    }
  end
end
