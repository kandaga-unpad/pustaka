defmodule Voile.LowInfoSecurityFixesTest do
  use ExUnit.Case, async: true

  describe "L1: password hashing documentation accuracy" do
    @tag :doc_accuracy
    test "assessment doc says Pbkdf2 (not Argon2)" do
      doc = File.read!("plans/assesment-of-voile.md")

      assert doc =~ "Pbkdf2",
             "Assessment should document Pbkdf2 as the hashing algorithm"

      refute doc =~ ~r"Password hashing with .?Argon2",
             "Assessment should not claim Argon2 is used (code uses Pbkdf2)"
    end
  end

  describe "L3: PII fields redacted in User schema" do
    @tag :pii_redaction
    test "phone_number is redacted in inspect output" do
      user = %Voile.Schema.Accounts.User{phone_number: "555-SECRET-1234"}
      inspected = inspect(user)

      refute inspected =~ "555-SECRET-1234",
             "phone_number should be redacted in inspect output"
    end

    @tag :pii_redaction
    test "address is redacted in inspect output" do
      user = %Voile.Schema.Accounts.User{address: "123 Secret Street"}
      inspected = inspect(user)

      refute inspected =~ "123 Secret Street",
             "address should be redacted in inspect output"
    end

    @tag :pii_redaction
    test "birth_date is redacted in inspect output" do
      user = %Voile.Schema.Accounts.User{birth_date: ~D[1990-05-15]}
      inspected = inspect(user)

      refute inspected =~ "1990-05-15",
             "birth_date should be redacted in inspect output"
    end

    @tag :pii_redaction
    test "last_login_ip is redacted in inspect output" do
      user = %Voile.Schema.Accounts.User{last_login_ip: "203.0.113.99"}
      inspected = inspect(user)

      refute inspected =~ "203.0.113.99",
             "last_login_ip should be redacted in inspect output"
    end

    @tag :pii_redaction
    test "birth_place is redacted in inspect output" do
      user = %Voile.Schema.Accounts.User{birth_place: "Secret City"}
      inspected = inspect(user)

      refute inspected =~ "Secret City",
             "birth_place should be redacted in inspect output"
    end
  end

  describe "L4: stray data files removed from tracking" do
    @tag :stray_files
    test "test_missing_items.csv is no longer tracked by git" do
      {output, 0} = System.cmd("git", ["ls-files", "test_missing_items.csv"], cd: File.cwd!())

      assert String.trim(output) == "",
             "test_missing_items.csv should not be tracked by git"
    end
  end

  describe "L5: plugin management requires super_admin" do
    @tag :plugin_security
    test "all privileged plugin handlers check is_super_admin" do
      source = File.read!("lib/voile_web/live/dashboard/plugins/index.ex")

      # Every privileged action must be present in the source
      for action <- ["install", "activate", "deactivate", "uninstall", "update"] do
        assert source =~ "\"#{action}\"",
               "Plugin handler for #{action} should exist"
      end

      # The super_admin guard must be enforced (once per handler = 5 occurrences)
      count = source |> String.split("is_super_admin") |> length() |> Kernel.-(1)
      assert count >= 5,
             "Expected at least 5 is_super_admin checks (one per privileged handler), got #{count}"
    end

    @tag :plugin_security
    test "plugin settings page also enforces super_admin" do
      source = File.read!("lib/voile_web/live/dashboard/plugins/settings.ex")

      assert source =~ "is_super_admin",
             "Plugin settings page must check is_super_admin"
    end
  end
end
