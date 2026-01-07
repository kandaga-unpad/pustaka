defmodule Voile.Schema.Catalog.StockOpnameNotifier do
  @moduledoc """
  Delivers notifications for stock opname events.
  """

  import Swoosh.Email
  alias Voile.Mailer

  # For now, use a placeholder for admin email
  # TODO: Get admin email from Settings context
  defp get_admin_email do
    # Placeholder - should be retrieved from Settings context
    "admin@example.com"
  end

  @doc """
  Deliver notification when session is started and librarians are assigned.
  """
  def deliver_session_started_notification(session, librarians) do
    session_url = url("/dashboard/stock-opname/#{session.id}")

    librarians
    |> Enum.map(fn librarian ->
      new()
      |> to({librarian.full_name || librarian.email, librarian.email})
      |> from({"Voile System", "noreply@voile.app"})
      |> subject("Stock Opname Session Started: #{session.title}")
      |> html_body("""
      <h2>Stock Opname Session Started</h2>
      <p>You have been assigned to a new stock opname session:</p>
      <ul>
        <li><strong>Session Code:</strong> #{session.session_code}</li>
        <li><strong>Title:</strong> #{session.title}</li>
        <li><strong>Total Items:</strong> #{session.total_items}</li>
      </ul>
      <p><a href="#{session_url}">View Session</a></p>
      <p>Please log in to start checking items.</p>
      """)
      |> text_body("""
      Stock Opname Session Started

      You have been assigned to a new stock opname session:

      Session Code: #{session.session_code}
      Title: #{session.title}
      Total Items: #{session.total_items}

      View session: #{session_url}

      Please log in to start checking items.
      """)
      |> Mailer.deliver()
    end)
  end

  @doc """
  Deliver notification when a librarian completes their work.
  """
  def deliver_librarian_completed_notification(session, librarian, assignment) do
    admin_email = get_admin_email()
    session_url = url("/dashboard/stock-opname/#{session.id}")

    new()
    |> to(admin_email)
    |> from({"Voile System", "noreply@voile.app"})
    |> subject("Librarian Completed Work: #{session.title}")
    |> html_body("""
    <h2>Librarian Completed Work Session</h2>
    <p><strong>#{librarian.full_name || librarian.email}</strong> has completed their work on the stock opname session:</p>
    <ul>
      <li><strong>Session:</strong> #{session.title} (#{session.session_code})</li>
      <li><strong>Items Checked:</strong> #{assignment.items_checked}</li>
    </ul>
    <p><a href="#{session_url}">View Session</a></p>
    """)
    |> text_body("""
    Librarian Completed Work Session

    #{librarian.full_name || librarian.email} has completed their work on the stock opname session:

    Session: #{session.title} (#{session.session_code})
    Items Checked: #{assignment.items_checked}

    View session: #{session_url}
    """)
    |> Mailer.deliver()
  end

  @doc """
  Deliver notification when session is completed and ready for review.
  """
  def deliver_session_completed_notification(session) do
    admin_email = get_admin_email()
    review_url = url("/dashboard/stock-opname/#{session.id}/review")

    new()
    |> to(admin_email)
    |> from({"Voile System", "noreply@voile.app"})
    |> subject("Stock Opname Ready for Review: #{session.title}")
    |> html_body("""
    <h2>Stock Opname Session Ready for Review</h2>
    <p>The stock opname session <strong>#{session.title}</strong> (#{session.session_code}) has been completed and is ready for your review.</p>
    <h3>Summary</h3>
    <ul>
      <li><strong>Total Items:</strong> #{session.total_items}</li>
      <li><strong>Checked Items:</strong> #{session.checked_items}</li>
      <li><strong>Missing Items:</strong> #{session.missing_items}</li>
      <li><strong>Items with Changes:</strong> #{session.items_with_changes}</li>
    </ul>
    <p><a href="#{review_url}">Review Session</a></p>
    """)
    |> text_body("""
    Stock Opname Session Ready for Review

    The stock opname session #{session.title} (#{session.session_code}) has been completed and is ready for your review.

    Summary:
    - Total Items: #{session.total_items}
    - Checked Items: #{session.checked_items}
    - Missing Items: #{session.missing_items}
    - Items with Changes: #{session.items_with_changes}

    Review session: #{review_url}
    """)
    |> Mailer.deliver()
  end

  @doc """
  Deliver notification when session is approved.
  """
  def deliver_session_approved_notification(session, librarians) do
    session_url = url("/dashboard/stock-opname/#{session.id}")

    librarians
    |> Enum.map(fn librarian ->
      new()
      |> to({librarian.full_name || librarian.email, librarian.email})
      |> from({"Voile System", "noreply@voile.app"})
      |> subject("Stock Opname Approved: #{session.title}")
      |> html_body("""
      <h2>Stock Opname Session Approved</h2>
      <p>The stock opname session <strong>#{session.title}</strong> (#{session.session_code}) has been approved.</p>
      <p>All changes have been applied to the system.</p>
      <p><a href="#{session_url}">View Session</a></p>
      """)
      |> text_body("""
      Stock Opname Session Approved

      The stock opname session #{session.title} (#{session.session_code}) has been approved.

      All changes have been applied to the system.

      View session: #{session_url}
      """)
      |> Mailer.deliver()
    end)
  end

  @doc """
  Deliver notification when session is rejected.
  """
  def deliver_session_rejected_notification(session, librarians, reason) do
    session_url = url("/dashboard/stock-opname/#{session.id}")

    librarians
    |> Enum.map(fn librarian ->
      new()
      |> to({librarian.full_name || librarian.email, librarian.email})
      |> from({"Voile System", "noreply@voile.app"})
      |> subject("Stock Opname Rejected: #{session.title}")
      |> html_body("""
      <h2>Stock Opname Session Rejected</h2>
      <p>The stock opname session <strong>#{session.title}</strong> (#{session.session_code}) has been rejected.</p>
      <h3>Reason:</h3>
      <p>#{reason}</p>
      <p><a href="#{session_url}">View Session</a></p>
      """)
      |> text_body("""
      Stock Opname Session Rejected

      The stock opname session #{session.title} (#{session.session_code}) has been rejected.

      Reason:
      #{reason}

      View session: #{session_url}
      """)
      |> Mailer.deliver()
    end)
  end

  @doc """
  Deliver notification when revision is requested.
  """
  def deliver_revision_requested_notification(session, librarians, notes) do
    session_url = url("/dashboard/stock-opname/#{session.id}/scan")

    librarians
    |> Enum.map(fn librarian ->
      new()
      |> to({librarian.full_name || librarian.email, librarian.email})
      |> from({"Voile System", "noreply@voile.app"})
      |> subject("Stock Opname Revision Requested: #{session.title}")
      |> html_body("""
      <h2>Stock Opname Revision Requested</h2>
      <p>A revision has been requested for the stock opname session <strong>#{session.title}</strong> (#{session.session_code}).</p>
      <h3>Notes from Reviewer:</h3>
      <p>#{notes}</p>
      <p><a href="#{session_url}">Resume Session</a></p>
      """)
      |> text_body("""
      Stock Opname Revision Requested

      A revision has been requested for the stock opname session #{session.title} (#{session.session_code}).

      Notes from Reviewer:
      #{notes}

      Resume session: #{session_url}
      """)
      |> Mailer.deliver()
    end)
  end

  # Generate URL helper
  defp url(path) do
    # Use VoileWeb.Endpoint to generate full URL
    VoileWeb.Endpoint.url() <> path
  end
end
