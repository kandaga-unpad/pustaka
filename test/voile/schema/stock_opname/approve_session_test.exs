defmodule Voile.Schema.StockOpname.ApproveSessionTest do
  # async: false is required because approve_session/3 uses Task.Supervisor to
  # run bulk updates in background tasks. Those tasks need DB connections that
  # would conflict with sandbox isolation in async mode.
  use Voile.DataCase, async: false

  import Voile.StockOpnameFixtures

  alias Voile.Schema.StockOpname

  # ---------------------------------------------------------------------------
  # Shared setup
  # ---------------------------------------------------------------------------

  setup do
    # Put the sandbox in shared mode so the background Task.Supervisor worker
    # spawned by approve_session/3 can check out connections from this test's
    # sandbox owner without hitting ownership errors.
    allow_sandbox(self())

    admin = admin_user_fixture()
    node = node_fixture()
    rc = resource_class_fixture()
    collection = collection_fixture(node, rc, admin)

    %{admin: admin, node: node, collection: collection}
  end

  # ---------------------------------------------------------------------------
  # Helper: approve a session and block until the background task has finished
  # (i.e. session.status transitions from "applying" → "approved"), then
  # return a map of reloaded catalog item fields keyed by item id.
  #
  # approve_session/3 now returns {:ok, applying_session} immediately and
  # completes the bulk updates in a Task.Supervisor background task that
  # broadcasts {:session_approved, session} on PubSub when done. We subscribe
  # before calling approve so we can block with a receive timeout instead of
  # polling.
  # ---------------------------------------------------------------------------

  defp approve_and_reload(session, admin, catalog_items) do
    StockOpname.subscribe_session(session.id)
    {:ok, _applying} = StockOpname.approve_session(session, admin, "test approval")

    # Wait up to 5 seconds for the background task to finish.
    receive do
      {:session_approved, _approved_session} -> :ok
      {:session_approval_failed, reason} -> flunk("Approval failed: #{inspect(reason)}")
    after
      5_000 -> flunk("Timed out waiting for background approval to complete")
    end

    reload_catalog_items(catalog_items)
  end

  # ===========================================================================
  # Step 1 — items never scanned (check_status: "pending")
  # ===========================================================================

  describe "approve_session/3 — pending (never scanned) items" do
    test "marks unscanned item as missing in catalog", %{
      admin: admin,
      node: node,
      collection: collection
    } do
      item = catalog_item_fixture(collection, node, admin, %{availability: "available"})
      session = pending_review_session_fixture(node, admin, [item])
      _opname_item = opname_item_fixture(session, item)

      reloaded = approve_and_reload(session, admin, [item])

      assert reloaded[item.id].availability == "missing"
    end

    test "marks multiple unscanned items as missing", %{
      admin: admin,
      node: node,
      collection: collection
    } do
      items = for _ <- 1..3, do: catalog_item_fixture(collection, node, admin)
      session = pending_review_session_fixture(node, admin, items)
      for item <- items, do: opname_item_fixture(session, item)

      reloaded = approve_and_reload(session, admin, items)

      for item <- items do
        assert reloaded[item.id].availability == "missing"
      end
    end

    test "does not touch catalog items that belong to a different session", %{
      admin: admin,
      node: node,
      collection: collection
    } do
      item_in_session =
        catalog_item_fixture(collection, node, admin, %{availability: "available"})

      item_other = catalog_item_fixture(collection, node, admin, %{availability: "available"})

      session = pending_review_session_fixture(node, admin, [item_in_session])
      opname_item_fixture(session, item_in_session)
      # item_other is deliberately NOT added to the session

      reloaded = approve_and_reload(session, admin, [item_in_session, item_other])

      assert reloaded[item_in_session.id].availability == "missing"
      assert reloaded[item_other.id].availability == "available"
    end
  end

  # ===========================================================================
  # Step 2 — items explicitly flagged missing (check_status: "missing")
  # ===========================================================================

  describe "approve_session/3 — explicitly missing items" do
    test "marks explicitly-missing item as missing in catalog", %{
      admin: admin,
      node: node,
      collection: collection
    } do
      item = catalog_item_fixture(collection, node, admin, %{availability: "available"})
      session = pending_review_session_fixture(node, admin, [item])
      opname_item_missing_fixture(session, item)

      reloaded = approve_and_reload(session, admin, [item])

      assert reloaded[item.id].availability == "missing"
    end

    test "marks multiple explicitly-missing items as missing", %{
      admin: admin,
      node: node,
      collection: collection
    } do
      items = for _ <- 1..4, do: catalog_item_fixture(collection, node, admin)
      session = pending_review_session_fixture(node, admin, items)
      for item <- items, do: opname_item_missing_fixture(session, item)

      reloaded = approve_and_reload(session, admin, items)

      for item <- items do
        assert reloaded[item.id].availability == "missing"
      end
    end

    test "explicitly-missing flag overrides any previous availability value", %{
      admin: admin,
      node: node,
      collection: collection
    } do
      # Start with a loaned item — still must become missing when flagged
      item = catalog_item_fixture(collection, node, admin, %{availability: "loaned"})
      session = pending_review_session_fixture(node, admin, [item])
      opname_item_missing_fixture(session, item)

      reloaded = approve_and_reload(session, admin, [item])

      assert reloaded[item.id].availability == "missing"
    end

    test "item not in session scope remains untouched even if missing elsewhere", %{
      admin: admin,
      node: node,
      collection: collection
    } do
      item_in = catalog_item_fixture(collection, node, admin, %{availability: "available"})
      item_out = catalog_item_fixture(collection, node, admin, %{availability: "available"})

      session = pending_review_session_fixture(node, admin, [item_in])
      opname_item_missing_fixture(session, item_in)
      # item_out has no opname row in this session

      reloaded = approve_and_reload(session, admin, [item_in, item_out])

      assert reloaded[item_in.id].availability == "missing"
      assert reloaded[item_out.id].availability == "available"
    end
  end

  # ===========================================================================
  # Step 3 — checked items with recorded field changes
  # ===========================================================================

  describe "approve_session/3 — checked items with field changes" do
    test "applies condition change to catalog item", %{
      admin: admin,
      node: node,
      collection: collection
    } do
      item = catalog_item_fixture(collection, node, admin, %{condition: "good"})
      session = pending_review_session_fixture(node, admin, [item])
      opname_item_checked_fixture(session, item, %{"condition" => "poor"}, admin)

      reloaded = approve_and_reload(session, admin, [item])

      assert reloaded[item.id].condition == "poor"
    end

    test "applies status change to catalog item", %{
      admin: admin,
      node: node,
      collection: collection
    } do
      item = catalog_item_fixture(collection, node, admin, %{status: "active"})
      session = pending_review_session_fixture(node, admin, [item])
      opname_item_checked_fixture(session, item, %{"status" => "damaged"}, admin)

      reloaded = approve_and_reload(session, admin, [item])

      assert reloaded[item.id].status == "damaged"
    end

    test "applies explicit availability change to catalog item", %{
      admin: admin,
      node: node,
      collection: collection
    } do
      item = catalog_item_fixture(collection, node, admin, %{availability: "available"})
      session = pending_review_session_fixture(node, admin, [item])

      opname_item_checked_fixture(
        session,
        item,
        %{"availability" => "maintenance"},
        admin
      )

      reloaded = approve_and_reload(session, admin, [item])

      assert reloaded[item.id].availability == "maintenance"
    end

    test "applies location change to catalog item", %{
      admin: admin,
      node: node,
      collection: collection
    } do
      item = catalog_item_fixture(collection, node, admin, %{location: "Shelf A"})
      session = pending_review_session_fixture(node, admin, [item])
      opname_item_checked_fixture(session, item, %{"location" => "Storage Room"}, admin)

      reloaded = approve_and_reload(session, admin, [item])

      assert reloaded[item.id].location == "Storage Room"
    end

    test "applies multiple field changes in a single opname item", %{
      admin: admin,
      node: node,
      collection: collection
    } do
      item =
        catalog_item_fixture(collection, node, admin, %{
          condition: "good",
          status: "active",
          location: "Shelf B"
        })

      session = pending_review_session_fixture(node, admin, [item])

      opname_item_checked_fixture(
        session,
        item,
        %{"condition" => "poor", "status" => "damaged", "location" => "Archive"},
        admin
      )

      reloaded = approve_and_reload(session, admin, [item])

      assert reloaded[item.id].condition == "poor"
      assert reloaded[item.id].status == "damaged"
      assert reloaded[item.id].location == "Archive"
    end

    test "checked item without changes leaves catalog item untouched", %{
      admin: admin,
      node: node,
      collection: collection
    } do
      item =
        catalog_item_fixture(collection, node, admin, %{
          availability: "available",
          condition: "excellent"
        })

      session = pending_review_session_fixture(node, admin, [item])
      # Empty changes map — librarian confirmed item is fine
      opname_item_checked_fixture(session, item, %{}, admin)

      reloaded = approve_and_reload(session, admin, [item])

      assert reloaded[item.id].availability == "available"
      assert reloaded[item.id].condition == "excellent"
    end
  end

  # ===========================================================================
  # Mixed scenarios — multiple items with different check statuses
  # ===========================================================================

  describe "approve_session/3 — mixed check statuses" do
    test "correctly handles pending, missing and checked items in the same session", %{
      admin: admin,
      node: node,
      collection: collection
    } do
      pending_item = catalog_item_fixture(collection, node, admin, %{availability: "available"})
      missing_item = catalog_item_fixture(collection, node, admin, %{availability: "available"})

      checked_ok_item =
        catalog_item_fixture(collection, node, admin, %{availability: "available"})

      checked_changed_item =
        catalog_item_fixture(collection, node, admin, %{
          availability: "available",
          condition: "good"
        })

      all_items = [pending_item, missing_item, checked_ok_item, checked_changed_item]
      session = pending_review_session_fixture(node, admin, all_items)

      # pending — never scanned
      opname_item_fixture(session, pending_item)

      # explicitly missing
      opname_item_missing_fixture(session, missing_item)

      # checked, no issues found
      opname_item_checked_fixture(session, checked_ok_item, %{}, admin)

      # checked, condition deteriorated
      opname_item_checked_fixture(
        session,
        checked_changed_item,
        %{"condition" => "poor"},
        admin
      )

      reloaded = approve_and_reload(session, admin, all_items)

      # never scanned → missing
      assert reloaded[pending_item.id].availability == "missing"

      # explicitly flagged → missing
      assert reloaded[missing_item.id].availability == "missing"

      # confirmed ok → availability unchanged
      assert reloaded[checked_ok_item.id].availability == "available"

      # changed field applied, availability unchanged
      assert reloaded[checked_changed_item.id].availability == "available"
      assert reloaded[checked_changed_item.id].condition == "poor"
    end

    test "a checked item can restore an item back to available", %{
      admin: admin,
      node: node,
      collection: collection
    } do
      # Item was previously missing, librarian found it and marked it available again
      item = catalog_item_fixture(collection, node, admin, %{availability: "missing"})
      session = pending_review_session_fixture(node, admin, [item])

      opname_item_checked_fixture(
        session,
        item,
        %{"availability" => "available"},
        admin
      )

      reloaded = approve_and_reload(session, admin, [item])

      assert reloaded[item.id].availability == "available"
    end
  end

  # ===========================================================================
  # Guard — only pending_review sessions can be approved
  # ===========================================================================

  describe "approve_session/3 — status guard" do
    test "returns error when session is not in pending_review status", %{
      admin: admin,
      node: node
    } do
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      draft_session =
        Voile.Repo.insert!(%Voile.Schema.StockOpname.Session{
          title: "Draft session",
          session_code: "SO-DRAFT-#{System.unique_integer([:positive])}",
          node_ids: [node.id],
          collection_types: ["Library"],
          scope_type: "all",
          status: "draft",
          started_at: now,
          total_items: 0,
          checked_items: 0,
          missing_items: 0,
          items_with_changes: 0,
          created_by_id: admin.id
        })

      assert {:error, :invalid_status} =
               StockOpname.approve_session(draft_session, admin, "notes")
    end
  end
end
