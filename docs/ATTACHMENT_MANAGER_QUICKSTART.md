# Attachment Manager - Quick Start Guide

## Access the Manager

Navigate to: **`/manage/catalog/attachments`**

Or from the dashboard menu: **Catalog → Attachments**

## Main Interface Overview

### Statistics Dashboard (Top)
Four cards showing:
- **Total Attachments**: All attachments in system
- **Public**: Publicly accessible
- **Limited**: Role or user-restricted  
- **Restricted**: Super admin only

### Search & Filter Bar
- **Search box**: Find by filename or description
- **Access Level filter**: Public, Limited, or Restricted
- **File Type filter**: Document, Image, Video, etc.
- **Attachable Type filter**: Collections or Items
- **Clear button**: Remove all filters (shows when filters active)

### Attachment Table
Displays:
- File icon and name
- File type badge
- File size
- Access level badge (with role/user counts)
- Embargo dates (if set)
- Entity type (collection/item)
- Last updated by and when
- Action buttons

## Quick Actions

### 🔍 Search for Attachments
1. Type in search box
2. Press Enter or click search icon
3. Click X to clear search

### 🔒 Manage Access
1. Click lock icon on any attachment
2. Modal opens with access settings
3. Make changes (see below)
4. Close modal - changes save automatically

### ⬇️ Download Attachment
1. Click download icon
2. File downloads to your computer

### 🗑️ Delete Attachment
1. Click trash icon
2. Confirm deletion
3. Attachment permanently removed

## Managing Access Control

### Change Access Level

**In the access modal:**

1. **Select Access Level dropdown**:
   - **Public**: Anyone can access
   - **Limited**: Only roles/users you specify
   - **Restricted**: Super admin only

2. **Set Embargo Dates** (optional):
   - **Start Date**: Available after this date
   - **End Date**: Available until this date
   - Leave blank for no embargo

3. Click **"Update Access Settings"** button

### Grant Role-Based Access (Limited only)

**When access level is "Limited":**

1. Scroll to **"Role-Based Access"** section
2. Check boxes next to roles that should have access:
   - ☑️ staff
   - ☑️ researcher
   - ☐ guest
3. Changes apply immediately (no save button)
4. Green badges show active roles

### Grant User-Specific Access (Limited only)

**When access level is "Limited":**

1. Scroll to **"User-Specific Access"** section
2. Type user email or name in search box
3. Wait for results (appears below search)
4. Click **"Add"** button next to user
5. User appears in allowed users list
6. Click **"Remove"** to revoke access

## Common Scenarios

### Scenario 1: Make Document Staff-Only
```
1. Find document in list
2. Click 🔒 (lock icon)
3. Select "Limited" from dropdown
4. Check "staff" role
5. Click "Update Access Settings"
✓ Done! Only staff can access now
```

### Scenario 2: Embargo Until Publication
```
1. Find attachment
2. Click 🔒 (lock icon)
3. Keep "Public" selected
4. Set Start Date to publication date
5. Click "Update Access Settings"
✓ Done! Public after that date
```

### Scenario 3: Time-Limited Event Access
```
1. Find attachment
2. Click 🔒 (lock icon)
3. Keep "Public" selected
4. Set Start Date to event start
5. Set End Date to event end
6. Click "Update Access Settings"
✓ Done! Only available during event
```

### Scenario 4: Grant Guest Access
```
1. Find attachment
2. Click 🔒 (lock icon)
3. Select "Limited"
4. Search for guest email
5. Click "Add" on guest user
✓ Done! Guest can now access
```

### Scenario 5: Super Admin Only
```
1. Find attachment
2. Click 🔒 (lock icon)
3. Select "Restricted"
4. Click "Update Access Settings"
✓ Done! Only super admins can access
```

## Access Level Guide

| Level | Who Can Access | When to Use |
|-------|----------------|-------------|
| **Public** | Everyone, including anonymous users | General documents, public resources |
| **Limited** | Specific roles OR specific users | Internal docs, member resources |
| **Restricted** | Super admin only | Sensitive admin documents |

## Embargo Guide

| Setup | Result | Use Case |
|-------|--------|----------|
| **Start Date only** | Available AFTER that date | Future publications |
| **End Date only** | Available UNTIL that date | Temporary materials |
| **Both dates** | Available BETWEEN dates | Event-specific content |
| **No dates** | Available according to access level | Normal documents |

## Tips & Tricks

### 💡 Filter Combinations
Combine filters for powerful searches:
- Limited + Document = All restricted docs
- Collection + Staff-only = Collection materials for staff
- Under embargo = Set start date in future

### 💡 Quick Stats
Top cards update in real-time:
- See immediate impact of changes
- Spot trends in access patterns

### 💡 Search Tips
Search includes:
- Original filename
- System filename  
- Description field
- Partial matches work

### 💡 Batch Changes
To update multiple files:
1. Filter to find similar files
2. Update each one's access
3. Use same roles/settings for consistency

## Keyboard Shortcuts

- **Tab**: Navigate between filters
- **Enter**: Submit search
- **Esc**: Close modal

## Understanding the Icons

| Icon | Meaning |
|------|---------|
| 🔒 | Manage access control |
| ⬇️ | Download file |
| 🗑️ | Delete attachment |
| 🔍 | Search |
| ✖️ | Clear/Close |
| ℹ️ | Information |
| ✓ | Success/Active |

## Access Summary Panel

At bottom of access modal, shows:
- Current access level
- Embargo status
- Number of allowed roles
- Number of allowed users
- Who last changed settings
- When they changed them

Use this to verify your changes!

## Troubleshooting

### Can't see attachments?
- Check you have `attachments.read` permission
- Try clearing filters
- Contact administrator

### Can't change access?
- Requires `attachments.update` permission
- Contact administrator

### User search not working?
- Type at least 2 characters
- Wait for debounce (300ms)
- Check user exists in system

### Embargo not working?
- Check dates are in correct order
- Start date must be before end date
- Times are in UTC

### Changes not saving?
- Check for validation errors (red text)
- Ensure dates are valid
- Check internet connection

## Need Help?

1. **Check this guide** - Most answers are here
2. **Review full documentation** - See `docs/ATTACHMENT_LIVEVIEW_GUIDE.md`
3. **Ask administrator** - They can help with permissions
4. **Report bugs** - Contact development team

## Best Practices

### ✅ DO
- Start with public, restrict only if needed
- Use roles over individual users (scales better)
- Document why you restricted access (use description)
- Test access from different user accounts
- Set embargos with timezones in mind

### ❌ DON'T
- Restrict everything by default
- Give everyone individual access (use roles)
- Set overlapping embargos (confusing)
- Delete attachments that might be referenced
- Change access without notifying affected users

## Quick Reference Card

```
┌─────────────────────────────────────────┐
│     ATTACHMENT MANAGER QUICK REF        │
├─────────────────────────────────────────┤
│ SEARCH:   Type & Enter                  │
│ FILTER:   Use dropdowns                 │
│ ACCESS:   🔒 icon → Modal               │
│ DOWNLOAD: ⬇️ icon                       │
│ DELETE:   🗑️ icon → Confirm            │
├─────────────────────────────────────────┤
│ ACCESS LEVELS:                          │
│  • Public    = Everyone                 │
│  • Limited   = Roles/Users              │
│  • Restricted = Super admin only        │
├─────────────────────────────────────────┤
│ EMBARGO:                                │
│  • Start = Available after              │
│  • End   = Available until              │
│  • Both  = Available between            │
└─────────────────────────────────────────┘
```

---

**Pro Tip**: Bookmark this page for quick reference! 📑
