defmodule VoileWeb.Auth.LiveHelpers do
  @moduledoc """
  Helper functions for authorization in Phoenix LiveView.
  """

  use Phoenix.VerifiedRoutes,
    endpoint: VoileWeb.Endpoint,
    router: VoileWeb.Router,
    statics: VoileWeb.static_paths()

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

  This function is typically used in mount/3 callbacks. It will redirect
  the user with a flash message if they don't have permission, rather than
  raising an error.

  ## Examples

      def mount(%{"id" => id}, _session, socket) do
        authorize!(socket, "collections.read", scope: {:collection, id})
        # ... rest of mount
      end
  """
  def authorize!(socket, permission, opts \\ []) do
    user = socket.assigns.current_scope.user

    if user do
      case Authorization.can?(user, permission, opts) do
        true ->
          socket

        false ->
          # Instead of raising an error, redirect with a flash message
          throw(
            {:unauthorized_redirect,
             socket
             |> Phoenix.LiveView.put_flash(
               :error,
               "Access Denied: You don't have permission to access this page"
             )
             |> Phoenix.LiveView.push_navigate(to: ~p"/manage")}
          )
      end
    else
      throw(
        {:unauthorized_redirect,
         socket
         |> Phoenix.LiveView.put_flash(:error, "You must be logged in to access this page")
         |> Phoenix.LiveView.push_navigate(to: ~p"/login")}
      )
    end
  end

  @doc """
  Check if the current user in the socket has a permission.

  ## Examples

      <%= if can?(assigns, "collections.update", scope: {:collection, @collection.id}) do %>
        <.button>Edit</.button>
      <% end %>
  """
  def can?(assigns_or_socket, permission, opts \\ [])

  def can?(%Phoenix.LiveView.Socket{} = socket, permission, opts) do
    case socket.assigns[:current_user] do
      nil -> false
      user -> Authorization.can?(user, permission, opts)
    end
  end

  def can?(%{} = assigns, permission, opts) when is_map(assigns) do
    case assigns[:current_user] do
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
