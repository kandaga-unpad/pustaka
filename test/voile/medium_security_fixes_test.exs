defmodule Voile.MediumSecurityFixesTest do
  use ExUnit.Case, async: true

  alias Voile.Schema.System.UserApiToken

  describe "M1: path traversal confinement in local storage delete" do
    @tag :path_traversal_security
    test "rejects deletion of files outside the upload root" do
      result = Client.Storage.Local.delete("/uploads/../../etc/passwd", [])

      assert match?({:error, :invalid_path}, result),
             "Path traversal must be rejected, got: #{inspect(result)}"
    end

    @tag :path_traversal_security
    test "rejects deeply nested traversal" do
      result = Client.Storage.Local.delete("/uploads/files/../../../../../../etc/shadow", [])

      assert match?({:error, :invalid_path}, result)
    end

    @tag :path_traversal_security
    test "returns ok for non-existent file within upload root (idempotent)" do
      result = Client.Storage.Local.delete("/uploads/nonexistent_dir/file.txt", [])

      assert match?({:ok, _}, result)
    end
  end

  describe "M3: constant-time API token comparison" do
    @tag :token_security
    test "verify_token returns true for matching tokens" do
      plain = UserApiToken.generate_token()
      hashed = UserApiToken.hash_token(plain)

      assert UserApiToken.verify_token(hashed, plain)
    end

    @tag :token_security
    test "verify_token returns false for non-matching tokens" do
      plain = UserApiToken.generate_token()
      hashed = UserApiToken.hash_token(plain)

      refute UserApiToken.verify_token(hashed, "completely-wrong-token")
    end

    @tag :token_security
    test "verify_token returns false when hashed_token is wrong" do
      plain = UserApiToken.generate_token()

      refute UserApiToken.verify_token(String.duplicate("a", 64), plain)
    end

    @tag :token_security
    test "does not raise on edge-case inputs" do
      refute UserApiToken.verify_token("", "anything")
      refute UserApiToken.verify_token("abc", "")
    end
  end

  describe "M4: API rate limiter runs before auth" do
    @tag :rate_limit_security
    test "rate limiter plug is listed before authorization in :api_authenticated pipeline" do
      router_text = File.read!("lib/voile_web/router.ex")

      # Extract the :api_authenticated pipeline block
      pipeline_start = String.split(router_text, "pipeline :api_authenticated") |> Enum.at(1)

      assert pipeline_start != nil, ":api_authenticated pipeline not found"

      rate_limiter_pos = :binary.match(pipeline_start, "APIRateLimiter")
      auth_pos = :binary.match(pipeline_start, "APIAuthorization")

      assert rate_limiter_pos != :not_found, "APIRateLimiter not in pipeline"
      assert auth_pos != :not_found, "APIAuthorization not in pipeline"

      {rl_pos, _} = rate_limiter_pos
      {au_pos, _} = auth_pos

      assert rl_pos < au_pos,
             "APIRateLimiter must run before APIAuthorization so failed-auth attempts are throttled"
    end
  end

  describe "M7: session cookie SameSite policy" do
    @tag :cookie_security
    test "endpoint uses SameSite=Lax (not None)" do
      endpoint_text = File.read!("lib/voile_web/endpoint.ex")

      assert endpoint_text =~ ~s(same_site: "Lax"),
             "Session cookie should use SameSite=Lax"

      refute endpoint_text =~ ~s(same_site: "None"),
             "SameSite=None weakens CSRF defense-in-depth"
    end
  end

  describe "M8: dev credentials externalized" do
    @tag :credential_security
    test "MySQL source reads from environment variables" do
      dev_text = File.read!("config/dev.exs")

      assert dev_text =~ "VOILE_MYSQL_USERNAME",
             "MySQL username should be read from env var"

      assert dev_text =~ "VOILE_MYSQL_PASSWORD",
             "MySQL password should be read from env var"
    end

    @tag :credential_security
    test "dev secret_key_base has a warning comment" do
      dev_text = File.read!("config/dev.exs")

      assert dev_text =~ "DEV ONLY" or dev_text =~ "must NEVER",
             "Dev secret_key_base should warn against production reuse"
    end
  end

  describe "M2: PAuS tokens moved out of URL query strings" do
    @tag :paus_security
    test "PAuS API calls use Authorization header, not query-string tokens" do
      paus_text = File.read!("lib/voile_web/auth/user_auth_paus.ex")

      refute paus_text =~ ~r"\?access_token=",
             "Access tokens must not be passed in URL query strings"

      assert paus_text =~ "authorization",
             "PAuS API calls should use authorization header"

      assert paus_text =~ "Bearer",
             "PAuS API calls should use Bearer token scheme"
    end
  end

  describe "M6: e-book reader rejects arbitrary url params" do
    @tag :ebook_security
    test "ebook reader no longer accepts ?url= or ?file_url= params" do
      ebook_text = File.read!("lib/voile_web/live/frontend/ebook_reader/show.ex")

      refute ebook_text =~ "params[\"url\"]",
             "E-book reader must not accept ?url= param"

      refute ebook_text =~ "params[\"file_url\"]",
             "E-book reader must not accept ?file_url= param"
    end
  end
end
