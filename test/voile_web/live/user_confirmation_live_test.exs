defmodule VoileWeb.UserConfirmationLiveTest do
  use VoileWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Voile.AccountsFixtures

  alias Voile.Schema.Accounts
  alias Voile.Repo

  setup do
    %{user: user_fixture()}
  end

  describe "Confirm user" do
    test "renders confirmation page", %{conn: conn, user: user} do
      token =
        extract_user_token(fn url ->
          Accounts.deliver_user_confirmation_instructions(user, url)
        end)

      {:ok, _lv, html} = live(conn, ~p"/users/confirm/#{token}")
      assert html =~ "Confirm Your Account"
      assert html =~ user.email
    end

    test "renders error for invalid token", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/users/confirm/some-invalid-token")
      assert html =~ "Invalid Confirmation Link"
      assert html =~ "Request New Confirmation Email"
    end

    @tag :skip
    test "confirms the given token once", %{conn: conn, user: user} do
      token =
        extract_user_token(fn url ->
          Accounts.deliver_user_confirmation_instructions(user, url)
        end)

      {:ok, lv, _html} = live(conn, ~p"/users/confirm/#{token}")

      result =
        lv
        |> form("#confirmation_form")
        |> render_submit()
        |> follow_redirect(conn, "/")

      assert {:ok, conn} = result

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~
               "User confirmed successfully"

      assert Accounts.get_user!(user.id).confirmed_at
      refute get_session(conn, :user_token)
      assert Repo.all(Accounts.UserToken) == []

      # when not logged in
      {:ok, lv, _html} = live(conn, ~p"/users/confirm/#{token}")

      result =
        lv
        |> form("#confirmation_form")
        |> render_submit()
        |> follow_redirect(conn, "/")

      assert {:ok, conn} = result

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "User confirmation link is invalid or it has expired"

      # when logged in
      conn =
        build_conn()
        |> log_in_user(user)

      {:ok, lv, _html} = live(conn, ~p"/users/confirm/#{token}")

      result =
        lv
        |> form("#confirmation_form")
        |> render_submit()
        |> follow_redirect(conn, "/")

      assert {:ok, conn} = result
      refute Phoenix.Flash.get(conn.assigns.flash, :error)
    end

    test "does not confirm email with invalid token", %{conn: conn, user: user} do
      {:ok, lv, _html} = live(conn, ~p"/users/confirm/invalid-token")

      # Invalid token shows error message but no form
      assert render(lv) =~ "Invalid Confirmation Link"
      assert render(lv) =~ "Request New Confirmation Email"

      refute Accounts.get_user!(user.id).confirmed_at
    end
  end
end
