defmodule VoileWeb.UserPresence do
  @moduledoc """
  Tracks connected users across the application using ETS.
  Tracks all connections and separately counts authenticated users.
  """

  @ets_table :user_presence

  def track_user(user) do
    ensure_ets_table()

    is_authenticated = not is_nil(user)

    connection_data = %{
      connection_id: make_ref(),
      socket_pid: self(),
      online_at: DateTime.utc_now(),
      node: node(),
      is_authenticated: is_authenticated,
      user_id: if(is_authenticated, do: user.id, else: nil),
      email: if(is_authenticated, do: user.email, else: nil),
      fullname: if(is_authenticated, do: user.fullname, else: nil)
    }

    :ets.insert(@ets_table, {connection_id(), connection_data})
  end

  def get_connection_stats do
    try do
      connections = :ets.tab2list(@ets_table)

      total_connections = length(connections)

      authenticated_connections =
        connections
        |> Enum.filter(fn {_key, presence} ->
          presence.is_authenticated == true and Process.alive?(presence.socket_pid)
        end)
        |> length()

      unauthenticated_connections = total_connections - authenticated_connections

      %{
        total: total_connections,
        authenticated: authenticated_connections,
        unauthenticated: unauthenticated_connections
      }
    rescue
      _ -> %{total: 0, authenticated: 0, unauthenticated: 0}
    end
  end

  defp connection_id do
    make_ref()
  end

  defp ensure_ets_table do
    case :ets.whereis(@ets_table) do
      :undefined ->
        :ets.new(@ets_table, [:bag, :public, :named_table])

      _ ->
        :ok
    end
  end
end
