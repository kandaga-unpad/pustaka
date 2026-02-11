# Voile GLAM Management System — Comprehensive Manual

This document explains the Voile project for three audiences: programmers (developers), librarians (collection managers), and end-users (visitors/curators). It describes the system's architecture, data schema, important modules, developer setup and workflows, librarian operations, and user interactions. Use this as a reference to understand, modify, and operate the system.

> NOTE: This guide was generated from the repository structure and common Phoenix/Elixir conventions. Refer to specific modules and files in the `lib/` and `config/` directories for deeper implementation details.

## Table of contents

- Overview
- Audience-specific guides
  - For programmers (developers)
  - For librarians (GLAM staff)
  - For end users (visitors / curators)
- Data model / schema
- Important modules and responsibilities
- Developer setup and common tasks
- Librarian workflows (cataloging, managing collections)
- User-facing features and interactions
- Maintenance, testing, and deployment
- Troubleshooting and FAQ
- Appendix: Useful file locations

## Overview

Voile is a GLAM (Galleries, Libraries, Archives, Museums) management system built with Elixir and Phoenix. It provides facilities to manage collections, catalog items, track provenance and metadata, and to present public or private catalogs through a web UI.

The project uses standard Phoenix conventions with a web layer in `lib/voile_web/` and domain logic in `lib/voile/`. Static assets are in `assets/` and configuration in `config/`.

## Audience-specific guides

### For programmers (developers)

What you need to know:

- Language & Framework: Elixir (>= 1.14 recommended) and Phoenix (1.6/1.7 conventions likely). Mix is the build tool. Dependencies are managed by `mix.exs` and `mix.lock`.
- Repo layout highlights:
  - `lib/voile/` — core application logic, contexts, schemas
  - `lib/voile_web/` — web interface: controllers, channels, LiveView components, templates
  - `priv/repo/` — (if present) migrations and seeds
  - `config/` — runtime configuration for environments
  - `assets/` — JS/CSS build pipeline files
- Running locally:
  - Install Elixir and Erlang/OTP.
  - Install Node.js (for asset tooling) and `esbuild`/`tailwind` as required by the project.
  - Typical commands:
    - mix deps.get
    - mix ecto.setup (if an Ecto repo is configured) or refer to project's specific setup
    - mix phx.server
  - Tests: `mix test`

Development practices:

- Follow the project's Elixir formatting and linting rules (mix format, Credo if present).
- Write unit tests for contexts and LiveView tests for interactions.
- For database changes use migrations and keep them small and reversible.
- Pay attention to contexts — group domain logic into context modules (e.g., `Catalog`, `Collections`, `Items`).

Contract/shape guidance for modules:

- Context functions should accept simple inputs (maps/structs) and return `{:ok, result}` or `{:error, changeset}` for DB operations.
- LiveViews should handle socket assigns clearly and validate input on change events.

Edge cases to consider:
- Missing or partial metadata for items
- Large batch imports of records
- Concurrent updates to collection records
- Authorization/permission boundaries between librarians and public users

### For librarians (GLAM staff)

This section summarizes how librarians interact with the system to manage collections.

Key concepts:
- Collection: a grouping of items (objects, documents, artworks) with shared metadata and access rules.
- Catalog record: the authoritative metadata record for an item.
- Provenance and rights information are critical fields to maintain.

Common tasks and where to find them in the UI:
- Create a new collection: Use the Collections UI under the Dashboard -> Catalogs area (likely LiveView pages under `lib/voile_web/live/dashboard/catalog/collection_live/`).
- Add items to a collection: Use the collection detail or item creation flows.
- Edit metadata: Use the edit form for items or batch-upload/import functionality if available.
- Searching and filtering: Use the catalog search UI to find items by metadata fields (title, creator, date, subject).

Best practices:
- Follow controlled vocabularies for fields like subject, type, material, and place.
- Keep provenance/rights statements up to date and attach licenses to digital surrogates.
- When importing, validate against the project's schema and run in a staging environment first.

### For end users (visitors, researchers)

The web interface exposes collections and items for browsing and searching. Typical features include:
- Browsing collections by theme, subject, or curator
- Full-text search and faceted filtering
- Item detail pages with metadata, images, and related items
- Account or request workflows if the project supports loans or appointments

Accessibility and usability:
- The UI should provide clear metadata fields, download or request actions, and citation information.
- Provide help text for complex metadata fields and clear licensing information for images and documents.

## Data model / schema (high-level)

The Voile repo typically models a GLAM domain with schemas such as:

- Collection
  - id: uuid or integer
  - title: string
  - description: text
  - published: boolean
  - visibility / access level: enum (public, restricted, private)
  - inserted_at, updated_at

- Item (or CatalogRecord)
  - id
  - collection_id (belongs_to Collection)
  - title
  - creator
  - date_created (free text + structured dates)
  - description
  - language
  - subjects (many-to-many or serialized field)
  - rights / license
  - provenance
  - digital_asset_refs (URLs or attachments)
  - metadata_json (for arbitrary fields)

- User / Account
  - id
  - email
  - role (librarian, curator, public)
  - profile fields

- Audit / ChangeLog (optional)
  - record_id
  - actor_id
  - changes
  - inserted_at

Relations and constraints:
- Collections has_many Items; Items belongs_to Collection.
- Use indexes for commonly searched fields (title, creator, subject).

Note: For precise column names and types, inspect the schema modules in `lib/voile/` and database migrations under `priv/repo/migrations/` if present.

## Important modules and responsibilities

These are likely present in this Phoenix app (adapt names to the actual project):

- lib/voile/catalog.ex — Context module for catalog operations (CRUD for collections and items, search functions)
- lib/voile/catalog/collection.ex — Ecto schema for Collection
- lib/voile/catalog/item.ex — Ecto schema for Item/CatalogRecord
- lib/voile_web/live/** — LiveView modules
  - `dashboard/catalog/collection_live/index.html.heex` — Collection index LiveView template
  - `dashboard/catalog/collection_live/show` — collection/show LiveView
- lib/voile_web/controllers/** — controllers for HTML API
- lib/voile_web/templates/** — server-rendered templates
- lib/voile_web/components/** — UI components used across LiveViews

How modules interact:
- Web controllers and LiveViews call context functions in `Voile` (or `Voile.Catalog`) to load and mutate data.
- Contexts encapsulate business logic and database interactions; they return typed tuples for success/failures.

Integration points:
- Authentication/Authorization: check for `Pow`, `Guardian`, or `phx_gen_auth` in `mix.exs` dependencies.
- Search: use `Postgres` full-text search or external search services (Elasticsearch) via libraries.

## Developer setup and common tasks

Quick start (assumptions — adapt if the project has custom scripts):

1. Install dependencies

- Install Erlang and Elixir (use ASDF or installer for Windows).
- Install Node.js for assets.

2. Setup the project

- Open a terminal in the project root and run:

```
mix deps.get
mix ecto.setup
npm install --prefix assets
mix assets.deploy # or mix phx.server in dev
```

3. Running tests

```
mix test
```

4. Common development tasks

- Add a migration: `mix ecto.gen.migration add_field_to_items`
- Run migration: `mix ecto.migrate`
- Format code: `mix format`
- Start dev server: `mix phx.server`

5. LiveView notes

- Templates end with `.html.heex` and are used by LiveView modules.
- Use `phx-click`, `phx-change`, `phx-submit` attributes for client events.

## Librarian workflows (practical steps)

- Create a collection
  - In the Dashboard -> Catalogs page, click "New Collection".
  - Fill title, description, visibility, and other fields.
  - Save to create collection.

- Add items
  - From a collection page, choose "Add Item" or "New Catalog Record".
  - Fill metadata; attach images or files using the provided form (drag-and-drop or upload field).

- Bulk import
  - If the system supports CSV or EAD import, prepare files following the sample import schema.
  - Use the import tool (look for `scripts/` or `priv/repo/seeds` scripts) to upload. Run in staging first.

- Edit and publish
  - Use edit forms to update metadata.
  - Toggle `published` or `visibility` to control public access.

- Deaccessioning
  - Mark items as deaccessioned with an audit note.
  - Ensure provenance and disposition fields are recorded.

## User-facing features and interactions

- Browse: Navigate collections and click through to item detail pages.
- Search: Use the search bar to find items by keywords and apply filters.
- Request/Acquire: If the project supports requests, sign in and submit a request from the item page.
- Export/Citation: Use the citation/export actions to get bibliographic metadata.

## Maintenance, testing, and deployment

- CI: Add `mix test` and `mix format --check-formatted` to CI.
- Backup: Schedule DB backups and archive digital assets.
- Deploy: Follow existing deployment strategy (release with `mix release`, Docker image, or Gigalixir). Check `mix.exs` for `release` config.

Quality gates (recommendations):
- Unit tests for contexts
- Integration tests for LiveViews
- E2E tests for core flows (optional)

## Troubleshooting and FAQ

Q: The UI shows empty metadata fields for imported records.
A: Check the CSV mapping and confirm the import script maps columns to schema fields.

Q: Images not showing on item pages.
A: Verify file storage (local `priv/static` or external S3) and correct URLs. Inspect browser console for 404s.

Q: How to add a new metadata field?
A: Add a DB migration, update the Ecto schema, update context functions, and update forms/templates.

## Appendix: Useful file locations

- Core app: `lib/voile/`
- Web UI: `lib/voile_web/`
  - LiveView templates: `lib/voile_web/live/`
  - Dashboard collection LiveView: `lib/voile_web/live/dashboard/catalog/collection_live/` (includes `index.html.heex`)
- Config: `config/`
- Assets: `assets/` and `css/`, `js/`
- Scripts: `scripts/` (importers, sample CSVs)

## Final notes

This manual is a high-level guide. For code-level changes and precise schema definitions, scan the Ecto schema modules in `lib/voile/` and the migration files in `priv/repo/migrations/` if present. If you'd like, I can:

- Generate a more detailed developer README that includes exact commands discovered from `mix.exs` and `config/`.
- Extract and document the actual Ecto schemas and fields into this manual.
- Produce a quick-start librarian cheat-sheet PDF or printable card.

If you want me to extract exact schema definitions and module descriptions from the repo, say "Yes — extract schemas" and I'll parse them and update this manual with exact types and field lists.