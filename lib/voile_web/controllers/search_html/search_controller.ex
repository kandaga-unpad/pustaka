defmodule VoileWeb.SearchController do
  use VoileWeb, :controller
  import Ecto.Query

  alias Voile.Search.Collections, as: SearchCollections
  alias Voile.Utils.SearchHelper
  alias Voile.Analytics.SearchAnalytics
  alias Voile.Schema.System.Node
  alias Voile.Repo

  # Helper function to get all nodes for the dropdown
  defp get_all_nodes do
    Repo.all(from n in Node, order_by: n.name)
  end

  @doc """
  Handles search requests from the web interface
  """
  def index(conn, params) do
    query = Map.get(params, "q", "")
    search_type = Map.get(params, "type", "universal")
    glam_type = Map.get(params, "glam_type", "quick")
    page = Map.get(params, "page", "1") |> String.to_integer()
    per_page = get_per_page_for_search_type(search_type)

    # Record search analytics
    current_user = conn.assigns[:current_user]

    if String.trim(query) != "" do
      SearchAnalytics.record_search(query, current_user && current_user.id, %{
        glam_type: glam_type,
        search_type: search_type,
        source: "web_search"
      })
    end

    # Use our new Search context
    search_params = %{
      "q" => query,
      "glam_type" => glam_type,
      "type" => search_type,
      "page" => Integer.to_string(page),
      "per_page" => Integer.to_string(per_page),
      "status" => "published"
    }

    # Transform results based on search type to match template expectations
    results =
      if String.trim(query) != "" do
        raw_results = SearchCollections.search_collections(search_params)

        case search_type do
          "universal" ->
            # For universal search, focus on collections only (items are part of collections)
            %{
              total_results: raw_results.total_count,
              collections: %{
                results: raw_results.results,
                total: raw_results.total_count,
                page: raw_results.current_page,
                total_pages: raw_results.total_pages,
                has_prev: raw_results.current_page > 1,
                has_next: raw_results.current_page < raw_results.total_pages
              }
            }

          "collections" ->
            # For collection-only search, provide flat structure with pagination
            %{
              results: raw_results.results,
              total_results: raw_results.total_count,
              page: raw_results.current_page,
              total_pages: raw_results.total_pages,
              has_prev: raw_results.current_page > 1,
              has_next: raw_results.current_page < raw_results.total_pages,
              per_page: per_page
            }
        end
      else
        # Empty results for empty query
        case search_type do
          "universal" ->
            %{
              total_results: 0,
              collections: %{
                results: [],
                total: 0,
                page: page,
                total_pages: 0,
                has_prev: false,
                has_next: false
              }
            }

          _ ->
            %{
              results: [],
              total_results: 0,
              page: page,
              total_pages: 0,
              has_prev: false,
              has_next: false,
              per_page: per_page
            }
        end
      end

    render(conn, :index, %{
      results: results,
      query: query,
      search_type: search_type,
      glam_type: glam_type,
      page: page
    })
  end

  @doc """
  Handles advanced search requests
  """
  def advanced(conn, %{"search" => search_params} = params) do
    _user_role = SearchHelper.get_user_role(conn)
    search_type = Map.get(params, "type", "both")
    glam_type = Map.get(params, "glam_type", "quick")
    page = Map.get(params, "page", "1") |> String.to_integer()
    per_page = get_per_page_for_search_type(search_type)

    # Clean and sanitize search parameters - keep as strings to avoid atom exhaustion
    cleaned_params =
      search_params
      |> Enum.reduce(%{}, fn {key, value}, acc ->
        sanitized_value = SearchHelper.sanitize_query(value)

        if sanitized_value != "",
          do: Map.put(acc, key, sanitized_value),
          else: acc
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

    results =
      if map_size(cleaned_params) > 0 do
        raw_results =
          SearchCollections.advanced_search(cleaned_params, :public, %{
            page: page,
            type: search_type,
            glam_type: glam_type,
            per_page: per_page
          })

        # Transform results based on search type to match template expectations
        case search_type do
          "collections" ->
            # For collection-only search, provide nested structure to match template expectations
            %{
              collections: %{
                results: raw_results.collections.results,
                total: raw_results.collections.total,
                page: raw_results.current_page,
                total_pages: raw_results.total_pages,
                has_prev: raw_results.current_page > 1,
                has_next: raw_results.current_page < raw_results.total_pages
              },
              total_results: raw_results.total_results,
              page: raw_results.current_page,
              per_page: raw_results.per_page
            }

          "both" ->
            # For both search (collections with GLAM filtering), provide nested structure
            %{
              collections: %{
                results: raw_results.collections.results,
                total: raw_results.collections.total,
                page: raw_results.current_page,
                total_pages: raw_results.total_pages,
                has_prev: raw_results.current_page > 1,
                has_next: raw_results.current_page < raw_results.total_pages
              },
              total_results: raw_results.total_results,
              page: raw_results.current_page,
              per_page: raw_results.per_page
            }

          _ ->
            # Default fallback for unknown search types - return nested structure
            %{
              collections: %{
                results: [],
                total: 0,
                page: page,
                total_pages: 0,
                has_prev: false,
                has_next: false
              },
              total_results: 0,
              page: page,
              per_page: per_page
            }
        end
      else
        # Empty results for empty search parameters - always return consistent nested structure
        %{
          collections: %{
            results: [],
            total: 0,
            page: page,
            total_pages: 0,
            has_prev: false,
            has_next: false
          },
          total_results: 0,
          page: page,
          per_page: per_page
        }
      end

    render(conn, :advanced, %{
      results: results,
      search_params: search_params,
      search_type: search_type,
      glam_type: glam_type,
      page: page,
      nodes: get_all_nodes()
    })
  end

  def advanced(conn, _params) do
    glam_type = Map.get(conn.params, "glam_type", "quick")

    render(conn, :advanced, %{
      results: %{
        collections: %{results: [], total: 0},
        items: %{results: [], total: 0},
        total_results: 0
      },
      search_params: %{},
      search_type: "both",
      glam_type: glam_type,
      page: 1,
      nodes: get_all_nodes()
    })
  end

  @doc """
  API endpoint for AJAX search requests
  """
  def api_search(conn, params) do
    _user_role = SearchHelper.get_user_role(conn)
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

    results =
      if String.trim(query) != "" do
        case search_type do
          "collections" ->
            # TODO: Implement with SearchCollections
            # SearchCollections.search_collections(query, user_role, %{page: page, per_page: 5})
            %{results: [], total: 0, page: page, total_pages: 0}

          "items" ->
            # TODO: Implement items search
            # SearchCollections.search_items(query, user_role, %{page: page, per_page: 10})
            %{results: [], total: 0, page: page, total_pages: 0}

          "universal" ->
            # TODO: Implement universal search
            # SearchCollections.universal_search(query, user_role, %{
            #   page: page,
            #   collections_per_page: 3,
            #   items_per_page: 7
            # })
            %{
              collections: %{results: [], total: 0},
              items: %{results: [], total: 0},
              total_results: 0
            }
        end
      else
        %{
          collections: %{results: [], total: 0},
          items: %{results: [], total: 0},
          total_results: 0
        }
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
  def suggestions(conn, %{"q" => query} = params) when byte_size(query) >= 2 do
    glam_type = Map.get(params, "glam_type", "quick")
    limit = Map.get(params, "limit", "8") |> String.to_integer()

    suggestions =
      if String.trim(query) != "" do
        SearchCollections.get_search_suggestions(query, glam_type, limit)
      else
        []
      end

    # Serialize for JSON response
    serialized_suggestions =
      Enum.map(suggestions, fn collection ->
        %{
          id: collection.id,
          title: collection.title,
          description: collection.description,
          thumbnail: collection.thumbnail,
          status: collection.status,
          resource_class:
            collection.resource_class &&
              %{
                glam_type: collection.resource_class.glam_type
              },
          mst_creator:
            collection.mst_creator &&
              %{
                creator_name: collection.mst_creator.creator_name
              },
          items_count: length(collection.items || [])
        }
      end)

    json(conn, %{suggestions: serialized_suggestions})
  end

  def suggestions(conn, _params) do
    json(conn, %{suggestions: []})
  end

  # Private helper functions

  # 10 collections + 10 items
  defp get_per_page_for_search_type("both"), do: 20
  # Single type searches
  defp get_per_page_for_search_type(_), do: 15

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
        creator: collection.mst_creator && collection.mst_creator.creator_name,
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
