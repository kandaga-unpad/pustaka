# Collection Review Quick Reference

## 🎯 Quick Access

**Review Page**: `/manage/catalog/collections/review`

**Who Can Review**: `super_admin`, `admin`, `editor` only

## ⚡ Quick Actions

### Submit for Review (Librarian)

1. Create/Edit Collection
2. Set Status = "pending"
3. Save

### Approve Collection (Reviewer)

1. Go to Review page
2. Click ✅ (green check)
3. Add notes (optional)
4. Confirm
   → Status changes to "published"

### Reject Collection (Reviewer)

1. Go to Review page
2. Click ❌ (red X)
3. Add reason (**required**)
4. Confirm
   → Status returns to "draft"

## 📊 Status Flow

```
draft → pending → published
         ↓
       draft (rejected)
```

## 🔑 Key Functions

```elixir
# Backend (lib/voile/schema/catalog.ex)
Catalog.list_pending_collections()
Catalog.list_pending_collections_paginated(page, per_page, user \ nil, search_query \ nil, filter_status \ nil, node_id \ nil, sort_order \ "asc")
Catalog.approve_collection(collection, reviewer, notes)  # publishes and marks items available
Catalog.reject_collection(collection, reviewer, reason)
Catalog.count_pending_collections()
```

## 🎨 UI Features

- **Badge Counter**: Shows pending count on Review button
- **Pagination**: 10 collections per page
- **Quick Actions**: View, Approve, Reject from list
- **Confirmation Modals**: Prevent accidents
- **Real-time Updates**: List refreshes after action

## ⚠️ Important Notes

- Rejection **requires** a reason
- Only "pending" collections can be reviewed
- Approval changes status to "published"
- Rejection sends back to "draft" with notes
- Unauthorized users are redirected

## 🔍 Troubleshooting

| Issue                     | Solution                                           |
| ------------------------- | -------------------------------------------------- |
| Review button not visible | Check user role (must be admin/editor/super_admin) |
| Can't approve/reject      | Verify collection status is "pending"              |
| Rejection fails           | Must provide reason (required field)               |
| Pending count wrong       | Check collection status is exactly "pending"       |

## 📁 Key Files

```
Backend:
  lib/voile/schema/catalog.ex

Frontend:
  lib/voile_web/live/dashboard/catalog/collection_live/review.ex
  lib/voile_web/live/dashboard/catalog/collection_live/review.html.heex
  lib/voile_web/live/dashboard/catalog/collection_live/index.ex

Routes:
  lib/voile_web/router.ex

Docs:
  docs/COLLECTION_REVIEW_PROCESS.md
  docs/COLLECTION_REVIEW_IMPLEMENTATION_SUMMARY.md
```

## 🚀 Next Steps

1. Test as librarian (create → submit)
2. Test as reviewer (approve/reject)
3. Consider adding email notifications
4. Add database migration for review tracking
5. Monitor pending queue regularly
