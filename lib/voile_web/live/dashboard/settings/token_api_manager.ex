defmodule VoileWeb.Dashboard.Settings.ApiManager do
  use VoileWeb, :live_view_dashboard

  alias Voile.Schema.System
  alias VoileWeb.Auth.Authorization

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-6">
      <.link
        navigate={~p"/manage/settings"}
        class="text-sm font-semibold leading-6 text-zinc-900 hover:text-zinc-700"
      >
        ← Back to Settings
      </.link>

      <div class="flex justify-between items-center mb-6 mt-4">
        <div>
          <h1 class="text-2xl font-bold">API Token Manager</h1>
          <p class="text-gray-600 mt-1">
            <%= if @is_admin do %>
              Manage all API tokens across the system
            <% else %>
              Manage your API tokens
            <% end %>
          </p>
        </div>
        <div class="flex gap-2">
          <%= if @is_admin do %>
            <.button phx-click="create_master_token" class="btn btn-cancel">
              Create Master Token
            </.button>
          <% end %>
          <.button phx-click="create_token">
            Create Token
          </.button>
        </div>
      </div>
      
    <!-- Token List -->
      <div class="bg-white shadow rounded-lg overflow-hidden">
        <div class="px-4 py-3 border-b border-gray-200">
          <h3 class="text-lg font-medium">API Tokens</h3>
        </div>

        <div class="overflow-x-auto">
          <table class="min-w-full divide-y divide-gray-200">
            <thead class="bg-gray-50">
              <tr>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Name
                </th>
                <%= if @is_admin do %>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    User
                  </th>
                <% end %>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Scopes
                </th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Status
                </th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Created
                </th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Expires
                </th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Last Used
                </th>
                <th class="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Actions
                </th>
              </tr>
            </thead>
            <tbody class="bg-white divide-y divide-gray-200">
              <%= for token <- @api_tokens do %>
                <tr>
                  <td class="px-6 py-4 whitespace-nowrap">
                    <div class="text-sm font-medium text-gray-900">
                      {token.name || "Unnamed Token"}
                    </div>
                    <div class="text-sm text-gray-500">
                      {token.description || "No description"}
                    </div>
                  </td>
                  <%= if @is_admin do %>
                    <td class="px-6 py-4 whitespace-nowrap">
                      <div class="text-sm text-gray-900">
                        <%= if token.user do %>
                          {token.user.email}
                        <% else %>
                          Unknown User
                        <% end %>
                      </div>
                    </td>
                  <% end %>
                  <td class="px-6 py-4 whitespace-nowrap">
                    <div class="flex flex-wrap gap-1">
                      <%= for scope <- token.scopes do %>
                        <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-blue-100 text-blue-800">
                          {scope}
                        </span>
                      <% end %>
                    </div>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap">
                    <%= if token.revoked_at do %>
                      <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-red-100 text-red-800">
                        Revoked
                      </span>
                    <% else %>
                      <%= if token.expires_at do %>
                        <%= if DateTime.compare(token.expires_at, DateTime.utc_now()) == :gt do %>
                          <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800">
                            Active
                          </span>
                        <% else %>
                          <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-yellow-100 text-yellow-800">
                            Expired
                          </span>
                        <% end %>
                      <% else %>
                        <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800">
                          Active (No Expiry)
                        </span>
                      <% end %>
                    <% end %>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                    {Calendar.strftime(token.inserted_at, "%Y-%m-%d %H:%M")}
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                    <%= if token.expires_at do %>
                      {Calendar.strftime(token.expires_at, "%Y-%m-%d %H:%M")}
                    <% else %>
                      Never
                    <% end %>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                    <%= if token.last_used_at do %>
                      {Calendar.strftime(token.last_used_at, "%Y-%m-%d %H:%M")}
                    <% else %>
                      Never
                    <% end %>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap text-right text-sm font-medium">
                    <div class="flex justify-end gap-2">
                      <.button
                        phx-click="edit_token"
                        phx-value-token-id={token.id}
                        class="text-blue-600 hover:text-blue-900 text-sm"
                      >
                        Edit
                      </.button>
                      <.button
                        phx-click="confirm_rotate_token"
                        phx-value-token-id={token.id}
                        class="text-orange-600 hover:text-orange-900 text-sm"
                      >
                        Rotate
                      </.button>
                      <%= unless token.revoked_at do %>
                        <.button
                          phx-click="revoke_token"
                          phx-value-token-id={token.id}
                          class="text-red-600 hover:text-red-900 text-sm"
                          data-confirm="Are you sure you want to revoke this token?"
                        >
                          Revoke
                        </.button>
                      <% end %>
                      <.button
                        phx-click="delete_token"
                        phx-value-token-id={token.id}
                        class="text-red-600 hover:text-red-900 text-sm"
                        data-confirm="Are you sure you want to permanently delete this token?"
                      >
                        Delete
                      </.button>
                    </div>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>

        <%= if Enum.empty?(@api_tokens) do %>
          <div class="text-center py-12">
            <p class="text-gray-500">No API tokens found.</p>
            <p class="text-sm text-gray-400 mt-1">
              <%= if @is_admin do %>
                Create your first token to get started.
              <% else %>
                Create your first token to get started with the API.
              <% end %>
            </p>
          </div>
        <% end %>
      </div>
      
    <!-- Create/Edit Token Modal -->
      <.modal :if={@show_modal} id="token-modal" show on_cancel={JS.push("close_modal")}>
        <.live_component
          module={VoileWeb.Dashboard.Settings.TokenFormComponent}
          id="token-form"
          current_user={@current_user}
          is_admin={@is_admin}
          token={@selected_token}
          action={@modal_action}
        />
      </.modal>
      
    <!-- Rotate Confirmation Modal -->
      <.modal
        :if={@show_rotate_confirm}
        id="rotate-confirm-modal"
        show
        on_cancel={JS.push("cancel_rotate")}
      >
        <div class="p-6">
          <h3 class="text-lg font-medium text-gray-900 mb-4">Confirm Token Rotation</h3>
          <p class="text-sm text-gray-500 mb-4">
            Are you sure you want to rotate this API token? The current token will be invalidated and a new one will be generated.
            <strong class="text-red-600">
              Make sure to update any applications using this token.
            </strong>
          </p>
          <div class="flex justify-end gap-3">
            <.button phx-click="cancel_rotate">
              Cancel
            </.button>
            <.button
              phx-click="proceed_rotate"
              phx-value-token-id={@token_to_rotate}
              class="bg-orange-600 hover:bg-orange-700"
            >
              Rotate Token
            </.button>
          </div>
        </div>
      </.modal>
      
    <!-- Token Details Modal -->
      <.modal
        :if={@show_token_details}
        id="token-details-modal"
        show
        on_cancel={JS.push("close_token_details")}
      >
        <div class="p-6">
          <h3 class="text-lg font-medium text-gray-900 mb-4">API Token Created</h3>
          <div class="mb-4">
            <p class="text-sm text-gray-600 mb-2">
              Your new API token has been created successfully. Copy the token below and save it securely:
            </p>
            <div class="bg-gray-50 border rounded-lg p-4">
              <div class="flex items-center justify-between">
                <code class="text-sm font-mono text-gray-800 break-all" id="new-token-value">
                  {@new_token_value}
                </code>
                <button
                  type="button"
                  class="ml-2 p-2 text-gray-400 hover:text-gray-600"
                  onclick="navigator.clipboard.writeText(document.getElementById('new-token-value').textContent).then(() => alert('Token copied to clipboard!'))"
                  title="Copy to clipboard"
                >
                  <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z"
                    >
                    </path>
                  </svg>
                </button>
              </div>
            </div>
            <p class="text-xs text-red-600 mt-2">
              <strong>Warning:</strong>
              This token will only be shown once. Make sure to save it securely!
            </p>
          </div>
          <div class="flex justify-end">
            <.button phx-click="close_token_details">
              Close
            </.button>
          </div>
        </div>
      </.modal>
    </div>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_scope.user
    is_admin = Authorization.is_super_admin?(current_user)

    api_tokens =
      if is_admin do
        System.list_all_api_tokens()
      else
        System.list_user_api_tokens(current_user)
      end

    {:ok,
     socket
     |> assign(:current_user, current_user)
     |> assign(:is_admin, is_admin)
     |> assign(:api_tokens, api_tokens)
     |> assign(:show_modal, false)
     |> assign(:selected_token, nil)
     |> assign(:modal_action, nil)
     |> assign(:show_rotate_confirm, false)
     |> assign(:token_to_rotate, nil)
     |> assign(:show_token_details, false)
     |> assign(:new_token_value, nil)}
  end

  @impl true
  def handle_event("create_token", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_modal, true)
     |> assign(:selected_token, nil)
     |> assign(:modal_action, :create)}
  end

  @impl true
  def handle_event("create_master_token", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_modal, true)
     |> assign(:selected_token, nil)
     |> assign(:modal_action, :create_master)}
  end

  @impl true
  def handle_event("edit_token", %{"token-id" => token_id}, socket) do
    token = System.get_api_token(token_id)

    {:noreply,
     socket
     |> assign(:show_modal, true)
     |> assign(:selected_token, token)
     |> assign(:modal_action, :edit)}
  end

  @impl true
  def handle_event("confirm_rotate_token", %{"token-id" => token_id}, socket) do
    {:noreply,
     socket
     |> assign(:show_rotate_confirm, true)
     |> assign(:token_to_rotate, token_id)}
  end

  @impl true
  def handle_event("proceed_rotate", %{"token-id" => token_id}, socket) do
    case System.rotate_api_token(System.get_api_token(token_id)) do
      {:ok, {_new_token, plain_token}} ->
        {:noreply,
         socket
         |> assign(:show_rotate_confirm, false)
         |> assign(:token_to_rotate, nil)
         |> assign(:show_token_details, true)
         |> assign(:new_token_value, plain_token)
         |> assign(:api_tokens, reload_tokens(socket))}

      {:error, _changeset} ->
        {:noreply,
         socket
         |> assign(:show_rotate_confirm, false)
         |> assign(:token_to_rotate, nil)
         |> put_flash(:error, "Failed to rotate token")}
    end
  end

  @impl true
  def handle_event("cancel_rotate", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_rotate_confirm, false)
     |> assign(:token_to_rotate, nil)}
  end

  @impl true
  def handle_event("close_token_details", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_token_details, false)
     |> assign(:new_token_value, nil)}
  end

  @impl true
  def handle_event("revoke_token", %{"token-id" => token_id}, socket) do
    case System.revoke_api_token(System.get_api_token(token_id)) do
      {:ok, _token} ->
        {:noreply,
         socket
         |> put_flash(:info, "Token revoked successfully")
         |> assign(:api_tokens, reload_tokens(socket))}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to revoke token")}
    end
  end

  @impl true
  def handle_event("delete_token", %{"token-id" => token_id}, socket) do
    case System.delete_api_token(System.get_api_token(token_id)) do
      {:ok, _token} ->
        {:noreply,
         socket
         |> put_flash(:info, "Token deleted successfully")
         |> assign(:api_tokens, reload_tokens(socket))}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to delete token")}
    end
  end

  @impl true
  def handle_event("close_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_modal, false)
     |> assign(:selected_token, nil)
     |> assign(:modal_action, nil)
     |> assign(:show_rotate_confirm, false)
     |> assign(:token_to_rotate, nil)
     |> assign(:show_token_details, false)
     |> assign(:new_token_value, nil)}
  end

  @impl true
  def handle_info({:token_created, _created_token}, socket) do
    {:noreply,
     socket
     |> assign(:show_modal, false)
     |> assign(:selected_token, nil)
     |> assign(:modal_action, nil)
     |> assign(:api_tokens, reload_tokens(socket))}
  end

  @impl true
  def handle_info({:token_created_with_value, _created_token, plain_token}, socket) do
    {:noreply,
     socket
     |> assign(:show_modal, false)
     |> assign(:selected_token, nil)
     |> assign(:modal_action, nil)
     |> assign(:show_token_details, true)
     |> assign(:new_token_value, plain_token)
     |> assign(:api_tokens, reload_tokens(socket))}
  end

  @impl true
  def handle_info({:token_updated, _updated_token}, socket) do
    {:noreply,
     socket
     |> assign(:show_modal, false)
     |> assign(:selected_token, nil)
     |> assign(:modal_action, nil)
     |> assign(:api_tokens, reload_tokens(socket))}
  end

  @impl true
  def handle_info(_msg, socket) do
    {:noreply, socket}
  end

  defp reload_tokens(socket) do
    if socket.assigns.is_admin do
      System.list_all_api_tokens()
    else
      System.list_user_api_tokens(socket.assigns.current_user)
    end
  end
end
