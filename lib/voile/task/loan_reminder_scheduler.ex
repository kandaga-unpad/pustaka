defmodule Voile.Task.LoanReminderScheduler do
  @moduledoc """
  Scheduled task that checks for loans due soon and sends reminders.

  This task:
  - Runs daily (or at configured interval)
  - Checks for loans due in 3 days and 1 day
  - Sends email notifications to all affected members
  - Broadcasts PubSub notifications for logged-in members

  Configuration:
  - Set reminder days in config: config :voile, :loan_reminder_days, [3, 1]
  - Set scheduler interval: config :voile, :loan_reminder_interval, :daily
  """

  use GenServer
  require Logger

  alias Voile.Schema.Library.Circulation
  alias Voile.Notifications.{LoanReminderEmail, LoanReminderNotifier, EmailQueue}
  alias Voile.Repo

  @default_reminder_days [3, 1]
  # Run every day at 8 AM (in milliseconds)
  @default_interval 24 * 60 * 60 * 1000
  # Run 5 minutes after start (for first run)
  @initial_delay 5 * 60 * 1000

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    # Schedule the first check after a short delay
    schedule_next_check(@initial_delay)
    {:ok, %{last_run: nil}}
  end

  @impl true
  def handle_info(:check_reminders, state) do
    Logger.info("Running loan reminder check...")

    try do
      send_loan_reminders()
      schedule_next_check()
      {:noreply, %{state | last_run: DateTime.utc_now()}}
    rescue
      error ->
        Logger.error("Error in loan reminder scheduler: #{inspect(error)}")
        # Still schedule next check even if current one fails
        schedule_next_check()
        {:noreply, state}
    end
  end

  @doc """
  Manually trigger a reminder check (useful for testing).
  """
  def trigger_check do
    send(__MODULE__, :check_reminders)
  end

  @doc """
  Main function to check and send loan reminders.
  """
  def send_loan_reminders do
    reminder_days = get_reminder_days()

    Enum.each(reminder_days, fn days ->
      Logger.info("Checking for loans due in #{days} days...")
      process_reminders_for_days(days)
    end)

    # Also check for overdue items
    Logger.info("Checking for overdue items...")
    process_overdue_reminders()
  end

  # Private Functions

  defp process_reminders_for_days(days_before_due) do
    # Calculate the target due date range
    now = DateTime.utc_now()
    target_date = DateTime.add(now, days_before_due * 24 * 60 * 60, :second)

    # Find transactions due on the target date (with some buffer for time zones)
    transactions = get_transactions_due_on_date(target_date)

    Logger.info("Found #{length(transactions)} transactions due in #{days_before_due} days")

    # Group transactions by member
    transactions_by_member = Enum.group_by(transactions, & &1.member_id)

    # Send reminders to each member
    Enum.each(transactions_by_member, fn {member_id, member_transactions} ->
      send_member_reminder(member_id, member_transactions, days_before_due)
    end)
  end

  defp process_overdue_reminders do
    transactions = Circulation.list_overdue_transactions()

    Logger.info("Found #{length(transactions)} overdue transactions")

    # Group by member
    transactions_by_member = Enum.group_by(transactions, & &1.member_id)

    # Send overdue notifications
    Enum.each(transactions_by_member, fn {member_id, member_transactions} ->
      send_overdue_notification(member_id, member_transactions)
    end)
  end

  defp get_transactions_due_on_date(target_date) do
    import Ecto.Query

    # Get the start and end of the target day
    start_of_day = DateTime.truncate(target_date, :second)
    end_of_day = DateTime.add(start_of_day, 24 * 60 * 60 - 1, :second)

    from(t in Voile.Schema.Library.Transaction,
      where: t.status == "active",
      where: t.due_date >= ^start_of_day and t.due_date <= ^end_of_day,
      preload: [:member, :item, item: [:collection]]
    )
    |> Repo.all()
  end

  defp send_member_reminder(member_id, transactions, days_before_due) do
    case Voile.Schema.Accounts.get_user(member_id) do
      nil ->
        Logger.warning("Member not found: #{member_id}")

      member ->
        # Queue email instead of sending immediately
        EmailQueue.enqueue(
          fn -> LoanReminderEmail.send_reminder_email(member, transactions, days_before_due) end,
          metadata: %{
            member_id: member_id,
            type: :reminder,
            days_before_due: days_before_due,
            transaction_count: length(transactions)
          }
        )

        Logger.info(
          "Reminder email queued for member #{member_id} for #{length(transactions)} items"
        )

        # Broadcast PubSub notifications immediately (no delay needed)
        Enum.each(transactions, fn transaction ->
          LoanReminderNotifier.broadcast_loan_reminder(transaction, days_before_due)
        end)
    end
  end

  defp send_overdue_notification(member_id, transactions) do
    case Voile.Schema.Accounts.get_user(member_id) do
      nil ->
        Logger.warning("Member not found: #{member_id}")

      member ->
        # Queue overdue email instead of sending immediately
        EmailQueue.enqueue(
          fn -> LoanReminderEmail.send_overdue_email(member, transactions) end,
          # Overdue emails are high priority
          priority: :high,
          metadata: %{
            member_id: member_id,
            type: :overdue,
            transaction_count: length(transactions)
          }
        )

        Logger.info(
          "Overdue email queued for member #{member_id} for #{length(transactions)} items"
        )

        # Broadcast PubSub notifications immediately
        Enum.each(transactions, fn transaction ->
          days_overdue = Voile.Schema.Library.Transaction.days_overdue(transaction)
          LoanReminderNotifier.broadcast_overdue_notification(transaction, days_overdue)
        end)
    end
  end

  defp schedule_next_check(delay \\ nil) do
    interval = delay || get_check_interval()
    Process.send_after(self(), :check_reminders, interval)
  end

  defp get_reminder_days do
    Application.get_env(:voile, :loan_reminder_days, @default_reminder_days)
  end

  defp get_check_interval do
    Application.get_env(:voile, :loan_reminder_interval, @default_interval)
  end
end
