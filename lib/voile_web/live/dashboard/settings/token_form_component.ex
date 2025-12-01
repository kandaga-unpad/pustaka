defmodule VoileWeb.Dashboard.Settings.TokenFormComponent do
  use VoileWeb, :live_component

  alias Voile.Schema.System
  alias Voile.Schema.System.UserApiToken

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-6">
      <div class="mb-6">
        <h3 class="text-lg font-medium text-gray-900">
          <%= if @action == :create_master do %>
            Create Master Token
          <% else %>
            {if @token, do: "Edit Token", else: "Create Token"}
          <% end %>
        </h3>
        <p class="mt-1 text-sm text-gray-600">
          <%= if @action == :create_master do %>
            Create a non-expiring master token with full admin privileges. Only super admins can create these.
          <% else %>
            {if @token,
              do: "Update token settings",
              else: "Create a new API token for accessing the system"}
          <% end %>
        </p>
      </div>

      <.form for={@form} phx-submit="save" phx-target={@myself} class="space-y-6">
        <div>
          <.input
            field={@form[:name]}
            type="text"
            label="Token Name"
            placeholder="My API Token"
            required
          />
        </div>

        <div>
          <.input
            field={@form[:description]}
            type="textarea"
            label="Description"
            placeholder="Optional description for this token"
            rows="3"
          />
        </div>

        <%= if @is_admin and @action != :create_master do %>
          <div>
            <.label>Scopes</.label>
            <div class="mt-2 space-y-2">
              <%= for scope <- UserApiToken.available_scopes() do %>
                <label class="inline-flex items-center">
                  <input
                    type="checkbox"
                    name="token[scopes][]"
                    value={scope}
                    checked={scope in (@form[:scopes].value || [])}
                    class="rounded border-gray-300 text-blue-600 shadow-sm focus:border-blue-300 focus:ring focus:ring-blue-200 focus:ring-opacity-50"
                  />
                  <span class="ml-2 text-sm text-gray-700">{scope}</span>
                </label>
              <% end %>
            </div>
          </div>
        <% end %>

        <%= if @action != :create_master do %>
          <div>
            <.input
              field={@form[:expires_at]}
              type="datetime-local"
              label="Expiration Date (optional)"
              placeholder="Leave empty for no expiration"
            />
          </div>
        <% end %>

        <%= if @is_admin do %>
          <div>
            <.input
              field={@form[:ip_whitelist]}
              type="text"
              label="IP Whitelist (optional)"
              placeholder="192.168.1.1, 10.0.0.1"
            />
            <p class="text-sm text-gray-500 mt-1">Comma-separated list of allowed IP addresses</p>
          </div>
        <% end %>

        <div class="flex justify-end gap-3">
          <button
            type="button"
            class="px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-md hover:bg-gray-50"
            phx-click="cancel"
            phx-target={@myself}
          >
            Cancel
          </button>
          <button type="submit" class="primary-btn">
            {if @token, do: "Update Token", else: "Create Token"}
          </button>
        </div>
      </.form>
    </div>
    """
  end

  @impl true
  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_form()}
  end

  @impl true
  def handle_event(
        "save",
        %{"user_api_token" => user_api_token_params, "token" => token_params},
        socket
      ) do
    # Merge the form data
    token_params = Map.merge(user_api_token_params, token_params)

    case save_token(socket, socket.assigns.action, token_params) do
      {:ok, token} ->
        handle_token_success(socket, token, nil)

      {:ok, token, plain_token} ->
        handle_token_success(socket, token, plain_token)

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}

      {:error, message} ->
        {:noreply, put_flash(socket, :error, message)}
    end
  end

  @impl true
  def handle_event("save", %{"user_api_token" => user_api_token_params}, socket) do
    # Handle case where only user_api_token params are present (no scopes)
    case save_token(socket, socket.assigns.action, user_api_token_params) do
      {:ok, token} ->
        handle_token_success(socket, token, nil)

      {:ok, token, plain_token} ->
        handle_token_success(socket, token, plain_token)

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}

      {:error, message} ->
        {:noreply, put_flash(socket, :error, message)}
    end
  end

  @impl true
  def handle_event("save", %{"token" => token_params}, socket) do
    # Handle case where only token params are present
    case save_token(socket, socket.assigns.action, token_params) do
      {:ok, token} ->
        handle_token_success(socket, token, nil)

      {:ok, token, plain_token} ->
        handle_token_success(socket, token, plain_token)

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}

      {:error, message} ->
        {:noreply, put_flash(socket, :error, message)}
    end
  end

  @impl true
  def handle_event("cancel", _params, socket) do
    {:noreply, push_navigate(socket, to: ~p"/manage/settings/api_manager")}
  end

  defp handle_token_success(socket, _token, plain_token) do
    if plain_token do
      # Send message to parent to show token details modal
      send(self(), {:token_created_with_value, plain_token})
    else
      # Send regular token created message
      send(self(), {:token_created})
    end

    {:noreply, socket}
  end

  defp assign_form(socket, changeset \\ nil) do
    changeset = changeset || change_token(socket.assigns.token, socket.assigns.action)

    assign(socket, :form, to_form(changeset))
  end

  defp change_token(nil, :create_master) do
    # Master token defaults
    UserApiToken.create_changeset(%UserApiToken{}, %{
      name: "Master Token",
      description: "Non-expiring master token with full access",
      scopes: ["admin"],
      expires_at: nil
    })
  end

  defp change_token(nil, :create) do
    # Regular token defaults
    UserApiToken.create_changeset(%UserApiToken{}, %{
      scopes: ["read"]
    })
  end

  defp change_token(token, :edit) do
    UserApiToken.update_changeset(token, %{})
  end

  defp save_token(socket, :create_master, _token_params) do
    System.create_master_api_token(socket.assigns.current_user)
  end

  defp save_token(socket, :create, token_params) do
    # Process scopes from checkbox array
    token_params = process_token_params(token_params)

    # Set default scopes for regular users if none provided
    token_params = if socket.assigns.is_admin do
      token_params
    else
      Map.update(token_params, "scopes", ["read"], fn
        scopes when is_list(scopes) and length(scopes) > 0 -> scopes
        _ -> ["read"]
      end)
    end

    System.create_api_token(socket.assigns.current_user, token_params)
  end

  defp save_token(socket, :edit, token_params) do
    # Process scopes from checkbox array
    token_params = process_token_params(token_params)

    System.update_api_token(socket.assigns.token, token_params)
  end

  defp process_token_params(params) do
    params
    |> Map.update("scopes", [], fn
      scopes when is_list(scopes) -> scopes
      scopes when is_binary(scopes) -> [scopes]
      _ -> []
    end)
    |> Map.update("expires_at", nil, fn
      "" -> nil
      datetime_str -> parse_datetime(datetime_str)
    end)
    |> Map.update("ip_whitelist", nil, fn
      nil ->
        nil

      "" ->
        nil

      whitelist when is_binary(whitelist) ->
        whitelist
        |> String.split(",")
        |> Enum.map(&String.trim/1)
        |> Enum.reject(&(&1 == ""))
    end)
  end

  defp parse_datetime(datetime_str) do
    # datetime-local input sends format like "2025-12-02T14:19"
    # We need to add seconds and timezone to make it valid ISO8601
    datetime_with_seconds = datetime_str <> ":00Z"

    case DateTime.from_iso8601(datetime_with_seconds) do
      {:ok, datetime, _offset} -> datetime
      _ -> nil
    end
  end
end
