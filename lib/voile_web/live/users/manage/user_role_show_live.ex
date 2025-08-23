defmodule VoileWeb.Users.ManageLive.Role.Show do
  use VoileWeb, :live_view_dashboard

  alias Voile.Schema.Accounts
  alias VoileWeb.Helpers.AuthHelper

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    current_user = socket.assigns.current_scope.user
    user_role = Accounts.get_user_role!(id)

    if AuthHelper.can?(current_user, "roles", "read") do
      {:ok, assign(socket, user_role: user_role)}
    else
      {:ok, redirect(socket, to: "/admin/roles")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      Role Details
      <:subtitle>View and manage role information</:subtitle>
    </.header>

    <div>
      <h2>{@user_role.name}</h2>
      
      <p>Description: {@user_role.description}</p>
      
      <h3>Permissions:</h3>
      
      <ul>
        <%= for perm <- @user_role.permissions do %>
          <li>{perm.resource} - {perm.action}</li>
        <% end %>
      </ul>
    </div>
    """
  end

  @impl true
  def handle_params(%{"id" => id}, _uri, socket) do
    user_role = Accounts.get_user_role!(id)
    {:noreply, assign(socket, user_role: user_role)}
  end
end
