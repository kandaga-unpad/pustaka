defmodule Voile.Schema.SearchTest do
  use Voile.DataCase

  alias Voile.Schema.Search
  alias Voile.Schema.Catalog
  alias Voile.Schema.Accounts

  describe "search_collections/3" do
    test "returns collections matching title" do
      # This would need proper test data setup
      # For now, this is a placeholder test structure
      assert %{results: results, total: total} = Search.search_collections("test", "patron", %{})
      assert is_list(results)
      assert is_integer(total)
    end

    test "respects user role access control" do
      # Test that patrons only see public collections
      patron_results = Search.search_collections("test", "patron", %{})
      librarian_results = Search.search_collections("test", "librarian", %{})

      # Librarians should potentially see more results
      assert librarian_results.total >= patron_results.total
    end

    test "handles pagination correctly" do
      results_page_1 = Search.search_collections("test", "patron", %{page: 1, per_page: 5})
      results_page_2 = Search.search_collections("test", "patron", %{page: 2, per_page: 5})

      assert results_page_1.page == 1
      assert results_page_2.page == 2
      assert length(results_page_1.results) <= 5
      assert length(results_page_2.results) <= 5
    end
  end

  describe "search_items/3" do
    test "returns items matching criteria" do
      assert %{results: results, total: total} = Search.search_items("test", "patron", %{})
      assert is_list(results)
      assert is_integer(total)
    end

    test "applies availability filters for patrons" do
      # Test that patrons only see available items
      results = Search.search_items("test", "patron", %{})

      # All results should be from available items only
      Enum.each(results.results, fn item ->
        assert item.availability in ["available", "reference"]
      end)
    end
  end

  describe "universal_search/3" do
    test "returns combined results from collections and items" do
      results = Search.universal_search("test", "patron", %{})

      assert Map.has_key?(results, :collections)
      assert Map.has_key?(results, :items)
      assert Map.has_key?(results, :total_results)
      assert results.total_results == results.collections.total + results.items.total
    end
  end

  describe "advanced_search/3" do
    test "searches with specific field criteria" do
      search_params = %{
        title: "science",
        creator: "author"
      }

      results = Search.advanced_search(search_params, "patron", %{type: :collections})

      assert Map.has_key?(results, :results)
      assert Map.has_key?(results, :total)
    end

    test "handles both collections and items search" do
      search_params = %{title: "test"}

      results = Search.advanced_search(search_params, "patron", %{type: :both})

      assert Map.has_key?(results, :collections)
      assert Map.has_key?(results, :items)
      assert Map.has_key?(results, :total_results)
    end
  end
end
