defmodule Voile.Schema.StockOpname.Notifier do
  @moduledoc """
  Delivers notifications for stock opname events.
  """

  import Swoosh.Email
  alias Voile.Mailer
  alias VoileWeb.EmailComponent.Template

  # For now, use a placeholder for admin email
  # TODO: Get admin email from Settings context
  defp get_admin_email do
    # Placeholder - should be retrieved from Settings context
    "perpustakaan@unpad.ac.id"
  end

  @doc """
  Deliver notification when session is started and librarians are assigned.
  """
  def deliver_session_started_notification(session, librarians) do
    librarians
    |> Enum.map(fn librarian ->
      html_body = Template.stock_opname_session_started(session, librarian)

      text_body = """
      Stock Opname Session Started / Sesi Stock Opname Dimulai

      You have been assigned to: #{session.title} (#{session.session_code})
      Anda telah ditugaskan untuk: #{session.title} (#{session.session_code})

      Total Items / Total Koleksi: #{session.total_items}

      Please log in to start checking items.
      Silakan masuk untuk mulai memeriksa koleksi.

      View session: #{VoileWeb.Endpoint.url()}/manage/stock-opname/#{session.id}
      """

      new()
      |> to({librarian.fullname || librarian.email, librarian.email})
      |> from({"Voile System", "perpustakaan@unpad.ac.id"})
      |> subject("Stock Opname Session Started: #{session.title}")
      |> html_body(html_body)
      |> text_body(text_body)
      |> Mailer.deliver()
    end)
  end

  @doc """
  Deliver notification when a librarian completes their work.
  """
  def deliver_librarian_completed_notification(session, librarian, assignment) do
    admin_email = get_admin_email()
    html_body = Template.stock_opname_librarian_completed(session, librarian, assignment)

    text_body = """
    Librarian Completed Work / Pustakawan Selesai Bekerja

    #{librarian.fullname || librarian.email} has completed their work on:
    #{librarian.fullname || librarian.email} telah menyelesaikan pekerjaan pada:

    Session / Sesi: #{session.title} (#{session.session_code})
    Items Checked / Koleksi Diperiksa: #{assignment.items_checked}

    View session: #{VoileWeb.Endpoint.url()}/manage/stock-opname/#{session.id}
    """

    new()
    |> to(admin_email)
    |> from({"Voile System", "perpustakaan@unpad.ac.id"})
    |> subject("Librarian Completed Work: #{session.title}")
    |> html_body(html_body)
    |> text_body(text_body)
    |> Mailer.deliver()
  end

  @doc """
  Deliver notification when session is completed and ready for review.
  """
  def deliver_session_completed_notification(session) do
    admin_email = get_admin_email()
    html_body = Template.stock_opname_session_completed(session)

    text_body = """
    Stock Opname Ready for Review / Siap untuk Ditinjau

    The session is ready for review:
    Sesi siap untuk ditinjau:

    #{session.title} (#{session.session_code})

    Summary / Ringkasan:
    - Total Items / Total Koleksi: #{session.total_items}
    - Checked / Diperiksa: #{session.checked_items}
    - Missing / Hilang: #{session.missing_items}
    - With Changes / Ada Perubahan: #{session.items_with_changes}

    Review: #{VoileWeb.Endpoint.url()}/manage/stock-opname/#{session.id}/review
    """

    new()
    |> to(admin_email)
    |> from({"Voile System", "perpustakaan@unpad.ac.id"})
    |> subject("Stock Opname Ready for Review: #{session.title}")
    |> html_body(html_body)
    |> text_body(text_body)
    |> Mailer.deliver()
  end

  @doc """
  Deliver notification when session is approved.
  """
  def deliver_session_approved_notification(session, librarians) do
    librarians
    |> Enum.map(fn librarian ->
      html_body = Template.stock_opname_session_approved(session, librarian)

      text_body = """
      Stock Opname Session Approved / Sesi Disetujui

      The session has been approved:
      Sesi telah disetujui:

      #{session.title} (#{session.session_code})

      All changes have been applied to the system.
      Semua perubahan telah diterapkan ke sistem.

      View session: #{VoileWeb.Endpoint.url()}/manage/stock-opname/#{session.id}
      """

      new()
      |> to({librarian.fullname || librarian.email, librarian.email})
      |> from({"Voile System", "perpustakaan@unpad.ac.id"})
      |> subject("Stock Opname Approved: #{session.title}")
      |> html_body(html_body)
      |> text_body(text_body)
      |> Mailer.deliver()
    end)
  end

  @doc """
  Deliver notification when session is rejected.
  """
  def deliver_session_rejected_notification(session, librarians, reason) do
    librarians
    |> Enum.map(fn librarian ->
      html_body = Template.stock_opname_session_rejected(session, librarian, reason)

      text_body = """
      Stock Opname Session Rejected / Sesi Ditolak

      The session has been rejected:
      Sesi telah ditolak:

      #{session.title} (#{session.session_code})

      Reason / Alasan:
      #{reason}

      View session: #{VoileWeb.Endpoint.url()}/manage/stock-opname/#{session.id}
      """

      new()
      |> to({librarian.fullname || librarian.email, librarian.email})
      |> from({"Voile System", "perpustakaan@unpad.ac.id"})
      |> subject("Stock Opname Rejected: #{session.title}")
      |> html_body(html_body)
      |> text_body(text_body)
      |> Mailer.deliver()
    end)
  end

  @doc """
  Deliver notification when revision is requested.
  """
  def deliver_revision_requested_notification(session, librarians, notes) do
    librarians
    |> Enum.map(fn librarian ->
      html_body = Template.stock_opname_revision_requested(session, librarian, notes)

      text_body = """
      Stock Opname Revision Requested / Revisi Diperlukan

      A revision has been requested for:
      Revisi telah diminta untuk:

      #{session.title} (#{session.session_code})

      Notes from Reviewer / Catatan dari Reviewer:
      #{notes}

      Resume session: #{VoileWeb.Endpoint.url()}/manage/stock-opname/#{session.id}/scan
      """

      new()
      |> to({librarian.fullname || librarian.email, librarian.email})
      |> from({"Voile System", "perpustakaan@unpad.ac.id"})
      |> subject("Stock Opname Revision Requested: #{session.title}")
      |> html_body(html_body)
      |> text_body(text_body)
      |> Mailer.deliver()
    end)
  end
end
