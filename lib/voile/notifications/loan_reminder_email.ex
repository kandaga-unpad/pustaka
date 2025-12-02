defmodule Voile.Notifications.LoanReminderEmail do
  @moduledoc """
  Email templates for loan due date reminders.
  Generates and sends reminder emails to members about upcoming due dates.
  """

  import Swoosh.Email

  alias Voile.Mailer
  alias Voile.Schema.Accounts.User
  alias VoileWeb.EmailComponent.Template

  @doc """
  Sends a loan reminder email to a member.

  ## Parameters
  - member: The member receiving the reminder
  - transactions: List of transactions that are due soon
  - days_before_due: Number of days before due date (e.g., 3 or 1)
  """
  def send_reminder_email(%User{} = member, transactions, days_before_due)
      when is_list(transactions) and length(transactions) > 0 do
    email =
      new()
      |> to({member.fullname || member.email, member.email})
      |> from({"Kandaga Universitas Padjadjaran", "perpustakaan@unpad.ac.id"})
      |> subject(reminder_subject(days_before_due, length(transactions)))
      |> html_body(Template.loan_reminder_html(member, transactions, days_before_due))
      |> text_body(Template.loan_reminder_text(member, transactions, days_before_due))

    Mailer.deliver(email)
  end

  def send_reminder_email(_, [], _), do: {:ok, :no_transactions}
  def send_reminder_email(nil, _, _), do: {:error, :no_member}

  @doc """
  Sends an overdue notification email to a member.
  """
  def send_overdue_email(%User{} = member, transactions)
      when is_list(transactions) and length(transactions) > 0 do
    email =
      new()
      |> to({member.fullname || member.email, member.email})
      |> from({"Kandaga Universitas Padjadjaran", "perpustakaan@unpad.ac.id"})
      |> subject("Overdue Items - Immediate Action Required")
      |> html_body(Template.overdue_reminder_html(member, transactions))
      |> text_body(Template.overdue_reminder_text(member, transactions))

    Mailer.deliver(email)
  end

  def send_overdue_email(_, []), do: {:ok, :no_transactions}
  def send_overdue_email(nil, _), do: {:error, :no_member}

  @doc """
  Sends a manual reminder email to a member.
  Used by librarians to manually send reminders.
  """
  def send_manual_reminder(%User{} = member, transactions)
      when is_list(transactions) and length(transactions) > 0 do
    # Calculate earliest due date (most urgent item)
    earliest_days_until_due =
      transactions
      |> Enum.map(fn t ->
        DateTime.diff(t.due_date, DateTime.utc_now(), :day)
      end)
      |> Enum.min()
      |> max(0)

    email =
      new()
      |> to({member.fullname || member.email, member.email})
      |> from({"Kandaga Universitas Padjadjaran", "perpustakaan@unpad.ac.id"})
      |> subject("Pengingat Manual: Peminjaman Perpustakaan / Manual Reminder: Library Loans")
      |> html_body(Template.manual_reminder_html(member, transactions, earliest_days_until_due))
      |> text_body(Template.manual_reminder_text(member, transactions, earliest_days_until_due))

    Mailer.deliver(email)
  end

  def send_manual_reminder(_, []), do: {:ok, :no_transactions}
  def send_manual_reminder(nil, _), do: {:error, :no_member}

  # Private helper functions

  defp reminder_subject(days, count) when count == 1 do
    "Library Reminder: 1 Item Due in #{days} #{pluralize_day(days)}"
  end

  defp reminder_subject(days, count) do
    "Library Reminder: #{count} Items Due in #{days} #{pluralize_day(days)}"
  end

  defp pluralize_day(1), do: "Day"
  defp pluralize_day(_), do: "Days"
end
