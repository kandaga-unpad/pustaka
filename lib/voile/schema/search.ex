defmodule Voile.Schema.Search do
  @moduledoc """
  The Search context for handling search operations across the application.
  Provides search functionality for both librarians and patrons with role-based filtering.
  """

  import Ecto.Query, warn: false
  alias Voile.Repo
  alias Voile.Schema.Catalog.{Collection, Item}
  alias Voile.Schema.Master.Creator

  @doc """
  Search collections with optional filters.

  ## Parameters
  - query_string: The search term
  - opts: Additional options like pagination, filters, etc.

  ## Examples
      iex> search_collections("science", %{page: 1, per_page: 10})
      %{results: [%Collection{}], total: 5, page: 1, total_pages: 1}
  """
  def search_collections(query_string, opts \\ %{})

  def search_collections(query_string, opts) when is_binary(query_string) do
    page = Map.get(opts, :page, 1)
    per_page = Map.get(opts, :per_page, 10)
    filters = Map.get(opts, :filters, %{})

    query_string
    |> build_collection_search_query(filters)
    |> paginate_results(page, per_page, [
      :resource_class,
      :resource_template,
      :mst_creator,
      :node
    ])
  end

  @doc """
  Search items with optional filters.

  ## Parameters
  - query_string: The search term
  - opts: Additional options like pagination, filters, etc.

  ## Examples
      iex> search_items("programming", %{status: "available"})
      %{results: [%Item{}], total: 12, page: 1, total_pages: 2}
  """
  def search_items(query_string, opts \\ %{})

  def search_items(query_string, opts) when is_binary(query_string) do
    page = Map.get(opts, :page, 1)
    per_page = Map.get(opts, :per_page, 10)
    filters = Map.get(opts, :filters, %{})

    query_string
    |> build_item_search_query(filters)
    |> paginate_results(page, per_page, [:collection, :node])
  end

  @doc """
  Universal search across collections and items.
  Returns a combined result set with type indicators.

  ## Examples
      iex> universal_search("history", %{page: 1})
      %{
        collections: %{results: [...], total: 3},
        items: %{results: [...], total: 8},
        total_results: 11
      }
  """
  def universal_search(query_string, opts \\ %{})

  def universal_search(query_string, opts) when is_binary(query_string) do
    collections_opts = Map.put(opts, :per_page, Map.get(opts, :collections_per_page, 5))
    items_opts = Map.put(opts, :per_page, Map.get(opts, :items_per_page, 10))

    collections_result = search_collections(query_string, collections_opts)
    items_result = search_items(query_string, items_opts)

    %{
      collections: collections_result,
      items: items_result,
      total_results: collections_result.total + items_result.total,
      query: query_string
    }
  end

  @doc """
  Advanced search with field-specific queries.
  Allows searching specific fields like title, description, creator, etc.

  ## Examples
      iex> advanced_search(%{title: "physics", creator: "einstein"})
      %{results: [...], total: 2}
  """
  def advanced_search(search_params, opts \\ %{})

  def advanced_search(search_params, opts) when is_map(search_params) do
    page = Map.get(opts, :page, 1)
    per_page = Map.get(opts, :per_page, 10)
    # :collections, :items, or :both
    search_type = Map.get(opts, :type, :both)

    case search_type do
      :collections ->
        search_params
        |> build_advanced_collection_query()
        |> paginate_results(page, per_page)

      :items ->
        search_params
        |> build_advanced_item_query()
        |> paginate_results(page, per_page)

      :both ->
        collections_result =
          advanced_search(search_params, Map.put(opts, :type, :collections))

        items_result = advanced_search(search_params, Map.put(opts, :type, :items))

        %{
          collections: collections_result,
          items: items_result,
          total_results: collections_result.total + items_result.total
        }
    end
  end

  # Private functions for building queries

  defp build_collection_search_query(query_string, filters) do
    {like, title_like} = build_search_patterns(query_string)

    # creator join is 1:1 (collection.creator_id FK) — no distinct needed
    base_query =
      from c in Collection,
        left_join: creator in Creator,
        on: c.creator_id == creator.id,
        where:
          ilike(c.title, ^title_like) or
            ilike(c.description, ^like) or
            ilike(c.collection_code, ^like) or
            ilike(creator.creator_name, ^like)

    apply_collection_filters(base_query, filters)
  end

  defp build_item_search_query(query_string, filters) do
    {like, title_like} = build_search_patterns(query_string)

    base_query =
      from i in Item,
        left_join: c in Collection,
        on: i.collection_id == c.id,
        left_join: creator in Creator,
        on: c.creator_id == creator.id,
        where:
          ilike(c.title, ^title_like) or
            ilike(c.description, ^like) or
            ilike(creator.creator_name, ^like) or
            ilike(i.item_code, ^like) or
            ilike(i.inventory_code, ^like) or
            ilike(i.location, ^like)

    apply_item_filters(base_query, filters)
  end

  defp build_advanced_collection_query(search_params) do
    # CollectionField join removed — cf was never used in any where clause
    # and the 1:many join caused row duplication requiring expensive distinct
    base_query =
      from c in Collection,
        left_join: creator in Creator,
        on: c.creator_id == creator.id

    query =
      Enum.reduce(search_params, base_query, fn {field, value}, acc_query ->
        search_term = "%#{String.trim(value)}%"

        case field do
          :title -> where(acc_query, [c], ilike(c.title, ^search_term))
          :description -> where(acc_query, [c], ilike(c.description, ^search_term))
          :creator -> where(acc_query, [c, creator], ilike(creator.creator_name, ^search_term))
          :collection_type -> where(acc_query, [c], ilike(c.collection_type, ^search_term))
          :status -> where(acc_query, [c], c.status == ^value)
          :access_level -> where(acc_query, [c], c.access_level == ^value)
          _ -> acc_query
        end
      end)

    query
  end

  defp build_advanced_item_query(search_params) do
    # ItemFieldValue join removed — ifv was never used in any where clause
    # and the 1:many join caused row duplication requiring expensive distinct.
    # Preloads are handled by paginate_results, not in the base query.
    base_query =
      from i in Item,
        left_join: c in Collection,
        on: i.collection_id == c.id,
        left_join: creator in Creator,
        on: c.creator_id == creator.id

    query =
      Enum.reduce(search_params, base_query, fn {field, value}, acc_query ->
        search_term = "%#{String.trim(value)}%"

        case field do
          :title -> where(acc_query, [i, c], ilike(c.title, ^search_term))
          :item_code -> where(acc_query, [i], ilike(i.item_code, ^search_term))
          :inventory_code -> where(acc_query, [i], ilike(i.inventory_code, ^search_term))
          :location -> where(acc_query, [i], ilike(i.location, ^search_term))
          :status -> where(acc_query, [i], i.status == ^value)
          :condition -> where(acc_query, [i], i.condition == ^value)
          :availability -> where(acc_query, [i], i.availability == ^value)
          :creator -> where(acc_query, [i, c, creator], ilike(creator.creator_name, ^search_term))
          _ -> acc_query
        end
      end)

    query
  end

  # Normalize a search string and return {like, title_like} patterns.
  # - `like`       — plain %term% for exact-spacing columns (all have trigram indexes).
  # - `title_like` — splits words with % so double-spaced stored titles still match.
  # Also converts common Unicode punctuation (curly quotes, en/em dashes) to their
  # ASCII equivalents, which is common in titles imported from MARC/OAI-PMH sources.
  defp build_search_patterns(search) do
    normalized =
      search
      |> String.trim()
      |> String.replace(~r/\s+/, " ")
      |> String.replace("\u2019", "'")
      |> String.replace("\u2018", "'")
      |> String.replace("\u201C", "\"")
      |> String.replace("\u201D", "\"")
      |> String.replace("\u2013", "-")
      |> String.replace("\u2014", "-")

    like = "%#{normalized}%"

    title_like =
      "%" <>
        (normalized |> String.split(" ", trim: true) |> Enum.join("%")) <>
        "%"

    {like, title_like}
  end

  defp apply_collection_filters(query, filters) do
    Enum.reduce(filters, query, fn {key, value}, acc ->
      case key do
        :status -> where(acc, [c], c.status == ^value)
        :collection_type -> where(acc, [c], c.collection_type == ^value)
        :access_level -> where(acc, [c], c.access_level == ^value)
        :creator_id -> where(acc, [c], c.creator_id == ^value)
        :unit_id -> where(acc, [c], c.unit_id == ^value)
        _ -> acc
      end
    end)
  end

  defp apply_item_filters(query, filters) do
    Enum.reduce(filters, query, fn {key, value}, acc ->
      case key do
        :status -> where(acc, [i], i.status == ^value)
        :condition -> where(acc, [i], i.condition == ^value)
        :availability -> where(acc, [i], i.availability == ^value)
        :location -> where(acc, [i], ilike(i.location, ^"%#{value}%"))
        :collection_id -> where(acc, [i], i.collection_id == ^value)
        :unit_id -> where(acc, [i], i.unit_id == ^value)
        _ -> acc
      end
    end)
  end

  defp paginate_results(query, page, per_page, preloads \\ []) do
    offset = (page - 1) * per_page

    total_count =
      query
      |> exclude(:preload)
      |> exclude(:distinct)
      |> exclude(:order_by)
      |> select([_], count())
      |> Repo.one()

    results =
      query
      |> limit(^per_page)
      |> offset(^offset)
      |> Repo.all()
      |> Repo.preload(preloads)

    total_pages = ceil(total_count / per_page)

    %{
      results: results,
      total: total_count,
      page: page,
      per_page: per_page,
      total_pages: total_pages,
      has_next: page < total_pages,
      has_prev: page > 1
    }
  end
end
