defmodule Voile.Schema.Accounts do
  @moduledoc """
  The Accounts context.
  """

  import Ecto.Query, warn: false
  alias Voile.Repo

  alias Voile.Schema.Accounts.{User, UserToken, UserNotifier}

  # Helper to ensure returned user structs have common associations preloaded
  defp preload_user_assocs(nil), do: nil
  defp preload_user_assocs(%User{} = user), do: Repo.preload(user, [:user_type])

  ## Database getters

  @doc """
  Gets a user by email.

  ## Examples

      iex> get_user_by_email("foo@example.com")
      %User{}

      iex> get_user_by_email("unknown@example.com")
      nil

  """
  def get_user_by_email(email) when is_binary(email) do
    Repo.get_by(User, email: email) |> preload_user_assocs()
  end

  @doc """
  Gets a user by email and password.

  ## Examples

      iex> get_user_by_email_and_password("foo@example.com", "correct_password")
      %User{}

      iex> get_user_by_email_and_password("foo@example.com", "invalid_password")
      nil

  """
  def get_user_by_email_and_password(email, password)
      when is_binary(email) and is_binary(password) do
    user = Repo.get_by(User, email: email)
    if User.valid_password?(user, password), do: preload_user_assocs(user)
  end

  @doc """
  Get a user by email or register it it's doesn't exist.
  """
  def get_user_by_email_or_register(user) when is_map(user) do
    case Repo.get_by(User, email: user["email"]) do
      nil ->
        pw = :crypto.strong_rand_bytes(30) |> Base.encode64(padding: false)
        username = String.split(user["email"], "@") |> hd
        profile_picture = user["picture"] || "/images/default_profile.png"
        fullname = "#{user["given_name"]} #{user["family_name"]}"

        {:ok, user} =
          register_user(%{
            email: user["email"],
            username: username,
            fullname: fullname,
            password: pw,
            user_image: profile_picture,
            user_role_id: 16,
            confirmed_at:
              if(user["email_verified"], do: DateTime.utc_now() |> DateTime.to_naive(), else: nil)
          })

        user

      user ->
        user
    end
  end

  def get_user_by_identifier(nil), do: nil

  def get_user_by_identifier(identifier) when is_binary(identifier) do
    case Integer.parse(identifier) do
      {id, ""} ->
        Repo.get_by(User, identifier: id) |> preload_user_assocs()

      :error ->
        Repo.get_by(User, identifier: identifier) |> preload_user_assocs()
    end
  end

  @doc """
  Gets all users.
  """
  def list_users() do
    Repo.all(from u in User, preload: [:user_role], order_by: [desc: u.inserted_at])
  end

  @doc """
  Gets all users with paginated results
  """
  def list_users_paginated(page \\ 1, per_page \\ 10) do
    offset = (page - 1) * per_page

    query =
      from u in User,
        preload: [:user_role, :user_type],
        order_by: [desc: u.inserted_at],
        limit: ^per_page,
        offset: ^offset

    users = Repo.all(query)

    total_count = Repo.aggregate(User, :count, :id)
    total_pages = div(total_count + per_page - 1, per_page)
    {users, total_pages}
  end

  @doc """
  Gets a single user.

  Raises `Ecto.NoResultsError` if the User does not exist.

      limit: ^per_page,
      offset: ^offset
    )
  end

  @doc \"""
  Gets a single user.

  Raises `Ecto.NoResultsError` if the User does not exist.

  ## Examples

      iex> get_user!(123)
      %User{}

      iex> get_user!(456)
      ** (Ecto.NoResultsError)

  """
  def get_user!(id) do
    User
    |> Repo.get!(id)
    |> Repo.preload([:user_role, :user_type])
  end

  @doc """
  Create a new User.
  """
  def create_user(attrs) do
    %User{}
    |> User.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Delete a single user.
  """
  def delete_user(%User{} = user) do
    Repo.delete(user)
  end

  @doc """
  Changeset for user.
  """
  def change_user(%User{} = user, attrs \\ %{}) do
    User.changeset(user, attrs)
  end

  @doc """
  Update an existing user data.
  """
  def update_user(%User{} = user, attrs) do
    user
    |> User.changeset(attrs)
    |> Repo.update()
  end

  def update_profile_user(%User{} = user, attrs) do
    user
    |> User.update_profile_changeset(attrs)
    |> Repo.update()
    |> case do
      {:ok, user} ->
        {:ok, Repo.preload(user, [:user_role, :user_type])}

      error ->
        error
    end
  end

  def update_user_login(%User{} = user, attrs) do
    user
    |> User.login_changeset(attrs)
    |> Repo.update()
  end

  ## User registration

  @doc """
  Registers a user.

  ## Examples

      iex> register_user(%{field: value})
      {:ok, %User{}}

      iex> register_user(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def register_user(attrs) do
    %User{}
    |> User.registration_changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, user} ->
        {:ok, Repo.preload(user, [:user_role, :user_type])}

      error ->
        error
    end
  end

  @doc """
  Checks whether the user is in sudo mode.

  The user is in sudo mode when the last authentication was done no further
  than 20 minutes ago. The limit can be given as second argument in minutes.
  """
  def sudo_mode?(user, minutes \\ -20)

  def sudo_mode?(%User{authenticated_at: ts}, minutes) when is_struct(ts, DateTime) do
    target_time = DateTime.utc_now() |> DateTime.add(minutes, :minute)
    DateTime.after?(ts, target_time)
  end

  def sudo_mode?(_user, _minutes), do: false

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking user changes.

  ## Examples

      iex> change_user_registration(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_registration(%User{} = user, attrs \\ %{}) do
    User.registration_changeset(user, attrs, hash_password: false, validate_email: false)
  end

  ## Settings

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user email.

  ## Examples

      iex> change_user_email(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_email(user, attrs \\ %{}) do
    User.email_changeset(user, attrs, validate_email: false)
  end

  @doc """
  Emulates that the email will change without actually changing
  it in the database.

  ## Examples

      iex> apply_user_email(user, "valid password", %{email: ...})
      {:ok, %User{}}

      iex> apply_user_email(user, "invalid password", %{email: ...})
      {:error, %Ecto.Changeset{}}

  """
  def apply_user_email(user, password, attrs) do
    user
    |> User.email_changeset(attrs)
    |> User.validate_current_password(password)
    |> Ecto.Changeset.apply_action(:update)
  end

  @doc """
  Updates the user email using the given token.

  If the token matches, the user email is updated and the token is deleted.
  The confirmed_at date is also updated to the current time.
  """
  def update_user_email(user, token) do
    context = "change:#{user.email}"

    with {:ok, query} <- UserToken.verify_change_email_token_query(token, context),
         %UserToken{sent_to: email} <- Repo.one(query),
         {:ok, _} <- Repo.transaction(user_email_multi(user, email, context)) do
      :ok
    else
      _ -> :error
    end
  end

  defp user_email_multi(user, email, context) do
    changeset =
      user
      |> User.email_changeset(%{email: email})
      |> User.confirm_changeset()

    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, changeset)
    |> Ecto.Multi.delete_all(:tokens, UserToken.by_user_and_contexts_query(user, [context]))
  end

  @doc ~S"""
  Delivers the update email instructions to the given user.

  ## Examples

      iex> deliver_user_update_email_instructions(user, current_email, &url(~p"/users/settings/confirm_email/#{&1}"))
      {:ok, %{to: ..., body: ...}}

  """
  def deliver_user_update_email_instructions(%User{} = user, current_email, update_email_url_fun)
      when is_function(update_email_url_fun, 1) do
    {encoded_token, user_token} = UserToken.build_email_token(user, "change:#{current_email}")

    Repo.insert!(user_token)
    UserNotifier.deliver_update_email_instructions(user, update_email_url_fun.(encoded_token))
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user password.

  ## Examples

      iex> change_user_password(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_password(user, attrs \\ %{}) do
    User.password_changeset(user, attrs, hash_password: false)
  end

  @doc """
  Updates the user password.

  ## Examples

      iex> update_user_password(user, "valid password", %{password: ...})
      {:ok, %User{}}

      iex> update_user_password(user, "invalid password", %{password: ...})
      {:error, %Ecto.Changeset{}}

  """
  def update_user_password(user, password, attrs) do
    changeset =
      user
      |> User.password_changeset(attrs)
      |> User.validate_current_password(password)

    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, changeset)
    |> Ecto.Multi.delete_all(:tokens, UserToken.by_user_and_contexts_query(user, :all))
    |> Repo.transaction()
    |> case do
      {:ok, %{user: user}} -> {:ok, preload_user_assocs(user)}
      {:error, :user, changeset, _} -> {:error, changeset}
    end
  end

  @doc """
  Updates the user password.

  Returns a tuple with the updated user, as well as a list of expired tokens.

  ## Examples

      iex> update_user_password(user, %{password: ...})
      {:ok, {%User{}, [...]}}

      iex> update_user_password(user, %{password: "too short"})
      {:error, %Ecto.Changeset{}}

  """
  def update_user_password(user, attrs) do
    user
    |> User.password_changeset(attrs)
    |> update_user_and_delete_all_tokens()
  end

  ## Session

  @doc """
  Generates a session token.
  """
  def generate_user_session_token(user) do
    {token, user_token} = UserToken.build_session_token(user)
    Repo.insert!(user_token)
    token
  end

  @doc """
  Gets the user with the given signed token.
  """
  def get_user_by_session_token(token) do
    {:ok, query} = UserToken.verify_session_token_query(token)

    case Repo.one(query) do
      {user, inserted_at} -> {preload_user_assocs(user), inserted_at}
      nil -> nil
    end
  end

  @doc """
  Deletes the signed token with the given context.
  """
  def delete_user_session_token(token) do
    Repo.delete_all(UserToken.by_token_and_context_query(token, "session"))
    :ok
  end

  @doc """
  Gets the user with the given magic link token.
  """
  def get_user_by_magic_link_token(token) do
    with {:ok, query} <- UserToken.verify_magic_link_token_query(token),
         {user, _token} <- Repo.one(query) do
      preload_user_assocs(user)
    else
      _ -> nil
    end
  end

  @doc """
  Logs the user in by magic link.

  There are three cases to consider:

  1. The user has already confirmed their email. They are logged in
     and the magic link is expired.

  2. The user has not confirmed their email and no password is set.
     In this case, the user gets confirmed, logged in, and all tokens -
     including session ones - are expired. In theory, no other tokens
     exist but we delete all of them for best security practices.

  3. The user has not confirmed their email but a password is set.
     This cannot happen in the default implementation but may be the
     source of security pitfalls. See the "Mixing magic link and password registration" section of
     `mix help phx.gen.auth`.
  """
  def login_user_by_magic_link(token) do
    {:ok, query} = UserToken.verify_magic_link_token_query(token)

    case Repo.one(query) do
      # Prevent session fixation attacks by disallowing magic links for unconfirmed users with password
      {%User{confirmed_at: nil, hashed_password: hash}, _token} when not is_nil(hash) ->
        raise """
        magic link log in is not allowed for unconfirmed users with a password set!

        This cannot happen with the default implementation, which indicates that you
        might have adapted the code to a different use case. Please make sure to read the
        "Mixing magic link and password registration" section of `mix help phx.gen.auth`.
        """

      {%User{confirmed_at: nil} = user, _token} ->
        user
        |> User.confirm_changeset()
        |> update_user_and_delete_all_tokens()

      {user, token} ->
        Repo.delete!(token)
        {:ok, {user, []}}

      nil ->
        {:error, :not_found}
    end
  end

  @doc """
  Delivers the magic link login instructions to the given user.
  """
  def deliver_login_instructions(%User{} = user, magic_link_url_fun)
      when is_function(magic_link_url_fun, 1) do
    {encoded_token, user_token} = UserToken.build_email_token(user, "login")
    Repo.insert!(user_token)
    UserNotifier.deliver_login_instructions(user, magic_link_url_fun.(encoded_token))
  end

  @doc """
  Delivers the onboarding magic link instructions to the given migrated user.
  This is specifically for users who were migrated from the old system and need
  to set their password and confirm their account.
  """
  def deliver_onboarding_instructions(%User{} = user, onboarding_url_fun)
      when is_function(onboarding_url_fun, 1) do
    {encoded_token, user_token} = UserToken.build_email_token(user, "onboarding")
    Repo.insert!(user_token)
    UserNotifier.deliver_onboarding_instructions(user, onboarding_url_fun.(encoded_token))
  end

  @doc """
  Gets the user by onboarding token for the onboarding process.
  """
  def get_user_by_onboarding_token(token) do
    with {:ok, query} <- UserToken.verify_email_token_query(token, "onboarding"),
         %User{} = user <- Repo.one(query) do
      preload_user_assocs(user)
    else
      _ -> nil
    end
  end

  @doc """
  Completes the onboarding process for a migrated user by setting their new password
  and confirming their account.
  """
  def complete_user_onboarding(user, attrs) do
    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, User.onboarding_changeset(user, attrs))
    |> Ecto.Multi.delete_all(:tokens, UserToken.by_user_and_contexts_query(user, ["onboarding"]))
    |> Repo.transaction()
    |> case do
      {:ok, %{user: user}} -> {:ok, preload_user_assocs(user)}
      {:error, :user, changeset, _} -> {:error, changeset}
    end
  end

  ## Confirmation

  @doc ~S"""
  Delivers the confirmation email instructions to the given user.

  ## Examples

      iex> deliver_user_confirmation_instructions(user, &url(~p"/users/confirm/#{&1}"))
      {:ok, %{to: ..., body: ...}}

      iex> deliver_user_confirmation_instructions(confirmed_user, &url(~p"/users/confirm/#{&1}"))
      {:error, :already_confirmed}

  """
  def deliver_user_confirmation_instructions(%User{} = user, confirmation_url_fun)
      when is_function(confirmation_url_fun, 1) do
    if user.confirmed_at do
      {:error, :already_confirmed}
    else
      {encoded_token, user_token} = UserToken.build_email_token(user, "confirm")
      Repo.insert!(user_token)
      UserNotifier.deliver_confirmation_instructions(user, confirmation_url_fun.(encoded_token))
    end
  end

  @doc """
  Confirms a user by the given token.

  If the token matches, the user account is marked as confirmed
  and the token is deleted.
  """
  def confirm_user(token) do
    with {:ok, query} <- UserToken.verify_email_token_query(token, "confirm"),
         %User{} = user <- Repo.one(query),
         {:ok, %{user: user}} <- Repo.transaction(confirm_user_multi(user)) do
      {:ok, preload_user_assocs(user)}
    else
      _ -> :error
    end
  end

  defp confirm_user_multi(user) do
    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, User.confirm_changeset(user))
    |> Ecto.Multi.delete_all(:tokens, UserToken.by_user_and_contexts_query(user, ["confirm"]))
  end

  ## Reset password

  @doc ~S"""
  Delivers the reset password email to the given user.

  ## Examples

      iex> deliver_user_reset_password_instructions(user, &url(~p"/users/reset_password/#{&1}"))
      {:ok, %{to: ..., body: ...}}

  """
  def deliver_user_reset_password_instructions(%User{} = user, reset_password_url_fun)
      when is_function(reset_password_url_fun, 1) do
    {encoded_token, user_token} = UserToken.build_email_token(user, "reset_password")
    Repo.insert!(user_token)
    UserNotifier.deliver_reset_password_instructions(user, reset_password_url_fun.(encoded_token))
  end

  @doc """
  Gets the user by reset password token.

  ## Examples

      iex> get_user_by_reset_password_token("validtoken")
      %User{}

      iex> get_user_by_reset_password_token("invalidtoken")
      nil

  """
  def get_user_by_reset_password_token(token) do
    with {:ok, query} <- UserToken.verify_email_token_query(token, "reset_password"),
         %User{} = user <- Repo.one(query) do
      preload_user_assocs(user)
    else
      _ -> nil
    end
  end

  @doc """
  Resets the user password.

  ## Examples

      iex> reset_user_password(user, %{password: "new long password", password_confirmation: "new long password"})
      {:ok, %User{}}

      iex> reset_user_password(user, %{password: "valid", password_confirmation: "not the same"})
      {:error, %Ecto.Changeset{}}

  """
  def reset_user_password(user, attrs) do
    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, User.password_changeset(user, attrs))
    |> Ecto.Multi.delete_all(:tokens, UserToken.by_user_and_contexts_query(user, :all))
    |> Repo.transaction()
    |> case do
      {:ok, %{user: user}} -> {:ok, preload_user_assocs(user)}
      {:error, :user, changeset, _} -> {:error, changeset}
    end
  end

  ## Token helper

  defp update_user_and_delete_all_tokens(changeset) do
    Repo.transact(fn ->
      with {:ok, user} <- Repo.update(changeset) do
        tokens_to_expire = Repo.all_by(UserToken, user_id: user.id)

        Repo.delete_all(from(t in UserToken, where: t.id in ^Enum.map(tokens_to_expire, & &1.id)))

        {:ok, {user, tokens_to_expire}}
      end
    end)
  end

  @doc """
  Gets user statistics.
  """
  def get_user_statistics do
    total_users = Repo.aggregate(User, :count, :id)

    confirmed_users =
      from(u in User, where: not is_nil(u.confirmed_at))
      |> Repo.aggregate(:count, :id)

    %{
      total_users: total_users,
      confirmed_users: confirmed_users,
      unconfirmed_users: total_users - confirmed_users
    }
  end

  @doc """
  Searches users by username, email, or fullname.

  Accepts either a plain query string or a map of filters.

  Example usages:
    search_users("alice")
    search_users(%{"query" => "alice", "node_id" => "1"})
  """
  def search_users(query) when is_binary(query) do
    search_users(%{"query" => query})
  end

  def search_users(%{} = params) do
    query_string = Map.get(params, "query", "")
    search_term = "%#{query_string}%"

    q = from(u in User, preload: [:user_type])

    q =
      if query_string != "" do
        from(u in q,
          where:
            ilike(u.username, ^search_term) or ilike(u.email, ^search_term) or
              ilike(u.fullname, ^search_term)
        )
      else
        q
      end

    # optional filters: node_id, user_type_id
    q =
      case Map.get(params, "node_id") do
        nil ->
          q

        "" ->
          q

        node_id when is_binary(node_id) ->
          from(u in q, where: u.node_id == ^String.to_integer(node_id))

        node_id when is_integer(node_id) ->
          from(u in q, where: u.node_id == ^node_id)
      end

    q =
      case Map.get(params, "user_type_id") do
        nil ->
          q

        "" ->
          q

        mt when is_binary(mt) ->
          from(u in q, where: u.user_type_id == ^String.to_integer(mt))

        mt when is_integer(mt) ->
          from(u in q, where: u.user_type_id == ^mt)
      end

    Repo.all(q)
  end
end
