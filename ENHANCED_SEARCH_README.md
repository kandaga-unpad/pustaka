# Enhanced Search Component with Immediate Feedback

This document explains how to implement and use the enhanced search component with immediate feedback functionality, similar to Google's search suggestions.

## Features

✨ **Immediate Feedback**: Shows search suggestions as the user types
🎯 **GLAM Type Filtering**: Filter by Gallery, Library, Archive, Museum, or All
🔍 **Text Highlighting**: Highlights search terms in results
⌨️ **Keyboard Navigation**: Support for arrow keys, Enter, and Esc
🎨 **Visual Indicators**: Color-coded GLAM type badges and status indicators
📱 **Responsive Design**: Works on mobile and desktop

## Components Overview

### 1. Main Search Component (`main_search/1`)

The primary search interface with tabs and autocomplete functionality.

**New Attributes:**

- `search_results`: List of collections for suggestions
- `show_suggestions`: Boolean to control dropdown visibility
- `loading`: Boolean to show loading state

### 2. Search Suggestions (`search_suggestions/1`)

Full-featured suggestion dropdown with rich collection information.

### 3. Compact Search Suggestions (`compact_search_suggestions/1`)

Lightweight suggestion dropdown for better performance.

### 4. GLAM Collection Card (`glam_collection_card/1`)

Enhanced collection card with GLAM type support.

## Implementation Guide

### Step 1: Update Your LiveView

```elixir
defmodule YourApp.SearchLive do
  use YourAppWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:search_query, "")
     |> assign(:current_glam_type, "quick")
     |> assign(:search_results, [])
     |> assign(:show_suggestions, false)
     |> assign(:loading, false)}
  end

  # Handle search input changes
  def handle_event("search_change", %{"q" => query, "glam_type" => glam_type}, socket) do
    if String.length(query) >= 2 do
      send(self(), {:perform_autocomplete, query, glam_type})

      {:noreply,
       socket
       |> assign(:search_query, query)
       |> assign(:current_glam_type, glam_type)
       |> assign(:loading, true)
       |> assign(:show_suggestions, true)}
    else
      {:noreply,
       socket
       |> assign(:search_query, query)
       |> assign(:search_results, [])
       |> assign(:show_suggestions, false)}
    end
  end

  # Handle autocomplete search
  def handle_info({:perform_autocomplete, query, glam_type}, socket) do
    results = search_collections(query, glam_type, limit: 8)

    {:noreply,
     socket
     |> assign(:search_results, results)
     |> assign(:loading, false)}
  end
end
```

### Step 2: Create Database Query Functions

```elixir
defmodule YourApp.Search do
  import Ecto.Query
  alias YourApp.Repo
  alias YourApp.Schema.Collection

  def search_collections(query, glam_type, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)

    Collection
    |> join(:left, [c], rc in assoc(c, :resource_class))
    |> join(:left, [c], creator in assoc(c, :mst_creator))
    |> preload([c, rc, creator], [resource_class: rc, mst_creator: creator, items: :items])
    |> filter_by_glam_type(glam_type)
    |> filter_by_search_query(query)
    |> where([c], c.status == "published")
    |> limit(^limit)
    |> order_by([c], desc: c.updated_at)
    |> Repo.all()
  end

  defp filter_by_glam_type(query, "quick"), do: query

  defp filter_by_glam_type(query, glam_type) do
    where(query, [c, rc], rc.glam_type == ^glam_type)
  end

  defp filter_by_search_query(query, search_query) when search_query in [nil, ""], do: query

  defp filter_by_search_query(query, search_query) do
    search_term = "%#{search_query}%"

    where(query, [c],
      ilike(c.title, ^search_term) or
      ilike(c.description, ^search_term)
    )
  end
end
```

### Step 3: Update Your Template

```heex
<VoileComponents.main_search
  current_glam_type={@current_glam_type}
  search_query={@search_query}
  search_results={@search_results}
  show_suggestions={@show_suggestions}
  loading={@loading}
  live_action={@live_action}
/>
```

## Database Schema Requirements

Ensure your ResourceClass schema includes the `glam_type` field:

```elixir
defmodule YourApp.Schema.Metadata.ResourceClass do
  use Ecto.Schema
  import Ecto.Changeset

  schema "resource_class" do
    field :label, :string
    field :local_name, :string
    field :information, :string
    field :glam_type, :string  # Required for search functionality

    timestamps()
  end

  def changeset(resource_class, attrs) do
    resource_class
    |> cast(attrs, [:label, :local_name, :information, :glam_type])
    |> validate_required([:label, :local_name, :glam_type])
    |> validate_inclusion(:glam_type, ["Gallery", "Library", "Archive", "Museum"])
  end
end
```

## Performance Optimization Tips

1. **Database Indexes**: Add indexes on frequently searched fields

```sql
CREATE INDEX idx_collections_title_search ON collections USING gin(to_tsvector('english', title));
CREATE INDEX idx_collections_glam_type ON resource_class(glam_type);
```

2. **Debouncing**: The component includes 300ms debouncing by default

3. **Result Limiting**: Limit autocomplete results to 6-8 items for better UX

4. **Caching**: Consider caching popular search results

## Styling Classes

The component uses these CSS classes that should be defined in your app.css:

```css
.input-main-search {
  @apply w-full px-4 py-3 text-sm border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500 dark:border-gray-600 dark:bg-gray-700 dark:text-white;
}

.search-tab {
  @apply flex border border-gray-200 dark:border-gray-600 rounded-t-lg overflow-hidden;
}

.search-tab-item {
  @apply flex items-center px-4 py-2 text-sm font-medium text-gray-700 dark:text-gray-300 bg-white dark:bg-gray-800 hover:bg-gray-50 dark:hover:bg-gray-700 border-r border-gray-200 dark:border-gray-600 last:border-r-0 transition-colors;
}

.active-tab-item {
  @apply bg-violet-200 dark:bg-gray-600 text-violet-800 dark:text-white;
}

.default-btn {
  @apply px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 focus:ring-2 focus:ring-blue-500 transition-colors;
}
```

## Event Handlers Summary

| Event               | Description                       | Purpose                  |
| ------------------- | --------------------------------- | ------------------------ |
| `search_change`     | Input value changes               | Trigger autocomplete     |
| `search`            | Form submission                   | Perform full search      |
| `select_collection` | Collection clicked in suggestions | Navigate to collection   |
| `perform_search`    | "Search all" clicked              | Navigate to full results |
| `show_suggestions`  | Input focused                     | Show dropdown            |
| `hide_suggestions`  | Input blurred                     | Hide dropdown            |

## Keyboard Navigation

- `↑/↓`: Navigate through suggestions
- `Enter`: Select highlighted item or perform search
- `Esc`: Close suggestions dropdown
- `Tab`: Navigate between GLAM type tabs

This enhanced search component provides a modern, responsive search experience that will significantly improve user engagement with your GLAM collections! 🚀
