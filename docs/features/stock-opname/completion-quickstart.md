# Stock Opname Librarian Completion - Quick Start Guide

## Quick Overview

This feature allows librarians to mark their work as complete and admins to manage completion status for all librarians across sessions.

## For Librarians

### Completing Your Work

1. **Navigate to scanning page**: `/manage/stock_opname/:id/scan`
2. **Click "Complete Work"** button at the bottom of the page
3. **Confirm** in the modal dialog that appears
4. **Done!** You'll be redirected and won't be able to scan more items

### What Happens After Completion?

- ✅ Your work is marked as "completed"
- ❌ You cannot access the scan page anymore
- 📧 Contact an admin to reopen your session if needed

### Important Notes

- **Think before completing**: Once completed, only admins can reopen your session
- **No minimum**: You can complete even with 0 items scanned
- **Session-specific**: Completion applies to one session only

## For Administrators

### Viewing Librarian Reports

1. **Go to**: `/manage/stock_opname/report` 
2. **Or click**: "Librarian Reports" button on stock opname index page
3. **Browse sessions**: Use pagination controls to navigate (10 sessions per page)
4. **Click on a session** to expand and view librarian details

### Managing Librarian Work

#### To Manually Complete Work

```
1. Find the librarian in the report
2. Click "Complete" button (green)
3. Confirm the action
4. Status changes to "completed"
```

#### To Reopen Completed Work

```
1. Find the completed librarian in the report
2. Click "Reopen" button (yellow)
3. Confirm the action
4. Status changes to "in_progress"
5. Librarian can scan again
```

### Report Information Shown

For each librarian, you can see:
- 👤 Name/Email
- 📊 Items checked count
- 🏷️ Work status badge
- 🕐 Started timestamp
- ✅ Completed timestamp
- 📝 Notes (if any)

## Common Scenarios

### Scenario 1: Librarian Accidentally Completes Work

**Problem**: Librarian clicked complete but needs to scan more items

**Solution**:
1. Admin goes to librarian reports
2. Finds the librarian in the session
3. Clicks "Reopen" button
4. Librarian can now scan again

### Scenario 2: Librarian Forgets to Complete

**Problem**: Librarian finished scanning but didn't mark as complete

**Solution**:
1. Admin goes to librarian reports
2. Finds the librarian in the session
3. Clicks "Complete" button
4. Work is now marked as completed

### Scenario 3: Checking Session Progress

**Problem**: Need to see who has completed their work

**Solution**:
1. Go to librarian reports page
2. Navigate through pages if you have many sessions
3. Expand the session
4. Look at status badges:
   - 🟢 Green = Completed
   - 🔵 Blue = In Progress
   - ⚪ Gray = Pending

## Work Status Values

| Status | Meaning | Badge Color | Icon |
|--------|---------|-------------|------|
| `pending` | Not started yet | Gray | 🕐 Clock |
| `in_progress` | Currently working | Blue | 🔄 Arrow |
| `completed` | Work finished | Green | ✅ Check |

## Code Examples

### Complete Work (Librarian)

```elixir
# In LiveView
def handle_event("confirm_complete_work", _params, socket) do
  case StockOpname.complete_librarian_work(
    socket.assigns.session,
    socket.assigns.current_user,
    nil
  ) do
    {:ok, _} ->
      socket =
        socket
        |> put_flash(:info, "Your work session has been completed!")
        |> redirect(to: ~p"/manage/stock_opname/#{socket.assigns.session.id}")

      {:noreply, socket}

    {:error, _} ->
      {:noreply, put_flash(socket, :error, "Failed to complete work session")}
  end
end
```

### Reopen Work (Admin)

```elixir
# In LiveView
def handle_event("reopen_work", %{"session-id" => session_id, "user-id" => user_id}, socket) do
  session = Enum.find(socket.assigns.sessions, &(&1.id == session_id))
  user = Voile.Schema.Accounts.get_user!(user_id)

  case StockOpname.cancel_librarian_completion(session, user) do
    {:ok, _} ->
      # Reload and update
      {:noreply, put_flash(socket, :info, "Work session reopened.")}

    {:error, _} ->
      {:noreply, put_flash(socket, :error, "Failed to reopen work.")}
  end
end
```

### Manual Complete (Admin)

```elixir
# In LiveView
def handle_event("complete_work", %{"session-id" => session_id, "user-id" => user_id}, socket) do
  session = Enum.find(socket.assigns.sessions, &(&1.id == session_id))
  user = Voile.Schema.Accounts.get_user!(user_id)

  case StockOpname.admin_complete_librarian_work(session, user) do
    {:ok, _} ->
      # Reload and update
      {:noreply, put_flash(socket, :info, "Work marked as completed.")}

    {:error, _} ->
      {:noreply, put_flash(socket, :error, "Failed to complete work.")}
  end
end
```

## API Reference

### Context Functions

```elixir
# Complete work (librarian)
StockOpname.complete_librarian_work(session, user, notes \\ nil)
# Returns: {:ok, assignment} | {:error, reason}

# Cancel completion (admin)
StockOpname.cancel_librarian_completion(session, user)
# Returns: {:ok, assignment} | {:error, reason}

# Manual complete (admin)
StockOpname.admin_complete_librarian_work(session, user, notes \\ nil)
# Returns: {:ok, assignment} | {:error, reason}

# Get session report
StockOpname.get_session_librarian_report(session)
# Returns: [%{assignment: ..., items_checked: ..., user: ...}]
```

## Routes

```elixir
# Scan page (checks completion status)
/manage/stock_opname/:id/scan

# Admin reports page
/manage/stock_opname/report
```

## Permissions

| Action | Required Permission |
|--------|---------------------|
| Complete own work | Assigned librarian |
| View scan page | Assigned librarian or super admin |
| View reports | Super admin only |
| Reopen work | Super admin only |
| Manual complete | Super admin only |

## Troubleshooting

### "You don't have permission to access this page"

**Cause**: Only super admins can access the reports page

**Fix**: Log in with a super admin account

### "Your work session is already completed"

**Cause**: Work was previously completed

**Fix**: Ask admin to reopen your session

### "You are not assigned to this session"

**Cause**: Librarian not assigned to the session

**Fix**: Admin needs to add you to the session's librarian assignments

## Tips

1. ⚠️ **Always use confirmation**: The modal prevents accidental completion
2. 📊 **Check regularly**: Admins should monitor completion status
3. 💬 **Add notes**: Use the notes field for completion context
4. 🔄 **Reopen cautiously**: Reopening should be done with reason
5. 📈 **Track progress**: Use the reports to monitor session progress
6. 📄 **Pagination**: Reports show 10 sessions per page for better performance

## Related Docs

- [Full Implementation](./librarian-completion.md)
- [Stock Opname Design](./design.md)
- [Quick Reference](./quick-reference.md)