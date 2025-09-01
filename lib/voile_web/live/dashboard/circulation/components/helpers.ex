defmodule VoileWeb.Dashboard.Circulation.Helpers do
  @moduledoc """
  Helper functions for the circulation dashboard components.
  """

  @doc """
  Returns CSS classes for transaction type badges.
  """
  def transaction_type_badge_class("loan"), do: "bg-blue-100 text-blue-800"
  def transaction_type_badge_class("return"), do: "bg-green-100 text-green-800"
  def transaction_type_badge_class("renewal"), do: "bg-yellow-100 text-yellow-800"
  def transaction_type_badge_class("lost_item"), do: "bg-red-100 text-red-800"
  def transaction_type_badge_class("damaged_item"), do: "bg-orange-100 text-orange-800"
  def transaction_type_badge_class("cancel"), do: "bg-gray-100 text-gray-800"
  def transaction_type_badge_class(_), do: "bg-gray-100 text-gray-800"

  @doc """
  Returns CSS classes for status badges.
  """
  def status_badge_class("active"), do: "bg-blue-100 text-blue-800"
  def status_badge_class("returned"), do: "bg-green-100 text-green-800"
  def status_badge_class("overdue"), do: "bg-red-100 text-red-800"
  def status_badge_class("lost"), do: "bg-red-100 text-red-800"
  def status_badge_class("damaged"), do: "bg-orange-100 text-orange-800"
  def status_badge_class("canceled"), do: "bg-gray-100 text-gray-800"
  def status_badge_class(_), do: "bg-gray-100 text-gray-800"

  @doc """
  Returns CSS classes for reservation status badges.
  """
  def reservation_status_badge_class("pending"), do: "bg-yellow-100 text-yellow-800"
  def reservation_status_badge_class("available"), do: "bg-green-100 text-green-800"
  def reservation_status_badge_class("picked_up"), do: "bg-blue-100 text-blue-800"
  def reservation_status_badge_class("expired"), do: "bg-red-100 text-red-800"
  def reservation_status_badge_class("cancelled"), do: "bg-gray-100 text-gray-800"
  def reservation_status_badge_class(_), do: "bg-gray-100 text-gray-800"

  @doc """
  Returns CSS classes for requisition type badges.
  """
  def requisition_type_badge_class("purchase_request"), do: "bg-blue-100 text-blue-800"
  def requisition_type_badge_class("interlibrary_loan"), do: "bg-green-100 text-green-800"
  def requisition_type_badge_class("digitization_request"), do: "bg-purple-100 text-purple-800"
  def requisition_type_badge_class("reference_question"), do: "bg-orange-100 text-orange-800"
  def requisition_type_badge_class(_), do: "bg-gray-100 text-gray-800"

  @doc """
  Returns CSS classes for requisition status badges.
  """
  def requisition_status_badge_class("submitted"), do: "bg-blue-100 text-blue-800"
  def requisition_status_badge_class("reviewing"), do: "bg-yellow-100 text-yellow-800"
  def requisition_status_badge_class("approved"), do: "bg-green-100 text-green-800"
  def requisition_status_badge_class("rejected"), do: "bg-red-100 text-red-800"
  def requisition_status_badge_class("fulfilled"), do: "bg-purple-100 text-purple-800"
  def requisition_status_badge_class("cancelled"), do: "bg-gray-100 text-gray-800"
  def requisition_status_badge_class(_), do: "bg-gray-100 text-gray-800"

  @doc """
  Returns CSS classes for fine type badges.
  """
  def fine_type_badge_class("overdue"), do: "bg-red-100 text-red-800"
  def fine_type_badge_class("lost_item"), do: "bg-red-100 text-red-800"
  def fine_type_badge_class("damaged_item"), do: "bg-orange-100 text-orange-800"
  def fine_type_badge_class("processing"), do: "bg-blue-100 text-blue-800"
  def fine_type_badge_class(_), do: "bg-gray-100 text-gray-800"

  @doc """
  Returns CSS classes for fine status badges.
  """
  def fine_status_badge_class("pending"), do: "bg-red-100 text-red-800"
  def fine_status_badge_class("partial_paid"), do: "bg-yellow-100 text-yellow-800"
  def fine_status_badge_class("paid"), do: "bg-green-100 text-green-800"
  def fine_status_badge_class("waived"), do: "bg-blue-100 text-blue-800"
  def fine_status_badge_class(_), do: "bg-gray-100 text-gray-800"

  @doc """
  Returns CSS classes for priority text.
  """
  def priority_text_class("urgent"), do: "text-red-600"
  def priority_text_class("high"), do: "text-orange-600"
  def priority_text_class("normal"), do: "text-gray-600"
  def priority_text_class("low"), do: "text-gray-500"
  def priority_text_class(_), do: "text-gray-600"

  @doc """
  Returns color classes for event types in history.
  """
  def event_type_color("loan"), do: "bg-blue-400"
  def event_type_color("return"), do: "bg-green-400"
  def event_type_color("renewal"), do: "bg-yellow-400"
  def event_type_color("reserve"), do: "bg-purple-400"
  def event_type_color("cancel_reserve"), do: "bg-gray-400"
  def event_type_color("fine_paid"), do: "bg-green-400"
  def event_type_color("fine_waived"), do: "bg-blue-400"
  def event_type_color("member_created"), do: "bg-indigo-400"
  def event_type_color("member_updated"), do: "bg-indigo-300"
  def event_type_color("item_status_change"), do: "bg-orange-400"
  def event_type_color(_), do: "bg-gray-400"

  @doc """
  Returns badge classes for event types in history detail.
  """
  def event_type_badge_class("loan"), do: "bg-blue-100 text-blue-800"
  def event_type_badge_class("return"), do: "bg-green-100 text-green-800"
  def event_type_badge_class("renewal"), do: "bg-yellow-100 text-yellow-800"
  def event_type_badge_class("reserve"), do: "bg-purple-100 text-purple-800"
  def event_type_badge_class("cancel_reserve"), do: "bg-gray-100 text-gray-800"
  def event_type_badge_class("fine_paid"), do: "bg-green-100 text-green-800"
  def event_type_badge_class("fine_waived"), do: "bg-blue-100 text-blue-800"
  def event_type_badge_class("member_created"), do: "bg-indigo-100 text-indigo-800"
  def event_type_badge_class("member_updated"), do: "bg-indigo-100 text-indigo-800"
  def event_type_badge_class("item_status_change"), do: "bg-orange-100 text-orange-800"
  def event_type_badge_class(_), do: "bg-gray-100 text-gray-800"

  @doc """
  Formats a DateTime to a user-friendly string.
  """
  def format_datetime(nil), do: "-"

  def format_datetime(datetime) do
    datetime
    |> Calendar.strftime("%m/%d/%Y %I:%M %p")
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
end
