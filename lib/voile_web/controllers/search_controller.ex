defmodule VoileWeb.SearchController do
  use VoileWeb, :controller

  alias Voile.Schema.Search
  alias Voile.Schema.Accounts
  alias Voile.Utils.SearchHelper
  alias Voile.Analytics.SearchAnalytics

  @doc """
  Handles search requests from the web interface
  """
  def index(conn, params) do
    user_role = SearchHelper.get_user_role(conn)
    query = SearchHelper.sanitize_query(Map.get(params, "q", ""))
    search_type = Map.get(params, "type", "universal")
    page = Map.get(params, "page", "1") |> String.to_integer()

    # Record search analytics
    current_user = conn.assigns[:current_user]
    if String.trim(query) != "" do
      SearchAnalytics.record_search(query, current_user && current_user.id, %{
        type: search_type,
        source: "web_search"
      })
    end

    results = if String.trim(query) != "" do
      case search_type do
        "collections" ->
          Search.search_collections(query, user_role, %{page: page})
        "items" ->
          Search.search_items(query, user_role, %{page: page})
        "universal" ->
          Search.universal_search(query, user_role, %{page: page})
      end
    else
      %{collections: %{results: [], total: 0}, items: %{results: [], total: 0}, total_results: 0}
    end

    render(conn, :index, %{
      results: results,
      query: query,
      search_type: search_type,
      page: page
    })
  end

  @doc """
  Handles advanced search requests
  """
  def advanced(conn, %{"search" => search_params} = params) do
    user_role = SearchHelper.get_user_role(conn)
    search_type = Map.get(params, "type", "both") |> String.to_atom()
    page = Map.get(params, "page", "1") |> String.to_integer()

    # Clean and sanitize search parameters
    cleaned_params =
      search_params
      |> Enum.reduce(%{}, fn {key, value}, acc ->
        sanitized_value = SearchHelper.sanitize_query(value)
        if sanitized_value != "", do: Map.put(acc, String.to_atom(key), sanitized_value), else: acc
      end)

    # Record advanced search analytics
    current_user = conn.assigns[:current_user]
    if map_size(cleaned_params) > 0 do
      search_query = Enum.map(cleaned_params, fn {k, v} -> "#{k}:#{v}" end) |> Enum.join(" ")
      SearchAnalytics.record_search(search_query, current_user && current_user.id, %{
        type: "advanced_search",
        params: cleaned_params,
        search_type: search_type
      })
    end

    results = if map_size(cleaned_params) > 0 do
      Search.advanced_search(cleaned_params, user_role, %{
        page: page,
        type: search_type
      })
    else
      %{collections: %{results: [], total: 0}, items: %{results: [], total: 0}, total_results: 0}
    end

    render(conn, :advanced, %{
      results: results,
      search_params: search_params,
      search_type: Atom.to_string(search_type),
      page: page
    })
  end

  def advanced(conn, params) do
    render(conn, :advanced, %{
      results: %{collections: %{results: [], total: 0}, items: %{results: [], total: 0}, total_results: 0},
      search_params: %{},
      search_type: "both",
      page: 1
    })
  end

  @doc """
  API endpoint for AJAX search requests
  """
  def api_search(conn, params) do
    user_role = SearchHelper.get_user_role(conn)
    query = SearchHelper.sanitize_query(Map.get(params, "q", ""))
    search_type = Map.get(params, "type", "universal")
    page = Map.get(params, "page", "1") |> String.to_integer()

    # Record API search analytics
    current_user = conn.assigns[:current_user]
    if String.trim(query) != "" do
      SearchAnalytics.record_search(query, current_user && current_user.id, %{
        type: search_type,
        source: "api_search"
      })
    end

    results = if String.trim(query) != "" do
      case search_type do
        "collections" ->
          Search.search_collections(query, user_role, %{page: page, per_page: 5})
        "items" ->
          Search.search_items(query, user_role, %{page: page, per_page: 10})
        "universal" ->
          Search.universal_search(query, user_role, %{
            page: page,
            collections_per_page: 3,
            items_per_page: 7
          })
      end
    else
      %{collections: %{results: [], total: 0}, items: %{results: [], total: 0}, total_results: 0}
    end

    json(conn, %{
      success: true,
      results: serialize_results(results, search_type),
      query: query,
      search_type: search_type
    })
  end

  @doc """
  Quick search suggestions for autocomplete
  """
  def suggestions(conn, %{"q" => query}) when byte_size(query) >= 2 do
    user_role = SearchHelper.get_user_role(conn)
    sanitized_query = SearchHelper.sanitize_query(query)

    suggestions = if String.trim(sanitized_query) != "" do
      SearchHelper.fetch_suggestions(sanitized_query, user_role, 8)
    else
      []
    end

    json(conn, %{suggestions: suggestions})
  end

  def suggestions(conn, _params) do
    json(conn, %{suggestions: []})
  end

  # Private helper functions

  defp serialize_results(results, "universal") do
    %{
      collections: serialize_collections(results.collections.results),
      items: serialize_items(results.items.results),
      total_results: results.total_results,
      collections_total: results.collections.total,
      items_total: results.items.total
    }
  end

  defp serialize_results(results, "collections") do
    %{
      collections: serialize_collections(results.results),
      total: results.total,
      page: results.page,
      total_pages: results.total_pages
    }
  end

  defp serialize_results(results, "items") do
    %{
      items: serialize_items(results.results),
      total: results.total,
      page: results.page,
      total_pages: results.total_pages
    }
  end

  defp serialize_collections(collections) do
    Enum.map(collections, fn collection ->
      %{
        id: collection.id,
        title: collection.title,
        description: collection.description,
        collection_type: collection.collection_type,
        status: collection.status,
        access_level: collection.access_level,
        creator: collection.mst_creator && collection.mst_creator.name,
        items_count: length(collection.items || [])
      }
    end)
  end

  defp serialize_items(items) do
    Enum.map(items, fn item ->
      %{
        id: item.id,
        item_code: item.item_code,
        inventory_code: item.inventory_code,
        location: item.location,
        status: item.status,
        condition: item.condition,
        availability: item.availability,
        collection: %{
          id: item.collection.id,
          title: item.collection.title
        }
      }
    end)
  end
end
