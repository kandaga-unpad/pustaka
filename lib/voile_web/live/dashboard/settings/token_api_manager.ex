defmodule VoileWeb.Dashboard.Settings.ApiManager do
  use VoileWeb, :live_view_dashboard

  alias Voile.Schema.System
  alias VoileWeb.Auth.Authorization

  @impl true
  def render(assigns) do
    ~H"""
    <section class="flex flex-col md:flex-row gap-4">
      <div class="w-full md:w-auto md:max-w-64">
        <.dashboard_settings_sidebar
          current_user={@current_scope.user}
          current_path={@current_path}
        />
      </div>
      <div class="p-6 w-full">
        <.link
          navigate={~p"/manage/settings"}
          class="text-sm font-semibold leading-6 text-zinc-900 hover:text-zinc-700"
        >
          {gettext("← Back to Settings")}
        </.link>

        <div class="flex flex-col md:flex-wrap justify-between mb-6 mt-4">
          <div>
            <h1 class="text-2xl font-bold">{gettext("API Token Manager")}</h1>
            <p class="text-gray-600 mt-1">
              <%= if @is_admin do %>
                {gettext("Manage all API tokens across the system")}
              <% else %>
                {gettext("Manage your API tokens")}
              <% end %>
            </p>
          </div>
          <div class="flex gap-2">
            <%= if @is_admin do %>
              <.button phx-click="create_master_token" class="btn btn-cancel">
                {gettext("Create Master Token")}
              </.button>
            <% end %>
            <.button phx-click="create_token">
              {gettext("Create Token")}
            </.button>
          </div>
        </div>
        
    <!-- Token List -->
        <div class="bg-white dark:bg-gray-800 shadow rounded-lg overflow-hidden">
          <div class="px-4 py-3 border-b border-gray-200 dark:border-gray-700">
            <h3 class="text-lg font-medium text-gray-900 dark:text-gray-100">
              {gettext("API Tokens")}
            </h3>
          </div>

          <div class="overflow-x-auto">
            <table class="min-w-full divide-y divide-gray-200 dark:divide-gray-700">
              <thead class="bg-gray-50 dark:bg-gray-700">
                <tr>
                  <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                    {gettext("Token")}
                  </th>
                  <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                    {gettext("Status")}
                  </th>
                  <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                    {gettext("Created")}
                  </th>
                  <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                    {gettext("Expires")}
                  </th>
                  <th class="px-4 py-3 text-right text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                    {gettext("Actions")}
                  </th>
                </tr>
              </thead>
              <tbody class="bg-white dark:bg-gray-800 divide-y divide-gray-200 dark:divide-gray-700">
                <%= for token <- @api_tokens do %>
                  <tr
                    class="hover:bg-gray-50 dark:hover:bg-gray-700 cursor-pointer"
                    phx-click="show_token_details"
                    phx-value-token-id={token.id}
                  >
                    <td class="px-4 py-4">
                      <div class="text-sm font-medium text-gray-900 dark:text-gray-100 truncate max-w-xs">
                        {String.slice(token.name || "Unnamed Token", 0, 30)}
                        <%= if String.length(token.name || "") > 30 do %>
                          ...
                        <% end %>
                      </div>
                      <div class="text-sm text-gray-500 dark:text-gray-400 truncate max-w-xs">
                        {String.slice(token.description || "No description", 0, 40)}
                        <%= if String.length(token.description || "") > 40 do %>
                          ...
                        <% end %>
                      </div>
                    </td>
                    <td class="px-4 py-4">
                      <%= if token.revoked_at do %>
                        <span class="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium bg-red-100 dark:bg-red-900 text-red-800 dark:text-red-200">
                          {gettext("Revoked")}
                        </span>
                      <% else %>
                        <%= if token.expires_at do %>
                          <%= if DateTime.compare(token.expires_at, DateTime.utc_now()) == :gt do %>
                            <span class="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium bg-green-100 dark:bg-green-900 text-green-800 dark:text-green-200">
                              {gettext("Active")}
                            </span>
                          <% else %>
                            <span class="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium bg-yellow-100 dark:bg-yellow-900 text-yellow-800 dark:text-yellow-200">
                              {gettext("Expired")}
                            </span>
                          <% end %>
                        <% else %>
                          <span class="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium bg-green-100 dark:bg-green-900 text-green-800 dark:text-green-200">
                            {gettext("Active")}
                          </span>
                        <% end %>
                      <% end %>
                    </td>
                    <td class="px-4 py-4 text-sm text-gray-500 dark:text-gray-400">
                      {Calendar.strftime(token.inserted_at, "%Y-%m-%d")}
                    </td>
                    <td class="px-4 py-4 text-sm text-gray-500 dark:text-gray-400">
                      <%= if token.expires_at do %>
                        {Calendar.strftime(token.expires_at, "%Y-%m-%d")}
                      <% else %>
                        {gettext("Never")}
                      <% end %>
                    </td>
                    <td class="px-4 py-4 text-right">
                      <div class="flex justify-end gap-2" phx-click-stop>
                        <button
                          phx-click="edit_token"
                          phx-value-token-id={token.id}
                          class="inline-flex items-center px-2 py-1 text-xs font-medium text-blue-600 dark:text-blue-400 hover:text-blue-900 dark:hover:text-blue-300 hover:bg-blue-50 dark:hover:bg-blue-900/20 rounded border border-blue-200 dark:border-blue-700"
                          title={gettext("Edit token")}
                        >
                          <svg
                            class="w-3 h-3 mr-1"
                            fill="none"
                            stroke="currentColor"
                            viewBox="0 0 24 24"
                          >
                            <path
                              stroke-linecap="round"
                              stroke-linejoin="round"
                              stroke-width="2"
                              d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"
                            >
                            </path>
                          </svg>
                          {gettext("Edit")}
                        </button>
                        <button
                          phx-click="confirm_rotate_token"
                          phx-value-token-id={token.id}
                          class="inline-flex items-center px-2 py-1 text-xs font-medium text-orange-600 dark:text-orange-400 hover:text-orange-900 dark:hover:text-orange-300 hover:bg-orange-50 dark:hover:bg-orange-900/20 rounded border border-orange-200 dark:border-orange-700"
                          title={gettext("Rotate token")}
                        >
                          <svg
                            class="w-3 h-3 mr-1"
                            fill="none"
                            stroke="currentColor"
                            viewBox="0 0 24 24"
                          >
                            <path
                              stroke-linecap="round"
                              stroke-linejoin="round"
                              stroke-width="2"
                              d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"
                            >
                            </path>
                          </svg>
                          {gettext("Rotate")}
                        </button>
                        <%= unless token.revoked_at do %>
                          <button
                            phx-click="revoke_token"
                            phx-value-token-id={token.id}
                            class="inline-flex items-center px-2 py-1 text-xs font-medium text-yellow-600 dark:text-yellow-400 hover:text-yellow-900 dark:hover:text-yellow-300 hover:bg-yellow-50 dark:hover:bg-yellow-900/20 rounded border border-yellow-200 dark:border-yellow-700"
                            title={gettext("Revoke token")}
                            data-confirm={gettext("Are you sure you want to revoke this token?")}
                          >
                            <svg
                              class="w-3 h-3 mr-1"
                              fill="none"
                              stroke="currentColor"
                              viewBox="0 0 24 24"
                            >
                              <path
                                stroke-linecap="round"
                                stroke-linejoin="round"
                                stroke-width="2"
                                d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.964-.833-2.732 0L3.732 16.5c-.77.833.192 2.5 1.732 2.5z"
                              >
                              </path>
                            </svg>
                            {gettext("Revoke")}
                          </button>
                        <% end %>
                        <button
                          phx-click="delete_token"
                          phx-value-token-id={token.id}
                          class="inline-flex items-center px-2 py-1 text-xs font-medium text-red-600 dark:text-red-400 hover:text-red-900 dark:hover:text-red-300 hover:bg-red-50 dark:hover:bg-red-900/20 rounded border border-red-200 dark:border-red-700"
                          title={gettext("Delete token")}
                          data-confirm={
                            gettext("Are you sure you want to permanently delete this token?")
                          }
                        >
                          <svg
                            class="w-3 h-3 mr-1"
                            fill="none"
                            stroke="currentColor"
                            viewBox="0 0 24 24"
                          >
                            <path
                              stroke-linecap="round"
                              stroke-linejoin="round"
                              stroke-width="2"
                              d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"
                            >
                            </path>
                          </svg>
                          {gettext("Delete")}
                        </button>
                      </div>
                    </td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>

          <%= if Enum.empty?(@api_tokens) do %>
            <div class="text-center py-12">
              <p class="text-gray-500 dark:text-gray-400">{gettext("No API tokens found.")}</p>
              <p class="text-sm text-gray-400 dark:text-gray-500 mt-1">
                <%= if @is_admin do %>
                  {gettext("Create your first token to get started.")}
                <% else %>
                  {gettext("Create your first token to get started with the API.")}
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
            <h3 class="text-lg font-medium text-gray-900 dark:text-gray-100 mb-4">
              {gettext("Confirm Token Rotation")}
            </h3>
            <p class="text-sm text-gray-500 dark:text-gray-400 mb-4">
              {gettext(
                "Are you sure you want to rotate this API token? The current token will be invalidated and a new one will be generated."
              )}
              <strong class="text-red-600 dark:text-red-400">
                {gettext("Make sure to update any applications using this token.")}
              </strong>
            </p>
            <div class="flex justify-end gap-3">
              <.button phx-click="cancel_rotate">
                {gettext("Cancel")}
              </.button>
              <.button
                phx-click="proceed_rotate"
                phx-value-token-id={@token_to_rotate}
                class="cancel-btn"
              >
                {gettext("Rotate Token")}
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
            <h3 class="text-lg font-medium text-gray-900 dark:text-gray-100 mb-4">
              {gettext("API Token Created")}
            </h3>
            <div class="mb-4">
              <p class="text-sm text-gray-600 dark:text-gray-400 mb-2">
                {gettext(
                  "Your new API token has been created successfully. Copy the token below and save it securely:"
                )}
              </p>
              <div class="bg-gray-50 dark:bg-gray-800 border dark:border-gray-600 rounded-lg p-4">
                <div class="flex items-center justify-between">
                  <input
                    type="text"
                    readonly
                    value={@new_token_value}
                    id="new-token-value"
                    class="flex-1 bg-transparent text-sm font-mono text-gray-800 dark:text-gray-200 border-none outline-none"
                  />
                  <button
                    type="button"
                    phx-click={
                      JS.dispatch("voile:copy-to-clipboard",
                        to: "#new-token-value",
                        detail: %{success_message: "Token copied!"}
                      )
                    }
                    class="ml-2 p-2 text-gray-400 hover:text-gray-600 dark:text-gray-500 dark:hover:text-gray-300"
                    title={gettext("Copy to clipboard")}
                  >
                    <.icon name="hero-clipboard-document" class="w-5 h-5" />
                  </button>
                </div>
              </div>
              <p class="text-xs text-red-600 dark:text-red-400 mt-2">
                <strong>{gettext("Warning:")}</strong>
                {gettext("This token will only be shown once. Make sure to save it securely!")}
              </p>
            </div>
            <div class="flex justify-end">
              <.button phx-click="close_token_details">
                {gettext("Close")}
              </.button>
            </div>
          </div>
        </.modal>
        
    <!-- Token Info Modal -->
        <.modal
          :if={@show_token_info}
          id="token-info-modal"
          show
          on_cancel={JS.push("close_token_info")}
        >
          <div class="p-6 max-w-2xl">
            <h3 class="text-lg font-medium text-gray-900 dark:text-gray-100 mb-4">
              {gettext("API Token Details")}
            </h3>

            <%= if @selected_token_for_info do %>
              <div class="space-y-4">
                <div>
                  <label class="block text-sm font-medium text-gray-700 dark:text-gray-300">
                    {gettext("Name")}
                  </label>
                  <p class="mt-1 text-sm text-gray-900 dark:text-gray-100">
                    {@selected_token_for_info.name || gettext("Unnamed Token")}
                  </p>
                </div>

                <div>
                  <label class="block text-sm font-medium text-gray-700 dark:text-gray-300">
                    {gettext("Description")}
                  </label>
                  <p class="mt-1 text-sm text-gray-900 dark:text-gray-100">
                    {@selected_token_for_info.description || gettext("No description")}
                  </p>
                </div>

                <%= if @is_admin do %>
                  <div>
                    <label class="block text-sm font-medium text-gray-700 dark:text-gray-300">
                      {gettext("User")}
                    </label>
                    <p class="mt-1 text-sm text-gray-900 dark:text-gray-100">
                      <%= if @selected_token_for_info.user do %>
                        {@selected_token_for_info.user.email}
                      <% else %>
                        {gettext("Unknown User")}
                      <% end %>
                    </p>
                  </div>
                <% end %>

                <div>
                  <label class="block text-sm font-medium text-gray-700 dark:text-gray-300">
                    {gettext("Scopes")}
                  </label>
                  <div class="mt-1 flex flex-wrap gap-1">
                    <%= for scope <- @selected_token_for_info.scopes do %>
                      <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-blue-100 dark:bg-blue-900 text-blue-800 dark:text-blue-200">
                        {scope}
                      </span>
                    <% end %>
                  </div>
                </div>

                <div>
                  <label class="block text-sm font-medium text-gray-700 dark:text-gray-300">
                    {gettext("Status")}
                  </label>
                  <div class="mt-1">
                    <%= if @selected_token_for_info.revoked_at do %>
                      <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-red-100 dark:bg-red-900 text-red-800 dark:text-red-200">
                        {gettext("Revoked on %{date}",
                          date:
                            Calendar.strftime(
                              @selected_token_for_info.revoked_at,
                              "%Y-%m-%d %H:%M"
                            )
                        )}
                      </span>
                    <% else %>
                      <%= if @selected_token_for_info.expires_at do %>
                        <%= if DateTime.compare(@selected_token_for_info.expires_at, DateTime.utc_now()) == :gt do %>
                          <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 dark:bg-green-900 text-green-800 dark:text-green-200">
                            {gettext("Active")}
                          </span>
                        <% else %>
                          <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-yellow-100 dark:bg-yellow-900 text-yellow-800 dark:text-yellow-200">
                            {gettext("Expired on %{date}",
                              date:
                                Calendar.strftime(
                                  @selected_token_for_info.expires_at,
                                  "%Y-%m-%d %H:%M"
                                )
                            )}
                          </span>
                        <% end %>
                      <% else %>
                        <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 dark:bg-green-900 text-green-800 dark:text-green-200">
                          {gettext("Active (No Expiry)")}
                        </span>
                      <% end %>
                    <% end %>
                  </div>
                </div>

                <div class="grid grid-cols-2 gap-4">
                  <div>
                    <label class="block text-sm font-medium text-gray-700 dark:text-gray-300">
                      {gettext("Created")}
                    </label>
                    <p class="mt-1 text-sm text-gray-900 dark:text-gray-100">
                      {Calendar.strftime(@selected_token_for_info.inserted_at, "%Y-%m-%d %H:%M")}
                    </p>
                  </div>
                  <div>
                    <label class="block text-sm font-medium text-gray-700 dark:text-gray-300">
                      {gettext("Expires")}
                    </label>
                    <p class="mt-1 text-sm text-gray-900 dark:text-gray-100">
                      <%= if @selected_token_for_info.expires_at do %>
                        {Calendar.strftime(@selected_token_for_info.expires_at, "%Y-%m-%d %H:%M")}
                      <% else %>
                        {gettext("Never")}
                      <% end %>
                    </p>
                  </div>
                </div>

                <div>
                  <label class="block text-sm font-medium text-gray-700 dark:text-gray-300">
                    {gettext("Last Used")}
                  </label>
                  <p class="mt-1 text-sm text-gray-900 dark:text-gray-100">
                    <%= if @selected_token_for_info.last_used_at do %>
                      {Calendar.strftime(@selected_token_for_info.last_used_at, "%Y-%m-%d %H:%M")}
                    <% else %>
                      {gettext("Never")}
                    <% end %>
                  </p>
                </div>
              </div>
            <% end %>

            <div class="flex justify-end mt-6">
              <.button phx-click="close_token_info">
                {gettext("Close")}
              </.button>
            </div>
          </div>
        </.modal>
      </div>
    </section>
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
     |> assign(:new_token_value, nil)
     |> assign(:show_token_info, false)
     |> assign(:selected_token_for_info, nil)}
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
         |> put_flash(:error, gettext("Failed to rotate token"))}
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
  def handle_event("show_token_details", %{"token-id" => token_id}, socket) do
    token = System.get_api_token(token_id)

    {:noreply,
     socket
     |> assign(:show_token_info, true)
     |> assign(:selected_token_for_info, token)}
  end

  @impl true
  def handle_event("close_token_info", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_token_info, false)
     |> assign(:selected_token_for_info, nil)}
  end

  @impl true
  def handle_event("revoke_token", %{"token-id" => token_id}, socket) do
    case System.revoke_api_token(System.get_api_token(token_id)) do
      {:ok, _token} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Token revoked successfully"))
         |> assign(:api_tokens, reload_tokens(socket))}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, gettext("Failed to revoke token"))}
    end
  end

  @impl true
  def handle_event("delete_token", %{"token-id" => token_id}, socket) do
    case System.delete_api_token(System.get_api_token(token_id)) do
      {:ok, _token} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Token deleted successfully"))
         |> assign(:api_tokens, reload_tokens(socket))}

      {:error, _changeset} ->
        put_flash(socket, :error, gettext("Failed to delete token"))
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
     |> assign(:new_token_value, nil)
     |> assign(:show_token_info, false)
     |> assign(:selected_token_for_info, nil)}
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
  def handle_info({:token_created_with_value, plain_token}, socket) do
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
