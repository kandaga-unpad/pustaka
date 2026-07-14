defmodule VoileWeb.UserPresence do
  @moduledoc """
  Tracks connected users across the application using ETS.
  Tracks all connections and separately counts authenticated users.

  Entries are keyed by the LiveView socket PID and use a `:set` table,
  so reconnecting with the same PID overwrites the previous entry instead
  of accumulating duplicates. Dead entries are cleaned up lazily whenever
  stats are queried.
  """

  @ets_table :user_presence

  def track_user(user) do
    ensure_ets_table()

    is_authenticated = not is_nil(user)
    pid = self()

    connection_data = %{
      socket_pid: pid,
      online_at: DateTime.utc_now(),
      node: node(),
      is_authenticated: is_authenticated,
      user_id: if(is_authenticated, do: user.id, else: nil),
      email: if(is_authenticated, do: user.email, else: nil),
      fullname: if(is_authenticated, do: user.fullname, else: nil)
    }

    :ets.insert(@ets_table, {pid, connection_data})
  end

  @doc """
  Remove the caller's entry from the presence table.
  Safe to call even if no entry exists.
  """
  def untrack_user(pid \\ self()) do
    try do
      :ets.delete(@ets_table, pid)
    rescue
      _ -> :ok
    end
  end

  def get_connection_stats do
    try do
      connections = :ets.tab2list(@ets_table)

      {alive, dead} =
        Enum.split_with(connections, fn {_pid, presence} ->
          Process.alive?(presence.socket_pid)
        end)

      # Lazily clean up dead entries
      Enum.each(dead, fn {pid, _} -> :ets.delete(@ets_table, pid) end)

      total = length(alive)

      authenticated =
        Enum.count(alive, fn {_pid, presence} -> presence.is_authenticated == true end)

      %{
        total: total,
        authenticated: authenticated,
        unauthenticated: total - authenticated
      }
    rescue
      _ -> %{total: 0, authenticated: 0, unauthenticated: 0}
    end
  end

  defp ensure_ets_table do
    case :ets.whereis(@ets_table) do
      :undefined ->
        :ets.new(@ets_table, [:set, :public, :named_table])

      _ ->
        :ok
    end
  end
end
