defmodule VoileWeb.Dashboard.Catalog.CollectionLive.AddItemLibrarianNodeTest do
  @moduledoc """
  Tests that item codes and inventory codes generated when adding items to a
  collection use the *librarian's* assigned node (current_scope.user.node_id),
  and NOT the collection's unit_id.

  This is the key invariant introduced by the refactor: a single collection can
  have its physical copies split across multiple nodes.  Each copy's item_code
  and inventory_code must uniquely identify *where* the item physically lives
  (the librarian's node), independently of which node "owns" the collection
  metadata.
  """

  use VoileWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Voile.AccountsFixtures
  import Voile.SystemFixtures

  alias Voile.Repo
  alias Voile.Schema.Accounts.{Role, UserRoleAssignment}
  alias Voile.Schema.Catalog
  alias Voile.Schema.Master
  alias Voile.Schema.Metadata
  # ---------------------------------------------------------------------------
  # Shared setup
  # ---------------------------------------------------------------------------

  setup %{conn: conn} do
    # Two nodes with clearly distinct abbreviations so assertions are unambiguous.
    librarian_node = node_fixture(%{abbr: "LIBTEST", name: "Librarian Test Node"})
    collection_node = node_fixture(%{abbr: "COLTEST", name: "Collection Test Node"})

    # Member type with slug "staff" so the auth hook allows access.
    {:ok, staff_type} =
      Voile.Schema.Master.create_member_type(%{
        name: "Staff Test Type",
        slug: "staff",
        loan_period: 14,
        loan_limit: 5,
        membership_period: 365
      })

    # Create a user and assign them to the *librarian* node.
    user = user_fixture()

    user =
      Repo.update!(
        Ecto.Changeset.change(user, %{
          node_id: librarian_node.id,
          user_type_id: staff_type.id,
          # Provide basic profile so non-super_admin users pass onboarding check
          fullname: "Test Librarian",
          phone_number: "0812345678",
          # Confirm the account
          confirmed_at: DateTime.utc_now() |> DateTime.truncate(:second)
        })
      )

    # Assign super_admin role so the user:
    #   1. Passes all permissions checks (items.create, etc.)
    #   2. Is exempt from the onboarding check
    # Use insert_or_ignore / get_by to avoid unique constraint errors when
    # the role already exists in the DB.
    role =
      case Repo.get_by(Role, name: "super_admin") do
        nil ->
          %Role{}
          |> Role.changeset(%{name: "super_admin", description: "Super admin for tests"})
          |> Repo.insert!()

        existing ->
          existing
      end

    %UserRoleAssignment{}
    |> UserRoleAssignment.changeset(%{
      user_id: user.id,
      role_id: role.id,
      scope_type: "global"
    })
    |> Repo.insert!()

    # Creator is required by the collection changeset.
    {:ok, creator} =
      Master.get_or_create_creator(%{
        creator_name: "Test Creator for Item Code Test"
      })

    # type_id is required by the DB schema; create a throwaway resource class.
    {:ok, resource_class} =
      Metadata.create_resource_class(%{
        label: "Test Book Type",
        local_name: "TestBook",
        information: "Test resource class",
        glam_type: "Library"
      })

    # Use a generated collection_code to satisfy the NOT NULL DB constraint.
    collection_code = "TEST-COLL-#{System.unique_integer([:positive])}"

    # Collection owned by the *collection* node (different from librarian's node).
    {:ok, collection} =
      Catalog.create_collection(%{
        title: "Test Collection for Item Code Test",
        description: "A test collection",
        thumbnail: "test-thumbnail.jpg",
        status: "published",
        access_level: "public",
        collection_code: collection_code,
        creator_id: creator.id,
        type_id: resource_class.id,
        unit_id: collection_node.id
      })

    %{
      conn: log_in_user(conn, user),
      user: user,
      librarian_node: librarian_node,
      collection_node: collection_node,
      collection: collection
    }
  end

  # ---------------------------------------------------------------------------
  # Tests
  # ---------------------------------------------------------------------------

  describe "apply_action :add_item_to_collection – item code uses librarian's node" do
    test "item_code starts with the librarian node's abbr (not the collection node's abbr)",
         %{
           conn: conn,
           collection: collection,
           librarian_node: librarian_node,
           collection_node: collection_node
         } do
      {:ok, _view, html} =
        live(conn, ~p"/manage/catalog/collections/add-item/#{collection.id}")

      librarian_abbr = String.downcase(librarian_node.abbr)
      collection_abbr = String.downcase(collection_node.abbr)

      # The pre-filled item_code rendered in the form should contain the
      # librarian node's abbr, not the collection node's abbr.
      assert html =~ librarian_abbr,
             "Expected item_code to contain librarian node abbr '#{librarian_abbr}' but got:\n#{html}"

      refute html =~ collection_abbr <> "-",
             "item_code must NOT contain collection node abbr '#{collection_abbr}-'"
    end

    test "inventory_code starts with INV/<librarian_abbr>/ (not collection_abbr)",
         %{
           conn: conn,
           collection: collection,
           librarian_node: librarian_node,
           collection_node: collection_node
         } do
      {:ok, _view, html} =
        live(conn, ~p"/manage/catalog/collections/add-item/#{collection.id}")

      # INV/LIBTEST/... should appear; INV/COLTEST/... should NOT.
      assert html =~ "INV/#{librarian_node.abbr}/",
             "Expected inventory_code prefix 'INV/#{librarian_node.abbr}/' not found in rendered HTML"

      refute html =~ "INV/#{collection_node.abbr}/",
             "inventory_code must NOT use collection node abbr '#{collection_node.abbr}'"
    end

    test "item unit_id is set to the librarian's node, not the collection's unit_id",
         %{
           conn: conn,
           collection: collection,
           librarian_node: librarian_node,
           collection_node: collection_node
         } do
      {:ok, _view, html} =
        live(conn, ~p"/manage/catalog/collections/add-item/#{collection.id}")

      librarian_id_str = to_string(librarian_node.id)
      collection_id_str = to_string(collection_node.id)

      document = LazyHTML.from_fragment(html)

      # The unit_id field is rendered as:
      #   - <input type="hidden" name="item[unit_id]"> when lock_unit_id=true (non-admin)
      #   - <select name="item[unit_id]"> with a selected <option> when lock_unit_id=false (super_admin)
      # We handle both by querying both element types.

      # Check hidden inputs first.
      hidden_inputs = LazyHTML.query(document, ~s(input[name="item[unit_id]"]))
      hidden_values = LazyHTML.attribute(hidden_inputs, "value")

      # Check selected options inside the select for unit_id.
      # The <option> that represents the selected node will contain `selected`.
      unit_id_select = LazyHTML.query(document, ~s(select[name="item[unit_id]"]))
      selected_options = LazyHTML.query(unit_id_select, "option[selected]")
      selected_values = LazyHTML.attribute(selected_options, "value")

      all_values = hidden_values ++ selected_values

      assert all_values != [],
             "unit_id field not found as either a hidden input or a selected option.\n" <>
               "Check that the item form renders item[unit_id]. HTML snippet:\n" <>
               String.slice(html, 0, 2000)

      assert Enum.all?(all_values, &(&1 == librarian_id_str)),
             "Expected item[unit_id] to equal librarian node id #{librarian_id_str}, " <>
               "got: #{inspect(all_values)}"

      refute Enum.any?(all_values, &(&1 == collection_id_str)),
             "item[unit_id] must NOT be set to the collection node's id #{collection_id_str}. " <>
               "Got: #{inspect(all_values)}"
    end
  end
end
