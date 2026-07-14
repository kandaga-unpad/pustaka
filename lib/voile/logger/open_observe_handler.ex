defmodule Voile.Logger.OpenObserveHandler do
  @moduledoc """
  OTP logger handler that ships log events to OpenObserve via the JSON ingest API.

  Ships batches of logs either when the buffer reaches `batch_size` or when
  the `flush_interval` timer fires. Uses Req (Finch) for HTTP transport.

  ## Configuration (via Application env `:voile, :open_observe_logs`)

      config :voile, :open_observe_logs,
        url: "https://host/api/org/stream/_json",
        username: "email@example.com",
        password: "secret",
        batch_size: 100,
        flush_interval: 5_000,
        max_buffer_size: 1_000,
        circuit_threshold: 5,
        circuit_reset_delay: 30_000

  ## Activation

  The handler is registered automatically when `Voile.Logger.OpenObserveSender`
  starts (added to the supervision tree in `Voile.Application`).
  """

  # OTP :logger handler callbacks — called synchronously from the logging process.
  # We immediately hand off to the GenServer to avoid blocking callers.

  @doc false
  def adding_handler(config), do: {:ok, config}

  @doc false
  def removing_handler(_config), do: :ok

  @doc false
  def log(log_event, _config) do
    # Guard against recursive logging from within our own sender process
    sender = Process.whereis(Voile.Logger.OpenObserveSender)

    if sender != nil and sender != self() do
      GenServer.cast(sender, {:log, log_event})
    end

    :ok
  end
end

defmodule Voile.Logger.OpenObserveSender do
  @moduledoc false
  use GenServer
  require Logger

  @handler_id :voile_open_observe
  @default_batch_size 100
  @default_flush_interval 5_000
  @default_max_buffer_size 1_000
  @default_circuit_threshold 5
  @default_circuit_reset_delay 30_000
  @flush_timeout_ms 15_000
  @default_max_heap_mb 100

  # inspect/2 options — limit collection depth and string output to prevent
  # a single log report from consuming megabytes of memory.
  @inspect_opts [limit: 50, printable_limit: 10_000]

  defstruct opts: %{},
            buffer: [],
            buffer_count: 0,
            flush_in_flight?: false,
            flush_ref: nil,
            circuit_open?: false,
            consecutive_failures: 0,
            dropped_count: 0

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  # ---------------------------------------------------------------------------
  # GenServer callbacks
  # ---------------------------------------------------------------------------

  @impl true
  def init(opts) do
    # Safety net: if the heap ever exceeds this, the process is killed and
    # restarted by the supervisor with a fresh, small heap. Normal operation
    # stays well under 15 MB; 100 MB gives generous headroom for temporary
    # spikes without triggering on healthy load.
    max_heap_mb = opts[:max_heap_mb] || @default_max_heap_mb
    max_heap_words = trunc(max_heap_mb * 1024 * 1024 / :erlang.system_info(:wordsize))
    Process.flag(:max_heap_size, %{size: max_heap_words, kill: true})

    :logger.add_handler(@handler_id, Voile.Logger.OpenObserveHandler, %{level: :info})
    schedule_flush(opts[:flush_interval] || @default_flush_interval)
    {:ok, %__MODULE__{opts: opts}}
  end

  @impl true
  def terminate(_reason, _state) do
    :logger.remove_handler(@handler_id)
    :ok
  end

  # 1. Buffer cap — drop logs when buffer exceeds max_buffer_size
  # 2. Circuit breaker — drop logs when circuit is open (OpenObserve unreachable)
  @impl true
  def handle_cast({:log, log_event}, state) do
    cond do
      state.circuit_open? ->
        {:noreply, %{state | dropped_count: state.dropped_count + 1}}

      state.buffer_count >= max_buffer_size(state.opts) ->
        if state.dropped_count == 0 do
          Logger.warning(
            "[OpenObserveSender] Buffer full (#{state.buffer_count} entries), dropping incoming logs"
          )
        end

        {:noreply, %{state | dropped_count: state.dropped_count + 1}}

      true ->
        entry = format_entry(log_event)
        new_buffer = [entry | state.buffer]
        new_count = state.buffer_count + 1

        if new_count >= batch_size(state.opts) and not state.flush_in_flight? do
          spawn_async_flush(new_buffer, %{state | buffer: [], buffer_count: 0})
        else
          {:noreply, %{state | buffer: new_buffer, buffer_count: new_count}}
        end
    end
  end

  @impl true
  def handle_info(:flush, state) do
    schedule_flush(state.opts[:flush_interval] || @default_flush_interval)

    cond do
      state.circuit_open? ->
        # Circuit open — discard buffer to free memory
        {:noreply, %{state | buffer: [], buffer_count: 0}}

      state.buffer_count == 0 ->
        {:noreply, state}

      state.flush_in_flight? ->
        # A flush is already running — keep buffering
        {:noreply, state}

      true ->
        spawn_async_flush(state.buffer, %{state | buffer: [], buffer_count: 0})
    end
  end

  # Flush succeeded — reset failure tracking
  @impl true
  def handle_info({:flush_result, ref, :ok}, %{flush_ref: ref} = state) do
    if state.dropped_count > 0 do
      Logger.info(
        "[OpenObserveSender] Flush succeeded; #{state.dropped_count} logs were dropped while buffer was full"
      )
    end

    {:noreply,
     %{
       state
       | flush_in_flight?: false,
         flush_ref: nil,
         consecutive_failures: 0,
         circuit_open?: false,
         dropped_count: 0
     }}
  end

  # Flush failed — increment failure count, maybe open circuit
  @impl true
  def handle_info({:flush_result, ref, {:error, reason}}, %{flush_ref: ref} = state) do
    failures = state.consecutive_failures + 1

    if failures == 1 do
      Logger.warning("[OpenObserveSender] Flush failed: #{inspect(reason)}")
    end

    handle_flush_failure(state, failures)
  end

  # Stale flush result (from a timed-out or superseded flush) — ignore
  @impl true
  def handle_info({:flush_result, _stale_ref, _result}, state), do: {:noreply, state}

  # Flush timed out — the task didn't report back in time
  @impl true
  def handle_info({:flush_timeout, ref}, %{flush_ref: ref} = state) do
    Logger.warning("[OpenObserveSender] Flush timed out after #{@flush_timeout_ms}ms")

    failures = state.consecutive_failures + 1
    handle_flush_failure(%{state | flush_in_flight?: false, flush_ref: nil}, failures)
  end

  # Stale timeout
  @impl true
  def handle_info({:flush_timeout, _stale_ref}, state), do: {:noreply, state}

  # Circuit breaker reset — try to resume logging
  @impl true
  def handle_info(:circuit_reset, state) do
    Logger.info("[OpenObserveSender] Circuit breaker reset — resuming log ingestion")
    {:noreply, %{state | circuit_open?: false}}
  end

  @impl true
  def handle_info(_msg, state), do: {:noreply, state}

  # ---------------------------------------------------------------------------
  # Private: flush failure / circuit breaker
  # ---------------------------------------------------------------------------

  defp handle_flush_failure(state, failures) do
    state = %{state | flush_in_flight?: false, flush_ref: nil, consecutive_failures: failures}

    if failures >= circuit_threshold(state.opts) do
      Logger.warning(
        "[OpenObserveSender] Circuit breaker opened after #{failures} consecutive failures. " <>
          "Dropping logs for #{div(circuit_reset_delay(state.opts), 1000)}s before retry."
      )

      schedule_circuit_reset(state.opts)
      {:noreply, %{state | circuit_open?: true, buffer: [], buffer_count: 0}}
    else
      {:noreply, state}
    end
  end

  # ---------------------------------------------------------------------------
  # Private: async flush (3. Non-blocking HTTP via Task.Supervisor)
  # ---------------------------------------------------------------------------

  defp spawn_async_flush(entries, state) do
    opts = state.opts
    ref = make_ref()

    Task.Supervisor.start_child(Voile.TaskSupervisor, fn ->
      result =
        try do
          Req.post(opts[:url],
            json: Enum.reverse(entries),
            auth: {:basic, "#{opts[:username]}:#{opts[:password]}"},
            receive_timeout: 5_000
          )
          |> case do
            {:ok, %Req.Response{status: status}} when status in 200..299 ->
              :ok

            {:ok, %Req.Response{status: status, body: body}} ->
              {:error, "HTTP #{status}: #{inspect(body)}"}

            {:error, exception} when is_exception(exception) ->
              {:error, Exception.message(exception)}

            {:error, reason} ->
              {:error, inspect(reason)}
          end
        rescue
          e ->
            {:error, Exception.message(e)}
        catch
          kind, reason ->
            {:error, {kind, reason}}
        end

      send(__MODULE__, {:flush_result, ref, result})
    end)

    # Safety timeout in case the task crashes without sending a result
    Process.send_after(self(), {:flush_timeout, ref}, @flush_timeout_ms)

    {:noreply, %{state | flush_in_flight?: true, flush_ref: ref}}
  end

  # ---------------------------------------------------------------------------
  # Private: formatting (4. Truncated inspect to cap entry size)
  # ---------------------------------------------------------------------------

  defp format_entry(%{level: level, msg: msg, meta: meta}) do
    %{
      "_timestamp" => format_time(Map.get(meta, :time)),
      "level" => to_string(level),
      "log" => format_message(msg),
      "application" => meta |> Map.get(:application, :voile) |> to_string(),
      "module" => meta |> Map.get(:module) |> inspect(),
      "function" => Map.get(meta, :function),
      "line" => Map.get(meta, :line),
      "node" => node() |> to_string(),
      "request_id" => Map.get(meta, :request_id),
      "trace_id" => Map.get(meta, :"logging.googleapis.com/trace"),
      "span_id" => Map.get(meta, :"logging.googleapis.com/spanId")
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  end

  defp format_message({:string, chardata}), do: IO.iodata_to_binary(chardata)
  defp format_message({:report, report}), do: inspect(report, @inspect_opts)

  defp format_message({:format, fmt, args}) do
    :io_lib.format(fmt, args) |> IO.iodata_to_binary()
  end

  defp format_message(other), do: inspect(other, @inspect_opts)

  # OTP logger meta :time is microseconds since Unix epoch
  defp format_time(nil), do: DateTime.utc_now() |> DateTime.to_iso8601()

  defp format_time(microseconds) do
    DateTime.from_unix!(microseconds, :microsecond) |> DateTime.to_iso8601()
  end

  # ---------------------------------------------------------------------------
  # Private: scheduling & config helpers
  # ---------------------------------------------------------------------------

  defp schedule_flush(interval) do
    Process.send_after(self(), :flush, interval)
  end

  defp schedule_circuit_reset(opts) do
    Process.send_after(self(), :circuit_reset, circuit_reset_delay(opts))
  end

  defp batch_size(opts), do: opts[:batch_size] || @default_batch_size
  defp max_buffer_size(opts), do: opts[:max_buffer_size] || @default_max_buffer_size
  defp circuit_threshold(opts), do: opts[:circuit_threshold] || @default_circuit_threshold

  defp circuit_reset_delay(opts), do: opts[:circuit_reset_delay] || @default_circuit_reset_delay
end
