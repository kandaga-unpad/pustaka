defmodule VoileWeb.Users.ManageLive.Role.Show do
  use VoileWeb, :live_view_dashboard

  alias Voile.Schema.Accounts
  alias VoileWeb.Helpers.AuthHelper
  alias VoileWeb.Users.Manage.UserRoleFormComponent

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    current_user = socket.assigns.current_scope.user
    user_role = Accounts.get_user_role!(id)

    if AuthHelper.can?(current_user, "roles", "read") do
      {:ok, assign(socket, user_role: user_role)}
    else
      {:ok, redirect(socket, to: "/manage/settings")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-4">
      <.header>
        Role Details
        <:subtitle>View and manage role information</:subtitle>
        
        <:actions>
          <.link navigate={~p"/manage/settings/users/roles"} class="mr-2">Back</.link>
          <%= if AuthHelper.can?(@current_scope.user, "roles", "update") do %>
            <.link patch={~p"/manage/settings/users/roles/#{@user_role}/show/edit"}>
              <.button>Edit Role</.button>
            </.link>
          <% end %>
        </:actions>
      </.header>
      
      <section class="mt-6 bg-white dark:bg-gray-700 p-6 rounded-lg shadow-sm">
        <div class="flex items-start justify-between gap-6">
          <div class="flex-1">
            <div class="flex items-center gap-4">
              <span class={"inline-flex items-center px-3 py-1 rounded-full text-sm font-medium " <> VoileWeb.Helpers.AuthHelper.role_badge_class(@user_role.name)}>
                {@user_role.name}
              </span>
              <div class="text-sm">ID: {@user_role.id}</div>
            </div>
            
            <div class="mt-4 text-sm">
              <p class="whitespace-pre-line">
                {@user_role.description || "No description provided."}
              </p>
            </div>
          </div>
          
          <div class="w-48 text-right">
            <div class="text-sm">Users with this role</div>
            
            <div class="text-2xl font-semibold mt-2">
              {length(Accounts.get_users_by_role(@user_role.name))}
            </div>
          </div>
        </div>
        
        <div class="mt-6">
          <h3 class="text-sm font-medium mb-3">Permissions</h3>
          
          <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <%= for {resource, actions} <- (@user_role.permissions || %{}) do %>
              <div class="p-4 border border-gray-100 rounded-lg bg-gray-50 dark:bg-gray-800">
                <div class="flex items-center justify-between mb-2">
                  <div class="text-sm font-semibold capitalize">{resource}</div>
                  
                  <div class="text-xs text-gray-500">{map_size(actions)} actions</div>
                </div>
                
                <div class="flex flex-wrap gap-2">
                  <%= for {action, allowed} <- actions do %>
                    <%= if allowed do %>
                      <span class="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-green-100 text-green-800 capitalize">
                        {action}
                      </span>
                    <% else %>
                      <span class="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-red-100 text-red-500 capitalize">
                        {action}
                      </span>
                    <% end %>
                  <% end %>
                </div>
              </div>
            <% end %>
          </div>
        </div>
      </section>
      <!-- Inline edit modal (keeps show page as background) - open via live_action like index -->
      <.modal
        :if={@live_action in [:edit]}
        id="user_role-edit-modal"
        show
        on_cancel={JS.patch(~p"/manage/settings/users/roles/#{@user_role}")}
      >
        <.live_component
          module={VoileWeb.Users.Manage.UserRoleFormComponent}
          id={@user_role.id}
          title={@page_title || "Edit Role"}
          action={@live_action}
          user_role={@user_role}
          available_resources={@available_resources || []}
          patch={~p"/manage/settings/users/roles/#{@user_role}"}
        />
      </.modal>
    </div>
    """
  end

  @impl true
  def handle_params(%{"id" => id} = _params, _uri, socket) do
    # keep the show page as background; support opening an edit modal locally
    user_role = Accounts.get_user_role!(id)

    case socket.assigns.live_action do
      :edit ->
        current_user = socket.assigns.current_scope.user

        if AuthHelper.can?(current_user, "roles", "update") do
          {:noreply,
           socket
           |> assign(user_role: user_role)
           |> assign(:available_resources, Accounts.get_available_resources())
           |> assign(:page_title, "Edit Role")}
        else
          {:noreply, socket |> put_flash(:error, "You don't have permission to edit roles.")}
        end

      _ ->
        {:noreply, assign(socket, user_role: user_role)}
    end
  end

  @impl true
  def handle_event("open_edit", _params, socket) do
    current_user = socket.assigns.current_scope.user

    if AuthHelper.can?(current_user, "roles", "update") do
      # navigate to the edit live_action on the show route so the modal
      # opens while keeping the show page as the background and the URL
      # reflects the nested edit route.
      {:noreply,
       push_patch(socket,
         to: ~p"/manage/settings/users/roles/#{socket.assigns.user_role}/show/edit"
       )}
    else
      {:noreply, socket |> put_flash(:error, "You don't have permission to edit roles.")}
    end
  end

  @impl true
  def handle_info({UserRoleFormComponent, {:saved, user_role}}, socket) do
    {:noreply,
     socket
     |> assign(:user_role, user_role)
     |> put_flash(:info, "Role updated successfully")}
  end
end
