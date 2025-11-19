defmodule Voile.Schema.Accounts.UserNotifier do
  import Swoosh.Email

  alias Voile.Mailer
  alias Voile.Schema.Accounts.User
  alias VoileWeb.EmailComponent.Template

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
    deliver(
      user.email,
      "Konfirmasi Akun / Account Confirmation",
      Template.confirmation_instructions(user, url)
    )
  end

  @doc """
  Deliver instructions to reset a user password.
  """
  def deliver_reset_password_instructions(user, url) do
    deliver(
      user.email,
      "Reset Password / Atur Ulang Kata Sandi",
      Template.reset_password_instructions(user, url)
    )
  end

  @doc """
  Deliver instructions to update a user email.
  """
  def deliver_update_email_instructions(user, url) do
    deliver(
      user.email,
      "Perbarui Email / Update Email",
      Template.update_email_instructions(user, url)
    )
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
    deliver(
      user.email,
      "Login dengan Tautan / Log in with Link",
      Template.magic_link_instructions(user, url)
    )
  end
end
