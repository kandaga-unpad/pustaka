# Stock Opname Quick Reference

## Quick Start

### For Super Admins

#### Creating a Session

1. Go to **Dashboard** → **Stock Opname** → **New Session**
2. Fill in:
   - Title and description
   - Select nodes (libraries/branches)
   - Choose collection types (book, journal, etc.)
   - Select scope:
     - **All**: Check all items matching nodes and types
     - **Collection**: Check items in specific collection
     - **Location**: Check items in specific location
3. Assign librarians who will scan items
4. Review estimated item count
5. Click **Create Session**

#### Starting a Session

1. Go to **Stock Opname** → Select session → **Start Session**
2. Librarians receive email notifications
3. Status changes to "In Progress"

#### Reviewing a Session

1. Wait for all librarians to complete their work
2. Click **Complete Session** (triggers missing detection)
3. Go to **Review** tab
4. Review:
   - Items with changes (before → after)
   - Missing items
   - Librarian work summary
5. Choose action:
   - **Approve**: Apply all changes
   - **Request Revision**: Send back with notes
   - **Reject**: Cancel without changes

### For Librarians

#### Scanning Items

1. Go to **Stock Opname** → Select assigned session → **Scan Items**
2. Scan or type item identifier:
   - Barcode
   - Inventory code
   - Item code
   - Legacy item code
3. If multiple matches appear, select the correct item
4. Review item details
5. Update if needed:
   - Status (available, borrowed, lost, etc.)
   - Condition (good, fair, poor, etc.)
   - Availability (available, not available)
   - Location
   - Add notes
6. Click **Check Item**
7. Repeat for all items
8. Click **Complete My Work** when done

## URL Paths

- **List Sessions**: `/manage/stock-opname`
- **New Session**: `/manage/stock-opname/new`
- **Session Details**: `/manage/stock-opname/:id`
- **Scan Items**: `/manage/stock-opname/:id/scan`
- **Review**: `/manage/stock-opname/:id/review`

## Session Statuses

| Status         | Description               | Actions Available                 |
| -------------- | ------------------------- | --------------------------------- |
| Draft          | Just created, not started | Start, Edit, Cancel               |
| In Progress    | Librarians scanning items | Scan, Complete (admin)            |
| Completed      | Ready for review          | Review, Request Revision          |
| Pending Review | Awaiting admin approval   | Approve, Reject, Request Revision |
| Approved       | Changes applied           | View only                         |
| Rejected       | Cancelled, no changes     | View only                         |

## Keyboard Shortcuts (Scan Page)

- **Enter** after scanning: Automatically finds item
- **Tab**: Navigate between fields
- **Esc**: Clear current item

## Tips & Best Practices

### For Admins

- **Start Small**: Begin with one location or collection
- **Assign Multiple Librarians**: Distribute workload
- **Review Regularly**: Check progress during scanning
- **Use Notes**: Request revision with specific instructions
- **Export Results**: Download reports for records

### For Librarians

- **Use Barcode Scanner**: Much faster than typing
- **Check Details**: Verify item matches before checking
- **Update Conditions**: Note any damage or issues
- **Add Notes**: Document unusual situations
- **Take Breaks**: Scanning can be tiring

## Common Issues

### "Item Already Checked"

- Item was scanned by you or another librarian
- Check recently scanned items list
- If error, contact admin

### "Multiple Items Found"

- Common with items sharing barcodes
- Select correct item from list
- Use item code or inventory code for precision

### "Not Found"

- Item may not be in session scope
- Check spelling of identifier
- Verify item exists in system

### "Permission Denied" (Scan Page)

- You're not assigned to this session
- Contact admin to be added

### Can't Complete Session (Admin)

- Not all librarians have completed work
- Check librarian progress on session details page
- Contact incomplete librarians

## Permissions

| Action           | Super Admin | Librarian (Assigned) | Librarian (Not Assigned) |
| ---------------- | ----------- | -------------------- | ------------------------ |
| Create Session   | ✅          | ❌                   | ❌                       |
| Start Session    | ✅          | ❌                   | ❌                       |
| Scan Items       | ✅          | ✅                   | ❌                       |
| Complete Work    | ✅          | ✅                   | ❌                       |
| Complete Session | ✅          | ❌                   | ❌                       |
| Review/Approve   | ✅          | ❌                   | ❌                       |
| View Session     | ✅          | ✅                   | ✅                       |

## Email Notifications

Librarians receive emails when:

- ✉️ Session started (start scanning)
- ✉️ Session completed (ready for review)
- ✉️ Session approved (changes applied)
- ✉️ Session rejected (cancelled)
- ✉️ Revision requested (need corrections)

Admins receive emails when:

- ✉️ Librarian completes work
- ✉️ All librarians complete work (ready to review)

## Support

For technical issues:

1. Check this guide
2. Review session status
3. Verify permissions
4. Contact system administrator

---

**Quick Tip**: Use the browser's back button to navigate, or use the "Back" links in the UI.
