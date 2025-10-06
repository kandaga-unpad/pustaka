# Catalog Module Family Documentation

## Overview

The **Catalog** module family (`VoileWeb.Dashboard.Catalog.*`) manages the library's catalog system, including collections and items. This is the core content management system for organizing and managing library materials.

## Architecture

```
VoileWeb.Dashboard.Catalog
├── Index                          # Catalog dashboard/overview
├── CollectionLive
│   ├── Index                      # List/manage collections
│   ├── Show                       # View collection details
│   ├── Attachments                # Manage collection attachments
│   ├── FormComponent              # Collection create/edit form
│   ├── FormCollectionHelper       # Helper functions for forms
│   └── TreeComponents             # Tree view components
├── ItemLive
│   ├── Index                      # List/manage items
│   ├── Show                       # View item details
│   └── FormComponent              # Item create/edit form
└── Components
    └── AttachmentUpload           # File upload component
```

## Module Descriptions

### VoileWeb.Dashboard.Catalog.Index

**Purpose:** Main catalog dashboard showing statistics and overview

**Route:** `/manage/catalog`

**Features:**
- Display total collections count across all nodes
- Display total items count
- Show statistics with colored gradient cards
- Quick navigation to collections and items
- Node-based color coding for visual distinction
- Loading states with spinners

**Key Functions:**
- Displays catalog overview statistics
- Provides quick access to collections and items management

**Assigns:**
- `@count_collections` - Total number of collections
- `@count_items` - Total number of items
- `@current_scope.user` - Current authenticated user

---

### VoileWeb.Dashboard.Catalog.CollectionLive.Index

**Purpose:** List and manage all collections with pagination and tree view

**Route:** `/manage/catalog/collections`

**Features:**
- **List View:** Paginated table of collections
- **Tree View:** Hierarchical tree structure of collections
- **Create Collection:** Modal-based multi-step form
- **Edit Collection:** Inline editing capabilities
- **Search Collections:** Filter by various criteria
- **View Modes:** Toggle between list and tree views
- **Pagination:** Navigate through collection pages

**Key Functions:**
- `mount/3` - Initialize collections list, tree view, and form data
- `handle_params/3` - Handle route actions (:index, :new, :edit)
- `handle_info/2` - Update streams when collections are saved
- `handle_event/3` - Handle pagination, search, view mode toggle

**Assigns:**
- `@streams.collections` - Stream of collections for list view
- `@tree_collections` - Collections organized in tree structure (limited to 50)
- `@view_mode` - Current view mode ("list" or "tree")
- `@collection_type` - Available resource classes
- `@collection_properties` - Metadata properties by vocabulary
- `@creator` - List of creators
- `@node_location` - Available nodes
- `@page` - Current page number
- `@total_pages` - Total number of pages
- `@step` - Current step in multi-step form
- `@time_identifier` - Unique timestamp for cache busting

**Events:**
- `paginate` - Navigate between pages
- `toggle_view` - Switch between list and tree view
- `search` - Filter collections

---

### VoileWeb.Dashboard.Catalog.CollectionLive.Show

**Purpose:** Display detailed information about a specific collection

**Route:** `/manage/catalog/collections/:id`

**Features:**
- View collection metadata and properties
- Display collection hierarchy (parent/children)
- Show all items in the collection
- Edit collection details via modal
- Manage collection attachments
- Export collection data
- Delete collection (with confirmation)

**Key Functions:**
- `mount/3` - Load collection with all associations
- `handle_params/3` - Handle show and edit actions
- `handle_event/3` - Handle delete, export, and other actions

**Assigns:**
- `@collection` - Current collection with preloaded associations
- `@items` - Items belonging to this collection
- `@parent_collection` - Parent collection if exists
- `@child_collections` - Child collections

**Events:**
- `delete_collection` - Delete the collection
- `export_collection` - Export collection data
- `manage_attachments` - Navigate to attachments management

---

### VoileWeb.Dashboard.Catalog.CollectionLive.Attachments

**Purpose:** Manage file attachments for collections

**Route:** `/manage/catalog/collections/:id/attachments`

**Features:**
- Upload multiple files
- View existing attachments
- Download attachments
- Delete attachments
- File type validation
- File size limits

**Key Functions:**
- `mount/3` - Load collection and existing attachments
- `handle_event/3` - Handle upload, delete, download actions

---

### VoileWeb.Dashboard.Catalog.CollectionLive.FormComponent

**Purpose:** Reusable live component for creating and editing collections

**Type:** LiveComponent

**Features:**
- **Multi-step Form:**
  - Step 1: Basic Information (title, description, type)
  - Step 2: Metadata Fields (dynamic based on resource class)
  - Step 3: Additional Settings (creator, node, visibility)
- Form validation at each step
- Dynamic field generation based on resource template
- Creator search functionality
- Parent collection selection
- Node assignment

**Key Functions:**
- `update/2` - Initialize component with collection data
- `handle_event("validate", ...)` - Validate form inputs
- `handle_event("save", ...)` - Save collection (create or update)
- `handle_event("next_step", ...)` - Navigate to next form step
- `handle_event("prev_step", ...)` - Navigate to previous form step

**Assigns:**
- `@form` - Collection form changeset
- `@collection` - Collection being edited or created
- `@action` - `:new` or `:edit`
- `@step` - Current form step (1, 2, or 3)
- `@collection_type` - Available resource classes
- `@creator` - Available creators
- `@node_location` - Available nodes

---

### VoileWeb.Dashboard.Catalog.CollectionLive.FormCollectionHelper

**Purpose:** Helper functions for collection form processing

**Functions:**
- Field parsing and validation
- Metadata field processing
- Form step navigation logic
- Data transformation utilities

---

### VoileWeb.Dashboard.Catalog.CollectionLive.TreeComponents

**Purpose:** Components for rendering collection tree hierarchy

**Components:**
- `collection_tree/1` - Renders hierarchical tree view
- `tree_node/1` - Individual tree node component
- `tree_children/1` - Recursively renders child nodes

**Features:**
- Collapsible/expandable nodes
- Visual hierarchy with indentation
- Click to navigate to collection details
- Color-coded by collection type
- Item count display per collection

---

### VoileWeb.Dashboard.Catalog.ItemLive.Index

**Purpose:** List and manage all catalog items

**Route:** `/manage/catalog/items`

**Features:**
- Paginated list of items
- Create new items
- Edit existing items
- Delete items
- Quick filters
- Search functionality
- Item code display
- Collection association display

**Key Functions:**
- `mount/3` - Initialize items list with pagination
- `handle_params/3` - Handle route actions
- `handle_event("delete", ...)` - Delete item
- `handle_event("paginate", ...)` - Navigate pages

**Assigns:**
- `@streams.items` - Stream of items
- `@page` - Current page number
- `@total_pages` - Total pages
- `@page_title` - Page title based on action

**Events:**
- `delete` - Delete an item
- `paginate` - Change page

---

### VoileWeb.Dashboard.Catalog.ItemLive.Show

**Purpose:** Display detailed information about a specific item

**Route:** `/manage/catalog/items/:id`

**Features:**
- View all item metadata
- Display item location and status
- Show collection association
- Edit item details
- View circulation history
- Display item attachments
- Check availability status

**Key Functions:**
- `mount/3` - Load item with all associations
- `handle_params/3` - Handle show and edit actions

**Assigns:**
- `@item` - Current item with preloaded data
- `@collection` - Associated collection
- `@circulation_status` - Current availability status

---

### VoileWeb.Dashboard.Catalog.ItemLive.FormComponent

**Purpose:** Reusable live component for creating and editing items

**Type:** LiveComponent

**Features:**
- Item code assignment (manual or auto-generated)
- Collection selection
- Location assignment
- Status selection
- Copy information fields
- Classification data
- ISBN/ISSN fields
- Call number assignment

**Key Functions:**
- `update/2` - Initialize component
- `handle_event("validate", ...)` - Validate inputs
- `handle_event("save", ...)` - Save item
- `handle_event("generate_code", ...)` - Auto-generate item code

**Assigns:**
- `@form` - Item form changeset
- `@item` - Item being edited or created
- `@action` - `:new` or `:edit`
- `@collections` - Available collections
- `@locations` - Available locations
- `@statuses` - Available item statuses

---

### VoileWeb.Dashboard.Catalog.Components.AttachmentUpload

**Purpose:** Reusable component for file uploads

**Features:**
- Drag and drop interface
- Multiple file selection
- File type validation
- File size validation
- Upload progress indication
- Preview uploaded files
- Remove files before upload

## Routes Reference

```elixir
# Catalog Overview
GET  /manage/catalog                          # Dashboard.Catalog.Index

# Collections
GET  /manage/catalog/collections              # CollectionLive.Index :index
GET  /manage/catalog/collections/new          # CollectionLive.Index :new
GET  /manage/catalog/collections/:id/edit    # CollectionLive.Index :edit
GET  /manage/catalog/collections/:id          # CollectionLive.Show :show
GET  /manage/catalog/collections/:id/show/edit         # CollectionLive.Show :edit
GET  /manage/catalog/collections/:id/attachments      # CollectionLive.Attachments

# Items
GET  /manage/catalog/items                    # ItemLive.Index :index
GET  /manage/catalog/items/new                # ItemLive.Index :new
GET  /manage/catalog/items/:id/edit           # ItemLive.Index :edit
GET  /manage/catalog/items/:id                # ItemLive.Show :show
GET  /manage/catalog/items/:id/show/edit      # ItemLive.Show :edit
```

## Database Schema

### Collections

```elixir
schema "collections" do
  field :title, :string
  field :description, :text
  field :visibility, :string           # public, private, restricted
  field :is_published, :boolean
  field :published_at, :utc_datetime
  
  belongs_to :resource_class, ResourceClass
  belongs_to :resource_template, ResourceTemplate
  belongs_to :mst_creator, Creator
  belongs_to :node, Node
  belongs_to :parent, Collection
  
  has_many :collection_fields, CollectionField
  has_many :items, Item
  has_many :children, Collection, foreign_key: :parent_id
  
  timestamps()
end
```

### Items

```elixir
schema "items" do
  field :item_code, :string            # Unique identifier
  field :barcode, :string
  field :call_number, :string
  field :copy_number, :integer
  field :volume, :string
  field :edition, :string
  field :isbn, :string
  field :status, :string               # available, checked_out, lost, damaged
  field :location, :string
  field :notes, :text
  
  belongs_to :collection, Collection
  belongs_to :node, Node
  
  has_many :transactions, Transaction
  has_many :reservations, Reservation
  
  timestamps()
end
```

## Business Logic

### Collection Management

1. **Creation:**
   - Collections can be standalone or have a parent
   - Resource class determines available metadata fields
   - Node assignment for multi-node setups
   - Creator assignment for provenance

2. **Hierarchy:**
   - Collections support parent-child relationships
   - Tree depth is limited for performance (default: 50)
   - Children inherit certain properties from parents

3. **Visibility:**
   - Public: Visible to all users
   - Private: Visible only to staff
   - Restricted: Requires specific permissions

4. **Publishing:**
   - Collections can be draft or published
   - Published timestamp tracks when made public
   - Unpublishing removes from public catalog

### Item Management

1. **Item Codes:**
   - Must be unique across the system
   - Can be auto-generated or manually assigned
   - Used for tracking and identification

2. **Availability:**
   - Status determines if item can be checked out
   - Tracked through circulation system
   - Real-time availability updates

3. **Location:**
   - Physical location within library
   - Can be at different nodes
   - Tracked for retrieval

## View Modes

### List View (Collections)
- **Pros:** Easy filtering, sorting, pagination
- **Cons:** Doesn't show hierarchy clearly
- **Use Case:** Managing many collections, searching

### Tree View (Collections)
- **Pros:** Clear hierarchy visualization, drag-drop capable
- **Cons:** Performance issues with many collections
- **Use Case:** Understanding structure, reorganizing

## Performance Considerations

1. **Tree View Limit:** Limited to 50 collections to prevent performance issues
2. **Pagination:** Items and collections use pagination (default: 10-15 per page)
3. **Preloading:** Strategic preloading of associations to minimize queries
4. **Streaming:** Uses LiveView streams for efficient list updates
5. **Caching:** Time identifiers for cache busting on updates

## Common Workflows

### Creating a Collection

1. Navigate to `/manage/catalog/collections`
2. Click "New Collection"
3. **Step 1:** Enter title, description, select resource class
4. **Step 2:** Fill in metadata fields (based on resource template)
5. **Step 3:** Select creator, node, parent (if applicable)
6. Save collection
7. Optionally add attachments

### Creating an Item

1. Navigate to `/manage/catalog/items`
2. Click "New Item"
3. Select or search for collection
4. Enter item code (or generate automatically)
5. Set location and status
6. Fill in copy information (volume, edition, etc.)
7. Add classification data (call number, ISBN)
8. Save item

### Organizing Collections

1. Use tree view to see hierarchy
2. Drag and drop to reorganize (if enabled)
3. Edit parent assignment to move collections
4. Create new child collections as needed

## Integration Points

### With Circulation Module
- Items link to circulation transactions
- Availability status affects checkout
- Circulation history tracked per item

### With Metadata Module
- Collections use resource templates
- Dynamic fields based on resource class
- Metadata properties define available fields

### With Master Data
- Creators from master creator list
- Nodes from system configuration
- Locations from master location data

## Security Considerations

- Collection visibility controls access
- Item availability prevents unauthorized checkouts
- Permissions required for create/edit/delete operations
- Node-based access control for multi-tenant setups

## Testing Checklist

- [ ] Create collection with all fields
- [ ] Create child collection under parent
- [ ] Switch between list and tree view
- [ ] Create item with auto-generated code
- [ ] Create item with manual code
- [ ] Edit collection metadata
- [ ] Edit item details
- [ ] Delete empty collection
- [ ] Upload collection attachments
- [ ] Pagination works correctly
- [ ] Search filters collections/items
- [ ] Tree view renders hierarchy correctly
