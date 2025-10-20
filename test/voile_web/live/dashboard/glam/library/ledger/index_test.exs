defmodule VoileWeb.Dashboard.Glam.Library.Ledger.IndexTest do
  use VoileWeb.ConnCase

  import Phoenix.LiveViewTest
  import Voile.AccountsFixtures
  import Voile.LibraryFixtures
  import Ecto.Query

  alias Voile.Repo
  alias Voile.Schema.Accounts.User
  alias Voile.Schema.Master.MemberType

  setup do
    # Create a librarian user with appropriate roles
    librarian = user_fixture(%{
      email: "librarian@test.com",
      username: "librarian",
      fullname: "Test Librarian"
    })

    # Get or create member type
    member_type = get_or_create_member_type()

    # Create test members with identifiers
    member1 = create_test_member(
      %{
        email: "member1@test.com",
        fullname: "John Doe",
        identifier: Decimal.new("12345"),
        phone_number: "123-456-7890",
        organization: "Test Org",
        registration_date: ~D[2024-01-01],
        expiry_date: ~D[2026-12-31]
      },
      member_type
    )

    member2 = create_test_member(
      %{
        email: "member2@test.com",
        fullname: "Jane Smith",
        identifier: Decimal.new("67890"),
        phone_number: "098-765-4321",
        organization: "Another Org",
        registration_date: ~D[2024-06-01],
        expiry_date: ~D[2025-06-30]
      },
      member_type
    )

    member3 = create_test_member(
      %{
        email: "expired@test.com",
        fullname: "Expired Member",
        identifier: Decimal.new("11111"),
        expiry_date: ~D[2024-01-01]
      },
      member_type
    )

    %{
      conn: log_in_user(build_conn(), librarian),
      librarian: librarian,
      member1: member1,
      member2: member2,
      expired_member: member3,
      member_type: member_type
    }
  end

  describe "Index page" do
    test "displays the search interface", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/manage/glam/library/ledger")

      assert html =~ "Start Library Transactions"
      assert html =~ "Find Member"
      assert html =~ "Search by identifier, name, or email"
      assert has_element?(view, "input#member-search")
    end

    test "shows dropdown results when searching by identifier", %{conn: conn, member1: member1} do
      {:ok, view, _html} = live(conn, ~p"/manage/glam/library/ledger")

      # Type identifier
      view
      |> element("input#member-search")
      |> render_keyup(%{value: "123"})

      # Should show dropdown with member
      assert has_element?(view, "button[phx-value-member_id=\"#{member1.id}\"]")
      assert render(view) =~ member1.fullname
      assert render(view) =~ member1.email
    end

    test "shows dropdown results when searching by name", %{conn: conn, member1: member1} do
      {:ok, view, _html} = live(conn, ~p"/manage/glam/library/ledger")

      # Type name
      view
      |> element("input#member-search")
      |> render_keyup(%{value: "John"})

      # Should show dropdown with member
      assert has_element?(view, "button[phx-value-member_id=\"#{member1.id}\"]")
      assert render(view) =~ member1.fullname
    end

    test "shows dropdown results when searching by email", %{conn: conn, member2: member2} do
      {:ok, view, _html} = live(conn, ~p"/manage/glam/library/ledger")

      # Type email
      view
      |> element("input#member-search")
      |> render_keyup(%{value: "member2"})

      # Should show dropdown with member
      assert has_element?(view, "button[phx-value-member_id=\"#{member2.id}\"]")
      assert render(view) =~ member2.email
    end

    test "shows no results message when member not found", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/manage/glam/library/ledger")

      # Type non-existent identifier
      view
      |> element("input#member-search")
      |> render_keyup(%{value: "99999"})

      # Should show no results
      assert render(view) =~ "No members found"
    end

    test "clears search when input is empty", %{conn: conn, member1: member1} do
      {:ok, view, _html} = live(conn, ~p"/manage/glam/library/ledger")

      # First search for member
      view
      |> element("input#member-search")
      |> render_keyup(%{value: "123"})

      assert has_element?(view, "button[phx-value-member_id=\"#{member1.id}\"]")

      # Clear input
      view
      |> element("input#member-search")
      |> render_keyup(%{value: ""})

      # Dropdown should be hidden
      refute has_element?(view, "button[phx-value-member_id=\"#{member1.id}\"]")
    end

    test "selects member and shows profile preview", %{conn: conn, member1: member1} do
      {:ok, view, _html} = live(conn, ~p"/manage/glam/library/ledger")

      # Search for member
      view
      |> element("input#member-search")
      |> render_keyup(%{value: "123"})

      # Click on member
      view
      |> element("button[phx-value-member_id=\"#{member1.id}\"]")
      |> render_click()

      html = render(view)

      # Should show member profile
      assert html =~ "Member Information"
      assert html =~ member1.fullname
      assert html =~ member1.email
      assert html =~ member1.phone_number
      assert html =~ member1.organization
      assert html =~ "Continue to Transaction"
    end

    test "shows expired badge for expired members", %{conn: conn, expired_member: member} do
      {:ok, view, _html} = live(conn, ~p"/manage/glam/library/ledger")

      # Search for expired member
      view
      |> element("input#member-search")
      |> render_keyup(%{value: "11111"})

      # Click on member
      view
      |> element("button[phx-value-member_id=\"#{member.id}\"]")
      |> render_click()

      html = render(view)

      # Should show expired badge
      assert html =~ "Expired"
    end

    test "can clear selection and search again", %{conn: conn, member1: member1} do
      {:ok, view, _html} = live(conn, ~p"/manage/glam/library/ledger")

      # Search and select member
      view
      |> element("input#member-search")
      |> render_keyup(%{value: "123"})

      view
      |> element("button[phx-value-member_id=\"#{member1.id}\"]")
      |> render_click()

      assert render(view) =~ "Member Information"

      # Click clear/change member button
      view
      |> element("button[phx-click=\"clear_selection\"]")
      |> render_click()

      # Should return to search interface
      html = render(view)
      assert html =~ "Find Member"
      refute html =~ "Member Information"
    end

    test "navigates to transaction page on continue", %{conn: conn, member1: member1} do
      {:ok, view, _html} = live(conn, ~p"/manage/glam/library/ledger")

      # Search and select member
      view
      |> element("input#member-search")
      |> render_keyup(%{value: "123"})

      view
      |> element("button[phx-value-member_id=\"#{member1.id}\"]")
      |> render_click()

      # Click continue button
      view
      |> element("button[phx-click=\"continue_transaction\"]")
      |> render_click()

      # Should redirect to transact page
      assert_redirect(view, ~p"/manage/glam/library/ledger/transact/#{member1.id}")
    end

    test "limits search results to 10 members", %{conn: conn, member_type: member_type} do
      # Create 15 members with similar names
      for i <- 1..15 do
        create_test_member(
          %{
            email: "test#{i}@test.com",
            fullname: "Test User #{i}",
            identifier: Decimal.new("#{20000 + i}")
          },
          member_type
        )
      end

      {:ok, view, _html} = live(conn, ~p"/manage/glam/library/ledger")

      # Search for "Test"
      view
      |> element("input#member-search")
      |> render_keyup(%{value: "Test"})

      html = render(view)

      # Should only show 10 results (check by counting buttons)
      buttons =
        html
        |> Floki.parse_document!()
        |> Floki.find("button[phx-click=\"select_member\"]")

      assert length(buttons) <= 10
    end
  end

  # Helper functions
  defp get_or_create_member_type do
    case Repo.one(
           from mt in MemberType,
             where: mt.is_active == true and mt.can_renew == true,
             limit: 1
         ) do
      %MemberType{} = member_type ->
        member_type

      nil ->
        {:ok, member_type} =
          %MemberType{}
          |> MemberType.changeset(%{
            name: "Regular Member",
            slug: "regular-#{System.unique_integer([:positive])}",
            description: "Regular library member",
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

  defp create_test_member(attrs, member_type) do
    default_attrs = %{
      username: "user_#{System.unique_integer([:positive])}",
      email: "user_#{System.unique_integer([:positive])}@example.com",
      fullname: "Test User",
      identifier: Decimal.new("#{System.unique_integer([:positive])}"),
      user_type_id: member_type.id,
      confirmed_at: DateTime.utc_now(),
      password: "testpassword123"
    }

    merged_attrs = Map.merge(default_attrs, attrs)

    %User{}
    |> User.changeset(merged_attrs)
    |> Repo.insert!()
    |> Repo.preload([:user_type])
  end
end
