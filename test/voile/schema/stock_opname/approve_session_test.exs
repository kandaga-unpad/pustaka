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

    node = node_fixture()
    rc = resource_class_fixture()
    admin = admin_user_fixture(%{"node_id" => node.id})
    collection = collection_fixture(node, rc, admin)

    %{admin: admin, node: node, rc: rc, collection: collection}
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

    # Wait up to 10 seconds for the background task to finish.
    # The batched implementation broadcasts progress messages before the final
    # :session_approved/:session_approval_failed — we must drain them.
    wait_for_approval(10_000)

    reload_catalog_items(catalog_items)
  end

  defp wait_for_approval(timeout) do
    receive do
      {:session_approved, _approved_session} -> :ok
      {:session_approval_failed, reason} -> flunk("Approval failed: #{inspect(reason)}")
      {:session_apply_progress, _progress} -> wait_for_approval(timeout)
    after
      timeout -> flunk("Timed out waiting for background approval to complete")
    end
  end

  defp collect_approval_messages(timeout, acc \\ []) do
    receive do
      {:session_approved, _} = msg -> Enum.reverse([msg | acc])
      {:session_approval_failed, reason} -> flunk("Approval failed: #{inspect(reason)}")
      {:session_apply_progress, _} = msg -> collect_approval_messages(timeout, [msg | acc])
    after
      timeout -> flunk("Timed out waiting for background approval to complete")
    end
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

  # ===========================================================================
  # Step 4 — archive collections whose every item is missing
  # ===========================================================================

  describe "approve_session/3 — archive fully-missing collections" do
    test "archives a collection when all its items are missing after approval", %{
      admin: admin,
      node: node,
      collection: collection
    } do
      item1 = catalog_item_fixture(collection, node, admin, %{availability: "available"})
      item2 = catalog_item_fixture(collection, node, admin, %{availability: "available"})
      session = pending_review_session_fixture(node, admin, [item1, item2])
      # Both items never scanned — will be marked missing in step 1
      opname_item_fixture(session, item1)
      opname_item_fixture(session, item2)

      approve_and_reload(session, admin, [item1, item2])

      assert reload_collection(collection).status == "archived"
    end

    test "does not archive a collection that still has a non-missing item", %{
      admin: admin,
      node: node,
      collection: collection
    } do
      missing_item = catalog_item_fixture(collection, node, admin, %{availability: "available"})
      ok_item = catalog_item_fixture(collection, node, admin, %{availability: "available"})
      session = pending_review_session_fixture(node, admin, [missing_item, ok_item])

      opname_item_fixture(session, missing_item)
      # ok_item is checked with no changes — availability stays "available"
      opname_item_checked_fixture(session, ok_item, %{}, admin)

      approve_and_reload(session, admin, [missing_item, ok_item])

      assert reload_collection(collection).status == "published"
    end

    test "does not re-archive a collection that is already archived", %{
      admin: admin,
      node: node,
      collection: collection
    } do
      # Manually set the collection to archived before the session runs
      Voile.Repo.update!(Ecto.Changeset.change(collection, status: "archived"))

      item = catalog_item_fixture(collection, node, admin, %{availability: "available"})
      session = pending_review_session_fixture(node, admin, [item])
      opname_item_fixture(session, item)

      approve_and_reload(session, admin, [item])

      # Still archived — not raised from archived or toggled
      assert reload_collection(collection).status == "archived"
    end

    test "archives only the collection with all items missing, leaves the other intact", %{
      admin: admin,
      node: node,
      rc: rc
    } do
      collection_all_missing = collection_fixture(node, rc, admin)
      collection_partial = collection_fixture(node, rc, admin)

      # collection_all_missing: both items are never scanned → will be marked missing
      m1 = catalog_item_fixture(collection_all_missing, node, admin)
      m2 = catalog_item_fixture(collection_all_missing, node, admin)

      # collection_partial: one missing, one confirmed ok
      p_missing = catalog_item_fixture(collection_partial, node, admin)
      p_ok = catalog_item_fixture(collection_partial, node, admin, %{availability: "available"})

      all_items = [m1, m2, p_missing, p_ok]
      session = pending_review_session_fixture(node, admin, all_items)

      opname_item_fixture(session, m1)
      opname_item_fixture(session, m2)
      opname_item_fixture(session, p_missing)
      opname_item_checked_fixture(session, p_ok, %{}, admin)

      approve_and_reload(session, admin, all_items)

      assert reload_collection(collection_all_missing).status == "archived"
      assert reload_collection(collection_partial).status == "published"
    end

    test "a checked item with availability set to available keeps the collection published", %{
      admin: admin,
      node: node,
      collection: collection
    } do
      item1 = catalog_item_fixture(collection, node, admin, %{availability: "available"})
      item2 = catalog_item_fixture(collection, node, admin, %{availability: "available"})
      session = pending_review_session_fixture(node, admin, [item1, item2])

      # item1 never scanned → missing
      opname_item_fixture(session, item1)
      # item2 checked and explicitly set to available
      opname_item_checked_fixture(session, item2, %{"availability" => "available"}, admin)

      approve_and_reload(session, admin, [item1, item2])

      assert reload_collection(collection).status == "published"
    end

    test "items outside session scope are not counted when deciding to archive", %{
      admin: admin,
      node: node,
      collection: collection
    } do
      # item_in_session is missing after approval
      item_in = catalog_item_fixture(collection, node, admin, %{availability: "available"})
      # item_outside is available but NOT part of this session
      _item_out = catalog_item_fixture(collection, node, admin, %{availability: "available"})

      # Only item_in is in the session
      session = pending_review_session_fixture(node, admin, [item_in])
      opname_item_fixture(session, item_in)

      approve_and_reload(session, admin, [item_in])

      # item_out is still available → collection must NOT be archived
      assert reload_collection(collection).status == "published"
    end
  end

  # ===========================================================================
  # Batched processing — progress messages and multi-batch coverage
  # ===========================================================================

  describe "approve_session/3 — batched processing" do
    test "broadcasts progress messages during approval", %{
      admin: admin,
      node: node,
      collection: collection
    } do
      item = catalog_item_fixture(collection, node, admin, %{availability: "available"})
      session = pending_review_session_fixture(node, admin, [item])
      opname_item_fixture(session, item)

      StockOpname.subscribe_session(session.id)
      {:ok, _applying} = StockOpname.approve_session(session, admin, "test approval")

      # Collect all messages until approval completes
      messages = collect_approval_messages(10_000)

      # We should have received at least one progress message
      progress_messages =
        Enum.filter(messages, fn
          {:session_apply_progress, _} -> true
          _ -> false
        end)

      assert length(progress_messages) > 0

      # The final message should be :session_approved
      assert {:session_approved, _} = List.last(messages)
    end

    test "handles a batch of items exceeding a single batch size", %{
      admin: admin,
      node: node,
      collection: collection
    } do
      # Create enough items to span multiple batched updates
      # Using 15 items — they'll all be "pending" (never scanned) so the
      # batch_mark_missing path gets exercised.
      items =
        for _ <- 1..15 do
          catalog_item_fixture(collection, node, admin, %{availability: "available"})
        end

      session = pending_review_session_fixture(node, admin, items)
      for item <- items, do: opname_item_fixture(session, item)

      reloaded = approve_and_reload(session, admin, items)

      for item <- items do
        assert reloaded[item.id].availability == "missing"
      end
    end

    test "handles mixed batch of checked items with changes across batches", %{
      admin: admin,
      node: node,
      collection: collection
    } do
      # Create items with field changes — exercises the batch_apply_item_changes path
      items =
        for i <- 1..10 do
          catalog_item_fixture(collection, node, admin, %{
            condition: "good",
            location: "Shelf #{i}"
          })
        end

      session = pending_review_session_fixture(node, admin, items)

      for item <- items do
        opname_item_checked_fixture(
          session,
          item,
          %{"condition" => "poor", "location" => "Archive"},
          admin
        )
      end

      reloaded = approve_and_reload(session, admin, items)

      for item <- items do
        assert reloaded[item.id].condition == "poor"
        assert reloaded[item.id].location == "Archive"
      end
    end
  end
end
