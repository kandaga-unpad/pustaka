defmodule Voile.Task.SuspensionExpiryScheduler do
  @moduledoc """
  Scheduled task that automatically unsuspends users when their suspension period ends.

  This task:
  - Runs daily (or at configured interval)
  - Checks for users with expired suspensions
  - Automatically sets manually_suspended to false
  - Logs the unsuspension action

  Configuration:
  - Set scheduler interval: config :voile, :suspension_expiry_interval, :daily
  """

  use GenServer
  require Logger

  alias Voile.Schema.Accounts.User
  alias Voile.Repo

  import Ecto.Query

  # Run every day at 9 AM (in milliseconds)
  @default_interval 24 * 60 * 60 * 1000
  # Run 10 minutes after start (for first run)
  @initial_delay 10 * 60 * 1000

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    # Schedule the first check after a short delay
    schedule_next_check(@initial_delay)
    {:ok, %{last_run: nil}}
  end

  @impl true
  def handle_info(:check_expiries, state) do
    Logger.info("Running suspension expiry check...")

    try do
      process_expired_suspensions()
      schedule_next_check()
      {:noreply, %{state | last_run: DateTime.utc_now()}}
    rescue
      error ->
        Logger.error("Error in suspension expiry scheduler: #{inspect(error)}")
        # Still schedule next check even if current one fails
        schedule_next_check()
        {:noreply, state}
    end
  end

  @doc """
  Manually trigger an expiry check (useful for testing).
  """
  def trigger_check do
    send(__MODULE__, :check_expiries)
  end

  @doc """
  Main function to check and process expired suspensions.
  """
  def process_expired_suspensions do
    now = DateTime.utc_now()

    # Find users with expired suspensions
    expired_users = get_expired_suspensions(now)

    Logger.info("Found #{length(expired_users)} users with expired suspensions")

    # Process each expired suspension
    Enum.each(expired_users, fn user ->
      unsuspend_user(user)
    end)
  end

  # Private Functions

  defp get_expired_suspensions(now) do
    from(u in User,
      where: u.manually_suspended == true,
      where: not is_nil(u.suspension_ends_at),
      where: u.suspension_ends_at <= ^now,
      select: u
    )
    |> Repo.all()
  end

  defp unsuspend_user(user) do
    Logger.info(
      "Automatically unsuspending user #{user.id} (#{user.fullname}) - suspension expired at #{user.suspension_ends_at}"
    )

    # Update the user to remove suspension
    changeset =
      Ecto.Changeset.change(user, %{
        manually_suspended: false,
        suspension_reason: nil,
        suspended_at: nil,
        suspension_ends_at: nil,
        suspended_by_id: nil
      })

    case Repo.update(changeset) do
      {:ok, updated_user} ->
        Logger.info("Successfully unsuspended user #{updated_user.id}")

      # TODO: Optionally send notification to user about automatic unsuspension
      # Could queue an email or broadcast a notification

      {:error, changeset} ->
        Logger.error("Failed to unsuspend user #{user.id}: #{inspect(changeset.errors)}")
    end
  end

  defp schedule_next_check(delay \\ nil) do
    interval = delay || get_check_interval()
    Process.send_after(self(), :check_expiries, interval)
  end

  defp get_check_interval do
    Application.get_env(:voile, :suspension_expiry_interval, @default_interval)
  end
end
