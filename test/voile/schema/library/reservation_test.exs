defmodule Voile.Schema.Library.ReservationTest do
  use Voile.DataCase

  alias Voile.Schema.Library.Reservation
  import Voile.LibraryFixtures
  import Voile.AccountsFixtures

  @valid_attrs %{
    reservation_date: DateTime.utc_now(),
    expiry_date: DateTime.add(DateTime.utc_now(), 7 * 24 * 60 * 60, :second),
    status: "pending",
    priority: 1
  }

  @invalid_attrs %{
    reservation_date: nil,
    status: nil,
    member_id: nil
  }

  describe "changeset/2" do
    test "changeset with valid attributes" do
      member = user_fixture()
      item = fine_fixture().item

      attrs =
        Map.merge(@valid_attrs, %{
          member_id: member.id,
          item_id: item.id
        })

      changeset = Reservation.changeset(%Reservation{}, attrs)
      assert changeset.valid?
    end

    test "changeset with invalid attributes" do
      changeset = Reservation.changeset(%Reservation{}, @invalid_attrs)
      refute changeset.valid?

      assert "can't be blank" in errors_on(changeset).reservation_date
      assert "can't be blank" in errors_on(changeset).status
      assert "can't be blank" in errors_on(changeset).member_id
    end

    test "changeset validates status inclusion" do
      attrs = Map.merge(@valid_attrs, %{status: "invalid_status"})
      changeset = Reservation.changeset(%Reservation{}, attrs)

      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).status
    end

    test "changeset accepts all valid statuses" do
      valid_statuses = ~w(pending available picked_up expired cancelled)

      Enum.each(valid_statuses, fn status ->
        member = user_fixture()
        item = fine_fixture().item

        attrs =
          Map.merge(@valid_attrs, %{
            status: status,
            member_id: member.id,
            item_id: item.id
          })

        changeset = Reservation.changeset(%Reservation{}, attrs)
        assert changeset.valid?, "#{status} should be valid"
      end)
    end

    test "changeset validates priority is greater than 0" do
      attrs = Map.merge(@valid_attrs, %{priority: 0})
      changeset = Reservation.changeset(%Reservation{}, attrs)

      refute changeset.valid?
      assert "must be greater than 0" in errors_on(changeset).priority
    end

    test "changeset allows collection-level reservations" do
      member = user_fixture()
      collection = fine_fixture().item.collection

      attrs =
        Map.merge(@valid_attrs, %{
          member_id: member.id,
          collection_id: collection.id,
          # No specific item
          item_id: nil
        })

      changeset = Reservation.changeset(%Reservation{}, attrs)
      assert changeset.valid?
    end

    test "changeset allows item-level reservations" do
      member = user_fixture()
      item = fine_fixture().item

      attrs =
        Map.merge(@valid_attrs, %{
          member_id: member.id,
          item_id: item.id,
          # No collection
          collection_id: nil
        })

      changeset = Reservation.changeset(%Reservation{}, attrs)
      assert changeset.valid?
    end
  end

  describe "expired?/1" do
    test "returns true for pending reservation past expiry date" do
      past_expiry = DateTime.add(DateTime.utc_now(), -1 * 24 * 60 * 60, :second)

      reservation = %Reservation{
        expiry_date: past_expiry,
        status: "pending"
      }

      assert Reservation.expired?(reservation) == true
    end

    test "returns true for available reservation past expiry date" do
      past_expiry = DateTime.add(DateTime.utc_now(), -1 * 24 * 60 * 60, :second)

      reservation = %Reservation{
        expiry_date: past_expiry,
        status: "available"
      }

      assert Reservation.expired?(reservation) == true
    end

    test "returns false for pending reservation not past expiry date" do
      future_expiry = DateTime.add(DateTime.utc_now(), 1 * 24 * 60 * 60, :second)

      reservation = %Reservation{
        expiry_date: future_expiry,
        status: "pending"
      }

      assert Reservation.expired?(reservation) == false
    end

    test "returns false for picked up reservation" do
      past_expiry = DateTime.add(DateTime.utc_now(), -1 * 24 * 60 * 60, :second)

      reservation = %Reservation{
        expiry_date: past_expiry,
        status: "picked_up"
      }

      assert Reservation.expired?(reservation) == false
    end

    test "returns false for cancelled reservation" do
      past_expiry = DateTime.add(DateTime.utc_now(), -1 * 24 * 60 * 60, :second)

      reservation = %Reservation{
        expiry_date: past_expiry,
        status: "cancelled"
      }

      assert Reservation.expired?(reservation) == false
    end
  end

  describe "struct" do
    test "has correct fields" do
      reservation = %Reservation{}

      assert Map.has_key?(reservation, :id)
      assert Map.has_key?(reservation, :reservation_date)
      assert Map.has_key?(reservation, :expiry_date)
      assert Map.has_key?(reservation, :notification_sent)
      assert Map.has_key?(reservation, :status)
      assert Map.has_key?(reservation, :priority)
      assert Map.has_key?(reservation, :notes)
      assert Map.has_key?(reservation, :pickup_date)
      assert Map.has_key?(reservation, :cancelled_date)
      assert Map.has_key?(reservation, :cancellation_reason)
      assert Map.has_key?(reservation, :item_id)
      assert Map.has_key?(reservation, :member_id)
      assert Map.has_key?(reservation, :collection_id)
      assert Map.has_key?(reservation, :processed_by_id)
    end

    test "has correct associations" do
      reservation = reservation_fixture()
      reservation = Repo.preload(reservation, [:item, :member, :collection])

      assert reservation.item != nil
      assert reservation.member != nil
      # Collection may be nil for item-level reservations
    end

    test "has correct default values" do
      reservation = %Reservation{}

      assert reservation.notification_sent == false
      assert reservation.priority == 1
    end
  end

  describe "database constraints" do
    test "enforces foreign key constraints" do
      invalid_attrs =
        Map.merge(@valid_attrs, %{
          member_id: Ecto.UUID.generate(),
          item_id: Ecto.UUID.generate()
        })

      changeset = Reservation.changeset(%Reservation{}, invalid_attrs)

      assert {:error, changeset} = Repo.insert(changeset)
      assert "does not exist" in errors_on(changeset).member_id
    end
  end

  describe "integration tests" do
    test "creates item-level reservation with all fields" do
      member = user_fixture()
      item = fine_fixture().item
      now = DateTime.utc_now()
      expiry = DateTime.add(now, 7 * 24 * 60 * 60, :second)

      attrs = %{
        reservation_date: now,
        expiry_date: expiry,
        status: "pending",
        priority: 2,
        notes: "Urgent reservation",
        notification_sent: false,
        member_id: member.id,
        item_id: item.id
      }

      changeset = Reservation.changeset(%Reservation{}, attrs)
      assert changeset.valid?

      assert {:ok, reservation} = Repo.insert(changeset)
      assert reservation.status == "pending"
      assert reservation.priority == 2
      assert reservation.notes == "Urgent reservation"
      assert reservation.notification_sent == false
    end

    test "creates collection-level reservation" do
      member = user_fixture()
      collection = fine_fixture().item.collection
      now = DateTime.utc_now()
      expiry = DateTime.add(now, 7 * 24 * 60 * 60, :second)

      attrs = %{
        reservation_date: now,
        expiry_date: expiry,
        status: "pending",
        priority: 1,
        member_id: member.id,
        collection_id: collection.id
      }

      changeset = Reservation.changeset(%Reservation{}, attrs)
      assert changeset.valid?

      assert {:ok, reservation} = Repo.insert(changeset)
      assert reservation.collection_id == collection.id
      assert reservation.item_id == nil
    end

    test "updates reservation status" do
      reservation = reservation_fixture(%{status: "pending"})
      librarian = user_fixture()

      update_attrs = %{
        status: "available",
        processed_by_id: librarian.id,
        notification_sent: true
      }

      changeset = Reservation.changeset(reservation, update_attrs)
      assert changeset.valid?

      assert {:ok, updated_reservation} = Repo.update(changeset)
      assert updated_reservation.status == "available"
      assert updated_reservation.processed_by_id == librarian.id
      assert updated_reservation.notification_sent == true
    end

    test "cancels reservation" do
      reservation = reservation_fixture(%{status: "pending"})
      cancel_time = DateTime.utc_now()

      update_attrs = %{
        status: "cancelled",
        cancelled_date: cancel_time,
        cancellation_reason: "User requested cancellation"
      }

      changeset = Reservation.changeset(reservation, update_attrs)
      assert changeset.valid?

      assert {:ok, cancelled_reservation} = Repo.update(changeset)
      assert cancelled_reservation.status == "cancelled"
      assert cancelled_reservation.cancelled_date == cancel_time
      assert cancelled_reservation.cancellation_reason == "User requested cancellation"
    end

    test "marks reservation as picked up" do
      reservation = reservation_fixture(%{status: "available"})
      pickup_time = DateTime.utc_now()

      update_attrs = %{
        status: "picked_up",
        pickup_date: pickup_time
      }

      changeset = Reservation.changeset(reservation, update_attrs)
      assert changeset.valid?

      assert {:ok, picked_up_reservation} = Repo.update(changeset)
      assert picked_up_reservation.status == "picked_up"
      assert picked_up_reservation.pickup_date == pickup_time
    end

    test "manages reservation priorities" do
      member = user_fixture()
      item = fine_fixture().item

      # High priority reservation
      high_priority_attrs =
        Map.merge(@valid_attrs, %{
          member_id: member.id,
          item_id: item.id,
          priority: 5
        })

      # Low priority reservation
      low_priority_attrs =
        Map.merge(@valid_attrs, %{
          member_id: member.id,
          item_id: item.id,
          priority: 1
        })

      {:ok, high_res} =
        Reservation.changeset(%Reservation{}, high_priority_attrs) |> Repo.insert()

      {:ok, low_res} = Reservation.changeset(%Reservation{}, low_priority_attrs) |> Repo.insert()

      assert high_res.priority == 5
      assert low_res.priority == 1
    end
  end
end
