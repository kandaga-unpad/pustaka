defmodule Voile.Schema.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  alias Voile.Schema.Accounts.UserRole
  alias Voile.Schema.Master.MemberType
  alias Voile.Schema.System.Node

  @primary_key {:id, :binary_id, autogenerate: true}
  @derive {Phoenix.Param, key: :id}
  schema "users" do
    field :username, :string
    field :identifier, :decimal
    field :email, :string
    field :fullname, :string
    field :password, :string, virtual: true, redact: true
    field :hashed_password, :string, redact: true
    field :current_password, :string, virtual: true, redact: true
    field :confirmed_at, :utc_datetime
    field :authenticated_at, :utc_datetime, virtual: true
    field :user_image, :string
    field :social_media, :map, type: :jsonb
    field :groups, {:array, :string}
    field :last_login, :utc_datetime
    field :last_login_ip, :string

    belongs_to :user_role, UserRole
    belongs_to :user_type, MemberType, type: :binary_id
    belongs_to :node, Node

    field :twitter, :string, virtual: true
    field :facebook, :string, virtual: true
    field :linkedin, :string, virtual: true
    field :instagram, :string, virtual: true
    field :website, :string, virtual: true

    timestamps(type: :utc_datetime)
  end

  def changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [
      :username,
      :identifier,
      :email,
      :fullname,
      :user_role_id,
      :user_type_id,
      :password,
      :confirmed_at,
      :user_image,
      :groups,
      :node_id,
      :twitter,
      :facebook,
      :linkedin,
      :instagram,
      :website,
      :last_login,
      :last_login_ip
    ])
    |> put_social_media
    |> validate_length(:username, min: 3, max: 30)
    |> validate_username(opts)
    |> validate_email(opts)
    |> validate_password(opts)
  end

  @doc """
  A user changeset for registration.
  """
  def registration_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [
      :username,
      :identifier,
      :email,
      :fullname,
      :user_role_id,
      :user_type_id,
      :password,
      :confirmed_at,
      :user_image,
      :groups,
      :node_id,
      :twitter,
      :facebook,
      :linkedin,
      :instagram,
      :website,
      :last_login,
      :last_login_ip
    ])
    |> validate_email(opts)
    |> validate_password(opts)
  end

  def update_profile_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [
      :username,
      :identifier,
      :email,
      :fullname,
      :user_role_id,
      :user_type_id,
      :password,
      :confirmed_at,
      :user_image,
      :groups,
      :node_id,
      :twitter,
      :facebook,
      :linkedin,
      :instagram,
      :website,
      :last_login,
      :last_login_ip
    ])
    |> validate_email(opts)
  end

  def login_changeset(user, attrs) do
    user
    |> cast(attrs, [:last_login, :last_login_ip])
  end

  defp validate_email(changeset, opts) do
    changeset
    |> validate_required([:email])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must have the @ sign and no spaces")
    |> validate_length(:email, max: 160)
    |> maybe_validate_unique_email(opts)
  end

  defp validate_username(changeset, opts) do
    changeset
    |> validate_required([:username])
    |> validate_length(:username, min: 3, max: 30)
    |> maybe_validate_username_unique(opts)
  end

  defp validate_password(changeset, opts) do
    changeset
    |> validate_required([:password])
    |> validate_length(:password, min: 12, max: 72)
    |> maybe_hash_password(opts)
  end

  defp maybe_hash_password(changeset, opts) do
    hash_password? = Keyword.get(opts, :hash_password, true)
    password = get_change(changeset, :password)

    if hash_password? && password && changeset.valid? do
      changeset
      |> put_change(:hashed_password, Pbkdf2.hash_pwd_salt(password))
      |> delete_change(:password)
    else
      changeset
    end
  end

  defp maybe_validate_unique_email(changeset, opts) do
    if Keyword.get(opts, :validate_email, true) do
      changeset
      |> unsafe_validate_unique(:email, Voile.Repo)
      |> unique_constraint(:email)
    else
      changeset
    end
  end

  defp maybe_validate_username_unique(changeset, opts) do
    if Keyword.get(opts, :validate_username, true) do
      changeset
      |> unsafe_validate_unique(:username, Voile.Repo, message: "Username has already been taken")
      |> unique_constraint(:username)
    else
      changeset
    end
  end

  @doc """
  A user changeset for changing the email.
  """
  def email_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:email])
    |> validate_email(opts)
    |> case do
      %{changes: %{email: _}} = changeset -> changeset
      %{} = changeset -> add_error(changeset, :email, "did not change")
    end
  end

  @doc """
  A user changeset for changing the password.
  """
  def password_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:password])
    |> validate_confirmation(:password, message: "does not match password")
    |> validate_password(opts)
  end

  @doc """
  Confirms the account by setting `confirmed_at`.
  """
  def confirm_changeset(user) do
    change(user, confirmed_at: Voile.Migration.Common.utc_now_db())
  end

  @doc """
  A user changeset for onboarding migrated users.
  """
  def onboarding_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:password])
    |> validate_confirmation(:password, message: "does not match password")
    |> validate_password(opts)
    |> put_change(:confirmed_at, Voile.Migration.Common.utc_now_db())
  end

  def valid_password?(%Voile.Schema.Accounts.User{hashed_password: hashed_password}, password)
      when is_binary(hashed_password) and byte_size(password) > 0 do
    Pbkdf2.verify_pass(password, hashed_password)
  end

  def valid_password?(_, _) do
    Pbkdf2.no_user_verify()
    false
  end

  @doc """
  Validates the current password otherwise adds an error to the changeset.
  """
  def validate_current_password(changeset, password) do
    changeset = cast(changeset, %{current_password: password}, [:current_password])

    if valid_password?(changeset.data, password) do
      changeset
    else
      add_error(changeset, :current_password, "is not valid")
    end
  end

  defp put_social_media(changeset) do
    twitter = get_field(changeset, :twitter)
    facebook = get_field(changeset, :facebook)
    linkedin = get_field(changeset, :linkedin)
    instagram = get_field(changeset, :instagram)
    website = get_field(changeset, :website)

    social_media = %{
      "twitter" => twitter,
      "facebook" => facebook,
      "linkedin" => linkedin,
      "instagram" => instagram,
      "website" => website
    }

    put_change(changeset, :social_media, social_media)
  end
end
