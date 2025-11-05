defmodule Voile.Notifications.EmailQueue do
  @moduledoc """
  Email queue for sending emails with configurable delays to avoid spam filters.

  This GenServer maintains a queue of emails to be sent and processes them
  one at a time with a configurable delay between sends.

  Features:
  - Rate limiting: Configurable delay between emails
  - Retry logic: Failed emails are retried up to N times
  - Priority queue: Support for urgent emails
  - Statistics: Track sent, failed, and queued emails

  Configuration:
  - config :voile, :email_queue_delay, 2000  # milliseconds between emails (default: 2 seconds)
  - config :voile, :email_queue_max_retries, 3  # maximum retry attempts
  """

  use GenServer
  require Logger

  # 2 seconds between emails
  @default_delay 2000
  @default_max_retries 3
  # 1 minute before retry
  @retry_delay 60_000

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Queue an email to be sent.

  ## Parameters
  - email_fn: A function that sends the email and returns {:ok, result} or {:error, reason}
  - opts: Options
    - :priority - :high, :normal, or :low (default: :normal)
    - :metadata - Map of metadata for logging

  ## Examples

      EmailQueue.enqueue(fn ->
        LoanReminderEmail.send_reminder_email(member, transactions, 3)
      end, metadata: %{member_id: 123, type: :reminder})
  """
  def enqueue(email_fn, opts \\ []) when is_function(email_fn, 0) do
    priority = Keyword.get(opts, :priority, :normal)
    metadata = Keyword.get(opts, :metadata, %{})

    GenServer.cast(__MODULE__, {:enqueue, email_fn, priority, metadata})
  end

  @doc """
  Get current queue statistics.
  """
  def stats do
    GenServer.call(__MODULE__, :stats)
  end

  @doc """
  Clear the queue (useful for testing or maintenance).
  """
  def clear_queue do
    GenServer.call(__MODULE__, :clear_queue)
  end

  @doc """
  Pause email processing.
  """
  def pause do
    GenServer.call(__MODULE__, :pause)
  end

  @doc """
  Resume email processing.
  """
  def resume do
    GenServer.call(__MODULE__, :resume)
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    state = %{
      queue: :queue.new(),
      processing: false,
      paused: false,
      stats: %{
        sent: 0,
        failed: 0,
        queued: 0,
        retried: 0
      }
    }

    Logger.info("Email queue started with delay: #{get_delay()}ms")
    {:ok, state}
  end

  @impl true
  def handle_cast({:enqueue, email_fn, priority, metadata}, state) do
    job = %{
      id: generate_job_id(),
      email_fn: email_fn,
      priority: priority,
      metadata: metadata,
      retries: 0,
      max_retries: get_max_retries(),
      enqueued_at: DateTime.utc_now()
    }

    new_queue = enqueue_job(state.queue, job)
    new_stats = update_stats(state.stats, :queued, 1)

    Logger.debug(
      "Email queued: #{job.id} (priority: #{priority}, queue size: #{:queue.len(new_queue)})"
    )

    # Start processing if not already processing
    new_state = %{state | queue: new_queue, stats: new_stats}
    new_state = maybe_start_processing(new_state)

    {:noreply, new_state}
  end

  @impl true
  def handle_call(:stats, _from, state) do
    stats = Map.put(state.stats, :queue_size, :queue.len(state.queue))
    {:reply, stats, state}
  end

  @impl true
  def handle_call(:clear_queue, _from, state) do
    new_state = %{state | queue: :queue.new(), processing: false}
    Logger.warning("Email queue cleared")
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call(:pause, _from, state) do
    Logger.info("Email queue paused")
    {:reply, :ok, %{state | paused: true}}
  end

  @impl true
  def handle_call(:resume, _from, state) do
    Logger.info("Email queue resumed")
    new_state = %{state | paused: false}
    new_state = maybe_start_processing(new_state)
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_info(:process_next, state) do
    if state.paused do
      # If paused, just mark as not processing
      {:noreply, %{state | processing: false}}
    else
      case :queue.out(state.queue) do
        {{:value, job}, new_queue} ->
          # Process the job
          result = process_job(job, state.stats)

          case result do
            {:ok, new_stats} ->
              # Job succeeded, schedule next processing
              schedule_next_processing()
              {:noreply, %{state | queue: new_queue, stats: new_stats, processing: true}}

            {:retry, updated_job, new_stats} ->
              # Job failed but should be retried - schedule retry after delay
              Process.send_after(self(), {:retry_job, updated_job}, @retry_delay)
              schedule_next_processing()
              {:noreply, %{state | queue: new_queue, stats: new_stats, processing: true}}

            {:failed, new_stats} ->
              # Job failed permanently, move to next
              schedule_next_processing()
              {:noreply, %{state | queue: new_queue, stats: new_stats, processing: true}}
          end

        {:empty, _} ->
          # Queue is empty, stop processing
          {:noreply, %{state | processing: false}}
      end
    end
  end

  @impl true
  def handle_info({:retry_job, job}, state) do
    # Add the job back to the queue
    new_queue = enqueue_job(state.queue, job)
    new_state = %{state | queue: new_queue}
    new_state = maybe_start_processing(new_state)
    {:noreply, new_state}
  end

  # Private Functions

  defp enqueue_job(queue, job) do
    # Simple FIFO for now, could implement priority later
    :queue.in(job, queue)
  end

  defp maybe_start_processing(state) do
    if not state.processing and not state.paused and :queue.len(state.queue) > 0 do
      # Start immediately
      schedule_next_processing(0)
      %{state | processing: true}
    else
      state
    end
  end

  defp schedule_next_processing(delay \\ nil) do
    delay = delay || get_delay()
    Process.send_after(self(), :process_next, delay)
  end

  defp process_job(job, stats) do
    Logger.info(
      "Processing email job: #{job.id} (attempt #{job.retries + 1}/#{job.max_retries + 1})"
    )

    try do
      case job.email_fn.() do
        {:ok, _result} ->
          Logger.info("Email sent successfully: #{job.id}")
          new_stats = update_stats(stats, :sent, 1)
          {:ok, new_stats}

        {:error, reason} ->
          Logger.error("Email failed: #{job.id}, reason: #{inspect(reason)}")
          handle_job_failure(job, stats, reason)

        other ->
          Logger.warning("Email function returned unexpected result: #{inspect(other)}")
          handle_job_failure(job, stats, other)
      end
    rescue
      error ->
        Logger.error("Email job crashed: #{job.id}, error: #{inspect(error)}")
        handle_job_failure(job, stats, error)
    end
  end

  defp handle_job_failure(job, stats, reason) do
    if job.retries < job.max_retries do
      # Retry the job
      updated_job = %{job | retries: job.retries + 1}
      new_stats = update_stats(stats, :retried, 1)

      Logger.info(
        "Scheduling retry for job: #{job.id} (attempt #{updated_job.retries + 1}/#{job.max_retries + 1})"
      )

      # Schedule retry after a delay
      Process.send_after(self(), {:retry_job, updated_job}, @retry_delay)

      {:retry, updated_job, new_stats}
    else
      # Max retries exceeded
      Logger.error(
        "Email permanently failed after #{job.retries} retries: #{job.id}, reason: #{inspect(reason)}"
      )

      new_stats = update_stats(stats, :failed, 1)
      {:failed, new_stats}
    end
  end

  defp update_stats(stats, key, increment) do
    Map.update(stats, key, increment, &(&1 + increment))
  end

  defp generate_job_id do
    "email_#{:erlang.unique_integer([:positive])}"
  end

  defp get_delay do
    Application.get_env(:voile, :email_queue_delay, @default_delay)
  end

  defp get_max_retries do
    Application.get_env(:voile, :email_queue_max_retries, @default_max_retries)
  end
end
