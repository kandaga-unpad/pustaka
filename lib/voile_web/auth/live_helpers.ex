defmodule VoileWeb.Auth.LiveHelpers do
  @moduledoc """
  Helper functions for authorization in Phoenix LiveView.
  """

  alias VoileWeb.Auth.Authorization

  @doc """
  Authorize a user in a LiveView action.
  Returns {:ok, socket} or {:error, reason}.

  ## Examples

      def handle_event("delete", _params, socket) do
        case authorize(socket, "collections.delete", scope: {:collection, @collection.id}) do
          {:ok, socket} ->
            # ... perform deletion
            {:noreply, socket}

          {:error, reason} ->
            {:noreply, put_flash(socket, :error, reason)}
        end
      end
  """
  def authorize(socket, permission, opts \\ []) do
    user = socket.assigns[:current_user]

    if user do
      case Authorization.can?(user, permission, opts) do
        true ->
          {:ok, socket}

        false ->
          {:error, "You do not have permission to perform this action"}
      end
    else
      {:error, "You must be logged in to perform this action"}
    end
  end

  @doc """
  Authorize a user and raise an error if unauthorized.

  ## Examples

      def mount(%{"id" => id}, _session, socket) do
        authorize!(socket, "collections.read", scope: {:collection, id})
        # ... rest of mount
      end
  """
  def authorize!(socket, permission, opts \\ []) do
    user = socket.assigns[:current_user]

    if user do
      Authorization.authorize!(user, permission, opts)
      socket
    else
      raise Authorization.UnauthorizedError,
        permission: permission,
        user_id: nil
    end
  end

  @doc """
  Check if the current user has a permission.

  ## Examples

      <%= if can?(@socket, "collections.update", scope: {:collection, @collection.id}) do %>
        <.button>Edit</.button>
      <% end %>
  """
  def can?(socket, permission, opts \\ []) do
    case socket.assigns[:current_user] do
      nil -> false
      user -> Authorization.can?(user, permission, opts)
    end
  end

  @doc """
  Assign permissions to socket for use in templates.
  Useful when you need to check multiple permissions.

  ## Examples

      def mount(_params, _session, socket) do
        socket = assign_permissions(socket, @collection.id)
        {:ok, socket}
      end

      # In template:
      <%= if @permissions.can_edit do %>
        <.button>Edit</.button>
      <% end %>
  """
  def assign_permissions(socket, collection_id) do
    user = socket.assigns[:current_user]

    permissions =
      if user do
        %{
          can_read:
            Authorization.can?(user, "collections.read", scope: {:collection, collection_id}),
          can_update:
            Authorization.can?(user, "collections.update", scope: {:collection, collection_id}),
          can_delete:
            Authorization.can?(user, "collections.delete", scope: {:collection, collection_id}),
          can_create_items:
            Authorization.can?(user, "items.create", scope: {:collection, collection_id}),
          can_export:
            Authorization.can?(user, "items.export", scope: {:collection, collection_id})
        }
      else
        %{
          can_read: false,
          can_update: false,
          can_delete: false,
          can_create_items: false,
          can_export: false
        }
      end

    Phoenix.Component.assign(socket, :permissions, permissions)
  end
end
