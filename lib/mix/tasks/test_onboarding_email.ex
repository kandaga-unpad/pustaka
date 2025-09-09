defmodule Mix.Tasks.Voile.TestOnboardingEmail do
  @moduledoc """
  Mix task to send a test onboarding email to any user for testing purposes.

  This task allows you to test the onboarding email functionality by sending
  an onboarding email to any existing user, regardless of their current status.
  This is useful for testing email templates, delivery, and the onboarding flow.

  Usage:
      mix voile.test_onboarding_email user@example.com
      mix voile.test_onboarding_email --email user@example.com
      mix voile.test_onboarding_email user@example.com --dry-run
  """

  use Mix.Task
  alias Voile.Schema.Accounts

  @shortdoc "Send a test onboarding email to any user"

  def run([]), do: show_usage()

  def run(args) do
    Mix.Task.run("app.start")

    {opts, positional_args, _} =
      OptionParser.parse(args,
        switches: [email: :string, dry_run: :boolean],
        aliases: [e: :email, d: :dry_run]
      )

    email =
      Keyword.get(opts, :email) ||
        List.first(positional_args) ||
        Mix.shell().prompt("Enter email address to test: ") |> String.trim()

    dry_run? = Keyword.get(opts, :dry_run, false)

    if String.trim(email) == "" do
      Mix.shell().error("❌ Email address is required")
      show_usage()
    else
      case Accounts.get_user_by_email(email) do
        nil ->
          Mix.shell().error("❌ No user found with email: #{email}")

          suggest_create? = Mix.shell().yes?("Would you like to see how to create a test user?")
          if suggest_create?, do: show_create_user_instructions()

        user ->
          IO.puts("📧 Found user: #{user.fullname || "N/A"} <#{user.email}>")
          IO.puts("   Username: @#{user.username}")
          IO.puts("   Status: #{if user.confirmed_at, do: "✅ Confirmed", else: "⚠️ Unconfirmed"}")
          IO.puts("   Migrated: #{if is_migrated_user?(user), do: "🔄 Yes", else: "👤 No"}")
          IO.puts("")

          if dry_run? do
            IO.puts("🔍 DRY RUN MODE - Would send onboarding email to #{email}")
            IO.puts("✅ Dry run complete. Remove --dry-run to actually send the email.")
          else
            if Mix.shell().yes?("📧 Send test onboarding email to #{email}?") do
              send_test_onboarding_email(user)
            else
              IO.puts("❌ Operation cancelled.")
            end
          end
      end
    end
  end

  defp show_usage do
    IO.puts("""
    Usage:
      mix voile.test_onboarding_email user@example.com
      mix voile.test_onboarding_email --email user@example.com
      mix voile.test_onboarding_email user@example.com --dry-run

    This task sends a test onboarding email to any existing user for testing purposes.
    """)
  end

  defp show_create_user_instructions do
    IO.puts("""

    📝 To create a test user, you can:

    1. Use the registration page: /register
    2. Use IEx console:

       iex> alias Voile.Schema.Accounts
       iex> {:ok, user} = Accounts.register_user(%{
         email: "test@example.com",
         password: "testpassword123",
         username: "testuser"
       })

    3. Or run the member importer to create migrated users
    """)
  end

  defp send_test_onboarding_email(user) do
    IO.puts("📤 Sending test onboarding email to #{user.email}...")

    case Accounts.deliver_onboarding_instructions(user, fn token ->
           VoileWeb.Endpoint.url() <> "/users/onboarding/#{token}"
         end) do
      {:ok, _} ->
        IO.puts("✅ Test onboarding email sent successfully!")
        IO.puts("")
        IO.puts("📋 Next steps:")
        IO.puts("   1. Check #{user.email} for the onboarding email")
        IO.puts("   2. Click the onboarding link in the email")
        IO.puts("   3. Test the onboarding flow by setting a new password")
        IO.puts("   4. Verify the user can login with the new password")
        IO.puts("")
        IO.puts("🔗 The onboarding link will expire in 24 hours")

      {:error, reason} ->
        Mix.shell().error("❌ Failed to send onboarding email: #{inspect(reason)}")
        IO.puts("")
        IO.puts("💡 Troubleshooting tips:")
        IO.puts("   - Check your email configuration in config/dev.exs or config/prod.exs")
        IO.puts("   - Verify Swoosh is properly configured")
        IO.puts("   - Check if the email service is running (if using local SMTP)")
        IO.puts("   - Look at the Phoenix server logs for detailed error messages")
    end
  end

  defp is_migrated_user?(user) do
    # Check if user has the default migrated password hash
    default_hash =
      "$pbkdf2-sha512$160000$OmHm5yQ4w.ZGpn7fvUcGzg$uBPzZQ2UOQ2oZFJt9JQZhVqJQa2wC9.XqBZQv1.2qHZqJQa2wC9.XqBZQv1.2qHZqJQa2wC9.XqBZQv1.2qHZqJQa2wC9.X"

    user.hashed_password == default_hash
  end
end
