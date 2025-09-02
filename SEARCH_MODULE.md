# Search Module Documentation

## Overview

The Search module provides comprehensive search functionality for the Voile library management system, supporting both librarian and patron users with role-based access control.

## Features

### 1. Universal Search
- Search across both collections and items simultaneously
- Real-time suggestions and autocomplete
- Role-based access control

### 2. Advanced Search
- Field-specific search criteria
- Multiple filter options
- Boolean search capabilities

### 3. Search Types
- **Collections Search**: Find books, journals, digital resources
- **Items Search**: Find specific item instances
- **Universal Search**: Combined search across all content types

### 4. User Roles
- **Patron**: Access to public and restricted resources
- **Librarian**: Full access to all resources including private ones

## API Endpoints

### Web Interface
```
GET /search                    # Main search page
GET /search/advanced           # Advanced search form
GET /search/live              # LiveView real-time search
```

### API Endpoints
```
GET /api/search               # JSON search API
GET /search/suggestions       # Autocomplete suggestions
```

## Usage Examples

### Basic Search
```elixir
# Search collections
Voile.Schema.Search.search_collections("programming", "patron", %{page: 1})

# Search items
Voile.Schema.Search.search_items("database", "librarian", %{per_page: 20})

# Universal search
Voile.Schema.Search.universal_search("science", "patron")
```

### Advanced Search
```elixir
search_params = %{
  title: "artificial intelligence",
  creator: "russell",
  status: "active"
}

Voile.Schema.Search.advanced_search(search_params, "librarian", %{type: :both})
```

### Using the Search Widget Component
```heex
<!-- In your LiveView template -->
<.live_component 
  module={VoileWeb.Components.SearchWidget} 
  id="search-widget"
  size="large"
  placeholder="Search library..."
/>
```

### Search Helper Functions
```elixir
# Get user role
user_role = Voile.Utils.SearchHelper.get_user_role(conn)

# Fetch suggestions
suggestions = Voile.Utils.SearchHelper.fetch_suggestions("python", "patron", 10)

# Sanitize query
clean_query = Voile.Utils.SearchHelper.sanitize_query(user_input)
```

## Search Parameters

### Collections
- `title`: Collection title
- `description`: Description content
- `creator`: Author/creator name
- `collection_type`: book, journal, media, digital, archive
- `status`: active, inactive, archived
- `access_level`: public, restricted, private

### Items
- `item_code`: Item identification code
- `inventory_code`: Inventory tracking code
- `location`: Physical location
- `status`: Item status
- `condition`: excellent, good, fair, poor, damaged
- `availability`: available, checked_out, reserved, reference, lost, damaged

## Role-Based Access Control

### Patron Access
- Collections: public and restricted only
- Items: available and reference items from accessible collections

### Librarian Access
- Collections: all collections regardless of access level
- Items: all items regardless of status or availability

## Frontend Integration

### Simple Search Form
```html
<form method="GET" action="/search">
  <input name="q" type="text" placeholder="Search...">
  <select name="type">
    <option value="universal">All</option>
    <option value="collections">Collections</option>
    <option value="items">Items</option>
  </select>
  <button type="submit">Search</button>
</form>
```

### AJAX Search
```javascript
fetch('/api/search?q=' + encodeURIComponent(query))
  .then(response => response.json())
  .then(data => {
    console.log('Results:', data.results);
  });
```

### Autocomplete
```javascript
fetch('/search/suggestions?q=' + encodeURIComponent(query))
  .then(response => response.json())
  .then(data => {
    displaySuggestions(data.suggestions);
  });
```

## Performance Considerations

1. **Indexing**: Ensure database indexes on searchable fields:
   - `collections.title`
   - `collections.description`
   - `items.item_code`
   - `items.inventory_code`
   - `creators.name`

2. **Query Optimization**: 
   - Use `LIMIT` for suggestion queries
   - Implement proper pagination
   - Consider full-text search for large datasets

3. **Caching**: Consider caching popular search queries

## Database Schema Requirements

The search functionality requires the following table relationships:
- Collections with creators, resource templates, and fields
- Items linked to collections
- Users with roles for access control
- Field values for extended metadata search

## Customization

### Adding New Search Fields
1. Update the search query builders in `lib/voile/schema/search.ex`
2. Add form fields to the advanced search template
3. Update the controller parameter handling

### Custom Search Logic
Extend the `Search` module with custom functions:

```elixir
defmodule Voile.Schema.Search do
  # ... existing functions ...
  
  def search_by_isbn(isbn, user_role) do
    # Custom ISBN search logic
  end
end
```

## Testing

Run the search tests:
```bash
mix test test/voile/schema/search_test.exs
mix test test/voile_web/controllers/search_controller_test.exs
```

## Future Enhancements

1. **Full-Text Search**: Implement PostgreSQL full-text search for better performance
2. **Search Analytics**: Track popular search terms and results
3. **Saved Searches**: Allow users to save and reuse complex searches
4. **Search Filters**: Add date ranges, language filters, and more
5. **Fuzzy Search**: Implement approximate string matching for typos
6. **Search Export**: Allow exporting search results to various formats
