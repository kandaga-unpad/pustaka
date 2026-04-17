defmodule Voile.Schema.StockOpname.RejectRevisionTest do
  use Voile.DataCase, async: false

  import Voile.StockOpnameFixtures

  alias Voile.Repo
  alias Voile.Schema.StockOpname
  alias Voile.Schema.StockOpname.{LibrarianAssignment, Session}

  # ---------------------------------------------------------------------------
  # Shared setup
  # ---------------------------------------------------------------------------

  setup do
    allow_sandbox(self())

    node = node_fixture()
    rc = resource_class_fixture()
    admin = admin_user_fixture(%{"node_id" => node.id})
    collection = collection_fixture(node, rc, admin)

    %{admin: admin, node: node, rc: rc, collection: collection}
  end

  # Helper to create a librarian assignment for a session
  defp create_librarian_assignment(session, user, attrs) do
    attrs =
      Map.merge(
        %{
          session_id: session.id,
          user_id: user.id,
          work_status: "completed",
          items_checked: 5,
          completed_at: DateTime.utc_now() |> DateTime.truncate(:second)
        },
        attrs
      )

    %LibrarianAssignment{}
    |> LibrarianAssignment.changeset(attrs)
    |> Repo.insert!()
  end

  # ===========================================================================
  # reject_session/3
  # ===========================================================================

  describe "reject_session/3" do
    test "rejects a pending_review session with a reason", %{
      admin: admin,
      node: node,
      collection: collection
    } do
      item = catalog_item_fixture(collection, node, admin)
      session = pending_review_session_fixture(node, admin, [item])

      assert {:ok, rejected} =
               StockOpname.reject_session(session, admin, "Data quality issues found")

      assert rejected.status == "rejected"
      assert rejected.rejection_reason == "Data quality issues found"
      assert rejected.reviewed_by_id == admin.id
      assert rejected.reviewed_at != nil
    end

    test "returns error for non-pending_review session", %{
      admin: admin,
      node: node,
      collection: collection
    } do
      item = catalog_item_fixture(collection, node, admin)
      session = pending_review_session_fixture(node, admin, [item])

      # Change status to something else
      session
      |> Ecto.Changeset.change(%{status: "in_progress"})
      |> Repo.update!()

      updated_session = Repo.get!(Session, session.id)

      assert {:error, :invalid_status} =
               StockOpname.reject_session(updated_session, admin, "reason")
    end

    test "does not affect catalog items", %{
      admin: admin,
      node: node,
      collection: collection
    } do
      item = catalog_item_fixture(collection, node, admin, %{availability: "available"})
      session = pending_review_session_fixture(node, admin, [item])
      opname_item_fixture(session, item, %{check_status: "checked"})

      assert {:ok, _rejected} =
               StockOpname.reject_session(session, admin, "Not ready")

      reloaded = reload_catalog_items([item])
      assert reloaded[item.id].availability == "available"
    end
  end

  # ===========================================================================
  # request_session_revision/3
  # ===========================================================================

  describe "request_session_revision/3" do
    test "resets session to in_progress with review notes", %{
      admin: admin,
      node: node,
      collection: collection
    } do
      item = catalog_item_fixture(collection, node, admin)
      session = pending_review_session_fixture(node, admin, [item])

      assert {:ok, revised} =
               StockOpname.request_session_revision(session, admin, "Please re-check shelf B")

      assert revised.status == "in_progress"
      assert revised.review_notes == "Please re-check shelf B"
      assert revised.reviewed_by_id == admin.id
      assert revised.completed_at == nil
    end

    test "resets completed librarian assignments to in_progress", %{
      admin: admin,
      node: node,
      collection: collection
    } do
      item = catalog_item_fixture(collection, node, admin)
      session = pending_review_session_fixture(node, admin, [item])

      librarian1 = admin_user_fixture(%{"node_id" => node.id})
      librarian2 = admin_user_fixture(%{"node_id" => node.id})

      assignment1 = create_librarian_assignment(session, librarian1, %{work_status: "completed"})
      assignment2 = create_librarian_assignment(session, librarian2, %{work_status: "completed"})

      assert {:ok, _revised} =
               StockOpname.request_session_revision(session, admin, "Re-scan needed")

      reloaded1 = Repo.get!(LibrarianAssignment, assignment1.id)
      reloaded2 = Repo.get!(LibrarianAssignment, assignment2.id)

      assert reloaded1.work_status == "in_progress"
      assert reloaded1.completed_at == nil
      assert reloaded2.work_status == "in_progress"
      assert reloaded2.completed_at == nil
    end

    test "does not reset non-completed assignments", %{
      admin: admin,
      node: node,
      collection: collection
    } do
      item = catalog_item_fixture(collection, node, admin)
      session = pending_review_session_fixture(node, admin, [item])

      librarian = admin_user_fixture(%{"node_id" => node.id})

      assignment =
        create_librarian_assignment(session, librarian, %{
          work_status: "in_progress",
          completed_at: nil
        })

      assert {:ok, _revised} =
               StockOpname.request_session_revision(session, admin, "Notes here")

      reloaded = Repo.get!(LibrarianAssignment, assignment.id)
      assert reloaded.work_status == "in_progress"
    end

    test "returns error for non-pending_review session", %{
      admin: admin,
      node: node,
      collection: collection
    } do
      item = catalog_item_fixture(collection, node, admin)
      session = pending_review_session_fixture(node, admin, [item])

      session
      |> Ecto.Changeset.change(%{status: "approved"})
      |> Repo.update!()

      updated_session = Repo.get!(Session, session.id)

      assert {:error, :invalid_status} =
               StockOpname.request_session_revision(updated_session, admin, "notes")
    end

    test "does not affect catalog items", %{
      admin: admin,
      node: node,
      collection: collection
    } do
      item = catalog_item_fixture(collection, node, admin, %{availability: "available"})
      session = pending_review_session_fixture(node, admin, [item])
      opname_item_fixture(session, item, %{check_status: "checked"})

      assert {:ok, _revised} =
               StockOpname.request_session_revision(session, admin, "Recheck")

      reloaded = reload_catalog_items([item])
      assert reloaded[item.id].availability == "available"
    end
  end

  # ===========================================================================
  # complete_session/2
  # ===========================================================================

  describe "complete_session/2" do
    test "flags pending items as missing and transitions to pending_review", %{
      admin: admin,
      node: node,
      collection: collection
    } do
      item1 = catalog_item_fixture(collection, node, admin)
      item2 = catalog_item_fixture(collection, node, admin)

      now = DateTime.utc_now() |> DateTime.truncate(:second)

      session =
        Repo.insert!(%Session{
          title: "Test Complete Session",
          session_code: "SO-COMPL-#{System.unique_integer([:positive])}",
          description: "Test",
          node_ids: [node.id],
          collection_types: ["Library"],
          scope_type: "all",
          status: "in_progress",
          started_at: now,
          total_items: 2,
          checked_items: 1,
          missing_items: 0,
          items_with_changes: 0,
          created_by_id: admin.id
        })

      # One checked, one pending
      opname_item_fixture(session, item1, %{check_status: "checked"})
      opname_item_fixture(session, item2, %{check_status: "pending"})

      assert {:ok, completed} = StockOpname.complete_session(session, admin)

      assert completed.status == "pending_review"
      assert completed.completed_at != nil
      assert completed.missing_items == 1
    end

    test "returns error for non-in_progress session", %{
      admin: admin,
      node: node,
      collection: collection
    } do
      item = catalog_item_fixture(collection, node, admin)
      session = pending_review_session_fixture(node, admin, [item])

      assert {:error, :invalid_status} = StockOpname.complete_session(session, admin)
    end
  end
end
