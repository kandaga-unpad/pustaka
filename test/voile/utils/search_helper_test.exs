defmodule Voile.Utils.SearchHelperTest do
  use ExUnit.Case, async: true

  alias Voile.Utils.SearchHelper

  describe "build_filters_from_params/1" do
    test "builds empty map from empty params" do
      assert SearchHelper.build_filters_from_params(%{}) == %{}
    end

    test "includes status filter when present" do
      filters = SearchHelper.build_filters_from_params(%{"status" => "published"})
      assert filters == %{status: "published"}
    end

    test "includes availability filter when present" do
      filters = SearchHelper.build_filters_from_params(%{"availability" => "available"})
      assert filters == %{availability: "available"}
    end

    test "includes condition filter when present" do
      filters = SearchHelper.build_filters_from_params(%{"condition" => "good"})
      assert filters == %{condition: "good"}
    end

    test "includes collection_type filter when present" do
      filters = SearchHelper.build_filters_from_params(%{"collection_type" => "book"})
      assert filters == %{collection_type: "book"}
    end

    test "includes access_level filter when present" do
      filters = SearchHelper.build_filters_from_params(%{"access_level" => "public"})
      assert filters == %{access_level: "public"}
    end

    test "includes location filter when present" do
      filters = SearchHelper.build_filters_from_params(%{"location" => "main"})
      assert filters == %{location: "main"}
    end

    test "excludes empty string filter values" do
      filters =
        SearchHelper.build_filters_from_params(%{"status" => "", "availability" => "available"})

      assert filters == %{availability: "available"}
      refute Map.has_key?(filters, :status)
    end

    test "ignores unrecognized filter keys" do
      filters = SearchHelper.build_filters_from_params(%{"unknown_key" => "value"})
      assert filters == %{}
    end

    test "builds multiple filters at once" do
      params = %{
        "status" => "published",
        "availability" => "available",
        "condition" => "good"
      }

      filters = SearchHelper.build_filters_from_params(params)

      assert filters == %{
               status: "published",
               availability: "available",
               condition: "good"
             }
    end
  end

  describe "sanitize_query/1" do
    test "trims whitespace from query" do
      assert SearchHelper.sanitize_query("  hello  ") == "hello"
    end

    test "removes special characters" do
      assert SearchHelper.sanitize_query("hello!@#$%^&*()world") == "helloworld"
    end

    test "preserves letters, digits, spaces, hyphens and quotes" do
      assert SearchHelper.sanitize_query("hello world 123 - test") == "hello world 123 - test"
    end

    test "limits query to 200 characters" do
      long_query = String.duplicate("a", 250)
      result = SearchHelper.sanitize_query(long_query)
      assert String.length(result) == 200
    end

    test "returns empty string for nil input" do
      assert SearchHelper.sanitize_query(nil) == ""
    end

    test "returns empty string for non-string input" do
      assert SearchHelper.sanitize_query(42) == ""
      assert SearchHelper.sanitize_query([]) == ""
    end

    test "preserves single quotes" do
      assert SearchHelper.sanitize_query("don't stop") == "don't stop"
    end

    test "preserves double quotes" do
      assert SearchHelper.sanitize_query(~s("exact match")) == ~s("exact match")
    end
  end

  describe "search_url/2" do
    test "builds basic search URL with query" do
      url = SearchHelper.search_url("elixir")
      assert url =~ "/search"
      assert url =~ "q=elixir"
      assert url =~ "type=universal"
    end

    test "builds advanced search URL when advanced: true" do
      url = SearchHelper.search_url("elixir", %{advanced: true})
      assert url =~ "/search/advanced"
      assert url =~ "q=elixir"
    end

    test "includes page parameter when page > 1" do
      url = SearchHelper.search_url("elixir", %{page: 2})
      assert url =~ "page=2"
    end

    test "omits page parameter when page is 1 (default)" do
      url = SearchHelper.search_url("elixir", %{page: 1})
      refute url =~ "page="
    end

    test "uses custom type when provided" do
      url = SearchHelper.search_url("elixir", %{type: "books"})
      assert url =~ "type=books"
    end

    test "URL-encodes query with spaces" do
      url = SearchHelper.search_url("hello world")
      # URI.encode_query encodes spaces as +
      assert url =~ "hello+world" or url =~ "hello%20world"
    end
  end

  describe "format_result_count/1" do
    test "returns 'No results' for 0" do
      assert SearchHelper.format_result_count(0) == "No results"
    end

    test "returns '1 result' for 1" do
      assert SearchHelper.format_result_count(1) == "1 result"
    end

    test "returns 'N results' for count between 2 and 1000" do
      assert SearchHelper.format_result_count(42) == "42 results"
      assert SearchHelper.format_result_count(999) == "999 results"
    end

    test "returns 'NK+ results' for count greater than 1000" do
      assert SearchHelper.format_result_count(1500) == "1K+ results"
      assert SearchHelper.format_result_count(5000) == "5K+ results"
    end
  end

  describe "extract_search_terms/1" do
    test "extracts individual words from query" do
      terms = SearchHelper.extract_search_terms("hello world test")
      assert "hello" in terms
      assert "world" in terms
      assert "test" in terms
    end

    test "converts terms to lowercase" do
      terms = SearchHelper.extract_search_terms("Hello World")
      assert "hello" in terms
      assert "world" in terms
    end

    test "rejects terms shorter than 2 characters" do
      terms = SearchHelper.extract_search_terms("a be cat")
      refute "a" in terms
      assert "be" in terms
      assert "cat" in terms
    end

    test "limits to 5 terms maximum" do
      terms = SearchHelper.extract_search_terms("one two three four five six seven eight")
      assert length(terms) <= 5
    end

    test "returns empty list for nil input" do
      assert SearchHelper.extract_search_terms(nil) == []
    end

    test "returns empty list for non-string input" do
      assert SearchHelper.extract_search_terms(42) == []
    end

    test "returns empty list for empty string" do
      assert SearchHelper.extract_search_terms("") == []
    end

    test "handles multiple whitespace between words" do
      terms = SearchHelper.extract_search_terms("hello   world")
      assert "hello" in terms
      assert "world" in terms
    end
  end
end
