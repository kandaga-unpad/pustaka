# Changelog

All notable changes to Voile will be documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

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

[Unreleased]: https://github.com/your-org/voile/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/your-org/voile/releases/tag/v0.1.0
