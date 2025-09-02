defmodule Voile.Schema.Library.CirculationHistoryTest do
  use Voile.DataCase

  alias Voile.Schema.Library.CirculationHistory
  import Voile.LibraryFixtures
  import Voile.AccountsFixtures

  @valid_attrs %{
    event_type: "loan",
    event_date: DateTime.utc_now(),
    description: "Test circulation event"
  }

  @invalid_attrs %{event_type: nil, event_date: nil, member_id: nil}

  describe "changeset/2" do
    test "changeset with valid attributes" do
      member = user_fixture()
      fine = fine_fixture()
      librarian = user_fixture()

      attrs =
        Map.merge(@valid_attrs, %{
          member_id: member.id,
          item_id: fine.item_id,
          processed_by_id: librarian.id
        })

      changeset = CirculationHistory.changeset(%CirculationHistory{}, attrs)
      assert changeset.valid?
    end

    test "changeset with invalid attributes" do
      changeset = CirculationHistory.changeset(%CirculationHistory{}, @invalid_attrs)
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).event_type
      assert "can't be blank" in errors_on(changeset).event_date
      assert "can't be blank" in errors_on(changeset).member_id
    end

    test "changeset validates event_type inclusion" do
      attrs = Map.merge(@valid_attrs, %{event_type: "invalid_event"})
      changeset = CirculationHistory.changeset(%CirculationHistory{}, attrs)

      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).event_type
    end

    test "changeset accepts all valid event types" do
      valid_types =
        ~w(loan return renewal reserve cancel_reserve fine_paid fine_waived member_created member_updated item_status_change)

      Enum.each(valid_types, fn event_type ->
        member = user_fixture()
        fine = fine_fixture()
        librarian = user_fixture()

        attrs =
          Map.merge(@valid_attrs, %{
            event_type: event_type,
            member_id: member.id,
            item_id: fine.item_id,
            processed_by_id: librarian.id
          })

        changeset = CirculationHistory.changeset(%CirculationHistory{}, attrs)
        assert changeset.valid?, "#{event_type} should be valid"
      end)
    end

    test "changeset allows optional fields" do
      member = user_fixture()
      fine = fine_fixture()
      librarian = user_fixture()

      attrs =
        Map.merge(@valid_attrs, %{
          member_id: member.id,
          item_id: fine.item_id,
          processed_by_id: librarian.id,
          old_value: %{"status" => "active"},
          new_value: %{"status" => "returned"},
          ip_address: "127.0.0.1",
          user_agent: "Test Browser"
        })

      changeset = CirculationHistory.changeset(%CirculationHistory{}, attrs)
      assert changeset.valid?
    end
  end

  describe "struct" do
    test "has correct fields" do
      circulation_history = %CirculationHistory{}

      assert Map.has_key?(circulation_history, :id)
      assert Map.has_key?(circulation_history, :event_type)
      assert Map.has_key?(circulation_history, :event_date)
      assert Map.has_key?(circulation_history, :description)
      assert Map.has_key?(circulation_history, :old_value)
      assert Map.has_key?(circulation_history, :new_value)
      assert Map.has_key?(circulation_history, :ip_address)
      assert Map.has_key?(circulation_history, :user_agent)
      assert Map.has_key?(circulation_history, :member_id)
      assert Map.has_key?(circulation_history, :item_id)
      assert Map.has_key?(circulation_history, :transaction_id)
      assert Map.has_key?(circulation_history, :reservation_id)
      assert Map.has_key?(circulation_history, :fine_id)
      assert Map.has_key?(circulation_history, :processed_by_id)
    end

    test "has correct associations" do
      circulation_history = circulation_history_fixture()
      circulation_history = Repo.preload(circulation_history, [:member, :item, :processed_by])

      assert circulation_history.member != nil
      assert circulation_history.item != nil
      assert circulation_history.processed_by != nil
    end
  end

  describe "database constraints" do
    test "enforces foreign key constraints" do
      invalid_attrs =
        Map.merge(@valid_attrs, %{
          member_id: Ecto.UUID.generate(),
          item_id: Ecto.UUID.generate(),
          processed_by_id: Ecto.UUID.generate()
        })

      changeset = CirculationHistory.changeset(%CirculationHistory{}, invalid_attrs)

      assert {:error, changeset} = Repo.insert(changeset)
      assert "does not exist" in errors_on(changeset).member_id
    end
  end
end
