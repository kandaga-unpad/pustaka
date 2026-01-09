defmodule VoileWeb.EmailComponent.Template do
  @moduledoc """
  Centralized HTML email templates for Voile system notifications.
  """

  alias Voile.Repo
  alias Voile.Schema.Library.Transaction
  alias Voile.Schema.System

  def confirmation_instructions(user, url) do
    app_name = System.get_setting_value("app_name", "Voile")
    app_logo_url = System.get_setting_value("app_logo_url", nil)

    """
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <style>
        body { margin: 0; padding: 0; font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background-color: #f5f7fa; }
        .wrapper { width: 100%; background-color: #f5f7fa; padding: 20px 0; }
        .container { max-width: 600px; margin: 0 auto; background-color: #ffffff; border-radius: 12px; overflow: hidden; box-shadow: 0 4px 6px rgba(0,0,0,0.1); }
        .header { background: linear-gradient(135deg, #4F46E5 0%, #6366F1 100%); padding: 40px 30px; text-align: center; color: white; }
        .header h1 { margin: 0 0 10px 0; font-size: 28px; font-weight: 700; }
        .header p { margin: 0; font-size: 16px; opacity: 0.95; }
        .logo-container { display: inline-block; margin-bottom: 15px; }
        .logo-container img { height: 50px; width: auto; }
        .content { padding: 40px 30px; }
        .greeting { font-size: 18px; color: #2d3748; margin-bottom: 20px; font-weight: 600; }
        .message { font-size: 15px; line-height: 1.8; color: #4a5568; margin-bottom: 25px; }
        .cta-button { display: inline-block; background: linear-gradient(135deg, #4F46E5 0%, #6366F1 100%); color: white; text-decoration: none; padding: 14px 32px; border-radius: 8px; font-weight: 600; font-size: 16px; margin: 25px 0; box-shadow: 0 4px 6px rgba(79,70,229,0.3); }
        .cta-button:hover { box-shadow: 0 6px 12px rgba(79,70,229,0.4); }
        .divider { border-top: 2px dashed #cbd5e0; margin: 40px 0; }
        .footer { background-color: #f7fafc; padding: 25px 30px; text-align: center; font-size: 13px; color: #718096; border-top: 1px solid #e2e8f0; }
        .footer-links { margin-top: 15px; }
        .footer-links a { color: #4F46E5; text-decoration: none; margin: 0 8px; }
        @media only screen and (max-width: 600px) {
          .content { padding: 25px 20px; }
        }
      </style>
    </head>
    <body>
      <div class="wrapper">
        <div class="container">
          <div class="header">
            #{if app_logo_url, do: "<div class='logo-container'><img src='#{app_logo_url}' alt='#{app_name}' /></div>", else: ""}
            <h1>✉️ Konfirmasi Akun / Account Confirmation</h1>
            <p>Verifikasi email Anda | Verify your email</p>
          </div>

          <div class="content">
            <!-- BAHASA INDONESIA -->
            <div class="greeting">Kepada Yth. #{user.email},</div>
            <div class="message">
              Silakan konfirmasi akun Anda dengan mengklik tombol di bawah ini. Jika Anda tidak membuat akun dengan kami, abaikan email ini.
            </div>

            <div style="text-align: center;">
              <a href="#{url}" class="cta-button">✅ Konfirmasi Akun</a>
            </div>

            <div class="divider"></div>

            <!-- ENGLISH -->
            <div class="greeting">Dear #{user.email},</div>
            <div class="message">
              Please confirm your account by clicking the button below. If you didn't create an account with us, please ignore this email.
            </div>

            <div style="text-align: center;">
              <a href="#{url}" class="cta-button">✅ Confirm Account</a>
            </div>
          </div>

          <div class="footer">
            <p><strong>Ini adalah pesan otomatis dari Sistem Perpustakaan.</strong><br>
            This is an automated message from the Library System.</p>
            <p>Mohon tidak membalas email ini. | Please do not reply to this email.</p>
            <div class="footer-links">
              <a href="mailto:perpustakaan@unpad.ac.id">📧 Email</a>
              <a href="https://instagram.com/kandagaunpad">📱 Instagram</a>
              <a href="https://wa.me/6282315798979">💬 WhatsApp</a>
            </div>
          </div>
        </div>
      </div>
    </body>
    </html>
    """
  end

  def reset_password_instructions(user, url) do
    app_name = System.get_setting_value("app_name", "Voile")
    app_logo_url = System.get_setting_value("app_logo_url", nil)

    """
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <style>
        body { margin: 0; padding: 0; font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background-color: #f5f7fa; }
        .wrapper { width: 100%; background-color: #f5f7fa; padding: 20px 0; }
        .container { max-width: 600px; margin: 0 auto; background-color: #ffffff; border-radius: 12px; overflow: hidden; box-shadow: 0 4px 6px rgba(0,0,0,0.1); }
        .header { background: linear-gradient(135deg, #DC2626 0%, #EF4444 100%); padding: 40px 30px; text-align: center; color: white; }
        .header h1 { margin: 0 0 10px 0; font-size: 28px; font-weight: 700; }
        .header p { margin: 0; font-size: 16px; opacity: 0.95; }
        .logo-container { display: inline-block; margin-bottom: 15px; }
        .logo-container img { height: 50px; width: auto; }
        .content { padding: 40px 30px; }
        .greeting { font-size: 18px; color: #2d3748; margin-bottom: 20px; font-weight: 600; }
        .message { font-size: 15px; line-height: 1.8; color: #4a5568; margin-bottom: 25px; }
        .cta-button { display: inline-block; background: linear-gradient(135deg, #DC2626 0%, #EF4444 100%); color: white; text-decoration: none; padding: 14px 32px; border-radius: 8px; font-weight: 600; font-size: 16px; margin: 25px 0; box-shadow: 0 4px 6px rgba(220,38,38,0.3); }
        .cta-button:hover { box-shadow: 0 6px 12px rgba(220,38,38,0.4); }
        .divider { border-top: 2px dashed #cbd5e0; margin: 40px 0; }
        .footer { background-color: #f7fafc; padding: 25px 30px; text-align: center; font-size: 13px; color: #718096; border-top: 1px solid #e2e8f0; }
        .footer-links { margin-top: 15px; }
        .footer-links a { color: #DC2626; text-decoration: none; margin: 0 8px; }
        @media only screen and (max-width: 600px) {
          .content { padding: 25px 20px; }
        }
      </style>
    </head>
    <body>
      <div class="wrapper">
        <div class="container">
          <div class="header">
            #{if app_logo_url, do: "<div class='logo-container'><img src='#{app_logo_url}' alt='#{app_name}' /></div>", else: ""}
            <h1>🔒 Reset Password / Atur Ulang Kata Sandi</h1>
            <p>Reset kata sandi Anda | Reset your password</p>
          </div>

          <div class="content">
            <!-- BAHASA INDONESIA -->
            <div class="greeting">Kepada Yth. #{user.email},</div>
            <div class="message">
              Anda dapat mengatur ulang kata sandi Anda dengan mengklik tombol di bawah ini. Jika Anda tidak meminta perubahan ini, abaikan email ini.
            </div>

            <div style="text-align: center;">
              <a href="#{url}" class="cta-button">🔑 Reset Password</a>
            </div>

            <div class="divider"></div>

            <!-- ENGLISH -->
            <div class="greeting">Dear #{user.email},</div>
            <div class="message">
              You can reset your password by clicking the button below. If you didn't request this change, please ignore this email.
            </div>

            <div style="text-align: center;">
              <a href="#{url}" class="cta-button">🔑 Reset Password</a>
            </div>
          </div>

          <div class="footer">
            <p><strong>Ini adalah pesan otomatis dari Sistem Perpustakaan.</strong><br>
            This is an automated message from the Library System.</p>
            <p>Mohon tidak membalas email ini. | Please do not reply to this email.</p>
            <div class="footer-links">
              <a href="mailto:perpustakaan@unpad.ac.id">📧 Email</a>
              <a href="https://instagram.com/kandagaunpad">📱 Instagram</a>
              <a href="https://wa.me/6282315798979">💬 WhatsApp</a>
            </div>
          </div>
        </div>
      </div>
    </body>
    </html>
    """
  end

  def update_email_instructions(user, url) do
    app_name = System.get_setting_value("app_name", "Voile")
    app_logo_url = System.get_setting_value("app_logo_url", nil)

    """
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <style>
        body { margin: 0; padding: 0; font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background-color: #f5f7fa; }
        .wrapper { width: 100%; background-color: #f5f7fa; padding: 20px 0; }
        .container { max-width: 600px; margin: 0 auto; background-color: #ffffff; border-radius: 12px; overflow: hidden; box-shadow: 0 4px 6px rgba(0,0,0,0.1); }
        .header { background: linear-gradient(135deg, #7C3AED 0%, #8B5CF6 100%); padding: 40px 30px; text-align: center; color: white; }
        .header h1 { margin: 0 0 10px 0; font-size: 28px; font-weight: 700; }
        .header p { margin: 0; font-size: 16px; opacity: 0.95; }
        .logo-container { display: inline-block; margin-bottom: 15px; }
        .logo-container img { height: 50px; width: auto; }
        .content { padding: 40px 30px; }
        .greeting { font-size: 18px; color: #2d3748; margin-bottom: 20px; font-weight: 600; }
        .message { font-size: 15px; line-height: 1.8; color: #4a5568; margin-bottom: 25px; }
        .cta-button { display: inline-block; background: linear-gradient(135deg, #7C3AED 0%, #8B5CF6 100%); color: white; text-decoration: none; padding: 14px 32px; border-radius: 8px; font-weight: 600; font-size: 16px; margin: 25px 0; box-shadow: 0 4px 6px rgba(124,58,237,0.3); }
        .cta-button:hover { box-shadow: 0 6px 12px rgba(124,58,237,0.4); }
        .divider { border-top: 2px dashed #cbd5e0; margin: 40px 0; }
        .footer { background-color: #f7fafc; padding: 25px 30px; text-align: center; font-size: 13px; color: #718096; border-top: 1px solid #e2e8f0; }
        .footer-links { margin-top: 15px; }
        .footer-links a { color: #7C3AED; text-decoration: none; margin: 0 8px; }
        @media only screen and (max-width: 600px) {
          .content { padding: 25px 20px; }
        }
      </style>
    </head>
    <body>
      <div class="wrapper">
        <div class="container">
          <div class="header">
            #{if app_logo_url, do: "<div class='logo-container'><img src='#{app_logo_url}' alt='#{app_name}' /></div>", else: ""}
            <h1>📧 Perbarui Email / Update Email</h1>
            <p>Ubah alamat email Anda | Change your email address</p>
          </div>

          <div class="content">
            <!-- BAHASA INDONESIA -->
            <div class="greeting">Kepada Yth. #{user.email},</div>
            <div class="message">
              Anda dapat memperbarui email Anda dengan mengklik tombol di bawah ini. Jika Anda tidak meminta perubahan ini, abaikan email ini.
            </div>

            <div style="text-align: center;">
              <a href="#{url}" class="cta-button">📝 Perbarui Email</a>
            </div>

            <div class="divider"></div>

            <!-- ENGLISH -->
            <div class="greeting">Dear #{user.email},</div>
            <div class="message">
              You can change your email by clicking the button below. If you didn't request this change, please ignore this email.
            </div>

            <div style="text-align: center;">
              <a href="#{url}" class="cta-button">📝 Update Email</a>
            </div>
          </div>

          <div class="footer">
            <p><strong>Ini adalah pesan otomatis dari Sistem Perpustakaan.</strong><br>
            This is an automated message from the Library System.</p>
            <p>Mohon tidak membalas email ini. | Please do not reply to this email.</p>
            <div class="footer-links">
              <a href="mailto:perpustakaan@unpad.ac.id">📧 Email</a>
              <a href="https://instagram.com/kandagaunpad">📱 Instagram</a>
              <a href="https://wa.me/6282315798979">💬 WhatsApp</a>
            </div>
          </div>
        </div>
      </div>
    </body>
    </html>
    """
  end

  def magic_link_instructions(user, url) do
    app_name = System.get_setting_value("app_name", "Voile")
    app_logo_url = System.get_setting_value("app_logo_url", nil)

    """
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <style>
        body { margin: 0; padding: 0; font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background-color: #f5f7fa; }
        .wrapper { width: 100%; background-color: #f5f7fa; padding: 20px 0; }
        .container { max-width: 600px; margin: 0 auto; background-color: #ffffff; border-radius: 12px; overflow: hidden; box-shadow: 0 4px 6px rgba(0,0,0,0.1); }
        .header { background: linear-gradient(135deg, #059669 0%, #10b981 100%); padding: 40px 30px; text-align: center; color: white; }
        .header h1 { margin: 0 0 10px 0; font-size: 28px; font-weight: 700; }
        .header p { margin: 0; font-size: 16px; opacity: 0.95; }
        .logo-container { display: inline-block; margin-bottom: 15px; }
        .logo-container img { height: 50px; width: auto; }
        .content { padding: 40px 30px; }
        .greeting { font-size: 18px; color: #2d3748; margin-bottom: 20px; font-weight: 600; }
        .message { font-size: 15px; line-height: 1.8; color: #4a5568; margin-bottom: 25px; }
        .cta-button { display: inline-block; background: linear-gradient(135deg, #059669 0%, #10b981 100%); color: white; text-decoration: none; padding: 14px 32px; border-radius: 8px; font-weight: 600; font-size: 16px; margin: 25px 0; box-shadow: 0 4px 6px rgba(5,150,105,0.3); }
        .cta-button:hover { box-shadow: 0 6px 12px rgba(5,150,105,0.4); }
        .divider { border-top: 2px dashed #cbd5e0; margin: 40px 0; }
        .footer { background-color: #f7fafc; padding: 25px 30px; text-align: center; font-size: 13px; color: #718096; border-top: 1px solid #e2e8f0; }
        .footer-links { margin-top: 15px; }
        .footer-links a { color: #059669; text-decoration: none; margin: 0 8px; }
        @media only screen and (max-width: 600px) {
          .content { padding: 25px 20px; }
        }
      </style>
    </head>
    <body>
      <div class="wrapper">
        <div class="container">
          <div class="header">
            #{if app_logo_url, do: "<div class='logo-container'><img src='#{app_logo_url}' alt='#{app_name}' /></div>", else: ""}
            <h1>🔗 Login dengan Tautan / Log in with Link</h1>
            <p>Akses instan ke akun Anda | Instant access to your account</p>
          </div>

          <div class="content">
            <!-- BAHASA INDONESIA -->
            <div class="greeting">Kepada Yth. #{user.email},</div>
            <div class="message">
              Anda dapat masuk ke akun Anda dengan mengklik tombol di bawah ini. Jika Anda tidak meminta email ini, abaikan email ini.
            </div>

            <div style="text-align: center;">
              <a href="#{url}" class="cta-button">🚀 Masuk Sekarang</a>
            </div>

            <div class="divider"></div>

            <!-- ENGLISH -->
            <div class="greeting">Dear #{user.email},</div>
            <div class="message">
              You can log into your account by clicking the button below. If you didn't request this email, please ignore it.
            </div>

            <div style="text-align: center;">
              <a href="#{url}" class="cta-button">🚀 Login Now</a>
            </div>
          </div>

          <div class="footer">
            <p><strong>Ini adalah pesan otomatis dari Sistem Perpustakaan.</strong><br>
            This is an automated message from the Library System.</p>
            <p>Mohon tidak membalas email ini. | Please do not reply to this email.</p>
            <div class="footer-links">
              <a href="mailto:perpustakaan@unpad.ac.id">📧 Email</a>
              <a href="https://instagram.com/kandagaunpad">📱 Instagram</a>
              <a href="https://wa.me/6282315798979">💬 WhatsApp</a>
            </div>
          </div>
        </div>
      </div>
    </body>
    </html>
    """
  end

  # Loan Reminder Email Templates

  def loan_reminder_html(member, transactions, days_before_due) do
    app_name = System.get_setting_value("app_name", "Voile")
    app_logo_url = System.get_setting_value("app_logo_url", nil)

    """
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <style>
        body { margin: 0; padding: 0; font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background-color: #f5f7fa; }
        .wrapper { width: 100%; background-color: #f5f7fa; padding: 20px 0; }
        .container { max-width: 600px; margin: 0 auto; background-color: #ffffff; border-radius: 12px; overflow: hidden; box-shadow: 0 4px 6px rgba(0,0,0,0.1); }
        .header { background: linear-gradient(135deg, #F59E0B 0%, #F97316 100%); padding: 40px 30px; text-align: center; color: white; }
        .header h1 { margin: 0 0 10px 0; font-size: 28px; font-weight: 700; }
        .header p { margin: 0; font-size: 16px; opacity: 0.95; }
        .logo-container { display: inline-block; margin-bottom: 15px; }
        .logo-container img { height: 50px; width: auto; }
        .content { padding: 40px 30px; }
        .greeting { font-size: 18px; color: #2d3748; margin-bottom: 20px; font-weight: 600; }
        .message { font-size: 15px; line-height: 1.8; color: #4a5568; margin-bottom: 25px; }
        .warning { background: linear-gradient(135deg, #FEF3C7 0%, #FDE68A 100%); border-left: 4px solid #F59E0B; padding: 20px; border-radius: 8px; margin: 25px 0; font-size: 14px; color: #92400E; font-weight: 600; }
        .item { background-color: #f8fafc; margin: 15px 0; padding: 20px; border-left: 4px solid #F59E0B; border-radius: 8px; }
        .item-title { font-weight: 700; color: #1e293b; font-size: 16px; margin-bottom: 8px; }
        .item-code { color: #64748b; font-size: 14px; margin-bottom: 6px; }
        .due-date { color: #DC2626; font-weight: 700; font-size: 15px; }
        .action-list { background-color: #f1f5f9; padding: 20px; border-radius: 8px; margin: 25px 0; }
        .action-list strong { color: #1e293b; display: block; margin-bottom: 12px; font-size: 16px; }
        .action-list ul { margin: 0; padding-left: 20px; color: #475569; line-height: 1.8; }
        .divider { border-top: 2px dashed #cbd5e0; margin: 40px 0; }
        .footer { background-color: #f7fafc; padding: 25px 30px; text-align: center; font-size: 13px; color: #718096; border-top: 1px solid #e2e8f0; }
        .footer-links { margin-top: 15px; }
        .footer-links a { color: #F59E0B; text-decoration: none; margin: 0 8px; }
        @media only screen and (max-width: 600px) {
          .content { padding: 25px 20px; }
        }
      </style>
    </head>
    <body>
      <div class="wrapper">
        <div class="container">
          <div class="header">
            #{if app_logo_url, do: "<div class='logo-container'><img src='#{app_logo_url}' alt='#{app_name}' /></div>", else: ""}
            <h1>⏰ Pengingat Peminjaman / Loan Reminder</h1>
            <p>Jatuh tempo dalam #{days_before_due} hari | Due in #{days_before_due} #{pluralize_day(days_before_due)}</p>
          </div>

          <div class="content">
            <!-- BAHASA INDONESIA -->
            <div class="greeting">Kepada Yth. #{member.fullname || "Anggota"},</div>
            <div class="message">
              Ini adalah pengingat bahwa Anda memiliki <strong>#{length(transactions)}</strong>
              #{if length(transactions) == 1, do: "koleksi", else: "daftar koleksi"} yang akan jatuh tempo dalam
              <strong>#{days_before_due} hari</strong>.
            </div>

            <div class="warning">
              ⚠️ Mohon mengembalikan atau memperpanjang koleksi Anda sebelum tanggal jatuh tempo untuk menghindari denda keterlambatan.
            </div>

            <h3 style="color: #1e293b; margin-bottom: 15px;">Koleksi Anda:</h3>
            #{Enum.map_join(transactions, "\n", &format_transaction_html/1)}

            <div class="action-list">
              <strong>Yang harus dilakukan:</strong>
              <ul>
                <li>Kembalikan koleksi ke perpustakaan sebelum tanggal jatuh tempo</li>
                <li>Atau masuk ke akun Anda untuk meminta perpanjangan</li>
                <li>Hubungi perpustakaan jika Anda memerlukan bantuan</li>
              </ul>
            </div>

            <div class="divider"></div>

            <!-- ENGLISH -->
            <div class="greeting">Dear #{member.fullname || "Member"},</div>
            <div class="message">
              This is a friendly reminder that you have <strong>#{length(transactions)}</strong>
              #{if length(transactions) == 1, do: "item", else: "items"} due in
              <strong>#{days_before_due} #{pluralize_day(days_before_due)}</strong>.
            </div>

            <div class="warning">
              ⚠️ Please return or renew your items before the due date to avoid late fees.
            </div>

            <h3 style="color: #1e293b; margin-bottom: 15px;">Your Items:</h3>
            #{Enum.map_join(transactions, "\n", &format_transaction_html/1)}

            <div class="action-list">
              <strong>What to do:</strong>
              <ul>
                <li>Return the items to the library before the due date</li>
                <li>Or log in to your account to request a renewal</li>
                <li>Contact the library if you need assistance</li>
              </ul>
            </div>
          </div>

          <div class="footer">
            <p><strong>Ini adalah pesan otomatis dari Sistem Perpustakaan.</strong><br>
            This is an automated message from the Library System.</p>
            <p>Mohon tidak membalas email ini. | Please do not reply to this email.</p>
            <div class="footer-links">
              <a href="mailto:perpustakaan@unpad.ac.id">📧 Email</a>
              <a href="https://instagram.com/kandagaunpad">📱 Instagram</a>
              <a href="https://wa.me/6282315798979">💬 WhatsApp</a>
            </div>
          </div>
        </div>
      </div>
    </body>
    </html>
    """
  end

  def loan_reminder_text(member, transactions, days_before_due) do
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

  # Helper functions for loan reminder templates

  defp pluralize_day(1), do: "Day"
  defp pluralize_day(_), do: "Days"

  defp format_transaction_html(%Transaction{} = transaction) do
    transaction = Repo.preload(transaction, [:item, item: [:collection]])
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
    transaction = Repo.preload(transaction, [:item, item: [:collection]])
    due_date_str = Calendar.strftime(transaction.due_date, "%B %d, %Y at %I:%M %p")

    """
    📚 #{get_collection_title(transaction)}
       Item Code: #{get_item_code(transaction)}
       Due Date: #{due_date_str}
    """
  end

  defp get_item_code(%{item: %{item_code: code}}) when not is_nil(code), do: code
  defp get_item_code(_), do: "Unknown"

  defp get_collection_title(%{item: %{collection: %{title: title}}}) when not is_nil(title),
    do: title

  defp get_collection_title(%{item: %{collection: %{title: title}}}) when not is_nil(title),
    do: title

  defp get_collection_title(_), do: "Unknown Collection"

  def overdue_reminder_html(member, transactions) do
    app_name = System.get_setting_value("app_name", "Voile")
    app_logo_url = System.get_setting_value("app_logo_url", nil)

    """
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <style>
        body { margin: 0; padding: 0; font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background-color: #f5f7fa; }
        .wrapper { width: 100%; background-color: #f5f7fa; padding: 20px 0; }
        .container { max-width: 600px; margin: 0 auto; background-color: #ffffff; border-radius: 12px; overflow: hidden; box-shadow: 0 4px 6px rgba(0,0,0,0.1); }
        .header { background: linear-gradient(135deg, #DC2626 0%, #B91C1C 100%); padding: 40px 30px; text-align: center; color: white; }
        .header h1 { margin: 0 0 10px 0; font-size: 28px; font-weight: 700; }
        .header p { margin: 0; font-size: 16px; opacity: 0.95; }
        .logo-container { display: inline-block; margin-bottom: 15px; }
        .logo-container img { height: 50px; width: auto; }
        .content { padding: 40px 30px; }
        .greeting { font-size: 18px; color: #2d3748; margin-bottom: 20px; font-weight: 600; }
        .message { font-size: 15px; line-height: 1.8; color: #4a5568; margin-bottom: 25px; }
        .alert { background: linear-gradient(135deg, #FEE2E2 0%, #FECACA 100%); border-left: 4px solid #DC2626; border: 2px solid #DC2626; padding: 20px; border-radius: 8px; margin: 25px 0; font-size: 14px; color: #7F1D1D; font-weight: 700; }
        .item { background-color: #fef2f2; margin: 15px 0; padding: 20px; border-left: 4px solid #DC2626; border-radius: 8px; }
        .item-title { font-weight: 700; color: #7F1D1D; font-size: 16px; margin-bottom: 8px; }
        .item-code { color: #991B1B; font-size: 14px; margin-bottom: 6px; }
        .overdue { color: #DC2626; font-weight: 700; font-size: 15px; }
        .action-list { background-color: #fef2f2; padding: 20px; border-radius: 8px; margin: 25px 0; border: 1px solid #FCA5A5; }
        .action-list strong { color: #7F1D1D; display: block; margin-bottom: 12px; font-size: 16px; }
        .action-list ul { margin: 0; padding-left: 20px; color: #991B1B; line-height: 1.8; }
        .divider { border-top: 2px dashed #cbd5e0; margin: 40px 0; }
        .footer { background-color: #f7fafc; padding: 25px 30px; text-align: center; font-size: 13px; color: #718096; border-top: 1px solid #e2e8f0; }
        .footer-links { margin-top: 15px; }
        .footer-links a { color: #DC2626; text-decoration: none; margin: 0 8px; }
        @media only screen and (max-width: 600px) {
          .content { padding: 25px 20px; }
        }
      </style>
    </head>
    <body>
      <div class="wrapper">
        <div class="container">
          <div class="header">
            #{if app_logo_url, do: "<div class='logo-container'><img src='#{app_logo_url}' alt='#{app_name}' /></div>", else: ""}
            <h1>🚨 Koleksi Terlambat / Overdue Items</h1>
            <p>Tindakan Segera Diperlukan | Immediate Action Required</p>
          </div>

          <div class="content">
            <!-- BAHASA INDONESIA -->
            <div class="greeting">Kepada Yth. #{member.fullname || "Anggota"},</div>

            <div class="alert">
              <strong>⚠️ MENDESAK:</strong> Anda memiliki #{length(transactions)}
              #{if length(transactions) == 1, do: "koleksi", else: "daftar koleksi"} yang
              TERLAMBAT dikembalikan. Denda keterlambatan mungkin berlaku.
            </div>

            <h3 style="color: #7F1D1D; margin-bottom: 15px;">Koleksi Terlambat:</h3>
            #{Enum.map_join(transactions, "\n", &format_overdue_transaction_html/1)}

            <div class="action-list">
              <strong>Tindakan Segera Diperlukan:</strong>
              <ul>
                <li>Kembalikan koleksi ke perpustakaan sesegera mungkin</li>
                <li>Hubungi perpustakaan untuk menyelesaikan masalah</li>
                <li>Denda keterlambatan terus bertambah pada item ini</li>
              </ul>
            </div>

            <div class="divider"></div>

            <!-- ENGLISH -->
            <div class="greeting">Dear #{member.fullname || "Member"},</div>

            <div class="alert">
              <strong>⚠️ URGENT:</strong> You have #{length(transactions)}
              #{if length(transactions) == 1, do: "item", else: "items"} that
              #{if length(transactions) == 1, do: "is", else: "are"} OVERDUE.
              Late fees may apply.
            </div>

            <h3 style="color: #7F1D1D; margin-bottom: 15px;">Overdue Items:</h3>
            #{Enum.map_join(transactions, "\n", &format_overdue_transaction_html/1)}

            <div class="action-list">
              <strong>Immediate Action Required:</strong>
              <ul>
                <li>Return the items to the library as soon as possible</li>
                <li>Contact the library to resolve any issues</li>
                <li>Late fees are accumulating on these items</li>
              </ul>
            </div>
          </div>

          <div class="footer">
            <p><strong>Ini adalah pesan otomatis dari Sistem Perpustakaan.</strong><br>
            This is an automated message from the Library System.</p>
            <p>Mohon tidak membalas email ini. | Please do not reply to this email.</p>
            <div class="footer-links">
              <a href="mailto:perpustakaan@unpad.ac.id">📧 Email</a>
              <a href="https://instagram.com/kandagaunpad">📱 Instagram</a>
              <a href="https://wa.me/6282315798979">💬 WhatsApp</a>
            </div>
          </div>
        </div>
      </div>
    </body>
    </html>
    """
  end

  def overdue_reminder_text(member, transactions) do
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

  defp format_overdue_transaction_html(%Transaction{} = transaction) do
    transaction = Repo.preload(transaction, [:item, item: [:collection]])
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
    transaction = Repo.preload(transaction, [:item, item: [:collection]])
    due_date_str = Calendar.strftime(transaction.due_date, "%B %d, %Y at %I:%M %p")
    days_overdue = Transaction.days_overdue(transaction)

    """
    📚 #{get_collection_title(transaction)}
       Item Code: #{get_item_code(transaction)}
       Was Due: #{due_date_str}
       ⚠️ Days Overdue: #{days_overdue}
    """
  end

  def manual_reminder_html(member, transactions, earliest_days_until_due) do
    app_name = System.get_setting_value("app_name", "Voile")
    app_logo_url = System.get_setting_value("app_logo_url", nil)

    urgency_message =
      cond do
        earliest_days_until_due == 0 ->
          "koleksi yang jatuh tempo HARI INI / item due TODAY"

        earliest_days_until_due == 1 ->
          "koleksi yang jatuh tempo BESOK / item due TOMORROW"

        earliest_days_until_due <= 3 ->
          "koleksi yang jatuh tempo dalam #{earliest_days_until_due} hari / items due in #{earliest_days_until_due} days"

        true ->
          "koleksi aktif / active items"
      end

    """
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <style>
        body { margin: 0; padding: 0; font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background-color: #f5f7fa; }
        .wrapper { width: 100%; background-color: #f5f7fa; padding: 20px 0; }
        .container { max-width: 600px; margin: 0 auto; background-color: #ffffff; border-radius: 12px; overflow: hidden; box-shadow: 0 4px 6px rgba(0,0,0,0.1); }
        .header { background: linear-gradient(135deg, #7C3AED 0%, #8B5CF6 100%); padding: 40px 30px; text-align: center; color: white; }
        .header h1 { margin: 0 0 10px 0; font-size: 28px; font-weight: 700; }
        .header p { margin: 0; font-size: 16px; opacity: 0.95; }
        .logo-container { display: inline-block; margin-bottom: 15px; }
        .logo-container img { height: 50px; width: auto; }
        .content { padding: 40px 30px; }
        .greeting { font-size: 18px; color: #2d3748; margin-bottom: 20px; font-weight: 600; }
        .message { font-size: 15px; line-height: 1.8; color: #4a5568; margin-bottom: 25px; }
        .info { background: linear-gradient(135deg, #DBEAFE 0%, #BFDBFE 100%); border-left: 4px solid #3B82F6; padding: 20px; border-radius: 8px; margin: 25px 0; font-size: 14px; color: #1E3A8A; font-weight: 600; }
        .urgent-badge { background: linear-gradient(135deg, #FEE2E2 0%, #FECACA 100%); color: #7F1D1D; padding: 15px 20px; border-radius: 8px; font-weight: 700; margin: 20px 0; text-align: center; border: 2px solid #DC2626; }
        .item { background-color: #f8fafc; margin: 15px 0; padding: 20px; border-left: 4px solid #7C3AED; border-radius: 8px; }
        .item-title { font-weight: 700; color: #1e293b; font-size: 16px; margin-bottom: 8px; }
        .item-code { color: #64748b; font-size: 14px; margin-bottom: 6px; }
        .due-date { color: #DC2626; font-weight: 700; font-size: 15px; }
        .action-list { background-color: #f1f5f9; padding: 20px; border-radius: 8px; margin: 25px 0; }
        .action-list strong { color: #1e293b; display: block; margin-bottom: 12px; font-size: 16px; }
        .action-list ul { margin: 0; padding-left: 20px; color: #475569; line-height: 1.8; }
        .divider { border-top: 2px dashed #cbd5e0; margin: 40px 0; }
        .footer { background-color: #f7fafc; padding: 25px 30px; text-align: center; font-size: 13px; color: #718096; border-top: 1px solid #e2e8f0; }
        .footer-links { margin-top: 15px; }
        .footer-links a { color: #7C3AED; text-decoration: none; margin: 0 8px; }
        @media only screen and (max-width: 600px) {
          .content { padding: 25px 20px; }
        }
      </style>
    </head>
    <body>
      <div class="wrapper">
        <div class="container">
          <div class="header">
            #{if app_logo_url, do: "<div class='logo-container'><img src='#{app_logo_url}' alt='#{app_name}' /></div>", else: ""}
            <h1>👋 Pengingat dari Pustakawan / Librarian Reminder</h1>
            <p>Pesan penting mengenai pinjaman Anda | Important message about your loans</p>
          </div>

          <div class="content">
            <!-- BAHASA INDONESIA -->
            <div class="greeting">Kepada Yth. #{member.fullname || "Anggota"},</div>
            <div class="message">
              Pustakawan kami telah mengirimkan pengingat mengenai peminjaman Anda.
              Anda memiliki <strong>#{length(transactions)}</strong>
              #{if length(transactions) == 1, do: "koleksi aktif", else: "koleksi aktif"}.
            </div>

            #{if earliest_days_until_due <= 3 do
      """
      <div class="urgent-badge">
        ⚠️ Koleksi paling cepat jatuh tempo: #{urgency_message}
      </div>
      """
    end}

            <div class="info">
              ℹ️ Ini adalah pengingat manual dari staf perpustakaan. Mohon periksa status peminjaman Anda.
            </div>

            <h3 style="color: #1e293b; margin-bottom: 15px;">Koleksi Pinjaman Anda:</h3>
            #{Enum.map_join(transactions, "\n", &format_transaction_html/1)}

            <div class="action-list">
              <strong>Silakan:</strong>
              <ul>
                <li>Periksa tanggal jatuh tempo setiap koleksi</li>
                <li>Kembalikan koleksi yang sudah jatuh tempo atau akan jatuh tempo segera</li>
                <li>Hubungi perpustakaan jika Anda memiliki pertanyaan</li>
                <li>Perpanjang peminjaman jika memungkinkan</li>
              </ul>
            </div>

            <div class="divider"></div>

            <!-- ENGLISH -->
            <div class="greeting">Dear #{member.fullname || "Member"},</div>
            <div class="message">
              Our librarian has sent you a reminder about your loans.
              You have <strong>#{length(transactions)}</strong>
              active #{if length(transactions) == 1, do: "item", else: "items"}.
            </div>

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

            <h3 style="color: #1e293b; margin-bottom: 15px;">Your Borrowed Items:</h3>
            #{Enum.map_join(transactions, "\n", &format_transaction_html/1)}

            <div class="action-list">
              <strong>Please:</strong>
              <ul>
                <li>Check the due date for each item</li>
                <li>Return items that are overdue or due soon</li>
                <li>Contact the library if you have any questions</li>
                <li>Renew loans if possible</li>
              </ul>
            </div>
          </div>

          <div class="footer">
            <p><strong>Pengingat manual dari Perpustakaan.</strong><br>
            Manual reminder from the Library.</p>
            <div class="footer-links">
              <a href="mailto:perpustakaan@unpad.ac.id">📧 Email</a>
              <a href="https://instagram.com/kandagaunpad">📱 Instagram</a>
              <a href="https://wa.me/6282315798979">💬 WhatsApp</a>
            </div>
          </div>
        </div>
      </div>
    </body>
    </html>
    """
  end

  def manual_reminder_text(member, transactions, earliest_days_until_due) do
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
    - Periksa tanggal jatuh tempo setiap koleksi
    - Kembalikan koleksi yang sudah jatuh tempo atau akan jatuh tempo segera
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

  # ===========================================================================
  # STOCK OPNAME EMAIL TEMPLATES
  # ===========================================================================

  @doc """
  Email template when stock opname session is started and librarians are assigned.
  """
  def stock_opname_session_started(session, librarian) do
    app_name = System.get_setting_value("app_name", "Voile")
    app_logo_url = System.get_setting_value("app_logo_url", nil)
    session_url = VoileWeb.Endpoint.url() <> "/manage/stock_opname/#{session.id}"

    """
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <style>
        body { margin: 0; padding: 0; font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background-color: #f5f7fa; }
        .wrapper { width: 100%; background-color: #f5f7fa; padding: 20px 0; }
        .container { max-width: 600px; margin: 0 auto; background-color: #ffffff; border-radius: 12px; overflow: hidden; box-shadow: 0 4px 6px rgba(0,0,0,0.1); }
        .header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); padding: 40px 30px; text-align: center; color: white; }
        .header h1 { margin: 0 0 10px 0; font-size: 28px; font-weight: 700; }
        .header p { margin: 0; font-size: 16px; opacity: 0.95; }
        .logo-container { display: inline-block; margin-bottom: 15px; }
        .logo-container img { height: 50px; width: auto; }
        .content { padding: 40px 30px; }
        .greeting { font-size: 18px; color: #2d3748; margin-bottom: 20px; font-weight: 600; }
        .message { font-size: 15px; line-height: 1.8; color: #4a5568; margin-bottom: 25px; }
        .info-card { background: linear-gradient(135deg, #667eea15 0%, #764ba215 100%); border-left: 4px solid #667eea; padding: 20px; border-radius: 8px; margin: 25px 0; }
        .info-row { display: flex; padding: 10px 0; border-bottom: 1px solid #e2e8f0; }
        .info-row:last-child { border-bottom: none; }
        .info-label { font-weight: 700; color: #4a5568; min-width: 140px; font-size: 14px; }
        .info-value { color: #2d3748; font-size: 14px; }
        .session-code { font-family: 'Courier New', monospace; background-color: #edf2f7; padding: 4px 12px; border-radius: 6px; font-weight: 700; color: #667eea; font-size: 16px; }
        .cta-button { display: inline-block; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; text-decoration: none; padding: 14px 32px; border-radius: 8px; font-weight: 600; font-size: 16px; margin: 25px 0; box-shadow: 0 4px 6px rgba(102,126,234,0.3); }
        .cta-button:hover { box-shadow: 0 6px 12px rgba(102,126,234,0.4); }
        .divider { border-top: 2px dashed #cbd5e0; margin: 40px 0; }
        .footer { background-color: #f7fafc; padding: 25px 30px; text-align: center; font-size: 13px; color: #718096; border-top: 1px solid #e2e8f0; }
        .footer-links { margin-top: 15px; }
        .footer-links a { color: #667eea; text-decoration: none; margin: 0 8px; }
        @media only screen and (max-width: 600px) {
          .content { padding: 25px 20px; }
          .info-row { flex-direction: column; }
          .info-label { margin-bottom: 5px; }
        }
      </style>
    </head>
    <body>
      <div class="wrapper">
        <div class="container">
          <div class="header">
            #{if app_logo_url, do: "<div class='logo-container'><img src='#{app_logo_url}' alt='#{app_name}' /></div>", else: ""}
            <h1>📦 Stock Opname Started</h1>
            <p>Sesi Stock Opname Dimulai</p>
          </div>

          <div class="content">
            <!-- BAHASA INDONESIA -->
            <div class="greeting">Kepada Yth. #{librarian.fullname || librarian.email},</div>
            <div class="message">
              Anda telah ditugaskan untuk melakukan stock opname (inventarisasi koleksi). Silakan masuk ke sistem untuk mulai memeriksa koleksi yang telah ditugaskan kepada Anda.
            </div>

            <div class="info-card">
              <div class="info-row">
                <div class="info-label">Kode Sesi:</div>
                <div class="info-value"><span class="session-code">#{session.session_code}</span></div>
              </div>
              <div class="info-row">
                <div class="info-label">Judul:</div>
                <div class="info-value">#{session.title}</div>
              </div>
              <div class="info-row">
                <div class="info-label">Total Koleksi:</div>
                <div class="info-value"><strong>#{session.total_items}</strong> items</div>
              </div>
            </div>

            <div style="text-align: center;">
              <a href="#{session_url}" class="cta-button">🔍 Lihat Detail Sesi</a>
            </div>

            <div class="divider"></div>

            <!-- ENGLISH -->
            <div class="greeting">Dear #{librarian.fullname || librarian.email},</div>
            <div class="message">
              You have been assigned to a stock opname session. Please log in to the system to start checking the items assigned to you.
            </div>

            <div class="info-card">
              <div class="info-row">
                <div class="info-label">Session Code:</div>
                <div class="info-value"><span class="session-code">#{session.session_code}</span></div>
              </div>
              <div class="info-row">
                <div class="info-label">Title:</div>
                <div class="info-value">#{session.title}</div>
              </div>
              <div class="info-row">
                <div class="info-label">Total Items:</div>
                <div class="info-value"><strong>#{session.total_items}</strong> items</div>
              </div>
            </div>

            <div style="text-align: center;">
              <a href="#{session_url}" class="cta-button">🔍 View Session Details</a>
            </div>
          </div>

          <div class="footer">
            <p><strong>Ini adalah pesan otomatis dari Sistem Perpustakaan.</strong><br>
            This is an automated message from the Library System.</p>
            <p>Mohon tidak membalas email ini. | Please do not reply to this email.</p>
            <div class="footer-links">
              <a href="mailto:perpustakaan@unpad.ac.id">📧 Email</a>
              <a href="https://instagram.com/kandagaunpad">📱 Instagram</a>
              <a href="https://wa.me/6282315798979">💬 WhatsApp</a>
            </div>
          </div>
        </div>
      </div>
    </body>
    </html>
    """
  end

  @doc """
  Email template when a librarian completes their work on a stock opname session.
  """
  def stock_opname_librarian_completed(session, librarian, assignment) do
    app_name = System.get_setting_value("app_name", "Voile")
    app_logo_url = System.get_setting_value("app_logo_url", nil)
    session_url = VoileWeb.Endpoint.url() <> "/manage/stock_opname/#{session.id}"

    """
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <style>
        body { margin: 0; padding: 0; font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background-color: #f5f7fa; }
        .wrapper { width: 100%; background-color: #f5f7fa; padding: 20px 0; }
        .container { max-width: 600px; margin: 0 auto; background-color: #ffffff; border-radius: 12px; overflow: hidden; box-shadow: 0 4px 6px rgba(0,0,0,0.1); }
        .header { background: linear-gradient(135deg, #10b981 0%, #059669 100%); padding: 40px 30px; text-align: center; color: white; }
        .header h1 { margin: 0 0 10px 0; font-size: 28px; font-weight: 700; }
        .header p { margin: 0; font-size: 16px; opacity: 0.95; }
        .logo-container { display: inline-block; margin-bottom: 15px; }
        .logo-container img { height: 50px; width: auto; }
        .content { padding: 40px 30px; }
        .greeting { font-size: 18px; color: #2d3748; margin-bottom: 20px; font-weight: 600; }
        .message { font-size: 15px; line-height: 1.8; color: #4a5568; margin-bottom: 25px; }
        .info-card { background: linear-gradient(135deg, #10b98115 0%, #05966915 100%); border-left: 4px solid #10b981; padding: 20px; border-radius: 8px; margin: 25px 0; }
        .info-row { display: flex; padding: 10px 0; border-bottom: 1px solid #e2e8f0; }
        .info-row:last-child { border-bottom: none; }
        .info-label { font-weight: 700; color: #4a5568; min-width: 140px; font-size: 14px; }
        .info-value { color: #2d3748; font-size: 14px; }
        .highlight-box { background-color: #d1fae5; border: 2px solid #10b981; padding: 20px; border-radius: 8px; text-align: center; margin: 25px 0; }
        .highlight-number { font-size: 36px; font-weight: 700; color: #059669; margin-bottom: 5px; }
        .highlight-label { font-size: 14px; color: #047857; font-weight: 600; text-transform: uppercase; }
        .cta-button { display: inline-block; background: linear-gradient(135deg, #10b981 0%, #059669 100%); color: white; text-decoration: none; padding: 14px 32px; border-radius: 8px; font-weight: 600; font-size: 16px; margin: 25px 0; box-shadow: 0 4px 6px rgba(16,185,129,0.3); }
        .divider { border-top: 2px dashed #cbd5e0; margin: 40px 0; }
        .footer { background-color: #f7fafc; padding: 25px 30px; text-align: center; font-size: 13px; color: #718096; border-top: 1px solid #e2e8f0; }
        .footer-links { margin-top: 15px; }
        .footer-links a { color: #10b981; text-decoration: none; margin: 0 8px; }
      </style>
    </head>
    <body>
      <div class="wrapper">
        <div class="container">
          <div class="header">
            #{if app_logo_url, do: "<div class='logo-container'><img src='#{app_logo_url}' alt='#{app_name}' /></div>", else: ""}
            <h1>✅ Librarian Work Completed</h1>
            <p>Pustakawan Selesai Bekerja</p>
          </div>

          <div class="content">
            <!-- BAHASA INDONESIA -->
            <div class="greeting">Kepada Administrator,</div>
            <div class="message">
              <strong>#{librarian.fullname || librarian.email}</strong> telah menyelesaikan pekerjaan mereka pada sesi stock opname berikut:
            </div>

            <div class="info-card">
              <div class="info-row">
                <div class="info-label">Sesi:</div>
                <div class="info-value"><strong>#{session.title}</strong></div>
              </div>
              <div class="info-row">
                <div class="info-label">Kode Sesi:</div>
                <div class="info-value">#{session.session_code}</div>
              </div>
            </div>

            <div class="highlight-box">
              <div class="highlight-number">#{assignment.items_checked}</div>
              <div class="highlight-label">Koleksi Diperiksa | Items Checked</div>
            </div>

            <div style="text-align: center;">
              <a href="#{session_url}" class="cta-button">📊 Lihat Detail Sesi</a>
            </div>

            <div class="divider"></div>

            <!-- ENGLISH -->
            <div class="greeting">Dear Administrator,</div>
            <div class="message">
              <strong>#{librarian.fullname || librarian.email}</strong> has completed their work on the following stock opname session:
            </div>

            <div class="info-card">
              <div class="info-row">
                <div class="info-label">Session:</div>
                <div class="info-value"><strong>#{session.title}</strong></div>
              </div>
              <div class="info-row">
                <div class="info-label">Session Code:</div>
                <div class="info-value">#{session.session_code}</div>
              </div>
            </div>

            <div style="text-align: center;">
              <a href="#{session_url}" class="cta-button">📊 View Session Details</a>
            </div>
          </div>

          <div class="footer">
            <p><strong>Ini adalah pesan otomatis dari Sistem Perpustakaan.</strong><br>
            This is an automated message from the Library System.</p>
            <p>Mohon tidak membalas email ini. | Please do not reply to this email.</p>
            <div class="footer-links">
              <a href="mailto:perpustakaan@unpad.ac.id">📧 Email</a>
              <a href="https://instagram.com/kandagaunpad">📱 Instagram</a>
              <a href="https://wa.me/6282315798979">💬 WhatsApp</a>
            </div>
          </div>
        </div>
      </div>
    </body>
    </html>
    """
  end

  @doc """
  Email template when stock opname session is completed and ready for review.
  """
  def stock_opname_session_completed(session) do
    app_name = System.get_setting_value("app_name", "Voile")
    app_logo_url = System.get_setting_value("app_logo_url", nil)
    review_url = VoileWeb.Endpoint.url() <> "/manage/stock_opname/#{session.id}/review"

    """
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <style>
        body { margin: 0; padding: 0; font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background-color: #f5f7fa; }
        .wrapper { width: 100%; background-color: #f5f7fa; padding: 20px 0; }
        .container { max-width: 600px; margin: 0 auto; background-color: #ffffff; border-radius: 12px; overflow: hidden; box-shadow: 0 4px 6px rgba(0,0,0,0.1); }
        .header { background: linear-gradient(135deg, #f59e0b 0%, #d97706 100%); padding: 40px 30px; text-align: center; color: white; }
        .header h1 { margin: 0 0 10px 0; font-size: 28px; font-weight: 700; }
        .header p { margin: 0; font-size: 16px; opacity: 0.95; }
        .logo-container { display: inline-block; margin-bottom: 15px; }
        .logo-container img { height: 50px; width: auto; }
        .content { padding: 40px 30px; }
        .greeting { font-size: 18px; color: #2d3748; margin-bottom: 20px; font-weight: 600; }
        .message { font-size: 15px; line-height: 1.8; color: #4a5568; margin-bottom: 25px; }
        .stats-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 15px; margin: 25px 0; }
        .stat-box { background: linear-gradient(135deg, #eff6ff 0%, #dbeafe 100%); padding: 20px; border-radius: 8px; text-align: center; border: 1px solid #bfdbfe; }
        .stat-box.warning { background: linear-gradient(135deg, #fef3c7 0%, #fde68a 100%); border-color: #fcd34d; }
        .stat-box.danger { background: linear-gradient(135deg, #fee2e2 0%, #fecaca 100%); border-color: #fca5a5; }
        .stat-number { font-size: 32px; font-weight: 700; color: #1e40af; margin-bottom: 5px; }
        .stat-box.warning .stat-number { color: #b45309; }
        .stat-box.danger .stat-number { color: #dc2626; }
        .stat-label { font-size: 12px; color: #4b5563; font-weight: 600; text-transform: uppercase; }
        .info-card { background: linear-gradient(135deg, #f59e0b15 0%, #d9770615 100%); border-left: 4px solid #f59e0b; padding: 20px; border-radius: 8px; margin: 25px 0; }
        .info-row { display: flex; padding: 10px 0; border-bottom: 1px solid #e2e8f0; }
        .info-row:last-child { border-bottom: none; }
        .info-label { font-weight: 700; color: #4a5568; min-width: 140px; font-size: 14px; }
        .info-value { color: #2d3748; font-size: 14px; }
        .cta-button { display: inline-block; background: linear-gradient(135deg, #f59e0b 0%, #d97706 100%); color: white; text-decoration: none; padding: 16px 36px; border-radius: 8px; font-weight: 700; font-size: 17px; margin: 25px 0; box-shadow: 0 4px 6px rgba(245,158,11,0.3); text-transform: uppercase; letter-spacing: 0.5px; }
        .divider { border-top: 2px dashed #cbd5e0; margin: 40px 0; }
        .footer { background-color: #f7fafc; padding: 25px 30px; text-align: center; font-size: 13px; color: #718096; border-top: 1px solid #e2e8f0; }
        .footer-links { margin-top: 15px; }
        .footer-links a { color: #f59e0b; text-decoration: none; margin: 0 8px; }
        @media only screen and (max-width: 600px) {
          .stats-grid { grid-template-columns: 1fr; }
        }
      </style>
    </head>
    <body>
      <div class="wrapper">
        <div class="container">
          <div class="header">
            #{if app_logo_url, do: "<div class='logo-container'><img src='#{app_logo_url}' alt='#{app_name}' /></div>", else: ""}
            <h1>📋 Ready for Review</h1>
            <p>Siap untuk Ditinjau</p>
          </div>

          <div class="content">
            <!-- BAHASA INDONESIA -->
            <div class="greeting">Kepada Administrator,</div>
            <div class="message">
              Sesi stock opname <strong>#{session.title}</strong> (#{session.session_code}) telah selesai dan siap untuk ditinjau dan disetujui.
            </div>

            <div class="info-card">
              <div class="info-row">
                <div class="info-label">Judul Sesi:</div>
                <div class="info-value"><strong>#{session.title}</strong></div>
              </div>
              <div class="info-row">
                <div class="info-label">Kode Sesi:</div>
                <div class="info-value">#{session.session_code}</div>
              </div>
            </div>

            <div style="text-align: center; margin: 30px 0 20px 0;">
              <h3 style="color: #4a5568; margin-bottom: 20px;">📊 Ringkasan Hasil</h3>
            </div>

            <div class="stats-grid">
              <div class="stat-box">
                <div class="stat-number">#{session.total_items}</div>
                <div class="stat-label">Total Koleksi</div>
              </div>
              <div class="stat-box">
                <div class="stat-number">#{session.checked_items}</div>
                <div class="stat-label">Diperiksa</div>
              </div>
              <div class="stat-box danger">
                <div class="stat-number">#{session.missing_items}</div>
                <div class="stat-label">Hilang</div>
              </div>
              <div class="stat-box warning">
                <div class="stat-number">#{session.items_with_changes}</div>
                <div class="stat-label">Ada Perubahan</div>
              </div>
            </div>

            <div style="text-align: center;">
              <a href="#{review_url}" class="cta-button">✔️ Tinjau & Setujui</a>
            </div>

            <div class="divider"></div>

            <!-- ENGLISH -->
            <div class="greeting">Dear Administrator,</div>
            <div class="message">
              The stock opname session <strong>#{session.title}</strong> (#{session.session_code}) has been completed and is ready for your review and approval.
            </div>

            <div style="text-align: center; margin: 30px 0 20px 0;">
              <h3 style="color: #4a5568; margin-bottom: 20px;">📊 Summary Results</h3>
            </div>

            <div class="stats-grid">
              <div class="stat-box">
                <div class="stat-number">#{session.total_items}</div>
                <div class="stat-label">Total Items</div>
              </div>
              <div class="stat-box">
                <div class="stat-number">#{session.checked_items}</div>
                <div class="stat-label">Checked</div>
              </div>
              <div class="stat-box danger">
                <div class="stat-number">#{session.missing_items}</div>
                <div class="stat-label">Missing</div>
              </div>
              <div class="stat-box warning">
                <div class="stat-number">#{session.items_with_changes}</div>
                <div class="stat-label">With Changes</div>
              </div>
            </div>

            <div style="text-align: center;">
              <a href="#{review_url}" class="cta-button">✔️ Review & Approve</a>
            </div>
          </div>

          <div class="footer">
            <p><strong>Ini adalah pesan otomatis dari Sistem Perpustakaan.</strong><br>
            This is an automated message from the Library System.</p>
            <p>Mohon tidak membalas email ini. | Please do not reply to this email.</p>
            <div class="footer-links">
              <a href="mailto:perpustakaan@unpad.ac.id">📧 Email</a>
              <a href="https://instagram.com/kandagaunpad">📱 Instagram</a>
              <a href="https://wa.me/6282315798979">💬 WhatsApp</a>
            </div>
          </div>
        </div>
      </div>
    </body>
    </html>
    """
  end

  @doc """
  Email template when stock opname session is approved.
  """
  def stock_opname_session_approved(session, librarian) do
    app_name = System.get_setting_value("app_name", "Voile")
    app_logo_url = System.get_setting_value("app_logo_url", nil)
    session_url = VoileWeb.Endpoint.url() <> "/manage/stock_opname/#{session.id}"

    """
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <style>
        body { margin: 0; padding: 0; font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background-color: #f5f7fa; }
        .wrapper { width: 100%; background-color: #f5f7fa; padding: 20px 0; }
        .container { max-width: 600px; margin: 0 auto; background-color: #ffffff; border-radius: 12px; overflow: hidden; box-shadow: 0 4px 6px rgba(0,0,0,0.1); }
        .header { background: linear-gradient(135deg, #10b981 0%, #059669 100%); padding: 40px 30px; text-align: center; color: white; }
        .header h1 { margin: 0 0 10px 0; font-size: 28px; font-weight: 700; }
        .header p { margin: 0; font-size: 16px; opacity: 0.95; }
        .logo-container { display: inline-block; margin-bottom: 15px; }
        .logo-container img { height: 50px; width: auto; }
        .content { padding: 40px 30px; }
        .greeting { font-size: 18px; color: #2d3748; margin-bottom: 20px; font-weight: 600; }
        .message { font-size: 15px; line-height: 1.8; color: #4a5568; margin-bottom: 25px; }
        .success-badge { background: linear-gradient(135deg, #d1fae5 0%, #a7f3d0 100%); border: 3px solid #10b981; padding: 25px; border-radius: 12px; text-align: center; margin: 30px 0; }
        .success-icon { font-size: 64px; margin-bottom: 15px; }
        .success-title { font-size: 24px; font-weight: 700; color: #047857; margin-bottom: 10px; }
        .success-message { font-size: 15px; color: #065f46; }
        .info-card { background: linear-gradient(135deg, #10b98115 0%, #05966915 100%); border-left: 4px solid #10b981; padding: 20px; border-radius: 8px; margin: 25px 0; }
        .info-row { display: flex; padding: 10px 0; border-bottom: 1px solid #e2e8f0; }
        .info-row:last-child { border-bottom: none; }
        .info-label { font-weight: 700; color: #4a5568; min-width: 140px; font-size: 14px; }
        .info-value { color: #2d3748; font-size: 14px; }
        .cta-button { display: inline-block; background: linear-gradient(135deg, #10b981 0%, #059669 100%); color: white; text-decoration: none; padding: 14px 32px; border-radius: 8px; font-weight: 600; font-size: 16px; margin: 25px 0; box-shadow: 0 4px 6px rgba(16,185,129,0.3); }
        .divider { border-top: 2px dashed #cbd5e0; margin: 40px 0; }
        .footer { background-color: #f7fafc; padding: 25px 30px; text-align: center; font-size: 13px; color: #718096; border-top: 1px solid #e2e8f0; }
        .footer-links { margin-top: 15px; }
        .footer-links a { color: #10b981; text-decoration: none; margin: 0 8px; }
      </style>
    </head>
    <body>
      <div class="wrapper">
        <div class="container">
          <div class="header">
            #{if app_logo_url, do: "<div class='logo-container'><img src='#{app_logo_url}' alt='#{app_name}' /></div>", else: ""}
            <h1>🎉 Session Approved</h1>
            <p>Sesi Disetujui</p>
          </div>

          <div class="content">
            <!-- BAHASA INDONESIA -->
            <div class="greeting">Kepada Yth. #{librarian.fullname || librarian.email},</div>

            <div class="success-badge">
              <div class="success-icon">✅</div>
              <div class="success-title">Selamat!</div>
              <div class="success-message">Sesi stock opname Anda telah disetujui</div>
            </div>

            <div class="message">
              Sesi stock opname <strong>#{session.title}</strong> (#{session.session_code}) telah ditinjau dan disetujui. Semua perubahan telah diterapkan ke sistem.
            </div>

            <div class="info-card">
              <div class="info-row">
                <div class="info-label">Judul Sesi:</div>
                <div class="info-value"><strong>#{session.title}</strong></div>
              </div>
              <div class="info-row">
                <div class="info-label">Kode Sesi:</div>
                <div class="info-value">#{session.session_code}</div>
              </div>
              <div class="info-row">
                <div class="info-label">Status:</div>
                <div class="info-value"><strong style="color: #10b981;">✓ Disetujui</strong></div>
              </div>
            </div>

            <div style="text-align: center;">
              <a href="#{session_url}" class="cta-button">📄 Lihat Detail Sesi</a>
            </div>

            <div class="divider"></div>

            <!-- ENGLISH -->
            <div class="greeting">Dear #{librarian.fullname || librarian.email},</div>

            <div class="success-badge">
              <div class="success-icon">✅</div>
              <div class="success-title">Congratulations!</div>
              <div class="success-message">Your stock opname session has been approved</div>
            </div>

            <div class="message">
              The stock opname session <strong>#{session.title}</strong> (#{session.session_code}) has been reviewed and approved. All changes have been applied to the system.
            </div>

            <div class="info-card">
              <div class="info-row">
                <div class="info-label">Session Title:</div>
                <div class="info-value"><strong>#{session.title}</strong></div>
              </div>
              <div class="info-row">
                <div class="info-label">Session Code:</div>
                <div class="info-value">#{session.session_code}</div>
              </div>
              <div class="info-row">
                <div class="info-label">Status:</div>
                <div class="info-value"><strong style="color: #10b981;">✓ Approved</strong></div>
              </div>
            </div>

            <div style="text-align: center;">
              <a href="#{session_url}" class="cta-button">📄 View Session Details</a>
            </div>
          </div>

          <div class="footer">
            <p><strong>Ini adalah pesan otomatis dari Sistem Perpustakaan.</strong><br>
            This is an automated message from the Library System.</p>
            <p>Mohon tidak membalas email ini. | Please do not reply to this email.</p>
            <div class="footer-links">
              <a href="mailto:perpustakaan@unpad.ac.id">📧 Email</a>
              <a href="https://instagram.com/kandagaunpad">📱 Instagram</a>
              <a href="https://wa.me/6282315798979">💬 WhatsApp</a>
            </div>
          </div>
        </div>
      </div>
    </body>
    </html>
    """
  end

  @doc """
  Email template when stock opname session is rejected.
  """
  def stock_opname_session_rejected(session, librarian, reason) do
    app_name = System.get_setting_value("app_name", "Voile")
    app_logo_url = System.get_setting_value("app_logo_url", nil)
    session_url = VoileWeb.Endpoint.url() <> "/manage/stock_opname/#{session.id}"

    """
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <style>
        body { margin: 0; padding: 0; font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background-color: #f5f7fa; }
        .wrapper { width: 100%; background-color: #f5f7fa; padding: 20px 0; }
        .container { max-width: 600px; margin: 0 auto; background-color: #ffffff; border-radius: 12px; overflow: hidden; box-shadow: 0 4px 6px rgba(0,0,0,0.1); }
        .header { background: linear-gradient(135deg, #ef4444 0%, #dc2626 100%); padding: 40px 30px; text-align: center; color: white; }
        .header h1 { margin: 0 0 10px 0; font-size: 28px; font-weight: 700; }
        .header p { margin: 0; font-size: 16px; opacity: 0.95; }
        .logo-container { display: inline-block; margin-bottom: 15px; }
        .logo-container img { height: 50px; width: auto; }
        .content { padding: 40px 30px; }
        .greeting { font-size: 18px; color: #2d3748; margin-bottom: 20px; font-weight: 600; }
        .message { font-size: 15px; line-height: 1.8; color: #4a5568; margin-bottom: 25px; }
        .alert-badge { background: linear-gradient(135deg, #fee2e2 0%, #fecaca 100%); border: 3px solid #ef4444; padding: 25px; border-radius: 12px; text-align: center; margin: 30px 0; }
        .alert-icon { font-size: 64px; margin-bottom: 15px; }
        .alert-title { font-size: 24px; font-weight: 700; color: #dc2626; margin-bottom: 10px; }
        .alert-message { font-size: 15px; color: #991b1b; }
        .info-card { background: linear-gradient(135deg, #ef444415 0%, #dc262615 100%); border-left: 4px solid #ef4444; padding: 20px; border-radius: 8px; margin: 25px 0; }
        .info-row { display: flex; padding: 10px 0; border-bottom: 1px solid #e2e8f0; }
        .info-row:last-child { border-bottom: none; }
        .info-label { font-weight: 700; color: #4a5568; min-width: 140px; font-size: 14px; }
        .info-value { color: #2d3748; font-size: 14px; }
        .reason-box { background-color: #fef2f2; border: 2px solid #fca5a5; padding: 20px; border-radius: 8px; margin: 25px 0; }
        .reason-title { font-weight: 700; color: #dc2626; margin-bottom: 10px; font-size: 16px; }
        .reason-text { color: #991b1b; line-height: 1.8; white-space: pre-wrap; }
        .cta-button { display: inline-block; background: linear-gradient(135deg, #ef4444 0%, #dc2626 100%); color: white; text-decoration: none; padding: 14px 32px; border-radius: 8px; font-weight: 600; font-size: 16px; margin: 25px 0; box-shadow: 0 4px 6px rgba(239,68,68,0.3); }
        .divider { border-top: 2px dashed #cbd5e0; margin: 40px 0; }
        .footer { background-color: #f7fafc; padding: 25px 30px; text-align: center; font-size: 13px; color: #718096; border-top: 1px solid #e2e8f0; }
        .footer-links { margin-top: 15px; }
        .footer-links a { color: #ef4444; text-decoration: none; margin: 0 8px; }
      </style>
    </head>
    <body>
      <div class="wrapper">
        <div class="container">
          <div class="header">
            #{if app_logo_url, do: "<div class='logo-container'><img src='#{app_logo_url}' alt='#{app_name}' /></div>", else: ""}
            <h1>❌ Session Rejected</h1>
            <p>Sesi Ditolak</p>
          </div>

          <div class="content">
            <!-- BAHASA INDONESIA -->
            <div class="greeting">Kepada Yth. #{librarian.fullname || librarian.email},</div>

            <div class="alert-badge">
              <div class="alert-icon">⚠️</div>
              <div class="alert-title">Sesi Ditolak</div>
              <div class="alert-message">Sesi stock opname memerlukan perhatian</div>
            </div>

            <div class="message">
              Sesi stock opname <strong>#{session.title}</strong> (#{session.session_code}) telah ditinjau dan ditolak oleh administrator.
            </div>

            <div class="reason-box">
              <div class="reason-title">📝 Alasan Penolakan / Rejection Reason:</div>
              <div class="reason-text">#{reason}</div>
            </div>

            <div class="info-card">
              <div class="info-row">
                <div class="info-label">Judul Sesi:</div>
                <div class="info-value"><strong>#{session.title}</strong></div>
              </div>
              <div class="info-row">
                <div class="info-label">Kode Sesi:</div>
                <div class="info-value">#{session.session_code}</div>
              </div>
              <div class="info-row">
                <div class="info-label">Status:</div>
                <div class="info-value"><strong style="color: #ef4444;">✗ Ditolak</strong></div>
              </div>
            </div>

            <div class="message">
              Silakan hubungi administrator untuk informasi lebih lanjut.
            </div>

            <div style="text-align: center;">
              <a href="#{session_url}" class="cta-button">📄 Lihat Detail Sesi</a>
            </div>

            <div class="divider"></div>

            <!-- ENGLISH -->
            <div class="greeting">Dear #{librarian.fullname || librarian.email},</div>

            <div class="alert-badge">
              <div class="alert-icon">⚠️</div>
              <div class="alert-title">Session Rejected</div>
              <div class="alert-message">Stock opname session requires attention</div>
            </div>

            <div class="message">
              The stock opname session <strong>#{session.title}</strong> (#{session.session_code}) has been reviewed and rejected by the administrator.
            </div>

            <div class="message">
              Please contact the administrator for more information.
            </div>

            <div style="text-align: center;">
              <a href="#{session_url}" class="cta-button">📄 View Session Details</a>
            </div>
          </div>

          <div class="footer">
            <p><strong>Ini adalah pesan otomatis dari Sistem Perpustakaan.</strong><br>
            This is an automated message from the Library System.</p>
            <p>Mohon tidak membalas email ini. | Please do not reply to this email.</p>
            <div class="footer-links">
              <a href="mailto:perpustakaan@unpad.ac.id">📧 Email</a>
              <a href="https://instagram.com/kandagaunpad">📱 Instagram</a>
              <a href="https://wa.me/6282315798979">💬 WhatsApp</a>
            </div>
          </div>
        </div>
      </div>
    </body>
    </html>
    """
  end

  @doc """
  Email template when revision is requested for a stock opname session.
  """
  def stock_opname_revision_requested(session, librarian, notes) do
    app_name = System.get_setting_value("app_name", "Voile")
    app_logo_url = System.get_setting_value("app_logo_url", nil)
    session_url = VoileWeb.Endpoint.url() <> "/manage/stock_opname/#{session.id}/scan"

    """
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <style>
        body { margin: 0; padding: 0; font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background-color: #f5f7fa; }
        .wrapper { width: 100%; background-color: #f5f7fa; padding: 20px 0; }
        .container { max-width: 600px; margin: 0 auto; background-color: #ffffff; border-radius: 12px; overflow: hidden; box-shadow: 0 4px 6px rgba(0,0,0,0.1); }
        .header { background: linear-gradient(135deg, #f59e0b 0%, #d97706 100%); padding: 40px 30px; text-align: center; color: white; }
        .header h1 { margin: 0 0 10px 0; font-size: 28px; font-weight: 700; }
        .header p { margin: 0; font-size: 16px; opacity: 0.95; }
        .logo-container { display: inline-block; margin-bottom: 15px; }
        .logo-container img { height: 50px; width: auto; }
        .content { padding: 40px 30px; }
        .greeting { font-size: 18px; color: #2d3748; margin-bottom: 20px; font-weight: 600; }
        .message { font-size: 15px; line-height: 1.8; color: #4a5568; margin-bottom: 25px; }
        .warning-badge { background: linear-gradient(135deg, #fef3c7 0%, #fde68a 100%); border: 3px solid #f59e0b; padding: 25px; border-radius: 12px; text-align: center; margin: 30px 0; }
        .warning-icon { font-size: 64px; margin-bottom: 15px; }
        .warning-title { font-size: 24px; font-weight: 700; color: #d97706; margin-bottom: 10px; }
        .warning-message { font-size: 15px; color: #b45309; }
        .info-card { background: linear-gradient(135deg, #f59e0b15 0%, #d9770615 100%); border-left: 4px solid #f59e0b; padding: 20px; border-radius: 8px; margin: 25px 0; }
        .info-row { display: flex; padding: 10px 0; border-bottom: 1px solid #e2e8f0; }
        .info-row:last-child { border-bottom: none; }
        .info-label { font-weight: 700; color: #4a5568; min-width: 140px; font-size: 14px; }
        .info-value { color: #2d3748; font-size: 14px; }
        .notes-box { background-color: #fffbeb; border: 2px solid #fcd34d; padding: 20px; border-radius: 8px; margin: 25px 0; }
        .notes-title { font-weight: 700; color: #d97706; margin-bottom: 10px; font-size: 16px; }
        .notes-text { color: #92400e; line-height: 1.8; white-space: pre-wrap; }
        .cta-button { display: inline-block; background: linear-gradient(135deg, #f59e0b 0%, #d97706 100%); color: white; text-decoration: none; padding: 14px 32px; border-radius: 8px; font-weight: 600; font-size: 16px; margin: 25px 0; box-shadow: 0 4px 6px rgba(245,158,11,0.3); }
        .divider { border-top: 2px dashed #cbd5e0; margin: 40px 0; }
        .footer { background-color: #f7fafc; padding: 25px 30px; text-align: center; font-size: 13px; color: #718096; border-top: 1px solid #e2e8f0; }
        .footer-links { margin-top: 15px; }
        .footer-links a { color: #f59e0b; text-decoration: none; margin: 0 8px; }
      </style>
    </head>
    <body>
      <div class="wrapper">
        <div class="container">
          <div class="header">
            #{if app_logo_url, do: "<div class='logo-container'><img src='#{app_logo_url}' alt='#{app_name}' /></div>", else: ""}
            <h1>🔄 Revision Requested</h1>
            <p>Revisi Diperlukan</p>
          </div>

          <div class="content">
            <!-- BAHASA INDONESIA -->
            <div class="greeting">Kepada Yth. #{librarian.fullname || librarian.email},</div>

            <div class="warning-badge">
              <div class="warning-icon">📝</div>
              <div class="warning-title">Revisi Diperlukan</div>
              <div class="warning-message">Sesi memerlukan perbaikan</div>
            </div>

            <div class="message">
              Revisi telah diminta untuk sesi stock opname <strong>#{session.title}</strong> (#{session.session_code}). Silakan tinjau catatan dari reviewer dan lakukan perbaikan yang diperlukan.
            </div>

            <div class="notes-box">
              <div class="notes-title">📋 Catatan dari Reviewer / Reviewer's Notes:</div>
              <div class="notes-text">#{notes}</div>
            </div>

            <div class="info-card">
              <div class="info-row">
                <div class="info-label">Judul Sesi:</div>
                <div class="info-value"><strong>#{session.title}</strong></div>
              </div>
              <div class="info-row">
                <div class="info-label">Kode Sesi:</div>
                <div class="info-value">#{session.session_code}</div>
              </div>
              <div class="info-row">
                <div class="info-label">Status:</div>
                <div class="info-value"><strong style="color: #f59e0b;">⟳ Perlu Revisi</strong></div>
              </div>
            </div>

            <div style="text-align: center;">
              <a href="#{session_url}" class="cta-button">🔧 Lanjutkan Sesi</a>
            </div>

            <div class="divider"></div>

            <!-- ENGLISH -->
            <div class="greeting">Dear #{librarian.fullname || librarian.email},</div>

            <div class="warning-badge">
              <div class="warning-icon">📝</div>
              <div class="warning-title">Revision Requested</div>
              <div class="warning-message">Session requires corrections</div>
            </div>

            <div class="message">
              A revision has been requested for the stock opname session <strong>#{session.title}</strong> (#{session.session_code}). Please review the notes from the reviewer and make the necessary corrections.
            </div>

            <div style="text-align: center;">
              <a href="#{session_url}" class="cta-button">🔧 Resume Session</a>
            </div>
          </div>

          <div class="footer">
            <p><strong>Ini adalah pesan otomatis dari Sistem Perpustakaan.</strong><br>
            This is an automated message from the Library System.</p>
            <p>Mohon tidak membalas email ini. | Please do not reply to this email.</p>
            <div class="footer-links">
              <a href="mailto:perpustakaan@unpad.ac.id">📧 Email</a>
              <a href="https://instagram.com/kandagaunpad">📱 Instagram</a>
              <a href="https://wa.me/6282315798979">💬 WhatsApp</a>
            </div>
          </div>
        </div>
      </div>
    </body>
    </html>
    """
  end
end
