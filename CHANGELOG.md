# Changelog

All notable changes to Voile will be documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

[0.1.2]: https://github.com/curatorian/voile/compare/v0.1.1...v0.1.2
[0.1.1]: https://github.com/curatorian/voile/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/curatorian/voile/releases/tag/v0.1.0
