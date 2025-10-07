defmodule Voile.GLAM.CollectionHelper do
  @moduledoc """
  Helper functions for working with GLAM collections and curator permissions.

  This module provides convenient functions for common GLAM collection operations
  with built-in permission checking.
  """

  import Ecto.Query
  alias Voile.Repo
  alias Voile.Schema.Catalog.Collection
  alias Voile.Schema.Metadata.ResourceClass
  alias Voile.Schema.Accounts.User
  alias VoileWeb.Auth.GLAMAuthorization

  @doc """
  List all collections accessible to a user based on their GLAM curator role.

  Super admins see all collections.
  Curators only see collections of their GLAM type.

  ## Options

  * `:preload` - List of associations to preload (default: [:resource_class])
  * `:order_by` - Field to order by (default: [desc: :inserted_at])
  * `:status` - Filter by status (e.g., "published", "draft")
  * `:glam_type` - Filter by specific GLAM type

  ## Examples

      # Get all accessible collections
      list_accessible_collections(user)

      # Get published Library collections only
      list_accessible_collections(user, status: "published", glam_type: "Library")
  """
  def list_accessible_collections(%User{} = user, opts \\ []) do
    preload = Keyword.get(opts, :preload, [:resource_class])
    order_by = Keyword.get(opts, :order_by, desc: :inserted_at)
    status = Keyword.get(opts, :status)
    glam_type = Keyword.get(opts, :glam_type)

    query = Collection

    # Apply GLAM role scoping
    query = GLAMAuthorization.scope_collections_by_glam_role(query, user)

    # Apply status filter
    query =
      if status do
        from c in query, where: c.status == ^status
      else
        query
      end

    # Apply additional GLAM type filter (for users with multiple GLAM types)
    query =
      if glam_type do
        from c in query,
          join: rc in ResourceClass,
          on: c.type_id == rc.id,
          where: rc.glam_type == ^glam_type
      else
        query
      end

    # Apply ordering and preload
    query
    |> order_by(^order_by)
    |> preload(^preload)
    |> Repo.all()
  end

  @doc """
  Get a single collection with permission check.

  Returns `{:ok, collection}` if user can manage the collection.
  Returns `{:error, :not_found}` if collection doesn't exist.
  Returns `{:error, :unauthorized}` if user can't manage the collection.

  ## Examples

      case get_collection_with_permission(collection_id, user) do
        {:ok, collection} ->
          # User can manage this collection

        {:error, :unauthorized} ->
          # Show error message

        {:error, :not_found} ->
          # Collection doesn't exist
      end
  """
  def get_collection_with_permission(collection_id, %User{} = user) do
    case Repo.get(Collection, collection_id) do
      nil ->
        {:error, :not_found}

      collection ->
        collection = Repo.preload(collection, :resource_class)

        if GLAMAuthorization.can_manage_glam_collection?(user, collection) do
          {:ok, collection}
        else
          {:error, :unauthorized}
        end
    end
  end

  @doc """
  Check if user can create a collection with the given resource class.

  Returns `{:ok, resource_class}` if user can create collections of this GLAM type.
  Returns `{:error, :unauthorized}` if user can't create this GLAM type.
  Returns `{:error, :not_found}` if resource class doesn't exist.

  ## Examples

      case can_create_with_resource_class?(resource_class_id, user) do
        {:ok, resource_class} ->
          # Proceed with creation

        {:error, :unauthorized} ->
          # Show error
      end
  """
  def can_create_with_resource_class?(resource_class_id, %User{} = user) do
    case Repo.get(ResourceClass, resource_class_id) do
      nil ->
        {:error, :not_found}

      resource_class ->
        if GLAMAuthorization.can_create_glam_collection?(user, resource_class.glam_type) do
          {:ok, resource_class}
        else
          {:error, :unauthorized}
        end
    end
  end

  @doc """
  Get available resource classes for a user to create collections.

  Returns only resource classes of GLAM types the user can manage.
  Super admins get all resource classes.

  ## Examples

      # Get resource classes user can use
      available_resource_classes(user)
      # Librarian returns: [%ResourceClass{glam_type: "Library"}, ...]
  """
  def available_resource_classes(%User{} = user) do
    glam_types = GLAMAuthorization.get_user_glam_types(user)

    if glam_types == [] do
      []
    else
      from(rc in ResourceClass,
        where: rc.glam_type in ^glam_types,
        order_by: [asc: rc.glam_type, asc: rc.label]
      )
      |> Repo.all()
    end
  end

  @doc """
  Get collection count grouped by GLAM type for a user.

  Returns a map like: %{"Library" => 10, "Archive" => 5}

  ## Examples

      count_by_glam_type(user)
      # => %{"Library" => 10, "Archive" => 5}
  """
  def count_by_glam_type(%User{} = user) do
    query =
      from c in Collection,
        join: rc in ResourceClass,
        on: c.type_id == rc.id,
        select: {rc.glam_type, count(c.id)},
        group_by: rc.glam_type

    query = GLAMAuthorization.scope_collections_by_glam_role(query, user)

    query
    |> Repo.all()
    |> Map.new()
  end

  @doc """
  Get collection statistics for a user's accessible collections.

  Returns a map with counts by status, GLAM type, etc.

  ## Examples

      get_collection_stats(user)
      # => %{
      #   total: 50,
      #   by_status: %{"published" => 30, "draft" => 20},
      #   by_glam_type: %{"Library" => 40, "Archive" => 10}
      # }
  """
  def get_collection_stats(%User{} = user) do
    base_query = GLAMAuthorization.scope_collections_by_glam_role(Collection, user)

    total = Repo.aggregate(base_query, :count, :id)

    by_status =
      from(c in base_query,
        select: {c.status, count(c.id)},
        group_by: c.status
      )
      |> Repo.all()
      |> Map.new()

    by_glam_type = count_by_glam_type(user)

    %{
      total: total,
      by_status: by_status,
      by_glam_type: by_glam_type
    }
  end

  @doc """
  Validate collection creation parameters against user's permissions.

  Returns `:ok` if user can create a collection with the given params.
  Returns `{:error, reason}` otherwise.

  ## Examples

      case validate_collection_creation(params, user) do
        :ok ->
          create_collection(params)

        {:error, reason} ->
          show_error(reason)
      end
  """
  def validate_collection_creation(params, %User{} = user) do
    with {:ok, type_id} <- get_type_id(params),
         {:ok, _resource_class} <- can_create_with_resource_class?(type_id, user) do
      :ok
    else
      {:error, :no_type_id} ->
        {:error, "Resource class must be specified"}

      {:error, :not_found} ->
        {:error, "Resource class not found"}

      {:error, :unauthorized} ->
        {:error, "You don't have permission to create this type of collection"}
    end
  end

  # Private helpers

  defp get_type_id(%{"type_id" => type_id}) when not is_nil(type_id), do: {:ok, type_id}
  defp get_type_id(%{type_id: type_id}) when not is_nil(type_id), do: {:ok, type_id}
  defp get_type_id(_), do: {:error, :no_type_id}
end
