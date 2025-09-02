defmodule Voile.Schema.Search do
  @moduledoc """
  The Search context for handling search operations across the application.
  Provides search functionality for both librarians and patrons with role-based filtering.
  """

  import Ecto.Query, warn: false
  alias Voile.Repo
  alias Voile.Schema.Catalog.{Collection, Item, CollectionField, ItemFieldValue}
  alias Voile.Schema.Accounts.User
  alias Voile.Schema.Master.Creator

  @doc """
  Search collections with optional filters and role-based access control.

  ## Parameters
  - query_string: The search term
  - user_role: "librarian" or "patron" for access control
  - opts: Additional options like pagination, filters, etc.

  ## Examples
      iex> search_collections("science", "patron", %{page: 1, per_page: 10})
      %{results: [%Collection{}], total: 5, page: 1, total_pages: 1}
  """
  def search_collections(query_string, user_role \\ "patron", opts \\ %{})

  def search_collections(query_string, user_role, opts) when is_binary(query_string) do
    page = Map.get(opts, :page, 1)
    per_page = Map.get(opts, :per_page, 10)
    filters = Map.get(opts, :filters, %{})

    query_string
    |> build_collection_search_query(user_role, filters)
    |> paginate_results(page, per_page)
  end

  @doc """
  Search items with optional filters and role-based access control.

  ## Parameters
  - query_string: The search term
  - user_role: "librarian" or "patron" for access control
  - opts: Additional options like pagination, filters, etc.

  ## Examples
      iex> search_items("programming", "patron", %{status: "available"})
      %{results: [%Item{}], total: 12, page: 1, total_pages: 2}
  """
  def search_items(query_string, user_role \\ "patron", opts \\ %{})

  def search_items(query_string, user_role, opts) when is_binary(query_string) do
    page = Map.get(opts, :page, 1)
    per_page = Map.get(opts, :per_page, 10)
    filters = Map.get(opts, :filters, %{})

    query_string
    |> build_item_search_query(user_role, filters)
    |> paginate_results(page, per_page)
  end

  @doc """
  Universal search across collections and items.
  Returns a combined result set with type indicators.

  ## Examples
      iex> universal_search("history", "patron", %{page: 1})
      %{
        collections: %{results: [...], total: 3},
        items: %{results: [...], total: 8},
        total_results: 11
      }
  """
  def universal_search(query_string, user_role \\ "patron", opts \\ %{})

  def universal_search(query_string, user_role, opts) when is_binary(query_string) do
    collections_opts = Map.put(opts, :per_page, Map.get(opts, :collections_per_page, 5))
    items_opts = Map.put(opts, :per_page, Map.get(opts, :items_per_page, 10))

    collections_result = search_collections(query_string, user_role, collections_opts)
    items_result = search_items(query_string, user_role, items_opts)

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
      iex> advanced_search(%{title: "physics", creator: "einstein"}, "librarian")
      %{results: [...], total: 2}
  """
  def advanced_search(search_params, user_role \\ "patron", opts \\ %{})

  def advanced_search(search_params, user_role, opts) when is_map(search_params) do
    page = Map.get(opts, :page, 1)
    per_page = Map.get(opts, :per_page, 10)
    search_type = Map.get(opts, :type, :both) # :collections, :items, or :both

    case search_type do
      :collections ->
        search_params
        |> build_advanced_collection_query(user_role)
        |> paginate_results(page, per_page)

      :items ->
        search_params
        |> build_advanced_item_query(user_role)
        |> paginate_results(page, per_page)

      :both ->
        collections_result = advanced_search(search_params, user_role, Map.put(opts, :type, :collections))
        items_result = advanced_search(search_params, user_role, Map.put(opts, :type, :items))

        %{
          collections: collections_result,
          items: items_result,
          total_results: collections_result.total + items_result.total
        }
    end
  end

  # Private functions for building queries

  defp build_collection_search_query(query_string, user_role, filters) do
    search_term = "%#{String.trim(query_string)}%"

    base_query =
      from c in Collection,
        left_join: creator in Creator, on: c.creator_id == creator.id,
        left_join: cf in CollectionField, on: c.id == cf.collection_id,
        where:
          ilike(c.title, ^search_term) or
          ilike(c.description, ^search_term) or
          ilike(creator.name, ^search_term) or
          ilike(cf.value, ^search_term),
        distinct: c.id,
        preload: [
          :resource_class,
          :resource_template,
          :mst_creator,
          :node,
          :collection_fields,
          :items
        ]

    base_query
    |> apply_role_based_access(user_role, :collection)
    |> apply_collection_filters(filters)
  end

  defp build_item_search_query(query_string, user_role, filters) do
    search_term = "%#{String.trim(query_string)}%"

    base_query =
      from i in Item,
        left_join: c in Collection, on: i.collection_id == c.id,
        left_join: creator in Creator, on: c.creator_id == creator.id,
        left_join: ifv in ItemFieldValue, on: i.id == ifv.item_id,
        where:
          ilike(c.title, ^search_term) or
          ilike(c.description, ^search_term) or
          ilike(creator.name, ^search_term) or
          ilike(i.item_code, ^search_term) or
          ilike(i.inventory_code, ^search_term) or
          ilike(i.location, ^search_term) or
          ilike(ifv.value, ^search_term),
        distinct: i.id,
        preload: [
          :collection,
          :node,
          :attachments
        ]

    base_query
    |> apply_role_based_access(user_role, :item)
    |> apply_item_filters(filters)
  end

  defp build_advanced_collection_query(search_params, user_role) do
    base_query =
      from c in Collection,
        left_join: creator in Creator, on: c.creator_id == creator.id,
        left_join: cf in CollectionField, on: c.id == cf.collection_id,
        distinct: c.id,
        preload: [
          :resource_class,
          :resource_template,
          :mst_creator,
          :node,
          :collection_fields,
          :items
        ]

    query = Enum.reduce(search_params, base_query, fn {field, value}, acc_query ->
      search_term = "%#{String.trim(value)}%"

      case field do
        :title -> where(acc_query, [c], ilike(c.title, ^search_term))
        :description -> where(acc_query, [c], ilike(c.description, ^search_term))
        :creator -> where(acc_query, [c, creator], ilike(creator.name, ^search_term))
        :collection_type -> where(acc_query, [c], ilike(c.collection_type, ^search_term))
        :status -> where(acc_query, [c], c.status == ^value)
        :access_level -> where(acc_query, [c], c.access_level == ^value)
        _ -> acc_query
      end
    end)

    apply_role_based_access(query, user_role, :collection)
  end

  defp build_advanced_item_query(search_params, user_role) do
    base_query =
      from i in Item,
        left_join: c in Collection, on: i.collection_id == c.id,
        left_join: creator in Creator, on: c.creator_id == creator.id,
        left_join: ifv in ItemFieldValue, on: i.id == ifv.item_id,
        distinct: i.id,
        preload: [
          :collection,
          :node,
          :attachments
        ]

    query = Enum.reduce(search_params, base_query, fn {field, value}, acc_query ->
      search_term = "%#{String.trim(value)}%"

      case field do
        :title -> where(acc_query, [i, c], ilike(c.title, ^search_term))
        :item_code -> where(acc_query, [i], ilike(i.item_code, ^search_term))
        :inventory_code -> where(acc_query, [i], ilike(i.inventory_code, ^search_term))
        :location -> where(acc_query, [i], ilike(i.location, ^search_term))
        :status -> where(acc_query, [i], i.status == ^value)
        :condition -> where(acc_query, [i], i.condition == ^value)
        :availability -> where(acc_query, [i], i.availability == ^value)
        :creator -> where(acc_query, [i, c, creator], ilike(creator.name, ^search_term))
        _ -> acc_query
      end
    end)

    apply_role_based_access(query, user_role, :item)
  end

  defp apply_role_based_access(query, "librarian", _type) do
    # Librarians can see everything
    query
  end

  defp apply_role_based_access(query, "patron", :collection) do
    # Patrons can only see public collections
    where(query, [c], c.access_level in ["public", "restricted"])
  end

  defp apply_role_based_access(query, "patron", :item) do
    # Patrons can only see available items from public collections
    where(query, [i, c],
      i.availability in ["available", "reference"] and
      c.access_level in ["public", "restricted"]
    )
  end

  defp apply_role_based_access(query, _user_role, _type), do: query

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

  defp paginate_results(query, page, per_page) do
    offset = (page - 1) * per_page

    total_count =
      query
      |> exclude(:preload)
      |> exclude(:distinct)
      |> select([_], count())
      |> Repo.one()

    results =
      query
      |> limit(^per_page)
      |> offset(^offset)
      |> Repo.all()

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
