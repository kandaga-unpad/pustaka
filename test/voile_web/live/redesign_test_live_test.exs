defmodule VoileWeb.RedesignTestLiveTest do
  use VoileWeb.ConnCase

  import Phoenix.LiveViewTest
  import Voile.AccountsFixtures

  alias Voile.Repo
  alias Voile.Schema.Accounts.Role
  alias Voile.Schema.Master.MemberType

  setup do
    staff_member_type = get_or_create_staff_member_type()

    user =
      user_fixture(%{
        email: "redesign_#{System.unique_integer([:positive, :monotonic])}@test.com",
        username: "redesign_#{System.unique_integer([:positive, :monotonic])}",
        fullname: "Review Reviewer",
        phone_number: "081234567890",
        user_type_id: staff_member_type.id
      })

    super_admin_role = get_or_create_super_admin_role()
    {:ok, _} = VoileWeb.Auth.Authorization.assign_role(user.id, super_admin_role.id)

    %{conn: log_in_user(build_conn(), user)}
  end

  describe "redesign showcase" do
    test "renders the default foundations tab with key sections", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/manage/redesign-test")

      assert has_element?(view, "button[phx-value-tab='foundations']")
      assert html =~ "Voile Dashboard Redesign"
      assert html =~ "Brand palette"
      assert html =~ "--color-voile-primary"
    end

    test "sidebar is collapsible with a persisted toggle", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/manage/redesign-test")

      assert has_element?(view, "aside#rd-sidebar[phx-hook='Sidebar']")
      assert has_element?(view, "button[data-rd-sidebar-toggle]")
      # nav scrolls independently while the user card stays pinned
      assert has_element?(view, "nav.rd-sidebar-nav")
    end

    test "switches to the components tab", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/manage/redesign-test")

      view
      |> element("button[phx-value-tab='components']")
      |> render_click()

      html = render(view)
      assert html =~ "Buttons"
      assert html =~ "Stat cards"
      assert html =~ "GLAM strip"
    end

    test "switches to the layouts tab and renders the dashboard mockup", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/manage/redesign-test")

      html =
        view
        |> element("button[phx-value-tab='layouts']")
        |> render_click()

      assert html =~ "Dashboard home"
      assert html =~ "Attention required"
      assert html =~ "Catalog snapshot"
    end

    test "switches to the patterns tab and renders loading + empty states", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/manage/redesign-test")

      html =
        view
        |> element("button[phx-value-tab='patterns']")
        |> render_click()

      assert html =~ "Loading skeletons"
      assert html =~ "Command palette"
    end

    test "switches to the legacy tab and renders existing components with refactor actions", %{
      conn: conn
    } do
      {:ok, view, _html} = live(conn, ~p"/manage/redesign-test")

      html =
        view
        |> element("button[phx-value-tab='legacy']")
        |> render_click()

      assert html =~ "Existing dashboard components"
      # legacy stat_card renders (the value 1204 from sample data)
      assert html =~ "1204"
      # the search widget's debug UI is visible (issue #3)
      assert html =~ "Query:"
      # action badges present
      assert html =~ "REMOVE"
      assert html =~ "REPLACE"
      assert html =~ "KEEP"
      # draft replacement section renders the new rd_ components
      assert html =~ "rd_ replacements"
      assert html =~ "DRAFT"
      assert html =~ "rd_pagination"
    end

    test "ignores unknown tab values", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/manage/redesign-test")

      # push an invalid tab event directly; page stays on foundations
      assert render_hook(view, "select_tab", %{"tab" => "bogus"}) =~ "Brand palette"
    end
  end

  defp get_or_create_staff_member_type do
    case Repo.get_by(MemberType, slug: "staff") do
      %MemberType{} = mt ->
        mt

      nil ->
        {:ok, mt} =
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

        mt
    end
  end

  defp get_or_create_super_admin_role do
    case Repo.get_by(Role, name: "super_admin") do
      %Role{} = role ->
        role

      nil ->
        Repo.insert!(Role.changeset(%Role{}, %{name: "super_admin", description: "Super admin"}))
    end
  end
end
