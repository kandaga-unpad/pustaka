# Stock Opname Context Migration Guide

## Overview

The stock opname functionality has been reorganized into its own dedicated schema and context structure:

- **Context**: `Voile.Schema.StockOpname` (was `Voile.StockOpname`)
- **Location**: `lib/voile/schema/stock_opname.ex` (was `lib/voile/stock_opname.ex`)
- **Schemas**: Moved to `lib/voile/schema/stock_opname/` (were in `lib/voile/schema/catalog/`)

This refactoring improves code organization by grouping all stock opname-related functionality together.

## What Changed

### New Directory Structure

```
lib/voile/schema/
├── stock_opname.ex                    # Main context module
└── stock_opname/
    ├── session.ex                     # StockOpnameSession schema
    ├── item.ex                        # StockOpnameItem schema
    ├── librarian_assignment.ex        # LibrarianAssignment schema
    └── notifier.ex                    # Email notifications
```

### Schema Module Renames

| Old Module                                 | New Module                                     |
| ------------------------------------------ | ---------------------------------------------- |
| `Voile.Schema.Catalog.StockOpnameSession`  | `Voile.Schema.StockOpname.Session`             |
| `Voile.Schema.Catalog.StockOpnameItem`     | `Voile.Schema.StockOpname.Item`                |
| `Voile.Schema.Catalog.LibrarianAssignment` | `Voile.Schema.StockOpname.LibrarianAssignment` |
| `Voile.Schema.Catalog.StockOpnameNotifier` | `Voile.Schema.StockOpname.Notifier`            |

### Context Module Rename

| Old Module          | New Module                 |
| ------------------- | -------------------------- |
| `Voile.StockOpname` | `Voile.Schema.StockOpname` |

## Function Mapping

All stock opname functions have been moved and some renamed for better consistency:

| Old Function (Catalog)            | New Function (StockOpname)       | Notes        |
| --------------------------------- | -------------------------------- | ------------ |
| `create_stock_opname_session/2`   | `create_session/2`               | Shorter name |
| `list_stock_opname_sessions/3`    | `list_sessions/3`                | Shorter name |
| `get_stock_opname_session!/1`     | `get_session!/1`                 | Shorter name |
| `update_stock_opname_session/3`   | `update_session/3`               | Shorter name |
| `start_stock_opname_session/2`    | `start_session/2`                | Shorter name |
| `assign_librarians_to_session/3`  | `assign_librarians/3`            | Shorter name |
| `all_librarians_completed?/1`     | `all_librarians_completed?/1`    | Same         |
| `start_librarian_work/2`          | `start_librarian_work/2`         | Same         |
| `complete_librarian_work/3`       | `complete_librarian_work/3`      | Same         |
| `get_librarian_progress/2`        | `get_librarian_progress/2`       | Same         |
| `find_items_for_scanning/2`       | `find_items_for_scanning/2`      | Same         |
| `add_item_to_session/3`           | `add_item_to_session/3`          | Same         |
| `check_item_in_session/4`         | `check_item/4`                   | Shorter name |
| `get_session_statistics/1`        | `get_session_statistics/1`       | Same         |
| `list_session_items/2`            | `list_session_items/2`           | Same         |
| `complete_stock_opname_session/2` | `complete_session/2`             | Shorter name |
| `cancel_stock_opname_session/2`   | `cancel_session/2`               | Shorter name |
| `list_sessions_pending_review/2`  | `list_sessions_pending_review/2` | Same         |
| `get_session_review_summary/1`    | `get_session_review_summary/1`   | Same         |
| `approve_stock_opname_session/3`  | `approve_session/3`              | Shorter name |
| `reject_stock_opname_session/3`   | `reject_session/3`               | Shorter name |
| `request_session_revision/3`      | `request_session_revision/3`     | Same         |

## Migration Steps

### 1. Update Your Imports

**Before:**

```elixir
alias Voile.Schema.Catalog
alias Voile.Schema.Catalog.{StockOpnameSession, LibrarianAssignment}
```

**After:**

```elixir
alias Voile.Schema.Catalog
alias Voile.Schema.StockOpname
alias Voile.Schema.StockOpname.{Session, LibrarianAssignment}
```

### 2. Update Function Calls

**Before:**

```elixir
Catalog.create_stock_opname_session(attrs, user)
Catalog.list_stock_opname_sessions(page, per_page, filters)
Catalog.check_item_in_session(session, item_id, attrs, user)
```

**After:**

```elixir
StockOpname.create_session(attrs, user)
StockOpname.list_sessions(page, per_page, filters)
StockOpname.check_item(session, item_id, attrs, user)
```

### 3. Update Schema References

**Before:**

```elixir
alias Voile.Schema.Catalog.StockOpnameSession
session = %StockOpnameSession{}
```

**After:**

```elixir
alias Voile.Schema.StockOpname.Session
session = %Session{}
```

### 3. Update LiveViews and Controllers

Search for uses of the old modules in your codebase:

```bash
# PowerShell
Select-String -Path "lib/voile_web" -Pattern "Catalog\.(create_stock_opname|list_stock_opname|check_item_in_session)" -Recurse
Select-String -Path "lib/voile_web" -Pattern "Catalog\.StockOpname" -Recurse
```

Then update them to use the new `StockOpname` context and schema modules.

### 4. Example LiveView Update

**Before:**

```elixir
defmodule VoileWeb.StockOpnameLive.Index do
  use VoileWeb, :live_view
  alias Voile.Schema.Catalog
  alias Voile.Schema.Catalog.StockOpnameSession

  def handle_event("create_session", params, socket) do
    case Catalog.create_stock_opname_session(params, socket.assigns.current_user) do
      {:ok, session} -> ...
      {:error, changeset} -> ...
    end
  end
end
```

**After:**

```elixir
defmodule VoileWeb.StockOpnameLive.Index do
  use VoileWeb, :live_view
  alias Voile.Schema.StockOpname
  alias Voile.Schema.StockOpname.Session

  def handle_event("create_session", params, socket) do
    case StockOpname.create_session(params, socket.assigns.current_user) do
      {:ok, session} -> ...
      {:error, changeset} -> ...
    end
  end
end
```

## Benefits of This Refactoring

1. **Better Organization**: All stock opname modules are now grouped together under `lib/voile/schema/stock_opname/`
2. **Clearer Module Names**: Shorter, clearer names (e.g., `Session` instead of `StockOpnameSession` within the StockOpname context)
3. **Better Namespace**: `Voile.Schema.StockOpname` clearly indicates this is a schema-related context
4. **Easier Maintenance**: Changes to stock opname functionality are isolated in one directory
5. **Better Discoverability**: Related modules are physically grouped together
6. **Shorter Function Names**: Context-scoped functions can have shorter, clearer names

## Files to Check

After migration, search these locations for any remaining references:

- `lib/voile_web/live/stock_opname/` - LiveView modules
- `lib/voile_web/controllers/` - Controller modules
- `test/voile/` - Test files
- `test/voile_web/` - Integration tests

## Testing the Migration

Run your test suite to ensure everything still works:

```bash
mix test
```

Focus on these test files:

- `test/voile/stock_opname_test.exs` (create if doesn't exist)
- Any LiveView tests that use stock opname functionality

## Backwards Compatibility

There is **no backwards compatibility** - this is a breaking change. You must update all references to the old function names.

Consider creating a deprecation wrapper if you need a gradual migration:

```elixir
# In catalog.ex (temporary)
@deprecated "Use Voile.StockOpname.create_session/2 instead"
def create_stock_opname_session(attrs, user) do
  Voile.StockOpname.create_session(attrs, user)
end
```

## Questions or Issues?

If you encounter any issues during migration, check:

1. All aliases are updated in your modules
2. Function names match the new naming scheme
3. The `Voile.StockOpname` module is being compiled (check `mix compile`)

## Summary

This refactoring creates a cleaner, more organized structure:

- **`Voile.Schema.Catalog`**: Collections, Items, Attachments, Transfers
- **`Voile.Schema.StockOpname`**: Inventory checking sessions and operations (with schemas grouped in `lib/voile/schema/stock_opname/`)

The new structure makes the codebase more maintainable and follows Elixir/Phoenix best practices for schema and context organization.
