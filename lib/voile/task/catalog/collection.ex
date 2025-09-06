defmodule Voile.Task.Catalog.Collection do
  @moduledoc """
  Task module for Collection-related business logic and data operations.
  """

  import Ecto.Query, warn: false
  alias Voile.Repo
  alias Voile.Schema.Catalog
  alias Voile.Schema.Catalog.{Collection, Item}
  alias Voile.Schema.System.Node

  @doc """
  Load collections with filtering, pagination, and search functionality.
  Now filters by unit_id (node) instead of non-existent collection types.
  """
  def load_collections(page, search_query, filter_unit_id, filter_status, per_page \\ 12) do
    # Build base query with filtering for public access and member-visible collections
    base_query = build_base_query(search_query, filter_unit_id, filter_status)

    # Apply pagination
    pagination_offset = (page - 1) * per_page

    query =
      base_query
      |> limit(^per_page)
      |> offset(^pagination_offset)
      |> order_by([c], desc: c.inserted_at, desc: c.id)
      |> preload([
        :resource_class,
        :mst_creator,
        :node,
        items: [:node]
      ])

    collections = Repo.all(query)

    # Calculate total pages
    total_count = Repo.aggregate(base_query, :count, :id)
    total_pages = div(total_count + per_page - 1, per_page)

    {collections, total_pages}
  end

  @doc """
  Load a collection with its items for the show page.
  """
  def load_collection_with_items(id, items_page \\ 1) do
    try do
      collection = Catalog.get_collection!(id)

      # Check if the collection is accessible to public (members)
      if collection.access_level not in ["public", "restricted"] do
        {:error, :access_denied}
      else
        {items, total_pages} = load_items_for_collection(id, items_page)
        {:ok, collection, items, total_pages}
      end
    rescue
      Ecto.NoResultsError ->
        {:error, :not_found}
    end
  end

  @doc """
  Load items for a specific collection with pagination.
  """
  def load_items_for_collection(collection_id, page, per_page \\ 20) do
    offset = (page - 1) * per_page

    query =
      from i in Item,
        where: i.collection_id == ^collection_id,
        where: i.status == "active",
        preload: [:node],
        order_by: [asc: i.item_code],
        limit: ^per_page,
        offset: ^offset

    items = Repo.all(query)

    # Calculate total pages
    total_count =
      from(i in Item,
        where: i.collection_id == ^collection_id,
        where: i.status == "active"
      )
      |> Repo.aggregate(:count, :id)

    total_pages = div(total_count + per_page - 1, per_page)

    {items, total_pages}
  end

  def count_collections do
    from(c in Collection)
    |> where([c], c.access_level in ["public", "restricted"])
    |> Repo.aggregate(:count, :id)
  end

  @doc """
  Get all nodes for the unit filter dropdown.
  """
  def get_all_nodes do
    Repo.all(from n in Node, order_by: n.name)
  end

  # Private functions

  defp build_base_query(search_query, filter_unit_id, filter_status) do
    from(c in Collection)
    |> where([c], c.access_level in ["public", "restricted"])
    |> filter_by_status(filter_status)
    |> filter_by_unit_id(filter_unit_id)
    |> search_by_query(search_query)
  end

  defp filter_by_status(query, "all"), do: query

  defp filter_by_status(query, status) do
    where(query, [c], c.status == ^status)
  end

  defp filter_by_unit_id(query, "all"), do: query
  defp filter_by_unit_id(query, ""), do: query

  defp filter_by_unit_id(query, unit_id) do
    case Integer.parse(unit_id) do
      {id, ""} -> where(query, [c], c.unit_id == ^id)
      _ -> query
    end
  end

  defp search_by_query(query, ""), do: query

  defp search_by_query(query, search_query) do
    search_term = "%#{search_query}%"

    query
    |> join(:left, [c], creator in assoc(c, :mst_creator))
    |> where(
      [c, creator],
      ilike(c.title, ^search_term) or
        ilike(c.description, ^search_term) or
        ilike(creator.creator_name, ^search_term)
    )
  end
end
