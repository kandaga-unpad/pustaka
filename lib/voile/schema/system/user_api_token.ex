defmodule Voile.Schema.System.UserApiToken do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @token_length 32
  @hash_algorithm :sha256

  schema "user_api_tokens" do
    field :token, :string, virtual: true, redact: true
    field :hashed_token, :string, redact: true
    field :name, :string
    field :description, :string
    field :scopes, {:array, :string}, default: ["read"]
    field :last_used_at, :utc_datetime
    field :expires_at, :utc_datetime
    field :revoked_at, :utc_datetime
    field :ip_whitelist, {:array, :string}
    field :user_agent, :string
    field :last_used_ip, :string

    belongs_to :user, Voile.Schema.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc """
  Avaliable scopes for API tokens
  """
  def available_scopes do
    [
      "read",
      "write",
      "delete",
      "admin",
      "users:read",
      "users:write"
    ]
  end

  def create_changeset(api_token, attrs) do
    api_token
    |> cast(
      attrs,
      [
        :name,
        :description,
        :scopes,
        :expires_at,
        :ip_whitelist,
        :user_agent,
        :last_used_ip,
        :user_id,
        :hashed_token
      ]
    )
    |> validate_required([:user_id, :hashed_token])
    |> validate_scopes()
    |> validate_expiration()
  end

  def update_changeset(api_token, attrs) do
    api_token
    |> cast(attrs, [:name, :description, :scopes, :expires_at, :ip_whitelist])
    |> validate_scopes()
    |> validate_expiration()
  end

  defp validate_scopes(changeset) do
    changeset
    |> validate_required([:scopes])
    |> validate_subset(:scopes, available_scopes())
    |> validate_length(:scopes, min: 1)
  end

  defp validate_expiration(changeset) do
    case get_field(changeset, :expires_at) do
      nil ->
        changeset

      expires_at ->
        if DateTime.compare(expires_at, DateTime.utc_now()) == :lt do
          add_error(changeset, :expires_at, "must be in the future")
        else
          changeset
        end
    end
  end

  @doc """
  Generates a random token
  """
  def generate_token do
    :crypto.strong_rand_bytes(@token_length)
    |> Base.url_encode64(padding: false)
  end

  @doc """
  Hashes a token
  """
  def hash_token(token) do
    :crypto.hash(@hash_algorithm, token)
    |> Base.encode16(case: :lower)
  end

  @doc """
  Verifies a token
  """
  def verify_token(hashed_token, plain_token) do
    hash_token(plain_token) == hashed_token
  end

  @doc """
  Query for valid tokens
  """
  def valid_tokens_query do
    from t in __MODULE__,
      where: is_nil(t.revoked_at),
      where: is_nil(t.expires_at) or t.expires_at > ^DateTime.utc_now()
  end

  @doc """
  Checks if token is valid
  """
  def valid?(%__MODULE__{} = token) do
    is_nil(token.revoked_at) and
      (is_nil(token.expires_at) or DateTime.compare(token.expires_at, DateTime.utc_now()) == :gt)
  end

  @doc """
  Checks if token has required scope
  """
  def has_scope?(%__MODULE__{scopes: scopes}, required_scope) do
    "admin" in scopes or required_scope in scopes
  end
end
