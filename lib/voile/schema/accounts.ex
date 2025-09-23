defmodule Voile.Schema.Accounts do
  @moduledoc """
  The Accounts context.
  """

  import Ecto.Query, warn: false
  alias Voile.Repo

  alias Voile.Schema.Accounts.{User, UserRole, UserToken, UserNotifier}
  alias Voile.Schema.Accounts.UserProfile

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
    Repo.get_by(User, email: email)
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
    if User.valid_password?(user, password), do: user
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
        Repo.get_by(User, identifier: id)

      :error ->
        Repo.get_by(User, identifier: identifier)
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
        order_by: [asc: u.inserted_at],
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
  Get the user profile record for a given user id, or nil if absent.
  """
  def get_user_profile(user_id) when is_binary(user_id) do
    Repo.get_by(UserProfile, user_id: user_id)
  end

  @doc """
  Upsert a user's profile. If a profile exists it's updated, otherwise a new profile is created.

  Returns {:ok, profile} or {:error, changeset}.
  """
  def upsert_user_profile(%User{} = user, attrs) when is_map(attrs) do
    attrs = Map.put(attrs, "user_id", user.id)

    case get_user_profile(user.id) do
      nil ->
        %UserProfile{}
        |> UserProfile.changeset(attrs)
        |> Repo.insert()

      profile ->
        profile
        |> UserProfile.changeset(attrs)
        |> Repo.update()
    end
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
      {:ok, %{user: user}} -> {:ok, user}
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
    Repo.one(query)
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
      user
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
      user
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
      {:ok, %{user: user}} -> {:ok, user}
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
      {:ok, user}
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
      user
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
      {:ok, %{user: user}} -> {:ok, user}
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
  Returns the list of user roles.
  """
  def list_user_roles do
    Repo.all(UserRole)
  end

  @doc """
  Gets a single user role.
  """
  def get_user_role!(id), do: Repo.get!(UserRole, id)

  @doc """
  Gets a user role by name.
  """
  def get_user_role_by_name(name) when is_binary(name) do
    Repo.get_by(UserRole, name: name)
  end

  @doc """
  Creates a user role.
  """
  def create_user_role(attrs \\ %{}) do
    %UserRole{}
    |> UserRole.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a user role.
  """
  def update_user_role(%UserRole{} = user_role, attrs) do
    user_role
    |> UserRole.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a user role.
  """
  def delete_user_role(%UserRole{} = user_role) do
    Repo.delete(user_role)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking user role changes.
  """
  def change_user_role(%UserRole{} = user_role, attrs \\ %{}) do
    UserRole.changeset(user_role, attrs)
  end

  ## Permission functions

  @doc """
  Checks if a user has permission for a specific resource and action.

  This function accepts `resource` in one of three forms:
    - a single string or atom key (e.g. "collection" or :collection)
    - a dot-separated string path (e.g. "collection.transaction.checkout")
    - a list of keys (e.g. ["collection", "transaction", "checkout"]) where each
      element is a string or atom

  `action` must be a string or atom that corresponds to the final permission key.

  Examples:

      # shallow
      has_permission?(user, "collection", "create")

      # deep, dot-separated
      has_permission?(user, "collection.transaction.checkout", "read")

      # deep, list
      has_permission?(user, ["collection", "transaction", "checkout"], "read")

  Passing the actual nested boolean value (for example `permissions["collection"]["create"]`)
  or other invalid shapes will raise an `ArgumentError` to guide callers to use keys/paths.
  """
  def has_permission?(%User{user_role: %UserRole{permissions: permissions}}, resource, action)
      when (is_binary(resource) or is_atom(resource) or is_list(resource)) and
             (is_binary(action) or is_atom(action)) do
    # Normalize resource into a list of keys
    keys =
      cond do
        is_list(resource) ->
          resource

        is_binary(resource) ->
          if String.contains?(resource, ".") do
            String.split(resource, ".")
          else
            [resource]
          end

        is_atom(resource) ->
          [resource]
      end

    # Validate each key element
    unless Enum.all?(keys, fn k -> is_binary(k) or is_atom(k) end) do
      raise ArgumentError,
            "has_permission?/3 expects resource path elements to be strings or atoms (got: #{inspect(keys)})"
    end

    path = keys ++ [action]

    case get_in(permissions, path) do
      true -> true
      _ -> false
    end
  end

  # Explicit false when user has no role or user is nil
  def has_permission?(%User{user_role: nil}, _resource, _action), do: false
  def has_permission?(nil, _resource, _action), do: false

  # Catch-all to prevent callers from passing nested boolean values or other invalid shapes.
  def has_permission?(_user, resource, _action)
      when not (is_binary(resource) or is_atom(resource)) do
    raise ArgumentError,
          "has_permission?/3 expects `resource` to be a string or atom key (got: #{inspect(resource)})"
  end

  def has_permission?(_user, _resource, action) when not (is_binary(action) or is_atom(action)) do
    raise ArgumentError,
          "has_permission?/3 expects `action` to be a string or atom key (got: #{inspect(action)})"
  end

  @doc """
  Checks if a user can perform any CRUD operation on a resource.
  """
  def can_access_resource?(%User{} = user, resource) do
    has_permission?(user, resource, "create") ||
      has_permission?(user, resource, "read") ||
      has_permission?(user, resource, "update") ||
      has_permission?(user, resource, "delete")
  end

  @doc """
  Gets all available resources from all roles.
  """
  def get_available_resources do
    list_user_roles()
    |> Enum.flat_map(fn role -> Map.keys(role.permissions) end)
    |> Enum.uniq()
    |> Enum.sort()
  end

  @doc """
  Gets user statistics.
  """
  def get_user_statistics do
    total_users = Repo.aggregate(User, :count, :id)

    confirmed_users =
      from(u in User, where: not is_nil(u.confirmed_at))
      |> Repo.aggregate(:count, :id)

    users_by_role =
      from(u in User,
        join: r in UserRole,
        on: u.user_role_id == r.id,
        group_by: r.name,
        select: {r.name, count(u.id)}
      )
      |> Repo.all()
      |> Enum.into(%{})

    %{
      total_users: total_users,
      confirmed_users: confirmed_users,
      unconfirmed_users: total_users - confirmed_users,
      users_by_role: users_by_role
    }
  end

  @doc """
  Searches users by username, email, or fullname.
  """
  def search_users(query_string) when is_binary(query_string) do
    search_term = "%#{query_string}%"

    from(u in User,
      where:
        ilike(u.username, ^search_term) or
          ilike(u.email, ^search_term) or
          ilike(u.fullname, ^search_term),
      preload: [:user_role]
    )
    |> Repo.all()
  end

  @doc """
  Gets users by role.
  """
  def get_users_by_role(role_name) when is_binary(role_name) do
    from(u in User,
      join: r in UserRole,
      on: u.user_role_id == r.id,
      where: r.name == ^role_name,
      preload: [:user_role]
    )
    |> Repo.all()
  end
end
