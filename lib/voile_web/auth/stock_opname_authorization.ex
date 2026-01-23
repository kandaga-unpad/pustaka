defmodule VoileWeb.Auth.StockOpnameAuthorization do
  @moduledoc """
  Authorization helpers specific to Stock Opname functionality.
  """

  import Ecto.Query
  alias Voile.Repo
  alias Voile.Schema.Accounts.User
  alias Voile.Schema.StockOpname.{Session, LibrarianAssignment}
  alias VoileWeb.Auth.Authorization

  @doc """
  Check if user can create stock opname sessions.
  Super admins can create anywhere, regular users can only create for their own node.
  """
  def can_create_session?(%User{} = user) do
    Authorization.is_super_admin?(user)
  end

  def can_create_session?(%Phoenix.LiveView.Socket{} = socket) do
    case socket.assigns[:current_scope] do
      %{user: user} when not is_nil(user) -> can_create_session?(user)
      _ -> false
    end
  end

  def can_create_session?(_), do: false

  def can_create_session?(%User{} = user, node_ids) when is_list(node_ids) do
    if Authorization.is_super_admin?(user) do
      true
    else
      # User can create if they belong to at least one of the selected nodes
      user.node_id && user.node_id in node_ids
    end
  end

  def can_create_session?(%Phoenix.LiveView.Socket{} = socket, node_ids) do
    case socket.assigns[:current_scope] do
      %{user: user} when not is_nil(user) ->
        if node_ids, do: can_create_session?(user, node_ids), else: can_create_session?(user)

      _ ->
        false
    end
  end

  def can_create_session?(_, _), do: false

  @doc """
  Check if user can start a stock opname session.
  Super admins can start anywhere, users can start sessions for their own node.
  """
  def can_start_session?(%User{} = user, %Session{} = session) do
    cond do
      Authorization.is_super_admin?(user) -> true
      user.node_id && user.node_id in session.node_ids -> true
      true -> false
    end
  end

  def can_start_session?(%Phoenix.LiveView.Socket{} = socket, session) do
    case socket.assigns[:current_scope] do
      %{user: user} when not is_nil(user) -> can_start_session?(user, session)
      _ -> false
    end
  end

  def can_start_session?(_, _), do: false

  @doc """
  Check if user can complete a stock opname session.
  Super admins can complete anywhere, users can complete sessions for their own node.
  """
  def can_complete_session?(%User{} = user, %Session{} = session) do
    cond do
      Authorization.is_super_admin?(user) -> true
      user.node_id && user.node_id in session.node_ids -> true
      true -> false
    end
  end

  def can_complete_session?(%Phoenix.LiveView.Socket{} = socket, session) do
    case socket.assigns[:current_scope] do
      %{user: user} when not is_nil(user) -> can_complete_session?(user, session)
      _ -> false
    end
  end

  def can_complete_session?(_, _), do: false

  @doc """
  Check if user can delete a stock opname session.
  Super admins can delete anywhere, users can delete sessions for their own node.
  Only approved or cancelled sessions can be deleted.
  """
  def can_delete_session?(%User{} = user, %Session{status: status} = session)
      when status in ["approved", "cancelled"] do
    cond do
      Authorization.is_super_admin?(user) -> true
      user.node_id && user.node_id in session.node_ids -> true
      true -> false
    end
  end

  def can_delete_session?(%Phoenix.LiveView.Socket{} = socket, session) do
    case socket.assigns[:current_scope] do
      %{user: user} when not is_nil(user) -> can_delete_session?(user, session)
      _ -> false
    end
  end

  def can_delete_session?(_, _), do: false

  @doc """
  Check if user can approve/reject stock opname sessions.
  Super admins can approve anywhere, users can approve sessions for their own node.
  """
  def can_approve_session?(%User{} = user, %Session{} = session) do
    cond do
      Authorization.is_super_admin?(user) -> true
      user.node_id && user.node_id in session.node_ids -> true
      true -> false
    end
  end

  def can_approve_session?(%Phoenix.LiveView.Socket{} = socket, session) do
    case socket.assigns[:current_scope] do
      %{user: user} when not is_nil(user) -> can_approve_session?(user, session)
      _ -> false
    end
  end

  def can_approve_session?(_, _), do: false

  @doc """
  Check if user can scan items in a session (assigned librarian only).
  """
  def can_scan_items?(%User{} = user, %Session{} = session) do
    # Super admins can scan
    if Authorization.is_super_admin?(user) do
      true
    else
      # Check if user is assigned to this session AND belongs to the session's node
      is_assigned_librarian?(user.id, session.id) and user.node_id in session.node_ids
    end
  end

  def can_scan_items?(%Phoenix.LiveView.Socket{} = socket, session) do
    case socket.assigns[:current_scope] do
      %{user: user} when not is_nil(user) -> can_scan_items?(user, session)
      _ -> false
    end
  end

  def can_scan_items?(_, _), do: false

  @doc """
  Check if user can complete their work session (assigned librarian with scanned items).
  """
  def can_complete_work?(%User{} = user, %Session{} = session) do
    if is_assigned_librarian?(user.id, session.id) do
      # Check if librarian has scanned at least one item
      assignment = get_assignment(user.id, session.id)
      assignment && assignment.items_checked > 0
    else
      false
    end
  end

  def can_complete_work?(%Phoenix.LiveView.Socket{} = socket, session) do
    case socket.assigns[:current_scope] do
      %{user: user} when not is_nil(user) -> can_complete_work?(user, session)
      _ -> false
    end
  end

  def can_complete_work?(_, _), do: false

  @doc """
  Check if user can view a stock opname session.
  Super admins can view all, users can view sessions where they are assigned as librarians.
  """
  def can_view_session?(%User{} = user, %Session{} = session) do
    cond do
      Authorization.is_super_admin?(user) -> true
      is_assigned_librarian?(user.id, session.id) -> true
      true -> false
    end
  end

  def can_view_session?(%Phoenix.LiveView.Socket{} = socket, session) do
    case socket.assigns[:current_scope] do
      %{user: user} when not is_nil(user) -> can_view_session?(user, session)
      _ -> false
    end
  end

  def can_view_session?(_, _), do: false

  @doc """
  Check if user is an assigned librarian for a session.
  """
  def is_assigned_librarian?(user_id, session_id) do
    from(la in LibrarianAssignment,
      where: la.session_id == ^session_id and la.user_id == ^user_id
    )
    |> Repo.exists?()
  end

  @doc """
  Get librarian assignment for a session.
  """
  def get_assignment(user_id, session_id) do
    Repo.get_by(LibrarianAssignment, user_id: user_id, session_id: session_id)
  end

  @doc """
  Authorize user for session creation or raise unauthorized error.
  """
  def authorize_session_creation!(%User{} = user) do
    if can_create_session?(user) do
      :ok
    else
      raise VoileWeb.Auth.Authorization.UnauthorizedError,
        message: "Only super administrators can create stock opname sessions"
    end
  end

  def authorize_session_creation!(%Phoenix.LiveView.Socket{} = socket) do
    case socket.assigns[:current_scope] do
      %{user: user} when not is_nil(user) -> authorize_session_creation!(user)
      _ -> raise VoileWeb.Auth.Authorization.UnauthorizedError, message: "Authentication required"
    end
  end

  @doc """
  Authorize user for scanning items or raise unauthorized error.
  """
  def authorize_scanning!(%User{} = user, %Session{} = session) do
    if can_scan_items?(user, session) do
      :ok
    else
      raise VoileWeb.Auth.Authorization.UnauthorizedError,
        message: "You are not assigned to this stock opname session"
    end
  end

  def authorize_scanning!(%Phoenix.LiveView.Socket{} = socket, session) do
    case socket.assigns[:current_scope] do
      %{user: user} when not is_nil(user) -> authorize_scanning!(user, session)
      _ -> raise VoileWeb.Auth.Authorization.UnauthorizedError, message: "Authentication required"
    end
  end

  @doc """
  Authorize user for session approval or raise unauthorized error.
  """
  def authorize_approval!(%User{} = user, %Session{} = session) do
    if can_approve_session?(user, session) do
      :ok
    else
      raise VoileWeb.Auth.Authorization.UnauthorizedError,
        message: "Only super administrators can approve stock opname sessions"
    end
  end

  def authorize_approval!(%Phoenix.LiveView.Socket{} = socket, session) do
    case socket.assigns[:current_scope] do
      %{user: user} when not is_nil(user) -> authorize_approval!(user, session)
      _ -> raise VoileWeb.Auth.Authorization.UnauthorizedError, message: "Authentication required"
    end
  end
end
