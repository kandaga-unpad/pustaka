defmodule VoileWeb.Live.AuthHooks do
  @moduledoc """
  LiveView hooks for handling authentication and authorization.

  These hooks automatically catch authorization errors and handle them gracefully
  by redirecting users with friendly flash messages instead of showing 500 errors.

  ## Usage

  Wrap your mount function with `handle_mount_errors`:

      def mount(params, session, socket) do
        handle_mount_errors do
          authorize!(socket, "some.permission")
          # ... rest of mount logic
          {:ok, socket}
        end
      end
  """

  @doc """
  Wraps mount logic to automatically catch and handle authorization errors.

  ## Examples

      def mount(_params, _session, socket) do
        handle_mount_errors do
          authorize!(socket, "system.settings")
          {:ok, assign(socket, :data, load_data())}
        end
      end
  """
  defmacro handle_mount_errors(do: block) do
    quote do
      try do
        unquote(block)
      rescue
        # Catch UnauthorizedError exceptions and convert to friendly redirect
        error in [VoileWeb.Auth.Authorization.UnauthorizedError] ->
          var!(socket)
          |> Phoenix.LiveView.put_flash(
            :error,
            "Access Denied: You don't have permission to access this page"
          )
          |> Phoenix.LiveView.push_navigate(to: ~p"/")
          |> then(&{:ok, &1})
      catch
        # Handle the redirect throw from authorize!
        {:unauthorized_redirect, updated_socket} ->
          {:ok, updated_socket}
      end
    end
  end
end
