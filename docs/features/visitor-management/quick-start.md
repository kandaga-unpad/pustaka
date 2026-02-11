# Visitor Management - Quick Start Guide

## Overview

The Visitor Management System allows you to track visitors, collect feedback, and generate comprehensive reports. It's designed for libraries, museums, and other public institutions that need to monitor visitor traffic and satisfaction.

## Quick Setup (5 minutes)

### 1. Run Migrations

```bash
cd voile
mix ecto.migrate
```

This creates two new tables:

Note: the Visitor Management system was recently refactored to use the existing `mst_locations` master data instead of a separate `visitor_rooms` table. See the "Refactoring notes" section below for important migration and API changes.

The system uses your existing `mst_locations` table for room/location data.

### 2. Configure Locations (Use Existing Master Data)

Ensure your `mst_locations` table has locations configured:

No additional seeding is needed - the system uses your existing location data.

### 3. Access the Features

#### For Visitors (Public - No Login Required)


#### For Staff/Admin (Login Required)


#### Manage Locations

Use your existing master data management interface to manage locations that appear in the visitor system.

## Key Features

### 🎯 Public Visitor Check-In
  1. Select your location (node)
  2. Choose the room you're visiting
  3. Enter your ID/name with built-in virtual keyboard


### ⭐ Visitor Surveys
  - 5-star rating system (required)
  - Optional comment field (up to 2000 characters)
  
  1. Select location
  2. Select room
  3. Submit rating and feedback

### 📊 Statistics Dashboard (Staff/Admin)
  - Date range
  - Location/Node
  - Specific room
  
  - Total visitors
  - Unique visitors
  - Average survey rating
  - Visitors by room
  - Visitors by origin/type
  - Rating distribution
  - Daily visitor trends

### ⚙️ Location Management

## Usage Examples

### Configure a Location for Visitors

1. Go to your master locations management interface
2. Find or create a location in `mst_locations`
3. Set these fields:
   - **node_id:** The library branch/node
   - **location_name:** Name shown to visitors (e.g., "Main Lobby")
   - **description:** Optional description
   - **is_active:** Set to `true` to make it visible to visitors
4. Save the location

### View Today's Visitors

1. Go to `/manage/visitor/statistics`
2. Set date range to today
3. Optionally filter by location or room
4. View the statistics and charts

### Check In a Visitor (Kiosk Mode)

1. Navigate to `/visitor` on a tablet/kiosk
2. Tap your location
3. Tap the room you're visiting
4. Use the virtual keyboard to enter your ID or name
5. (Optional) Select where you're from
6. Tap "Check In"

## Common Visitor Origins

The system includes these default visitor types:

You can use these to segment your visitor data in reports.

## Data Structure

### Visitor Log Entry
```elixir
%{
  visitor_identifier: "12345" or "John Doe",
  visitor_origin: "Student",
  location_id: 1,
  node_id: 1,
  check_in_time: ~U[2024-02-04 12:30:00Z],
  ip_address: "192.168.1.100",
  user_agent: "Mozilla/5.0..."
}
```

### Survey Entry
```elixir
%{
  rating: 5,
  comment: "Great facilities and helpful staff!",
  location_id: 1,
  node_id: 1,
  survey_type: "general"
}
```

## Tips & Best Practices

### For Kiosk Deployments
1. Use a tablet in landscape mode
2. Enable kiosk mode in your browser to prevent navigation
3. Mount the tablet at an accessible height
4. Consider adding clear signage directing visitors to check in
5. Use the virtual keyboard for easier touch input

### For Data Analysis
1. Review statistics weekly to identify trends
2. Monitor average ratings to gauge satisfaction
3. Check visitor distribution across rooms for space planning
4. Read comments regularly to identify improvement areas
5. Export data periodically for long-term analysis

### For Room Setup
1. Name rooms clearly and consistently
2. Set logical display orders (entrance → interior spaces)
3. Keep active rooms relevant (deactivate unused spaces)
4. Update descriptions seasonally if needed
5. Group similar rooms across nodes for consistency

## Troubleshooting

**Q: I don't see any locations when trying to check in**

**Q: Statistics showing zero visitors**

**Q: Virtual keyboard not responding**

**Q: Can't manage visitor locations**

## API Usage (Future)

While not yet implemented, future versions will support:

```bash
# Get visitor statistics via API
GET /api/v1/visitor/statistics?from=2024-01-01&to=2024-01-31&node_id=1

# Submit check-in via API
POST /api/v1/visitor/checkin
{
  "visitor_identifier": "12345",
  "visitor_origin": "Student",
  "location_id": 1
}

# Submit survey via API
POST /api/v1/visitor/survey
{
  "rating": 5,
  "comment": "Excellent service!",
  "location_id": 1
}
```

## Refactoring notes

- Migration file: `priv/repo/migrations/20260204162521_refactor_visitor_to_use_locations.exs`
- What changed:
  - `visitor_room_id` columns were renamed to `location_id` in `visitor_logs` and `visitor_surveys`
  - The `visitor_rooms` table and associated schema/UI were removed
  - LiveViews and context functions now use `Master.list_locations(node_id: ..., is_active: true)`
- After pulling latest code, run the migration:

```bash
mix ecto.migrate
```

- Verify locations in `mst_locations` have `node_id`, `location_name`, and `is_active = true`.

## Next Steps

1. ✅ Verify locations in `mst_locations` are configured
2. ✅ Test the check-in flow
3. ✅ Try submitting a survey
4. ✅ Review the statistics dashboard
5. 📝 Share the visitor URL with your staff
6. 📊 Set up regular reporting schedules
7. 🔄 Adjust location configurations as needed

## Need More Help?

- Read the full documentation: `docs/VISITOR_MANAGEMENT.md`
- Check the code examples in the documentation
- Review the seed file: `priv/repo/seeds/visitor_rooms_seed.exs`
- Contact your system administrator

## Feature Roadmap

Planned enhancements:
- [ ] Export statistics to CSV/Excel
- [ ] QR code generation for quick check-in
- [ ] Email notifications for feedback
- [ ] Customizable survey questions
- [ ] Visitor check-out tracking
- [ ] Integration with membership system
- [ ] Dashboard widgets
- [ ] Mobile app support

---

**Happy Tracking! 📊📚**