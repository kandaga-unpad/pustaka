defmodule VoileWeb.Auth.Authorization do
  @moduledoc """
  Authorization module for checking user permissions in the Voile application.
  """

  import Ecto.Query
  alias Voile.Repo
  alias Voile.Schema.Accounts.{User, Role, Permission, UserRoleAssignment, UserPermission}

  @doc """
  Check if a user has a specific permission.

  ## Examples

      # Check global permission
      iex> can?(user, "collections.create")
      true

      # Check scoped permission for a collection
      iex> can?(user, "items.update", scope: {:collection, 5})
      true

      # Check scoped permission for an item
      iex> can?(user, "items.delete", scope: {:item, 123})
      false
  """
  def can?(user_or_id, permission_name, opts \\ [])

  def can?(%User{} = user, permission_name, opts) do
    scope = Keyword.get(opts, :scope)

    # Super admins bypass all permission checks
    if is_super_admin?(user) do
      true
    else
      cond do
        # Check explicit user permissions first (including denies)
        has_explicit_permission?(user.id, permission_name, scope) ->
          is_granted = get_explicit_permission_grant(user.id, permission_name, scope)
          is_granted

        # Then check role-based permissions
        has_role_permission?(user.id, permission_name, scope) ->
          true

        # Check collection-level permissions
        scope && has_collection_permission?(user.id, permission_name, scope) ->
          true

        true ->
          false
      end
    end
  end

  def can?(user_id, permission_name, opts) when is_binary(user_id) do
    case Repo.get(User, user_id) do
      nil -> false
      user -> can?(user, permission_name, opts)
    end
  end

  def can?(%Phoenix.LiveView.Socket{assigns: assigns}, permission_name, opts)
      when is_map(assigns) do
    case Map.get(assigns, :current_scope) do
      %{user: user} when not is_nil(user) -> can?(user, permission_name, opts)
      _ -> false
    end
  end

  def can?(%Phoenix.LiveView.Socket{}, _permission_name, _opts) do
    # Socket without assigns map (shouldn't happen in normal flow)
    false
  end

  def can?(%Plug.Conn{} = conn, permission_name, opts) do
    case conn.assigns[:current_scope] do
      %{user: user} when not is_nil(user) -> can?(user, permission_name, opts)
      _ -> false
    end
  end

  @doc """
  Authorize a user for a permission or raise an error.

  ## Examples

      iex> authorize!(user, "collections.create")
      :ok

      iex> authorize!(user, "collections.delete")
      ** (Glam.Authorization.UnauthorizedError) User does not have permission: collections.delete
  """
  def authorize!(user_or_socket_or_conn, permission_name, opts \\ [])

  def authorize!(%User{} = user, permission_name, opts) do
    if can?(user, permission_name, opts) do
      :ok
    else
      error_opts = [permission: permission_name, user_id: user.id]

      error_opts =
        if redirect_to = Keyword.get(opts, :redirect_to) do
          Keyword.put(error_opts, :redirect_to, redirect_to)
        else
          error_opts
        end

      raise __MODULE__.UnauthorizedError, error_opts
    end
  end

  def authorize!(%Phoenix.LiveView.Socket{assigns: assigns}, permission_name, opts)
      when is_map(assigns) do
    case Map.get(assigns, :current_scope) do
      %{user: user} when not is_nil(user) ->
        authorize!(user, permission_name, opts)

      _ ->
        error_opts = [permission: permission_name, user_id: nil]

        error_opts =
          if redirect_to = Keyword.get(opts, :redirect_to) do
            Keyword.put(error_opts, :redirect_to, redirect_to)
          else
            error_opts
          end

        raise __MODULE__.UnauthorizedError, error_opts
    end
  end

  def authorize!(%Phoenix.LiveView.Socket{}, permission_name, opts) do
    error_opts = [permission: permission_name, user_id: nil]

    error_opts =
      if redirect_to = Keyword.get(opts, :redirect_to) do
        Keyword.put(error_opts, :redirect_to, redirect_to)
      else
        error_opts
      end

    raise __MODULE__.UnauthorizedError, error_opts
  end

  def authorize!(%Plug.Conn{} = conn, permission_name, opts) do
    case conn.assigns[:current_scope] do
      %{user: user} when not is_nil(user) ->
        authorize!(user, permission_name, opts)

      _ ->
        error_opts = [permission: permission_name, user_id: nil]

        error_opts =
          if redirect_to = Keyword.get(opts, :redirect_to) do
            Keyword.put(error_opts, :redirect_to, redirect_to)
          else
            error_opts
          end

        raise __MODULE__.UnauthorizedError, error_opts
    end
  end

  @doc """
  Get all permissions for a user (including role and direct permissions).
  """
  def get_user_permissions(user_id, opts \\ []) do
    scope = Keyword.get(opts, :scope)

    role_permissions = get_role_based_permissions(user_id, scope)
    direct_permissions = get_direct_permissions(user_id, scope)

    # Merge and deduplicate
    (role_permissions ++ direct_permissions)
    |> Enum.uniq_by(& &1.name)
  end

  @doc """
  Assign a role to a user.

  ## Options

  * `:scope_type` - "global", "collection", or "item" (default: "global")
  * `:scope_id` - ID of the scoped resource (required for collection/item scope)
  * `:glam_type` - "Gallery", "Library", "Archive", or "Museum" (optional, for GLAM curator roles)
  * `:assigned_by_id` - ID of the user assigning the role
  * `:expires_at` - DateTime when the role assignment expires

  ## Examples

      # Assign librarian role for Library collections only
      assign_role(user_id, librarian_role_id, glam_type: "Library")

      # Assign role to specific collection
      assign_role(user_id, role_id, scope_type: "collection", scope_id: collection_id)
  """
  def assign_role(user_id, role_id, opts \\ []) do
    scope_type = Keyword.get(opts, :scope_type, "global")
    scope_id = Keyword.get(opts, :scope_id)
    glam_type = Keyword.get(opts, :glam_type)
    assigned_by_id = Keyword.get(opts, :assigned_by_id)
    expires_at = Keyword.get(opts, :expires_at)

    attrs = %{
      user_id: user_id,
      role_id: role_id,
      scope_type: scope_type,
      scope_id: scope_id,
      glam_type: glam_type,
      assigned_by_id: assigned_by_id,
      expires_at: expires_at
    }

    %UserRoleAssignment{}
    |> UserRoleAssignment.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Grant a direct permission to a user.
  """
  def grant_permission(user_id, permission_id, opts \\ []) do
    scope_type = Keyword.get(opts, :scope_type, "global")
    scope_id = Keyword.get(opts, :scope_id)
    assigned_by_id = Keyword.get(opts, :assigned_by_id)
    expires_at = Keyword.get(opts, :expires_at)

    attrs = %{
      user_id: user_id,
      permission_id: permission_id,
      scope_type: scope_type,
      scope_id: scope_id,
      granted: true,
      assigned_by_id: assigned_by_id,
      expires_at: expires_at
    }

    %UserPermission{}
    |> UserPermission.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Explicitly deny a permission for a user (overrides role permissions).
  """
  def deny_permission(user_id, permission_id, opts \\ []) do
    scope_type = Keyword.get(opts, :scope_type, "global")
    scope_id = Keyword.get(opts, :scope_id)
    assigned_by_id = Keyword.get(opts, :assigned_by_id)

    attrs = %{
      user_id: user_id,
      permission_id: permission_id,
      scope_type: scope_type,
      scope_id: scope_id,
      granted: false,
      assigned_by_id: assigned_by_id
    }

    %UserPermission{}
    |> UserPermission.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Remove a role assignment from a user.
  """
  def revoke_role(user_id, role_id, opts \\ []) do
    scope_type = Keyword.get(opts, :scope_type, "global")
    scope_id = Keyword.get(opts, :scope_id)

    query =
      from ura in UserRoleAssignment,
        where: ura.user_id == ^user_id,
        where: ura.role_id == ^role_id,
        where: ura.scope_type == ^scope_type

    query =
      if scope_id do
        from ura in query, where: ura.scope_id == ^scope_id
      else
        from ura in query, where: is_nil(ura.scope_id)
      end

    Repo.delete_all(query)
  end

  @doc """
  Check if user is authenticated (from socket or conn assigns).

  ## Examples

      authenticated?(socket)
      authenticated?(conn)
  """
  def authenticated?(socket_or_conn)

  def authenticated?(%Phoenix.LiveView.Socket{assigns: assigns}) when is_map(assigns) do
    case Map.get(assigns, :current_scope) do
      %{user: user} when not is_nil(user) -> true
      _ -> false
    end
  end

  def authenticated?(%Phoenix.LiveView.Socket{}), do: false

  def authenticated?(%Plug.Conn{} = conn) do
    case conn.assigns[:current_scope] do
      %{user: user} when not is_nil(user) -> true
      _ -> false
    end
  end

  @doc """
  Get the current user from socket or conn assigns.

  Returns `nil` if no user is authenticated.

  ## Examples

      user = current_user(socket)
      user = current_user(conn)
  """
  def current_user(socket_or_conn)

  def current_user(%Phoenix.LiveView.Socket{assigns: assigns}) when is_map(assigns) do
    case Map.get(assigns, :current_scope) do
      %{user: user} -> user
      _ -> nil
    end
  end

  def current_user(%Phoenix.LiveView.Socket{}), do: nil

  def current_user(%Plug.Conn{} = conn) do
    case conn.assigns[:current_scope] do
      %{user: user} -> user
      _ -> nil
    end
  end

  @doc """
  Check if a user has the super_admin role.

  Super admins have unrestricted access to all resources across all nodes/units.

  ## Examples

      iex> is_super_admin?(user)
      true

      iex> is_super_admin?(socket)
      false
  """
  def is_super_admin?(user_or_socket_or_conn)

  def is_super_admin?(%User{} = user) do
    user = Repo.preload(user, :roles)

    Enum.any?(user.roles, fn role ->
      role.name == "super_admin"
    end)
  end

  def is_super_admin?(%Phoenix.LiveView.Socket{assigns: assigns}) when is_map(assigns) do
    case Map.get(assigns, :current_scope) do
      %{user: user} when not is_nil(user) -> is_super_admin?(user)
      _ -> false
    end
  end

  def is_super_admin?(%Phoenix.LiveView.Socket{}), do: false

  def is_super_admin?(%Plug.Conn{} = conn) do
    case conn.assigns[:current_scope] do
      %{user: user} when not is_nil(user) -> is_super_admin?(user)
      _ -> false
    end
  end

  def is_super_admin?(nil), do: false

  # Private functions

  defp has_explicit_permission?(user_id, permission_name, scope) do
    {scope_type, scope_id} = parse_scope(scope)

    query =
      from up in UserPermission,
        join: p in Permission,
        on: up.permission_id == p.id,
        where: up.user_id == ^user_id,
        where: p.name == ^permission_name,
        where: up.scope_type == ^scope_type,
        where: is_nil(up.expires_at) or up.expires_at > ^DateTime.utc_now()

    query =
      if scope_id do
        from [up, p] in query, where: up.scope_id == ^scope_id or up.scope_type == "global"
      else
        from [up, p] in query, where: is_nil(up.scope_id) or up.scope_type == "global"
      end

    Repo.exists?(query)
  end

  defp get_explicit_permission_grant(user_id, permission_name, scope) do
    {scope_type, scope_id} = parse_scope(scope)

    query =
      from up in UserPermission,
        join: p in Permission,
        on: up.permission_id == p.id,
        where: up.user_id == ^user_id,
        where: p.name == ^permission_name,
        where: up.scope_type == ^scope_type,
        where: is_nil(up.expires_at) or up.expires_at > ^DateTime.utc_now(),
        select: up.granted,
        order_by: [desc: up.inserted_at],
        limit: 1

    query =
      if scope_id do
        from [up, p] in query, where: up.scope_id == ^scope_id or up.scope_type == "global"
      else
        from [up, p] in query, where: is_nil(up.scope_id) or up.scope_type == "global"
      end

    Repo.one(query) || false
  end

  defp has_role_permission?(user_id, permission_name, scope) do
    {scope_type, scope_id} = parse_scope(scope)

    query =
      from ura in UserRoleAssignment,
        join: r in Role,
        on: ura.role_id == r.id,
        join: rp in "role_permissions",
        on: rp.role_id == r.id,
        join: p in Permission,
        on: rp.permission_id == p.id,
        where: ura.user_id == ^user_id,
        where: p.name == ^permission_name,
        where: is_nil(ura.expires_at) or ura.expires_at > ^DateTime.utc_now()

    # Check scope matching
    query =
      case {scope_type, scope_id} do
        {"global", nil} ->
          from [ura, r, rp, p] in query, where: ura.scope_type == "global"

        {scope_type, scope_id} when not is_nil(scope_id) ->
          from [ura, r, rp, p] in query,
            where:
              ura.scope_type == "global" or
                (ura.scope_type == ^scope_type and ura.scope_id == ^scope_id)

        _ ->
          query
      end

    Repo.exists?(query)
  end

  defp has_collection_permission?(user_id, permission_name, scope) do
    case scope do
      {:collection, collection_id} ->
        check_collection_permission(user_id, permission_name, collection_id)

      {:item, _item_id} ->
        # TODO: Implement item-level permission checking through parent collection
        false

      _ ->
        false
    end
  end

  defp check_collection_permission(user_id, permission_name, collection_id) do
    # Map permission names to collection permission levels
    permission_level = map_permission_to_level(permission_name)

    if permission_level do
      query =
        from cp in Voile.Schema.Accounts.CollectionPermission,
          where: cp.collection_id == ^collection_id,
          where: cp.user_id == ^user_id,
          where: cp.permission_level == ^permission_level

      Repo.exists?(query)
    else
      false
    end
  end

  defp map_permission_to_level(permission_name) do
    case permission_name do
      # Owner level permissions (can delete / full manage)
      name when name in ~w(collections.delete items.delete metadata.manage) -> "owner"
      # Editor level permissions (can create/update content)
      name when name in ~w(collections.update items.update items.create metadata.edit) -> "editor"
      # Viewer level permissions (read/export)
      name when name in ~w(collections.read items.read items.export) -> "viewer"
      _ -> nil
    end
  end

  defp get_role_based_permissions(user_id, scope) do
    {scope_type, scope_id} = parse_scope(scope)

    query =
      from ura in UserRoleAssignment,
        join: r in Role,
        on: ura.role_id == r.id,
        join: rp in "role_permissions",
        on: rp.role_id == r.id,
        join: p in Permission,
        on: rp.permission_id == p.id,
        where: ura.user_id == ^user_id,
        where: is_nil(ura.expires_at) or ura.expires_at > ^DateTime.utc_now(),
        select: p

    query =
      case {scope_type, scope_id} do
        {"global", nil} ->
          from [ura, r, rp, p] in query, where: ura.scope_type == "global"

        {scope_type, scope_id} when not is_nil(scope_id) ->
          from [ura, r, rp, p] in query,
            where:
              ura.scope_type == "global" or
                (ura.scope_type == ^scope_type and ura.scope_id == ^scope_id)

        _ ->
          query
      end

    Repo.all(query)
  end

  defp get_direct_permissions(user_id, scope) do
    {scope_type, scope_id} = parse_scope(scope)

    query =
      from up in UserPermission,
        join: p in Permission,
        on: up.permission_id == p.id,
        where: up.user_id == ^user_id,
        where: up.granted == true,
        where: is_nil(up.expires_at) or up.expires_at > ^DateTime.utc_now(),
        select: p

    query =
      case {scope_type, scope_id} do
        {"global", nil} ->
          from [up, p] in query, where: up.scope_type == "global"

        {scope_type, scope_id} when not is_nil(scope_id) ->
          from [up, p] in query,
            where:
              up.scope_type == "global" or
                (up.scope_type == ^scope_type and up.scope_id == ^scope_id)

        _ ->
          query
      end

    Repo.all(query)
  end

  defp parse_scope(nil), do: {"global", nil}
  defp parse_scope({:collection, id}), do: {"collection", id}
  defp parse_scope({:item, id}), do: {"item", id}
  defp parse_scope({scope_type, id}), do: {to_string(scope_type), id}

  @doc """
  Authorize that at least one permission in the list is granted for the given
  subject (user, conn, or socket) or raise `UnauthorizedError`.

  Example:
      Authorization.authorize_any!(conn, ["metadata.manage", "metadata.edit"])
  """
  def authorize_any!(user_or_conn_or_socket, permission_names) when is_list(permission_names) do
    if authorize_any?(user_or_conn_or_socket, permission_names) do
      :ok
    else
      user_id =
        case user_or_conn_or_socket do
          %User{} = user ->
            user.id

          %Phoenix.LiveView.Socket{assigns: assigns} when is_map(assigns) ->
            assigns[:current_scope] && assigns[:current_scope].user &&
              assigns[:current_scope].user.id

          %Plug.Conn{} = conn ->
            conn.assigns[:current_scope] && conn.assigns[:current_scope].user &&
              conn.assigns[:current_scope].user.id

          id when is_binary(id) ->
            id

          _ ->
            nil
        end

      raise __MODULE__.UnauthorizedError,
        permission: Enum.join(permission_names, ", "),
        user_id: user_id
    end
  end

  @doc """
  Returns `true` if any of the given permission names are granted for the
  provided subject (user, conn, or socket).
  """
  def authorize_any?(user_or_conn_or_socket, permission_names) when is_list(permission_names) do
    Enum.any?(permission_names, fn perm -> can?(user_or_conn_or_socket, perm) end)
  end

  # Exception module
  defmodule UnauthorizedError do
    defexception [:message, :permission, :user_id, :redirect_to]

    def exception(opts) do
      permission = Keyword.get(opts, :permission)
      user_id = Keyword.get(opts, :user_id)
      redirect_to = Keyword.get(opts, :redirect_to)

      message = "User #{user_id} does not have permission: #{permission}"

      %__MODULE__{
        message: message,
        permission: permission,
        user_id: user_id,
        redirect_to: redirect_to
      }
    end
  end

  def verify_api_token(token) do
    {:ok, token}
  end
end
