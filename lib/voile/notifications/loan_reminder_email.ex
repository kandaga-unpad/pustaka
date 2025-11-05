defmodule Voile.Notifications.LoanReminderEmail do
  @moduledoc """
  Email templates for loan due date reminders.
  Generates and sends reminder emails to members about upcoming due dates.
  """

  import Swoosh.Email

  alias Voile.Mailer
  alias Voile.Schema.Library.Transaction
  alias Voile.Schema.Accounts.User

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
      |> html_body(build_html_body(member, transactions, days_before_due))
      |> text_body(build_text_body(member, transactions, days_before_due))

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
      |> html_body(build_overdue_html_body(member, transactions))
      |> text_body(build_overdue_text_body(member, transactions))

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
      |> html_body(build_manual_reminder_html_body(member, transactions, earliest_days_until_due))
      |> text_body(build_manual_reminder_text_body(member, transactions, earliest_days_until_due))

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

  defp build_html_body(member, transactions, days_before_due) do
    """
    <!DOCTYPE html>
    <html>
    <head>
      <style>
        body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
        .container { max-width: 600px; margin: 0 auto; padding: 20px; }
        .header { background-color: #4F46E5; color: white; padding: 20px; text-align: center; }
        .content { padding: 20px; background-color: #f9f9f9; }
        .item { background-color: white; margin: 10px 0; padding: 15px; border-left: 4px solid #4F46E5; }
        .item-title { font-weight: bold; color: #4F46E5; }
        .due-date { color: #DC2626; font-weight: bold; }
        .footer { padding: 20px; text-align: center; color: #666; font-size: 12px; }
        .warning { background-color: #FEF3C7; padding: 15px; margin: 20px 0; border-radius: 5px; }
        .divider { border-top: 3px dashed #4F46E5; margin: 40px 0; padding-top: 40px; }
        .lang-section { margin-bottom: 20px; }
      </style>
    </head>
    <body>
      <div class="container">
        <div class="header">
          <h1>Pengingat Peminjaman Perpustakaan / Library Loan Reminder</h1>
        </div>

        <div class="content">
          <!-- BAHASA INDONESIA VERSION -->
          <div class="lang-section">
            <p>Kepada Yth. #{member.fullname || "Anggota"},</p>

            <p>Ini adalah pengingat bahwa Anda memiliki <strong>#{length(transactions)}</strong>
            #{if length(transactions) == 1, do: "item", else: "item"} yang akan jatuh tempo dalam
            <strong>#{days_before_due} hari</strong>.</p>

            <div class="warning">
              ⚠️ Mohon mengembalikan atau memperpanjang item Anda sebelum tanggal jatuh tempo untuk menghindari denda keterlambatan.
            </div>

            <h3>Item Anda:</h3>
            #{Enum.map_join(transactions, "\n", &format_transaction_html/1)}

            <p style="margin-top: 30px;">
              <strong>Yang harus dilakukan:</strong><br>
              • Kembalikan item ke perpustakaan sebelum tanggal jatuh tempo<br>
              • Atau masuk ke akun Anda untuk meminta perpanjangan<br>
              • Hubungi perpustakaan jika Anda memerlukan bantuan
            </p>
          </div>

          <!-- DIVIDER -->
          <div class="divider"></div>

          <!-- ENGLISH VERSION -->
          <div class="lang-section">
            <p>Dear #{member.fullname || "Member"},</p>

            <p>This is a friendly reminder that you have <strong>#{length(transactions)}</strong>
            #{if length(transactions) == 1, do: "item", else: "items"} due in
            <strong>#{days_before_due} #{pluralize_day(days_before_due)}</strong>.</p>

            <div class="warning">
              ⚠️ Please return or renew your items before the due date to avoid late fees.
            </div>

            <h3>Your Items:</h3>
            #{Enum.map_join(transactions, "\n", &format_transaction_html/1)}

            <p style="margin-top: 30px;">
              <strong>What to do:</strong><br>
              • Return the items to the library before the due date<br>
              • Or log in to your account to request a renewal<br>
              • Contact the library if you need assistance
            </p>
          </div>
        </div>

        <div class="footer">
          <p>Ini adalah pesan otomatis dari Sistem Perpustakaan.</p>
          <p>This is an automated message from the Library System.</p>
          <p>Mohon tidak membalas email ini. / Please do not reply to this email.</p>
        </div>
        <div style="text-align: center; font-size: 12px; color: #666; margin-top: 20px;">
          <p>Jika Anda memerlukan bantuan, silakan hubungi perpustakaan Anda.</p>
          <p>If you need assistance, please contact your library.</p>
          <div>
            <a href="mailto:perpustakaan@unpad.ac.id">perpustakaan@unpad.ac.id</a>
            <a href="https://instagram.com/kandagaunpad">Instagram: @kandagaunpad</a>
            <a href="https://twitter.com/kandagaunpad">Twitter: @kandagaunpad</a>
            <a href="https://wa.me/6282315798979">WhatsApp: +62 823-1579-8979</a>
          </div>
        </div>
      </div>
    </body>
    </html>
    """
  end

  defp build_text_body(member, transactions, days_before_due) do
    """
    PENGINGAT PEMINJAMAN PERPUSTAKAAN / LIBRARY LOAN REMINDER

    ═══════════════════════════════════════════════════════════════
    VERSI BAHASA INDONESIA
    ═══════════════════════════════════════════════════════════════

    Kepada Yth. #{member.fullname || "Anggota"},

    Ini adalah pengingat bahwa Anda memiliki #{length(transactions)}
    #{if length(transactions) == 1, do: "item", else: "item"} yang akan jatuh tempo dalam
    #{days_before_due} hari.

    ITEM ANDA:
    #{Enum.map_join(transactions, "\n\n", &format_transaction_text/1)}

    YANG HARUS DILAKUKAN:
    - Kembalikan item ke perpustakaan sebelum tanggal jatuh tempo
    - Atau masuk ke akun Anda untuk meminta perpanjangan
    - Hubungi perpustakaan jika Anda memerlukan bantuan

    ⚠️ Mohon mengembalikan atau memperpanjang item Anda sebelum tanggal jatuh tempo untuk menghindari denda keterlambatan.

    ═══════════════════════════════════════════════════════════════
    ENGLISH VERSION
    ═══════════════════════════════════════════════════════════════

    Dear #{member.fullname || "Member"},

    This is a friendly reminder that you have #{length(transactions)}
    #{if length(transactions) == 1, do: "item", else: "items"} due in
    #{days_before_due} #{pluralize_day(days_before_due)}.

    YOUR ITEMS:
    #{Enum.map_join(transactions, "\n\n", &format_transaction_text/1)}

    WHAT TO DO:
    - Return the items to the library before the due date
    - Or log in to your account to request a renewal
    - Contact the library if you need assistance

    ⚠️ Please return or renew your items before the due date to avoid late fees.

    ═══════════════════════════════════════════════════════════════

    Ini adalah pesan otomatis dari Sistem Perpustakaan.
    This is an automated message from the Library System.

    Mohon tidak membalas email ini.
    Please do not reply to this email.
    """
  end

  defp build_overdue_html_body(member, transactions) do
    """
    <!DOCTYPE html>
    <html>
    <head>
      <style>
        body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
        .container { max-width: 600px; margin: 0 auto; padding: 20px; }
        .header { background-color: #DC2626; color: white; padding: 20px; text-align: center; }
        .content { padding: 20px; background-color: #f9f9f9; }
        .item { background-color: white; margin: 10px 0; padding: 15px; border-left: 4px solid #DC2626; }
        .item-title { font-weight: bold; color: #DC2626; }
        .overdue { color: #DC2626; font-weight: bold; }
        .footer { padding: 20px; text-align: center; color: #666; font-size: 12px; }
        .alert { background-color: #FEE2E2; padding: 15px; margin: 20px 0; border-radius: 5px; border: 2px solid #DC2626; }
        .divider { border-top: 3px dashed #DC2626; margin: 40px 0; padding-top: 40px; }
        .lang-section { margin-bottom: 20px; }
      </style>
    </head>
    <body>
      <div class="container">
        <div class="header">
          <h1>⚠️ ITEM TERLAMBAT / OVERDUE ITEMS</h1>
        </div>

        <div class="content">
          <!-- BAHASA INDONESIA VERSION -->
          <div class="lang-section">
            <p>Kepada Yth. #{member.fullname || "Anggota"},</p>

            <div class="alert">
              <strong>MENDESAK:</strong> Anda memiliki <strong>#{length(transactions)}</strong>
              #{if length(transactions) == 1, do: "item", else: "item"} yang
              TERLAMBAT dikembalikan. Denda keterlambatan mungkin berlaku.
            </div>

            <h3>Item Terlambat:</h3>
            #{Enum.map_join(transactions, "\n", &format_overdue_transaction_html/1)}

            <p style="margin-top: 30px;">
              <strong>Tindakan Segera Diperlukan:</strong><br>
              • Kembalikan item ke perpustakaan sesegera mungkin<br>
              • Hubungi perpustakaan untuk menyelesaikan masalah<br>
              • Denda keterlambatan terus bertambah pada item ini
            </p>
          </div>

          <!-- DIVIDER -->
          <div class="divider"></div>

          <!-- ENGLISH VERSION -->
          <div class="lang-section">
            <p>Dear #{member.fullname || "Member"},</p>

            <div class="alert">
              <strong>URGENT:</strong> You have <strong>#{length(transactions)}</strong>
              #{if length(transactions) == 1, do: "item", else: "items"} that
              #{if length(transactions) == 1, do: "is", else: "are"} OVERDUE.
              Late fees may apply.
            </div>

            <h3>Overdue Items:</h3>
            #{Enum.map_join(transactions, "\n", &format_overdue_transaction_html/1)}

            <p style="margin-top: 30px;">
              <strong>Immediate Action Required:</strong><br>
              • Return the items to the library as soon as possible<br>
              • Contact the library to resolve any issues<br>
              • Late fees are accumulating on these items
            </p>
          </div>
        </div>

        <div class="footer">
          <p>Ini adalah pesan otomatis dari Sistem Perpustakaan.</p>
          <p>This is an automated message from the Library System.</p>
          <p>Mohon tidak membalas email ini. / Please do not reply to this email.</p>
        </div>
        <div style="text-align: center; font-size: 12px; color: #666; margin-top: 20px;">
          <p>Jika Anda memerlukan bantuan, silakan hubungi perpustakaan Anda.</p>
          <p>If you need assistance, please contact your library.</p>
          <div>
            <a href="mailto:perpustakaan@unpad.ac.id">perpustakaan@unpad.ac.id</a>
            <a href="https://instagram.com/kandagaunpad">Instagram: @kandagaunpad</a>
            <a href="https://twitter.com/kandagaunpad">Twitter: @kandagaunpad</a>
            <a href="https://wa.me/6282315798979">WhatsApp: +62 823-1579-8979</a>
          </div>
        </div>
      </div>
    </body>
    </html>
    """
  end

  defp build_overdue_text_body(member, transactions) do
    """
    ⚠️ ITEM TERLAMBAT / OVERDUE ITEMS - TINDAKAN SEGERA DIPERLUKAN / IMMEDIATE ACTION REQUIRED

    ═══════════════════════════════════════════════════════════════
    VERSI BAHASA INDONESIA
    ═══════════════════════════════════════════════════════════════

    Kepada Yth. #{member.fullname || "Anggota"},

    MENDESAK: Anda memiliki #{length(transactions)}
    #{if length(transactions) == 1, do: "item", else: "item"} yang
    TERLAMBAT dikembalikan. Denda keterlambatan mungkin berlaku.

    ITEM TERLAMBAT:
    #{Enum.map_join(transactions, "\n\n", &format_overdue_transaction_text/1)}

    TINDAKAN SEGERA DIPERLUKAN:
    - Kembalikan item ke perpustakaan sesegera mungkin
    - Hubungi perpustakaan untuk menyelesaikan masalah
    - Denda keterlambatan terus bertambah pada item ini

    ═══════════════════════════════════════════════════════════════
    ENGLISH VERSION
    ═══════════════════════════════════════════════════════════════

    Dear #{member.fullname || "Member"},

    URGENT: You have #{length(transactions)}
    #{if length(transactions) == 1, do: "item", else: "items"} that
    #{if length(transactions) == 1, do: "is", else: "are"} OVERDUE.
    Late fees may apply.

    OVERDUE ITEMS:
    #{Enum.map_join(transactions, "\n\n", &format_overdue_transaction_text/1)}

    IMMEDIATE ACTION REQUIRED:
    - Return the items to the library as soon as possible
    - Contact the library to resolve any issues
    - Late fees are accumulating on these items

    ═══════════════════════════════════════════════════════════════

    Ini adalah pesan otomatis dari Sistem Perpustakaan.
    This is an automated message from the Library System.

    Mohon tidak membalas email ini.
    Please do not reply to this email.
    """
  end

  defp format_transaction_html(%Transaction{} = transaction) do
    transaction = Voile.Repo.preload(transaction, [:item, item: [:collection]])
    due_date_str = Calendar.strftime(transaction.due_date, "%B %d, %Y at %I:%M %p")

    """
    <div class="item">
      <div class="item-title">#{get_collection_title(transaction)}</div>
      <div>Item Code: #{get_item_code(transaction)}</div>
      <div class="due-date">Due Date: #{due_date_str}</div>
    </div>
    """
  end

  defp format_transaction_text(%Transaction{} = transaction) do
    transaction = Voile.Repo.preload(transaction, [:item, item: [:collection]])
    due_date_str = Calendar.strftime(transaction.due_date, "%B %d, %Y at %I:%M %p")

    """
    📚 #{get_collection_title(transaction)}
       Item Code: #{get_item_code(transaction)}
       Due Date: #{due_date_str}
    """
  end

  defp format_overdue_transaction_html(%Transaction{} = transaction) do
    transaction = Voile.Repo.preload(transaction, [:item, item: [:collection]])
    due_date_str = Calendar.strftime(transaction.due_date, "%B %d, %Y at %I:%M %p")
    days_overdue = Transaction.days_overdue(transaction)

    """
    <div class="item">
      <div class="item-title">#{get_collection_title(transaction)}</div>
      <div>Item Code: #{get_item_code(transaction)}</div>
      <div class="overdue">Was Due: #{due_date_str}</div>
      <div class="overdue">Days Overdue: #{days_overdue}</div>
    </div>
    """
  end

  defp format_overdue_transaction_text(%Transaction{} = transaction) do
    transaction = Voile.Repo.preload(transaction, [:item, item: [:collection]])
    due_date_str = Calendar.strftime(transaction.due_date, "%B %d, %Y at %I:%M %p")
    days_overdue = Transaction.days_overdue(transaction)

    """
    📚 #{get_collection_title(transaction)}
       Item Code: #{get_item_code(transaction)}
       Was Due: #{due_date_str}
       ⚠️ Days Overdue: #{days_overdue}
    """
  end

  defp get_item_code(%{item: %{item_code: code}}) when not is_nil(code), do: code
  defp get_item_code(_), do: "Unknown"

  defp get_collection_title(%{item: %{collection: %{title: title}}}) when not is_nil(title),
    do: title

  defp get_collection_title(_), do: "Unknown Collection"

  defp build_manual_reminder_html_body(member, transactions, earliest_days_until_due) do
    urgency_message =
      cond do
        earliest_days_until_due == 0 ->
          "item yang jatuh tempo HARI INI / item due TODAY"

        earliest_days_until_due == 1 ->
          "item yang jatuh tempo BESOK / item due TOMORROW"

        earliest_days_until_due <= 3 ->
          "item yang jatuh tempo dalam #{earliest_days_until_due} hari / items due in #{earliest_days_until_due} days"

        true ->
          "item aktif / active items"
      end

    """
    <!DOCTYPE html>
    <html>
    <head>
      <style>
        body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
        .container { max-width: 600px; margin: 0 auto; padding: 20px; }
        .header { background-color: #7C3AED; color: white; padding: 20px; text-align: center; }
        .content { padding: 20px; background-color: #f9f9f9; }
        .item { background-color: white; margin: 10px 0; padding: 15px; border-left: 4px solid #7C3AED; }
        .item-title { font-weight: bold; color: #7C3AED; }
        .due-date { color: #DC2626; font-weight: bold; }
        .footer { padding: 20px; text-align: center; color: #666; font-size: 12px; }
        .info { background-color: #DBEAFE; padding: 15px; margin: 20px 0; border-radius: 5px; }
        .divider { border-top: 3px dashed #7C3AED; margin: 40px 0; padding-top: 40px; }
        .lang-section { margin-bottom: 20px; }
        .urgent-badge { background-color: #FEE2E2; color: #DC2626; padding: 10px 15px; border-radius: 5px; font-weight: bold; margin: 15px 0; text-align: center; }
      </style>
    </head>
    <body>
      <div class="container">
        <div class="header">
          <h1>Pengingat dari Pustakawan / Reminder from Librarian</h1>
        </div>

        <div class="content">
          <!-- BAHASA INDONESIA VERSION -->
          <div class="lang-section">
            <p>Kepada Yth. #{member.fullname || "Anggota"},</p>

            <p>Pustakawan kami telah mengirimkan pengingat mengenai peminjaman Anda.
            Anda memiliki <strong>#{length(transactions)}</strong>
            #{if length(transactions) == 1, do: "item aktif", else: "item aktif"}.</p>

            #{if earliest_days_until_due <= 3 do
      """
      <div class="urgent-badge">
        ⚠️ Item paling cepat jatuh tempo: #{urgency_message}
      </div>
      """
    end}

            <div class="info">
              ℹ️ Ini adalah pengingat manual dari staf perpustakaan. Mohon periksa status peminjaman Anda.
            </div>

            <h3>Item Pinjaman Anda:</h3>
            #{Enum.map_join(transactions, "\n", &format_transaction_html/1)}

            <p style="margin-top: 30px;">
              <strong>Silakan:</strong><br>
              • Periksa tanggal jatuh tempo setiap item<br>
              • Kembalikan item yang sudah jatuh tempo atau akan jatuh tempo segera<br>
              • Hubungi perpustakaan jika Anda memiliki pertanyaan<br>
              • Perpanjang peminjaman jika memungkinkan
            </p>
          </div>

          <!-- DIVIDER -->
          <div class="divider"></div>

          <!-- ENGLISH VERSION -->
          <div class="lang-section">
            <p>Dear #{member.fullname || "Member"},</p>

            <p>Our librarian has sent you a reminder about your loans.
            You have <strong>#{length(transactions)}</strong>
            active #{if length(transactions) == 1, do: "item", else: "items"}.</p>

            #{if earliest_days_until_due <= 3 do
      """
      <div class="urgent-badge">
        ⚠️ Earliest item due: #{urgency_message}
      </div>
      """
    end}

            <div class="info">
              ℹ️ This is a manual reminder from library staff. Please check your loan status.
            </div>

            <h3>Your Borrowed Items:</h3>
            #{Enum.map_join(transactions, "\n", &format_transaction_html/1)}

            <p style="margin-top: 30px;">
              <strong>Please:</strong><br>
              • Check the due date for each item<br>
              • Return items that are overdue or due soon<br>
              • Contact the library if you have any questions<br>
              • Renew loans if possible
            </p>
          </div>
        </div>

        <div class="footer">
          <p>Pengingat manual dari Perpustakaan.</p>
          <p>Manual reminder from the Library.</p>
        </div>
        <div style="text-align: center; font-size: 12px; color: #666; margin-top: 20px;">
          <p>Jika Anda memerlukan bantuan, silakan hubungi perpustakaan Anda.</p>
          <p>If you need assistance, please contact your library.</p>
          <div>
            <a href="mailto:perpustakaan@unpad.ac.id">perpustakaan@unpad.ac.id</a>
            <a href="https://instagram.com/kandagaunpad">Instagram: @kandagaunpad</a>
            <a href="https://twitter.com/kandagaunpad">Twitter: @kandagaunpad</a>
            <a href="https://wa.me/6282315798979">WhatsApp: +62 823-1579-8979</a>
          </div>
        </div>
      </div>
    </body>
    </html>
    """
  end

  defp build_manual_reminder_text_body(member, transactions, earliest_days_until_due) do
    urgency_message =
      cond do
        earliest_days_until_due == 0 ->
          "HARI INI / TODAY"

        earliest_days_until_due == 1 ->
          "BESOK / TOMORROW"

        earliest_days_until_due <= 3 ->
          "dalam #{earliest_days_until_due} hari / in #{earliest_days_until_due} days"

        true ->
          ""
      end

    urgency_notice =
      if earliest_days_until_due <= 3 do
        """

        ⚠️ PERHATIAN: Item paling cepat jatuh tempo #{urgency_message}
        ⚠️ ATTENTION: Earliest item due #{urgency_message}
        """
      else
        ""
      end

    """
    PENGINGAT DARI PUSTAKAWAN / REMINDER FROM LIBRARIAN

    ═══════════════════════════════════════════════════════════════
    VERSI BAHASA INDONESIA
    ═══════════════════════════════════════════════════════════════

    Kepada Yth. #{member.fullname || "Anggota"},

    Pustakawan kami telah mengirimkan pengingat mengenai peminjaman Anda.
    Anda memiliki #{length(transactions)}
    #{if length(transactions) == 1, do: "item aktif", else: "item aktif"}.#{urgency_notice}

    ℹ️ Ini adalah pengingat manual dari staf perpustakaan.
    Mohon periksa status peminjaman Anda.

    ITEM PINJAMAN ANDA:
    #{Enum.map_join(transactions, "\n\n", &format_transaction_text/1)}

    SILAKAN:
    - Periksa tanggal jatuh tempo setiap item
    - Kembalikan item yang sudah jatuh tempo atau akan jatuh tempo segera
    - Hubungi perpustakaan jika Anda memiliki pertanyaan
    - Perpanjang peminjaman jika memungkinkan

    ═══════════════════════════════════════════════════════════════
    ENGLISH VERSION
    ═══════════════════════════════════════════════════════════════

    Dear #{member.fullname || "Member"},

    Our librarian has sent you a reminder about your loans.
    You have #{length(transactions)}
    active #{if length(transactions) == 1, do: "item", else: "items"}.#{urgency_notice}

    ℹ️ This is a manual reminder from library staff.
    Please check your loan status.

    YOUR BORROWED ITEMS:
    #{Enum.map_join(transactions, "\n\n", &format_transaction_text/1)}

    PLEASE:
    - Check the due date for each item
    - Return items that are overdue or due soon
    - Contact the library if you have any questions
    - Renew loans if possible

    ═══════════════════════════════════════════════════════════════

    Pengingat manual dari Perpustakaan.
    Manual reminder from the Library.
    """
  end
end
