# Import Fixes Summary - Composite Key Implementation

## Problem Identified

**Critical Data Integrity Issue**: The original implementation used only `old_biblio_id` as the unique identifier, causing collisions across different units/nodes.

### Example of the Problem:

- **Unit 1** has `biblio_id = 100` (Collection A)
- **Unit 2** has `biblio_id = 100` (Collection B - different collection)
- Original code would skip Unit 2's collection as a "duplicate"
- Item importer would map items to wrong collections

## Solutions Implemented

### 1. BiblioImporter Changes (`lib/voile/migration/biblio_importer.ex`)

#### a. Cache Initialization

```elixir
# BEFORE: Only used old_biblio_id
existing_collections =
  from(c in Collection, select: c.old_biblio_id, where: not is_nil(c.old_biblio_id))
  |> Repo.all()
  |> MapSet.new()

# AFTER: Uses composite key {unit_id, old_biblio_id}
existing_collections =
  from(c in Collection,
    select: {c.unit_id, c.old_biblio_id},
    where: not is_nil(c.old_biblio_id)
  )
  |> Repo.all()
  |> MapSet.new()
```

#### b. Duplicate Check

```elixir
# BEFORE: Only checked old_biblio_id
if MapSet.member?(cache.existing_collections, biblio_id_int) do
  {:skip, "Collection with biblio_id #{biblio_id_int} already exists"}

# AFTER: Checks composite key (unit_id, old_biblio_id)
if MapSet.member?(cache.existing_collections, {unit_id, biblio_id_int}) do
  {:skip, "Collection with unit_id #{unit_id}, biblio_id #{biblio_id_int} already exists"}
```

#### c. Enhanced Logging

- Now shows unit ID and filename in processing messages
- Limits verbose output to first 10 skipped rows
- Shows progress every 1000 skips
- Displays sample of skipped rows with column counts
- Summary report of problematic units at the end

### 2. ItemImporter Changes (`lib/voile/migration/item_importer.ex`)

#### a. Biblio Map Building

```elixir
# BEFORE: Simple biblio_id → collection_id mapping
defp build_biblio_map do
  from(c in Collection, select: {c.old_biblio_id, c.id})
  |> Repo.all()
  |> Enum.into(%{}, fn {old_biblio_id, id} ->
    {parse_int(to_string(old_biblio_id)), id}
  end)
end

# AFTER: Composite key {unit_id, old_biblio_id} → collection_id mapping
defp build_biblio_map do
  from(c in Collection, select: {c.unit_id, c.old_biblio_id, c.id})
  |> Repo.all()
  |> Enum.reduce(%{}, fn {unit_id, old_biblio_id, id}, acc ->
    case old_biblio_id do
      nil -> acc
      val ->
        biblio_int = parse_int(to_string(val))
        if biblio_int && unit_id do
          Map.put(acc, {unit_id, biblio_int}, id)
        else
          acc
        end
    end
  end)
end
```

#### b. Item Preparation with Composite Key Lookup

```elixir
# BEFORE: Looked up by biblio_id only
case Map.fetch(biblio_map, parse_int(biblio_id)) do

# AFTER: Looks up by (unit_id, biblio_id)
biblio_id_int = parse_int(biblio_id)
case Map.fetch(biblio_map, {unit_id, biblio_id_int}) do
```

#### c. Column Validation

```elixir
# Added guard clause to ensure minimum 21 columns
defp prepare_item_data([...21 columns...] = row, ...)
     when length(row) >= 21 do
  # Process valid row
end

defp prepare_item_data(row, _cache, _state_ref, _unit_id) do
  {:error, {:invalid_row, "Expected at least 21 columns, got #{length(row)}"}}
end
```

#### d. Enhanced Error Reporting

- Logs first 10 errors with line numbers and column counts
- Tracks composite key in error messages: `"unit_#{unit_id}_biblio_#{biblio_id}"`
- Shows sample errors in summary

### 3. Database Migration

**File**: `priv/repo/migrations/20250424011551_create_collections.exs` (updated original migration)

```elixir
# Added to the original create_collections migration:

# Composite unique index to ensure old_biblio_id is unique per unit
# This prevents collisions when the same biblio_id exists in different units
create unique_index(:collections, [:unit_id, :old_biblio_id],
         name: :collections_unit_id_old_biblio_id_index,
         where: "old_biblio_id IS NOT NULL"
       )
```

**Note**: Since you use `mix ecto.reset`, this is integrated directly into the original collections table migration rather than as a separate migration file.

## CSV Column Validation

### Biblio CSV (29 columns)

```
biblio_id,gmd_id,title,sor,edition,isbn_issn,publisher_id,publish_year,
collation,series_title,call_number,language_id,source,publish_place_id,
classification,notes,image,file_att,opac_hide,promoted,labels,frequency_id,
spec_detail_info,content_type_id,media_type_id,carrier_type_id,input_date,
last_update,uid
```

✅ Guard clause: `when length(row) >= 29`

### Item CSV (21 columns)

```
item_id,biblio_id,call_number,coll_type_id,item_code,inventory_code,
received_date,supplier_id,order_no,location_id,order_date,item_status_id,
site,source,invoice,price,price_currency,invoice_date,input_date,
last_update,uid
```

✅ Guard clause: `when length(row) >= 21`

## Migration Steps

### 1. Run Database Reset (as you normally do)

```bash
mix ecto.reset
```

This will:

- Drop and recreate the database
- Run all migrations including the updated collections migration with composite unique index

### 2. Run Imports

```elixir
# Import bibliographies (collections)
Voile.Migration.BiblioImporter.import_all(1000, false)

# Import items
Voile.Migration.ItemImporter.import_all(1000)
```

## Expected Behavior After Fixes

### Before (Broken):

```
Unit 1: biblio_id=100 → Collection A ✅ Imported
Unit 2: biblio_id=100 → Collection B ❌ SKIPPED (false duplicate)
Unit 3: biblio_id=100 → Collection C ❌ SKIPPED (false duplicate)

Result: 66,975 rows skipped, 0 imported
```

### After (Fixed):

```
Unit 1: biblio_id=100 → Collection A ✅ Imported
Unit 2: biblio_id=100 → Collection B ✅ Imported (different unit!)
Unit 3: biblio_id=100 → Collection C ✅ Imported (different unit!)

Result: Minimal skips (only real duplicates or invalid data)
```

## Benefits

1. ✅ **Data Integrity**: Each unit's bibliographies are properly imported
2. ✅ **Correct Item Mapping**: Items map to the correct collection within their unit
3. ✅ **Better Logging**: Clear visibility into what's being skipped and why
4. ✅ **Database Constraints**: Prevents accidental duplicates at DB level
5. ✅ **Scalability**: Works correctly with any number of units/nodes

## Testing Checklist

- [ ] Run database migration
- [ ] Clear existing test data
- [ ] Import biblio files - verify low skip rate
- [ ] Check that each unit's collections are imported
- [ ] Import item files - verify items map to correct collections
- [ ] Verify no "missing biblio_id" errors for valid items
- [ ] Check logs for any unexpected patterns

## Monitoring

Watch for these in the output:

```
✅ Good signs:
- "Collections: XXXX" (high number)
- "Skipped: XX" (low number)
- "Missing biblio_id" errors should be rare

⚠️ Warning signs:
- "Skipped: XXXXX" (very high number)
- Many "Invalid row format" with 29 columns (investigate CSV parsing)
- "Units with high skip rates" section populated
```
