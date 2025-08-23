defmodule VoileWeb.Users.ManageLive.Show do
  use VoileWeb, :live_view_dashboard

  alias Voile.Schema.Accounts
  alias VoileWeb.Helpers.AuthHelper

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    current_user = socket.assigns.current_scope.user
    user = Accounts.get_user!(id)

    if AuthHelper.can?(current_user, "users", "show") do
      {:ok, assign(socket, user: user)}
    else
      {:ok, redirect(socket, to: "/manage/users")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      User Details
      <:subtitle>View and manage user information</:subtitle>
    </.header>

    <div>
      <h2>{@user.fullname}</h2>
      
      <p>Email: {@user.email}</p>
      
      <p>Username: {@user.username}</p>
    </div>
    """
  end

  @impl true
  def handle_params(%{"id" => id}, _uri, socket) do
    user = Accounts.get_user!(id)
    {:noreply, assign(socket, user: user)}
  end
end
