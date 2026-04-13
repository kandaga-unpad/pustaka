# Voile Application Architecture Overview

## System Architecture

Voile is designed as a GLAM platform for Galleries, Libraries, Archives, and Museums. The core architecture is built around a shared catalog and metadata model, with GLAM-aware resource classes, role-based access, and multi-node support.

```
┌─────────────────────────────────────────────────────────────────┐
│               VOILE GLAM MANAGEMENT PLATFORM                    │
│          Phoenix LiveView + Ecto + Plugin Extension             │
└─────────────────────────────────────────────────────────────────┘
                                │
                ┌───────────────┴───────────────┐
                │                               │
        ┌───────▼────────┐             ┌────────▼────────┐
        │   GALLERY      │             │   LIBRARY       │
        │   DOMAIN       │             │   DOMAIN        │
        └───────┬────────┘             └────────┬────────┘
                │                               │
        ┌───────▼───────────┐           ┌───────▼──────────┐
        │   ARCHIVE         │           │   MUSEUM         │
        │   DOMAIN          │           │   DOMAIN         │
        └───────┬───────────┘           └───────┬──────────┘
                │                               │
                └───────────────┬───────────────┘
                                │
                     ┌──────────▼───────────┐
                     │  Shared Catalog &    │
                     │  Metadata Core       │
                     └──────────┬───────────┘
                                │
                ┌───────────────┴───────────────┐
                │                               │
        ┌───────▼────────────┐         ┌────────▼────────────┐
        │  Collections       │         │  Items              │
        └───────┬────────────┘         └────────┬────────────┘
                │                            │
        ┌───────▼────────────┐               │
        │  CollectionFields  │<──────────────┘
        └────────────────────┘
```

Collections are the primary GLAM resource containers in Voile. Each collection belongs to a `ResourceClass` with a `glam_type` (Gallery, Library, Archive, or Museum) and may include shared content, attachments, and child items.

Items are the collection-specific units that inherit catalog metadata from their parent collection. `collection_fields` are flexible metadata entries attached to a collection, used to store custom field values such as call numbers, provenance details, or domain-specific properties that can be mapped into exports and GLAM workflows.

The GLAM model is enforced through `ResourceClass.glam_type`, institution-scoped `node_id`, and curated roles such as `librarian`, `archivist`, `gallery_curator`, and `museum_curator`.

`Voile.GLAM.CollectionHelper` and `VoileWeb.Auth.GLAMAuthorization` implement the access rules that keep collections and metadata filtered by GLAM type.

## Module Family Structure

### Catalog Family (`VoileWeb.Dashboard.Catalog`)

```
Catalog.Index                           [Dashboard Overview]
    │
    ├── CollectionLive/
    │   ├── Index                       [List & Search]
    │   ├── Show                        [Detail View]
    │   ├── Attachments                 [File Management]
    │   ├── FormComponent               [Create/Edit Form]
    │   ├── FormCollectionHelper        [Form Utilities]
    │   └── TreeComponents              [Hierarchy View]
    │
    ├── ItemLive/
    │   ├── Index                       [List & Search]
    │   ├── Show                        [Detail View]
    │   └── FormComponent               [Create/Edit Form]
    │
    └── Components/
        └── AttachmentUpload            [File Upload UI]
```

### Circulation Family (`VoileWeb.Dashboard.Circulation`)

```
Circulation.Index                       [Dashboard with Stats]
    │
    ├── Transaction/
    │   ├── Index                       [Checkout/Return/Renew]
    │   └── Show                        [Detail View]
    │
    ├── Reservation/
    │   ├── Index                       [Hold Management]
    │   └── Show                        [Detail View]
    │
    ├── Requisition/
    │   ├── Index                       [Purchase Requests]
    │   └── Show                        [Detail View]
    │
    ├── Fine/
    │   ├── Index                       [Fine Management]
    │   └── Show                        [Payment/Waiver]
    │
    ├── CirculationHistory/
    │   ├── Index                       [Reports & Analytics]
    │   └── Show                        [Detail View]
    │
    └── Components/
        ├── Components                  [UI Elements]
        └── Helpers                     [Utility Functions]
```

## Data Flow Diagrams

### Catalog: Collection Creation Flow

```
User Action                   LiveView                    Database
    │                            │                            │
    ├─[Click "New"]─────────────>│                            │
    │                            ├─[Open Modal]               │
    │                            │                            │
    ├─[Fill Form]───────────────>│                            │
    │                            ├─[Validate]                 │
    │                            │                            │
    ├─[Click Save]──────────────>│                            │
    │                            ├─[Create Collection]───────>│
    │                            │                            ├─[Insert]
    │                            │<───[Return Collection]─────┤
    │                            ├─[Stream Insert]            │
    │<───[Update UI]─────────────┤                            │
    │                            ├─[Close Modal]              │
    │<───[Flash Success]─────────┤                            │
```

### Circulation: Checkout Flow

```
Librarian              LiveView           Business Logic        Database
    │                      │                     │                 │
    ├─[Scan Member]───────>│                     │                 │
    │                      ├─[Validate Member]──>│                 │
    │                      │                     ├─[Check Fines]──>│
    │                      │                     │<──[OK]──────────┤
    │                      │<──[Member OK]───────┤                 │
    │                      │                     │                 │
    ├─[Scan Item]─────────>│                     │                 │
    │                      ├─[Check Availability]────────────────>│
    │                      │<──────────────────────[Available]─────┤
    │                      │                     │                 │
    │                      ├─[Calculate Due]────>│                 │
    │                      │<──[Due Date]────────┤                 │
    │                      │                     │                 │
    ├─[Confirm]───────────>│                     │                 │
    │                      ├─[Create Transaction]────────────────>│
    │                      │                     │                 ├─[Insert]
    │                      │                     │                 ├─[Update Item]
    │                      │<──────────────────────[Success]───────┤
    │<──[Receipt]──────────┤                     │                 │
```

### Circulation: Return with Fine Flow

```
Librarian          LiveView       Fine Calculator      Database
    │                 │                  │                 │
    ├─[Scan Item]────>│                  │                 │
    │                 ├─[Find Transaction]───────────────>│
    │                 │<────[Transaction + Due Date]──────┤
    │                 │                  │                 │
    │                 ├─[Calculate Fine]>│                 │
    │                 │                  ├─[Days × Rate]   │
    │                 │<──[Fine Amount]──┤                 │
    │                 │                  │                 │
    │<──[Show Fine]───┤                  │                 │
    │                 │                  │                 │
    ├─[Process Pay]──>│                  │                 │
    │                 ├─[Create Fine Record]─────────────>│
    │                 ├─[Mark Transaction Returned]──────>│
    │                 ├─[Update Item Status]─────────────>│
    │                 │<────[Success]─────────────────────┤
    │<──[Receipt]─────┤                  │                 │
```

## Database Relationships

### Catalog Schema Relationships

```
┌─────────────┐
│ Collections │
├─────────────┤          ┌────────────┐
│ id          │─────────<│ Items      │
│ title       │  1    ∞  ├────────────┤
│ parent_id   │──┐       │ id         │
│ node_id     │  │       │ item_code  │
│ creator_id  │  │       │ collection │
└─────────────┘  │       │ status     │
      │          │       └────────────┘
      │ self-ref │              │
      └──────────┘              │
                                │ 1
                                │
                                │ ∞
                         ┌──────▼──────────┐
                         │ Transactions    │
                         ├─────────────────┤
                         │ id              │
                         │ item_id         │
                         │ member_id       │
                         │ checkout_date   │
                         │ due_date        │
                         └─────────────────┘
```

### Circulation Schema Relationships

```
┌──────────────┐
│ Users        │
│ (Members)    │
├──────────────┤
│ id           │────┐
│ email        │    │ 1
│ username     │    │
└──────────────┘    │
                    │ ∞
              ┌─────▼──────────┐
              │ Transactions   │──────┐
              ├────────────────┤      │ 1
              │ id             │      │
              │ member_id      │      │
              │ item_id        │      │ 1
              │ checkout_date  │      │
              │ due_date       │      │
              │ return_date    │      │
              │ status         │      │
              └────────────────┘      │
                     │                │
                     │ 1              │
                     │                │
                     │ 0..1           │ 0..1
              ┌──────▼──────────┐    │
              │ Fines           │<───┘
              ├─────────────────┤
              │ id              │
              │ transaction_id  │
              │ amount          │
              │ status          │
              │ fine_type       │
              └─────────────────┘

┌──────────────┐       ┌─────────────────┐
│ Users        │       │ Items           │
├──────────────┤       ├─────────────────┤
│ id           │──┐    │ id              │──┐
└──────────────┘  │    └─────────────────┘  │
                  │ 1                        │ 1
                  │                          │
                  │ ∞                        │ ∞
            ┌─────▼──────────────────────────▼────┐
            │ Reservations                        │
            ├─────────────────────────────────────┤
            │ id                                  │
            │ member_id                           │
            │ item_id                             │
            │ status (pending/available/fulfilled)│
            │ reservation_date                    │
            │ available_date                      │
            │ expiration_date                     │
            └─────────────────────────────────────┘

┌──────────────┐
│ Users        │
├──────────────┤
│ id           │──┐
└──────────────┘  │ 1
                  │
                  │ ∞
            ┌─────▼──────────┐
            │ Requisitions   │
            ├────────────────┤
            │ id             │
            │ requested_by   │
            │ title          │
            │ author         │
            │ status         │
            │ priority       │
            └────────────────┘
```

## User Journey Maps

### Catalog User Journey

```
Step 1: Access Catalog
    │
    ├─> View Dashboard (/manage/catalog)
    │   └─> See total collections & items
    │
Step 2: Manage Collections
    │
    ├─> List View (/manage/catalog/collections)
    │   ├─> Search/Filter
    │   └─> Paginate
    │
    ├─> Create Collection (Modal)
    │   ├─> Step 1: Basic Info
    │   ├─> Step 2: Metadata
    │   └─> Step 3: Settings
    │
    ├─> View Collection (/manage/catalog/collections/:id)
    │   ├─> See details
    │   ├─> Edit inline
    │   └─> Manage attachments
    │
    └─> Tree View (Toggle)
        └─> See hierarchy

Step 3: Manage Items
    │
    ├─> List View (/manage/catalog/items)
    │   ├─> Search/Filter
    │   └─> Paginate
    │
    ├─> Create Item (Modal)
    │   ├─> Select collection
    │   ├─> Enter details
    │   └─> Set location
    │
    └─> View Item (/manage/catalog/items/:id)
        ├─> See details
        └─> Edit inline
```

### Circulation User Journey

```
Step 1: Access Circulation
    │
    ├─> View Dashboard (/manage/circulation)
    │   ├─> See active loans
    │   ├─> See overdue items
    │   └─> See pending reservations
    │
Step 2: Process Checkout
    │
    ├─> Click "Checkout" (/manage/circulation/transactions/checkout)
    │   ├─> Scan member ID
    │   ├─> System validates member
    │   ├─> Scan item barcode
    │   ├─> System checks availability
    │   ├─> System calculates due date
    │   └─> Transaction created
    │
Step 3: Process Return
    │
    ├─> Scan item (/manage/circulation/transactions/:id/return)
    │   ├─> System finds transaction
    │   ├─> System checks if overdue
    │   ├─> If overdue: Calculate fine
    │   ├─> Process payment (if needed)
    │   └─> Mark returned
    │
Step 4: Manage Reservations
    │
    ├─> View List (/manage/circulation/reservations)
    │   ├─> See pending holds
    │   ├─> Mark item available
    │   └─> Process pickup
    │
Step 5: Manage Fines
    │
    └─> View Fines (/manage/circulation/fines)
        ├─> See unpaid fines
        ├─> Process payment
        └─> Waive fine (if authorized)
```

## State Management

### Transaction Status State Machine

```
                ┌──────────┐
                │  START   │
                └────┬─────┘
                     │
            [Checkout Item]
                     │
                     ▼
              ┌────────────┐
              │   ACTIVE   │──────┐
              └──────┬─────┘      │
                     │             │
          [Due Date Passes]    [Return]
                     │             │
                     ▼             │
              ┌────────────┐      │
              │  OVERDUE   │──────┤
              └────────────┘      │
                                  │
                                  ▼
                          ┌──────────────┐
                          │  RETURNED    │
                          └──────────────┘
```

### Reservation Status State Machine

```
               ┌──────────┐
               │  START   │
               └────┬─────┘
                    │
         [Create Reservation]
                    │
                    ▼
             ┌─────────────┐
             │  PENDING    │
             └──┬────┬─────┘
                │    │
    [Item Returned]  │
                │    │
                │    │ [Cancel]
                │    │
                ▼    ▼
      ┌──────────┐ ┌──────────┐
      │AVAILABLE │ │CANCELLED │
      └────┬─────┘ └──────────┘
           │
    [Member Picks Up]
           │
           ▼
    ┌──────────────┐
    │  FULFILLED   │
    └──────────────┘
           │
    [Timeout]
           │
           ▼
      ┌─────────┐
      │ EXPIRED │
      └─────────┘
```

## Performance Architecture

```
┌─────────────────────────────────────────────┐
│           LiveView Connection               │
│  (WebSocket - Real-time bidirectional)     │
└──────────────┬──────────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────────┐
│        Phoenix LiveView Process             │
│  - Stateful                                 │
│  - Manages assigns                          │
│  - Handles events                           │
│  - Streams updates                          │
└──────────────┬──────────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────────┐
│        Business Logic Layer                 │
│  - Catalog context                          │
│  - Circulation context                      │
│  - Authorization checks                     │
└──────────────┬──────────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────────┐
│        Ecto Repository Layer                │
│  - Queries                                  │
│  - Changesets                               │
│  - Transactions                             │
│  - Preloading                               │
└──────────────┬──────────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────────┐
│          PostgreSQL Database                │
│  - Tables                                   │
│  - Indexes                                  │
│  - Constraints                              │
│  - Triggers                                 │
└─────────────────────────────────────────────┘
```

## Key Files Reference

```
lib/voile_web/
├── live/
│   └── dashboard/
│       ├── catalog/
│       │   ├── index.ex                    [Catalog Dashboard]
│       │   ├── collection_live/            [Collections]
│       │   ├── item_live/                  [Items]
│       │   └── components/                 [Shared UI]
│       │
│       └── circulation/
│           ├── index.ex                    [Circulation Dashboard]
│           ├── transaction/                [Loans]
│           ├── reservation/                [Holds]
│           ├── requisition/                [Requests]
│           ├── fine/                       [Fines]
│           ├── circulation_history/        [History]
│           └── components/                 [Shared UI]
│
├── router.ex                               [Route Definitions]
├── auth/                                   [Authorization]
└── components/                             [Global Components]

lib/voile/
└── schema/
    ├── catalog/                            [Catalog Schemas]
    └── library/                            [Circulation Schemas]
```

---

**Architecture Type:** Modular Monolith with LiveView
**Pattern:** MVC with LiveView
**Database:** PostgreSQL with Ecto
**Frontend:** Server-rendered with LiveView
**Real-time:** WebSocket via Phoenix Channels
