# Collection Filter System Documentation

## Overview

The collection page now includes a comprehensive filtering system that allows librarians and staff to search and filter collections based on multiple criteria. The system also includes role-based automatic filtering to ensure users only see collections relevant to their assigned location/node.

## Features

### 1. **Search Functionality**

- Full-text search across collection titles, descriptions, and collection types
- Real-time search with debouncing (300ms)
- Search persists across filter changes and pagination
- Clear search button to reset search query

### 2. **Comprehensive Filters**

#### Available Filter Categories:

1. **Status**

   - Draft
   - Pending
   - Published
   - Archived

2. **Access Level**

   - Public
   - Private
   - Restricted

3. **Collection Type**

   - Series
   - Book
   - Movie
   - Album
   - Course
   - Other

4. **Hierarchy**

   - All (shows both root and child collections)
   - Root Only (collections without parent)
   - Children Only (collections with parent)

5. **Creator/Author**

   - Dropdown list of all available creators
   - Searchable by creator name

6. **Location/Node**

   - Dropdown list of all system nodes
   - Useful for multi-location library systems
   - Automatically filtered for staff users (see Role-Based Filtering)

7. **Resource Class**
   - Dropdown list of available resource class types
   - Based on metadata configuration

### 3. **Quick Actions**

#### "My Location" Button

- Instantly filters collections to show only those from the user's assigned node
- Only visible for users with an assigned node
- Useful for staff to quickly see their own location's collections

#### "Clear All Filters" Button

- Resets all active filters at once
- Only appears when at least one filter is active
- Preserves search query if present

### 4. **Active Filters Display**

- Visual badges showing all currently active filters
- Color-coded by filter type:
  - **Indigo**: Status
  - **Green**: Access Level
  - **Purple**: Collection Type
  - **Yellow**: Hierarchy
  - **Pink**: Creator
  - **Blue**: Location
  - **Orange**: Resource Class
- Filter count displayed in header

### 5. **Role-Based Automatic Filtering**

The system automatically applies filters based on user roles:

#### Admin Users

- See all collections across all locations
- No automatic filters applied
- Can manually filter by any criteria

#### Staff/Librarian Users

- Automatically filtered to show only collections from their assigned node
- Can see collection count from their location
- Can manually override by selecting a different location in the filter
- The "My Location" button quickly returns them to their assigned node view

#### How Role Detection Works

The system checks if a user is an admin by looking at their `groups` field for:

- "admin"
- "administrator"
- "super_admin"
- "system_admin"

If the user is not an admin and has a `node_id` assigned, the system automatically filters collections by that node.

## Usage Examples

### Example 1: Staff Member Finding Published Books at Their Location

1. System automatically filters to staff member's node
2. Select "published" from Status filter
3. Select "book" from Collection Type filter
4. Results show only published books at their location

### Example 2: Admin Searching for Restricted Collections

1. Type collection name in search box
2. Select "restricted" from Access Level filter
3. Results show all matching restricted collections across all locations

### Example 3: Finding Root Collections by a Specific Creator

1. Select "Root Only" from Hierarchy filter
2. Select creator name from Creator/Author dropdown
3. Results show only root collections by that creator

### Example 4: Quick View of Staff's Location

1. Click "My Location" button
2. System instantly shows only collections from assigned node
3. Apply additional filters as needed (status, type, etc.)

## Technical Implementation

### Backend (Catalog Context)

The filtering is implemented in `Voile.Schema.Catalog`:

```elixir
# Basic usage with filters
Catalog.list_collections_paginated(page, per_page, search, %{
  status: "published",
  access_level: "public",
  collection_type: "book",
  creator_id: 5,
  node_id: 3,
  type_id: 1,
  parent_filter: "root"
})

# Role-based filtering for users
Catalog.list_collections_for_user(user, page, per_page, search, filters)

# Apply role-based filters manually
filters = Catalog.apply_role_based_filters(user, %{status: "published"})
```

### Frontend (LiveView)

All filter state is maintained in LiveView assigns:

- `@filters` - Map of active filters
- `@filter_status` - Current status filter value
- `@filter_access_level` - Current access level filter value
- `@filter_collection_type` - Current collection type filter value
- `@filter_creator_id` - Current creator filter value
- `@filter_node_id` - Current node filter value
- `@filter_type_id` - Current resource class filter value
- `@filter_hierarchy` - Current hierarchy filter value
- `@active_filters_count` - Number of active filters
- `@user_node_id` - User's assigned node (for quick filtering)

### Events

1. `filter_change` - Triggered when any filter dropdown changes
2. `clear_filters` - Clears all active filters
3. `filter_by_my_node` - Quick filter to user's assigned node
4. `search` - Text search with debouncing
5. `clear_search` - Clears search query
6. `paginate` - Page navigation (preserves filters)

## Customization

### Adding New Filter Categories

To add a new filter category:

1. **Update the Catalog context** (`lib/voile/schema/catalog.ex`):

   ```elixir
   defp apply_collection_filters(query, filters) do
     query
     # ... existing filters
     |> filter_by_your_new_field(filters[:your_new_field])
   end

   defp filter_by_your_new_field(query, nil), do: query
   defp filter_by_your_new_field(query, ""), do: query
   defp filter_by_your_new_field(query, value) do
     from c in query, where: c.your_field == ^value
   end
   ```

2. **Update LiveView mount** (`lib/voile_web/live/dashboard/catalog/collection_live/index.ex`):

   ```elixir
   |> assign(:filter_your_new_field, "")
   ```

3. **Update event handlers**:

   ```elixir
   defp build_filters_from_params(params) do
     %{}
     # ... existing filters
     |> maybe_add_filter(:your_new_field, params["your_new_field"])
   end
   ```

4. **Add UI in template** (`index.html.heex`):
   ```heex
   <div>
     <label class="block text-xs font-medium text-gray-700 dark:text-gray-300 mb-1">
       Your New Field
     </label>
     <select name="your_new_field" value={@filter_your_new_field} class="...">
       <option value="">All</option>
       <!-- Add options -->
     </select>
   </div>
   ```

### Modifying Role-Based Filtering Logic

Edit the `apply_role_based_filters/2` function in `lib/voile/schema/catalog.ex`:

```elixir
def apply_role_based_filters(user, filters) do
  cond do
    # Add custom role checks here
    has_permission?(user, "view_all_collections") ->
      filters

    # Custom filtering logic
    user.department == "special_collections" ->
      Map.put(filters, :collection_type, "special")

    # Default behavior
    true ->
      filters
  end
end
```

## Performance Considerations

1. **Tree View Limitation**: Tree view is limited to 50 collections for performance
2. **Filter Indexing**: Ensure database indexes exist on commonly filtered fields:

   - `status`
   - `access_level`
   - `collection_type`
   - `creator_id`
   - `unit_id` (node_id)
   - `type_id`
   - `parent_id`

3. **Query Optimization**: All filters are applied at the database level using Ecto queries for efficiency

## Future Enhancements

Potential improvements for the filter system:

1. **Advanced Filters**

   - Date range filtering (created_at, updated_at)
   - Multi-select filters (multiple statuses, multiple creators)
   - Tag-based filtering from collection_fields

2. **Saved Filters**

   - Allow users to save frequently used filter combinations
   - Quick access to saved filters

3. **Export Functionality**

   - Export filtered results to CSV/Excel
   - Bulk operations on filtered collections

4. **Filter Presets**

   - "My Draft Collections"
   - "Recently Published"
   - "Awaiting Review"

5. **Advanced Search**
   - Search within collection fields
   - Boolean operators (AND, OR, NOT)
   - Field-specific search

## Troubleshooting

### Filters Not Working

- Check browser console for JavaScript errors
- Verify all filter assigns are initialized in `mount/3`
- Ensure form uses `phx-change="filter_change"`

### Role-Based Filtering Issues

- Verify user's `node_id` is set correctly
- Check user's `groups` field contains correct role names
- Review `is_user_admin?/1` logic matches your role system

### Performance Issues

- Check database indexes on filtered fields
- Consider adding pagination limits
- Review query performance with `Ecto.Adapters.SQL.explain/2`

## Support

For issues or questions about the filter system:

1. Check this documentation
2. Review code comments in relevant files
3. Test filters in development environment
4. Check Ecto query logs for filter application
