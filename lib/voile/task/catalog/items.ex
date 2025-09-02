defmodule Voile.Task.Catalog.Items do
  @moduledoc """
  Task module for Items-related business logic and data operations.
  """

  import Ecto.Query, warn: false
  alias Voile.Repo
  alias Voile.Schema.Catalog

  @doc """
  Load items with filtering, pagination, search, and sorting functionality.
  """
  def load_items(page, search_query, filters, sort_by, sort_order, per_page \\ 20) do
    # Build base query with filtering for accessible items
    base_query = build_base_query(search_query, filters)

    # Apply sorting
    sorted_query = apply_sorting(base_query, sort_by, sort_order)

    # Apply pagination
    pagination_offset = (page - 1) * per_page

    query =
      sorted_query
      |> limit(^per_page)
      |> offset(^pagination_offset)
      |> preload(
        collection: [:mst_creator],
        node: []
      )

    items = Repo.all(query)

    # Calculate total pages
    total_count = Repo.aggregate(base_query, :count, :id)
    total_pages = div(total_count + per_page - 1, per_page)

    {items, total_pages}
  end

  @doc """
  Load an item with its related data for the show page.
  """
  def load_item_with_related(id) do
    try do
      item = Catalog.get_item!(id)

      # Check if the item's collection is accessible to public (members)
      if item.collection.access_level not in ["public", "restricted"] do
        {:error, :access_denied}
      else
        related_items = load_related_items(item)
        {:ok, item, related_items}
      end
    rescue
      Ecto.NoResultsError ->
        {:error, :not_found}
    end
  end

  @doc """
  Load related items for a given item (same collection, excluding the current item).
  """
  def load_related_items(item, limit \\ 5) do
    # Find other items in the same collection, excluding the current item
    from(i in Voile.Schema.Catalog.Item,
      where: i.collection_id == ^item.collection_id,
      where: i.id != ^item.id,
      where: i.status == "active",
      preload: [:node],
      order_by: [asc: i.item_code],
      limit: ^limit
    )
    |> Repo.all()
  end

  # Private functions

  defp build_base_query(search_query, filters) do
    from(i in Voile.Schema.Catalog.Item)
    |> join(:inner, [i], c in assoc(i, :collection))
    |> where([i, c], c.access_level in ["public", "restricted"])
    |> where([i, c], i.status in ["active"])
    |> filter_by_availability(filters.availability)
    |> filter_by_condition(filters.condition)
    |> filter_by_location(filters.location)
    |> search_by_query(search_query)
  end

  defp filter_by_availability(query, "all"), do: query

  defp filter_by_availability(query, availability) do
    where(query, [i], i.availability == ^availability)
  end

  defp filter_by_condition(query, "all"), do: query

  defp filter_by_condition(query, condition) do
    where(query, [i], i.condition == ^condition)
  end

  defp filter_by_location(query, "all"), do: query

  defp filter_by_location(query, location) do
    where(query, [i], i.location == ^location)
  end

  defp search_by_query(query, ""), do: query

  defp search_by_query(query, search_query) do
    search_term = "%#{search_query}%"

    query
    |> join(:left, [i, c], creator in assoc(c, :mst_creator))
    |> where(
      [i, c, creator],
      ilike(i.item_code, ^search_term) or
        ilike(i.inventory_code, ^search_term) or
        ilike(i.location, ^search_term) or
        ilike(c.title, ^search_term) or
        ilike(creator.creator_name, ^search_term)
    )
  end

  defp apply_sorting(query, sort_by, sort_order) do
    order = if sort_order == "desc", do: :desc, else: :asc

    case sort_by do
      "item_code" -> order_by(query, [i], {^order, i.item_code})
      "location" -> order_by(query, [i], {^order, i.location})
      "availability" -> order_by(query, [i], {^order, i.availability})
      "condition" -> order_by(query, [i], {^order, i.condition})
      "collection" -> order_by(query, [i, c], {^order, c.title})
      "date_added" -> order_by(query, [i], {^order, i.inserted_at})
      _ -> order_by(query, [i], {^order, i.item_code})
    end
  end
end
