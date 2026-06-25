defmodule Voile.SecurityConfigTest do
  use ExUnit.Case, async: true

  describe "upload file-type allow-list (H3)" do
    @tag :upload_security
    test "does not allow application/octet-stream (executable catch-all)" do
      types = Application.get_env(:voile, :attachment_allowed_file_types, [])

      refute "application/octet-stream" in types,
             "application/octet-stream allows arbitrary binary/executable uploads"
    end

    @tag :upload_security
    test "does not allow application/x-executable" do
      types = Application.get_env(:voile, :attachment_allowed_file_types, [])

      refute "application/x-executable" in types,
             "application/x-executable explicitly allows malware"
    end

    @tag :upload_security
    test "still allows legitimate document and image types" do
      types = Application.get_env(:voile, :attachment_allowed_file_types, [])

      assert "application/pdf" in types
      assert "image/jpeg" in types
      assert "image/png" in types
    end
  end

  describe "force_ssl in production endpoint config (H5)" do
    @tag :ssl_security
    test "force_ssl is configured in the prod runtime config" do
      config_text = File.read!("config/runtime.exs")

      assert config_text =~ "force_ssl",
             "force_ssl must be enabled in config/runtime.exs for production"

      assert config_text =~ "hsts",
             "HSTS must be enabled alongside force_ssl"
    end

    @tag :ssl_security
    test "force_ssl is NOT enabled in dev or test configs (would break local dev)" do
      refute File.read!("config/dev.exs") =~ ~r/force_ssl\s*:/,
             "force_ssl should not be set in dev.exs"

      refute File.read!("config/test.exs") =~ ~r/force_ssl\s*:/,
             "force_ssl should not be set in test.exs"
    end
  end
end
