defmodule Voile.Notifications.EmailQueue do
  @moduledoc """
  Email queue for sending emails with configurable delays to avoid spam filters.

  This GenServer maintains a queue of emails to be sent and processes them
  one at a time with a configurable delay between sends.

  Features:
  - Rate limiting: Configurable delay between emails
  - Retry logic: Failed emails are retried up to N times
  - Bounded queue: Max queue size with backpressure (drops when full)
  - Async sending: Email functions run in a supervised Task, never blocking the GenServer
  - Statistics: Track sent, failed, retried, and dropped emails

  Configuration:
  - config :voile, :email_queue_delay, 2000  # milliseconds between emails (default: 2 seconds)
  - config :voile, :email_queue_max_retries, 3  # maximum retry attempts (default: 3)
  - config :voile, :email_queue_max_size, 10_000  # max buffered jobs before dropping (default: 10_000)
  """

  use GenServer
  require Logger

  @default_delay 2000
  @default_max_retries 3
  @default_max_queue_size 10_000
  # 1 minute before retry
  @retry_delay 60_000
  # Timeout for the email-sending Task
  @send_timeout_ms 30_000

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
    Logger.info("Email queue started with delay: #{get_delay()}ms")

    state = %{
      queue: :queue.new(),
      processing: false,
      paused: false,
      current_job: nil,
      current_ref: nil,
      retry_timers: [],
      stats: %{
        sent: 0,
        failed: 0,
        retried: 0,
        dropped: 0
      }
    }

    {:ok, state}
  end

  @impl true
  def handle_cast({:enqueue, email_fn, priority, metadata}, state) do
    current_size = :queue.len(state.queue)
    max_size = get_max_queue_size()

    if current_size >= max_size do
      Logger.warning("Email queue full (#{current_size}/#{max_size}), dropping email")

      {:noreply, %{state | stats: update_stats(state.stats, :dropped, 1)}}
    else
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

      Logger.debug(
        "Email queued: #{job.id} (priority: #{priority}, queue size: #{:queue.len(new_queue)})"
      )

      new_state = %{state | queue: new_queue}
      new_state = maybe_start_processing(new_state)

      {:noreply, new_state}
    end
  end

  @impl true
  def handle_call(:stats, _from, state) do
    stats =
      state.stats
      |> Map.put(:queue_size, :queue.len(state.queue))
      |> Map.put(:paused, state.paused)

    {:reply, stats, state}
  end

  @impl true
  def handle_call(:clear_queue, _from, state) do
    # Cancel all pending retry timers to prevent race condition
    Enum.each(state.retry_timers, &Process.cancel_timer/1)

    Logger.warning("Email queue cleared")

    new_state = %{
      state
      | queue: :queue.new(),
        processing: false,
        current_job: nil,
        current_ref: nil,
        retry_timers: []
    }

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

  # Process next email from the queue — spawns a Task (non-blocking)
  @impl true
  def handle_info(:process_next, state) do
    if state.paused do
      {:noreply, %{state | processing: false}}
    else
      case :queue.out(state.queue) do
        {{:value, job}, new_queue} ->
          ref = make_ref()
          spawn_send_task(job, ref)

          Logger.info(
            "Processing email job: #{job.id} (attempt #{job.retries + 1}/#{job.max_retries + 1})"
          )

          # Safety timeout in case the Task hangs
          Process.send_after(self(), {:email_timeout, ref}, @send_timeout_ms)

          {:noreply,
           %{state | queue: new_queue, processing: true, current_job: job, current_ref: ref}}

        {:empty, _} ->
          {:noreply, %{state | processing: false}}
      end
    end
  end

  # Email Task completed successfully
  @impl true
  def handle_info({:email_result, ref, result}, %{current_ref: ref} = state) do
    job = state.current_job

    state = %{state | current_job: nil, current_ref: nil}

    case result do
      :ok ->
        Logger.info("Email sent successfully: #{job.id}")
        new_stats = update_stats(state.stats, :sent, 1)
        schedule_next_processing()
        {:noreply, %{state | stats: new_stats}}

      {:error, reason} ->
        Logger.error("Email failed: #{job.id}, reason: #{inspect(reason)}")
        handle_job_failure(state, job, reason)
    end
  end

  # Stale result from a previous job (after timeout or clear)
  def handle_info({:email_result, _stale_ref, _result}, state), do: {:noreply, state}

  # Email Task timed out
  @impl true
  def handle_info({:email_timeout, ref}, %{current_ref: ref} = state) do
    job = state.current_job
    Logger.warning("Email timed out after #{@send_timeout_ms}ms: #{job.id}")

    state = %{state | current_job: nil, current_ref: nil}
    handle_job_failure(state, job, :timeout)
  end

  # Stale timeout
  def handle_info({:email_timeout, _stale_ref}, state), do: {:noreply, state}

  # Retry job re-enters the queue
  @impl true
  def handle_info({:retry_job, job}, state) do
    new_queue = enqueue_job(state.queue, job)
    new_state = %{state | queue: new_queue}
    new_state = maybe_start_processing(new_state)
    {:noreply, new_state}
  end

  @impl true
  def handle_info(_msg, state), do: {:noreply, state}

  # Private Functions

  defp enqueue_job(queue, job) do
    :queue.in(job, queue)
  end

  defp maybe_start_processing(state) do
    if not state.processing and not state.paused and :queue.len(state.queue) > 0 do
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

  defp spawn_send_task(job, ref) do
    email_fn = job.email_fn

    Task.Supervisor.start_child(Voile.TaskSupervisor, fn ->
      result =
        try do
          case email_fn.() do
            {:ok, _result} -> :ok
            {:error, reason} -> {:error, reason}
            other -> {:error, other}
          end
        rescue
          error ->
            {:error, Exception.message(error)}
        catch
          kind, reason ->
            {:error, {kind, reason}}
        end

      send(__MODULE__, {:email_result, ref, result})
    end)
  end

  defp handle_job_failure(state, job, reason) do
    if job.retries < job.max_retries do
      updated_job = %{job | retries: job.retries + 1}
      new_stats = update_stats(state.stats, :retried, 1)

      Logger.info(
        "Scheduling retry for job: #{job.id} (attempt #{updated_job.retries + 1}/#{updated_job.max_retries + 1})"
      )

      timer_ref = Process.send_after(self(), {:retry_job, updated_job}, @retry_delay)

      schedule_next_processing()

      {:noreply, %{state | stats: new_stats, retry_timers: [timer_ref | state.retry_timers]}}
    else
      Logger.error(
        "Email permanently failed after #{job.retries} retries: #{job.id}, reason: #{inspect(reason)}"
      )

      new_stats = update_stats(state.stats, :failed, 1)
      schedule_next_processing()
      {:noreply, %{state | stats: new_stats}}
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

  defp get_max_queue_size do
    Application.get_env(:voile, :email_queue_max_size, @default_max_queue_size)
  end
end
