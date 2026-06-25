defmodule Voile.OauthRegistrationTest do
  use ExUnit.Case, async: false

  alias Voile.Schema.Accounts

  setup do
    # Clean up env var before and after each test
    System.delete_env("VOILE_OAUTH_ALLOWED_DOMAINS")
    on_exit(fn -> System.delete_env("VOILE_OAUTH_ALLOWED_DOMAINS") end)
    :ok
  end

  describe "L2: oauth_registration_allowed?/1" do
    @tag :oauth_registration
    test "allows any domain when VOILE_OAUTH_ALLOWED_DOMAINS is not set" do
      assert Accounts.oauth_registration_allowed?("user@gmail.com")
      assert Accounts.oauth_registration_allowed?("admin@unpad.ac.id")
      assert Accounts.oauth_registration_allowed?("anyone@example.org")
    end

    @tag :oauth_registration
    test "allows emails from configured domains" do
      System.put_env("VOILE_OAUTH_ALLOWED_DOMAINS", "unpad.ac.id,mail.unpad.ac.id")

      assert Accounts.oauth_registration_allowed?("user@unpad.ac.id")
      assert Accounts.oauth_registration_allowed?("user@mail.unpad.ac.id")
    end

    @tag :oauth_registration
    test "rejects emails from non-configured domains when restricted" do
      System.put_env("VOILE_OAUTH_ALLOWED_DOMAINS", "unpad.ac.id")

      refute Accounts.oauth_registration_allowed?("user@gmail.com")
      refute Accounts.oauth_registration_allowed?("user@example.org")
    end

    @tag :oauth_registration
    test "domain matching is case-insensitive" do
      System.put_env("VOILE_OAUTH_ALLOWED_DOMAINS", "UNPAD.AC.ID")

      assert Accounts.oauth_registration_allowed?("user@unpad.ac.id")
    end

    @tag :oauth_registration
    test "rejects invalid email formats" do
      System.put_env("VOILE_OAUTH_ALLOWED_DOMAINS", "unpad.ac.id")

      refute Accounts.oauth_registration_allowed?("not-an-email")
      refute Accounts.oauth_registration_allowed?("")
    end

    @tag :oauth_registration
    test "returns false for non-string input" do
      refute Accounts.oauth_registration_allowed?(nil)
      refute Accounts.oauth_registration_allowed?(123)
    end
  end
end
