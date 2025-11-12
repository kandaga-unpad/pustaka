defmodule Voile.Schema.Accounts.UserNotifier do
  import Swoosh.Email

  alias Voile.Mailer
  alias Voile.Schema.Accounts.User

  # Delivers the email using the application mailer.
  defp deliver(recipient, subject, body) do
    app_name = Voile.Schema.System.get_setting_value("app_name", "Voile")

    app_contact_email =
      Voile.Schema.System.get_setting_value("app_contact_email", "hi@curatorian.id")

    dbg(app_name)
    dbg(app_contact_email)

    email =
      new()
      |> to(recipient)
      |> from({app_name, app_contact_email})
      |> subject(subject)
      |> html_body(body)

    with {:ok, _metadata} <- Mailer.deliver(email) do
      {:ok, email}
    end
  end

  @doc """
  Deliver instructions to confirm account.
  """
  def deliver_confirmation_instructions(user, url) do
    deliver(user.email, "Konfirmasi Akun / Account Confirmation", """
      <!DOCTYPE html>
      <html>
      <head>
        <meta name='viewport' content='width=device-width, initial-scale=1'>
        <style>
          body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; margin: 0; padding: 0; }
          .container { margin: 0; padding: 20px; box-sizing: border-box; }
          .header { background-color: #4F46E5; color: white; padding: 20px; text-align: center; }
          .content { padding: 20px; background-color: #f9f9f9; width: 100%; box-sizing: border-box; }
          .footer { padding: 20px; text-align: center; color: #666; font-size: 12px; width: 100%; }
          .divider { border-top: 3px dashed #4F46E5; margin: 40px 0; padding-top: 40px; width: 100%; }
          .lang-section { margin-bottom: 20px; }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="header">
            <h1>Konfirmasi Akun / Account Confirmation</h1>
          </div>
          <div class="content">
            <div class="lang-section">
              <p>Kepada Yth. #{user.email},</p>
              <p>Silakan konfirmasi akun Anda dengan mengunjungi tautan di bawah ini:</p>
              <p><a href='#{url}' style='color:#4F46E5;'>#{url}</a></p>
              <p>Jika Anda tidak membuat akun dengan kami, abaikan email ini.</p>
            </div>
            <div class="divider"></div>
            <div class="lang-section">
              <p>Dear #{user.email},</p>
              <p>You can confirm your account by visiting the link below:</p>
              <p><a href='#{url}' style='color:#4F46E5;'>#{url}</a></p>
              <p>If you didn't create an account with us, please ignore this email.</p>
            </div>
          </div>
          <div class="footer">
            <p>Ini adalah pesan otomatis dari Sistem Voile.</p>
            <p>This is an automated message from the Voile System.</p>
            <p>Mohon tidak membalas email ini. / Please do not reply to this email.</p>
          </div>
        </div>
      </body>
      </html>
    """)
  end

  @doc """
  Deliver instructions to reset a user password.
  """
  def deliver_reset_password_instructions(user, url) do
    deliver(user.email, "Reset Password / Atur Ulang Kata Sandi", """
      <!DOCTYPE html>
      <html>
      <head>
        <meta name='viewport' content='width=device-width, initial-scale=1'>
        <style>
          body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; margin: 0; padding: 0; }
          .container { margin: 0; padding: 20px; box-sizing: border-box; }
          .header { background-color: #DC2626; color: white; padding: 20px; text-align: center; }
          .content { padding: 20px; background-color: #f9f9f9; width: 100%; box-sizing: border-box; }
          .footer { padding: 20px; text-align: center; color: #666; font-size: 12px; width: 100%; }
          .divider { border-top: 3px dashed #DC2626; margin: 40px 0; padding-top: 40px; width: 100%; }
          .lang-section { margin-bottom: 20px; }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="header">
            <h1>Reset Password / Atur Ulang Kata Sandi</h1>
          </div>
          <div class="content">
            <div class="lang-section">
              <p>Kepada Yth. #{user.email},</p>
              <p>Anda dapat mengatur ulang kata sandi Anda dengan mengunjungi tautan di bawah ini:</p>
              <p><a href='#{url}' style='color:#DC2626;'>#{url}</a></p>
              <p>Jika Anda tidak meminta perubahan ini, abaikan email ini.</p>
            </div>
            <div class="divider"></div>
            <div class="lang-section">
              <p>Dear #{user.email},</p>
              <p>You can reset your password by visiting the link below:</p>
              <p><a href='#{url}' style='color:#DC2626;'>#{url}</a></p>
              <p>If you didn't request this change, please ignore this email.</p>
            </div>
          </div>
          <div class="footer">
            <p>Ini adalah pesan otomatis dari Sistem Voile.</p>
            <p>This is an automated message from the Voile System.</p>
            <p>Mohon tidak membalas email ini. / Please do not reply to this email.</p>
          </div>
        </div>
      </body>
      </html>
    """)
  end

  @doc """
  Deliver instructions to update a user email.
  """
  def deliver_update_email_instructions(user, url) do
    deliver(user.email, "Perbarui Email / Update Email", """
      <!DOCTYPE html>
      <html>
      <head>
        <meta name='viewport' content='width=device-width, initial-scale=1'>
        <style>
          body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; margin: 0; padding: 0; }
          .container { margin: 0; padding: 20px; box-sizing: border-box; }
          .header { background-color: #7C3AED; color: white; padding: 20px; text-align: center; }
          .content { padding: 20px; background-color: #f9f9f9; width: 100%; box-sizing: border-box; }
          .footer { padding: 20px; text-align: center; color: #666; font-size: 12px; width: 100%; }
          .divider { border-top: 3px dashed #7C3AED; margin: 40px 0; padding-top: 40px; width: 100%; }
          .lang-section { margin-bottom: 20px; }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="header">
            <h1>Perbarui Email / Update Email</h1>
          </div>
          <div class="content">
            <div class="lang-section">
              <p>Kepada Yth. #{user.email},</p>
              <p>Anda dapat memperbarui email Anda dengan mengunjungi tautan di bawah ini:</p>
              <p><a href='#{url}' style='color:#7C3AED;'>#{url}</a></p>
              <p>Jika Anda tidak meminta perubahan ini, abaikan email ini.</p>
            </div>
            <div class="divider"></div>
            <div class="lang-section">
              <p>Dear #{user.email},</p>
              <p>You can change your email by visiting the link below:</p>
              <p><a href='#{url}' style='color:#7C3AED;'>#{url}</a></p>
              <p>If you didn't request this change, please ignore this email.</p>
            </div>
          </div>
          <div class="footer">
            <p>Ini adalah pesan otomatis dari Sistem Voile.</p>
            <p>This is an automated message from the Voile System.</p>
            <p>Mohon tidak membalas email ini. / Please do not reply to this email.</p>
          </div>
        </div>
      </body>
      </html>
    """)
  end

  @doc """
  Deliver instructions to log in with a magic link.
  """
  def deliver_login_instructions(user, url) do
    case user do
      %User{confirmed_at: nil} -> deliver_confirmation_instructions(user, url)
      _ -> deliver_magic_link_instructions(user, url)
    end
  end

  defp deliver_magic_link_instructions(user, url) do
    deliver(user.email, "Login dengan Tautan / Log in with Link", """
      <!DOCTYPE html>
      <html>
      <head>
        <meta name='viewport' content='width=device-width, initial-scale=1'>
        <style>
          body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; margin: 0; padding: 0; }
          .container { margin: 0; padding: 20px; box-sizing: border-box; }
          .header { background-color: #059669; color: white; padding: 20px; text-align: center; }
          .content { padding: 20px; background-color: #f9f9f9; width: 100%; box-sizing: border-box; }
          .footer { padding: 20px; text-align: center; color: #666; font-size: 12px; width: 100%; }
          .divider { border-top: 3px dashed #059669; margin: 40px 0; padding-top: 40px; width: 100%; }
          .lang-section { margin-bottom: 20px; }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="header">
            <h1>Login dengan Tautan / Log in with Link</h1>
          </div>
          <div class="content">
            <div class="lang-section">
              <p>Kepada Yth. #{user.email},</p>
              <p>Anda dapat masuk ke akun Anda dengan mengunjungi tautan di bawah ini:</p>
              <p><a href='#{url}' style='color:#059669;'>#{url}</a></p>
              <p>Jika Anda tidak meminta email ini, abaikan email ini.</p>
            </div>
            <div class="divider"></div>
            <div class="lang-section">
              <p>Dear #{user.email},</p>
              <p>You can log into your account by visiting the link below:</p>
              <p><a href='#{url}' style='color:#059669;'>#{url}</a></p>
              <p>If you didn't request this email, please ignore it.</p>
            </div>
          </div>
          <div class="footer">
            <p>Ini adalah pesan otomatis dari Sistem Voile.</p>
            <p>This is an automated message from the Voile System.</p>
            <p>Mohon tidak membalas email ini. / Please do not reply to this email.</p>
          </div>
        </div>
      </body>
      </html>
    """)
  end
end
