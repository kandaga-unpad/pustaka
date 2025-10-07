defmodule VoileWeb.Auth.GLAMAuthorization do
  @moduledoc """
  GLAM-specific authorization helpers for Gallery, Library, Archive, and Museum curators.

  This module extends the base RBAC system to support GLAM-specific role checks
  where curators can only manage collections of their designated GLAM type.

  ## Usage

      # Check if user can manage a collection based on their curator role
      can_manage_glam_collection?(user, collection)

      # Get user's assigned GLAM types
      get_user_glam_types(user)

      # Check if user is a specific type of curator
      is_librarian?(user)
      is_archivist?(user)
      is_gallery_curator?(user)
      is_museum_curator?(user)
  """

  import Ecto.Query
  alias Voile.Repo
  alias Voile.Schema.Accounts.{User, Role, UserRoleAssignment}
  alias Voile.Schema.Catalog.Collection
  alias Voile.Schema.Metadata.ResourceClass
  alias VoileWeb.Auth.Authorization

  # GLAM role name mappings
  @glam_roles %{
    "Library" => "librarian",
    "Archive" => "archivist",
    "Gallery" => "gallery_curator",
    "Museum" => "museum_curator"
  }

  @doc """
  Check if a user can manage a collection based on their GLAM curator role.

  A curator can only manage collections of their designated GLAM type.
  Super admins can manage all collections.

  ## Examples

      iex> can_manage_glam_collection?(librarian_user, library_collection)
      true

      iex> can_manage_glam_collection?(librarian_user, museum_collection)
      false
  """
  def can_manage_glam_collection?(%User{} = user, %Collection{} = collection) do
    cond do
      # Super admin can manage everything
      is_super_admin?(user) ->
        true

      # Check if user has the appropriate GLAM curator role for this collection
      has_glam_curator_role_for_collection?(user, collection) ->
        true

      # Check if user has direct collection permission
      has_direct_collection_permission?(user, collection) ->
        true

      true ->
        false
    end
  end

  def can_manage_glam_collection?(user_id, collection) when is_binary(user_id) do
    case Repo.get(User, user_id) do
      nil -> false
      user -> can_manage_glam_collection?(user, collection)
    end
  end

  @doc """
  Check if a user can create collections of a specific GLAM type.

  ## Examples

      iex> can_create_glam_collection?(librarian, "Library")
      true

      iex> can_create_glam_collection?(librarian, "Museum")
      false
  """
  def can_create_glam_collection?(%User{} = user, glam_type)
      when glam_type in ["Gallery", "Library", "Archive", "Museum"] do
    cond do
      is_super_admin?(user) ->
        true

      has_glam_curator_role?(user, glam_type) ->
        Authorization.can?(user, "collections.create")

      true ->
        false
    end
  end

  @doc """
  Get all GLAM types a user is authorized to manage based on their curator roles.

  Returns a list of GLAM type strings: ["Library", "Archive", etc.]

  ## Examples

      iex> get_user_glam_types(user)
      ["Library", "Archive"]
  """
  def get_user_glam_types(%User{} = user) do
    if is_super_admin?(user) do
      ["Gallery", "Library", "Archive", "Museum"]
    else
      # Get all GLAM types from role assignments
      query =
        from ura in UserRoleAssignment,
          join: r in Role,
          on: ura.role_id == r.id,
          where: ura.user_id == ^user.id,
          where: r.name in ["librarian", "archivist", "gallery_curator", "museum_curator"],
          where: is_nil(ura.expires_at) or ura.expires_at > ^DateTime.utc_now(),
          select: {r.name, ura.glam_type}

      role_assignments = Repo.all(query)

      # Map role names and glam_type to GLAM types
      Enum.flat_map(role_assignments, fn {role_name, glam_type} ->
        cond do
          # If glam_type is set, use it directly
          glam_type in ["Gallery", "Library", "Archive", "Museum"] ->
            [glam_type]

          # Otherwise infer from role name
          role_name == "librarian" ->
            ["Library"]

          role_name == "archivist" ->
            ["Archive"]

          role_name == "gallery_curator" ->
            ["Gallery"]

          role_name == "museum_curator" ->
            ["Museum"]

          true ->
            []
        end
      end)
      |> Enum.uniq()
    end
  end

  @doc """
  Check if user is a librarian (can manage Library collections).
  """
  def is_librarian?(%User{} = user) do
    has_role?(user, "librarian")
  end

  @doc """
  Check if user is an archivist (can manage Archive collections).
  """
  def is_archivist?(%User{} = user) do
    has_role?(user, "archivist")
  end

  @doc """
  Check if user is a gallery curator (can manage Gallery collections).
  """
  def is_gallery_curator?(%User{} = user) do
    has_role?(user, "gallery_curator")
  end

  @doc """
  Check if user is a museum curator (can manage Museum collections).
  """
  def is_museum_curator?(%User{} = user) do
    has_role?(user, "museum_curator")
  end

  @doc """
  Check if user is a super admin.
  """
  def is_super_admin?(%User{} = user) do
    has_role?(user, "super_admin") || has_role?(user, "admin")
  end

  @doc """
  Filter collections query to only include collections the user can manage based on GLAM type.

  ## Examples

      Collection
      |> GLAMAuthorization.scope_collections_by_glam_role(user)
      |> Repo.all()
  """
  def scope_collections_by_glam_role(query, %User{} = user) do
    if is_super_admin?(user) do
      query
    else
      glam_types = get_user_glam_types(user)

      if glam_types == [] do
        # User has no GLAM curator roles, show nothing
        from c in query, where: false
      else
        from c in query,
          join: rc in ResourceClass,
          on: c.type_id == rc.id,
          where: rc.glam_type in ^glam_types
      end
    end
  end

  # Private helper functions

  defp has_glam_curator_role_for_collection?(%User{} = user, %Collection{} = collection) do
    collection = Repo.preload(collection, :resource_class)

    if collection.resource_class && collection.resource_class.glam_type do
      has_glam_curator_role?(user, collection.resource_class.glam_type)
    else
      false
    end
  end

  defp has_glam_curator_role?(%User{} = user, glam_type) do
    required_role = @glam_roles[glam_type]

    if required_role do
      has_role?(user, required_role)
    else
      false
    end
  end

  defp has_role?(%User{} = user, role_name) do
    query =
      from ura in UserRoleAssignment,
        join: r in Role,
        on: ura.role_id == r.id,
        where: ura.user_id == ^user.id,
        where: r.name == ^role_name,
        where: is_nil(ura.expires_at) or ura.expires_at > ^DateTime.utc_now()

    Repo.exists?(query)
  end

  defp has_direct_collection_permission?(%User{} = user, %Collection{} = collection) do
    # Check if user has owner or editor permission on this specific collection
    query =
      from cp in Voile.Schema.Accounts.CollectionPermission,
        where: cp.collection_id == ^collection.id,
        where: cp.user_id == ^user.id,
        where: cp.permission_level in ["owner", "editor"]

    Repo.exists?(query)
  end
end
