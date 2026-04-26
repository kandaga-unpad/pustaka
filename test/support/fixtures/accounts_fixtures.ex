defmodule Voile.AccountsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Voile.Accounts` context.
  """

  import Ecto.Query

  alias Voile.Repo
  alias Voile.Schema.Accounts
  alias Voile.Schema.Accounts.{Scope, Role, UserRoleAssignment}

  def unique_user_email, do: "user#{System.unique_integer()}@example.com"
  def valid_user_password, do: "hello world!"

  def valid_user_attributes(attrs \\ %{}) do
    email = unique_user_email()
    username = String.split(email, "@") |> hd()

    Enum.into(attrs, %{
      email: email,
      username: username,
      password: valid_user_password()
    })
  end

  def user_fixture(attrs \\ %{}) do
    {:ok, user} =
      attrs
      |> valid_user_attributes()
      |> Voile.Schema.Accounts.register_user()

    user
  end

  def user_scope_fixture do
    user = user_fixture()
    user_scope_fixture(user)
  end

  def user_scope_fixture(user) do
    Scope.for_user(user)
  end

  def set_password(user) do
    {:ok, {user, _expired_tokens}} =
      Accounts.update_user_password(user, %{password: valid_user_password()})

    user
  end

  def extract_user_token(fun) do
    {:ok, captured_email} = fun.(&"[TOKEN]#{&1}[TOKEN]")
    body = captured_email.text_body || captured_email.html_body
    [_, token | _] = String.split(body, "[TOKEN]")
    token
  end

  def override_token_authenticated_at(token, authenticated_at) when is_binary(token) do
    Voile.Repo.update_all(
      from(t in Accounts.UserToken,
        where: t.token == ^token
      ),
      set: [authenticated_at: authenticated_at]
    )
  end

  def generate_user_magic_link_token(user) do
    {encoded_token, user_token} = Accounts.UserToken.build_email_token(user, "login")
    Voile.Repo.insert!(user_token)
    {encoded_token, user_token.token}
  end

  def offset_user_token(token, amount_to_add, unit) do
    dt = DateTime.add(DateTime.utc_now(:second), amount_to_add, unit)

    Voile.Repo.update_all(
      from(ut in Accounts.UserToken, where: ut.token == ^token),
      set: [inserted_at: dt, authenticated_at: dt]
    )
  end

  @doc """
  Generate a role.
  """
  def role_fixture(attrs \\ %{}) do
    name = "role_#{System.unique_integer()}"

    role =
      attrs
      |> Enum.into(%{
        name: name,
        description: "Test role"
      })
      |> then(&Repo.insert!(%Role{} |> Role.changeset(&1)))

    role
  end

  @doc """
  Assign a role to a user.
  """
  def user_role_assignment_fixture(attrs \\ %{}) do
    assignment =
      attrs
      |> Enum.into(%{
        scope_type: "global"
      })
      |> then(&Repo.insert!(%UserRoleAssignment{} |> UserRoleAssignment.changeset(&1)))

    assignment
  end
end
