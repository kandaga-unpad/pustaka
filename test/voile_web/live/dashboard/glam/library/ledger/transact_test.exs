defmodule VoileWeb.Dashboard.Glam.Library.Ledger.TransactTest do
  use VoileWeb.ConnCase

  import Phoenix.LiveViewTest
  import Voile.AccountsFixtures
  import Voile.SystemFixtures
  import Ecto.Query

  alias Voile.Repo
  alias Voile.Schema.Accounts.User
  alias Voile.Schema.Master.MemberType
  alias Voile.Schema.Catalog.Item

  setup do
    # Create librarian
    staff_member_type = get_or_create_staff_member_type()

    librarian =
      user_fixture(%{
        email: "librarian_#{System.unique_integer([:positive, :monotonic])}@test.com",
        username: "librarian_#{System.unique_integer([:positive, :monotonic])}",
        fullname: "Test Librarian",
        phone_number: "081234567890",
        user_type_id: staff_member_type.id
      })

    super_admin_role = get_or_create_super_admin_role()

    {:ok, _assignment} =
      VoileWeb.Auth.Authorization.assign_role(librarian.id, super_admin_role.id)

    # Get or create member type
    member_type = get_or_create_member_type()

    # Create member
    member =
      create_test_member(
        %{
          email: "member@test.com",
          fullname: "John Doe",
          identifier: Decimal.new("12345#{System.unique_integer([:positive])}"),
          phone_number: "123-456-7890",
          organization: "Test Org",
          registration_date: ~D[2024-01-01],
          expiry_date: ~D[2026-12-31]
        },
        member_type
      )

    # Use existing fixtures to create library items
    item1 = ensure_item_with_barcode("ITEM001")
    item2 = ensure_item_with_barcode("ITEM002")
    item3 = ensure_item_with_barcode("ITEM003")

    %{
      conn: log_in_user(build_conn(), librarian),
      librarian: librarian,
      member: member,
      member_type: member_type,
      item1: item1,
      item2: item2,
      item3: item3
    }
  end

  describe "Transact page initialization" do
    test "loads member information correctly", %{conn: conn, member: member} do
      {:ok, _view, html} = live(conn, ~p"/manage/glam/library/ledger/transact/#{member.id}")

      assert html =~ member.fullname
      assert html =~ member.email
      assert html =~ to_string(member.identifier)
    end

    test "redirects when member not found", %{conn: conn} do
      fake_id = Ecto.UUID.generate()

      assert {:error, {:live_redirect, %{to: path}}} =
               live(conn, ~p"/manage/glam/library/ledger/transact/#{fake_id}")

      assert path == "/manage/glam/library/ledger"
    end

    test "displays all five tabs", %{conn: conn, member: member} do
      {:ok, view, _html} = live(conn, ~p"/manage/glam/library/ledger/transact/#{member.id}")

      assert has_element?(view, "button[phx-value-tab=\"loan\"]")
      assert has_element?(view, "button[phx-value-tab=\"current_loans\"]")
      assert has_element?(view, "button[phx-value-tab=\"reserve\"]")
      assert has_element?(view, "button[phx-value-tab=\"fines\"]")
      assert has_element?(view, "button[phx-value-tab=\"history\"]")

      # Default tab should be Loan
      assert has_element?(view, "form[phx-submit=\"search_item\"]")
    end
  end

  describe "Loan Tab" do
    test "displays loan tab interface", %{conn: conn, member: member} do
      {:ok, view, _html} = live(conn, ~p"/manage/glam/library/ledger/transact/#{member.id}")

      assert has_element?(view, "form[phx-submit=\"search_item\"]")
    end

    test "shows message when no items in temporary loan list", %{conn: conn, member: member} do
      {:ok, view, _html} = live(conn, ~p"/manage/glam/library/ledger/transact/#{member.id}")

      assert render(view) =~ "Belum ada item yang ditambahkan."
    end
  end

  describe "Current Loans Tab" do
    test "can switch to current loans tab", %{conn: conn, member: member} do
      {:ok, view, _html} = live(conn, ~p"/manage/glam/library/ledger/transact/#{member.id}")

      # Switch to Current Loans tab
      view
      |> element("button[phx-click=\"change_tab\"][phx-value-tab=\"current_loans\"]")
      |> render_click()

      html = render(view)
      assert html =~ "Tidak ada pinjaman aktif untuk anggota ini." or html =~ "Pinjaman Saat Ini"
    end
  end

  describe "Reserve Tab" do
    test "can switch to reserve tab", %{conn: conn, member: member} do
      {:ok, view, _html} = live(conn, ~p"/manage/glam/library/ledger/transact/#{member.id}")

      # Switch to Reserve tab
      view
      |> element("button[phx-click=\"change_tab\"][phx-value-tab=\"reserve\"]")
      |> render_click()

      html = render(view)
      assert html =~ "Belum ada reservasi yang ditambahkan." or html =~ "Reservasi"
    end
  end

  describe "Fines Tab" do
    test "displays fines tab", %{conn: conn, member: member} do
      {:ok, view, _html} = live(conn, ~p"/manage/glam/library/ledger/transact/#{member.id}")

      # Switch to Fines tab
      view
      |> element("button[phx-click=\"change_tab\"][phx-value-tab=\"fines\"]")
      |> render_click()

      html = render(view)
      assert html =~ "Tidak ada denda yang belum dibayar." or html =~ "Denda"
    end
  end

  describe "Loan History Tab" do
    test "displays loan history tab", %{conn: conn, member: member} do
      {:ok, view, _html} = live(conn, ~p"/manage/glam/library/ledger/transact/#{member.id}")

      # Switch to Loan History tab
      view
      |> element("button[phx-click=\"change_tab\"][phx-value-tab=\"history\"]")
      |> render_click()

      html = render(view)
      assert html =~ "Riwayat pinjaman tidak tersedia." or html =~ "Riwayat Pinjaman"
    end
  end

  # Helper functions
  defp get_or_create_staff_member_type do
    case Repo.one(
           from mt in MemberType,
             where: mt.slug == "staff",
             limit: 1
         ) do
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
    alias Voile.Schema.Accounts.Role

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
      identifier: Decimal.new("#{System.unique_integer([:positive, :monotonic])}"),
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

  defp ensure_item_with_barcode(barcode) do
    case Repo.one(from i in Item, where: i.item_code == ^barcode, limit: 1) do
      %Item{} = item ->
        Repo.preload(item, [:collection])

      nil ->
        collection = ensure_collection()

        barcode_value = "#{barcode}-00000"

        {:ok, item} =
          %Item{}
          |> Item.changeset(%{
            item_code: barcode,
            barcode: barcode_value,
            inventory_code: "INV-#{barcode_value}",
            location: "Test Library - Shelf A1",
            status: "active",
            availability: "available",
            condition: "good",
            collection_id: collection.id,
            unit_id: collection.unit_id
          })
          |> Repo.insert()

        Repo.preload(item, [:collection])
    end
  end

  defp ensure_collection do
    alias Voile.Schema.Catalog.Collection

    case Repo.one(from c in Collection, limit: 1) do
      %Collection{} = collection ->
        Repo.preload(collection, [:mst_creator])

      nil ->
        creator = ensure_creator()
        node = node_fixture()

        {:ok, resource_class} =
          Voile.Schema.Metadata.create_resource_class(%{
            label: "Test Book Type",
            local_name: "TestBook",
            information: "Test resource class",
            glam_type: "Library"
          })

        {:ok, collection} =
          %Collection{}
          |> Collection.changeset(%{
            collection_code: "TEST-COLL-#{System.unique_integer([:positive])}",
            title: "Test Collection",
            description: "Test collection description",
            thumbnail: "test-thumbnail.jpg",
            status: "published",
            access_level: "public",
            creator_id: creator.id,
            type_id: resource_class.id,
            unit_id: node.id
          })
          |> Repo.insert()

        Repo.preload(collection, [:mst_creator])
    end
  end

  defp ensure_creator do
    alias Voile.Schema.Master.Creator

    case Repo.one(from c in Creator, limit: 1) do
      %Creator{} = creator ->
        creator

      nil ->
        {:ok, creator} =
          %Creator{}
          |> Creator.changeset(%{
            creator_name: "Test Creator",
            type: "Person",
            creator_contact: "test@example.com",
            affiliation: "Test Institution"
          })
          |> Repo.insert()

        creator
    end
  end
end
