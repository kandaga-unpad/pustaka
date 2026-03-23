defmodule Voile.Analytics.SearchAnalyticsTest do
  # Must run with async: false because tests manipulate shared ETS state.
  # The :search_analytics ETS table is a global named table, so concurrent
  # test processes would interfere with each other's data.
  use ExUnit.Case, async: false

  alias Voile.Analytics.SearchAnalytics

  # Days in the past for "old" test entries - must be beyond the default 30-day cleanup window
  @old_entry_days_ago 40

  # Clean up the ETS table before each test to ensure isolation
  setup do
    # Delete the ETS table if it exists to start fresh
    case :ets.whereis(:search_analytics) do
      :undefined -> :ok
      tid -> :ets.delete_all_objects(tid)
    end

    :ok
  end

  describe "record_search/3" do
    test "records a search query and returns :ok" do
      result = SearchAnalytics.record_search("elixir programming")
      assert result == :ok
    end

    test "records a search with user_id and returns :ok" do
      result = SearchAnalytics.record_search("phoenix framework", "user-123")
      assert result == :ok
    end

    test "records a search with metadata and returns :ok" do
      result = SearchAnalytics.record_search("books", "user-456", %{source: "homepage"})
      assert result == :ok
    end

    test "creates the ETS table if it does not exist" do
      # Ensure ETS table doesn't exist first
      case :ets.whereis(:search_analytics) do
        :undefined -> :ok
        tid -> :ets.delete(tid)
      end

      SearchAnalytics.record_search("test query")

      # Table should now exist
      assert :ets.whereis(:search_analytics) != :undefined
    end

    test "records multiple searches" do
      SearchAnalytics.record_search("query one")
      SearchAnalytics.record_search("query two")
      SearchAnalytics.record_search("query three")

      stats = SearchAnalytics.get_search_stats()
      assert stats.total_searches >= 3
    end
  end

  describe "get_search_stats/1" do
    test "returns zero stats when no searches recorded" do
      # ETS table cleared in setup
      stats = SearchAnalytics.get_search_stats()

      assert stats.total_searches == 0
      assert stats.popular_queries == []
      assert stats.recent_activity == []
    end

    test "returns zero stats when ETS table does not exist" do
      case :ets.whereis(:search_analytics) do
        :undefined -> :ok
        tid -> :ets.delete(tid)
      end

      stats = SearchAnalytics.get_search_stats()

      assert stats.total_searches == 0
      assert stats.popular_queries == []
      assert stats.recent_activity == []
    end

    test "counts searches recorded today" do
      SearchAnalytics.record_search("test query 1")
      SearchAnalytics.record_search("test query 2")
      SearchAnalytics.record_search("test query 1")

      stats = SearchAnalytics.get_search_stats()

      # Total searches includes all searches from today
      assert stats.total_searches >= 3
    end

    test "reports popular queries with counts" do
      SearchAnalytics.record_search("popular query")
      SearchAnalytics.record_search("popular query")
      SearchAnalytics.record_search("popular query")
      SearchAnalytics.record_search("less popular")

      stats = SearchAnalytics.get_search_stats()

      # popular_queries is a list of {query, count}
      assert is_list(stats.popular_queries)

      popular_map = Enum.into(stats.popular_queries, %{})
      assert popular_map["popular query"] == 3
      assert popular_map["less popular"] == 1
    end

    test "returns at most 5 popular queries" do
      Enum.each(1..10, fn i ->
        Enum.each(1..i, fn _ -> SearchAnalytics.record_search("query #{i}") end)
      end)

      stats = SearchAnalytics.get_search_stats()
      assert length(stats.popular_queries) <= 5
    end

    test "returns recent_activity as list of strings" do
      SearchAnalytics.record_search("recent search")

      stats = SearchAnalytics.get_search_stats()

      assert is_list(stats.recent_activity)

      Enum.each(stats.recent_activity, fn activity ->
        assert is_binary(activity)
      end)
    end

    test "recent_activity entries include the search query" do
      SearchAnalytics.record_search("my search term")

      stats = SearchAnalytics.get_search_stats()

      activity_text = Enum.join(stats.recent_activity, " ")
      assert activity_text =~ "my search term"
    end

    test "returns at most 5 recent activities" do
      Enum.each(1..10, fn i ->
        SearchAnalytics.record_search("search #{i}")
        # Small sleep to ensure different timestamps
        Process.sleep(1)
      end)

      stats = SearchAnalytics.get_search_stats()
      assert length(stats.recent_activity) <= 5
    end
  end

  describe "get_popular_searches/2" do
    test "returns empty list when ETS table does not exist" do
      case :ets.whereis(:search_analytics) do
        :undefined -> :ok
        tid -> :ets.delete(tid)
      end

      assert SearchAnalytics.get_popular_searches() == []
    end

    test "returns empty list when no recent searches" do
      result = SearchAnalytics.get_popular_searches(7, 10)
      assert result == []
    end

    test "returns popular searches within the given days_back window" do
      SearchAnalytics.record_search("trending topic")
      SearchAnalytics.record_search("trending topic")

      popular = SearchAnalytics.get_popular_searches(7)

      assert is_list(popular)
      # [{query, count}, ...]
      queries = Enum.map(popular, fn {query, _count} -> query end)
      assert "trending topic" in queries
    end

    test "limits results to specified limit" do
      Enum.each(1..20, fn i ->
        SearchAnalytics.record_search("topic #{i}")
      end)

      popular = SearchAnalytics.get_popular_searches(7, 5)
      assert length(popular) <= 5
    end

    test "orders results by count descending" do
      # Record "high count" 5 times and "low count" 1 time
      Enum.each(1..5, fn _ -> SearchAnalytics.record_search("high count") end)
      SearchAnalytics.record_search("low count")

      popular = SearchAnalytics.get_popular_searches(7, 10)

      assert length(popular) >= 2
      [{top_query, top_count} | _] = popular
      assert top_query == "high count"
      assert top_count == 5
    end
  end

  describe "get_search_trends/1" do
    test "returns empty map when ETS table does not exist" do
      case :ets.whereis(:search_analytics) do
        :undefined -> :ok
        tid -> :ets.delete(tid)
      end

      assert SearchAnalytics.get_search_trends() == %{}
    end

    test "returns empty map when no recent searches" do
      result = SearchAnalytics.get_search_trends(7)
      assert result == %{}
    end

    test "returns hour-based frequency map" do
      SearchAnalytics.record_search("morning search")

      trends = SearchAnalytics.get_search_trends(7)

      assert is_map(trends)
      # Keys should be integers (hours 0-23)
      Enum.each(trends, fn {hour, count} ->
        assert is_integer(hour)
        assert hour >= 0 and hour <= 23
        assert is_integer(count)
        assert count > 0
      end)
    end

    test "accumulates multiple searches in the same hour" do
      SearchAnalytics.record_search("search 1")
      SearchAnalytics.record_search("search 2")
      SearchAnalytics.record_search("search 3")

      trends = SearchAnalytics.get_search_trends(7)

      total = Enum.reduce(trends, 0, fn {_hour, count}, acc -> acc + count end)
      assert total >= 3
    end
  end

  describe "cleanup_old_data/1" do
    test "returns :ok when ETS table does not exist" do
      case :ets.whereis(:search_analytics) do
        :undefined -> :ok
        tid -> :ets.delete(tid)
      end

      assert SearchAnalytics.cleanup_old_data(30) == :ok
    end

    test "returns :ok when table exists" do
      SearchAnalytics.record_search("test")
      assert SearchAnalytics.cleanup_old_data(30) == :ok
    end

    test "removes entries older than days_to_keep" do
      # Record a search first (this will be recent)
      SearchAnalytics.record_search("recent search")

      # Manually insert an old entry into ETS
      table_name = :search_analytics
      old_timestamp = DateTime.utc_now() |> DateTime.add(-@old_entry_days_ago, :day)
      old_entry = {"old query", nil, old_timestamp, %{}}
      :ets.insert(table_name, {old_timestamp, old_entry})

      # Run cleanup for 30 days - should remove the 40-day-old entry
      SearchAnalytics.cleanup_old_data(30)

      # Check popular searches - old query should not appear in 7-day window
      popular = SearchAnalytics.get_popular_searches(7)
      queries = Enum.map(popular, fn {q, _} -> q end)
      refute "old query" in queries
    end
  end
end
