defmodule VoileWeb.PageLiveTest do
  use VoileWeb.ConnCase

  import Phoenix.LiveViewTest

  test "GET /", %{conn: conn} do
    {:ok, _index_live, html} = live(conn, ~p"/")

    assert html =~ "Voile, the Magic Library"
    assert html =~ "Search across all collections"
  end

  test "GET /about", %{conn: conn} do
    {:ok, _about_live, html} = live(conn, ~p"/about")

    assert html =~ "Voile, the Magic Library"
    assert html =~ "Virtual Organized of Information &amp; Library Ecosystem"
  end

  test "search functionality", %{conn: conn} do
    {:ok, home_live, _html} = live(conn, ~p"/")

    # Test search change event
    html =
      home_live
      |> form("form", %{q: "test", glam_type: "quick"})
      |> render_change()

    assert html =~ "test"
  end
end
