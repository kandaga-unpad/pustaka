# Seeds Idempotency Fix

## Issue
When running `mix ecto.reset`, the seeds were crashing due to primary key conflicts when trying to insert records that already existed.

## Root Cause
Several seed files were using `Repo.insert!()` without checking if records already existed:
- `metadata_resource_class.exs` - Inserting resource classes without checking
- `metadata_properties.exs` - Inserting properties without checking

When PostgreSQL auto-generated IDs, it would eventually hit an ID that was manually assigned elsewhere, causing a constraint error.

## Files Fixed

### 1. `priv/repo/seeds/metadata_resource_class.exs`
**Before:**
```elixir
for resource <- resource_class do
  %ResourceClass{...}
  |> Repo.insert!()
end
```

**After:**
```elixir
for resource <- resource_class do
  case Repo.get_by(ResourceClass, local_name: resource[:local_name]) do
    nil -> 
      %ResourceClass{...}
      |> Repo.insert!()
    _existing -> 
      :ok
  end
end
```

### 2. `priv/repo/seeds/metadata_properties.exs`
**Before:**
```elixir
for property <- properties_list do
  %Property{...}
  |> Repo.insert!()
end
```

**After:**
```elixir
for property <- properties_list do
  vocabulary_id = case property[:vocabulary_id] do ... end
  
  case Repo.get_by(Property, local_name: property[:local_name], vocabulary_id: vocabulary_id) do
    nil -> 
      %Property{...}
      |> Repo.insert!()
    _existing -> 
      :ok
  end
end
```

### 3. `priv/repo/seeds/glams.exs`
Enhanced to handle hardcoded IDs gracefully:

**Resource Classes:**
```elixir
defp ensure_resource_classes do
  # First check by ID, then by local_name
  case Repo.get(ResourceClass, rc.id) do
    nil ->
      case Repo.get_by(ResourceClass, local_name: rc.local_name) do
        nil -> insert with explicit ID
        existing -> show info message
      end
    _existing -> show success message
  end
end
```

**Properties:**
```elixir
defp ensure_properties do
  # First check by ID, then by local_name
  case Repo.get(Property, prop.id) do
    nil ->
      case Repo.get_by(Property, local_name: prop.local_name) do
        nil -> insert with explicit ID
        existing -> show info message
      end
    _existing -> show success message
  end
end
```

**Creator:**
```elixir
defp ensure_default_creator do
  # First check by ID, then by name
  case Repo.get(Creator, 1) do
    nil ->
      case Repo.get_by(Creator, creator_name: "System") do
        nil -> insert
        existing -> show info message
      end
    _existing -> show success message
  end
end
```

## Seeds That Were Already Idempotent

### ✅ `priv/repo/seeds/pustakawan.exs`
Already using proper checks:
```elixir
case Repo.get_by(Accounts.User, email: email) do
  nil -> create user
  existing -> update node_id
end
```

### ✅ `priv/repo/seeds/master.exs`
Already using proper checks:
```elixir
case Repo.get_by(MemberType, slug: member_type.slug) do
  nil -> create
  existing -> return existing
end
```

### ✅ `priv/repo/seeds/seeds.exs`
Already using proper checks for nodes and vocabularies.

## Testing

Now you can safely run:

```bash
mix ecto.reset
```

Multiple times without errors! All seeds are now idempotent.

## Benefits

1. **No duplicate records** - Existing records are preserved
2. **Safe to re-run** - Seeds can be run multiple times
3. **ID conflict handling** - Gracefully handles hardcoded IDs
4. **Clear feedback** - Shows informative messages about what was created/skipped
5. **Database consistency** - No constraint errors or crashes

## Seed Execution Order

The seeds run in this order (defined in `priv/repo/seeds/seeds.exs`):

1. Vocabularies
2. Nodes
3. Metadata Properties (`metadata_properties.exs`)
4. Metadata Resource Classes (`metadata_resource_class.exs`)
5. GLAM Collections (`glams.exs`)
6. Authorization System (`authorization_seeds.ex`)
7. Member Types & Admin User (`master.exs`)
8. Librarian Accounts (`pustakawan.exs`)

All of them are now idempotent! ✅
