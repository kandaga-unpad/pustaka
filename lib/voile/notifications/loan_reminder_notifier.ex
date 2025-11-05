defmodule Voile.Notifications.LoanReminderNotifier do
  @moduledoc """
  Handles broadcasting and subscribing to loan due date reminder notifications.
  Members get notified via PubSub when they have loans due soon.

  This module handles real-time notifications for logged-in users.
  Email notifications are handled separately by LoanReminderEmail.
  """

  alias Phoenix.PubSub
  alias Voile.Schema.Library.Transaction

  @doc """
  Broadcasts a loan reminder notification to a specific member.
  This is used for real-time notifications when the member is logged in.

  ## Parameters
  - transaction: The transaction that's due soon
  - days_until_due: Number of days until the due date (can be negative for overdue)
  """
  def broadcast_loan_reminder(%Transaction{} = transaction, days_until_due) do
    transaction = Voile.Repo.preload(transaction, [:member, :item, item: [:collection]])

    notification_data = %{
      transaction_id: transaction.id,
      member_id: transaction.member_id,
      item_id: transaction.item_id,
      item_code: get_item_code(transaction),
      collection_title: get_collection_title(transaction),
      due_date: transaction.due_date,
      days_until_due: days_until_due,
      is_overdue: days_until_due < 0,
      timestamp: DateTime.utc_now()
    }

    # Broadcast to member-specific topic
    PubSub.broadcast(
      Voile.PubSub,
      member_topic(transaction.member_id),
      {:loan_reminder, notification_data}
    )
  end

  @doc """
  Broadcasts an overdue notification to a specific member.
  """
  def broadcast_overdue_notification(%Transaction{} = transaction, days_overdue) do
    transaction = Voile.Repo.preload(transaction, [:member, :item, item: [:collection]])

    notification_data = %{
      transaction_id: transaction.id,
      member_id: transaction.member_id,
      item_id: transaction.item_id,
      item_code: get_item_code(transaction),
      collection_title: get_collection_title(transaction),
      due_date: transaction.due_date,
      days_overdue: days_overdue,
      timestamp: DateTime.utc_now()
    }

    # Broadcast to member-specific topic
    PubSub.broadcast(
      Voile.PubSub,
      member_topic(transaction.member_id),
      {:loan_overdue, notification_data}
    )
  end

  @doc """
  Subscribe to loan reminder notifications for a specific member.
  Should be called when a member logs in or opens a LiveView.
  """
  def subscribe_to_member_notifications(member_id) do
    PubSub.subscribe(Voile.PubSub, member_topic(member_id))
  end

  @doc """
  Unsubscribe from loan reminder notifications for a specific member.
  """
  def unsubscribe_from_member_notifications(member_id) do
    PubSub.unsubscribe(Voile.PubSub, member_topic(member_id))
  end

  # Private helper functions

  defp member_topic(member_id), do: "member:#{member_id}:loan_reminders"

  defp get_item_code(%{item: %{item_code: code}}) when not is_nil(code), do: code
  defp get_item_code(_), do: "Unknown Item"

  defp get_collection_title(%{item: %{collection: %{title: title}}}) when not is_nil(title),
    do: title

  defp get_collection_title(_), do: "Unknown Collection"
end
