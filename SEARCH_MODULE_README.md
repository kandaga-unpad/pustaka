# Voile Search Module

A comprehensive search module for the Voile library management system, providing both librarian and patron search capabilities with dark mode support.

## Features

### Core Search Functionality
- **Universal Search**: Search across collections and items simultaneously
- **Advanced Search**: Field-specific search with filters
- **Role-based Access**: Different results for librarians vs patrons
- **Pagination**: Efficient handling of large result sets
- **Auto-suggestions**: Search autocomplete functionality

### Search Types
1. **Simple Search**: Quick text-based search across all fields
2. **Advanced Search**: Detailed search with specific field targeting
3. **API Search**: AJAX endpoints for dynamic search interfaces
4. **Live Search**: Real-time search with LiveView components

### User Interface
- **Dark Mode Support**: Full Phoenix 1.8 theme compatibility
- **Responsive Design**: Mobile-friendly search interfaces
- **Dashboard Widgets**: Search statistics and quick search components
- **Autocomplete**: Dynamic search suggestions

## Files Structure

```
lib/
├── voile/
│   ├── schema/
│   │   └── search.ex                    # Core search logic and queries
│   ├── utils/
│   │   └── search_helper.ex             # Search utilities and helpers
│   └── analytics/
│       └── search_analytics.ex          # Search analytics and tracking
├── voile_web/
│   ├── controllers/
│   │   ├── search_controller.ex         # HTTP search endpoints
│   │   └── search_html/
│   │       ├── index.html.heex          # Simple search interface
│   │       └── advanced.html.heex       # Advanced search interface
│   ├── components/
│   │   ├── search_widget.ex             # LiveView search component
│   │   ├── search_bar.ex                # Reusable search bar component
│   │   └── voile_dashboard_components.ex # Dashboard search widgets
│   └── live/
│       ├── search_live.ex               # LiveView search interface
│       └── search_dashboard_live.ex     # Search analytics dashboard
```

## Usage Examples

### 1. Basic Search Component

```heex
<.search_bar 
  placeholder="Search collections, items, authors..." 
  show_filters={true} 
  size="lg"
/>
```

### 2. Dashboard Search Widget

```heex
<.dashboard_search_widget />
```

### 3. Search Statistics Widget

```heex
<.search_stats_widget stats={@search_stats} />
```

### 4. API Search Request

```javascript
fetch('/api/search?q=phoenix&type=collections&page=1')
  .then(response => response.json())
  .then(data => console.log(data.results))
```

## Search Parameters

### Simple Search
- `q`: Search query string
- `type`: Filter type (`all`, `collections`, `items`)
- `page`: Page number for pagination

### Advanced Search
- `title`: Title field search
- `author`: Author field search
- `subject`: Subject field search
- `isbn`: ISBN field search
- `type`: Resource type filter
- `year_from`: Publication year start
- `year_to`: Publication year end
- `availability`: Availability status

## Role-based Access Control

### Librarian Access
- Full access to all collections and items
- Can see restricted and confidential materials
- Access to detailed item information
- Advanced search capabilities

### Patron Access
- Access to public collections only
- Limited item details
- Basic search functionality
- No access to internal system information

## Dark Mode Implementation

All search components support Phoenix 1.8 dark mode with consistent styling:

```css
/* Light mode */
bg-white text-gray-900 border-gray-300

/* Dark mode */
dark:bg-gray-700 dark:text-white dark:border-gray-600
```

## Search Analytics

The search module includes analytics tracking:

### Tracked Metrics
- Total searches per day
- Popular search queries
- Search trends by hour
- User search patterns
- Recent search activity

### Analytics API
```elixir
# Record a search
SearchAnalytics.record_search(query, user_id, metadata)

# Get dashboard stats
SearchAnalytics.get_search_stats()

# Get popular searches
SearchAnalytics.get_popular_searches(7, 10)

# Get search trends
SearchAnalytics.get_search_trends(7)
```

## Database Queries

### Search Collections
```elixir
Search.search_collections(query, user_role, opts)
```

### Search Items
```elixir
Search.search_items(query, user_role, opts)
```

### Universal Search
```elixir
Search.universal_search(query, user_role, opts)
```

### Advanced Search
```elixir
Search.advanced_search(params, user_role, opts)
```

## Configuration

### Search Results Per Page
```elixir
# Default pagination
%{
  page: 1,
  per_page: 20,
  collections_per_page: 10,
  items_per_page: 10
}
```

### Search Filters
```elixir
# Available filter types
["all", "collections", "items", "books", "articles", "media"]
```

## Routes

```elixir
# Web interface
get "/search", SearchController, :index
post "/search", SearchController, :index
get "/search/advanced", SearchController, :advanced
post "/search/advanced", SearchController, :advanced

# API endpoints
get "/api/search", SearchController, :api_search
get "/search/suggestions", SearchController, :suggestions

# LiveView interfaces
live "/search/live", SearchLive, :index
live "/search/dashboard", SearchDashboardLive, :index
```

## Performance Considerations

1. **Database Indexing**: Ensure proper indexes on searchable fields
2. **Query Optimization**: Use ILIKE with proper LIMIT clauses
3. **Caching**: Consider caching popular search results
4. **Pagination**: Always paginate large result sets
5. **Analytics Storage**: Use ETS for temporary analytics, consider database for persistence

## Security Features

1. **Query Sanitization**: All search inputs are sanitized
2. **Role-based Filtering**: Results filtered by user permissions
3. **XSS Protection**: All output is properly escaped
4. **SQL Injection Prevention**: All queries use parameterized statements

## Future Enhancements

1. **Full-text Search**: PostgreSQL full-text search capabilities
2. **Search Highlighting**: Highlight search terms in results
3. **Faceted Search**: Category-based search refinement
4. **Search History**: User search history tracking
5. **Search Recommendations**: ML-based search suggestions
6. **Elasticsearch Integration**: Advanced search capabilities
7. **Search API Rate Limiting**: API usage controls

## Testing

Run search module tests:
```bash
mix test test/voile/schema/search_test.exs
mix test test/voile_web/controllers/search_controller_test.exs
mix test test/voile_web/live/search_live_test.exs
```

## Contributing

When contributing to the search module:

1. Maintain role-based access patterns
2. Follow dark mode styling conventions
3. Update search analytics for new search types
4. Add appropriate tests for new functionality
5. Document any new search parameters or filters

## Dependencies

- Phoenix Framework 1.8+
- Phoenix LiveView
- Ecto and PostgreSQL
- TailwindCSS with dark mode support
- Heroicons for UI icons
