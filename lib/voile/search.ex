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
        where: c.status == "published",
        preload: [resource_class: rc, mst_creator: creator, collection_fields: [], items: []]

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
    |> order_by([c],
      # Same relevance-based sorting as main search
      desc: fragment("CASE WHEN LOWER(?) = LOWER(?) THEN 3
                          WHEN LOWER(?) LIKE LOWER(?) THEN 2
                          ELSE 1 END", c.title, ^query, c.title, ^"%#{query}%"),
      desc: :updated_at,
      desc: :id
    )
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
  Can handle both simple query strings and advanced search parameters.
  """
  def search_collections(params \\ %{}) do
    query = Map.get(params, "q", "")
    glam_type = Map.get(params, "glam_type", "quick")
    # Default to "published" if status is empty or not provided
    status =
      case Map.get(params, "status", "published") do
        "" -> "published"
        s -> s
      end

    page = String.to_integer(Map.get(params, "page", "1"))
    per_page = String.to_integer(Map.get(params, "per_page", "20"))

    # Handle advanced search parameters
    title_filter = Map.get(params, "title", "")
    description_filter = Map.get(params, "description", "")
    creator_filter = Map.get(params, "creator", "")
    collection_code_filter = Map.get(params, "collection_code", "")
    access_level_filter = Map.get(params, "access_level", "")
    unit_id_filter = Map.get(params, "unit_id", "")
    resource_glam_type_filter = Map.get(params, "resource_glam_type", "")
    resource_class_filter = Map.get(params, "resource_class", "")
    collection_type_filter = Map.get(params, "collection_type", "")
    creator_type_filter = Map.get(params, "creator_type", "")
    creator_affiliation_filter = Map.get(params, "creator_affiliation", "")
    creator_contact_filter = Map.get(params, "creator_contact", "")
    resource_template_filter = Map.get(params, "resource_template", "")
    node_name_filter = Map.get(params, "node_name", "")
    node_abbr_filter = Map.get(params, "node_abbr", "")
    media_type_filter = Map.get(params, "media_type", "")
    created_by_filter = Map.get(params, "created_by", "")
    updated_by_filter = Map.get(params, "updated_by", "")
    sort_order_min_filter = Map.get(params, "sort_order_min", "")
    sort_order_max_filter = Map.get(params, "sort_order_max", "")

    base_query =
      from c in Collection,
        left_join: rc in assoc(c, :resource_class),
        left_join: creator in assoc(c, :mst_creator),
        left_join: template in assoc(c, :resource_template),
        left_join: node_join in assoc(c, :node),
        left_join: created_by_user in assoc(c, :created_by),
        left_join: updated_by_user in assoc(c, :updated_by),
        preload: [resource_class: rc, mst_creator: creator, collection_fields: [], items: []]

    # Apply filters
    filtered_query =
      base_query
      |> filter_by_status(status)
      |> filter_by_glam_type(glam_type)
      |> filter_by_search_query(query)
      |> filter_by_title(title_filter)
      |> filter_by_description(description_filter)
      |> filter_by_creator(creator_filter)
      |> filter_by_collection_code(collection_code_filter)
      |> filter_by_access_level(access_level_filter)
      |> filter_by_unit_id(unit_id_filter)
      |> filter_by_resource_glam_type(resource_glam_type_filter)
      |> filter_by_resource_class(resource_class_filter)
      |> filter_by_collection_type(collection_type_filter)
      |> filter_by_creator_type(creator_type_filter)
      |> filter_by_creator_affiliation(creator_affiliation_filter)
      |> filter_by_creator_contact(creator_contact_filter)
      |> filter_by_resource_template(resource_template_filter)
      |> filter_by_media_type(media_type_filter)
      |> filter_by_node_name(node_name_filter)
      |> filter_by_node_abbr(node_abbr_filter)
      |> filter_by_created_by(created_by_filter)
      |> filter_by_updated_by(updated_by_filter)
      |> filter_by_sort_order_min(sort_order_min_filter)
      |> filter_by_sort_order_max(sort_order_max_filter)

    # Get total count for pagination
    total_count = Repo.aggregate(filtered_query, :count, :id)
    total_pages = ceil(total_count / per_page)

    # Get paginated results with relevance-based sorting
    results =
      filtered_query
      |> order_by([c],
        # Prioritize exact title matches, then title contains, then recent updates
        desc: fragment("CASE WHEN LOWER(?) = LOWER(?) THEN 3
                            WHEN LOWER(?) LIKE LOWER(?) THEN 2
                            ELSE 1 END", c.title, ^query, c.title, ^"%#{query}%"),
        desc: :updated_at,
        # Final tiebreaker for deterministic results
        desc: :id
      )
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
  Focus on collections with GLAM type filtering.
  """
  def advanced_search(search_params, _user_role \\ :public, opts \\ %{}) do
    page = Map.get(opts, :page, 1)
    search_type = Map.get(opts, :type, "collections")
    glam_type = Map.get(opts, :glam_type, "quick")
    per_page = Map.get(opts, :per_page, 10)

    collections_result =
      if search_type in ["collections", "both"] do
        # search_params already has string keys, so we can use them directly
        search_collection_params =
          search_params
          |> Map.merge(%{
            "page" => Integer.to_string(page),
            "per_page" => Integer.to_string(per_page),
            "glam_type" => glam_type
          })

        search_collections(search_collection_params)
      else
        %{results: [], total_count: 0}
      end

    %{
      collections: %{results: collections_result.results, total: collections_result.total_count},
      total_results: collections_result.total_count,
      total_pages: collections_result.total_pages,
      current_page: collections_result.current_page,
      per_page: collections_result.per_page
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

  defp filter_by_title(query, ""), do: query

  defp filter_by_title(query, title) do
    where(query, [c], ilike(c.title, ^"%#{title}%"))
  end

  defp filter_by_description(query, ""), do: query

  defp filter_by_description(query, description) do
    where(query, [c], ilike(c.description, ^"%#{description}%"))
  end

  defp filter_by_creator(query, ""), do: query

  defp filter_by_creator(query, creator) do
    where(query, [c, _rc, creator_join], ilike(creator_join.creator_name, ^"%#{creator}%"))
  end

  defp filter_by_access_level(query, ""), do: query

  defp filter_by_access_level(query, access_level) do
    where(query, [c], c.access_level == ^access_level)
  end

  defp filter_by_collection_code(query, ""), do: query

  defp filter_by_collection_code(query, collection_code) do
    where(query, [c], ilike(c.collection_code, ^"%#{collection_code}%"))
  end

  defp filter_by_unit_id(query, ""), do: query

  defp filter_by_unit_id(query, unit_id) do
    case Integer.parse(unit_id) do
      {id, ""} -> where(query, [c], c.unit_id == ^id)
      _ -> query
    end
  end

  defp filter_by_resource_glam_type(query, ""), do: query

  defp filter_by_resource_glam_type(query, resource_glam_type) do
    where(query, [c, rc], rc.glam_type == ^resource_glam_type)
  end

  defp filter_by_resource_class(query, ""), do: query

  defp filter_by_resource_class(query, resource_class) do
    where(query, [c, rc], ilike(rc.label, ^"%#{resource_class}%"))
  end

  defp filter_by_collection_type(query, ""), do: query

  defp filter_by_collection_type(query, collection_type) do
    where(query, [c], ilike(c.collection_type, ^"%#{collection_type}%"))
  end

  defp filter_by_creator_type(query, ""), do: query

  defp filter_by_creator_type(query, creator_type) do
    where(query, [c, _rc, creator_join], creator_join.type == ^creator_type)
  end

  defp filter_by_creator_affiliation(query, ""), do: query

  defp filter_by_creator_affiliation(query, affiliation) do
    where(query, [c, _rc, creator_join], ilike(creator_join.affiliation, ^"%#{affiliation}%"))
  end

  defp filter_by_creator_contact(query, ""), do: query

  defp filter_by_creator_contact(query, contact) do
    where(query, [c, _rc, creator_join], ilike(creator_join.creator_contact, ^"%#{contact}%"))
  end

  defp filter_by_resource_template(query, ""), do: query

  defp filter_by_resource_template(query, template_label) do
    where(
      query,
      [c, _rc, _creator, _node, template],
      ilike(template.label, ^"%#{template_label}%")
    )
  end

  defp filter_by_media_type(query, ""), do: query
  defp filter_by_media_type(query, "all"), do: query

  defp filter_by_media_type(query, "digital") do
    where(
      query,
      [c],
      fragment(
        "EXISTS (SELECT 1 FROM attachments WHERE attachable_type = 'collection' AND attachable_id = ? AND is_primary = TRUE)",
        c.id
      )
    )
  end

  defp filter_by_media_type(query, "physical") do
    where(
      query,
      [c],
      fragment(
        "NOT EXISTS (SELECT 1 FROM attachments WHERE attachable_type = 'collection' AND attachable_id = ? AND is_primary = TRUE)",
        c.id
      )
    )
  end

  defp filter_by_node_name(query, ""), do: query

  defp filter_by_node_name(query, node_name) do
    where(query, [c, _rc, _creator, node_join], ilike(node_join.name, ^"%#{node_name}%"))
  end

  defp filter_by_node_abbr(query, ""), do: query

  defp filter_by_node_abbr(query, node_abbr) do
    where(query, [c, _rc, _creator, node_join], ilike(node_join.abbr, ^"%#{node_abbr}%"))
  end

  defp filter_by_created_by(query, ""), do: query

  defp filter_by_created_by(query, created_by_name) do
    where(
      query,
      [c, _rc, _creator, _node, _template, created_by_user],
      ilike(created_by_user.fullname, ^"%#{created_by_name}%") or
        ilike(created_by_user.username, ^"%#{created_by_name}%") or
        ilike(created_by_user.email, ^"%#{created_by_name}%")
    )
  end

  defp filter_by_updated_by(query, ""), do: query

  defp filter_by_updated_by(query, updated_by_name) do
    where(
      query,
      [c, _rc, _creator, _node, _template, _created_by, updated_by_user],
      ilike(updated_by_user.fullname, ^"%#{updated_by_name}%") or
        ilike(updated_by_user.username, ^"%#{updated_by_name}%") or
        ilike(updated_by_user.email, ^"%#{updated_by_name}%")
    )
  end

  defp filter_by_sort_order_min(query, ""), do: query

  defp filter_by_sort_order_min(query, min_order) do
    case Integer.parse(min_order) do
      {min_val, ""} -> where(query, [c], c.sort_order >= ^min_val)
      _ -> query
    end
  end

  defp filter_by_sort_order_max(query, ""), do: query

  defp filter_by_sort_order_max(query, max_order) do
    case Integer.parse(max_order) do
      {max_val, ""} -> where(query, [c], c.sort_order <= ^max_val)
      _ -> query
    end
  end
end
