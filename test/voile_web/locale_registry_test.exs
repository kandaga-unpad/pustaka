defmodule VoileWeb.LocaleRegistryTest do
  use ExUnit.Case, async: false

  alias VoileWeb.Utils.Locale

  defmodule TestPlugin.Gettext do
    use Voile.Plugin.Gettext, otp_app: :voile
  end

  defmodule TestPlugin do
    def metadata,
      do: %{
        id: "test_plugin",
        name: "Test Plugin",
        version: "0.0.1",
        author: "test",
        description: "fixture",
        license_type: :free
      }

    def routes, do: []
    def hooks, do: []
    def on_install, do: :ok
  end

  setup do
    on_exit(fn ->
      :persistent_term.erase({Locale, :plugin_backends})
      Gettext.put_locale(VoileWeb.Gettext, "en")
    end)

    :persistent_term.erase({Locale, :plugin_backends})
    :ok
  end

  test "register/unregister around a plugin backend" do
    assert :ok = Locale.register_plugin_gettext(TestPlugin, TestPlugin.Gettext)
    assert TestPlugin.Gettext in Locale.plugin_gettext_backends()

    # idempotent upsert
    :ok = Locale.register_plugin_gettext(TestPlugin, TestPlugin.Gettext)
    assert Enum.count(Locale.plugin_gettext_backends(), &(&1 == TestPlugin.Gettext)) == 1

    assert :ok = Locale.unregister_plugin_gettext(TestPlugin)
    assert TestPlugin.Gettext not in Locale.plugin_gettext_backends()

    # unregistering an unregistered owner is a no-op
    assert :ok = Locale.unregister_plugin_gettext(TestPlugin)
  end

  test "put_locale propagates to registered plugin backends" do
    :ok = Locale.register_plugin_gettext(TestPlugin, TestPlugin.Gettext)

    :ok = Locale.put_locale("id")
    assert Gettext.get_locale(TestPlugin.Gettext) == "id"

    :ok = Locale.put_locale("en")
    assert Gettext.get_locale(TestPlugin.Gettext) == "en"
  end

  test "a fresh process that runs the LocaleHook resolves the plugin locale from session" do
    :ok = Locale.register_plugin_gettext(TestPlugin, TestPlugin.Gettext)

    # Simulates a child LiveView process (e.g. a plugin LiveView rendered via
    # live_render): process dictionary is empty, locale comes from the session.
    assert "id" ==
             Task.async(fn ->
               VoileWeb.Live.Hooks.LocaleHook.on_mount(
                 :set_locale,
                 %{},
                 %{"locale" => "id"},
                 %Phoenix.LiveView.Socket{}
               )

               Gettext.get_locale(TestPlugin.Gettext)
             end)
             |> Task.await()
  end

  test "rejects a module that is not a plugin Gettext backend" do
    assert_raise ArgumentError, ~r/not a Voile plugin Gettext backend/, fn ->
      Locale.register_plugin_gettext(TestPlugin, String)
    end
  end
end
