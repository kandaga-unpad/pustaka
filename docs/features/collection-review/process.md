# Collection Review Process

## Overview

The collection review process allows librarians to submit collections for approval, and authorized reviewers (super_admin, admin, editor) can examine and approve or reject those submissions.

## User Roles

### Librarians

- Can create collections with status "draft" or "pending"
- When status is set to "pending", the collection is submitted for review
- Cannot directly publish collections (unless they are super_admin, admin, or editor)
- Will receive feedback if their collection is rejected

### Reviewers (super_admin, admin, editor)

- Can review all pending collections
- Can approve collections (changes status to "published")
- Can reject collections (sends back to "draft" with feedback)
- Have access to the Review page at `/manage/catalog/collections/review`

## Collection Status Flow

```
draft → pending → published (approved by reviewer)
         ↓
       draft (rejected by reviewer)
```

**Statuses:**

- `draft` - Work in progress, not yet submitted
- `pending` - Submitted for review, awaiting approval
- `published` - Approved and visible to public
- `archived` - No longer active

## How It Works

### For Librarians

1. **Create a Collection**: Navigate to Collections → New Collection
2. **Fill in Details**: Complete all required fields (title, description, creator, etc.)
3. **Submit for Review**:
   - Save the collection with status "pending"
   - The collection is now in the review queue
4. **Wait for Review**: Reviewers will examine the collection
5. **If Approved**: Collection status changes to "published" and becomes visible
6. **If Rejected**: Collection returns to "draft" status with reviewer notes explaining what needs to be fixed

### For Reviewers

1. **Access Review Page**:

   - Click the "Review" button in the Collections index (shows badge with pending count)
   - Or navigate to `/manage/catalog/collections/review`

2. **Review Pending Collections**:

   - See list of all collections with "pending" status
   - View collection details including:
     - Title, description, and thumbnail
     - Creator/author information
     - Resource type and node/location
     - Number of items in collection
     - Who submitted it and when

3. **Approve a Collection**:

   - Click the green checkmark icon
   - Optionally add approval notes
   - Click "Approve & Publish"
   - Collection status changes to "published"

4. **Reject a Collection**:
   - Click the red X icon
   - **Required**: Provide detailed rejection reason
   - Click "Reject Collection"
   - Collection returns to "draft" status
   - Librarian can see the rejection reason and make corrections

## Key Features

### Review Page Features

- **Pagination**: Handle large numbers of pending collections
- **Quick Actions**: Approve or reject directly from the list
- **Detailed View**: Click eye icon to see full collection details
- **Badge Counter**: Review button shows number of pending collections
- **Confirmation Modals**: Prevent accidental approvals/rejections

### Security & Permissions

- Only users with roles `super_admin`, `admin`, or `editor` can access review page
- Review functions check collection status (must be "pending")
- Unauthorized users are redirected with error message

### Audit Trail

The system tracks:

- Who submitted the collection (`created_by_id`)
- When it was submitted (`inserted_at`)
- Review action (approve/reject)
- Review notes/reasons
- Timestamp of review action

## Routes

- **Review Index**: `/manage/catalog/collections/review`
- **Review Specific**: `/manage/catalog/collections/review/:id`
- **Collections Index**: `/manage/catalog/collections` (with Review button for authorized users)

## Implementation Files

### Backend (Context)

- **File**: `lib/voile/schema/catalog.ex`
- **Functions**:
  - `list_pending_collections()` - Get all pending collections
  - `list_pending_collections_paginated(page, per_page)` (supports search, filters and optional `sort_order` argument) - Paginated pending list
  - `approve_collection(collection, reviewer_user, notes)` - Approve collection (publishes and sets all contained items to available)
  - `reject_collection(collection, reviewer_user, reason)` - Reject collection
  - `count_pending_collections()` - Count pending collections

### Frontend (LiveView)

- **LiveView**: `lib/voile_web/live/dashboard/catalog/collection_live/review.ex`
- **Template**: `lib/voile_web/live/dashboard/catalog/collection_live/review.html.heex`
- **Routes**: Defined in `lib/voile_web/router.ex` under `/collections` scope

### UI Enhancements

- **Collections Index**: Shows "Review" button with badge counter for reviewers
- **File**: `lib/voile_web/live/dashboard/catalog/collection_live/index.ex` and `.html.heex`

## Usage Example

### Librarian Workflow

```elixir
# In the collection form, librarian selects status "pending"
collection_params = %{
  title: "New Book Collection",
  description: "A collection of classic literature",
  status: "pending",  # Submits for review
  # ... other fields
}

# Collection is saved and appears in review queue
```

### Reviewer Workflow

```elixir
# Navigate to review page
# Click approve button
Catalog.approve_collection(collection, current_user, "Great collection!")
# => {:ok, %Collection{status: "published"}}

# Or reject with reason
Catalog.reject_collection(collection, current_user, "Missing required metadata fields")
# => {:ok, %Collection{status: "draft"}}
```

## Future Enhancements

### Recommended Database Migration

Add review tracking fields to collections table:

```elixir
alter table(:collections) do
  add :reviewed_at, :utc_datetime
  add :reviewed_by_id, references(:users, type: :binary_id)
  add :review_notes, :text
end
```

### Potential Features

- Email notifications when collection is approved/rejected
- Review history/changelog
- Bulk approve/reject operations
- Filter/search within pending collections
- Review statistics dashboard
- Comment threads for reviewer-librarian communication
- Draft auto-save for librarians
- Review assignment to specific reviewers

## Troubleshooting

### Issue: Review button not showing

**Solution**: Check user role. Only `super_admin`, `admin`, and `editor` roles can see the review button.

### Issue: Cannot approve/reject collection

**Solution**:

1. Verify collection status is "pending"
2. Check user has correct role
3. For rejection, ensure reason is provided (required field)

### Issue: Pending count shows 0 but collections exist

**Solution**: Check collections table - ensure status is exactly "pending" (lowercase)

### Issue: After approval, collection not visible

**Solution**:

1. Check collection `access_level` field (should be "public" for public visibility)
2. Verify `status` changed to "published"
3. Check RBAC permissions if using collection-level permissions

## Best Practices

1. **For Librarians**:

   - Complete all fields before submitting for review
   - Double-check metadata accuracy
   - Include clear descriptions
   - Add proper thumbnails

2. **For Reviewers**:

   - Provide detailed rejection reasons
   - Be consistent in review criteria
   - Review promptly to avoid backlog
   - Add approval notes for audit trail

3. **For Administrators**:
   - Define clear submission guidelines
   - Train librarians on requirements
   - Monitor pending queue regularly
   - Review rejection patterns to improve training
