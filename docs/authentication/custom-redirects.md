# Custom Unauthorized Redirects

This guide explains how to customize where users are redirected when they attempt to access unauthorized resources.

## Overview

By default, when a user attempts to access a page they're not authorized to view, they are redirected to the home page (`/`). However, you can customize this redirect based on user type, role, or other criteria.

## Implementation

### 1. UnauthorizedError with redirect_to

The `VoileWeb.Auth.Authorization.UnauthorizedError` exception now supports an optional `redirect_to` field:

```elixir
raise VoileWeb.Auth.Authorization.UnauthorizedError,
  permission: "system.settings",
  user_id: user.id,
  redirect_to: "/custom/path"
```

### 2. Using authorize! with redirect_to Option

The recommended approach is to use the `authorize!/3` function with the `redirect_to` option:

```elixir
def mount(_params, _session, socket) do
  handle_mount_errors do
    user = socket.assigns.current_scope.user
    
    # Determine redirect based on user type
    redirect_path = 
      if user && user.user_type && user.user_type.slug in ["administrator", "staff"] do
        ~p"/manage"  # Staff goes to dashboard
      else
        ~p"/"        # Members go to home
      end
    
    # Authorize with custom redirect
    VoileWeb.Auth.Authorization.authorize!(socket, "system.settings", redirect_to: redirect_path)
    
    # ... rest of mount logic
  end
end
```

### 3. Error Handler

The `VoileWeb.Live.AuthHooks.handle_mount_errors/1` macro automatically respects the `redirect_to` field:

```elixir
{:error, %UnauthorizedError{} = error} ->
  {:halt,
   socket
   |> put_flash(:error, error.message)
   |> redirect(to: error.redirect_to || ~p"/")}
```

## Use Cases

### Different Redirects for Staff vs Members

```elixir
redirect_path = 
  if user.user_type.slug in ["administrator", "staff"] do
    ~p"/manage"  # Staff sees their dashboard
  else
    ~p"/"        # Members see home page
  end

authorize!(socket, "admin.function", redirect_to: redirect_path)
```

### Role-Based Redirects

```elixir
redirect_path = 
  cond do
    has_role?(user, "super_admin") -> ~p"/admin/dashboard"
    has_role?(user, "staff") -> ~p"/manage"
    true -> ~p"/"
  end

authorize!(socket, permission, redirect_to: redirect_path)
```

### Context-Aware Redirects

```elixir
# Redirect back to where they came from
redirect_path = Map.get(params, "return_to", ~p"/")

authorize!(socket, permission, redirect_to: redirect_path)
```

## Benefits

1. **Better UX**: Users are directed to a meaningful page rather than always going to the home page
2. **Contextual**: Different user types see appropriate fallback pages
3. **Flexible**: Can be customized per authorization check
4. **Consistent**: Uses the same authorization flow throughout the app

## Examples in Codebase

See `VoileWeb.Dashboard.Settings.AppProfileSettingsLive` for a real-world example where:
- Staff/admins attempting to access system settings (unauthorized) → redirected to `/manage`
- Regular members attempting to access system settings → redirected to `/` (home)

## API Reference

### authorize!/3

```elixir
@spec authorize!(
  User.t() | Phoenix.LiveView.Socket.t() | Plug.Conn.t(),
  String.t(),
  keyword()
) :: :ok | no_return()
```

**Options:**
- `:redirect_to` - Custom path to redirect to on unauthorized access (default: `/`)
- `:scope` - Permission scope to check within

**Example:**
```elixir
authorize!(socket, "users.delete", redirect_to: ~p"/users")
```

### UnauthorizedError

**Fields:**
- `:permission` - The permission that was checked
- `:user_id` - The ID of the user who was denied (can be nil)
- `:redirect_to` - Optional custom redirect path
- `:message` - Human-readable error message

## Testing

When testing authorization failures, you can verify the redirect path:

```elixir
test "unauthorized staff redirects to /manage", %{conn: conn} do
  conn = get(conn, ~p"/admin/settings")
  assert redirected_to(conn) == ~p"/manage"
  assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "not authorized"
end
```
