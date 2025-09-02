defmodule Voile.Analytics.SearchAnalytics do
  @moduledoc """
  Analytics module for tracking search patterns and usage statistics.
  Provides insights into user search behavior and popular content.
  """

  import Ecto.Query, warn: false
  alias Voile.Repo
  alias Voile.Accounts.User

  @doc """
  Records a search query for analytics purposes
  """
  def record_search(query, user_id \\ nil, metadata \\ %{}) do
    # Store in a simple ETS table for now, could be moved to database later
    table_name = :search_analytics

    # Ensure ETS table exists
    case :ets.whereis(table_name) do
      :undefined ->
        :ets.new(table_name, [:named_table, :public, :bag])
      _ -> :ok
    end

    timestamp = DateTime.utc_now()
    entry = {
      query,
      user_id,
      timestamp,
      metadata
    }

    :ets.insert(table_name, {timestamp, entry})
    :ok
  end

  @doc """
  Gets search statistics for dashboard display
  """
  def get_search_stats(opts \\ []) do
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
        today_start = DateTime.beginning_of_day(now)

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
      :undefined -> []

      _ ->
        cutoff = DateTime.utc_now() |> DateTime.add(-days_back, :day)

        :ets.tab2list(table_name)
        |> Enum.filter(fn {timestamp, _entry} ->
          DateTime.compare(timestamp, cutoff) in [:gt, :eq]
        end)
        |> Enum.map(fn {_timestamp, {query, _user_id, _timestamp, _metadata}} -> query end)
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
      :undefined -> %{}

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
  Clears old search analytics data (cleanup task)
  """
  def cleanup_old_data(days_to_keep \\ 30) do
    table_name = :search_analytics

    case :ets.whereis(table_name) do
      :undefined -> :ok

      _ ->
        cutoff = DateTime.utc_now() |> DateTime.add(-days_to_keep, :day)

        :ets.tab2list(table_name)
        |> Enum.each(fn {timestamp, entry} = record ->
          if DateTime.compare(timestamp, cutoff) == :lt do
            :ets.delete_object(table_name, record)
          end
        end)

        :ok
    end
  end

  # Private functions

  defp get_user_name(user_id) do
    case Repo.get(User, user_id) do
      %User{username: username} -> username
      %User{email: email} -> email
      _ -> "Unknown User"
    end
  end
end
