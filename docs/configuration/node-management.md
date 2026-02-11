# Node/Unit Management LiveView

## Overview
A beautiful LiveView interface for managing system nodes (organizational units, library branches, departments, etc.) with image upload capabilities.

## Features

### 1. **Visual Node Management**
- Grid-based card layout displaying all nodes with:
  - Node image/logo with fallback icon
  - Node name, abbreviation badge, and description
  - Quick action buttons (Edit/Delete)
  - Responsive design (1-3 columns based on screen size)

### 2. **Statistics Dashboard**
- Total Nodes count
- Nodes with images count
- Nodes with abbreviations count
- Beautiful stat cards with icons

### 3. **Image Upload System**
- Drag-and-drop file upload
- Click to upload interface
- Real-time upload progress bar
- Image preview before submission
- Ability to remove uploaded images
- Support for JPG, PNG, WEBP formats
- Max file size: 5MB
- Uses `Client.Storage` module for flexible storage (S3 or local)

### 4. **CRUD Operations**
- **Create**: Add new nodes with all fields and image
- **Read**: View all nodes in an organized grid
- **Update**: Edit existing nodes and update images
- **Delete**: Remove nodes with confirmation and automatic image cleanup

### 5. **User Experience**
- Modal-based forms for create/edit operations
- Real-time form validation
- Flash messages for success/error states
- Empty state with helpful prompts
- Responsive design for all screen sizes
- Dark mode support

## Technical Implementation

### File Structure
```
lib/voile_web/live/dashboard/settings/system_node_live.ex
lib/voile/schema/system/node.ex (updated)
lib/voile/schema/system.ex (context)
```

### Key Components

#### LiveView Module
- `mount/3`: Initializes socket with nodes data and upload configuration
- `handle_event/3`: Handles all user interactions (CRUD, image upload, form management)
- `handle_progress/3`: Manages file upload progress and storage

#### Upload Configuration
```elixir
allow_upload(:node_image,
  accept: ~w(.jpg .jpeg .png .webp),
  max_entries: 1,
  max_file_size: 5_000_000,
  auto_upload: true,
  progress: &handle_progress/3
)
```

#### Storage Integration
- Uses `Client.Storage.upload/2` for flexible storage
- Uploads to "node_images" folder
- Automatic cleanup on delete/update
- Supports both S3 and local filesystem

### Schema Updates
Updated `Voile.Schema.System.Node` changeset to include:
- `:name` (required)
- `:abbr` (required)
- `:image` (optional)
- `:description` (optional)

### Routes
```elixir
live "/manage/settings/nodes", Dashboard.Settings.SystemNodeLive, :index
```

### Authorization
- Requires `"system.settings"` permission
- Integrated with existing auth system

## UI/UX Design

### Color Scheme
- Primary actions: Voile primary color
- Success: Green for create/update
- Danger: Red for delete
- Info: Blue for statistics
- Neutral: Gray for secondary elements

### Layout
- Left sidebar: Settings navigation (shared component)
- Main content: Stats + nodes grid
- Modal overlay: Create/edit forms

### Responsive Breakpoints
- Mobile: 1 column
- Tablet: 2 columns
- Desktop: 3 columns

## Usage Examples

### Accessing the Page
Navigate to `/manage/settings/nodes` or click "Nodes / Units" in the settings sidebar.

### Creating a Node
1. Click "Add Node" button
2. Fill in required fields (Name, Abbreviation)
3. Optionally add description
4. Optionally upload an image (drag-and-drop or click)
5. Click "Create Node"

### Editing a Node
1. Click "Edit" button on any node card
2. Modify fields as needed
3. Upload new image or remove existing one
4. Click "Update Node"

### Deleting a Node
1. Click "Delete" button on any node card
2. Confirm deletion in browser dialog
3. Node and associated image are removed

## Future Enhancements
- Bulk operations (delete multiple nodes)
- Search and filter functionality
- Sort options (by name, date created, etc.)
- Node association with users and collections
- Export/import nodes as CSV
- Node hierarchy (parent/child relationships)
- Custom fields per node

## References
- Based on `HolidayLive` design patterns
- Uses Phoenix LiveView upload system
- Integrates with existing `Client.Storage` module
- Follows Phoenix 1.8 guidelines from AGENTS.md
