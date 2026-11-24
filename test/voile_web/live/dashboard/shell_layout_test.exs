defmodule VoileWeb.Dashboard.ShellLayoutTest do
  use VoileWeb.ConnCase

  import Phoenix.LiveViewTest
  import Voile.AccountsFixtures
  import Ecto.Query

  alias Voile.Repo
  alias Voile.Schema.Accounts.Role
  alias Voile.Schema.Master.MemberType

  setup do
    staff_member_type = get_or_create_staff_member_type()

    librarian =
      user_fixture(%{
        email: "librarian_#{System.unique_integer([:positive, :monotonic])}@test.com",
        username: "librarian_#{System.unique_integer([:positive, :monotonic])}",
        fullname: "Test Librarian",
        user_type_id: staff_member_type.id
      })

    super_admin_role = get_or_create_super_admin_role()

    {:ok, _assignment} =
      VoileWeb.Auth.Authorization.assign_role(librarian.id, super_admin_role.id)

    conn =
      build_conn()
      |> Plug.Test.init_test_session(%{"locale" => "en"})
      |> log_in_user(librarian)

    %{conn: conn}
  end

  test "renders the mobile drawer with the full navigation tree", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/manage/glam/library/circulation/report")
    document = Floki.parse_document!(html)

    assert [drawer] = Floki.find(document, "#voile-mobile-drawer")

    # Drawer reuses the sidebar tree (parents + deep children) with its own
    # namespaced nav ids so they never collide with the desktop sidebar's
    assert Floki.find(drawer, "a[href='/manage/catalog/items']") != []
    assert Floki.find(drawer, "a[href='/manage/master/topics']") != []
    assert Floki.find(drawer, "a[href='/manage/settings/holidays']") != []

    assert Floki.find(drawer, "[id='voile-drawer-nav-manage-catalog']") != []
    assert Floki.find(document, "[id='voile-nav-manage-catalog']") != []
  end

  test "bottom-nav More button opens the drawer, not the command palette", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/manage/glam/library/circulation/report")
    document = Floki.parse_document!(html)

    assert [more_button] = Floki.find(document, "[data-voile-bottom-nav-more]")
    assert Floki.attribute(more_button, "phx-click") |> hd() =~ "voile:open-dashboard-nav"
  end

  test "command palette reflects all dashboard menu paths", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/manage/glam/library/circulation/report")
    document = Floki.parse_document!(html)

    results = Floki.find(document, "[data-voile-cmd-result]")
    assert length(results) > 10

    hrefs = Floki.attribute(results, "href")
    assert "/manage/master/topics" in hrefs
    assert "/manage/settings/holidays" in hrefs
    assert "/manage/catalog/items" in hrefs
  end

  test "sidebar front-page link hides its label when collapsed", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/manage/glam/library/circulation/report")
    document = Floki.parse_document!(html)

    sidebar = Floki.find(document, "#voile-sidebar")
    assert [front_page_span] = Floki.find(sidebar, "a[href='/'] span.voile-sidebar-label")
    assert Floki.text(front_page_span) =~ "Front page"
  end

  # -- Fixtures -------------------------------------------------------------

  defp get_or_create_staff_member_type do
    case Repo.one(from mt in MemberType, where: mt.slug == "staff", limit: 1) do
      %MemberType{} = member_type ->
        member_type

      nil ->
        {:ok, member_type} =
          %MemberType{}
          |> MemberType.changeset(%{
            name: "Staff",
            slug: "staff",
            description: "Staff member type",
            max_concurrent_loans: 5,
            max_days: 14,
            can_renew: true,
            max_renewals: 2,
            can_reserve: true,
            max_reserves: 3,
            fine_per_day: Decimal.new("5000"),
            max_fine: Decimal.new("100000"),
            is_active: true,
            priority_level: 1
          })
          |> Repo.insert()

        member_type
    end
  end

  defp get_or_create_super_admin_role do
    case Repo.get_by(Role, name: "super_admin") do
      %Role{} = role ->
        role

      nil ->
        {:ok, role} =
          %Role{}
          |> Role.changeset(%{name: "super_admin", description: "Super admin"})
          |> Repo.insert()

        role
    end
  end
end
