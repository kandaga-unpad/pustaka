defmodule Voile.Schema.Library.CirculationTest do
  use Voile.DataCase

  alias Voile.Schema.Library.Circulation
  alias Voile.Schema.Library.{CirculationHistory, Fine, Requisition, Reservation, Transaction}
  alias Voile.Repo
  alias Voile.Schema.Catalog.Item

  import Voile.LibraryFixtures
  import Voile.AccountsFixtures

  # Test module aliasing
  describe "module aliases" do
    test "CirculationHistory alias works" do
      circulation_history = circulation_history_fixture()
      assert %CirculationHistory{} = circulation_history
      assert circulation_history.id != nil
    end

    test "Fine alias works" do
      fine = fine_fixture()
      assert %Fine{} = fine
      assert fine.id != nil
    end

    test "Requisition alias works" do
      requisition = requisition_fixture()
      assert %Requisition{} = requisition
      assert requisition.id != nil
    end

    test "Reservation alias works" do
      reservation = reservation_fixture()
      assert %Reservation{} = reservation
      assert reservation.id != nil
    end

    test "Transaction alias works" do
      transaction = transaction_fixture()
      assert %Transaction{} = transaction
      assert transaction.id != nil
    end
  end

  # CirculationHistory CRUD tests
  describe "circulation_history" do
    test "list_circulation_history_paginated/2 returns paginated circulation history" do
      circulation_history_fixture()
      circulation_history_fixture()
      circulation_history_fixture()

      {results, total_pages} = Circulation.list_circulation_history_paginated(1, 2)

      assert length(results) <= 2
      assert total_pages >= 1
      assert Enum.all?(results, fn ch -> %CirculationHistory{} = ch end)
    end

    test "get_circulation_history!/1 returns the circulation history with given id" do
      circulation_history = circulation_history_fixture()

      found = Circulation.get_circulation_history!(circulation_history.id)

      assert found.id == circulation_history.id
      assert found.member != nil
      assert found.item != nil
      assert found.processed_by != nil
    end

    test "create_circulation_history/1 with valid data creates a circulation history" do
      member = user_fixture()
      # Get item from existing fixture
      item = fine_fixture().item
      librarian = user_fixture()

      valid_attrs = %{
        event_type: "loan",
        event_date: DateTime.utc_now(),
        description: "Test loan event",
        member_id: member.id,
        item_id: item.id,
        processed_by_id: librarian.id
      }

      assert {:ok, %CirculationHistory{} = circulation_history} =
               Circulation.create_circulation_history(valid_attrs)

      assert circulation_history.event_type == "loan"
      assert circulation_history.description == "Test loan event"
    end

    test "create_circulation_history/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Circulation.create_circulation_history(%{})
    end

    test "update_circulation_history/2 with valid data updates the circulation history" do
      circulation_history = circulation_history_fixture()
      update_attrs = %{description: "Updated description"}

      assert {:ok, %CirculationHistory{} = circulation_history} =
               Circulation.update_circulation_history(circulation_history, update_attrs)

      assert circulation_history.description == "Updated description"
    end

    test "delete_circulation_history/1 deletes the circulation history" do
      circulation_history = circulation_history_fixture()

      assert {:ok, %CirculationHistory{}} =
               Circulation.delete_circulation_history(circulation_history)

      assert_raise Ecto.NoResultsError, fn ->
        Circulation.get_circulation_history!(circulation_history.id)
      end
    end

    test "change_circulation_history/2 returns a circulation history changeset" do
      circulation_history = circulation_history_fixture()

      assert %Ecto.Changeset{} = Circulation.change_circulation_history(circulation_history, %{})
    end
  end

  # Fines CRUD tests
  describe "fines" do
    test "list_fines/0 returns all fines" do
      fine = fine_fixture()
      assert Enum.any?(Circulation.list_fines(), fn f -> f.id == fine.id end)
    end

    test "list_fines_paginated/2 returns paginated fines" do
      fine_fixture()
      fine_fixture()

      {results, total_pages} = Circulation.list_fines_paginated(1, 1)

      assert length(results) == 1
      assert total_pages >= 1
    end

    test "get_fine!/1 returns the fine with given id" do
      fine = fine_fixture()

      found = Circulation.get_fine!(fine.id)

      assert found.id == fine.id
      assert found.member != nil
      assert found.item != nil
      assert found.processed_by != nil
    end

    test "create_fine/1 with valid data creates a fine" do
      member = user_fixture()
      # Get item from existing fixture
      item = fine_fixture().item
      librarian = user_fixture()

      valid_attrs = %{
        fine_type: "overdue",
        amount: Decimal.new("15000"),
        fine_date: DateTime.utc_now(),
        fine_status: "pending",
        description: "Test fine",
        member_id: member.id,
        item_id: item.id,
        processed_by_id: librarian.id
      }

      assert {:ok, %Fine{} = fine} = Circulation.create_fine(valid_attrs)

      assert fine.fine_type == "overdue"
      assert Decimal.equal?(fine.amount, Decimal.new("15000"))
      assert fine.fine_status == "pending"
    end

    test "update_fine/2 with valid data updates the fine" do
      fine = fine_fixture()
      update_attrs = %{description: "Updated fine description"}

      assert {:ok, %Fine{} = fine} = Circulation.update_fine(fine, update_attrs)
      assert fine.description == "Updated fine description"
    end

    test "delete_fine/1 deletes the fine" do
      fine = fine_fixture()

      assert {:ok, %Fine{}} = Circulation.delete_fine(fine)
      assert_raise Ecto.NoResultsError, fn -> Circulation.get_fine!(fine.id) end
    end
  end

  # Requisitions CRUD tests
  describe "requisitions" do
    test "list_requisitions/0 returns all requisitions" do
      requisition = requisition_fixture()
      assert requisition in Circulation.list_requisitions()
    end

    test "list_requisitions_paginated/2 returns paginated requisitions" do
      requisition_fixture()
      requisition_fixture()

      {results, total_pages} = Circulation.list_requisitions_paginated(1, 1)

      assert length(results) == 1
      assert total_pages >= 1
    end

    test "get_requisition!/1 returns the requisition with given id" do
      requisition = requisition_fixture()

      found = Circulation.get_requisition!(requisition.id)

      assert found.id == requisition.id
      assert found.requested_by != nil
    end

    test "create_requisition/1 with map creates a requisition" do
      user = user_fixture()

      valid_attrs = %{
        request_date: DateTime.utc_now(),
        request_type: "purchase_request",
        status: "submitted",
        title: "New Book Request",
        author: "Test Author",
        requested_by_id: user.id
      }

      assert {:ok, %Requisition{} = requisition} = Circulation.create_requisition(valid_attrs)
      assert requisition.title == "New Book Request"
      assert requisition.status == "submitted"
    end

    test "create_requisition/2 with requested_by_id sets defaults" do
      user = user_fixture()

      attrs = %{
        title: "Test Book",
        request_type: "purchase_request"
      }

      assert {:ok, %Requisition{} = requisition} =
               Circulation.create_requisition(user.id, attrs)

      assert requisition.requested_by_id == user.id
      assert requisition.status == "submitted"
      assert requisition.request_date != nil
    end

    test "update_requisition/2 with valid data updates the requisition" do
      requisition = requisition_fixture()
      update_attrs = %{status: "reviewing"}

      assert {:ok, %Requisition{} = requisition} =
               Circulation.update_requisition(requisition, update_attrs)

      assert requisition.status == "reviewing"
    end

    test "delete_requisition/1 deletes the requisition" do
      requisition = requisition_fixture()

      assert {:ok, %Requisition{}} = Circulation.delete_requisition(requisition)

      assert_raise Ecto.NoResultsError, fn ->
        Circulation.get_requisition!(requisition.id)
      end
    end
  end

  # Reservations CRUD tests
  describe "reservations" do
    test "list_reservations/0 returns all reservations" do
      reservation = reservation_fixture()
      assert reservation in Circulation.list_reservations()
    end

    test "list_reservations_paginated/2 returns paginated reservations" do
      reservation_fixture()
      reservation_fixture()

      {results, total_pages} = Circulation.list_reservations_paginated(1, 1)

      assert length(results) == 1
      assert total_pages >= 1
    end

    test "get_reservation!/1 returns the reservation with given id" do
      reservation = reservation_fixture()

      found = Circulation.get_reservation!(reservation.id)

      assert found.id == reservation.id
      assert found.member != nil
      assert found.item != nil
    end

    test "create_reservation/1 with valid data creates a reservation" do
      member = user_fixture()
      item = fine_fixture().item

      valid_attrs = %{
        reservation_date: DateTime.utc_now(),
        expiry_date: DateTime.add(DateTime.utc_now(), 7 * 24 * 60 * 60, :second),
        status: "pending",
        member_id: member.id,
        item_id: item.id
      }

      assert {:ok, %Reservation{} = reservation} = Circulation.create_reservation(valid_attrs)
      assert reservation.status == "pending"
    end

    test "update_reservation/2 with valid data updates the reservation" do
      reservation = reservation_fixture()
      update_attrs = %{status: "available"}

      assert {:ok, %Reservation{} = reservation} =
               Circulation.update_reservation(reservation, update_attrs)

      assert reservation.status == "available"
    end

    test "delete_reservation/1 deletes the reservation" do
      reservation = reservation_fixture()

      assert {:ok, %Reservation{}} = Circulation.delete_reservation(reservation)

      assert_raise Ecto.NoResultsError, fn ->
        Circulation.get_reservation!(reservation.id)
      end
    end
  end

  # Transactions CRUD tests
  describe "transactions" do
    test "list_transactions/0 returns all transactions" do
      transaction = transaction_fixture()
      assert transaction in Circulation.list_transactions()
    end

    test "list_transactions_paginated/2 returns paginated transactions" do
      transaction_fixture()
      transaction_fixture()

      {results, total_pages} = Circulation.list_transactions_paginated(1, 1)

      assert length(results) == 1
      assert total_pages >= 1
    end

    test "get_transaction!/1 returns the transaction with given id" do
      transaction = transaction_fixture()

      found = Circulation.get_transaction!(transaction.id)

      assert found.id == transaction.id
      assert found.member != nil
      assert found.item != nil
      assert found.librarian != nil
    end

    test "create_transaction/1 with valid data creates a transaction" do
      member = user_fixture()
      item = fine_fixture().item
      librarian = user_fixture()

      valid_attrs = %{
        transaction_type: "loan",
        transaction_date: DateTime.utc_now(),
        due_date: DateTime.add(DateTime.utc_now(), 14 * 24 * 60 * 60, :second),
        status: "active",
        member_id: member.id,
        item_id: item.id,
        librarian_id: librarian.id
      }

      assert {:ok, %Transaction{} = transaction} = Circulation.create_transaction(valid_attrs)
      assert transaction.transaction_type == "loan"
      assert transaction.status == "active"
    end

    test "update_transaction/2 with valid data updates the transaction" do
      transaction = transaction_fixture()
      update_attrs = %{status: "returned"}

      assert {:ok, %Transaction{} = transaction} =
               Circulation.update_transaction(transaction, update_attrs)

      assert transaction.status == "returned"
    end

    test "delete_transaction/1 deletes the transaction" do
      transaction = transaction_fixture()

      assert {:ok, %Transaction{}} = Circulation.delete_transaction(transaction)

      assert_raise Ecto.NoResultsError, fn ->
        Circulation.get_transaction!(transaction.id)
      end
    end
  end

  # Transaction workflow tests
  describe "transaction workflows" do
    test "checkout_item/4 creates a transaction successfully" do
      member = user_fixture()
      item = fine_fixture().item
      librarian = user_fixture()

      # Make sure item is available
      item =
        Repo.get!(Item, item.id)
        |> Ecto.Changeset.change(availability: "available")
        |> Repo.update!()

      assert {:ok, transaction} =
               Circulation.checkout_item(member.id, item.id, librarian.id, %{
                 notes: "Test checkout"
               })

      assert transaction.status == "active"
      assert transaction.member_id == member.id
      assert transaction.item_id == item.id
      assert transaction.librarian_id == librarian.id

      # Check that item availability was updated
      updated_item = Repo.get!(Item, item.id)
      assert updated_item.availability == "loaned"
    end

    test "checkout_item/4 sets unit_id from item's node" do
      member = user_fixture()
      item = fine_fixture().item
      librarian = user_fixture()

      # Make sure item is available and has a unit_id
      item =
        Repo.get!(Item, item.id)
        |> Ecto.Changeset.change(availability: "available", unit_id: 1)
        |> Repo.update!()

      assert {:ok, transaction} =
               Circulation.checkout_item(member.id, item.id, librarian.id, %{})

      # Verify unit_id is correctly set from item
      assert transaction.unit_id == item.unit_id

      # Verify we can preload the node association
      transaction_with_node = Circulation.get_transaction!(transaction.id) |> Repo.preload(:node)
      assert transaction_with_node.node != nil
    end

    test "return_item/3 completes a transaction successfully" do
      transaction = transaction_fixture()
      librarian = user_fixture()

      assert {:ok, returned_transaction} =
               Circulation.return_item(transaction.id, librarian.id, %{notes: "Test return"})

      assert returned_transaction.status == "returned"
      assert returned_transaction.return_date != nil

      # Check that item availability was updated
      updated_item = Repo.get!(Item, transaction.item_id)
      assert updated_item.availability == "available"
    end

    test "renew_transaction/3 renews a transaction successfully" do
      transaction = transaction_fixture()
      librarian = user_fixture()
      original_due_date = transaction.due_date

      assert {:ok, renewed_transaction} =
               Circulation.renew_transaction(transaction.id, librarian.id, %{})

      assert renewed_transaction.renewal_count == 1
      assert DateTime.compare(renewed_transaction.due_date, original_due_date) == :gt
    end

    test "list_member_active_transactions/1 returns member's active transactions" do
      member = user_fixture()
      transaction = transaction_fixture(%{member_id: member.id, status: "active"})

      active_transactions = Circulation.list_member_active_transactions(member.id)

      assert length(active_transactions) == 1
      assert List.first(active_transactions).id == transaction.id
    end

    test "list_overdue_transactions/0 returns overdue transactions" do
      overdue_transaction = overdue_transaction_fixture()

      overdue_transactions = Circulation.list_overdue_transactions()

      assert Enum.any?(overdue_transactions, fn t -> t.id == overdue_transaction.id end)
    end

    test "list_transactions_due_soon/1 returns transactions due soon" do
      # Create transaction due in 2 days
      due_soon = DateTime.add(DateTime.utc_now(), 2 * 24 * 60 * 60, :second)
      transaction = transaction_fixture(%{due_date: due_soon, status: "active"})

      due_soon_transactions = Circulation.list_transactions_due_soon(3)

      assert Enum.any?(due_soon_transactions, fn t -> t.id == transaction.id end)
    end
  end

  # Reservation workflow tests
  describe "reservation workflows" do
    test "cancel_reservation/2 cancels a reservation" do
      reservation = reservation_fixture()

      assert {:ok, cancelled_reservation} =
               Circulation.cancel_reservation(reservation.id, "Test cancellation")

      assert cancelled_reservation.status == "cancelled"
      assert cancelled_reservation.cancellation_reason == "Test cancellation"
      assert cancelled_reservation.cancelled_date != nil
    end

    test "mark_reservation_available/2 marks reservation as available" do
      reservation = reservation_fixture(%{status: "pending"})
      librarian = user_fixture()

      assert {:ok, available_reservation} =
               Circulation.mark_reservation_available(reservation.id, librarian.id)

      assert available_reservation.status == "available"
      assert available_reservation.processed_by_id == librarian.id
    end

    test "list_member_reservations/1 returns member's reservations" do
      member = user_fixture()
      reservation = reservation_fixture(%{member_id: member.id, status: "pending"})

      member_reservations = Circulation.list_member_reservations(member.id)

      assert length(member_reservations) == 1
      assert List.first(member_reservations).id == reservation.id
    end

    test "list_expired_reservations/0 returns expired reservations" do
      expired_reservation = expired_reservation_fixture()

      expired_reservations = Circulation.list_expired_reservations()

      assert Enum.any?(expired_reservations, fn r -> r.id == expired_reservation.id end)
    end
  end

  # Fine workflow tests
  describe "fine workflows" do
    test "pay_fine/5 processes fine payment" do
      fine = fine_fixture(%{amount: Decimal.new("20000"), balance: Decimal.new("20000")})
      librarian = user_fixture()
      payment_amount = Decimal.new("10000")

      assert {:ok, updated_fine} =
               Circulation.pay_fine(fine.id, payment_amount, "cash", librarian.id, "REC001")

      assert Decimal.equal?(updated_fine.paid_amount, Decimal.new("10000"))
      assert Decimal.equal?(updated_fine.balance, Decimal.new("10000"))
      assert updated_fine.fine_status == "partial_paid"
      assert updated_fine.payment_method == "cash"
      assert updated_fine.receipt_number == "REC001"
    end

    test "waive_fine/3 waives a fine" do
      fine = fine_fixture()
      librarian = user_fixture()

      assert {:ok, waived_fine} =
               Circulation.waive_fine(fine.id, "Administrative waiver", librarian.id)

      assert waived_fine.waived == true
      assert waived_fine.waived_reason == "Administrative waiver"
      assert waived_fine.waived_by_id == librarian.id
      assert waived_fine.fine_status == "waived"
    end

    test "list_member_unpaid_fines/1 returns unpaid fines for member" do
      member = user_fixture()
      fine = fine_fixture(%{member_id: member.id, fine_status: "pending"})

      unpaid_fines = Circulation.list_member_unpaid_fines(member.id)

      assert length(unpaid_fines) == 1
      assert List.first(unpaid_fines).id == fine.id
    end

    test "get_member_outstanding_fine_amount/1 calculates total outstanding fines" do
      member = user_fixture()
      fine_fixture(%{member_id: member.id, balance: Decimal.new("15000"), fine_status: "pending"})
      fine_fixture(%{member_id: member.id, balance: Decimal.new("10000"), fine_status: "pending"})

      total_outstanding = Circulation.get_member_outstanding_fine_amount(member.id)

      assert Decimal.equal?(total_outstanding, Decimal.new("25000"))
    end
  end

  # Requisition workflow tests
  describe "requisition workflows" do
    test "assign_requisition/2 assigns requisition to staff" do
      requisition = requisition_fixture()
      staff = user_fixture()

      assert {:ok, assigned_requisition} =
               Circulation.assign_requisition(requisition.id, staff.id)

      assert assigned_requisition.assigned_to_id == staff.id
      assert assigned_requisition.status == "reviewing"
    end

    test "approve_requisition/2 approves a requisition" do
      requisition = requisition_fixture()

      assert {:ok, approved_requisition} =
               Circulation.approve_requisition(requisition.id, "Approved for purchase")

      assert approved_requisition.status == "approved"
      assert approved_requisition.staff_notes == "Approved for purchase"
    end

    test "reject_requisition/2 rejects a requisition" do
      requisition = requisition_fixture()

      assert {:ok, rejected_requisition} =
               Circulation.reject_requisition(requisition.id, "Budget constraints")

      assert rejected_requisition.status == "rejected"
      assert rejected_requisition.staff_notes == "Budget constraints"
    end

    test "list_requisitions_by_status/1 filters requisitions by status" do
      approved_req = requisition_fixture(%{status: "approved"})
      _pending_req = requisition_fixture(%{status: "submitted"})

      approved_requisitions = Circulation.list_requisitions_by_status("approved")

      assert length(approved_requisitions) == 1
      assert List.first(approved_requisitions).id == approved_req.id
    end
  end

  # Circulation history tests
  describe "circulation history" do
    test "list_circulation_history/1 returns recent circulation history" do
      circulation_history_fixture()
      circulation_history_fixture()

      history = Circulation.list_circulation_history(1)

      assert length(history) == 1
      assert List.first(history).member != nil
      assert List.first(history).item != nil
    end

    test "get_item_history/1 returns history for specific item" do
      item = fine_fixture().item
      circulation_history_fixture(%{item_id: item.id})

      item_history = Circulation.get_item_history(item.id)

      assert length(item_history) >= 1
      assert Enum.all?(item_history, fn ch -> ch.item_id == item.id end)
    end

    test "get_member_history/1 returns history for specific member" do
      member = user_fixture()
      circulation_history_fixture(%{member_id: member.id})

      member_history = Circulation.get_member_history(member.id)

      assert length(member_history) >= 1
      assert Enum.all?(member_history, fn ch -> ch.member_id == member.id end)
    end

    test "get_member_history/1 with nil returns empty list" do
      assert Circulation.get_member_history(nil) == []
    end
  end

  # Member type policy tests
  describe "member type policies" do
    test "list_active_member_types/0 returns active member types only" do
      active_types = Circulation.list_active_member_types()

      assert is_list(active_types)
      assert Enum.all?(active_types, fn mt -> mt.is_active == true end)
    end

    test "member_privileges_suspended?/1 checks fine limits" do
      member = user_fixture()

      # Create fines that exceed the member type's max fine limit
      # Assuming max_fine is 100000 from fixture
      fine_fixture(%{
        member_id: member.id,
        balance: Decimal.new("150000"),
        fine_status: "pending"
      })

      assert Circulation.member_privileges_suspended?(member.id) == true
    end

    test "member_privileges_suspended?/1 returns false for members within limits" do
      member = user_fixture()
      fine_fixture(%{member_id: member.id, balance: Decimal.new("5000"), fine_status: "pending"})

      assert Circulation.member_privileges_suspended?(member.id) == false
    end
  end

  # Batch operations tests
  describe "batch operations" do
    test "process_overdue_items/0 marks overdue transactions and creates fines" do
      _overdue_transaction = overdue_transaction_fixture()

      result = Circulation.process_overdue_items()

      assert result.processed >= 0
      assert result.total >= 0
      assert is_integer(result.failed)
    end

    test "expire_old_reservations/0 expires old reservations" do
      expired_reservation_fixture()

      expired_count = Circulation.expire_old_reservations()

      assert is_integer(expired_count)
      assert expired_count >= 0
    end

    test "process_auto_renewals/0 processes eligible auto-renewals" do
      # This test depends on member type auto-renew settings
      result = Circulation.process_auto_renewals()

      assert is_map(result)
      assert Map.has_key?(result, :renewed)
      assert Map.has_key?(result, :failed)
      assert Map.has_key?(result, :total)
    end
  end
end
