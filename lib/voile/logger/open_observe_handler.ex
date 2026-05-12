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
        flush_interval: 5_000

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

  @handler_id :voile_open_observe
  @default_batch_size 100
  @default_flush_interval 5_000

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
    # Register the OTP logger handler now that we are running
    :logger.add_handler(@handler_id, Voile.Logger.OpenObserveHandler, %{level: :info})

    schedule_flush(opts[:flush_interval] || @default_flush_interval)
    {:ok, %{buffer: [], opts: opts}}
  end

  @impl true
  def terminate(_reason, _state) do
    :logger.remove_handler(@handler_id)
    :ok
  end

  @impl true
  def handle_cast({:log, log_event}, state) do
    entry = format_entry(log_event)
    buffer = [entry | state.buffer]
    batch_size = state.opts[:batch_size] || @default_batch_size

    if length(buffer) >= batch_size do
      flush_buffer(Enum.reverse(buffer), state.opts)
      {:noreply, %{state | buffer: []}}
    else
      {:noreply, %{state | buffer: buffer}}
    end
  end

  @impl true
  def handle_info(:flush, state) do
    unless state.buffer == [] do
      flush_buffer(Enum.reverse(state.buffer), state.opts)
    end

    schedule_flush(state.opts[:flush_interval] || @default_flush_interval)
    {:noreply, %{state | buffer: []}}
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp flush_buffer(entries, opts) do
    Req.post(opts[:url],
      json: entries,
      auth: {opts[:username], opts[:password]},
      receive_timeout: 10_000
    )
  rescue
    _ -> :ok
  catch
    _, _ -> :ok
  end

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
  defp format_message({:report, report}), do: inspect(report)

  defp format_message({:format, fmt, args}) do
    :io_lib.format(fmt, args) |> IO.iodata_to_binary()
  end

  defp format_message(other), do: inspect(other)

  # OTP logger meta :time is microseconds since Unix epoch
  defp format_time(nil), do: DateTime.utc_now() |> DateTime.to_iso8601()

  defp format_time(microseconds) do
    DateTime.from_unix!(microseconds, :microsecond) |> DateTime.to_iso8601()
  end

  defp schedule_flush(interval) do
    Process.send_after(self(), :flush, interval)
  end
end
