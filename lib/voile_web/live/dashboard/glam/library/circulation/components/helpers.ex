defmodule VoileWeb.Dashboard.Glam.Library.Circulation.Helpers do
  @moduledoc """
  Helper functions for the circulation dashboard components.
  """
  import VoileWeb.Utils.FormatIndonesiaTime,
    only: [safe_format_utc_to_jakarta: 1, shift_to_jakarta: 1]

  @doc """
  Returns CSS classes for transaction type badges.
  """
  def transaction_type_badge_class("loan"), do: "bg-voile-info text-voile-neutral"
  def transaction_type_badge_class("return"), do: "bg-voile-success text-voile-neutral"
  def transaction_type_badge_class("renewal"), do: "bg-voile-warning text-voile-neutral"
  def transaction_type_badge_class("lost_item"), do: "bg-voile-error text-voile-neutral"
  def transaction_type_badge_class("damaged_item"), do: "bg-voile-warning text-voile-neutral"
  def transaction_type_badge_class("cancel"), do: "bg-voile-neutral text-voile-dark"
  def transaction_type_badge_class(_), do: "bg-voile-neutral text-voile-dark"

  @doc """
  Returns CSS classes for status badges.
  """
  def status_badge_class("active"), do: "bg-voile-info text-voile-neutral"
  def status_badge_class("returned"), do: "bg-voile-success text-voile-neutral"
  def status_badge_class("overdue"), do: "bg-voile-error text-voile-neutral"
  def status_badge_class("lost"), do: "bg-voile-error text-voile-neutral"
  def status_badge_class("damaged"), do: "bg-voile-warning text-voile-neutral"
  def status_badge_class("canceled"), do: "bg-voile-neutral text-voile-dark"
  def status_badge_class(_), do: "bg-voile-neutral"

  @doc """
  Returns CSS classes for reservation status badges.
  """
  def reservation_status_badge_class("pending"), do: "bg-voile-warning text-gray-700"
  def reservation_status_badge_class("available"), do: "bg-voile-success"
  def reservation_status_badge_class("picked_up"), do: "bg-voile-info"
  def reservation_status_badge_class("expired"), do: "bg-voile-neutral"
  def reservation_status_badge_class("cancelled"), do: "bg-voile-error"
  def reservation_status_badge_class(_), do: "bg-voile-neutral"

  @doc """
  Returns CSS classes for requisition type badges.
  """
  def requisition_type_badge_class("purchase_request"),
    do: "bg-blue-100 text-blue-800 dark:bg-blue-900/40 dark:text-blue-300"

  def requisition_type_badge_class("interlibrary_loan"),
    do: "bg-green-100 text-green-800 dark:bg-green-900/40 dark:text-green-300"

  def requisition_type_badge_class("digitization_request"),
    do: "bg-purple-100 text-purple-800 dark:bg-purple-900/40 dark:text-purple-300"

  def requisition_type_badge_class("reference_question"),
    do: "bg-amber-100 text-amber-800 dark:bg-amber-900/40 dark:text-amber-300"

  def requisition_type_badge_class(_),
    do: "bg-gray-100 text-gray-700 dark:bg-gray-700 dark:text-gray-300"

  @doc """
  Returns CSS classes for requisition status badges.
  """
  def requisition_status_badge_class("submitted"),
    do: "bg-blue-100 text-blue-800 dark:bg-blue-900/40 dark:text-blue-300"

  def requisition_status_badge_class("reviewing"),
    do: "bg-yellow-100 text-yellow-800 dark:bg-yellow-900/40 dark:text-yellow-300"

  def requisition_status_badge_class("approved"),
    do: "bg-green-100 text-green-800 dark:bg-green-900/40 dark:text-green-300"

  def requisition_status_badge_class("rejected"),
    do: "bg-red-100 text-red-800 dark:bg-red-900/40 dark:text-red-300"

  def requisition_status_badge_class("fulfilled"),
    do: "bg-purple-100 text-purple-800 dark:bg-purple-900/40 dark:text-purple-300"

  def requisition_status_badge_class("cancelled"),
    do: "bg-gray-100 text-gray-700 dark:bg-gray-700 dark:text-gray-300"

  def requisition_status_badge_class(_),
    do: "bg-gray-100 text-gray-700 dark:bg-gray-700 dark:text-gray-300"

  @doc """
  Returns CSS classes for fine type badges.
  """
  def fine_type_badge_class("overdue"), do: "bg-voile-error text-voile-light"
  def fine_type_badge_class("lost_item"), do: "bg-voile-error text-voile-light"
  def fine_type_badge_class("damaged_item"), do: "bg-voile-warning text-voile-dark"
  def fine_type_badge_class("processing"), do: "bg-voile-info text-voile-primary"
  def fine_type_badge_class(_), do: "bg-voile-neutral text-voile-dark"

  @doc """
  Returns CSS classes for fine status badges.
  """
  def fine_status_badge_class("pending"), do: "bg-voile-error text-voile-light"
  def fine_status_badge_class("partial_paid"), do: "bg-voile-warning text-voile-dark"
  def fine_status_badge_class("paid"), do: "bg-voile-success text-voile-light"
  def fine_status_badge_class("waived"), do: "bg-voile-info text-voile-primary"
  def fine_status_badge_class(_), do: "bg-voile-neutral text-voile-dark"

  @doc """
  Returns CSS classes for priority text.
  """
  def priority_text_class("urgent"), do: "text-voile-error"
  def priority_text_class("high"), do: "text-voile-warning"
  def priority_text_class("normal"), do: "text-voile-dark"
  def priority_text_class("low"), do: "text-voile-dark"
  def priority_text_class(_), do: "text-voile-dark"

  @doc """
  Returns color classes for event types in history.
  """
  def event_type_color("loan"), do: "bg-voile-info"
  def event_type_color("return"), do: "bg-voile-success"
  def event_type_color("renewal"), do: "bg-voile-warning"
  def event_type_color("reserve"), do: "bg-voile-accent"
  def event_type_color("cancel_reserve"), do: "bg-voile-neutral"
  def event_type_color("fine_paid"), do: "bg-voile-success"
  def event_type_color("fine_waived"), do: "bg-voile-info"
  def event_type_color("member_created"), do: "bg-voile-primary"
  def event_type_color("member_updated"), do: "bg-voile-secondary"
  def event_type_color("item_status_change"), do: "bg-voile-warning"
  def event_type_color(_), do: "bg-voile-neutral"

  @doc """
  Returns badge classes for event types in history detail.
  """
  def event_type_badge_class("loan"), do: "bg-voile-info text-voile-primary"
  def event_type_badge_class("return"), do: "bg-voile-success text-voile-success"
  def event_type_badge_class("renewal"), do: "bg-voile-warning text-voile-warning"
  def event_type_badge_class("reserve"), do: "bg-voile-accent text-voile-primary"
  def event_type_badge_class("cancel_reserve"), do: "bg-voile-neutral text-voile-dark"
  def event_type_badge_class("fine_paid"), do: "bg-voile-success text-voile-success"
  def event_type_badge_class("fine_waived"), do: "bg-voile-info text-voile-primary"
  def event_type_badge_class("member_created"), do: "bg-voile-primary text-voile-surface"
  def event_type_badge_class("member_updated"), do: "bg-voile-secondary text-voile-surface"
  def event_type_badge_class("item_status_change"), do: "bg-voile-warning text-voile-warning"
  def event_type_badge_class(_), do: "bg-voile-neutral text-voile-dark"

  @doc """
  Formats a DateTime to a user-friendly string.
  """
  def format_datetime(nil), do: "-"

  def format_datetime(datetime) do
    case safe_format_utc_to_jakarta(datetime) do
      {:ok, formatted} -> formatted
      {:error, _} -> Calendar.strftime(datetime, "%d/%m/%Y %H:%M")
    end
  end

  @doc """
  Formats a Date to a user-friendly string.
  """
  def format_date(nil), do: "-"

  def format_date(%Date{} = date) do
    date
    |> Calendar.strftime("%m/%d/%Y")
  end

  def format_date(%DateTime{} = datetime) do
    datetime
    |> shift_to_jakarta()
    |> DateTime.to_date()
    |> format_date()
  end

  @doc """
  Calculates days between two dates.
  """
  def days_between(nil, _), do: 0
  def days_between(_, nil), do: 0

  def days_between(date1, date2) do
    Date.diff(date1, date2)
  end

  @doc """
  Checks if a date is overdue compared to today.
  """
  def overdue?(nil), do: false

  def overdue?(due_date) do
    Date.compare(Date.utc_today(), due_date) == :gt
  end

  @doc """
  Returns a user-friendly status description.
  """
  def status_description("active"), do: "Currently checked out"
  def status_description("returned"), do: "Successfully returned"
  def status_description("overdue"), do: "Past due date"
  def status_description("lost"), do: "Reported as lost"
  def status_description("damaged"), do: "Reported as damaged"
  def status_description("canceled"), do: "Transaction cancelled"
  def status_description("pending"), do: "Waiting for processing"
  def status_description("available"), do: "Ready for pickup"
  def status_description("picked_up"), do: "Item has been picked up"
  def status_description("expired"), do: "Reservation has expired"
  def status_description("cancelled"), do: "Reservation cancelled"
  def status_description("submitted"), do: "Request submitted"
  def status_description("reviewing"), do: "Under review"
  def status_description("approved"), do: "Request approved"
  def status_description("rejected"), do: "Request rejected"
  def status_description("fulfilled"), do: "Request fulfilled"
  def status_description("paid"), do: "Fine fully paid"
  def status_description("partial_paid"), do: "Partially paid"
  def status_description("waived"), do: "Fine waived"
  def status_description(status), do: String.capitalize(status)

  @doc """
  Formats a Decimal amount as Indonesian Rupiah currency.
  """
  def format_idr(nil), do: "Rp 0"

  def format_idr(amount) when is_struct(amount, Decimal) do
    amount
    |> Decimal.to_float()
    |> format_idr()
  end

  def format_idr(amount) when is_float(amount) or is_integer(amount) do
    amount
    |> trunc()
    |> to_string()
    |> String.replace(~r/(\d)(?=(\d{3})+(?!\d))/, "\\1,")
    |> (&("Rp " <> &1)).()
  end

  # Transaction-specific helpers (migrated from Transaction.Helpers)
  alias Voile.Schema.Accounts
  alias Voile.Schema.Library.Transaction

  @doc """
  Calculate predicted fine for a transaction.
  """
  def predicted_fine_for(transaction) do
    member = Accounts.get_user!(transaction.member_id)

    if Transaction.overdue?(transaction) do
      days = Transaction.days_overdue(transaction)
      daily = member.user_type.fine_per_day || Decimal.new("1.00")
      Decimal.mult(Decimal.new(days), daily)
    else
      Decimal.new("0")
    end
  end

  def recommended_renew_days_for(transaction) do
    member = Accounts.get_user!(transaction.member_id)

    case member.user_type do
      %{} = ut -> ut.max_days || nil
      _ -> nil
    end
  end

  def preview_due_date_for(transaction, days)
      when is_integer(days) and not is_nil(transaction.due_date) do
    DateTime.add(transaction.due_date, days * 24 * 60 * 60, :second)
  end

  def preview_due_date_for(_transaction, _), do: nil

  def remaining_renewals_for(transaction) do
    member = Accounts.get_user!(transaction.member_id)

    case member.user_type do
      %{} = ut ->
        max = ut.max_renewals || 0
        max - (transaction.renewal_count || 0)

      _ ->
        0
    end
  end

  def get_id_from_member_identifier(identifier) do
    case Accounts.get_user_by_identifier(identifier) do
      nil -> nil
      user -> user.id
    end
  end
end
