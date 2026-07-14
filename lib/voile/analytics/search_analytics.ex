defmodule Voile.Analytics.SearchAnalytics do
  @moduledoc """
  Analytics module for tracking search patterns and usage statistics.
  Provides insights into user search behavior and popular content.
  """

  import Ecto.Query, warn: false
  alias Voile.Repo
  alias Voile.Schema.Accounts.User

  @max_entries 10_000
  @cleanup_every 100

  @doc """
  Records a search query for analytics purposes.
  Periodically cleans up old entries to prevent unbounded ETS growth.
  """
  def record_search(query, user_id \\ nil, metadata \\ %{}) do
    table_name = :search_analytics

    ensure_ets_table(table_name)

    timestamp = DateTime.utc_now()

    entry = {
      query,
      user_id,
      timestamp,
      metadata
    }

    :ets.insert(table_name, {timestamp, entry})

    # Probabilistic cleanup — runs roughly every @cleanup_every inserts
    maybe_cleanup(table_name)

    :ok
  end

  @doc """
  Gets search statistics for dashboard display
  """
  def get_search_stats(_opts \\ []) do
    table_name = :search_analytics

    case :ets.whereis(table_name) do
      :undefined ->
        %{
          total_searches: 0,
          popular_queries: [],
          recent_activity: []
        }

      _ ->
        now = DateTime.utc_now()

        today_start = %DateTime{
          year: now.year,
          month: now.month,
          day: now.day,
          hour: 0,
          minute: 0,
          second: 0,
          microsecond: {0, 0},
          time_zone: now.time_zone,
          zone_abbr: now.zone_abbr,
          utc_offset: now.utc_offset,
          std_offset: now.std_offset
        }

        # Get all entries from today
        all_entries = :ets.tab2list(table_name)

        today_entries =
          all_entries
          |> Enum.filter(fn {timestamp, _entry} ->
            DateTime.compare(timestamp, today_start) in [:gt, :eq]
          end)
          |> Enum.map(fn {_timestamp, entry} -> entry end)

        # Calculate statistics
        total_searches = length(today_entries)

        popular_queries =
          today_entries
          |> Enum.map(fn {query, _user_id, _timestamp, _metadata} -> query end)
          |> Enum.frequencies()
          |> Enum.sort_by(fn {_query, count} -> count end, :desc)
          |> Enum.take(5)

        recent_activity =
          today_entries
          |> Enum.sort_by(fn {_query, _user_id, timestamp, _metadata} -> timestamp end, :desc)
          |> Enum.take(5)
          |> Enum.map(fn {query, user_id, timestamp, _metadata} ->
            user_name = if user_id, do: get_user_name(user_id), else: "Anonymous"
            time_str = Calendar.strftime(timestamp, "%H:%M")
            "#{time_str} - #{user_name} searched '#{query}'"
          end)

        %{
          total_searches: total_searches,
          popular_queries: popular_queries,
          recent_activity: recent_activity
        }
    end
  end

  @doc """
  Gets popular search terms over a given period
  """
  def get_popular_searches(days_back \\ 7, limit \\ 10) do
    table_name = :search_analytics

    case :ets.whereis(table_name) do
      :undefined ->
        []

      _ ->
        cutoff = DateTime.utc_now() |> DateTime.add(-days_back, :day)

        :ets.tab2list(table_name)
        |> Enum.filter(fn {timestamp, _entry} ->
          DateTime.compare(timestamp, cutoff) in [:gt, :eq]
        end)
        |> Enum.map(fn {_timestamp, {query, _user_id, _entry_timestamp, _metadata}} -> query end)
        |> Enum.frequencies()
        |> Enum.sort_by(fn {_query, count} -> count end, :desc)
        |> Enum.take(limit)
    end
  end

  @doc """
  Gets search trends by hour of day
  """
  def get_search_trends(days_back \\ 7) do
    table_name = :search_analytics

    case :ets.whereis(table_name) do
      :undefined ->
        %{}

      _ ->
        cutoff = DateTime.utc_now() |> DateTime.add(-days_back, :day)

        :ets.tab2list(table_name)
        |> Enum.filter(fn {timestamp, _entry} ->
          DateTime.compare(timestamp, cutoff) in [:gt, :eq]
        end)
        |> Enum.map(fn {_timestamp, {_query, _user_id, timestamp, _metadata}} ->
          timestamp.hour
        end)
        |> Enum.frequencies()
        |> Enum.into(%{})
    end
  end

  @doc """
  Clears old search analytics data (cleanup task).
  Also caps total entries to @max_entries.
  """
  def cleanup_old_data(days_to_keep \\ 30) do
    table_name = :search_analytics

    case :ets.whereis(table_name) do
      :undefined ->
        :ok

      _ ->
        cutoff = DateTime.utc_now() |> DateTime.add(-days_to_keep, :day)

        :ets.tab2list(table_name)
        |> Enum.each(fn {timestamp, _entry} = record ->
          if DateTime.compare(timestamp, cutoff) == :lt do
            :ets.delete_object(table_name, record)
          end
        end)

        # Also enforce a hard cap on total entries
        cap_entries(table_name)

        :ok
    end
  end

  # Private functions

  defp ensure_ets_table(table_name) do
    case :ets.whereis(table_name) do
      :undefined ->
        :ets.new(table_name, [:named_table, :public, :bag])

      _ ->
        :ok
    end
  end

  defp maybe_cleanup(_table_name) do
    if :rand.uniform(@cleanup_every) == 1 do
      spawn(fn -> cleanup_old_data(30) end)
    end
  end

  defp cap_entries(table_name) do
    info = :ets.info(table_name, :size)

    if info > @max_entries do
      excess = info - @max_entries

      :ets.tab2list(table_name)
      |> Enum.sort_by(fn {timestamp, _} -> timestamp end, :asc)
      |> Enum.take(excess)
      |> Enum.each(&:ets.delete_object(table_name, &1))
    end
  end

  defp get_user_name(user_id) do
    case Repo.get(User, user_id) do
      %User{username: username} -> username
      %User{email: email} -> email
      _ -> "Unknown User"
    end
  end
end
