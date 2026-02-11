# Visitor Management System

This document describes the Visitor Management System feature, which allows tracking visitors, collecting feedback through surveys, and generating reports.

## Overview

The Visitor Management System consists of three main components:

1. **Public Visitor Check-In** - A public-facing page where visitors can register their visits
2. **Public Survey Form** - A public-facing page where visitors can provide feedback
3. **Dashboard & Reports** - Staff/admin pages for viewing statistics

The system uses existing `mst_locations` (master locations) data, so there's no need for separate room management - simply configure your locations through the existing master data management interface.

Note: The visitor system was refactored to use the existing `mst_locations` table. The migration `20260204162521_refactor_visitor_to_use_locations.exs` renames `visitor_room_id` to `location_id` and removes the `visitor_rooms` table. After updating your code, run `mix ecto.migrate` and ensure `mst_locations` entries have `is_active = true`.

#### `visitor_logs`
Records each visitor check-in.

- `id` - Primary key
- `visitor_identifier` - User ID, student number, or name (required)
- `location_id` - Foreign key to `mst_locations` (required)

**Indexes:**
- `location_id`
- `node_id`
- `ip_address` - IP address
- `user_agent` - Browser user agent
- `additional_data` - JSONB field for extra data
- `visitor_log_id` - Optional link to visitor log
- `location_id` - Foreign key to `mst_locations` (required)
- `node_id` - Foreign key to `nodes` (required)
- `inserted_at`, `updated_at` - Timestamps
**Indexes:**
   2. Select location within the node (from `mst_locations`)
- `node_id`
- `visitor_log_id`
- `rating`
- `inserted_at`
- `survey_type`

## Public Routes
### Visitor Check-In
   2. Select location within the node (from `mst_locations`)

**Access:** Public (no authentication required)
#### Visitor Log Entry
- `location_id` - Foreign key to `mst_locations` (required)
**Features:**
- Multi-step workflow:
#### Survey Entry
- `location_id` - Foreign key to `mst_locations` (required)
  2. Select room/location within the node (from `mst_locations`)
  3. Fill in visitor information
- Virtual keyboard for easy data entry
- Input fields:
  - Visitor identifier (ID, student number, or name) - Required
  - Visitor origin/type (Student, Faculty, Alumni, etc.) - Optional
- Auto-reset after successful check-in

### Visitor Survey
**URL:** `/visitor/survey`

**Access:** Public (no authentication required)

**Features:**
- Multi-step workflow:
  1. Select location/node
  2. Select room/location within the node (from `mst_locations`)
  3. Submit feedback
- Star-based rating (1-5 stars) - Required
- Optional text comment (up to 2000 characters)
- Auto-reset after successful submission

## Staff/Admin Routes

### Visitor Statistics Dashboard
**URL:** `/manage/visitor/statistics`

**Access:** Staff and Admin users (requires authentication)

**Features:**
  - Specific room/location
- Statistics shown:
  - Visitors by room
  - Visitors by origin/type
  - Rating distribution
  - Daily visitor trend
- Real-time refresh button

## Location Management

The visitor system uses the existing `mst_locations` table for room/location data. To manage visitor locations:

1. Navigate to the master locations management interface
2. Ensure locations are assigned to the correct node
3. Set `is_active` to true for locations that should appear in visitor check-in
4. Use `location_name` as the display name for visitors

**Note:** There is no separate visitor room management interface - all location data is managed through the existing master data system.

## Context Functions

### `Voile.Schema.System`

#### Visitor Logs

```elixir
# List visitor logs with filters
System.list_visitor_logs(opts \\ [])
# Options: node_id, location_id, from_date, to_date, search, preload, limit

# Get a single visitor log
System.get_visitor_log!(id, opts \\ [])

# Create a visitor log (check-in)
System.create_visitor_log(attrs)

# Update a visitor log (e.g., check-out)
System.update_visitor_log(visitor_log, attrs)

# Delete a visitor log
System.delete_visitor_log(visitor_log)
```

#### Visitor Surveys

```elixir
System.update_visitor_survey(visitor_survey, attrs)

# Delete a visitor survey
System.delete_visitor_survey(visitor_survey)
```

# Get comprehensive visitor statistics
System.get_visitor_statistics(opts \\ [])
# %{
#   total_visitors: integer,
#   unique_visitors: integer,
#   by_room: [%{room_id: id, room_name: name, count: count}],
#   by_origin: [%{origin: origin, count: count}],
#   daily_trend: [%{date: date, count: count}],
#   surveys: %{
#     total: integer,
#     average_rating: float,
#     distribution: [%{rating: rating, count: count}]
#   }
# }
```

## Setup Instructions

1. **Run Migrations**
   ```bash
   mix ecto.migrate
   ```

2. **Configure Locations** (use existing master data)
   - Ensure your `mst_locations` table has locations configured
   - Assign each location to the appropriate `node_id`
   - Set `is_active = true` for locations that should appear in visitor check-in
   - The `location_name` field will be displayed to visitors

3. **Verify Locations**
   - Check that each node has at least one active location
   - Locations will be displayed in alphabetical order by `location_name`

4. **Test the Public Pages**
   - Navigate to `/visitor` to test check-in
   - Navigate to `/visitor/survey` to test survey submission

6. **View Statistics**
   - Go to `/manage/visitor/statistics`
   - Filter by date range, location, or room
   - Export or analyze the data as needed

## Virtual Keyboard

The visitor check-in page includes a built-in virtual keyboard for easy data entry, especially useful for:
- Kiosk deployments
- Touch screen interfaces
- Environments where physical keyboards are not available

**Features:**
- QWERTY layout
- Numbers (0-9)
- Special characters (@, -, _, .)
- Backspace and Clear functions
- Alternative numeric-only layout available

**Usage:**
```elixir
<VirtualKeyboard.virtual_keyboard target="input_field_id" layout="qwerty" />
# Or for numeric only:
<VirtualKeyboard.virtual_keyboard target="input_field_id" layout="numeric" />
```

## Best Practices

1. **Location Naming**
   - Use clear, descriptive `location_name` values
   - Keep names short for mobile displays
   - Be consistent across nodes

2. **Data Privacy**
   - The system logs IP addresses for analytics
   - Consider your privacy policy regarding visitor data
   - Regularly archive or purge old visitor logs based on retention policy

3. **Survey Design**
   - Keep the survey simple (1-5 stars + optional comment)
   - Don't make too many fields required
   - The system is designed for quick feedback

4. **Statistics**
   - Use date filters to analyze trends
   - Compare different locations
   - Look at rating distributions to identify areas for improvement

5. **Maintenance**
   - Regularly review active locations in `mst_locations`
   - Set `is_active = false` for locations that are no longer in use
   - Update location descriptions as needed through master data management

## Integration with Existing Systems

The visitor management system integrates with:

- **Nodes System** - Multi-location support
- **Master Locations (`mst_locations`)** - Uses existing location data for visitor check-in
- **User Authentication** - For staff/admin access to reports

## Future Enhancements

Potential features for future development:

- Export statistics to CSV/Excel
- Email notifications for low ratings
- Visitor check-out tracking
- QR code generation for quick check-in
- Integration with membership system
- SMS notifications
- Visitor badges/receipts
- Customizable survey questions
- API endpoints for external integrations
- Dashboard widgets for homepage
- Bulk import/export of visitor data

## Troubleshooting

**Problem:** Locations not appearing in the check-in list
- Ensure the location `is_active` is set to `true` in `mst_locations`
- Verify the `node_id` is correct
- Check that the location exists in the database

**Problem:** Statistics not updating
- Click the "Refresh" button
- Check the date range filter
- Verify data exists for the selected filters

**Problem:** Virtual keyboard not working
- Check browser console for JavaScript errors
- Ensure Phoenix LiveView is properly connected
- Verify the `target` attribute matches the input field ID

## Support

For questions or issues related to the Visitor Management System, please contact the development team or file an issue in the project repository.