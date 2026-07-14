# Changelog

All notable changes to Voile will be documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [0.1.45] - 2026-07-14

### Fixed

- **Catalog dashboard crash: `Map.new` argument error** — `count_collections_by_status_per_unit/0` and `count_items_by_availability_per_unit/0` returned `%{unit_id => %{status => count}}` but the `Map.new/2` callback returned a map instead of a `{key, value}` tuple, causing `(ArgumentError) argument error` on every `/manage/catalog` page load. Fixed callback to return `{unit_id, Map.new(pairs)}`.
- **Asset Vault crash: `GROUP BY` on aggregate** — `load_stats/0` used `group_by: fragment("1")` which PostgreSQL rejects (`aggregate functions are not allowed in GROUP BY`). Removed the `group_by` clause — the query now correctly returns a single aggregated row.

## [0.1.44] - 2026-07-14

### Fixed

- **Critical: OpenObserveSender memory leak (4.5 GB)** — The log shipping GenServer called `Req.post` synchronously inside `handle_cast`, blocking for up to 10 seconds per flush. While blocked, log events piled up in the mailbox and the process heap grew to 4.5 GB without ever shrinking. Rewritten to use async `Task.Supervisor` for HTTP calls, with a 15-second safety timeout, a `flush_ref` to prevent race conditions, a `max_heap_size` of 100 MB as a hard ceiling, truncated `inspect/2` for log report messages (`limit: 50, printable_limit: 10_000`), a buffer cap (1,000 entries), and a circuit breaker that drops logs after 5 consecutive failures.
- **Critical: MetricsLive tight CPU spin loop** — `send(self(), :update_presence)` fired with no delay, burning 100% CPU as long as any admin had the metrics page open. Changed to `Process.send_after(self(), :update_presence, 5_000)` for 5-second polling. Now also refreshes system metrics on each tick.
- **Critical: EmailQueue blocking and unbounded** — `job.email_fn.()` ran synchronously inside the GenServer with no timeout; a hanging SMTP/API call permanently stalled the queue. Queue had no size limit — closures capturing member structs and transaction lists accumulated under burst load. Rewritten with async sending via `Task.Supervisor`, 30-second send timeout, max queue cap (`10_000`), proper `clear_queue` timer cancellation, and fixed stale-result handling via `flush_ref`.
- **Critical: UserPresence ETS memory leak** — `track_user/1` inserted entries keyed by `make_ref()` (unrecoverable), in a `:bag` table (accumulates duplicates), with no cleanup on disconnect. Changed to key by socket PID, `:set` table type (reconnecting overwrites), and `get_connection_stats/0` now lazily deletes dead entries. Counts are now accurate (only alive processes).
- **delete_setting stale cache** — `delete_setting/1` did not invalidate the `persistent_term` cache, so deleted settings returned stale values until node restart. Now erases the cache entry after successful deletion.
- **Permission search debounce not cancelling timers** — Rapid typing in the permission management search fired multiple `Process.send_after` messages, each triggering a DB query. Now cancels the previous timer before scheduling a new one.
- **Reservation notification silently discarded** — `{:reservation_member_notify, _}` broadcasts from `ReservationNotifier.notify_member/1` had no matching `handle_info` clause, so every staff member received and threw away the message. Added a handler in `NotificationHook`.

### Changed

- **Removed `:items` preload from collection list/search queries** — `list_pending_collections_paginated`, `search_collections_for_suggestions`, `search_collections`, `load_collections`, and `list_collections` previously loaded every item (and nested `:node`) of every collection just to call `length/1`. Now uses `attach_collection_counts/1` (single batch `GROUP BY` query) and the `items_count` virtual field. Updated 8+ template references from `length(collection.items)` to `collection.items_count`.
- **Collapsed Asset Vault `load_stats` from 5 queries to 1** — Replaced 5 separate `COUNT` queries with a single conditional aggregation using `count(...) filter (where ...)`.
- **Asset Vault `sort_change` no longer rebuilds folder tree** — Added `refresh_list_light/1` that only re-queries the paginated list (5 queries) instead of calling `apply_action` (~14 queries including folder tree + stats).
- **Inlined `Repo.all |> Repo.preload` into single queries** — Eliminated extra DB round-trips in `get_collection!/1`, `get_collection/1`, `get_item!/1`, `get_item/1`, `get_item_by_code!/1`, `get_item_by_code/1`, `get_item_by_code_or_barcode/1`, `list_collections_paginated`, `list_sets/1`, `list_identifiers/1`, `list_records/1`, `list_letters_paginated/3`.
- **Added safety limits to unbounded `Repo.all` calls** — `list_fines/0`, `list_requisitions/0`, `list_reservations/0`, `list_transactions/0` (limit 1,000), `list_member_active_transactions/1`, `list_transactions_due_soon/1` (limit 500), `list_system_logs/0`, `list_collection_logs/0` (limit 1,000, now ordered by `inserted_at desc`), `list_all_api_tokens/0` (limit 500), `search_users/1` (limit 100, now ordered by `inserted_at desc`).
- **LoanReminderScheduler: eliminated N+1 member lookups** — `send_member_reminder/3` and `send_overdue_notification/2` called `Accounts.get_user(member_id)` per member despite `:member` already being preloaded on transactions. Now extracts the member from the first matching transaction.
- **Added limit to `list_overdue_transactions/0`** — Was unbounded; now defaults to 500.
- **Visitor check-in is now async** — `submit_check_in` spawned a `Task.Supervisor.async_nolink` for the external API lookup instead of blocking the LiveView up to 5 seconds. All post-lookup logic extracted into `process_check_in/3`.
- **Labels page logo fetch is now async** — `logo_to_data_uri` runs in a `Task.Supervisor.async_nolink` instead of blocking `mount/3`.
- **Added timeout to thumbnail-from-URL helper** — `Req.get(url, redirect: true)` had no timeout (could hang 15s). Added `receive_timeout: 10_000, connect_timeout: 5_000`.
- **DB query removed from HEEx template** — `frontend/items/show.ex` called `Repo.preload(@current_scope.user, :roles)` on every render. Moved to `mount/3`, stored as `@is_staff_or_admin` assign.
- **N+1 dashboard queries eliminated** — `dashboard/catalog/index.ex` replaced 4 queries per node with 4 total batch `GROUP BY` queries. `analytics/dashboard.ex` replaced N+1 `count_collections(node.id)` with a single grouped query.
- **Atrium notifications capped** — Three `handle_info` clauses that prepend to `loan_reminders` now cap at 20 entries via `Enum.take`.
- **SearchAnalytics ETS auto-cleanup** — `cleanup_old_data/1` was never called. Now runs probabilistically (every ~100th insert) in a background process, with a hard cap of 10,000 entries.
- **Hooks cleanup on terminate** — Added `terminate/2` to erase `persistent_term` entries. `unregister_all` now prunes empty hooks from `known_hooks` and erases their persistent_term entries instead of writing back empty lists.
- **Holiday cache past-date eviction** — Added `sweep_past_entries/0` that deletes ETS entries with past `%Date{}` keys. Runs probabilistically (1 in 100 lookups).
- **Circulation filter deduplication** — Extracted filter logic from `list_fines_paginated_with_filters/3` into reusable `apply_fines_status_filter/2`, `apply_fines_type_filter/2`, `apply_fines_search_filter/2` helpers.
- **Dead code removed** — Deleted `get_library_collections/1` from `glam/library/index.ex` (50-row query with `:items` preload, result never referenced in template).
- **UI: PAuS ID button prominence** — On login and register pages, the PAuS ID button is now positioned after the "or continue with" divider but styled as the most prominent option (solid gradient, larger size, "Recommended" badge). Google and Passwordless are below in smaller outline style. PAuS ID button also added to the register page (was previously login-only).

### Added

- **Expression indexes migration** — Added indexes for `DATE(event_date)` on `lib_circulation_history`, `COALESCE(read_at, inserted_at)` on `lib_read_on_spots`, `COALESCE(fullname, '')` trigram on `users`, and `DATE(check_in_time)` on `visitor_logs`. These fix full table scans on hot-path queries.
- **Batch count functions** — Added `Catalog.count_collections_by_unit/0`, `count_items_by_unit/0`, `count_collections_by_status_per_unit/0`, `count_items_by_availability_per_unit/0` for single-query batch counts per node.
- **EmailQueue configuration** — New options: `email_queue_max_size` (default 10,000), `max_heap_mb` on OpenObserveSender (default 100 MB), `max_buffer_size`/`circuit_threshold`/`circuit_reset_delay` on OpenObserveSender.

## [0.1.43] - 2026-07-08

### Security

- **API: mass-assignment hardening (Collections)** — `created_by_id`/`updated_by_id` are no longer accepted via `Collection.changeset`'s `cast` list (per project convention). They are now set programmatically by `Catalog.create_collection/update_collection` from the authenticated user, and the Collections API controller strips client-supplied `id` values. A client can no longer forge the audit actor or choose a collection UUID through the API.

### Fixed

- **API: 404 dead-code across Collections, Items & Fines** — `show`/`update`/`delete` called the bang context getter (`get_*!`, which raises `Ecto.NoResultsError`) then pattern-matched on `nil`, making the `{:error, :not_found}` branch unreachable. A request for a missing ID returned a 500 instead of a 404. Switched to non-bang getters (`get_collection/1`, `get_item/1`, `get_fine/1`) so the FallbackController returns a proper 404.
- **API: empty associations on create/update responses** — `create`/`update` rendered `:show` straight from the context result without preloading, so `type`, `creator`, `unit`, `metadata`, `items`, and `attachments` came back as `nil`/`[]`. The Collections, Items, Fines, and Circulation History endpoints now re-fetch via the bang getter after a successful write.
- **API: Items `render_user` KeyError** — `item_api_json.ex` read `user.first_name`/`user.last_name`, but the `User` schema only has `fullname`. Every Items show/create/update that loaded `created_by` crashed with a runtime `KeyError`. Now uses `user.fullname`.
- **API: attachment field-name bug** — `render_attachments` read `attachment.filename` (does not exist); corrected to `file_name` across the Collections and Items renderers for cross-endpoint consistency.
- **API: audit logging blind spots** — The Collections and Items contexts accept an optional `user_id` for `CollectionLogger`, but the controllers dropped it, logging every API mutation with `user_id: nil`. Both controllers now forward the authenticated API user id.
- **API: Collection types `index` MatchError** — The `glam_type` branch matched a 2-tuple, but `Metadata.list_glam_type_based_resource_classes/3` returns a 3-tuple, so `GET /v1/collection_types?glam_type=X` raised a `MatchError` (500). Now correctly unpacks the result and surfaces `total_count`.
- **Catalog: `resource_class` double-join** — When `search` and `glam_type` filters were combined, the `resource_class` association was joined twice. The `glam_type` filter now reuses the search query's named binding via `has_named_binding?/2`.
- **API: Fines show missing `payments`** — `get_fine!/1` did not preload `:payments` (rendered by the JSON), so the field was always `[]`. Added it to the preloads via a shared `fine_preloads/0` helper.

### Changed

- **API: Collections list payload** — The `index` view now returns `items_count`/`attachments_count` (computed via grouped count queries, no full rows loaded) instead of the full `items`/`attachments` arrays, and omits `metadata`; full item/attachment/metadata data is only on the `show` endpoint. Deduplicated the list/show JSON renderers through a shared `base_data/1`.
- **API: `limit` parsed instead of hardcoded** — All paginated API endpoints (Collections, Items, Fines, Circulation History, Users, Collection Types `index`/`details`) now honor a `limit` query param via `Voile.Utils.Pagination.parse_per_page/2` (capped at 100) instead of hardcoding a page size of 10.
- **API: shared `current_user_id`** — The `APIAuthorization` plug now assigns `:current_user_id` once, removing the per-controller `current_user_id/1` helpers.
- **Swagger docs** — Refreshed the Collections `CollectionsResponse`/`Pagination` examples and added `limit` params to reflect the actual response shapes.

### Added

- **Context: non-bang getters** — Added `Catalog.get_collection/1` (already had `get_item/1`), and `Circulation.get_fine/1` to support proper 404 handling. Also added a `Voile.get_collection/1` delegate for symmetry.

## [0.1.42] - 2026-07-01

### Fixed

- **OpenObserve logger: deprecated auth syntax** — Updated `Req` HTTP client authentication from deprecated `auth: {username, password}` syntax to the new `auth: {:basic, "username:password"}` format to eliminate deprecation warnings.
- **Collection form: duplicate collection_fields IDs** — Fixed Ecto warning about duplicate primary keys in `:collection_fields` association. The issue occurred in the `delete_existing_field` function where both persisted DB fields and unsaved form fields could contain the same IDs, causing duplicates when concatenated. Now filters out unsaved fields that have IDs already present in the DB field list, ensuring each field ID appears only once.
- **API/Search: glam_type enum case sensitivity** — Fixed PostgreSQL enum error when filtering by `glam_type`. The database enum values are capitalized (`Gallery`, `Library`, `Archive`, `Museum`) but API requests and search queries were sending lowercase values. Added automatic case normalization using `String.capitalize/1` in all glam_type filter functions across:
  - `Voile.Schema.Catalog.filter_by_glam_type/2`
  - `Voile.Search.Collections.search_collections_for_suggestions/2`
  - `Voile.Search.Collections.filter_by_glam_type/2`
  - `Voile.Search.Collections.filter_by_resource_glam_type/2`
  - `Voile.GLAM.CollectionHelper.list_accessible_collections/3`
  - `Voile.Task.Catalog.Collection.filter_by_glam_type/2`

## [0.1.41] - 2026-07-01

### Fixed

- **Stock Opname: barcode scanning crash** — Fixed `KeyError` when scanning items during stock opname. The code was attempting to access `prop.name` on `Metadata.Property` structs, but the schema uses `prop.local_name` instead. Updated property filtering logic to use the correct field name.

## [0.1.40] - 2026-06-25

### Changed

- **Version bump** — Release version 0.1.40 with accumulated fixes and improvements.

## [0.1.39] - 2026-06-25

### Changed

- **Version bump** — Release version 0.1.39 with accumulated fixes and improvements.

## [0.1.38] - 2026-06-25

### Security

- **Security audit and comprehensive fixes** — Conducted thorough security audit and implemented multiple security enhancements:
  - Added pagination helpers with input validation to prevent SQL injection
  - Enhanced OAuth registration flow with proper error handling and security checks
  - Improved API authorization with comprehensive permission validation
  - Hardened attachment download controller against SSRF attacks
  - Strengthened Xendit webhook validation and signature verification
  - Added security configuration tests and validation
  - Implemented comprehensive test coverage for security-critical paths
  - Fixed potential vulnerabilities in Google OAuth flow
  - Enhanced PAUS authentication security
  - Improved plugin management security controls
  - Secured ebook reader access controls
  - Added rate limiting and input validation across API endpoints

### Added

- **Security test suites** — Added comprehensive test coverage for security fixes including:
  - Low and medium severity security fixes tests
  - OAuth registration security tests
  - API authorization permission tests
  - Attachment download SSRF prevention tests
  - Xendit webhook validation tests
  - Pagination utility tests
  - Security configuration validation tests

## [0.1.37] - 2026-06-11

### Changed

- **Member management: restrict sensitive fields for librarians** — When a librarian opens the "Edit Member" tab, the Node, Member Type, Registration Date, Expiry Date, and Assign Roles fields are hidden. Librarians can only edit basic profile fields (name, email, username, identifier, phone, birth date, address, organization, social media, groups, and profile picture). These fields remain visible and editable for users with the `users.update` permission (admins and super-admins).

## [0.1.36] - 2026-06-11

### Added

- **Asset Vault: bulk file selection and actions** — Files in the Asset Vault can now be selected individually (checkbox toggle) or all at once. A bulk-action toolbar appears when files are selected, offering bulk delete and bulk move-to-folder.
- **Asset Vault: move files between folders** — A new move modal lets users move one or more selected files to any folder in the tree. The folder tree is fully expanded and shown as a flat list for easy selection.
- **Asset Vault: file preview panel** — Clicking a file now opens an inline preview panel showing the image, file metadata (name, type, size, date), and quick action buttons.
- **Asset Vault: sortable file listing** — Files can be sorted by insertion date or name using a sort control in the toolbar. Sort direction toggles between ascending and descending.
- **Asset Vault: storage stats** — The page header now shows total file count and storage usage loaded on mount.
- **Asset Vault: folder tree sidebar** — Mount now builds a full hierarchical folder tree and flat folder list for navigation and move-modal use.
- **Asset Vault: upload panel toggle** — The upload area is now hidden by default and revealed via a dedicated "Upload" button, reducing visual clutter on the main listing.
- **`Authorization.is_librarian?/1`** — New helper following the same pattern as `is_node_admin?/1`, supporting `User`, `Socket`, `Conn`, and `nil` inputs.

### Changed

- **Member management: librarian can edit member info** — Users with the `librarian` role can now access the "Edit Member" tab on the member detail page. The "Extend Membership", "Change Password", and "Delete" tabs remain restricted to users with `users.update` permission or super-admin.
- **Public search LiveView: full UI redesign** — `SearchLive` at `/search/live` has been redesigned with card-based result rows. Each collection card shows status, availability, and condition as colour-coded pill badges (`coll_status_badge`, `avail_badge`, `cond_badge`). The "no results" state uses an icon-centred empty-state block.
- **Public search LiveView: route** — The `clear_search` event now redirects to `/search/live` (previously `/search`).
- **Public search LiveView: universal fallback** — The `perform_search` handler now falls back to `universal_search` for any unrecognised `search_type` instead of only matching the literal `"universal"` string.
- **Search HTML: GLAM-type tabs and browse sections** — The static search results page now renders a page title and description scoped to the active `glam_type`. GLAM-type quick-link cards (Library, Gallery, Archive, Museum) are shown when no query is active.
- **Search HTML: media type filter** — An inline media type dropdown (All / Digital / Physical) has been added to the search bar for collection searches.
- **Search HTML: filter pills and advanced search link** — Active filters are shown as pill badges beneath the search bar. An "Advanced Search →" link is always visible for navigation to `/search/advanced`.

## [0.1.35] - 2026-06-02

### Fixed

- **Visitor management: virtual keyboard input not appearing** — Clicking the virtual keyboard's number or letter keys sent events that were correctly processed server-side, but the updated value never appeared in the identifier input field. The root cause was that `IdentifierInput` keeps the field focused at all times, and Phoenix LiveView intentionally skips DOM-patching focused form inputs to avoid clobbering active user input. Fixed by adding `push_event("keyboard_update_value", %{value: new_value})` to the `keyboard_input`, `keyboard_backspace`, and `keyboard_clear` handlers (in both `CheckIn` and `CheckOut`) and handling that event in the `IdentifierInput` JS hook to set the value directly on the DOM element.

## [0.1.34] - 2026-05-23

### Changed

- **Library circulation report: detailed statistics** — The circulation report overview now shows a detailed breakdown by status for transactions, reservations, and fines, including active/returned/overdue/lost/damaged/cancelled transactions, reservation statuses, and fine payment status with aggregated totals.
- **Library circulation report: year/month filters** — Added dynamic year and month filters to the circulation report. Year selection is required before month selection, and when month is not selected the report shows aggregated data for the chosen year. The month selector is disabled until a year is chosen.
- **Library circulation report: item node scoping** — The report remains scoped by item node_id so statistics are computed per node branch, not by the user's node.
- **UI polish: dark/light mode select support** — Month/year select controls now use the default theme-aware select styling so they render correctly in both dark and light mode.

## [0.1.33] - 2026-05-18

### Added

- **Member Atrium: Reservations tab** — The member self-service portal now includes a dedicated "Reservations" tab showing all reservations across all statuses (pending, available, fulfilled, picked up, cancelled, expired). Each card shows the collection thumbnail, title, item code, status badge, reservation date, and expiry date. Active reservations display a pickup-ready banner. The tab is refreshed on navigation and subscribes to real-time reservation notifications via PubSub.
- **`Circulation.list_all_member_reservations/1`** — New context function (and top-level delegate in `Voile`) that fetches all reservations for a member ordered by reservation date descending, preloading `item.collection` and `collection`.
- **Reservation notification: email fallback** — `ReservationNotifier.notify_member_reservation_available/1` now sends a pickup-ready email (HTML + plain-text) to the member in addition to the real-time PubSub push, ensuring members who are offline are also notified.
- **Holiday management: RBAC action guards** — Edit, Enable/Disable, and Delete buttons on the holidays settings page are now hidden for entries the current user does not own. All three event handlers (`edit_holiday`, `toggle_holiday`, `delete_holiday`) enforce the same `can_modify_holiday?` check server-side, returning a 403-style flash for unauthorised attempts.
- **Holiday management: Import Data page** — The "Setup Default Schedule" toolbar button has been replaced with an "Import Data" link navigating to the new `/manage/settings/holidays/import` route (`Dashboard.Settings.HolidayImportLive`).
- **Admin reservation index: card layout** — The reservations list page has been redesigned with a card-based layout replacing the previous `<.table>` component. Each card shows member avatar, member identifier, item/collection title with item code, status badge, priority, reserved date, expiry date, notification status, and notes. Action buttons (Mark Available, Fulfill, Cancel, View) are styled as pill badges in the card footer.

### Changed

- **Admin reservation show: status-aware action buttons** — The action button block now uses `cond` keyed on reservation status. `"pending"` shows Mark Available + Send Notification + Cancel Reservation. `"available"` shows Fulfill Reservation + Send Notification + Cancel Reservation. Terminal statuses (`picked_up`, `fulfilled`, `cancelled`, `expired`) show no action buttons.
- **Admin reservation show: `mark_available` event** — New `handle_event/3` clause calls `Circulation.mark_reservation_available/2` and updates the reservation assign in-place without a page navigate.
- **Admin reservation show: notes field always visible** — The notes field is now always rendered (showing `"-"` when empty) rather than conditionally hidden.
- **Frontend item show: reservation form redesign** — The Reserve Item modal now uses `<.form>` with `@reservation_form` assign (backed by `to_form/2`), displays an item preview card with cover image, title, creator, and description, and resets the form state on open/close. The submit button label changed to "Confirm Reservation".
- **`create_reservation` call: explicit nil collection** — `Items.Show` now passes `nil` as the `collection_id` argument so the function signature matches `Circulation.create_reservation/4`.
- **`LibHoliday`: recurring holiday support in `is_holiday?`** — The holiday check now matches recurring holidays by month and day across any year using a `EXTRACT(month)/EXTRACT(day)` fragment, replacing the previous exact-date-only lookup.
- **`LibHoliday.get_holidays_in_range/2`: recurring holidays included** — Recurring holidays are now matched by month/day against every date in the requested range, so they appear in business-day calculations regardless of the year stored in `holiday_date`.
- **`LibHolidays.list_holidays/1`: node-scoped visibility** — When called with a `unit_id`, the query now also returns public holidays and system-wide holidays (those with a nil unit), ensuring nodes see both their own and shared holidays.
- **`LibHolidays`: cache invalidation on mutations** — `create_holiday/1`, `update_holiday/2`, `delete_holiday/1`, `create_schedule/1`, `update_schedule/2`, and `delete_schedule/1` now call `LibHoliday.clear_cache/0` after a successful write so the `is_holiday?` cache is immediately consistent.

### Fixed

- **`confirm_fulfill` crash on already-processed reservations** — `handle_event("confirm_fulfill")` now matches `{:error, reason} when is_binary(reason)` before the changeset clause, preventing a `CaseClauseError` when `Circulation.fulfill_reservation/2` returns `{:error, "Reservation is not available"}`.
- **SSO suspension bypass — PAuS** — Suspended users could previously complete a PAuS SSO login because the suspension redirect was piped after `log_in_user` (whose `redirect/2` call was then overwritten). The suspension check now happens before any session is created; suspended users are redirected to `/login` with an error flash.
- **SSO suspension bypass — Google** — Same fix applied to the Google OAuth callback.
- **Magic link suspension flash** — Suspended users logging in via magic link no longer briefly see the "Welcome!" info flash alongside the suspension error. The handler now uses an explicit `if/else` to produce exactly one response.
- **`LibHoliday` changeset: duplicate recurring holiday validation** — Added a `validate_recurring_holiday_conflicts/1` callback that queries existing active holidays matching the same month/day, type, and unit before inserting, preventing silent duplicate recurring entries that would distort business-day calculations.
- **Duplicate Atrium reservations tab panel** — Removed a duplicate reservations tab panel that was inserted during a previous session, which caused the panel to render twice when the tab was active.
- **`catalog/collection_live/import.ex` removed** — Deleted the old standalone collection import LiveView that was superseded by the unified Import & Export page in v0.1.14.

## [0.1.32] - 2026-05-13

### Added

- **Frontend collections: sidebar filter panel** — The collection browse page (`/collections`) has been redesigned with a persistent left-side filter panel containing all filter controls. The top bar now holds only the search input and page title, keeping browsing and filtering concerns visually separate.
- **Frontend collections: publication year range filter** — Users can now narrow collections by publication year using a "From / To" input pair in the sidebar. The year is matched against the `publishedYear` collection field stored in `collection_fields`. Supports open-ended ranges (from only, to only, or both).
- **Frontend collections: sidebar radio-button filters** — Node, Status, GLAM Type, and Media Type filters are now rendered as radio-button groups in the sidebar instead of dropdown selects, improving scannability and touch usability.
- **Frontend collections: mobile filter toggle** — A "Filters" button appears on small screens to show/hide the sidebar panel, with an indicator badge when any filter is active.
- **Frontend collections: active-filter indicator and clear-all button** — When any filter is active, a "Clear all" link appears in the sidebar header and a "Clear filters" shortcut appears in the results header on mobile.
- **`frontend_pagination`: `filter_media_type`, `filter_year_from`, `filter_year_to` attrs** — The pagination component now forwards all active filter parameters (including the new year-range and media-type filters) through page links so filter state is preserved across pages.
- **`build_page_url/7`: `extra_params` argument** — Accepts an optional extra params map merged into the pagination URL, enabling arbitrary filter keys without changing the function signature.
- **`LibHoliday.business_days_add/3`** — New function that advances a `%Date{}` by N business days, skipping holidays and non-business days for a given `unit_id`. Used by loan and renewal due-date calculations so due dates land on the next open business day rather than on a holiday.
- **Node Loan Rules: super-admin guard** — The "Add Node" and "Configure Rules" buttons on the nodes settings page are now hidden for non-super-admin users. The Node Loan Rules page (`/manage/settings/nodes/rules`) now redirects non-super-admins back to the nodes list with an "Access Denied" flash.
- **Test fixtures: `ensure_node` and `ensure_resource_class`** — `AccountsFixtures.user_fixture/1` and `LibraryFixtures` collection fixture now automatically provision a `Node` (and `ResourceClass`) when none exists, preventing FK constraint failures in isolated test runs.

### Changed

- **Due-date calculation: holiday-aware** — `calculate_due_date_for_member_type/3` and `calculate_renewal_due_date/3` in `Circulation` now call `LibHoliday.business_days_add/3` instead of a plain `DateTime.add` so loan and renewal due dates skip over library holidays. The item's `unit_id` is passed separately from the override-rules `node`, ensuring holidays are always scoped to the item's home branch.
- **Overdue calculation: holiday-aware per node** — `Transaction.days_overdue/1` now passes `unit_id` to `LibHoliday.business_days_between/3` so overdue day counts exclude holidays at the item's branch.

### Fixed

- **Year filter: integer overflow on non-year `publishedYear` values** — Some imported records store ISBN-like numbers (e.g. `9798150201`) in the `publishedYear` field. The previous `value ~ '^[0-9]+$'` regex matched any all-digit string, causing `value::integer` to overflow PostgreSQL's 32-bit integer type. Fixed by tightening the regex to `'^[0-9]{4}$'` (exactly four digits), so only valid 4-digit years are cast.
- **`LibHolidays.create_holiday/1`: `schedule_type` default not applied** — `Map.put_new/3` was called with an atom key (`:schedule_type`) while the incoming attrs map used string keys, so the default was never set. Changed to `"schedule_type"` (string key) to match the changeset cast.
- **`LibraryFixtures` collection fixture: missing required fields** — Collection fixture was missing `collection_code`, `type_id`, and `unit_id`, causing FK constraint errors in test runs that start with an empty database. Fixture now auto-generates a unique collection code and resolves or creates a `ResourceClass` and `Node`.

---

## [0.1.31] - 2026-05-12

### Changed

- **PAuS SSO: identifier-first email reconciliation** — On PAuS login, the system now looks up the user by `identifier` (NPM/NIP) before falling back to email. If a matching record is found whose stored email differs from the institution email returned by PAuS (e.g. an imported member still using a `@gmail.com` address), the email is silently updated to the institution email (`@mail.unpad.ac.id` / `@unpad.ac.id`) without requiring a confirmation link. If the identifier is absent or has no database match, the login falls back to email lookup; if neither matches, a new user is created with the institution email as usual. Email update conflicts (institution email already taken by a different account) are logged as warnings and do not block login.

---

## [0.1.30] - 2026-05-12

### Added

- **PAuS SSO: full user provisioning from PAuS API** — On first login, the PAuS callback now reads the `/api/accounts` response to extract `username`, `fullname`, `identifier` (NIP/NPM), `image_url`, `birth_date`, `gender`, `group_name`, and `faculty_name`. New users are created with all available fields populated, including `user_type_id` (resolved from `group_name` via `MemberType` slug) and `node_id` (resolved by matching `faculty_name` against node names for students, or falling back to the system default node for staff).
- **PAuS SSO: `sso_paus_enabled` setting** — Added a new toggle in App Profile Settings to enable or disable the PAuS SSO button. When disabled, the button is hidden from the login page entirely.
- **PAuS SSO: conditional login button** — The "Sign in with PAuS ID" button on the login page is now shown only when the `sso_paus_enabled` system setting is `"true"`, and is styled as an active button (previously always disabled/greyed out).
- **OpenObserve log shipping** — Added `Voile.Logger.OpenObserveHandler` and `Voile.Logger.OpenObserveSender`, a batched OTP logger handler that ships structured log events to the OpenObserve JSON ingest API (`_json` endpoint) via Req. Activated automatically when `VOILE_OPENOBSERVE_LOGS_URL` is set. Batch size and flush interval are configurable.
- **Structured JSON logging in production** — Production now uses `LoggerJSON.Formatters.GoogleCloud` via the OTP `:default_handler` API, producing structured JSON with `severity`, `time`, `logging.googleapis.com/sourceLocation`, `trace`, and `spanId` fields. Development retains the previous human-readable `$time [$level] $message` format.

### Changed

- **Removed PromEx** — `prom_ex` dependency, `Voile.PromEx` module, `/metrics` route, and all related configuration have been removed. Metrics push to OpenObserve via the broken `PromEx.MetricWriters.Push` (non-existent API) has been cleaned up. Metrics are no longer collected.
- **OpenTelemetry config is fully optional** — All OpenTelemetry and OpenObserve configuration is now gated on environment variables (`VOILE_OTEL_EXPORTER_ENDPOINT`, `VOILE_OPENOBSERVE_LOGS_URL`). When neither is set, the app starts and runs with zero observability overhead and no crashes.

### Fixed

- **PAuS: `expires_in` type handling** — The token exchange now handles `expires_in` returned as a string (as the PAuS API does) by converting it with `String.to_integer/1` before arithmetic, preventing a `BadArithmeticError` crash.
- **PAuS: correct user profile API endpoint** — Fixed the profile fetch URL from `/user/profile` to `/accounts`, matching the actual PAuS API contract.
- **PAuS: Req auto-decoding compatibility** — All PAuS HTTP response bodies are now decoded through a `decode_body/1` helper that accepts both pre-decoded maps (Req auto-decodes `application/json`) and raw binary strings, eliminating `Jason.decode` errors on already-decoded responses.
- **PAuS: onboarding bypass for SSO users** — Users authenticated via PAuS SSO (who have an `identifier` set) are no longer required to provide a `phone_number` during onboarding, since PAuS does not supply one. Only `fullname` is required for SSO users.
- **Settings: `upsert_setting/2` PK sequence crash** — `upsert_setting` now uses `Repo.insert/2` with `on_conflict: [set: [...]]` instead of a read-then-write pattern, avoiding race conditions. An `Ecto.ConstraintError` rescue with a self-healing `setval` query handles out-of-sync PK sequences (common after seeding) and retries once automatically.
- **Logger: FORMATTER CRASH from Bandit/Plug chardata messages** — Removed the legacy `config :logger, :console, format: {LoggerJSON, :format}` which caused `FORMATTER CRASH` errors when Bandit emitted Erlang chardata log events. Replaced with the correct LoggerJSON v7 OTP handler API (`config :logger, :default_handler, formatter: ...`).
- **`create_user_from_oauth/1`: extended field support** — `create_user_from_oauth` now accepts and propagates `identifier`, `birth_date`, `gender`, `registration_date`, `confirmed_at`, and `last_login` from the attrs map, enabling PAuS (and future OAuth providers) to pass richer profile data on account creation.

### Added

- **Loan reminder: item location display** — Loan cards in the loan reminder page now show the item's location as `{Node} / {Location}` (or just the node or location name when only one is available) beneath the item code.
- **Member management: RBAC role and member-type assignment guards** — Admins can no longer assign member types with a higher priority level than their own, nor assign roles equal to or above their own rank. The member type dropdown is filtered to only show types the assigning user is permitted to grant. Role checkboxes for disallowed roles are hidden in the create/edit form, and server-side validation rejects any attempt to bypass these restrictions.

### Fixed

- **Read On Spot: node name crash for non-super-admin** — Non-super-admin users were getting a `nil` selected node name because `find_node_name/2` was called with an empty `nodes` list (which is intentionally empty for non-admins). Fixed by reading directly from `current_user.node.name` for non-super-admin users.
- **Read On Spot: `select_node` KeyError on missing param** — The `select_node` event handler now uses `Map.fetch/2` to safely fall back to the current node ID when the `node_id` key is absent from params, preventing a `KeyError` crash.
- **Read On Spot: invalid Tailwind class `bg-gray-750`** — Replaced the non-existent `dark:bg-gray-750` class with `dark:bg-gray-700` in the report and report detail row striping.
- **Collection review: created_by/updated_by audit trail** — The review table now displays "Created by" and "Updated by" labels alongside their respective user names and timestamps, giving reviewers a clearer audit trail.
- **Circulation: enriched transaction preloads** — `list_member_active_transactions`, `list_paginated_member_active_transactions`, and `list_overdue_transactions` now preload `item_location` and `node` on transaction items so location-aware components (such as the loan reminder) can render without additional queries.

---

## [0.1.28] - 2026-06-10

### Changed

- Change the default collection sort listing to be sorted by 'updated_at' instead of 'inserted_at' to show the most recently updated collections first.

## [0.1.27] - 2026-05-09

### Fixed

- Explicitly configured `PromEx.Plugins.Ecto` with `repos: [Voile.Repo]` to prevent startup failure when the host environment does not expose the repo config.
- Guarded optional `VoileLockerLuggage.Lockers` calls behind `Code.ensure_loaded?/1` and `function_exported?/3`, so the app no longer emits warnings or crashes when the locker plugin is not installed.

---

## [0.1.26] - 2026-05-08

### Fixed

- **Stock opname: duplicate modal stays open after discard** — Clicking "Discard" on an item in the duplicate-selection modal no longer closes the modal. The discarded item's button immediately switches to a disabled "Discarded" state so the librarian can continue selecting the correct item (or scan again) without re-triggering the search. The modal now only closes when the librarian clicks "Check this item" or the "Cancel" button.
- **Stock opname: duplicate modal Cancel button color** — The Cancel button in the duplicate-selection modal footer was styled with an incorrect yellow Tailwind class (`bg-yellow-100`) and contained a typo (`dark:bg-y-700`). Corrected to neutral gray (`bg-gray-100 hover:bg-gray-200 dark:bg-gray-700 dark:hover:bg-gray-600`) so it is clearly readable on both light and dark backgrounds without conflicting with warning-colored elements.

---

## [0.1.25] - 2026-05-08

### Added

- **Stock opname: mark duplicate item for discard from scan modal** — When scanning an item code that matches multiple opname items (e.g. a shared legacy code), the duplicate-selection modal now shows a trash button beside each item. Clicking it records `status → discarded` on the opname item via `check_item_with_collection/6`. The status change is applied to the catalog item automatically when the session is approved, setting it to `discarded` (an existing valid status). No schema migration required.
- **Stock opname: discard badge in review page** — Items in the "Items with Changes" tab that carry a `status → discarded` change are now highlighted with a red border and a prominent "Marked for Discard" banner so reviewers can clearly identify them before approving the session.
- **Stock opname: mark-for-discard tests** — Added 4 tests covering: (1) `check_item_with_collection` records the discard change correctly, (2) session counters are incremented, (3) `approve_session` writes `discarded` status to the catalog item, (4) only the flagged item is discarded while other items in the session remain unaffected.

### Fixed

- **Critical: Stock opname duplicate scan crash** — Scanning a legacy item code that matched multiple opname items raised `KeyError: key :item_code not found in %Voile.Schema.StockOpname.Item{}`. The duplicate-items template was accessing fields directly on the opname item struct instead of traversing the preloaded associations (`opname_item.item.item_code`, `opname_item.collection.title`, etc.).
- **Stock opname: duplicate items inline banner replaced with modal** — The inline yellow banner shown when multiple items matched a scan has been replaced with a proper `<.modal>` dialog, including a "Cancel" button and a `dismiss_duplicate_modal` event handler that clears the search term.

---

## [0.1.24] - 2026-04-29

### Added

- Member management: add a `Generate` button beside the identifier input on the new member form so staff can populate or regenerate member identifiers instantly.
- Collection import: remove the hard row limit in preview and import the full deduplicated CSV set, with live progress updates and chunked background processing.
- Circulation legacy item lookup: show a selection modal when multiple active items share the same legacy item code.

### Fixed

- Plugin management UI now only shows the `Update` button to super admins.
- Legacy item selection modal now correctly routes to the different-node warning state and avoids unknown modal rendering.

## [0.1.23] - 2026-04-28

### Added

- Bumped release version to `0.1.23`.
- New Translation - Added Indonesian translations for the clearance letter feature, including new keys for the letter body, closing text, and various UI elements on the clearance pages.

### Fixed

- Fixed PluginManager checking for status.
- Fixed Update Full Script for deployment.

## [0.1.22] - 2026-04-25

### Added

- **Clearance letter: paginated list with search and node scoping** — New `list_letters_paginated/3` with search on letter number, member name, and identifier; node-scoped for non-super-admin users.
- **Clearance letter: full management UI** — New routes `/clearance/`, `/clearance/verify`, `/clearance/settings`, and `/clearance/:id` under `Dashboard.Members.Clearance.*` with index, verify, settings, and show views.
- **Clearance letter: custom identifier and external department lookup** — Clearance generation now accepts a custom identifier and can resolve the member's department from an external visitor source API when configured.
- **Clearance letter: customisable body and closing text** — Two new settings (`clearance_body_text`, `clearance_closing_text`) allow institutions to customise the letter body and closing paragraph.
- **Clearance letter: institution logo on printed letter** — The public clearance letter now shows the `app_logo_url` image alongside institution name, subtitle, address, phone, and email.
- **Master: `create_creator/1`** — New context function to create a `Creator` record directly.

### Changed

- **Clearance letter: redesigned letter header** — Header now uses a double-rule border and shows logo, subtitle, name, address, phone, and email in a structured layout.
- **Clearance letter: reuse existing issued letter** — If a member already has an active clearance letter, the page now redirects to the existing letter instead of creating a duplicate.
- **Fine calculation: off-by-one day fix** — Overdue day count no longer subtracts an extra day from the due date.
- **Clearance letter number padding removed** — Letter sequence is no longer zero-padded to 4 digits.
- **Translation** - Updated some Indonesian translations and added missing ones for the clearance letter.

### Fixed

- **JSONB settings corruption** — `plugins.ex` and `schema/system.ex` now use `type(^map, :map)` instead of `Jason.encode!` to prevent double-encoding of JSONB settings.
- **`Scope.for_user/1` nil guard** — Returns an empty `%Scope{}` instead of `nil` when called with `nil`.
- **`paid_amount` and `fine_amount` decimal defaults** — Use `Decimal.new("0")` instead of bare integers/floats to avoid type mismatches.
- **`Requisition` foreign key constraint** — Added `foreign_key_constraint` on `requested_by_id`.

## [0.1.21] - 2026-04-20

### Added

- **Digital/physical collection filtering** — Public search and frontend collection browsing now support a `Media Type` filter, allowing users to narrow collections to `Digital Only`, `Physical Only`, or `All Media`.

### Changed

- **Collection search and browse query handling** — Updated search query builders to filter by primary collection attachments for digital/physical collection classification.
- **Date/time display formatting** — Frontend collection and loan date rendering now shifts UTC dates to Asia/Jakarta (WIB/GMT+7) before formatting.

## [0.1.20] - 2026-04-17

### Added

- **Collection review: create new creator from review modal** — Reviewers can now type a creator name in the collection review metadata editor and click a dedicated `Create` button to create and select a new `mst_creator` without leaving the review flow.

## [0.1.19] - 2026-04-17

### Added

- **Collection import now creates items** — CSV import creates N item records per collection based on the `total_items` column (with duplicate row sums). Items are auto-generated with `item_code`, `inventory_code`, and `barcode` via `ItemHelper`, matching the manual "Add Item Data" form behaviour. Defaults: `status: "active"`, `condition: "good"`, `availability: "in_processing"`.
- **Stock opname: batched approval processing** — Rewrote `do_apply_session_changes` to process `batch_mark_missing` and `batch_apply_item_changes` in small cursor-based batches instead of a single giant transaction. Prevents Postgrex checkout timeouts on large sessions (100k+ items).
- **Stock opname: real-time approval progress bar** — The review page now shows a live progress bar with step labels and percentage during background approval via PubSub broadcasts.
- **Stock opname: batched `complete_session`** — `complete_session` now flags pending items as missing in batches of 5,000 using cursor-based pagination instead of a single `update_all`.
- **Stock opname: review notes and rejection banners** — The session show page now displays an amber "Revision Requested" banner when `review_notes` is present (in_progress status) and a red "Session Rejected" banner when `rejection_reason` is present (rejected status).
- **Stock opname: 10 new tests for reject/revision workflows** — Added tests for `reject_session`, `request_session_revision` (reset librarian work_status, clear completed_at), and additional batched processing tests (progress messages, multi-batch coverage, mixed checked items).

### Fixed

- **Critical: Stock opname approval timeout on large sessions** — Sessions with ~196k items crashed with Postgrex timeout because the entire approval ran in a single long transaction. Now uses cursor-based pagination (`WHERE id > last_id ORDER BY id LIMIT batch_size`) instead of OFFSET-based queries, avoiding O(n²) degradation.
- **Stock opname: revision not resetting librarian assignments** — `request_session_revision` now uses `Ecto.Multi` with `update_all` to reset all librarian `work_status` to `"assigned"` and clear `completed_at`, so librarians can resume work after a revision request.
- **Stock opname: misleading revision flash message** — Changed flash from "Librarians have been notified" to "Librarians can view the notes on the session page" since there is no push notification.
- **Collection import/export: RBAC node scoping enforced server-side** — `export_csv` and `confirm_import` handlers now force the user's own `node_id` for non-super-admin users, preventing crafted events from accessing other nodes' data.
- **Collection export: no loading feedback** — Export button now shows a spinner with "Exporting…" text and disabled state while generating the CSV.
- **Item lookup: broadened barcode/code matching** — `find_item_by_barcode` in `Catalog` and `find_item_by_code` in `Transact` now search across `barcode`, `item_code`, `inventory_code`, `legacy_item_code`, and numeric `id` in a single query instead of sequential fallbacks.
- **Production DB timeouts for batch operations** — Added `queue_target: 5_000`, `queue_interval: 5_000`, and `timeout: 60_000` to production Repo config in `runtime.exs` to accommodate large batch operations.

## [0.1.18] - 2026-04-16

### Added

- **Bulk member import** — Added a new CSV import page for members at `/manage/members/management/import` with a guided upload flow and sample CSV download.
- **Member CSV export** — Added an export button on the member management page that exports filtered member results to CSV.
- **Sample member import template** — Added a downloadable sample CSV file for member import so users can see the required header structure and example data.
- **Import validation alignment** — Added tests and import mapping coverage to ensure imported member rows are converted into the same attribute shape used by `Accounts.register_user/1`.

## [0.1.17] - 2026-04-16

### Fixed

- Fixed search item to add legacy_barcode_item

## [0.1.15] - 2026-04-16

### Added

- **Read On Spot module** — New library feature for recording in-library reading activity without a formal checkout. Visitors scan item barcodes at a reading station and the event is logged under the library's Read On Spot records.
  - **Scan page** (`/manage/glam/library/read_on_spot/scan`) — Camera-based barcode scanner (with Start/Stop/Switch controls) and manual barcode entry. Records the reading event against the scanned item, node, location, and optionally the logged-in user.
  - **Index page** (`/manage/glam/library/read_on_spot`) — Overview showing today's count, this month's count, and a live stream of the most recent scanned records with Jakarta-localised timestamps.
  - **Report page** (`/manage/glam/library/read_on_spot/report`) — Aggregated daily and monthly report table with node and location filters, paginated (25 rows per page), and clickable rows.
  - **Report Detail page** (`/manage/glam/library/read_on_spot/report/detail`) — Drill-down list of all items scanned on a specific day or month. Shows title, author (from `mst_creator`), barcode, location, and scan time. Supports pagination (20 rows per page) and is accessible by clicking any report row.
- **`Feats` context** (`Voile.Schema.Library.Feats`) — All Read On Spot business logic including `list_read_on_spots/1`, `count_today/1`, `count_this_month/1`, `daily_report/2`, `monthly_report/2`, and `report_detail/1`. All date comparisons use `COALESCE(read_at, inserted_at)` so records with a nil `read_at` are handled correctly. Location joins use `LEFT JOIN` to include records with no assigned location.
- **`ReadOnSpot` schema** — New Ecto schema and migration (`add_read_on_spot_in_library_module`) with fields: `item_id`, `node_id`, `location_id`, `recorded_by_id`, `read_at`, `notes`.
- **Visitor Statistics by Location page** (`/manage/visitor/statistics/node`) — New LiveView showing a monthly visitor totals matrix (rows = locations/nodes, columns = Jan–Dec) for a selected year. Accessible from the Visitor Statistics quick links panel.
- **Visitor Statistics quick links** — Added "Statistics by Location" as a third quick link card on the Visitor Statistics page alongside the existing Visitor Logs and Survey Feedback links.

### Fixed

- **Visitor survey timestamps** — `survey.inserted_at` is now shifted to Asia/Jakarta before formatting in the survey logs table, consistent with other date displays in the app.
- **Jakarta timezone on Read On Spot dates** — All datetime displays across the Read On Spot pages (`add.ex`, `index.ex`, `report_detail.ex`) are wrapped with `FormatIndonesiaTime.shift_to_jakarta/1` before `Calendar.strftime`.

---

## [0.1.14] - 2026-04-15

### Added

- **Combined Import & Export page** — Replaced the old collection import page with a unified Import & Export LiveView at `/manage/catalog/collections/import`. The new page provides a three-step import flow (Upload → Preview → Done) and a sidebar export panel, both scoped per-node.
- **Simplified CSV format for import/export** — Collections can now be imported and exported using a flat, human-readable CSV format (18 columns: `title`, `description`, `thumbnail`, `collection_type`, `access_level`, `status`, `creator_name`, `resource_class`, `language`, `publisher`, `date_published`, `isbn`, `subject`, `location`, `condition`, `availability`, `total_items`, `metadata`). `creator_name` is resolved or created automatically; `resource_class` is matched by label string.
- **Per-node import and export** — Both import and export can be scoped to a specific library branch. The selected node is used to set `unit_id` and generate the `collection_code` on imported records.
- **RBAC node scoping on import/export** — `super_admin` users see a full node dropdown and can select any branch. Staff and admin users have their node fixed to their own `user.node_id` (read-only display, no dropdown). The node cannot be changed server-side by non-super-admins even via crafted events.
- **Downloadable sample CSV** — A sample import file is available at `/sample_collection_import.csv` and linked from the CSV format guide on the import page.
- **In-file duplicate merging** — During CSV parse/preview, rows with the same `title` + `creator_name` (case-insensitive) are automatically merged into a single row with their `total_items` summed. The preview header shows an amber "N duplicates merged" badge when merging occurred.
- **DB duplicate detection** — Before inserting each imported collection, the importer checks the database for an existing collection matching `title` + `creator_id` + `type_id` + `collection_type` + `node`. Matching records are skipped (not re-inserted). The Done screen reports separate counts for imported, skipped, and failed rows.
- **Collection show: enriched metadata** — The frontend collection detail page now displays `collection_code` (monospace badge), `resource_class.label`, and last-updated date in the metadata grid. A new "Bibliographic Details" section renders all `collection_fields` (sorted by `sort_order`) between the header and parent/children cards. A "Catalog Reference" sidebar card shows the code, resource type, and creator link.
- **Collection card: code and resource class badges** — `collection_card` component now renders the `collection_code` as a monospace badge and `resource_class.label` as an indigo badge alongside the existing status badge.
- **Item show: collection cover** — The item detail page now uses the parent collection's `thumbnail` as the cover image (with a gradient fallback when nil). Also added `barcode` field (with QR code icon) and `last_inventory_date` field (with clipboard icon), both conditional on having a value.

### Fixed

- **Search: double-space and Unicode query handling** — Collection and item search now normalises queries before building ILIKE patterns: collapses multiple spaces, converts Unicode curly quotes to straight quotes, and converts en/em dashes to hyphens. Titles are also matched with a word-split `%word%word%` pattern so multi-word queries like `Everyman's Encyclopaedia Volume 1 A - Barter` return results regardless of internal spacing.
- **Search: dead JOIN removal** — Removed unused `CollectionField` and `ItemFieldValue` LEFT JOINs from advanced query builders in `search.ex`, eliminating unnecessary table scans. Also removed `:collection_fields` and `:items` from `search_collections` preloads and fixed the `paginate_results` count query to use `exclude(:order_by)`.

---

## [0.1.13] - 2026-04-13

### Fixed

- **OpenTelemetry and PromEx config moved out of compile-time** — The OpenTelemetry exporter and PromEx metrics push configuration blocks were incorrectly placed in `config/config.exs`, which is evaluated at compile time. Since these blocks read from `System.get_env`, the env vars were not available during compilation in release builds, causing the configuration to silently fall back to no-op defaults regardless of what was set at runtime. Both blocks have been removed from `config.exs` and consolidated into `config/runtime.exs`. `config.exs` now only holds a static base PromEx config with `manual_metrics_configuration: []`.
- **OpenTelemetry and PromEx monitoring no longer prod-only** — The observability configuration block in `config/runtime.exs` was previously nested inside the `if config_env() == :prod do` guard, meaning OpenTelemetry traces and PromEx metrics push would never activate in development even when the relevant env vars were set. The monitoring blocks are now placed outside the prod guard so they apply in all environments when `VOILE_OTEL_EXPORTER_ENDPOINT` or `VOILE_OPENOBSERVE_METRICS_URL` are configured.

---

## [0.1.12] - 2026-04-13

### Fixed

- **Google Analytics layout fix** — Corrected `lib/voile_web/components/layouts/root.html.heex` to use `Elixir.System.get_env/1` for `VOILE_GOOGLE_ANALYTICS_ID`, avoiding the local `System` alias conflict.

---

## [0.1.11] - 2026-04-13

### Added

- **OpenTelemetry support** — Added optional trace export configuration for OpenTelemetry via `VOILE_OTEL_EXPORTER_ENDPOINT`.
- **OpenObserve integration** — Added optional PromEx metrics push and OpenObserve-specific configuration for observability.
- **Google Analytics support** — Added optional Google Analytics tracking integration via `VOILE_GOOGLE_ANALYTICS_ID`.
- **Observability documentation** — Added new docs under `docs/integrations/observability` describing OpenObserve setup, supported environment variables, and future monitoring tool plans.

### Changed

- Updated architecture documentation to reflect Voile as a full GLAM platform with Gallery, Library, Archive, and Museum domains.

---

## [0.1.10] - 2026-04-10

### Fixed

- **Critical: Missing fine_per_day causes infinite fine calculation** — If a member type's `fine_per_day` is not set (nil) or set to zero, the system was previously treating it as a zero daily fine, which caused the total fine amount to also be zero regardless of how many days overdue. This could lead to confusion and incorrect fine waivers. The fix is to treat nil or zero `fine_per_day` as a default of 1000 (currency units) per day, ensuring that overdue items accrue fines properly even if the member type configuration is incomplete. This change affects both the fine calculation logic in `Voile.Library.Circulation` and the member type defaults when fetching member type details.

---

## [0.1.9] - 2026-04-10

### Added

- **Requisition workflow** — Added library requisition pages in the frontend and dashboard, including new circulation schema support and requisition helpers.

### Fixed

- **Plugin access control** — Fixed plugin access and dashboard routing so plugin pages now respect the correct authorization rules.
- **Node-scoped circulation actions** — Librarians can no longer Return, Extend, Waive, or Pay items and fines that belong to a different node. In the **Current Loans** tab, the Return and Extend buttons are now replaced with a read-only "Loaned from {Node}" badge when the item's node does not match the librarian's node. In the **Fines** tab, the Waive and Pay buttons are similarly replaced with a "Managed by {Node}" badge for fines originating from another node. Super admins bypass this restriction and always see all action buttons.

---

## [0.1.8] - 2026-04-06

### Added

- **Member identifier display** — The member management table now shows an
  `Identifier` column beside `Member Type` for faster lookup.
- **Identifier-aware search** — The members search input now matches identifier
  values in addition to name, email, and username.

### Fixed

- **Barcode label rendering** — Label printing now encodes the full stored
  barcode value instead of truncating it.
- **Barcode readability** — Increased the barcode value font size and weight on
  labels to make long barcode strings easier for librarians to read.

---

## [0.1.7] - 2026-04-05

### Added

- **Contact & Social settings** — Added `app_email`, `app_instagram_url`, and
  `app_contact_number` settings (IDs 22–24) to the System Settings dashboard
  (`SettingLive`). These are used in email templates and public-facing contact
  information. Settings are editable via a new "Contact & Social Settings" form
  card on the settings overview page.
- **Dynamic contact info on item detail page** — The "Need Help?" sidebar on
  `/items/:id` now reads `app_contact_number` and `app_email` from the settings
  store instead of the previously hardcoded values. Each entry is a clickable
  link (WhatsApp/tel for contact number, `mailto:` for email) and only renders
  if the setting is configured.

### Fixed

- **`mix hex.build` hard-fail on heroicons** — Newer Hex versions reject packages
  with non-Hex dependencies. Restored `only: :dev` on the heroicons GitHub dep so
  it is excluded from the published package. Added a `files:` whitelist to
  `package/0` to also exclude `priv/static/uploads/` and compiled asset bundles,
  keeping the tarball well under the 128 MB limit.
- **Production container builds with `heroicons: only: :dev`** — Since heroicons
  is now dev-only, `mix deps.get --only prod` no longer fetches it. The
  `Containerfile` now has a dedicated `git clone --depth=1` step that fetches
  only the `optimized/` SVG tree before `mix assets.deploy`, replicating what
  `mix deps.get` previously did. The same fix is applied to `pustaka/Containerfile`.

---

## [0.1.6] - 2026-04-05

### Revert

- Revert publishing Voile to Hex.pm. Planning to only use tags for releases and publishing only in Github.

---

## [0.1.5] - 2026-04-05

### Fixed

- Revert the deps and Containerfile changes from v0.1.4 that were meant for `pustaka` but accidentally got merged into `voile`. The `heroicons` dependency is only needed in `pustaka` for asset compilation, not in `voile`, and the extra `mix deps.get` command is also only needed in `pustaka`. These changes have been re-applied to the correct repo (`pustaka`) in a separate commit.

---

## [0.1.4] - 2026-04-05

### Fixed

- Small fix in mix dependency for heroicons

---

## [0.1.3] - 2026-04-05

### Fixed

- Default Seeds, Visitor Display and other stuffs that should be in the `pustaka` repo, not `voile`, have been moved to the correct repo. This was causing confusion and merge conflicts since `voile` is the core engine and `pustaka` is the GLAM-specific implementation.

---

## [0.1.2] - 2026-04-05

### Added

- Auto-release active locker sessions on visitor checkout when the
  `locker_luggage` plugin is installed and the visitor has an active locker
  session.

### Fixed

- Guarded plugin settings access to super admins and made the plugin settings
  sidebar render correctly when the current plugin is loaded.
- Prevent duplicate hook registrations in `Voile.Hooks` when the same handler
  and owner are registered multiple times.

### Changed

- Added `Plugins` to the main dashboard and mobile sidebar navigation.
- Plugin routing now forwards auth state into nested plugin LiveViews so plugin
  pages render correctly for current user roles.
- `visitor_identifier` is now included in `:visitor_check_in_panels` hook payloads
  for better plugin integration.

---

## [0.1.1] - 2026-04-04

### Fixed

- **Critical: RAM exhaustion on pages using LiveStream tables** — `table/1` in
  `core_components.ex` had an infinite recursion bug introduced in v0.1.0. The
  `LiveStream`-detecting clause called `table(assigns)` after enriching assigns,
  but `assigns.rows` was still a `%LiveStream{}`, so the same clause re-matched
  forever. Each recursive call allocated a new assigns map, exhausting heap memory
  and crashing the process. Fixed by extracting rendering into a private
  `do_table/1` that both public clauses delegate to. Affected pages:
  `/manage/master/locations` and `/manage/master/member_types`.
- **Performance: settings DB queries on every render** — `get_setting_value/2`
  was issuing a `Repo.get_by` on every call with no caching. Since settings are
  read on every page render (app name, logo, colours) but almost never change,
  results are now cached in `:persistent_term`. Cache is invalidated on
  `create_setting/1` and `update_setting/2`.
- **Performance: nav bar double DB call** — The `nav_bar` component was calling
  `get_setting_value("app_logo_url")` twice per render (once in the `if` guard,
  once in the `src` attribute). Reduced to a single call via a temporary assign.

---

## [0.1.0] - 2026-04-04

Initial public release of Voile — a GLAM (Gallery, Library, Archive, Museum)
management system built with Elixir and Phoenix LiveView.

### Catalog

- Collection management with hierarchical structure support
- Item cataloging with customizable metadata resource classes
- MARC-compatible metadata properties system
- Full-text and trigram search across collections and items
- Attachment system for digital assets (polymorphic, multi-type)
- External book search integration (ISBN lookup & enrichment)
- OAI-PMH metadata harvesting endpoint

### Circulation

- Visitor check-in and check-out flow with per-node support
- Member management with borrowing history
- Fine calculation and payment tracking
- Stock opname (inventory count) module with CSV import/export

### Authentication & Access Control

- Role-based access control (RBAC) with GLAM-specific roles:
  `super_admin`, `librarian`, `archivist`, `gallery_curator`, `museum_curator`
- `glam_type` scoping — roles constrained to institution type
- `phx.gen.auth`-based authentication with email/password
- OAuth 2.0 / SSO via Assent
- Audit logging with IP, user agent, and session tracking
- Fine-grained collection-level permissions

### GLAM Configuration

- Multi-GLAM instance support (one database, multiple institution profiles)
- Per-GLAM settings and branding
- Node (branch / service desk) management
- Master data management (subjects, classifications, languages, etc.)

### Plugin System

- OTP-application based plugin architecture
- `Voile.Plugin` behaviour contract
- `Voile.Hooks` action/filter system (`:persistent_term`-backed, zero-cost reads)
- `Voile.PluginManager` — install, activate, deactivate, uninstall, update lifecycle
- Per-plugin database migrations via `Voile.Plugin.Migrator`
- Per-plugin settings with a dynamic schema-driven form
- Dynamic plugin routing at `/manage/plugins/:plugin_id/*path`
- Plugin navigation sidebar with `nav/0` callback
- Plugin discovery from loaded OTP applications

### Dashboard & UI

- Phoenix LiveView dashboard with real-time updates
- Analytics overview
- Search dashboard
- Notification system (LiveView push)
- Cloudflare Turnstile CAPTCHA integration
- Dark mode support

### Developer

- Swagger / OpenAPI documentation (`/api/swagger`)
- Phoenix LiveDashboard at `/dev/dashboard` (dev only)

[0.1.34]: https://github.com/curatorian/voile/compare/v0.1.33...v0.1.34
[0.1.33]: https://github.com/curatorian/voile/compare/v0.1.32...v0.1.33
[0.1.32]: https://github.com/curatorian/voile/compare/v0.1.31...v0.1.32
[0.1.31]: https://github.com/curatorian/voile/compare/v0.1.30...v0.1.31
[0.1.30]: https://github.com/curatorian/voile/compare/v0.1.29...v0.1.30
[0.1.29]: https://github.com/curatorian/voile/compare/v0.1.28...v0.1.29
[0.1.27]: https://github.com/curatorian/voile/compare/v0.1.26...v0.1.27
[0.1.26]: https://github.com/curatorian/voile/compare/v0.1.25...v0.1.26
[0.1.25]: https://github.com/curatorian/voile/compare/v0.1.24...v0.1.25
[0.1.28]: https://github.com/curatorian/voile/compare/v0.1.27...v0.1.28
[0.1.24]: https://github.com/curatorian/voile/compare/v0.1.23...v0.1.24
[0.1.23]: https://github.com/curatorian/voile/compare/v0.1.22...v0.1.23
[0.1.19]: https://github.com/curatorian/voile/compare/v0.1.18...v0.1.19
[0.1.18]: https://github.com/curatorian/voile/compare/v0.1.15...v0.1.18
[0.1.15]: https://github.com/curatorian/voile/compare/v0.1.14...v0.1.15
[0.1.14]: https://github.com/curatorian/voile/compare/v0.1.13...v0.1.14
[0.1.13]: https://github.com/curatorian/voile/compare/v0.1.12...v0.1.13
[0.1.7]: https://github.com/curatorian/voile/compare/v0.1.6...v0.1.7
[0.1.2]: https://github.com/curatorian/voile/compare/v0.1.1...v0.1.2
[0.1.1]: https://github.com/curatorian/voile/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/curatorian/voile/releases/tag/v0.1.0
