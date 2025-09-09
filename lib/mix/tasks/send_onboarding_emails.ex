defmodule Mix.Tasks.Voile.SendOnboardingEmails do
  @moduledoc """
  Mix task to send onboarding emails to all migrated users who need to set their passwords.

  This task finds users who:
  - Have not confirmed their accounts (confirmed_at is nil)
  - Have the default migrated password hash
  - Need to complete the onboarding process

  Usage:
      mix voile.send_onboarding_emails
      mix voile.send_onboarding_emails --dry-run
      mix voile.send_onboarding_emails --limit 10
      mix voile.send_onboarding_emails --email user@example.com
  """

  use Mix.Task
  import Ecto.Query
  alias Voile.Schema.Accounts
  alias Voile.Repo

  @shortdoc "Send onboarding emails to migrated users"

  def run(args) do
    Mix.Task.run("app.start")

    {opts, _, _} =
      OptionParser.parse(args,
        switches: [dry_run: :boolean, limit: :integer, email: :string],
        aliases: [d: :dry_run, l: :limit, e: :email]
      )

    dry_run? = Keyword.get(opts, :dry_run, false)
    limit = Keyword.get(opts, :limit, nil)
    specific_email = Keyword.get(opts, :email, nil)

    if dry_run? do
      IO.puts("🔍 DRY RUN MODE - No emails will be sent\n")
    end

    users =
      if specific_email do
        get_user_by_email(specific_email)
      else
        get_unconfirmed_migrated_users(limit)
      end

    email_type =
      if specific_email,
        do: "specific user (#{specific_email})",
        else: "migrated users needing onboarding"

    IO.puts("📊 Found #{length(users)} #{email_type}:")
    IO.puts("#{String.duplicate("=", 60)}")

    for {user, index} <- Enum.with_index(users, 1) do
      IO.puts("#{index}. #{user.fullname || "N/A"} <#{user.email}> (@#{user.username})")
      IO.puts("   Registered: #{format_date(user.inserted_at)}")

      if specific_email do
        status = if user.confirmed_at, do: "✅ Confirmed", else: "⚠️ Unconfirmed"

        migration_status =
          if is_migrated_user?(user), do: "🔄 Migrated User", else: "👤 Regular User"

        IO.puts("   Status: #{status} | #{migration_status}")
      end
    end

    IO.puts("#{String.duplicate("=", 60)}\n")

    if length(users) == 0 do
      if specific_email do
        IO.puts("❌ No user found with email: #{specific_email}")
      else
        IO.puts("✅ No users found that need onboarding emails.")

        IO.puts(
          "All migrated users have either completed onboarding or don't have the default password.\n"
        )
      end
    else
      if dry_run? do
        IO.puts("✅ Dry run complete. Use without --dry-run to actually send emails.")
      else
        email_action =
          if specific_email,
            do: "Send onboarding email to #{specific_email}?",
            else: "Send onboarding emails to #{length(users)} users?"

        confirm_and_send = Mix.shell().yes?("📧 #{email_action}")

        if confirm_and_send do
          IO.puts("📤 Sending onboarding emails...\n")
          send_onboarding_emails(users)
        else
          IO.puts("❌ Operation cancelled.")
        end
      end
    end
  end

  defp get_unconfirmed_migrated_users(limit) do
    # This is the hash for "changeme123" from the member_importer.ex
    default_hash =
      "$pbkdf2-sha512$160000$OmHm5yQ4w.ZGpn7fvUcGzg$uBPzZQ2UOQ2oZFJt9JQZhVqJQa2wC9.XqBZQv1.2qHZqJQa2wC9.XqBZQv1.2qHZqJQa2wC9.XqBZQv1.2qHZqJQa2wC9.X"

    query =
      from(u in Accounts.User,
        where: is_nil(u.confirmed_at) and u.hashed_password == ^default_hash,
        order_by: [desc: u.inserted_at]
      )

    query = if limit, do: limit(query, ^limit), else: query

    Repo.all(query)
  end

  defp get_user_by_email(email) do
    case Accounts.get_user_by_email(email) do
      nil -> []
      user -> [user]
    end
  end

  defp is_migrated_user?(user) do
    # Check if user has the default migrated password hash
    default_hash =
      "$pbkdf2-sha512$160000$OmHm5yQ4w.ZGpn7fvUcGzg$uBPzZQ2UOQ2oZFJt9JQZhVqJQa2wC9.XqBZQv1.2qHZqJQa2wC9.XqBZQv1.2qHZqJQa2wC9.XqBZQv1.2qHZqJQa2wC9.X"

    user.hashed_password == default_hash
  end

  defp send_onboarding_emails(users) do
    {success_count, error_count} =
      Enum.reduce(users, {0, 0}, fn user, {success, errors} ->
        case send_onboarding_email(user) do
          {:ok, _} ->
            IO.puts("✅ Sent to #{user.email}")
            {success + 1, errors}

          {:error, reason} ->
            IO.puts("❌ Failed to send to #{user.email}: #{inspect(reason)}")
            {success, errors + 1}
        end
      end)

    IO.puts("\n#{String.duplicate("=", 60)}")
    IO.puts("📊 SUMMARY:")
    IO.puts("   ✅ Successfully sent: #{success_count}")
    IO.puts("   ❌ Failed: #{error_count}")
    IO.puts("   📧 Total processed: #{success_count + error_count}")

    if error_count > 0 do
      IO.puts("\n⚠️  Some emails failed to send. Check your email configuration and try again.")
    else
      IO.puts("\n🎉 All onboarding emails sent successfully!")
    end
  end

  defp send_onboarding_email(user) do
    try do
      # Add a small delay to avoid overwhelming the email service
      Process.sleep(100)

      Accounts.deliver_onboarding_instructions(user, fn token ->
        VoileWeb.Endpoint.url() <> "/users/onboarding/#{token}"
      end)
    rescue
      error ->
        {:error, Exception.message(error)}
    end
  end

  defp format_date(nil), do: "N/A"

  defp format_date(datetime) do
    Calendar.strftime(datetime, "%Y-%m-%d %H:%M")
  end
end
