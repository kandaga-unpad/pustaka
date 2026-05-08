defmodule Voile.Schema.StockOpname.MarkForDiscardTest do
  # async: false required because approve_session/3 spawns Task.Supervisor
  # workers that need DB connections from the sandbox owner.
  use Voile.DataCase, async: false

  import Voile.StockOpnameFixtures

  alias Voile.Repo
  alias Voile.Schema.StockOpname
  alias Voile.Schema.StockOpname.Session

  # ---------------------------------------------------------------------------
  # Shared setup
  # ---------------------------------------------------------------------------

  setup do
    allow_sandbox(self())

    node = node_fixture()
    rc = resource_class_fixture()
    admin = admin_user_fixture(%{"node_id" => node.id})
    collection = collection_fixture(node, rc, admin)
    catalog_item = catalog_item_fixture(collection, node, admin)

    %{admin: admin, node: node, collection: collection, catalog_item: catalog_item}
  end

  # ---------------------------------------------------------------------------
  # Approval helper (mirrors approve_session_test.exs)
  # ---------------------------------------------------------------------------

  defp approve_and_wait(session, admin) do
    StockOpname.subscribe_session(session.id)
    {:ok, _applying} = StockOpname.approve_session(session, admin, "discard test approval")
    wait_for_approval(10_000)
  end

  defp wait_for_approval(timeout) do
    receive do
      {:session_approved, _} -> :ok
      {:session_approval_failed, reason} -> flunk("Approval failed: #{inspect(reason)}")
      {:session_apply_progress, _} -> wait_for_approval(timeout)
    after
      timeout -> flunk("Timed out waiting for background approval to complete")
    end
  end

  # ===========================================================================
  # check_item_with_collection — marking a duplicate item for discard
  # ===========================================================================

  describe "check_item_with_collection/6 — mark for discard" do
    test "records status=discarded change on the opname item", %{
      admin: admin,
      node: node,
      catalog_item: catalog_item
    } do
      session = pending_review_session_fixture(node, admin, [catalog_item])
      opname_item = opname_item_fixture(session, catalog_item)

      assert {:ok, updated} =
               StockOpname.check_item_with_collection(
                 session,
                 opname_item.id,
                 %{"status" => "discarded"},
                 %{},
                 nil,
                 admin
               )

      assert updated.check_status == "checked"
      assert updated.has_changes == true
      assert updated.changes["status"] == "discarded"
      assert updated.checked_by_id == admin.id
    end

    test "increments session items_with_changes counter", %{
      admin: admin,
      node: node,
      collection: _collection,
      catalog_item: catalog_item
    } do
      session = pending_review_session_fixture(node, admin, [catalog_item])
      opname_item = opname_item_fixture(session, catalog_item)

      assert {:ok, _updated} =
               StockOpname.check_item_with_collection(
                 session,
                 opname_item.id,
                 %{"status" => "discarded"},
                 %{},
                 nil,
                 admin
               )

      updated_session = Repo.get!(Session, session.id)
      assert updated_session.items_with_changes == 1
      assert updated_session.checked_items == 1
    end
  end

  # ===========================================================================
  # approve_session — discard change is applied to catalog item
  # ===========================================================================

  describe "approve_session/3 — discarded items" do
    test "sets catalog item status to discarded on approval", %{
      admin: admin,
      node: node,
      catalog_item: catalog_item
    } do
      session = pending_review_session_fixture(node, admin, [catalog_item])

      _opname_item =
        opname_item_checked_fixture(
          session,
          catalog_item,
          %{"status" => "discarded"},
          admin
        )

      session =
        session
        |> Ecto.Changeset.change(%{checked_items: 1, items_with_changes: 1})
        |> Repo.update!()

      approve_and_wait(session, admin)

      reloaded = reload_catalog_item(catalog_item)
      assert reloaded.status == "discarded"
    end

    test "only marks the discarded item — other items in session are unaffected", %{
      admin: admin,
      node: node,
      collection: collection,
      catalog_item: discard_item
    } do
      keep_item = catalog_item_fixture(collection, node, admin, %{status: "active"})
      session = pending_review_session_fixture(node, admin, [discard_item, keep_item])

      _discard_opname_item =
        opname_item_checked_fixture(session, discard_item, %{"status" => "discarded"}, admin)

      _keep_opname_item = opname_item_checked_fixture(session, keep_item, %{}, admin)

      session =
        session
        |> Ecto.Changeset.change(%{checked_items: 2, items_with_changes: 1})
        |> Repo.update!()

      approve_and_wait(session, admin)

      results = reload_catalog_items([discard_item, keep_item])
      assert results[discard_item.id].status == "discarded"
      assert results[keep_item.id].status == "active"
    end
  end
end
