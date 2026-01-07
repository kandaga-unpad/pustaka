defmodule Voile.Schema.Catalog do
  @moduledoc """
  The Catalog context.
  """

  import Ecto.Query, warn: false
  alias Voile.Repo

  alias Voile.Schema.Catalog.{
    Collection,
    Item,
    CollectionField,
    ItemFieldValue,
    Attachment,
    TransferRequest,
    StockOpnameSession,
    LibrarianAssignment,
    StockOpnameItem
  }

  @doc """
  Returns the list of collections.

  ## Examples

      iex> list_collections()
      [%Collection{}, ...]

  """
  def list_collections do
    Repo.all(Collection)
    |> Repo.preload([
      :resource_class,
      :resource_template,
      :mst_creator,
      :node,
      :collection_fields,
      :items
    ])
  end

  @doc """
  Return the list of collections for pagination with comprehensive filtering.
  ## Examples

      iex> list_collections_paginated(page, per_page, search, filters)
      {[%Collection{}, ...], total_pages}

  ## Filter options:
    * `:status` - Filter by collection status (draft, pending, published, archived)
    * `:access_level` - Filter by access level (public, private, restricted)
    * `:collection_type` - Filter by collection type (series, book, movie, etc.)
    * `:creator_id` - Filter by creator/author ID
    * `:node_id` - Filter by node/location ID
    * `:type_id` - Filter by resource class ID
    * `:parent_filter` - Filter hierarchy: "root" (no parent), "child" (has parent), or "all"
  """
  def list_collections_paginated(page \\ 1, per_page \\ 10, search \\ nil, filters \\ %{}) do
    offset = (page - 1) * per_page

    base_query =
      from c in Collection,
        order_by: [desc: c.inserted_at, desc: c.id]

    query =
      base_query
      |> maybe_search_collections(search)
      |> apply_collection_filters(filters)
      |> limit(^per_page)
      |> offset(^offset)

    # Only preload necessary associations for list view (not items)
    collections =
      Repo.all(query)
      |> Repo.preload([
        :collection_fields,
        :resource_class,
        :mst_creator,
        :node
      ])

    # Count query without preloads for better performance
    count_query =
      from c in Collection,
        select: count(c.id)

    total_count =
      count_query
      |> maybe_search_collections_for_count(search)
      |> apply_collection_filters(filters)
      |> Repo.one()

    total_pages = div(total_count + per_page - 1, per_page)

    {collections, total_pages, total_count}
  end

  defp maybe_search_collections(query, nil), do: query

  defp maybe_search_collections(query, search) when is_binary(search) and search != "" do
    like = "%#{search}%"

    from c in query,
      as: :collection,
      left_join: creator in assoc(c, :mst_creator),
      left_join: node in assoc(c, :node),
      left_join: rc in assoc(c, :resource_class),
      where:
        ilike(c.title, ^like) or
          ilike(c.description, ^like) or
          ilike(c.collection_type, ^like) or
          ilike(c.collection_code, ^like) or
          ilike(c.status, ^like) or
          ilike(c.access_level, ^like) or
          ilike(creator.creator_name, ^like) or
          ilike(node.name, ^like) or
          ilike(rc.label, ^like)
  end

  defp maybe_search_collections(query, _), do: query

  defp maybe_search_collections_for_count(query, nil), do: query

  defp maybe_search_collections_for_count(query, search)
       when is_binary(search) and search != "" do
    like = "%#{search}%"

    from c in query,
      left_join: creator in assoc(c, :mst_creator),
      left_join: node in assoc(c, :node),
      left_join: rc in assoc(c, :resource_class),
      where:
        ilike(c.title, ^like) or
          ilike(c.description, ^like) or
          ilike(c.collection_type, ^like) or
          ilike(c.collection_code, ^like) or
          ilike(c.status, ^like) or
          ilike(c.access_level, ^like) or
          ilike(creator.creator_name, ^like) or
          ilike(node.name, ^like) or
          ilike(rc.label, ^like)
  end

  defp maybe_search_collections_for_count(query, _), do: query

  defp apply_collection_filters(query, filters) do
    query
    |> filter_by_status(filters[:status])
    |> filter_by_access_level(filters[:access_level])
    |> filter_by_glam_type(filters[:glam_type])
    |> filter_by_node(filters[:node_id])
  end

  defp filter_by_status(query, nil), do: query
  defp filter_by_status(query, ""), do: query

  defp filter_by_status(query, status) when is_binary(status) do
    from c in query, where: c.status == ^status
  end

  defp filter_by_access_level(query, nil), do: query
  defp filter_by_access_level(query, ""), do: query

  defp filter_by_access_level(query, access_level) when is_binary(access_level) do
    from c in query, where: c.access_level == ^access_level
  end

  defp filter_by_glam_type(query, nil), do: query
  defp filter_by_glam_type(query, ""), do: query

  defp filter_by_glam_type(query, glam_type) when is_binary(glam_type) do
    from c in query,
      join: rc in assoc(c, :resource_class),
      where: rc.glam_type == ^glam_type
  end

  defp filter_by_node(query, nil), do: query
  defp filter_by_node(query, ""), do: query

  defp filter_by_node(query, node_id) when is_binary(node_id) do
    case Integer.parse(node_id) do
      {id, ""} -> from c in query, where: c.unit_id == ^id
      _ -> query
    end
  end

  defp filter_by_node(query, node_id) when is_integer(node_id) do
    from c in query, where: c.unit_id == ^node_id
  end

  @doc """
  List collections with automatic role-based filtering.
  This function applies filters based on the user's role and permissions:
  - Staff/Librarians: Filter by their assigned node automatically
  - Admins: See all collections
  - Users with specific collection permissions: See only permitted collections

  ## Examples

      iex> list_collections_for_user(user, page, per_page, search, filters)
      {[%Collection{}, ...], total_pages}
  """
  def list_collections_for_user(user, page \\ 1, per_page \\ 10, search \\ nil, filters \\ %{}) do
    filters = apply_role_based_filters(user, filters)
    list_collections_paginated(page, per_page, search, filters)
  end

  @doc """
  Apply automatic filters based on user role and permissions.
  Returns modified filters map with role-based restrictions applied.

  Staff members are automatically filtered to:
  - Their assigned node (location)
  - Their role-specific GLAM type:
    * Librarians → Library collections only
    * Archivists → Archive collections only
    * Gallery Curators → Gallery collections only
    * Museum Curators → Museum collections only

  ## Examples

      iex> apply_role_based_filters(librarian_user, %{})
      %{node_id: 5, glam_type: "Library"}  # librarian at node 5

      iex> apply_role_based_filters(admin_user, %{})
      %{}  # no additional filters for admin
  """
  def apply_role_based_filters(user, filters) do
    is_admin = is_user_admin?(user)

    cond do
      # Admins can see everything - don't add automatic filters
      is_admin ->
        filters

      # Staff members: apply node and role-based GLAM type filters
      true ->
        filters
        |> maybe_apply_node_filter(user)
        |> maybe_apply_glam_type_filter(user)
    end
  end

  defp maybe_apply_node_filter(filters, user) do
    # For non-admin users, ALWAYS force their node restriction
    # Admin users can select any node
    if user.node_id && !is_user_admin?(user) do
      # Force the user's node_id, ignoring any user-selected node
      Map.put(filters, :node_id, user.node_id)
    else
      # For admins, respect their node selection or leave it empty
      filters
    end
  end

  defp maybe_apply_glam_type_filter(filters, user) do
    # If no GLAM type filter is explicitly set, apply role-based filter
    if is_nil(filters[:glam_type]) do
      glam_type = get_user_glam_type(user)

      if glam_type do
        Map.put(filters, :glam_type, glam_type)
      else
        filters
      end
    else
      filters
    end
  end

  defp get_user_glam_type(user) do
    user_groups = user.groups || []

    cond do
      Enum.any?(user_groups, &(String.downcase(&1) in ["librarian", "library_staff"])) ->
        "Library"

      Enum.any?(user_groups, &(String.downcase(&1) in ["archivist", "archive_staff"])) ->
        "Archive"

      Enum.any?(user_groups, &(String.downcase(&1) in ["gallery_curator", "gallery_staff"])) ->
        "Gallery"

      Enum.any?(user_groups, &(String.downcase(&1) in ["museum_curator", "museum_staff"])) ->
        "Museum"

      true ->
        nil
    end
  end

  @doc """
  Check if a user is an admin.
  Admins can see all collections without restrictions.
  """
  def is_user_admin?(user) do
    # Check if user belongs to admin groups
    admin_groups = ["admin", "administrator", "super_admin", "system_admin"]
    user_groups = user.groups || []

    has_admin_group? =
      Enum.any?(user_groups, fn group ->
        String.downcase(group) in admin_groups
      end)

    # Also check if user has admin role via RBAC
    has_admin_role? =
      case Ecto.assoc_loaded?(user.roles) do
        true ->
          Enum.any?(user.roles || [], fn role ->
            String.downcase(role.name) in admin_groups or
              String.contains?(String.downcase(role.name), "admin")
          end)

        false ->
          # If roles not preloaded, check via database query
          Voile.Repo.exists?(
            from ur in Voile.Schema.Accounts.UserRoleAssignment,
              join: r in assoc(ur, :role),
              where:
                ur.user_id == ^user.id and
                  (is_nil(ur.expires_at) or ur.expires_at > ^DateTime.utc_now()) and
                  (fragment("LOWER(?)", r.name) in ^admin_groups or
                     fragment("LOWER(?) LIKE '%admin%'", r.name))
          )
      end

    has_admin_group? or has_admin_role?
  end

  @doc """
  Gets a single collection.

  Raises `Ecto.NoResultsError` if the Collection does not exist.

  ## Examples

      iex> get_collection!(123)
      %Collection{}

      iex> get_collection!(456)
      ** (Ecto.NoResultsError)

  """
  def get_collection!(id) do
    Collection
    |> Repo.get!(id)
    |> Repo.preload([
      :resource_class,
      :resource_template,
      :mst_creator,
      :node,
      :attachments,
      items: [:node],
      collection_fields: [:metadata_properties]
    ])
  end

  @doc """
  Creates a collection.

  ## Examples

      iex> create_collection(%{field: value})
      {:ok, %Collection{}}

      iex> create_collection(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_collection(attrs \\ %{}) do
    %Collection{}
    |> Collection.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a collection.

  ## Examples

      iex> update_collection(collection, %{field: new_value})
      {:ok, %Collection{}}

      iex> update_collection(collection, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_collection(%Collection{} = collection, attrs) do
    collection
    |> Collection.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a collection.

  ## Examples

      iex> delete_collection(collection)
      {:ok, %Collection{}}

      iex> delete_collection(collection)
      {:error, %Ecto.Changeset{}}

  """
  def delete_collection(%Collection{} = collection) do
    Repo.delete(collection)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking collection changes.

  ## Examples

      iex> change_collection(collection)
      %Ecto.Changeset{data: %Collection{}}

  """
  def change_collection(%Collection{} = collection, attrs \\ %{}) do
    collection
    |> Repo.preload([
      :resource_class,
      :resource_template,
      :mst_creator,
      :node,
      :collection_fields,
      :items,
      :parent,
      :children
    ])
    |> Collection.changeset(attrs)
  end

  def count_collections() do
    Repo.aggregate(Collection, :count, :id)
  end

  def count_collections(unit_id) when is_integer(unit_id) do
    from(c in Collection, where: c.unit_id == ^unit_id)
    |> Repo.aggregate(:count, :id)
  end

  @doc """
  Get collections organized in a hierarchical tree structure.
  Now with pagination to prevent loading too many records at once.

  ## Examples

      iex> list_collections_tree()
      [%Collection{children: [%Collection{}, ...]}, ...]

  """
  def list_collections_tree(limit \\ 100) do
    # Use a more efficient approach - get limited collections and build the tree in memory
    all_collections =
      Repo.all(
        from c in Collection,
          # Only include collections that have a parent (i.e. exclude root collections)
          where: not is_nil(c.parent_id),
          preload: [:mst_creator, :resource_class],
          order_by: [desc: c.updated_at, asc: c.title],
          limit: ^limit
      )

    # Build a map of parent_id -> children for quick lookup
    children_map =
      all_collections
      |> Enum.group_by(& &1.parent_id)

    # Get root collections and attach their children
    children_map[nil]
    |> Kernel.||([])
    |> Enum.map(&attach_children(&1, children_map, []))
  end

  defp attach_children(collection, children_map, visited) do
    # Prevent circular references
    if collection.id in visited do
      %{collection | children: []}
    else
      updated_visited = [collection.id | visited]

      children =
        children_map[collection.id]
        |> Kernel.||([])
        |> Enum.map(&attach_children(&1, children_map, updated_visited))

      %{collection | children: children}
    end
  end

  @doc """
  Get root collections (collections without parents).

  ## Examples

      iex> list_root_collections()
      [%Collection{}, ...]

  """
  def list_root_collections do
    Repo.all(
      from c in Collection,
        where: is_nil(c.parent_id),
        preload: [:mst_creator, :resource_class],
        order_by: [asc: c.sort_order, asc: c.title]
    )
  end

  @doc """
  Get child collections for a given parent collection.

  ## Examples

      iex> list_children_collections(parent_id)
      [%Collection{}, ...]

  """
  def list_children_collections(parent_id) do
    Repo.all(
      from c in Collection,
        where: c.parent_id == ^parent_id,
        preload: [:mst_creator, :resource_class],
        order_by: [asc: c.sort_order, asc: c.title]
    )
  end

  @doc """
  Get collections suitable for being parents (excludes the given collection itself and its descendants).

  ## Examples

      iex> list_potential_parent_collections(collection_id)
      [%Collection{}, ...]

  """
  def list_potential_parent_collections(collection_id \\ nil) do
    query =
      from c in Collection,
        preload: [:mst_creator, :resource_class],
        order_by: [asc: c.title],
        limit: 50

    query =
      if collection_id do
        from c in query, where: c.id != ^collection_id
      else
        query
      end

    Repo.all(query)
  end

  @doc """
  Search for potential parent collections by title.
  Returns limited results for performance.

  ## Examples

      iex> search_potential_parent_collections("Harry", collection_id)
      [%Collection{}, ...]

  """
  def search_potential_parent_collections(search_term, collection_id \\ nil, limit \\ 10) do
    search_pattern = "%#{search_term}%"

    query =
      from c in Collection,
        where: ilike(c.title, ^search_pattern),
        preload: [:mst_creator, :resource_class],
        order_by: [asc: c.title],
        limit: ^limit

    query =
      if collection_id do
        from c in query, where: c.id != ^collection_id
      else
        query
      end

    Repo.all(query)
  end

  @doc """
  Get the full path/breadcrumb for a collection.

  ## Examples

      iex> get_collection_path(collection)
      [%Collection{title: "Harry Potter Series"}, %Collection{title: "Harry Potter 1"}]

  """
  def get_collection_path(collection) do
    get_collection_path_recursive(collection, [])
  end

  defp get_collection_path_recursive(collection, acc) do
    acc = [collection | acc]

    if collection.parent_id do
      parent = get_collection!(collection.parent_id) |> Repo.preload(:parent)
      get_collection_path_recursive(parent, acc)
    else
      acc
    end
  end

  @doc """
  Remove and nilify the thumbnail of an existing collection.
  """

  def remove_thumbnail(%Collection{id: nil} = collection) do
    dbg(collection)
    {:error, :not_persisted}
  end

  def remove_thumbnail(%Collection{} = collection) do
    # Optional: delete file if needed
    file_path =
      case collection.thumbnail do
        nil -> nil
        path -> Path.join([:code.priv_dir(:voile), "static", path])
      end

    if file_path && File.exists?(file_path), do: File.rm(file_path)

    collection
    |> Collection.remove_thumbnail_changeset()
    |> Repo.update()
  end

  @doc """
  Returns the list of items.

  ## Examples

      iex> list_items()
      [%Item{}, ...]

  """
  def list_items do
    Repo.all(Item)
  end

  @doc """
  Gets a single item.

  Raises `Ecto.NoResultsError` if the Item does not exist.

  ## Examples

      iex> get_item!(123)
      %Item{}

      iex> get_item!(456)
      ** (Ecto.NoResultsError)

  """
  def get_item!(id) do
    Item
    |> Repo.get!(id)
    |> Repo.preload([
      :node,
      collection: [:mst_creator, :node]
    ])
  end

  @doc """
  Get a single item based on the item_code passed.
  """
  def get_item_by_code!(item_code) when is_binary(item_code) do
    Item
    |> Repo.get_by!(item_code: item_code)
    |> Repo.preload([
      :node,
      collection: [:mst_creator]
    ])
  end

  @doc """
  Get a single item based on the item_code passed. Returns nil if not found.
  """
  def get_item_by_code(item_code) when is_binary(item_code) do
    Item
    |> Repo.get_by(item_code: item_code)
    |> case do
      nil -> nil
      item -> Repo.preload(item, [:node, collection: [:mst_creator]])
    end
  end

  @doc """
  List items with pagination, search, and filters.

  ## Examples

      iex> list_items_paginated(1, 10, "book", %{node_id: 5})
      {[%Item{}, ...], 3}

      iex> list_items_paginated(1, 10, nil, %{status: "active"})
      {[%Item{}, ...], 5}
  """
  def list_items_paginated(page \\ 1, per_page \\ 10, search \\ nil, filters \\ %{}) do
    offset = (page - 1) * per_page

    # Build the base query for items
    base_query =
      from i in Item,
        order_by: [desc: i.inserted_at, desc: i.id]

    # Apply search and filters
    query =
      base_query
      |> maybe_search_items(search)
      |> apply_item_filters(filters)

    # Get item IDs first (fast, no preloads)
    item_ids_query = query |> select([i], i.id) |> limit(^per_page) |> offset(^offset)
    item_ids = Repo.all(item_ids_query)

    # Fetch full items with preloads only for the limited IDs
    items =
      if item_ids == [] do
        []
      else
        from(i in Item,
          where: i.id in ^item_ids,
          order_by: [desc: i.inserted_at, desc: i.id],
          preload: [:collection, :node]
        )
        |> Repo.all()
      end

    # Always calculate total_count for consistent API
    total_count = Repo.aggregate(query, :count, :id)
    total_pages = div(total_count + per_page - 1, per_page)

    {items, total_pages, total_count}
  end

  defp maybe_search_items(query, nil), do: query

  defp maybe_search_items(query, search) when is_binary(search) and search != "" do
    search = String.trim(search)
    like = "%#{search}%"

    from i in query,
      as: :item,
      where:
        ilike(i.item_code, ^like) or
          ilike(i.inventory_code, ^like) or
          ilike(i.location, ^like) or
          exists(
            from c in Collection,
              where: c.id == parent_as(:item).collection_id and ilike(c.title, ^like),
              select: 1
          )
  end

  defp maybe_search_items(query, _), do: query

  defp apply_item_filters(query, filters) when filters == %{}, do: query

  defp apply_item_filters(query, filters) do
    Enum.reduce(filters, query, fn
      {:node_id, nil}, q ->
        q

      {:node_id, ""}, q ->
        q

      {:node_id, node_id}, q when is_binary(node_id) ->
        node_id = String.to_integer(node_id)
        from i in q, where: i.unit_id == ^node_id

      {:node_id, node_id}, q when is_integer(node_id) ->
        from i in q, where: i.unit_id == ^node_id

      {:status, nil}, q ->
        q

      {:status, ""}, q ->
        q

      {:status, status}, q ->
        from i in q, where: i.status == ^status

      {:availability, nil}, q ->
        q

      {:availability, ""}, q ->
        q

      {:availability, availability}, q ->
        from i in q, where: i.availability == ^availability

      {:condition, nil}, q ->
        q

      {:condition, ""}, q ->
        q

      {:condition, condition}, q ->
        from i in q, where: i.condition == ^condition

      _, q ->
        q
    end)
  end

  @doc """
  Creates a item.

  ## Examples

      iex> create_item(%{field: value})
      {:ok, %Item{}}

      iex> create_item(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_item(attrs \\ %{}) do
    %Item{}
    |> Item.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a item.

  ## Examples

      iex> update_item(item, %{field: new_value})
      {:ok, %Item{}}

      iex> update_item(item, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_item(%Item{} = item, attrs) do
    item
    |> Item.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a item.

  ## Examples

      iex> delete_item(item)
      {:ok, %Item{}}

      iex> delete_item(item)
      {:error, %Ecto.Changeset{}}

  """
  def delete_item(%Item{} = item) do
    Repo.delete(item)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking item changes.

  ## Examples

      iex> change_item(item)
      %Ecto.Changeset{data: %Item{}}

  """
  def change_item(%Item{} = item, attrs \\ %{}) do
    Item.changeset(item, attrs)
  end

  def count_items() do
    Repo.aggregate(Item, :count, :id)
  end

  def count_items(unit_id) when is_integer(unit_id) do
    from(i in Item, where: i.unit_id == ^unit_id)
    |> Repo.aggregate(:count, :id)
  end

  def count_items_by_collection(collection_id) do
    from(i in Item, where: i.collection_id == ^collection_id)
    |> Repo.aggregate(:count, :id)
  end

  def list_available_items do
    query =
      from(i in Item,
        where: i.availability == "available" and i.status == "active",
        preload: [:collection, :node],
        order_by: [desc: i.inserted_at, desc: i.id]
      )

    query
    |> Repo.all()
  end

  def list_available_items_paginated(page \\ 1, per_page \\ 10) do
    offset = (page - 1) * per_page

    query =
      from i in Item,
        where: i.availability == "available" and i.status == "active",
        preload: [:collection, :node],
        order_by: [desc: i.inserted_at, desc: i.id],
        limit: ^per_page,
        offset: ^offset

    items = Repo.all(query)

    total_count =
      from(i in Item, where: i.availability == "available" and i.status == "active")
      |> Repo.aggregate(:count, :id)

    total_pages = div(total_count + per_page - 1, per_page)

    {items, total_pages, total_count}
  end

  def item_available?(item_id) do
    case Repo.get(Item, item_id) do
      %Item{availability: "available", status: "active"} -> true
      _ -> false
    end
  end

  def search_items(query_string) when is_binary(query_string) do
    search_term = "%#{query_string}%"

    Item
    |> join(:inner, [i], c in Collection, on: i.collection_id == c.id)
    |> where(
      [i, c],
      ilike(c.title, ^search_term) or
        ilike(c.description, ^search_term) or
        ilike(i.item_code, ^search_term) or
        ilike(i.inventory_code, ^search_term) or
        ilike(i.location, ^search_term)
    )
    |> where([i], i.status == "active")
    |> order_by([i], asc: i.item_code, desc: i.inserted_at)
    |> limit(50)
    |> preload([:item_location, :node, collection: [:collection_fields, :mst_creator]])
    |> Repo.all()
  end

  def search_collections(query_string) when is_binary(query_string) do
    search_term = "%#{query_string}%"

    Collection
    |> where(
      [c],
      ilike(c.title, ^search_term) or
        ilike(c.description, ^search_term) or
        ilike(c.collection_code, ^search_term)
    )
    |> where([c], c.status == "published")
    |> order_by([c], asc: c.title)
    |> limit(50)
    |> preload([:mst_creator])
    |> Repo.all()
  end

  def get_items_by_collection(collection_id) do
    Item
    |> where([i], i.collection_id == ^collection_id)
    |> where([i], i.status == "active")
    |> order_by([i], asc: i.item_code)
    |> preload([:item_location, :node, collection: [:collection_fields, :mst_creator]])
    |> Repo.all()
  end

  def search_items_paginated(query_string, page \\ 1, per_page \\ 10)
      when is_binary(query_string) do
    offset = (page - 1) * per_page
    search_term = "%#{query_string}%"

    base_query =
      Item
      |> join(:inner, [i], c in Collection, on: i.collection_id == c.id)
      |> where(
        [i, c],
        ilike(c.title, ^search_term) or
          ilike(i.description, ^search_term) or
          ilike(i.item_code, ^search_term) or
          ilike(i.inventory_code, ^search_term)
      )
      |> where([i], i.status == "active")

    query =
      from [i, c] in base_query,
        preload: [:collection, :node],
        order_by: [desc: i.inserted_at, desc: i.id],
        limit: ^per_page,
        offset: ^offset

    items = Repo.all(query)

    total_count = Repo.aggregate(base_query, :count, :id)
    total_pages = div(total_count + per_page - 1, per_page)

    {items, total_pages, total_count}
  end

  @doc """
  Returns the list of collection_fields.

  ## Examples

      iex> list_collection_fields()
      [%CollectionField{}, ...]

  """
  def list_collection_fields do
    Repo.all(CollectionField)
  end

  @doc """
  Gets a single collection_field.

  Raises `Ecto.NoResultsError` if the Collection field does not exist.

  ## Examples

      iex> get_collection_field!(123)
      %CollectionField{}

      iex> get_collection_field!(456)
      ** (Ecto.NoResultsError)

  """
  def get_collection_field!(id), do: Repo.get!(CollectionField, id)

  @doc """
  Creates a collection_field.

  ## Examples

      iex> create_collection_field(%{field: value})
      {:ok, %CollectionField{}}

      iex> create_collection_field(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_collection_field(attrs \\ %{}) do
    %CollectionField{}
    |> CollectionField.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a collection_field.

  ## Examples

      iex> update_collection_field(collection_field, %{field: new_value})
      {:ok, %CollectionField{}}

      iex> update_collection_field(collection_field, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_collection_field(%CollectionField{} = collection_field, attrs) do
    collection_field
    |> CollectionField.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a collection_field.

  ## Examples

      iex> delete_collection_field(collection_field)
      {:ok, %CollectionField{}}

      iex> delete_collection_field(collection_field)
      {:error, %Ecto.Changeset{}}

  """
  def delete_collection_field(%CollectionField{} = collection_field) do
    Repo.delete(collection_field)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking collection_field changes.

  ## Examples

      iex> change_collection_field(collection_field)
      %Ecto.Changeset{data: %CollectionField{}}

  """
  def change_collection_field(%CollectionField{} = collection_field, attrs \\ %{}) do
    CollectionField.changeset(collection_field, attrs)
  end

  @doc """
  Returns the list of item_field_values.

  ## Examples

      iex> list_item_field_values()
      [%ItemFieldValue{}, ...]

  """
  def list_item_field_values do
    Repo.all(ItemFieldValue)
  end

  @doc """
  Gets a single item_field_value.

  Raises `Ecto.NoResultsError` if the Item field value does not exist.

  ## Examples

      iex> get_item_field_value!(123)
      %ItemFieldValue{}

      iex> get_item_field_value!(456)
      ** (Ecto.NoResultsError)

  """
  def get_item_field_value!(id), do: Repo.get!(ItemFieldValue, id)

  @doc """
  Creates a item_field_value.

  ## Examples

      iex> create_item_field_value(%{field: value})
      {:ok, %ItemFieldValue{}}

      iex> create_item_field_value(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_item_field_value(attrs \\ %{}) do
    %ItemFieldValue{}
    |> ItemFieldValue.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a item_field_value.

  ## Examples

      iex> update_item_field_value(item_field_value, %{field: new_value})
      {:ok, %ItemFieldValue{}}

      iex> update_item_field_value(item_field_value, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_item_field_value(%ItemFieldValue{} = item_field_value, attrs) do
    item_field_value
    |> ItemFieldValue.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a item_field_value.

  ## Examples

      iex> delete_item_field_value(item_field_value)
      {:ok, %ItemFieldValue{}}

      iex> delete_item_field_value(item_field_value)
      {:error, %Ecto.Changeset{}}

  """
  def delete_item_field_value(%ItemFieldValue{} = item_field_value) do
    Repo.delete(item_field_value)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking item_field_value changes.

  ## Examples

      iex> change_item_field_value(item_field_value)
      %Ecto.Changeset{data: %ItemFieldValue{}}

  """
  def change_item_field_value(%ItemFieldValue{} = item_field_value, attrs \\ %{}) do
    ItemFieldValue.changeset(item_field_value, attrs)
  end

  @doc """
  Create attachment for a given entity using the new storage system

  Supports both legacy format (%{upload: upload, description: description})
  and new format (%{file_url: file_url, filename: filename, content_type: content_type, description: description})
  """
  def create_attachment(entity, %{upload: upload, description: description} = params) do
    # Legacy format - upload the file first, then create record
    case Client.Storage.upload(upload, folder: "attachments") do
      {:ok, file_url} ->
        file_size = Map.get(params, :file_size) || get_file_size_from_upload(upload)

        create_attachment_record(entity, %{
          file_url: file_url,
          filename: upload.filename,
          content_type: upload.content_type,
          description: description,
          file_size: file_size
        })

      {:error, reason} ->
        {:error, reason}
    end
  end

  def create_attachment(
        entity,
        %{
          file_url: file_url,
          filename: filename,
          content_type: content_type,
          description: description
        } = params
      ) do
    # New format - file already uploaded
    file_size = Map.get(params, :file_size) || get_file_size_from_url(file_url)

    create_attachment_record(entity, %{
      file_url: file_url,
      filename: filename,
      content_type: content_type,
      description: description,
      file_size: file_size
    })
  end

  @doc """
  Create multiple attachments for an entity
  """
  def create_attachments(entity, files_params) when is_list(files_params) do
    results = Enum.map(files_params, &create_attachment(entity, &1))

    case Enum.split_with(results, &match?({:ok, _}, &1)) do
      {successes, []} ->
        attachments = Enum.map(successes, fn {:ok, attachment} -> attachment end)
        {:ok, attachments}

      {_, errors} ->
        {:error, errors}
    end
  end

  @doc """
  Get all attachments for an entity
  """
  def list_attachments(%Collection{id: id}) do
    Attachment
    |> Attachment.for_entity(id, "collection")
    |> Repo.all()
  end

  def list_attachments(%Item{id: id}) do
    Attachment
    |> Attachment.for_entity(id, "item")
    |> Repo.all()
  end

  @doc """
  Get one attachments based on the id
  """
  def get_attachment!(id) do
    attachment =
      Attachment
      |> Repo.get!(id)

    # Load the polymorphic attachable (collection or item)
    attachment
    |> load_attachable()
  end

  @doc """
  Load the polymorphic attachable entity (collection or item) for an attachment
  """
  def load_attachable(%Attachment{attachable_type: "collection", attachable_id: id} = attachment) do
    collection = Repo.get(Collection, id)
    Map.put(attachment, :attachable, collection)
  end

  def load_attachable(%Attachment{attachable_type: "item", attachable_id: id} = attachment) do
    item = Repo.get(Item, id)
    Map.put(attachment, :attachable, item)
  end

  def load_attachable(attachment), do: attachment

  @doc """
  Get attachments filtered by file type
  """
  def list_attachments_by_type(entity, file_type) do
    entity
    |> list_attachments()
    |> Enum.filter(&(&1.file_type == file_type))
  end

  @doc """
  Get primary attachment for an entity
  """
  def get_primary_attachment(%Collection{id: id}) do
    Attachment
    |> Attachment.primary_for_entity(id, "collection")
    |> Repo.one()
  end

  def get_primary_attachment(%Item{id: id}) do
    Attachment
    |> Attachment.primary_for_entity(id, "item")
    |> Repo.one()
  end

  @doc """
  Update attachment
  """
  def update_attachment(%Attachment{} = attachment, attrs) do
    attachment
    |> Attachment.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Delete attachment and its file using the storage system
  """
  def delete_attachment(%Attachment{} = attachment) do
    # Delete file using storage system
    case Client.Storage.delete(attachment.file_path) do
      {:ok, _} ->
        # File deleted successfully, now delete the database record
        Repo.delete(attachment)

      {:error, reason} ->
        # Log the error but still try to delete the database record
        IO.inspect("Failed to delete file #{attachment.file_path}: #{inspect(reason)}")
        Repo.delete(attachment)
    end
  end

  @doc """
  Set attachment as primary (unsets other primary attachments for the same entity)
  """
  def set_primary_attachment(%Attachment{} = attachment) do
    Repo.transaction(fn ->
      # Unset all primary attachments for this entity
      from(a in Attachment,
        where:
          a.attachable_id == ^attachment.attachable_id and
            a.attachable_type == ^attachment.attachable_type and
            a.id != ^attachment.id
      )
      |> Repo.update_all(set: [is_primary: false])

      # Set this attachment as primary
      attachment
      |> Attachment.changeset(%{is_primary: true})
      |> Repo.update()
    end)
  end

  @doc """
  Reorder attachments for an entity
  """
  def reorder_attachments(entity, attachment_ids) when is_list(attachment_ids) do
    entity_type = get_entity_type(entity)
    entity_id = entity.id

    Repo.transaction(fn ->
      attachment_ids
      |> Enum.with_index()
      |> Enum.each(fn {attachment_id, index} ->
        from(a in Attachment,
          where:
            a.id == ^attachment_id and
              a.attachable_id == ^entity_id and
              a.attachable_type == ^entity_type
        )
        |> Repo.update_all(set: [sort_order: index])
      end)
    end)
  end

  @doc """
  Get file path for serving
  """
  def get_file_url(%Attachment{} = attachment) do
    # Return the file path as-is if it already contains the full path
    # This handles both asset_vault files and regular attachment files
    if attachment.file_path && String.starts_with?(attachment.file_path, "/uploads") do
      attachment.file_path
    else
      # Fallback for legacy attachments that only have filename
      "/uploads/attachments/#{Path.basename(attachment.file_path)}"
    end
  end

  # Private functions

  defp create_attachment_record(entity, %{
         file_url: file_url,
         filename: filename,
         content_type: content_type,
         description: description,
         file_size: file_size
       }) do
    entity_type = get_entity_type(entity)
    entity_id = entity.id

    # Extract file_key from file_url
    file_key = extract_file_key_from_url(file_url)

    # Get unit_id from entity if available
    unit_id = Map.get(entity, :unit_id)

    attrs = %{
      # Extract filename from URL
      file_name: Path.basename(file_url),
      original_name: filename,
      # Store the full URL/path
      file_path: file_url,
      # Store storage key for Client.Storage operations
      file_key: file_key,
      file_size: file_size,
      mime_type: content_type,
      file_type: Attachment.determine_file_type(content_type),
      description: description || "",
      sort_order: 0,
      is_primary: false,
      metadata: %{
        upload_date: DateTime.utc_now(),
        original_size: file_size
      },
      attachable_id: entity_id,
      attachable_type: entity_type,
      unit_id: unit_id
    }

    %Attachment{}
    |> Attachment.changeset(attrs)
    |> Repo.insert()
  end

  defp get_file_size_from_upload(%Plug.Upload{path: path}) do
    case File.stat(path) do
      {:ok, %{size: size}} -> size
      {:error, _} -> 0
    end
  end

  defp get_file_size_from_url(file_url) do
    # For local files, try to get actual file size
    if String.starts_with?(file_url, "/uploads") do
      local_path = Path.join(["priv/static", file_url])

      case File.stat(local_path) do
        {:ok, %{size: size}} -> size
        {:error, _} -> 0
      end
    else
      # For S3 URLs, we can't easily get size, return 0
      # You might want to store size during upload for S3 files
      0
    end
  end

  defp get_entity_type(%Collection{}), do: "collection"
  defp get_entity_type(%Item{}), do: "item"

  # Extract file key from storage URL for Client.Storage operations
  # Handles both /uploads/path and full URLs
  defp extract_file_key_from_url(file_url) when is_binary(file_url) do
    cond do
      String.starts_with?(file_url, "/uploads/") ->
        String.trim_leading(file_url, "/uploads/")

      String.contains?(file_url, "/uploads/") ->
        file_url
        |> String.split("/uploads/")
        |> List.last()

      true ->
        file_url
    end
  end

  defp extract_file_key_from_url(_), do: nil

  @doc """
  Get attachment statistics for an entity
  """
  def get_attachment_stats(entity) do
    attachments = list_attachments(entity)

    %{
      total_count: length(attachments),
      total_size: Enum.sum(Enum.map(attachments, & &1.file_size)),
      by_type:
        Enum.group_by(attachments, & &1.file_type)
        |> Enum.map(fn {type, items} -> {type, length(items)} end)
        |> Enum.into(%{})
    }
  end

  @doc """
  Search attachments by filename or description
  """
  def search_attachments(entity, query) when is_binary(query) do
    entity
    |> list_attachments()
    |> Enum.filter(fn attachment ->
      String.contains?(String.downcase(attachment.file_name), String.downcase(query)) ||
        (attachment.description &&
           String.contains?(String.downcase(attachment.description), String.downcase(query)))
    end)
  end

  @doc """
  Find item by barcode scan.
  Supports both full item_code and shortened barcode format.

  ## Examples

      iex> find_item_by_barcode("c47e6d008b3a001")
      %Item{}

      iex> find_item_by_barcode("kandaga-book-9c195395-d002-4c2a-8bfb-c47e6d008b3a-1761276668-001")
      %Item{}
  """
  def find_item_by_barcode(code) when is_binary(code) do
    code = String.trim(code)

    # Try direct barcode lookup first (for items imported with barcode field)
    item =
      Repo.one(
        from i in Item,
          where: i.barcode == ^code,
          preload: [:collection, :node]
      )

    # Fallback to item_code lookup for backward compatibility
    # (items that were created before barcode field was added)
    if item do
      item
    else
      Repo.one(
        from i in Item,
          where: i.item_code == ^code,
          preload: [:collection, :node]
      )
    end
  end

  def find_item_by_barcode(_), do: nil

  ## Transfer Requests

  @doc """
  Returns the list of transfer_requests with optional filtering.

  ## Examples

      iex> list_transfer_requests()
      [%TransferRequest{}, ...]

      iex> list_transfer_requests(%{status: "pending"})
      [%TransferRequest{status: "pending"}, ...]
  """
  def list_transfer_requests(filters \\ %{}) do
    query = from(tr in TransferRequest)

    query
    |> apply_transfer_filters(filters)
    |> order_by([tr], desc: tr.inserted_at)
    |> Repo.all()
    |> Repo.preload(
      item: [:collection, :node],
      from_node: [],
      to_node: [],
      requested_by: [],
      reviewed_by: []
    )
  end

  defp apply_transfer_filters(query, filters) do
    Enum.reduce(filters, query, fn
      {:status, status}, q when not is_nil(status) ->
        from tr in q, where: tr.status == ^status

      {:to_node_id, node_id}, q when not is_nil(node_id) ->
        from tr in q, where: tr.to_node_id == ^node_id

      {:from_node_id, node_id}, q when not is_nil(node_id) ->
        from tr in q, where: tr.from_node_id == ^node_id

      {:requested_by_id, user_id}, q when not is_nil(user_id) ->
        from tr in q, where: tr.requested_by_id == ^user_id

      {:item_id, item_id}, q when not is_nil(item_id) ->
        from tr in q, where: tr.item_id == ^item_id

      _, q ->
        q
    end)
  end

  @doc """
  Gets a single transfer_request.
  """
  def get_transfer_request!(id) do
    Repo.get!(TransferRequest, id)
    |> Repo.preload(
      item: [:collection, :node],
      from_node: [],
      to_node: [],
      requested_by: [],
      reviewed_by: []
    )
  end

  @doc """
  Creates a transfer_request.
  """
  def create_transfer_request(attrs \\ %{}) do
    %TransferRequest{}
    |> TransferRequest.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a transfer_request.
  """
  def update_transfer_request(%TransferRequest{} = transfer_request, attrs) do
    transfer_request
    |> TransferRequest.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Reviews a transfer request (approve or deny).
  """
  def review_transfer_request(%TransferRequest{} = transfer_request, attrs) do
    transfer_request
    |> TransferRequest.review_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Approves a transfer request and executes the location transfer.
  """
  def approve_transfer_request(%TransferRequest{} = transfer_request, reviewed_by_id) do
    Repo.transaction(fn ->
      # Update transfer request status
      {:ok, transfer_request} =
        review_transfer_request(transfer_request, %{
          status: "approved",
          reviewed_by_id: reviewed_by_id,
          reviewed_at: DateTime.utc_now()
        })

      # Get the item and update its location
      item = get_item!(transfer_request.item_id)

      {:ok, item} =
        update_item(item, %{
          unit_id: transfer_request.to_node_id,
          location: transfer_request.to_location
        })

      # Mark transfer as completed
      {:ok, transfer_request} =
        update_transfer_request(transfer_request, %{
          completed_at: DateTime.utc_now()
        })

      {transfer_request, item}
    end)
  end

  @doc """
  Denies a transfer request.
  """
  def deny_transfer_request(%TransferRequest{} = transfer_request, reviewed_by_id, notes \\ nil) do
    review_transfer_request(transfer_request, %{
      status: "denied",
      reviewed_by_id: reviewed_by_id,
      reviewed_at: DateTime.utc_now(),
      notes: notes
    })
  end

  @doc """
  Cancels a transfer request (by requester).
  """
  def cancel_transfer_request(%TransferRequest{} = transfer_request) do
    update_transfer_request(transfer_request, %{
      status: "cancelled"
    })
  end

  @doc """
  Deletes a transfer_request.
  """
  def delete_transfer_request(%TransferRequest{} = transfer_request) do
    Repo.delete(transfer_request)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking transfer_request changes.
  """
  def change_transfer_request(%TransferRequest{} = transfer_request, attrs \\ %{}) do
    TransferRequest.changeset(transfer_request, attrs)
  end

  @doc """
  Get pending transfer requests for a specific node (target node).
  """
  def list_pending_transfers_for_node(node_id) do
    list_transfer_requests(%{status: "pending", to_node_id: node_id})
  end

  @doc """
  Get transfer request history for an item.
  """
  def list_transfer_history_for_item(item_id) do
    list_transfer_requests(%{item_id: item_id})
  end

  # ===========================================================================
  # STOCK OPNAME / INVENTORY CHECK FUNCTIONS
  # ===========================================================================

  @doc """
  Creates a new stock opname session (Super Admin only).

  ## Examples

      iex> create_stock_opname_session(%{title: "Jan 2026 Inventory", ...}, admin_user)
      {:ok, %StockOpnameSession{}}

  """
  def create_stock_opname_session(attrs \\ %{}, user) do
    %StockOpnameSession{}
    |> StockOpnameSession.changeset(Map.put(attrs, "created_by_id", user.id))
    |> Repo.insert()
  end

  @doc """
  List stock opname sessions with pagination and filters.

  ## Filter options:
    * `:status` - Filter by session status
    * `:node_id` - Filter by node
    * `:created_by_id` - Filter by creator
    * `:from_date` - Filter sessions created after this date
    * `:to_date` - Filter sessions created before this date
  """
  def list_stock_opname_sessions(page \\ 1, per_page \\ 10, filters \\ %{}) do
    base_query =
      from s in StockOpnameSession,
        order_by: [desc: s.inserted_at],
        preload: [:created_by, :reviewed_by, :librarian_assignments]

    query =
      base_query
      |> maybe_filter_by_status(filters[:status])
      |> maybe_filter_by_date_range(filters[:from_date], filters[:to_date])
      |> maybe_filter_by_creator(filters[:created_by_id])

    total_count = Repo.aggregate(query, :count, :id)
    total_pages = ceil(total_count / per_page)
    offset = (page - 1) * per_page

    sessions =
      query
      |> limit(^per_page)
      |> offset(^offset)
      |> Repo.all()

    {sessions, total_pages, total_count}
  end

  defp maybe_filter_by_status(query, nil), do: query
  defp maybe_filter_by_status(query, ""), do: query
  defp maybe_filter_by_status(query, status), do: from(s in query, where: s.status == ^status)

  defp maybe_filter_by_date_range(query, nil, nil), do: query

  defp maybe_filter_by_date_range(query, from_date, nil) when not is_nil(from_date) do
    from(s in query, where: s.inserted_at >= ^from_date)
  end

  defp maybe_filter_by_date_range(query, nil, to_date) when not is_nil(to_date) do
    from(s in query, where: s.inserted_at <= ^to_date)
  end

  defp maybe_filter_by_date_range(query, from_date, to_date) do
    from(s in query, where: s.inserted_at >= ^from_date and s.inserted_at <= ^to_date)
  end

  defp maybe_filter_by_creator(query, nil), do: query
  defp maybe_filter_by_creator(query, ""), do: query

  defp maybe_filter_by_creator(query, creator_id),
    do: from(s in query, where: s.created_by_id == ^creator_id)

  @doc """
  Get a single stock opname session with all associations preloaded.
  """
  def get_stock_opname_session!(id) do
    StockOpnameSession
    |> Repo.get!(id)
    |> Repo.preload([
      :created_by,
      :updated_by,
      :reviewed_by,
      librarian_assignments: [:user],
      items: [:item, :collection, :checked_by]
    ])
  end

  @doc """
  Update a stock opname session.
  """
  def update_stock_opname_session(%StockOpnameSession{} = session, attrs, user) do
    session
    |> StockOpnameSession.changeset(Map.put(attrs, "updated_by_id", user.id))
    |> Repo.update()
  end

  @doc """
  Assign librarians to a session.
  Creates LibrarianAssignment records for each user.
  """
  def assign_librarians_to_session(%StockOpnameSession{} = session, user_ids, _admin_user)
      when is_list(user_ids) do
    Ecto.Multi.new()
    |> Ecto.Multi.run(:assignments, fn repo, _changes ->
      assignments =
        Enum.map(user_ids, fn user_id ->
          %LibrarianAssignment{}
          |> LibrarianAssignment.changeset(%{
            session_id: session.id,
            user_id: user_id,
            work_status: "pending"
          })
          |> repo.insert()
        end)

      errors = Enum.filter(assignments, fn result -> match?({:error, _}, result) end)

      if errors == [] do
        {:ok, Enum.map(assignments, fn {:ok, a} -> a end)}
      else
        {:error, List.first(errors) |> elem(1)}
      end
    end)
    |> Ecto.Multi.run(:initialize_items, fn _repo, %{assignments: _assignments} ->
      initialize_session_items(session)
    end)
    |> Repo.transaction()
  end

  defp initialize_session_items(%StockOpnameSession{} = session) do
    # Build query based on session scope
    items_query =
      from i in Item,
        where: i.unit_id in ^session.node_ids,
        join: c in Collection,
        on: c.id == i.collection_id,
        where: c.collection_type in ^session.collection_types,
        preload: [:collection]

    items_query =
      case session.scope_type do
        "collection" when not is_nil(session.scope_id) ->
          from i in items_query, where: i.collection_id == ^session.scope_id

        "location" when not is_nil(session.scope_id) ->
          from i in items_query, where: i.item_location_id == type(^session.scope_id, :integer)

        _ ->
          items_query
      end

    items = Repo.all(items_query)
    total_items = length(items)

    # Create StockOpnameItem records for each item
    opname_items =
      Enum.map(items, fn item ->
        attrs = StockOpnameItem.snapshot_from_item(item, session.id)

        %StockOpnameItem{}
        |> StockOpnameItem.changeset(attrs)
        |> Repo.insert!()
      end)

    # Update session total_items counter
    session
    |> Ecto.Changeset.change(total_items: total_items)
    |> Repo.update!()

    {:ok, opname_items}
  end

  @doc """
  Start a stock opname session (draft → in_progress).
  Only Super Admin can start sessions.
  """
  def start_stock_opname_session(%StockOpnameSession{status: "draft"} = session, admin_user) do
    session
    |> Ecto.Changeset.change(%{
      status: "in_progress",
      started_at: DateTime.utc_now(),
      updated_by_id: admin_user.id
    })
    |> Repo.update()
  end

  def start_stock_opname_session(%StockOpnameSession{}, _admin_user) do
    {:error, :invalid_status}
  end

  @doc """
  Check if all assigned librarians have completed their work.
  """
  def all_librarians_completed?(%StockOpnameSession{} = session) do
    session = Repo.preload(session, :librarian_assignments, force: true)

    Enum.all?(session.librarian_assignments, fn assignment ->
      assignment.work_status == "completed"
    end)
  end

  @doc """
  Start a librarian's work session.
  """
  def start_librarian_work(%StockOpnameSession{} = session, user) do
    assignment =
      Repo.get_by(LibrarianAssignment, session_id: session.id, user_id: user.id)

    if assignment do
      assignment
      |> Ecto.Changeset.change(%{
        work_status: "in_progress",
        started_at: DateTime.utc_now()
      })
      |> Repo.update()
    else
      {:error, :not_assigned}
    end
  end

  @doc """
  Complete a librarian's work session.
  """
  def complete_librarian_work(%StockOpnameSession{} = session, user, notes \\ nil) do
    assignment =
      Repo.get_by(LibrarianAssignment, session_id: session.id, user_id: user.id)

    if assignment do
      assignment
      |> Ecto.Changeset.change(%{
        work_status: "completed",
        completed_at: DateTime.utc_now(),
        notes: notes
      })
      |> Repo.update()
    else
      {:error, :not_assigned}
    end
  end

  @doc """
  Get librarian's progress in a session.
  """
  def get_librarian_progress(%StockOpnameSession{} = session, user) do
    assignment =
      Repo.get_by(LibrarianAssignment, session_id: session.id, user_id: user.id)

    if assignment do
      {:ok, assignment}
    else
      {:error, :not_assigned}
    end
  end

  @doc """
  Search for items by barcode, legacy_item_code, or item_code.
  Returns a list to handle duplicates.
  """
  def find_items_for_scanning(%StockOpnameSession{} = session, search_term)
      when is_binary(search_term) do
    search_term = String.trim(search_term)

    # Search in items that are part of this session
    from(oi in StockOpnameItem,
      where: oi.session_id == ^session.id,
      join: i in Item,
      on: i.id == oi.item_id,
      where:
        i.barcode == ^search_term or
          i.legacy_item_code == ^search_term or
          i.item_code == ^search_term,
      preload: [item: [:collection]]
    )
    |> Repo.all()
  end

  @doc """
  Add an item to the session with snapshot (transaction-based).
  This is called when initializing the session, not during scanning.
  """
  def add_item_to_session(%StockOpnameSession{} = session, item_id, _user) do
    item = get_item!(item_id)
    attrs = StockOpnameItem.snapshot_from_item(item, session.id)

    %StockOpnameItem{}
    |> StockOpnameItem.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Mark an item as checked with optional updates.
  Uses transaction to prevent race conditions.
  """
  def check_item_in_session(%StockOpnameSession{} = session, opname_item_id, attrs, user) do
    Ecto.Multi.new()
    |> Ecto.Multi.run(:lock_item, fn repo, _changes ->
      # Lock the opname_item row to prevent concurrent updates
      opname_item =
        from(oi in StockOpnameItem,
          where: oi.id == ^opname_item_id and oi.session_id == ^session.id,
          lock: "FOR UPDATE"
        )
        |> repo.one()

      if opname_item do
        {:ok, opname_item}
      else
        {:error, :not_found}
      end
    end)
    |> Ecto.Multi.update(:update_item, fn %{lock_item: opname_item} ->
      opname_item
      |> StockOpnameItem.changeset(
        Map.merge(attrs, %{
          "check_status" => "checked",
          "scanned_at" => DateTime.utc_now(),
          "checked_by_id" => user.id
        })
      )
    end)
    |> Ecto.Multi.run(:update_counters, fn repo, %{update_item: updated_item} ->
      # Update session counters
      session = repo.get!(StockOpnameSession, session.id)

      new_checked_count =
        from(oi in StockOpnameItem,
          where: oi.session_id == ^session.id and oi.check_status == "checked"
        )
        |> repo.aggregate(:count, :id)

      new_changes_count =
        from(oi in StockOpnameItem,
          where: oi.session_id == ^session.id and oi.has_changes == true
        )
        |> repo.aggregate(:count, :id)

      session
      |> Ecto.Changeset.change(%{
        checked_items: new_checked_count,
        items_with_changes: new_changes_count
      })
      |> repo.update()

      # Update librarian's checked count
      assignment = repo.get_by(LibrarianAssignment, session_id: session.id, user_id: user.id)

      if assignment do
        librarian_checked_count =
          from(oi in StockOpnameItem,
            where: oi.session_id == ^session.id and oi.checked_by_id == ^user.id
          )
          |> repo.aggregate(:count, :id)

        assignment
        |> Ecto.Changeset.change(items_checked: librarian_checked_count)
        |> repo.update!()
      end

      {:ok, updated_item}
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{update_item: opname_item}} -> {:ok, opname_item}
      {:error, _step, error, _changes} -> {:error, error}
    end
  end

  @doc """
  Get session statistics.
  """
  def get_session_statistics(%StockOpnameSession{} = session) do
    session = Repo.preload(session, :items, force: true)

    %{
      total_items: session.total_items,
      checked_items: session.checked_items,
      pending_items: session.total_items - session.checked_items,
      missing_items: session.missing_items,
      items_with_changes: session.items_with_changes,
      progress_percentage:
        if(session.total_items > 0,
          do: Float.round(session.checked_items / session.total_items * 100, 1),
          else: 0.0
        )
    }
  end

  @doc """
  List session items filtered by check status.
  """
  def list_session_items(%StockOpnameSession{} = session, check_status \\ nil) do
    query =
      from oi in StockOpnameItem,
        where: oi.session_id == ^session.id,
        order_by: [desc: oi.updated_at],
        preload: [:item, :collection, :checked_by]

    query =
      if check_status do
        from oi in query, where: oi.check_status == ^check_status
      else
        query
      end

    Repo.all(query)
  end

  @doc """
  Complete a stock opname session (in_progress → pending_review).
  Flags unscanned items as missing within the session scope.
  Only Super Admin can complete sessions.
  """
  def complete_stock_opname_session(
        %StockOpnameSession{status: "in_progress"} = session,
        admin_user
      ) do
    Ecto.Multi.new()
    |> Ecto.Multi.run(:flag_missing, fn repo, _changes ->
      # Flag unscanned items as missing
      {count, _} =
        from(oi in StockOpnameItem,
          where: oi.session_id == ^session.id and oi.check_status == "pending"
        )
        |> repo.update_all(set: [check_status: "missing", updated_at: DateTime.utc_now()])

      {:ok, count}
    end)
    |> Ecto.Multi.run(:update_session, fn repo, %{flag_missing: missing_count} ->
      session
      |> Ecto.Changeset.change(%{
        status: "pending_review",
        completed_at: DateTime.utc_now(),
        updated_by_id: admin_user.id,
        missing_items: missing_count
      })
      |> repo.update()
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{update_session: session}} -> {:ok, session}
      {:error, _step, error, _changes} -> {:error, error}
    end
  end

  def complete_stock_opname_session(%StockOpnameSession{}, _admin_user) do
    {:error, :invalid_status}
  end

  @doc """
  Cancel a stock opname session.
  """
  def cancel_stock_opname_session(%StockOpnameSession{} = session, admin_user) do
    session
    |> Ecto.Changeset.change(%{
      status: "cancelled",
      updated_by_id: admin_user.id
    })
    |> Repo.update()
  end

  @doc """
  List sessions pending review (Super Admin).
  """
  def list_sessions_pending_review(page \\ 1, per_page \\ 10) do
    list_stock_opname_sessions(page, per_page, %{status: "pending_review"})
  end

  @doc """
  Get session review summary with detailed statistics.
  """
  def get_session_review_summary(%StockOpnameSession{} = session) do
    session = Repo.preload(session, [:items, librarian_assignments: [:user]], force: true)

    items_by_status =
      Enum.group_by(session.items, & &1.check_status)
      |> Enum.map(fn {status, items} -> {status, length(items)} end)
      |> Enum.into(%{})

    items_with_changes =
      Enum.filter(session.items, & &1.has_changes)

    %{
      session: session,
      statistics: get_session_statistics(session),
      items_by_status: items_by_status,
      items_with_changes: items_with_changes,
      librarians: session.librarian_assignments
    }
  end

  @doc """
  Approve a stock opname session and apply all changes to main tables.
  """
  def approve_stock_opname_session(session, admin_user, notes \\ nil)

  def approve_stock_opname_session(
        %StockOpnameSession{status: "pending_review"} = session,
        admin_user,
        notes
      ) do
    session = Repo.preload(session, :items, force: true)

    Ecto.Multi.new()
    |> Ecto.Multi.run(:apply_changes, fn repo, _changes ->
      # Apply changes from items with has_changes = true
      items_to_update =
        Enum.filter(session.items, fn oi ->
          oi.has_changes and oi.check_status == "checked"
        end)

      Enum.each(items_to_update, fn opname_item ->
        item = repo.get!(Item, opname_item.item_id)

        item
        |> Item.changeset(%{
          status: opname_item.status_after,
          condition: opname_item.condition_after,
          availability: opname_item.availability_after,
          location: opname_item.location_after,
          item_location_id: opname_item.item_location_id_after,
          updated_by_id: admin_user.id
        })
        |> repo.update!()
      end)

      # Mark missing items appropriately
      missing_items =
        Enum.filter(session.items, fn oi ->
          oi.check_status == "missing"
        end)

      Enum.each(missing_items, fn opname_item ->
        item = repo.get!(Item, opname_item.item_id)

        item
        |> Item.changeset(%{
          availability: "missing",
          updated_by_id: admin_user.id
        })
        |> repo.update!()
      end)

      {:ok, {length(items_to_update), length(missing_items)}}
    end)
    |> Ecto.Multi.update(:update_session, fn _changes ->
      session
      |> Ecto.Changeset.change(%{
        status: "approved",
        approved_at: DateTime.utc_now(),
        reviewed_at: DateTime.utc_now(),
        reviewed_by_id: admin_user.id,
        review_notes: notes
      })
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{update_session: session}} -> {:ok, session}
      {:error, _step, error, _changes} -> {:error, error}
    end
  end

  def approve_stock_opname_session(%StockOpnameSession{}, _admin_user, _notes) do
    {:error, :invalid_status}
  end

  @doc """
  Reject a stock opname session.
  """
  def reject_stock_opname_session(
        %StockOpnameSession{status: "pending_review"} = session,
        admin_user,
        reason
      ) do
    session
    |> Ecto.Changeset.change(%{
      status: "rejected",
      reviewed_at: DateTime.utc_now(),
      reviewed_by_id: admin_user.id,
      rejection_reason: reason
    })
    |> Repo.update()
  end

  def reject_stock_opname_session(%StockOpnameSession{}, _admin_user, _reason) do
    {:error, :invalid_status}
  end

  @doc """
  Request revision on a session (send back to librarians).
  """
  def request_session_revision(
        %StockOpnameSession{status: "pending_review"} = session,
        admin_user,
        notes
      ) do
    session
    |> Ecto.Changeset.change(%{
      status: "in_progress",
      reviewed_by_id: admin_user.id,
      review_notes: notes,
      updated_by_id: admin_user.id
    })
    |> Repo.update()
  end

  def request_session_revision(%StockOpnameSession{}, _admin_user, _notes) do
    {:error, :invalid_status}
  end
end
