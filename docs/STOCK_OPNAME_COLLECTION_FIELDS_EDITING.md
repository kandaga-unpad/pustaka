# Stock Opname Collection Fields Editing

## Overview

Librarians can now edit and add collection metadata fields during stock opname scanning. This allows for updating bibliographic information in real-time as items are physically verified.

## Features

### 1. Edit Existing Collection Fields

- All existing collection fields (except creator/author fields) are displayed as editable inputs
- Changes are tracked and saved when the item is checked
- Fields show their original label from the metadata property

### 2. Add New Metadata Fields

- Click the "+ Add Field" button to see available metadata properties
- Available properties are based on the collection's resource template
- Select a property from the dropdown to add it to the collection
- New fields are highlighted with a green border
- Enter the value for the new field before checking the item

### 3. Remove Fields

- Click the "X" button next to any field to mark it for deletion
- For new fields being added, clicking "X" cancels the addition and returns the property to the available list
- For existing fields, clicking "X" marks them for deletion when the item is checked

## Technical Implementation

### Frontend (scan.ex)

**New Assigns:**
- `@available_metadata_properties` - List of metadata properties from the collection's template that aren't already in use
- `@collection_field_edits` - Map tracking changes to collection fields:
  - Direct field ID keys map to updated values
  - `:new_fields` - Map of new fields being added (keyed by unique identifier)
  - `:deleted_fields` - List of field IDs marked for deletion
- `@show_add_field_dropdown` - Boolean to toggle the add field UI

**Event Handlers:**
- `toggle_add_field` - Shows/hides the add field dropdown
- `add_collection_field` - Adds a new field from available properties
- `update_collection_field` - Updates the value of an existing field
- `update_new_collection_field` - Updates the value of a new field being added
- `remove_collection_field` - Marks an existing field for deletion
- `cancel_new_collection_field` - Cancels adding a new field

**Helper Functions:**
- `build_collection_field_changes/2` - Builds the changeset for collection field updates, additions, and deletions

### Backend (stock_opname.ex)

**Updated Function:**
- `check_item_with_collection/6` - Now handles `collection_field_changes` within the `collection_changes` parameter

**New Multi Step:**
- `:handle_collection_field_changes` - Applies collection field changes in a transaction:
  - Updates existing fields with new values
  - Inserts new collection fields
  - Deletes marked fields

### Data Structure

Collection field changes are passed as:

```elixir
%{
  "collection_field_changes" => %{
    updated: [
      %{id: "field-id-1", value: "new value"}
    ],
    new: [
      %{
        property_id: 123,
        name: "dcterms:publisher",
        label: "Publisher",
        value: "Example Publisher"
      }
    ],
    deleted: ["field-id-2", "field-id-3"]
  }
}
```

## User Workflow

1. Scan or search for an item
2. Item details are loaded, showing:
   - Editable existing collection fields
   - "+ Add Field" button (if template has available properties)
3. To edit a field:
   - Simply type in the input box
   - Changes are debounced (300ms delay)
4. To add a new field:
   - Click "+ Add Field"
   - Select a property from the dropdown
   - Enter the value in the new field input
5. To remove a field:
   - Click the "X" button next to the field
6. Click "Mark as Checked" to save all changes

## Notes

- Creator/author fields are handled separately and not included in the editable metadata fields
- Only properties defined in the collection's resource template can be added
- Properties already used in existing collection fields are filtered out from the available list
- All changes are saved atomically when the item is checked
- Changes are tracked in the `has_changes` flag and contribute to the session's "items with changes" count
