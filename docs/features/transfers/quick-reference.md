# Transfer Location - Quick Reference Card

## 🎯 Quick Access

| Action | URL | Permission Required |
|--------|-----|---------------------|
| View all transfers | `/manage/transfers` | `transfer_requests.read` |
| View transfer detail | `/manage/transfers/:id` | `transfer_requests.read` |
| Create transfer | Click "Transfer Location" on item card | `transfer_requests.create` |

## 👥 User Roles

### As a Requester
- Click "Transfer Location" button on any item
- Fill out: target node, location, reason
- Submit and wait for approval
- Can delete your own pending requests

### As a Reviewer (Target Node Librarian)
- Check `/manage/transfers` for pending requests
- See requests filtered for your node by default
- Review details and approve/deny
- Add notes explaining your decision

## 📋 Transfer States

| State | Description | Next Actions |
|-------|-------------|--------------|
| **Pending** ⏳ | Awaiting review | Can be reviewed or deleted by requester |
| **Approved** ✅ | Transfer completed | Item moved, cannot be undone |
| **Denied** ❌ | Transfer rejected | Item unchanged, cannot be undone |
| **Cancelled** 🚫 | Requester withdrew | No action taken |

## 🔑 Permissions Quick Guide

```
transfer_requests.create  → Can request transfers
transfer_requests.read    → Can view transfers
transfer_requests.update  → Can edit transfers
transfer_requests.delete  → Can delete own pending requests
transfer_requests.review  → Can approve/deny transfers
```

**Default Role Access:**
- `super_admin` → All permissions
- `librarian` → All permissions
- Other roles → No access (can be granted)

## ⚡ Common Tasks

### Request a Transfer
1. Navigate to collection show page
2. Find item → Click "Transfer Location"
3. Select target node and location
4. Write reason → Submit

### Review a Transfer
1. Go to `/manage/transfers`
2. Click on pending request
3. Review details
4. Add notes (optional)
5. Click "Approve" or "Deny"

### Check Transfer History
- View item's past transfers in the system
- Use filters to find specific transfers
- Search by item, node, or status

### Cancel Your Request
1. Go to `/manage/transfers`
2. Find your pending request
3. Click "Delete"
4. Confirm deletion

## 🎨 Status Badge Colors

- 🟡 **Pending** - Yellow badge
- 🟢 **Approved** - Green badge
- 🔴 **Denied** - Red badge
- ⚪ **Cancelled** - Gray badge

## 🔍 Filters Available

**By Status:**
- All Statuses
- Pending
- Approved
- Denied
- Cancelled

**By Node:**
- All Nodes
- [Your Nodes]

## ⚠️ Important Notes

- ✅ Transfers execute immediately upon approval
- ✅ Item location updates are permanent
- ✅ Only target node librarians can review
- ✅ Full audit trail is maintained
- ⚠️ Cannot undo approved/denied transfers
- ⚠️ Can only delete your own pending requests

## 🐛 Troubleshooting

**Problem:** Cannot see transfer button
- **Check:** You need `transfer_requests.create` permission

**Problem:** Cannot review transfer
- **Check:** Your node must match the target node
- **Check:** You need `transfer_requests.review` permission

**Problem:** Cannot delete transfer request
- **Check:** Status must be "pending"
- **Check:** You must be the requester

**Problem:** Item not moved after approval
- **Check:** Transfer status shows "approved"
- **Check:** Completion timestamp is set
- **Verify:** Item location was updated in database

## 📞 Need Help?

See full documentation:
 