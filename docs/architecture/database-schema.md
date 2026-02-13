# Database schema & infrastructure (comprehensive)

This document is a single authoritative reference that merges the high-level overview and the full per-table breakdown of the database schema defined by the project's Ecto migrations. It includes:

- Global DB-level configuration (extensions, custom types)
- ID/type conventions and use of JSONB/arrays
- Indexing patterns, constraints and performance notes
- A per-table reference (columns, types, nullability, defaults)
- Foreign keys, indexes, unique/partial/check constraints and important notes

Canonical source: `priv/repo/migrations/` — consult the migrations for authoritative, line-level details and historical evolution.

---

Contents
- Global / infra-level items
- Conventions & cross-cutting notes
- Per-table reference (alphabetical-ish by domain)
  - Authentication & users
  - RBAC / permissions
  - Metadata, resources & templates
  - Catalog: collections, items & fields
  - Attachments & access control
  - Library / circulation domain
  - Stock opname / transfers / payments / logs / settings
- Maintenance tips and quick inspection SQLs
- Next steps you can request

---

## Global / infra-level items

- Extensions
  - `citext` — case-insensitive text (used for usernames, emails).
  - `pg_trgm` — trigram indexes to optimize ILIKE / fuzzy searches.

- Custom Postgres enum types (created via `execute` in migrations)
  - `glam_type` — 'Gallery', 'Library', 'Archive', 'Museum'
  - `transaction_type` — loan/return/renewal/lost_item/damaged_item/cancel
  - `transaction_status` — active/returned/overdue/lost/damaged/canceled
  - `reservation_status` — pending/available/picked_up/expired/cancelled
  - `fine_type`, `fine_status`
  - `circulation_event_type`
  - `patron_request_type`, `patron_request_status`

- ID & key conventions
  - Many domain tables use `:binary_id` (UUID) as primary keys. Migrations typically declare `primary_key: false` then `add :id, :binary_id, primary_key: true`.
  - Some system/master tables (e.g., `nodes`) use integer / bigint primary keys — pay attention when referencing/mapping units.
  - Foreign keys generally follow the referenced PK type. Many `users` references use `type: :binary_id`.
  - Timestamps use `type: :utc_datetime` across migrations.

- JSON, maps & arrays
  - JSONB (`:map`) used widely for flexible metadata (attachments.metadata, collection_logs.old_values/new_values, stock_opname_items.changes, etc).
  - Array columns used for sets: `node_ids` in stock opname sessions, `scopes` in API tokens, `groups` on users.

- Indexing & query optimization patterns
  - Trigram GIN indexes (gin_trgm_ops) applied to many text columns to speed ILIKE/fuzzy searches.
  - JSONB GIN indexes for metadata columns.
  - Partial indexes for common high-selectivity queries (e.g., available items, published collections, active loans, unpaid fines).
  - Hash indexes used where equality lookups are frequent (applied via raw SQL).
  - Covering indexes (using `INCLUDE`) created via raw SQL for index-only scans on listing queries.
  - Statistics (`ALTER TABLE ... SET STATISTICS`) tuned for specific text columns to improve planner estimates.

- Constraints & data integrity
  - Check constraints for domain rules (barcode lengths; date consistency; embargo rules; schedule day_of_week).
  - Unique and partial-unique indexes for business uniqueness (collection_code, item_code, old_biblio_id per unit).
  - Foreign keys use `on_delete` semantics chosen per domain: `:nilify_all`, `:delete_all`, `:restrict` as appropriate.

---

## Conventions & cross-cutting notes

- Audit fields: many tables include `created_by_id`, `updated_by_id`, `processed_by_id`, etc., referencing `users` and indexed for queries/audit.
- Polymorphism: `attachments` implements polymorphic relationships via `attachable_id` and `attachable_type`. Migrations add DB-level checks to restrict allowed types.
- Use of `:binary_id` favors distributed uniqueness and easier replication across nodes; `nodes` remain integer-based.
- When a migration executes raw SQL (e.g., create trigram index), look at the migration file to see both create/drop statements used for reversibility.
- For any schema change, update both migrations and this documentation.

---

## Per-table reference

Below are consolidated entries for each table present in the migrations. Each entry lists primary key, columns (type, nullability, defaults), foreign keys, indexes and notable constraints or SQL actions.

(If you need a CSV/JSON export for this content, I can generate that as a follow-up.)

---

### users
Primary key
- `id` — `:binary_id` (UUID), primary key

Columns (high level)
- `username :citext` (NOT NULL)
- `identifier :numeric` (nullable)
- `email :citext` (NOT NULL)
- `fullname :string`
- `hashed_password :string` (NOT NULL)
- `confirmed_at :utc_datetime`
- `user_image :string`
- `social_media :map` (jsonb)
- `groups {:array, :string}`
- `last_login :utc_datetime`
- `last_login_ip :string`
- Profile fields: `address :text`, `phone_number :string`, `birth_date :date`, `birth_place :string`, `gender :string`, `registration_date :date`, `expiry_date :date`, `organization :string`, `department :string`, `position :string`
- Later additions: `node_id references(:nodes, type: :bigint)`, `user_type_id references(:mst_member_types, type: :binary_id)`, manual suspension fields (`manually_suspended :boolean` default false, `suspension_reason`, `suspended_at`, `suspended_by_id references(:users)`, `suspension_ends_at`)
- `inserted_at`, `updated_at` — timestamps (utc_datetime)

Foreign keys
- `node_id` -> `nodes` (on_delete: :nilify_all)
- `user_type_id` -> `mst_member_types` (on_delete: :nilify_all)
- `suspended_by_id` -> `users` (on_delete: :nilify_all)

Indexes / Unique constraints
- unique: `email`, `username`, `identifier`
- indexes: `confirmed_at`, `last_login`, `node_id`, `user_type_id`, `manually_suspended`, `suspended_by_id`

Notes
- `citext` extension used for username and email (case-insensitive uniqueness).

---

### users_tokens
Primary key
- default numeric id (migration used default table PK)

Columns
- `user_id references(:users, type: :uuid, on_delete: :delete_all)` (NOT NULL)
- `token :binary` (NOT NULL)
- `context :string` (NOT NULL)
- `sent_to :string`
- `authenticated_at :utc_datetime`
- timestamps (inserted_at, updated_at) — updated_at often false in token tables

Indexes / Unique
- index on `user_id`
- unique on `[context, token]`

---

### user_api_tokens
Primary key
- `id :binary_id`

Columns
- `hashed_token :string` (NOT NULL)
- `name :string` (NOT NULL)
- `description :text`
- `scopes {:array, :string}` default `[]`
- `last_used_at :utc_datetime`
- `expires_at :utc_datetime`
- `revoked_at :utc_datetime`
- `ip_whitelist {:array, :string}`
- `user_id references(:users, type: :binary_id, on_delete: :delete_all)` (NOT NULL)
- `user_agent :string`
- `last_used_ip :string`
- timestamps (utc_datetime)

Indexes / Unique
- unique on `hashed_token`
- index on `user_id`, `expires_at`, `revoked_at`

---

### metadata_vocabularies
Primary key
- default integer id

Columns
- `label :string`
- `prefix :string`
- `namespace_url :string`
- `information :text`
- `owner_id references(:users, type: :binary_id)`
- timestamps

Indexes
- index on `owner_id`

---

### metadata_properties
Primary key
- default integer id

Columns
- `label :string`
- `local_name :string`
- `information :text`
- `type_value :string`
- `owner_id references(:users, type: :binary_id)`
- `vocabulary_id references(:metadata_vocabularies)`
- timestamps

Indexes
- index on `owner_id`, `vocabulary_id`
- trigram GIN indexes on `label` and `local_name` added in a separate migration

---

### resource_class
Primary key
- default integer id

Columns
- `label :string`
- `local_name :string`
- `information :text`
- `glam_type :glam_type` (enum)
- `owner_id references(:users, type: :binary_id)`
- `vocabulary_id references(:metadata_vocabularies)`
- timestamps

Indexes & Notes
- index on `owner_id`, `vocabulary_id`
- trigram GIN index on `label` via raw SQL

---

### resource_template
Primary key
- default integer id

Columns
- `label :string`
- `description :text`
- `owner_id references(:users, type: :binary_id, on_delete: :nilify_all)` (NOT NULL)
- `resource_class_id references(:resource_class, on_delete: :nilify_all)` (NOT NULL)
- timestamps

Indexes
- index on `owner_id`, `resource_class_id`

---

### resource_template_properties
Primary key
- `id :binary_id`

Columns
- `position :integer` (NOT NULL)
- `override_label :string`
- `template_id references(:resource_template)`
- `property_id references(:metadata_properties)`
- timestamps

Indexes & Unique
- unique index `[template_id, property_id]` named `template_property_unique`
- indexes on `template_id` and `property_id`

---

### nodes
Primary key
- integer / bigint id

Columns
- `name :string`
- `abbr :string`
- `description :text`
- `image :string`
- timestamps

Indexes / Unique
- unique on `name`
- trigram GIN index on `name` via raw SQL

---

### settings
Primary key
- default integer id

Columns
- `setting_name :string`
- `setting_value :text`
- timestamps

---

### system_logs
Primary key
- default integer id

Columns
- `log_type :string`
- `log_location :string`
- `log_msg :text`
- `log_date :utc_datetime`
- `owner_id references(:users, type: :binary_id)`
- timestamps

Indexes
- index on `owner_id`

---

### mst_creator
Primary key
- default integer id

Columns
- `creator_name :string`
- `creator_contact :string`
- `affiliation :string`
- `type :string`
- timestamps

Indexes
- unique on `creator_name`
- trigram GIN index on `creator_name`

---

### mst_frequency
Primary key
- default integer id

Columns
- `frequency :string`
- `time_increment :integer`
- `time_unit :string`
- timestamps

---

### mst_member_types
Primary key
- `id :binary_id`

Columns (selected)
- `name :string` (NOT NULL)
- `slug :string` (NOT NULL)
- `description :text`
- Various loan/fine/limit fields: `max_items`, `max_days`, `max_renewals`, `max_reserves`, `max_concurrent_loans`, `fine_per_day`, `max_fine`, `membership_fee`, `currency` (size 3, default "IDR"), `can_reserve`, `can_renew`, `digital_access`, `exhibition_preview_access`, discount fields, `membership_period_days`, `auto_renew`, recurrence fields, `priority_level`, `is_active`, `publicly_listed`, `institutional`, `allowed_collections :map`, `metadata :map`
- timestamps

Indexes
- index on `is_active`, `priority_level`

Notes
- `users` table altered to include `user_type_id` referencing this table.

---

### mst_locations
Primary key
- default integer id

Columns
- `location_code :string`
- `location_name :string`
- `location_place :string`
- `location_type :string`
- `description :text`
- `notes :text`
- `is_active :boolean` default true (NOT NULL)
- `node_id references(:nodes, on_delete: :nilify_all)`
- timestamps

Indexes
- unique on `location_code`
- index on `location_type`, `is_active`

---

### mst_places
Primary key
- default integer id

Columns
- `name :string`
- timestamps

---

### mst_publishers
Primary key
- default integer id

Columns
- `name :string`
- `city :string`
- `address :string`
- `contact :string`
- timestamps

---

### mst_topics
Primary key
- default integer id

Columns
- `name :string`
- `type :string`
- `description :text`
- timestamps

---

### collections
Primary key
- `id :binary_id`

Columns
- `collection_code :text` (NOT NULL)
- `title :text` (NOT NULL)
- `description :text`
- `thumbnail :string`
- `status :string` (NOT NULL, default "draft")
- `access_level :string` (NOT NULL, default "private")
- `old_biblio_id :integer`
- `type_id references(:resource_class, on_delete: :nilify_all)` (NOT NULL)
- `template_id references(:resource_template, on_delete: :nilify_all)`
- `creator_id references(:mst_creator, on_delete: :nilify_all)` (NOT NULL)
- `unit_id references(:nodes, on_delete: :nilify_all)` (NOT NULL)
- `created_by_id references(:users, type: :binary_id, on_delete: :nilify_all)`
- `updated_by_id references(:users, type: :binary_id, on_delete: :nilify_all)`
- Later alterations: `parent_id references(:collections, type: :binary_id, on_delete: :nilify_all)`, `sort_order :integer default 1`, `collection_type :string`
- timestamps

Indexes & Constraints
- index on `title`, `type_id`, `template_id`, `creator_id`, `unit_id`, `status`, `access_level`, `created_by_id`
- unique on `collection_code`
- composite indexes: `[:unit_id, :status]` (collections_unit_status_idx), `[:creator_id, :status]` (collections_creator_status_idx)
- partial index on `[:type_id, :unit_id]` where `status = 'published'` (collections_published_idx)
- trigram GIN indexes on `title`, `description`, `collection_code` (raw SQL)
- hash indexes on `status`, `access_level` (raw SQL)
- covering index `collections_listing_covering_idx` (INCLUDE title, thumbnail, collection_code) WHERE status = 'published' (raw SQL)
- unique partial index on `[:unit_id, :old_biblio_id]` when `old_biblio_id IS NOT NULL`
- indexes on `parent_id`, `sort_order`, `collection_type` (trigram GIN on collection_type)

Notes
- `ALTER TABLE ... SET STATISTICS` set for title in migration to improve planner.

---

### items
Primary key
- `id :binary_id`

Columns
- `item_code :text` (NOT NULL)
- `barcode :text` (nullable)
- `inventory_code :text` (NOT NULL)
- `location :text` (NOT NULL)
- `status :string` (NOT NULL, default "active")
- `condition :string` (NOT NULL, default "good")
- `availability :string` (NOT NULL, default "available")
- `price :decimal, precision:10, scale:2`
- `acquisition_date :date`
- `last_inventory_date :date`
- `last_circulated :utc_datetime`
- `rfid_tag :string`
- `legacy_item_code :text`
- `unit_id references(:nodes, on_delete: :nilify_all)` (NOT NULL)
- `collection_id references(:collections, on_delete: :delete_all, type: :binary_id)` (NOT NULL)
- `item_location_id references(:mst_locations, on_delete: :nilify_all)` (nullable)
- Auditing fields added later: `created_by_id`, `updated_by_id` referencing `users` (type: :binary_id)
- timestamps

Indexes & Constraints
- unique: `item_code`, `inventory_code`
- unique partial: `rfid_tag` where not null; `barcode` where not null
- index: `collection_id`, `unit_id`, `location`, `legacy_item_code`, `status`, `availability`
- composite index: `[:collection_id, :status, :availability]` (items_collection_status_availability_idx)
- partial index `items_available_idx` where `status = 'active' AND availability = 'available'`
- trigram GIN indexes on `item_code`, `inventory_code`, `location`, `barcode` (raw SQL)
- hash index on `status` (raw SQL)
- covering index `items_catalog_covering_idx` (INCLUDE item_code, barcode, location) WHERE status = 'active'
- check constraint (via raw SQL): `barcode IS NULL OR length(barcode) BETWEEN 10 AND 20`

Notes
- Statistics tuning applied to columns `item_code` and `barcode`; comments on indexes added in migrations.

---

### collection_fields
Primary key
- `id :binary_id`

Columns
- `name :string` (NOT NULL)
- `label :string` (NOT NULL)
- `value :text`
- `value_lang :string` default "en"
- `type_value :string` (NOT NULL)
- `sort_order :integer` default 1
- `collection_id references(:collections, on_delete: :delete_all, type: :binary_id)` (NOT NULL)
- `property_id references(:metadata_properties, on_delete: :nilify_all)` (NOT NULL)
- timestamps

Indexes
- index: `collection_id`, `property_id`, `name`, `sort_order`
- composite index: `[:collection_id, :property_id]` (collection_fields_collection_property_idx)

---

### collection_logs
Primary key
- `id :binary_id`

Columns
- `title :string`
- `message :text`
- `action :string`
- `ip_address :string`
- `user_agent :text`
- `session_id :string`
- `request_id :string`
- `old_values :map`
- `new_values :map`
- `action_type :string`
- `entity_type :string` default "collection"
- `severity :string` default "info"
- `metadata :map`
- `duration_ms :integer`
- `success :boolean` default true
- `collection_id references(:collections, type: :binary_id)`
- `user_id references(:users, type: :binary_id)`
- timestamps

Indexes
- indexes on `action_type`, `entity_type`, `severity`, `success`, `inserted_at`, `session_id`
- composite indexes: `[:collection_id, :action_type, :inserted_at]`, `[:user_id, :action_type, :inserted_at]`

---

### item_field_values
Primary key
- `id :binary_id`

Columns
- `value :string`
- `locale :string`
- `item_id references(:items, on_delete: :nothing, type: :binary_id)`
- `collection_field_id references(:collection_fields, on_delete: :nothing, type: :binary_id)`
- timestamps

Indexes
- index on `item_id`, `collection_field_id`

Notes
- Trigram index added on `value` in a later migration.

---

### attachments
Primary key
- `id :binary_id`

Columns
- `file_name :string`
- `original_name :string`
- `file_path :string`
- `file_key :string` (added later)
- `file_size :integer`
- `mime_type :string`
- `file_type :string`
- `description :text`
- `sort_order :integer` (default 0)
- `is_primary :boolean` (default false)
- `metadata :map` default `%{}`
- `attachable_id :binary_id` (polymorphic)
- `attachable_type :string` (polymorphic)
- `parent_id :binary_id` (nullable) for folder hierarchy; later modified to reference attachments
- `access_level :string` (default "public") (added later)
- `embargo_start_date, embargo_end_date :utc_datetime`
- `access_settings_updated_by_id references(:users, type: :binary_id)`
- `access_settings_updated_at :utc_datetime`
- `unit_id references(:nodes, type: :integer)` added and later converted to FK
- timestamps

Indexes & Unique
- index on `(attachable_id, attachable_type)`
- index on `file_type`, `is_primary`, `sort_order`
- unique index on `(attachable_id, attachable_type, file_name)` named `attachments_unique_file_per_entity`
- index on `parent_id`
- index on `file_key`, `unit_id`

Constraints
- `attachable_type_must_be_valid` — check constraint restricting attachable_type to a set (initially 'collection','item', extended later: 'asset_vault','folder', and NULL allowed)
- `file_type_must_be_valid` — check allowed file_type values
- `file_size_must_be_positive` — `file_size > 0`
- `sort_order_must_be_non_negative` — `sort_order >= 0`
- Embargo validation: ensure start < end when both present
- `parent_id_fk` check to avoid self-parenting and then proper FK added

Notes
- `attachments` is polymorphic; migration updates made over time to support folders, unit scoping, and file_key for storage backends.

---

### attachment_role_access
Primary key
- `id :binary_id`

Columns
- `attachment_id references(:attachments, type: :binary_id, on_delete: :delete_all)` (NOT NULL)
- `role_id references(:roles, on_delete: :delete_all)` (NOT NULL)
- timestamps (utc_datetime)

Indexes & Unique
- index on `attachment_id`, `role_id`
- unique `(attachment_id, role_id)` named `attachment_role_access_unique`

---

### attachment_user_access
Primary key
- `id :binary_id`

Columns
- `attachment_id references(:attachments, type: :binary_id, on_delete: :delete_all)` (NOT NULL)
- `user_id references(:users, type: :binary_id, on_delete: :delete_all)` (NOT NULL)
- `granted_by_id references(:users, type: :binary_id, on_delete: :nilify_all)` (nullable)
- `granted_at :utc_datetime` (NOT NULL)
- timestamps

Indexes & Unique
- index on `attachment_id`, `user_id`, `granted_by_id`
- unique `(attachment_id, user_id)` named `attachment_user_access_unique`

---

### lib_transactions
Primary key
- `id :binary_id`

Columns
- `transaction_type :transaction_type` (enum, NOT NULL)
- `transaction_date :utc_datetime`
- `due_date :utc_datetime`
- `return_date :utc_datetime`
- `renewal_count :integer` default 0
- `notes :text`
- `status :transaction_status` (enum, NOT NULL)
- `fine_amount :decimal, precision:10, scale:2` default 0.0
- `is_overdue :boolean` default false
- `item_id references(:items, on_delete: :nilify_all, type: :binary_id)` (NOT NULL)
- `member_id references(:users, on_delete: :nilify_all, type: :binary_id)` (NOT NULL)
- `librarian_id references(:users, on_delete: :nilify_all, type: :binary_id)` (NOT NULL)
- `unit_id references(:nodes, on_delete: :nilify_all)` (nullable)
- timestamps

Indexes & Constraints
- indexes: `due_date`, `is_overdue`, `item_id`, `member_id`, `librarian_id`, `status`, `transaction_type`, `transaction_date`
- composite index: `[:member_id, :status, :due_date]` (lib_transactions_member_status_due_idx)
- partial indexes:
  - `lib_transactions_active_loans_idx` where `status = 'active'`
  - `lib_transactions_overdue_idx` where `is_overdue = true AND status = 'active'`
- ordered index via raw SQL: `lib_transactions_date_desc_idx` (transaction_date DESC)
- checks:
  - `transactions_due_date_check`: `due_date IS NULL OR due_date >= transaction_date`
  - `transactions_return_date_check`: `return_date IS NULL OR return_date >= transaction_date`

Notes
- Stats tuning for `due_date` applied in migration.

---

### lib_reservations
Primary key
- `id :binary_id`

Columns
- `reservation_date :utc_datetime` (NOT NULL)
- `expiry_date :utc_datetime`
- `notification_sent :boolean` default false
- `status :reservation_status` (enum, NOT NULL)
- `priority :integer` default 1
- `notes :text`
- `pickup_date :utc_datetime`
- `cancelled_date :utc_datetime`
- `cancellation_reason :text`
- `item_id references(:items, on_delete: :nilify_all, type: :binary_id)` (NOT NULL)
- `member_id references(:users, on_delete: :nilify_all, type: :binary_id)` (nullable)
- `collection_id references(:collections, on_delete: :nilify_all, type: :binary_id)` (nullable)
- `processed_by_id references(:users, on_delete: :nilify_all, type: :binary_id)` (nullable)
- timestamps

Indexes & Constraints
- indexes: `item_id`, `collection_id`, `member_id`, `status`, `reservation_date`, `expiry_date`, `priority`, `member_id,status`
- partial index `lib_reservations_active_idx` for `(item_id, status)` where status IN ('pending','available')
- checks:
  - `item_or_collection_check`: `item_id IS NOT NULL OR collection_id IS NOT NULL`
  - `reservations_expiry_date_check`: `expiry_date IS NULL OR expiry_date >= reservation_date`

---

### lib_fines
Primary key
- `id :binary_id`

Columns
- `fine_type :fine_type` (enum)
- `amount :decimal, precision:10, scale:2` (NOT NULL)
- `paid_amount :decimal, precision:10, scale:2` default 0.0
- `balance :decimal, precision:10, scale:2`
- `fine_date :utc_datetime` (NOT NULL)
- `payment_date :utc_datetime`
- `fine_status :fine_status` (enum, NOT NULL)
- `description :text`
- waiver fields: `waived :boolean` default false, `waived_date :utc_datetime`, `waived_reason :text`, `waived_by_id references(:users, type: :binary_id)`
- `payment_method`, `receipt_number`
- `member_id references(:users, type: :binary_id, on_delete: :nilify_all)` (NOT NULL)
- `item_id references(:items, type: :binary_id, on_delete: :nilify_all)` (NOT NULL)
- `transaction_id references(:lib_transactions, type: :binary_id)` (nullable)
- `processed_by_id references(:users, type: :binary_id)` (nullable)
- timestamps

Indexes & Constraints
- indexes: by member, item, transaction_id, processed_by_id, fine_type, fine_status, fine_date, payment_date, waived
- composite index `[:member_id, :fine_status]`
- partial index `lib_fines_unpaid_idx` where `fine_status IN ('pending','partial_paid')` on `(member_id, fine_status, balance)`
- checks:
  - `balance_non_negative`: `balance >= 0`
  - `paid_amount_non_negative`: `paid_amount >= 0`
  - `fines_paid_amount_check`: `paid_amount <= amount`

---

### lib_circulation_history
Primary key
- `id :binary_id`

Columns
- `event_type :circulation_event_type` (enum, NOT NULL)
- `event_date :utc_datetime` (NOT NULL)
- `description :text`
- `old_value :map`
- `new_value :map`
- `ip_address :string`
- `user_agent :text`
- `member_id references(:users, type: :binary_id)`
- `item_id references(:items, type: :binary_id)`
- `transaction_id references(:lib_transactions, type: :binary_id)`
- `reservation_id references(:lib_reservations, type: :binary_id)`
- `fine_id references(:lib_fines, type: :binary_id)`
- `processed_by_id references(:users, type: :binary_id)` (NOT NULL)
- timestamps

Indexes
- indexes on `event_type`, `event_date`, `member_id`, `item_id`, `processed_by_id`

---

### lib_requisitions
Primary key
- `id :binary_id`

Columns
- `request_date :utc_datetime` (NOT NULL)
- `request_type :patron_request_type` (enum, NOT NULL)
- `status :patron_request_status` (enum, NOT NULL, default 'submitted')
- `title :text` (NOT NULL)
- `author`, `publisher`, `isbn`, `publication_year`, `description`, `justification`, `priority` (default 'normal'), `estimated_cost`, `notes`, `staff_notes`, `due_date`, `fulfilled_date`
- `requested_by_id references(:users, type: :binary_id, on_delete: :nilify_all)` (NOT NULL)
- `assigned_to_id references(:users, type: :binary_id)` (nullable)
- `unit_id references(:nodes)` (nullable)
- timestamps

Indexes
- indexes on `request_type`, `request_date`, `requested_by_id`, `assigned_to_id`, `unit_id`, `status`, `priority`, `due_date`

---

### lib_holidays
Primary key
- `id :binary_id`

Columns
- `name :string` (NOT NULL)
- `holiday_date :date` (nullable; schedule entries may omit date)
- `holiday_type :string` (NOT NULL)
- `is_recurring :boolean` default false (NOT NULL)
- `description :text`
- `is_active :boolean` default true (NOT NULL)
- `unit_id references(:nodes, on_delete: :delete_all)` (nullable)
- `day_of_week :integer` (nullable) — 1=Monday..7=Sunday
- `schedule_type :string` (NOT NULL, default 'holiday') — 'holiday' or 'schedule'
- timestamps

Indexes & Unique
- many indexes for holiday_date, holiday_type, is_active, unit_id, day_of_week, schedule_type and combos
- unique partial index on `(holiday_date, holiday_type, unit_id)` where schedule_type = 'holiday'
- unique partial index on `(day_of_week, holiday_type, unit_id)` where schedule_type = 'schedule'

Constraints
- `valid_day_of_week`: day_of_week IS NULL OR day_of_week BETWEEN 1 AND 7
- `valid_schedule_type`: schedule_type IN ('holiday','schedule')
- `schedule_requires_day_of_week` and `holiday_requires_date` to ensure schedule rows and holiday rows have required fields

---

### roles
Primary key
- default integer id

Columns
- `name :string` (NOT NULL)
- `description :text`
- `is_system_role :boolean` default false (NOT NULL)
- timestamps

Indexes
- unique on `name`

---

### permissions
Primary key
- default integer id

Columns
- `name :string` (NOT NULL)
- `resource :string` (NOT NULL)
- `action :string` (NOT NULL)
- `description :text`
- timestamps

Indexes
- unique on `name`
- index on `resource`, `action`

---

### role_permissions
Primary key
- default integer id

Columns
- `role_id references(:roles, on_delete: :delete_all)` (NOT NULL)
- `permission_id references(:permissions, on_delete: :delete_all)` (NOT NULL)
- timestamps (no updated_at)

Indexes
- unique on `(role_id, permission_id)`
- index on `role_id`, `permission_id`

---

### user_role_assignments
Primary key
- default integer id

Columns
- `user_id references(:users, type: :binary_id, on_delete: :delete_all)` (NOT NULL)
- `role_id references(:roles, on_delete: :delete_all)` (NOT NULL)
- `scope_type :string` (NOT NULL, default 'global')
- `scope_id :binary_id` (nullable)
- `glam_type :string` (nullable)
- `assigned_by_id references(:users, type: :binary_id, on_delete: :nilify_all)` (nullable)
- `assigned_at :utc_datetime` (NOT NULL)
- `expires_at :utc_datetime` (nullable)

Indexes & Constraints
- indexes: user_id, role_id, (scope_type, scope_id), (user_id, scope_type, scope_id), (user_id, glam_type)
- unique index `(user_id, role_id, scope_type, scope_id)` to avoid duplicates
- check `valid_glam_type`: glam_type IS NULL OR glam_type IN ('Gallery','Library','Archive','Museum')

---

### user_permissions
Primary key
- default integer id

Columns
- `user_id references(:users, type: :binary_id, on_delete: :delete_all)` (NOT NULL)
- `permission_id references(:permissions, on_delete: :delete_all)` (NOT NULL)
- `scope_type :string` (NOT NULL, default 'global')
- `scope_id :binary_id` (nullable)
- `granted :boolean` default true (NOT NULL)
- `assigned_by_id references(:users, type: :binary_id, on_delete: :nilify_all)` (nullable)
- `assigned_at :utc_datetime` (NOT NULL)
- `expires_at :utc_datetime` (nullable)

Indexes & Constraints
- indexes on user_id, permission_id, (scope_type, scope_id)
- unique `(user_id, permission_id, scope_type, scope_id)` to avoid duplicates

---

### collection_permissions
Primary key
- default integer id

Columns
- `collection_id references(:collections, type: :binary_id, on_delete: :delete_all)` (NOT NULL)
- `user_id references(:users, type: :binary_id, on_delete: :delete_all)` (nullable)
- `role_id references(:roles, on_delete: :delete_all)` (nullable)
- `permission_level :string` (NOT NULL)
- timestamps

Indexes & Constraints
- index on `collection_id`, `user_id`, `role_id`
- check `user_or_role_required`: `(user_id IS NOT NULL AND role_id IS NULL) OR (user_id IS NULL AND role_id IS NOT NULL)`

---

### audit_logs
Primary key
- default integer id

Columns
- `user_id references(:users, type: :binary_id, on_delete: :nilify_all)`
- `action :string` (NOT NULL)
- `resource_type :string`
- `resource_id :binary_id`
- `ip_address :string`
- `user_agent :text`
- `metadata :map` (jsonb)
- timestamps (updated_at: false)

Indexes & Extras
- index: `user_id`, `action`, `(resource_type, resource_id)`, `inserted_at`
- raw SQL: ordered index `audit_logs_timestamp_desc_idx` on `inserted_at DESC`
- raw SQL GIN JSONB index on `metadata` (`audit_logs_metadata_gin_idx`)

---

### lib_payments
Primary key
- `id :binary_id`

Columns
- `fine_id references(:lib_fines, type: :binary_id, on_delete: :nilify_all)` (nullable)
- `member_id references(:users, type: :binary_id, on_delete: :nilify_all)` (NOT NULL)
- `payment_gateway :string` (NOT NULL, default 'xendit')
- `payment_link_id :string`
- `external_id :string` (NOT NULL)
- `payment_url :string`
- `amount :decimal, precision:15, scale:2` (NOT NULL)
- `paid_amount :decimal, precision:15, scale:2` (default 0)
- `currency :string` default 'IDR'
- `payment_method`, `payment_channel`
- `status :string` default 'pending' (NOT NULL)
- `payment_date`, `expired_at :utc_datetime`
- `failure_reason :string`
- `description :text`
- `callback_data :map`
- `metadata :map`
- `processed_by_id references(:users, type: :binary_id, on_delete: :nilify_all)` (nullable)
- timestamps (utc_datetime)

Indexes
- index on `fine_id`, `member_id`, `external_id`, `payment_link_id`, `status`, `payment_gateway`

---

### transfer_requests
Primary key
- `id :binary_id`

Columns
- `item_id references(:items, type: :binary_id, on_delete: :delete_all)` (NOT NULL)
- `from_node_id references(:nodes, on_delete: :restrict)` (nullable)
- `to_node_id references(:nodes, on_delete: :restrict)` (NOT NULL)
- `from_location :string`
- `to_location :string` (NOT NULL)
- `status :string` default 'pending' (NOT NULL)
- `reason :text`
- `notes :text`
- `requested_by_id references(:users, type: :binary_id, on_delete: :restrict)` (NOT NULL)
- `reviewed_by_id references(:users, type: :binary_id, on_delete: :restrict)` (nullable)
- `reviewed_at`, `completed_at :utc_datetime`
- timestamps

Indexes
- index on `item_id`, `from_node_id`, `to_node_id`, `status`, `requested_by_id`, `reviewed_by_id`

---

### stock_opname_sessions
Primary key
- `id :binary_id`

Columns
- `session_code :string` (NOT NULL)
- `title :string` (NOT NULL)
- `description :text`
- `node_ids {:array, :integer}` (NOT NULL)
- `collection_types {:array, :string}` (NOT NULL)
- `scope_type :string` (NOT NULL)
- `scope_id :string`
- `status :string` default 'draft' (NOT NULL)
- `started_at`, `completed_at`, `reviewed_at`, `approved_at :utc_datetime`
- counters: `total_items`, `checked_items`, `missing_items`, `items_with_changes` (integers default 0)
- `notes`, `review_notes`, `rejection_reason`
- `created_by_id references(:users, type: :binary_id, on_delete: :nilify_all)` (NOT NULL)
- `updated_by_id references(:users, type: :binary_id, on_delete: :nilify_all)`
- `reviewed_by_id references(:users, type: :binary_id, on_delete: :nilify_all)`
- timestamps

Indexes & Unique
- unique on `session_code`
- index on `status`, `created_by_id`, `inserted_at`

---

### stock_opname_librarian_assignments
Primary key
- `id :binary_id`

Columns
- `session_id references(:stock_opname_sessions, type: :binary_id, on_delete: :delete_all)` (NOT NULL)
- `user_id references(:users, type: :binary_id, on_delete: :delete_all)` (NOT NULL)
- `work_status :string` default 'pending' (NOT NULL)
- `items_checked :integer` default 0
- `started_at`, `completed_at :utc_datetime`
- `notes :text`
- timestamps

Indexes
- index on `session_id`, `user_id`, `work_status`
- unique index on `(session_id, user_id)`

---

### stock_opname_items
Primary key
- `id :binary_id`

Columns
- `session_id references(:stock_opname_sessions, type: :binary_id, on_delete: :delete_all)` (NOT NULL)
- `item_id references(:items, type: :binary_id, on_delete: :delete_all)` (NOT NULL)
- `collection_id references(:collections, type: :binary_id, on_delete: :delete_all)` (nullable)
- `changes :jsonb` (nullable) — store diffs only
- `scanned_barcode :string`
- `check_status :string` default 'pending' (NOT NULL)
- `has_changes :boolean` default false
- `notes :text`
- `scanned_at :utc_datetime`
- `checked_by_id references(:users, type: :binary_id, on_delete: :nilify_all)`
- timestamps

Indexes & Unique
- index on `session_id`, `item_id`, `check_status`, `checked_by_id`
- unique on `(session_id, item_id)`
- GIN index on `changes` (JSONB)

---

## Additional migrations & index-only actions

- Several migrations run raw SQL `execute` commands to:
  - Create trigram GIN indexes for many text columns (e.g., `collections.title`, `items.item_code`) via `gin_trgm_ops`.
  - Create JSONB GIN indexes on metadata fields (e.g., `audit_logs.metadata`).
  - Create covering indexes (using `INCLUDE`) for faster listing queries (e.g., `collections_listing_covering_idx`, `items_catalog_covering_idx`).
  - Tune column statistics for planner accuracy using `ALTER TABLE ... SET STATISTICS`.

Search `priv/repo/migrations` for `execute` lines to find these SQL operations and their DROP counterparts.

---

## Recommended maintenance & sample inspection queries

- Check that key extensions are installed:
  - SELECT * FROM pg_extension WHERE extname IN ('citext','pg_trgm');

- List custom enum types:
  - SELECT n.nspname AS schema, t.typname AS enum_name
    FROM pg_type t JOIN pg_enum e ON t.oid = e.enumtypid JOIN pg_catalog.pg_namespace n ON n.oid = t.typnamespace
    GROUP BY n.nspname, t.typname;

- Inspect trigram indexes:
  - SELECT indexname, tablename FROM pg_indexes WHERE indexdef LIKE '%gin_trgm_ops%';

- Inspect JSONB GIN indexes:
  - SELECT indexname, tablename FROM pg_indexes WHERE indexdef LIKE '%USING gin (%' AND indexdef LIKE '%jsonb%';

- Get table columns directly from Postgres if you want quick authoritative view:
  - SELECT column_name, data_type, is_nullable, column_default FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'items';

---

## Suggested next steps / optional exports

If you'd like, I can:
- Generate a machine-friendly CSV or JSON export listing every table/column with type/null/default/fk/notes (one row per column).
- Produce per-table Markdown tables (compact tabular style: column | type | null | default | FK | notes).
- Add a small script to parse migrations and auto-generate this document so it's kept in-sync.

Tell me which format you prefer for downstream uses (CSV, JSON, or compact Markdown tables) and I will produce it and save it under `docs/architecture/`.

--- 

If you want me to remove one of the prior documents and keep only this merged file, say so and I'll remove the duplicate and ensure only this comprehensive file remains as the canonical reference.