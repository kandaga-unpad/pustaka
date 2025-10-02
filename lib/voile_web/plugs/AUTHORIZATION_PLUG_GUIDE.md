# Authorization Plug - Fixed Issues

## Issues Fixed

### ❌ Original Issues

1. **Incorrect `put_view/2` usage** - Was passing JSON data directly
2. **Type mismatch** - Dialyzer warning about contract violation
3. **UUID handling** - Was trying to convert UUID strings to integers

### ✅ Fixed Implementation

#### 1. Changed from `put_view/2` to `json/2`

**Before:**
```elixir
conn
|> put_status(:unauthorized)
|> put_view(json: %{error: "Authentication required"})
|> halt()
```

**After:**
```elixir
conn
|> put_status(:unauthorized)
|> json(%{error: "Authentication required"})
|> halt()
```

**Why:** `put_view/2` expects a view module, not JSON data. `json/2` from `Phoenix.Controller` is the correct function for JSON responses.

#### 2. Fixed UUID handling in scope extraction

**Before:**
```elixir
{resource_type, String.to_integer(id)}
```

**After:**
```elixir
{resource_type, id}
```

**Why:** Your app uses binary UUIDs (`:binary_id`), not integers. The ID should be passed as-is.

#### 3. Added comprehensive documentation

Added detailed moduledoc explaining:
- How to use the plug in controllers
- Available options
- Response codes
- Example usage patterns

## Current Implementation

```elixir
defmodule VoileWeb.Plugs.Authorization do
  @moduledoc """
  Plug for authorization in Phoenix controllers.
  [Full documentation included]
  """

  import Plug.Conn
  import Phoenix.Controller
  alias VoileWeb.Auth.Authorization

  def init(opts), do: opts

  def call(conn, opts) do
    permission = Keyword.fetch!(opts, :permission)
    scope = get_scope(conn, opts)

    case conn.assigns[:current_user] do
      nil ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Authentication required"})
        |> halt()

      user ->
        if Authorization.can?(user, permission, scope: scope) do
          conn
        else
          conn
          |> put_status(:forbidden)
          |> json(%{error: "Insufficient permissions"})
          |> halt()
        end
    end
  end

  defp get_scope(conn, opts) do
    case Keyword.get(opts, :scope) do
      nil ->
        nil

      {resource_type, param_name} when is_atom(param_name) ->
        case conn.params[to_string(param_name)] do
          nil -> nil
          id -> {resource_type, id}
        end

      scope ->
        scope
    end
  end
end
```

## Usage Examples

### Basic Permission Check

```elixir
defmodule VoileWeb.CollectionController do
  use VoileWeb, :controller

  # All actions require collections.read permission
  plug VoileWeb.Plugs.Authorization, permission: "collections.read"

  def index(conn, _params), do: render(conn, :index)
  def show(conn, _params), do: render(conn, :show)
end
```

### Action-Specific Permissions

```elixir
defmodule VoileWeb.CollectionController do
  use VoileWeb, :controller

  # Different permissions for different actions
  plug VoileWeb.Plugs.Authorization,
    permission: "collections.read"
    when action in [:index, :show]

  plug VoileWeb.Plugs.Authorization,
    permission: "collections.update"
    when action in [:edit, :update]

  plug VoileWeb.Plugs.Authorization,
    permission: "collections.delete"
    when action in [:delete]

  def index(conn, _params), do: render(conn, :index)
  def show(conn, _params), do: render(conn, :show)
  def edit(conn, _params), do: render(conn, :edit)
  def update(conn, _params), do: redirect(conn, to: ~p"/collections")
  def delete(conn, _params), do: send_resp(conn, :no_content, "")
end
```

### Scoped Permissions

```elixir
defmodule VoileWeb.CollectionController do
  use VoileWeb, :controller

  # Check permission scoped to specific collection
  # Gets collection ID from params[:id]
  plug VoileWeb.Plugs.Authorization,
    permission: "collections.update",
    scope: {:collection, :id}
    when action in [:edit, :update]

  plug VoileWeb.Plugs.Authorization,
    permission: "collections.delete",
    scope: {:collection, :id}
    when action in [:delete]

  def edit(conn, %{"id" => id}) do
    # User is authorized to edit this specific collection
    collection = get_collection(id)
    render(conn, :edit, collection: collection)
  end
end
```

### Custom Scope Parameter

```elixir
defmodule VoileWeb.ItemController do
  use VoileWeb, :controller

  # Get collection_id from params[:collection_id]
  plug VoileWeb.Plugs.Authorization,
    permission: "items.create",
    scope: {:collection, :collection_id}
    when action in [:new, :create]

  def create(conn, %{"collection_id" => collection_id, "item" => item_params}) do
    # User is authorized to create items in this collection
    # ...
  end
end
```

## Response Codes

| Code | Description | When |
|------|-------------|------|
| `401 Unauthorized` | User not authenticated | `current_user` not in assigns |
| `403 Forbidden` | Insufficient permissions | User doesn't have required permission |
| `200 OK` | Success | User has permission, continues to action |

## Error Responses

### 401 Response
```json
{
  "error": "Authentication required"
}
```

### 403 Response
```json
{
  "error": "Insufficient permissions"
}
```

## Integration with Other Helpers

The plug works seamlessly with other authorization helpers:

```elixir
defmodule VoileWeb.CollectionController do
  use VoileWeb, :controller
  import VoileWeb.Auth.ControllerHelpers

  # Plug for basic authorization
  plug VoileWeb.Plugs.Authorization,
    permission: "collections.read"

  def show(conn, %{"id" => id}) do
    collection = get_collection(id)
    
    # Additional fine-grained check for specific action
    can_edit = can?(conn, "collections.update", scope: {:collection, id})
    can_delete = can?(conn, "collections.delete", scope: {:collection, id})
    
    render(conn, :show,
      collection: collection,
      can_edit: can_edit,
      can_delete: can_delete
    )
  end
end
```

## Testing the Plug

```elixir
defmodule VoileWeb.CollectionControllerTest do
  use VoileWeb.ConnCase

  setup do
    user = insert_user()
    permission = insert_permission("collections.read")
    grant_permission(user.id, permission.id)
    
    {:ok, user: user}
  end

  test "authorized user can access index", %{user: user} do
    conn =
      build_conn()
      |> assign(:current_user, user)
      |> get(~p"/collections")

    assert html_response(conn, 200)
  end

  test "unauthorized user gets 403", %{user: user} do
    conn =
      build_conn()
      |> assign(:current_user, user)
      |> delete(~p"/collections/#{collection_id}")

    assert json_response(conn, 403)
    assert %{"error" => "Insufficient permissions"} = json_response(conn, 403)
  end

  test "unauthenticated user gets 401" do
    conn = build_conn() |> get(~p"/collections")

    assert json_response(conn, 401)
    assert %{"error" => "Authentication required"} = json_response(conn, 401)
  end
end
```

## Benefits of Using the Plug

1. **Declarative** - Permission requirements are clear at the top of the controller
2. **DRY** - Don't repeat authorization checks in every action
3. **Consistent** - Same authorization logic across all controllers
4. **Early Exit** - Stops unauthorized requests before action execution
5. **Composable** - Can combine multiple plugs with different permissions

## Status

✅ All warnings fixed
✅ Proper JSON response handling
✅ UUID support
✅ Comprehensive documentation
✅ Ready for use
