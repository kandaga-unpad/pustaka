defmodule Voile.Notifications.LoanReminderNotifierTest do
  use Voile.DataCase, async: true

  alias Voile.Notifications.LoanReminderNotifier
  alias Voile.Schema.Library.{Transaction, Circulation}
  alias Voile.AccountsFixtures
  alias Voile.CatalogFixtures

  setup do
    # Subscribe to test broadcasts
    Phoenix.PubSub.subscribe(Voile.PubSub, "member:test-member-id:loan_reminders")
    :ok
  end

  describe "broadcast_loan_reminder/2" do
    test "broadcasts loan reminder with correct structure" do
      member = AccountsFixtures.user_fixture()
      item = CatalogFixtures.item_fixture()

      transaction = %Transaction{
        id: Ecto.UUID.generate(),
        member_id: member.id,
        item_id: item.id,
        due_date: DateTime.add(DateTime.utc_now(), 3 * 24 * 60 * 60, :second),
        status: "active"
      }

      # Mock the preload
      transaction = %{
        transaction
        | member: member,
          item: %{item | collection: %{title: "Test Book"}}
      }

      # Subscribe to member's topic
      Phoenix.PubSub.subscribe(Voile.PubSub, "member:#{member.id}:loan_reminders")

      # Broadcast
      LoanReminderNotifier.broadcast_loan_reminder(transaction, 3)

      # Assert message received
      assert_receive {:loan_reminder, notification_data}
      assert notification_data.transaction_id == transaction.id
      assert notification_data.days_until_due == 3
      assert notification_data.is_overdue == false
    end
  end

  describe "broadcast_overdue_notification/2" do
    test "broadcasts overdue notification" do
      member = AccountsFixtures.user_fixture()
      item = CatalogFixtures.item_fixture()

      transaction = %Transaction{
        id: Ecto.UUID.generate(),
        member_id: member.id,
        item_id: item.id,
        due_date: DateTime.add(DateTime.utc_now(), -2 * 24 * 60 * 60, :second),
        status: "active"
      }

      transaction = %{
        transaction
        | member: member,
          item: %{item | collection: %{title: "Overdue Book"}}
      }

      Phoenix.PubSub.subscribe(Voile.PubSub, "member:#{member.id}:loan_reminders")

      LoanReminderNotifier.broadcast_overdue_notification(transaction, 2)

      assert_receive {:loan_overdue, notification_data}
      assert notification_data.days_overdue == 2
    end
  end

  describe "subscribe_to_member_notifications/1" do
    test "subscribes to member-specific topic" do
      member_id = Ecto.UUID.generate()

      assert :ok = LoanReminderNotifier.subscribe_to_member_notifications(member_id)

      # Test by broadcasting and receiving
      Phoenix.PubSub.broadcast(
        Voile.PubSub,
        "member:#{member_id}:loan_reminders",
        {:test_message, "hello"}
      )

      assert_receive {:test_message, "hello"}
    end
  end
end
