defmodule VoileWeb.Auth.StockOpnameAuthorization do
  @moduledoc """
  Authorization helpers specific to Stock Opname functionality.
  """

  import Ecto.Query
  alias Voile.Repo
  alias Voile.Schema.Accounts.User
  alias Voile.Schema.Catalog.{StockOpnameSession, LibrarianAssignment}
  alias VoileWeb.Auth.Authorization

  @doc """
  Check if user can create stock opname sessions (Super Admin only).
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

  @doc """
  Check if user can start a stock opname session (Super Admin only).
  """
  def can_start_session?(%User{} = user, %StockOpnameSession{}) do
    Authorization.is_super_admin?(user)
  end

  def can_start_session?(%Phoenix.LiveView.Socket{} = socket, session) do
    case socket.assigns[:current_scope] do
      %{user: user} when not is_nil(user) -> can_start_session?(user, session)
      _ -> false
    end
  end

  def can_start_session?(_, _), do: false

  @doc """
  Check if user can complete a stock opname session (Super Admin only).
  """
  def can_complete_session?(%User{} = user, %StockOpnameSession{}) do
    Authorization.is_super_admin?(user)
  end

  def can_complete_session?(%Phoenix.LiveView.Socket{} = socket, session) do
    case socket.assigns[:current_scope] do
      %{user: user} when not is_nil(user) -> can_complete_session?(user, session)
      _ -> false
    end
  end

  def can_complete_session?(_, _), do: false

  @doc """
  Check if user can approve/reject stock opname sessions (Super Admin only).
  """
  def can_approve_session?(%User{} = user, %StockOpnameSession{}) do
    Authorization.is_super_admin?(user)
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
  def can_scan_items?(%User{} = user, %StockOpnameSession{} = session) do
    # Super admins can scan
    if Authorization.is_super_admin?(user) do
      true
    else
      # Check if user is assigned to this session
      is_assigned_librarian?(user.id, session.id)
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
  def can_complete_work?(%User{} = user, %StockOpnameSession{} = session) do
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
  Check if user can view a stock opname session (assigned librarian or admin).
  """
  def can_view_session?(%User{} = user, %StockOpnameSession{} = session) do
    Authorization.is_super_admin?(user) or is_assigned_librarian?(user.id, session.id)
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
  def authorize_scanning!(%User{} = user, %StockOpnameSession{} = session) do
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
  def authorize_approval!(%User{} = user, %StockOpnameSession{} = session) do
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
