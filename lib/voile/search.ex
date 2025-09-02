defmodule Voile.Search.Collections do
  @moduledoc """
  Search context for collections with GLAM categorization support.
  Handles autocomplete suggestions and search functionality.
  """

  import Ecto.Query, warn: false
  alias Voile.Repo
  alias Voile.Schema.Catalog.Collection

  @doc """
  Search for collections with autocomplete suggestions.

  Returns up to `limit` collections that match the query string.
  """
  def search_collections_for_suggestions(query, opts \\ []) when is_binary(query) do
    limit = Keyword.get(opts, :limit, 10)
    glam_type = Keyword.get(opts, :glam_type, "quick")

    base_query =
      from c in Collection,
        left_join: rc in assoc(c, :resource_class),
        left_join: creator in assoc(c, :mst_creator),
        left_join: items in assoc(c, :items),
        where: c.status == "published",
        preload: [resource_class: rc, mst_creator: creator, items: items]

    # Add search conditions
    search_query =
      base_query
      |> where(
        [c],
        ilike(c.title, ^"%#{query}%") or
          ilike(c.description, ^"%#{query}%")
      )

    # Filter by GLAM type if specified
    final_query =
      if glam_type != "quick" do
        search_query |> where([c, rc], rc.glam_type == ^glam_type)
      else
        search_query
      end

    final_query
    |> order_by([c], desc: :updated_at)
    |> limit(^limit)
    |> Repo.all()
  end

  @doc """
  Search collections by GLAM type specifically.
  """
  def search_collections_by_glam_type(query, glam_type, opts \\ []) when is_binary(query) do
    opts = Keyword.put(opts, :glam_type, glam_type)
    search_collections_for_suggestions(query, opts)
  end

  @doc """
  Get search suggestions with enhanced metadata for autocomplete.
  """
  def get_search_suggestions(query, glam_type \\ "quick", limit \\ 8) when is_binary(query) do
    if String.length(query) >= 2 do
      search_collections_for_suggestions(query, glam_type: glam_type, limit: limit)
    else
      []
    end
  end

  @doc """
  Full-text search across collections with pagination and filtering.
  """
  def search_collections(params \\ %{}) do
    query = Map.get(params, "q", "")
    glam_type = Map.get(params, "glam_type", "quick")
    status = Map.get(params, "status", "published")
    page = String.to_integer(Map.get(params, "page", "1"))
    per_page = String.to_integer(Map.get(params, "per_page", "20"))

    base_query =
      from c in Collection,
        left_join: rc in assoc(c, :resource_class),
        left_join: creator in assoc(c, :mst_creator),
        left_join: items in assoc(c, :items),
        preload: [resource_class: rc, mst_creator: creator, items: items]

    # Apply filters
    filtered_query =
      base_query
      |> filter_by_status(status)
      |> filter_by_glam_type(glam_type)
      |> filter_by_search_query(query)

    # Get total count for pagination
    total_count = Repo.aggregate(filtered_query, :count, :id)
    total_pages = ceil(total_count / per_page)

    # Get paginated results
    results =
      filtered_query
      |> order_by([c], desc: :updated_at)
      |> limit(^per_page)
      |> offset(^((page - 1) * per_page))
      |> Repo.all()

    %{
      results: results,
      total_count: total_count,
      total_pages: total_pages,
      current_page: page,
      per_page: per_page
    }
  end

  @doc """
  Advanced search with multiple parameters and filters.
  """
  def advanced_search(search_params, _user_role \\ :public, opts \\ %{}) do
    # This is a placeholder implementation for advanced search
    # You can expand this based on your specific requirements

    query = Map.get(search_params, :title, Map.get(search_params, :query, ""))
    page = Map.get(opts, :page, 1)
    search_type = Map.get(opts, :type, :both)

    collections_result =
      if search_type in [:collections, :both] do
        search_collections(%{
          "q" => query,
          "page" => Integer.to_string(page),
          "per_page" => "10"
        })
      else
        %{results: [], total_count: 0}
      end

    items_result =
      if search_type in [:items, :both] do
        # Placeholder for items search
        %{results: [], total_count: 0}
      else
        %{results: [], total_count: 0}
      end

    %{
      collections: %{results: collections_result.results, total: collections_result.total_count},
      items: %{results: items_result.results, total: items_result.total_count},
      total_results: collections_result.total_count + items_result.total_count
    }
  end

  @doc """
  Search items with filters and pagination.
  """
  def search_items(_query, _user_role \\ :public, opts \\ %{}) do
    # Placeholder implementation for item search
    # You'll need to implement this based on your Item schema

    %{
      results: [],
      total: 0,
      page: Map.get(opts, :page, 1),
      total_pages: 0
    }
  end

  @doc """
  Universal search across collections and items.
  """
  def universal_search(query, user_role \\ :public, opts \\ %{}) do
    page = Map.get(opts, :page, 1)
    collections_per_page = Map.get(opts, :collections_per_page, 5)
    items_per_page = Map.get(opts, :items_per_page, 10)

    collections_result =
      search_collections(%{
        "q" => query,
        "page" => Integer.to_string(page),
        "per_page" => Integer.to_string(collections_per_page)
      })

    items_result =
      search_items(query, user_role, %{
        page: page,
        per_page: items_per_page
      })

    %{
      collections: %{results: collections_result.results, total: collections_result.total_count},
      items: %{results: items_result.results, total: items_result.total},
      total_results: collections_result.total_count + items_result.total
    }
  end

  defp filter_by_status(query, "all"), do: query
  defp filter_by_status(query, status), do: where(query, [c], c.status == ^status)

  defp filter_by_glam_type(query, "quick"), do: query

  defp filter_by_glam_type(query, glam_type) do
    where(query, [c, rc], rc.glam_type == ^glam_type)
  end

  defp filter_by_search_query(query, ""), do: query

  defp filter_by_search_query(query, search_query) do
    where(
      query,
      [c],
      ilike(c.title, ^"%#{search_query}%") or
        ilike(c.description, ^"%#{search_query}%")
    )
  end
end
