# Changelog

All notable changes to Voile will be documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

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

[0.1.19]: https://github.com/curatorian/voile/compare/v0.1.18...v0.1.19
[0.1.18]: https://github.com/curatorian/voile/compare/v0.1.15...v0.1.18
[0.1.15]: https://github.com/curatorian/voile/compare/v0.1.14...v0.1.15
[0.1.14]: https://github.com/curatorian/voile/compare/v0.1.13...v0.1.14
[0.1.13]: https://github.com/curatorian/voile/compare/v0.1.12...v0.1.13
[0.1.7]: https://github.com/curatorian/voile/compare/v0.1.6...v0.1.7
[0.1.2]: https://github.com/curatorian/voile/compare/v0.1.1...v0.1.2
[0.1.1]: https://github.com/curatorian/voile/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/curatorian/voile/releases/tag/v0.1.0
