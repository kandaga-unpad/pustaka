defmodule VoileWeb.Dashboard.Glam.Library.Circulation.ReportTest do
  use VoileWeb.ConnCase

  import Phoenix.LiveViewTest
  import Voile.AccountsFixtures
  import Voile.LibraryFixtures
  import Ecto.Query

  alias Voile.Repo
  alias Voile.Schema.Accounts.{Role, User}
  alias Voile.Schema.Catalog.Collection
  alias Voile.Schema.Master.{Creator, Location}
  alias Voile.Schema.Metadata.ResourceClass
  alias Voile.Schema.System.VisitorLog

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

    # Force the English locale so UI string assertions are stable
    conn =
      build_conn()
      |> Plug.Test.init_test_session(%{"locale" => "en"})
      |> log_in_user(librarian)

    %{conn: conn, librarian: librarian}
  end

  describe "Usability tab" do
    test "renders the tab with summary cards and rankings", %{conn: conn, librarian: librarian} do
      seed_usability_data(librarian.node_id)

      {:ok, view, _html} = live(conn, ~p"/manage/glam/library/circulation/report")

      assert has_element?(view, "button[phx-value-tab=\"usability\"]")

      view
      |> element("button[phx-value-tab=\"usability\"]")
      |> render_click()

      html = render(view)

      assert has_element?(view, "#usability-tab")
      assert html =~ "Total Loans"
      assert html =~ "Unique Borrowers"
      assert html =~ "Library Visits"
      assert html =~ "Most Loaned Titles"
      assert html =~ "Most Active Members"
      assert html =~ "Most Frequent Visitors"

      # Default filter is the current month/year, so the seeded rows are visible
      assert html =~ "Usability Book 1"
      assert html =~ "Usability Member A"
      assert html =~ "3100001"
    end

    test "paginates the rankings five rows per page", %{conn: conn, librarian: librarian} do
      seed_usability_data(librarian.node_id)

      {:ok, view, _html} = live(conn, ~p"/manage/glam/library/circulation/report")

      view
      |> element("button[phx-value-tab=\"usability\"]")
      |> render_click()

      html = render(view)

      # Six loaned titles (plus the shared base fixture row) -> multiple pages
      # of five rows; the last seeded title can never be on page 1
      assert html =~ "Page 1 / 2"
      refute html =~ "Usability Book 6"

      assert has_element?(
               view,
               "button[phx-click=\"usability_next_page\"][phx-value-list=\"collections\"]:not([disabled])"
             )

      view
      |> element("button[phx-click=\"usability_next_page\"][phx-value-list=\"collections\"]")
      |> render_click()

      html = render(view)

      assert html =~ "Page 2 / 2"
      assert html =~ "Usability Book 6"

      view
      |> element("button[phx-click=\"usability_prev_page\"][phx-value-list=\"collections\"]")
      |> render_click()

      html = render(view)

      assert html =~ "Page 1 / 2"
      refute html =~ "Usability Book 6"
    end

    test "changing the year resets the month filter and reloads", %{
      conn: conn,
      librarian: librarian
    } do
      seed_usability_data(librarian.node_id)

      {:ok, view, _html} = live(conn, ~p"/manage/glam/library/circulation/report")

      view
      |> element("button[phx-value-tab=\"usability\"]")
      |> render_click()

      assert has_element?(view, "#usability-tab")

      current_year = Date.utc_today().year

      view
      |> element("#usability-tab form[phx-change=\"usability_filter_year\"]")
      |> render_change(%{"year" => to_string(current_year)})

      html = render(view)

      assert html =~ "Page 1 / 2"
      assert has_element?(view, "#usability-tab")
    end
  end

  # -- Fixtures -------------------------------------------------------------

  defp seed_usability_data(node_id) do
    # Ensure shared fixture entities (creator, resource class) exist
    _ = transaction_fixture()

    creator = Repo.one!(from c in Creator, limit: 1)
    resource_class = Repo.one!(from r in ResourceClass, limit: 1)

    member_a = usability_member("Usability Member A", "3100001")
    member_b = usability_member("Usability Member B", "3100002")
    librarian = usability_member("Usability Librarian", "1990001")

    collections =
      for i <- 1..6 do
        collection =
          usability_collection("Usability Book #{i}", node_id, creator, resource_class.id)

        usability_item(collection)
      end

    now = DateTime.utc_now() |> DateTime.truncate(:second)

    collections
    |> Enum.with_index()
    |> Enum.each(fn {item, index} ->
      member = if rem(index, 2) == 0, do: member_a, else: member_b

      transaction_fixture(%{
        member_id: member.id,
        item_id: item.id,
        librarian_id: librarian.id,
        transaction_date: now
      })
    end)

    location =
      Repo.insert!(%Location{
        location_code: "USAB-LOC-#{System.unique_integer([:positive])}",
        location_name: "Usability Test Location",
        location_type: "library",
        node_id: node_id
      })

    base_time = DateTime.utc_now() |> DateTime.truncate(:second)

    usability_visit("3100001", "Usability Member A", node_id, location.id, base_time)

    usability_visit(
      "3100001",
      "Usability Member A",
      node_id,
      location.id,
      DateTime.add(base_time, -60)
    )

    usability_visit(
      "3100002",
      "Usability Member B",
      node_id,
      location.id,
      DateTime.add(base_time, -120)
    )
  end

  defp get_or_create_staff_member_type do
    case Repo.one(from mt in Voile.Schema.Master.MemberType, where: mt.slug == "staff", limit: 1) do
      %Voile.Schema.Master.MemberType{} = member_type ->
        member_type

      nil ->
        {:ok, member_type} =
          %Voile.Schema.Master.MemberType{}
          |> Voile.Schema.Master.MemberType.changeset(%{
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

  defp usability_member(fullname, identifier) do
    %User{}
    |> User.changeset(%{
      username: "usability_#{System.unique_integer([:positive])}",
      email: "usability_#{System.unique_integer([:positive])}@test.com",
      fullname: fullname,
      identifier: Decimal.new(identifier),
      password: "testpassword123",
      confirmed_at: DateTime.utc_now()
    })
    |> Repo.insert!()
  end

  defp usability_collection(title, node_id, creator, type_id) do
    {:ok, collection} =
      %Collection{}
      |> Collection.changeset(%{
        title: title,
        description: "Usability test collection",
        status: "published",
        access_level: "public",
        thumbnail: "test-thumbnail.jpg",
        collection_code: "USAB-COLL-#{System.unique_integer([:positive])}",
        creator_id: creator.id,
        type_id: type_id,
        unit_id: node_id
      })
      |> Repo.insert()

    collection
  end

  defp usability_item(collection) do
    {:ok, item} =
      Voile.Schema.Catalog.Item.changeset(%Voile.Schema.Catalog.Item{}, %{
        item_code: "USAB-#{System.unique_integer([:positive])}",
        inventory_code: "INV-#{System.unique_integer([:positive])}",
        barcode: "USAB-BAR-#{System.unique_integer([:positive])}",
        location: "Test Library - Shelf A1",
        status: "active",
        availability: "available",
        condition: "good",
        collection_id: collection.id,
        unit_id: collection.unit_id
      })
      |> Repo.insert()

    item
  end

  defp usability_visit(identifier, name, node_id, location_id, at) do
    Repo.insert!(%VisitorLog{
      visitor_identifier: identifier,
      visitor_name: name,
      visitor_origin: "Usability Test Origin",
      check_in_time: at,
      location_id: location_id,
      node_id: node_id
    })
  end
end
