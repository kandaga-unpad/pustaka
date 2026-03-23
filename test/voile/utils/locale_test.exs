defmodule VoileWeb.Utils.LocaleTest do
  use ExUnit.Case, async: true

  alias VoileWeb.Utils.Locale

  describe "put_locale/1" do
    test "sets supported locale and updates Voile gettext state" do
      assert Locale.put_locale("en") == :ok
      assert Locale.get_locale() == "en"
      assert Gettext.get_locale(VoileWeb.Gettext) == "en"
    end

    test "invalid locale falls back to default" do
      assert Locale.put_locale("xx") == :ok
      assert Locale.get_locale() == Locale.default_locale()
    end
  end

  describe "locale_query_path/2" do
    test "builds locale links from current path" do
      assert VoileWeb.CoreComponents.locale_query_path("/dashboard", "id") ==
               "/dashboard?locale=id"
    end

    test "live paths normalize to /" do
      assert VoileWeb.CoreComponents.locale_query_path("/live/websocket", "id") == "/?locale=id"
      assert VoileWeb.CoreComponents.locale_query_path("/live/whatever", "en") == "/?locale=en"
    end

    test "empty path defaults to /" do
      assert VoileWeb.CoreComponents.locale_query_path("", "en") == "/?locale=en"
      assert VoileWeb.CoreComponents.locale_query_path(nil, "en") == "/?locale=en"
    end
  end
end
