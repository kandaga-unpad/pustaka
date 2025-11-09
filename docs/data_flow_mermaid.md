# Data Flow & Collection Management (Mermaid)

This file contains two Mermaid diagrams: a high-level data flow for typical requests and attachments, and a LiveView collection management diagram showing `stream/3` operations and template behavior.

## 1) High-level Data Flow (Client → Server → Storage)

```mermaid
flowchart LR
  subgraph Client
    A[Browser / JS / LiveView Socket]
  end

  subgraph Phoenix
    E[Endpoint (HTTP/WebSocket)]
    R[Router]
    LV[LiveView / Controller]
    C[Context / Business Logic]
    DB[(Postgres / Repo)]
    AS[Attachment Service / Presigner]
  end

  subgraph Storage
    S3[(Object Storage / S3)]
  end

  A -->|HTTP / WS| E
  E --> R
  R -->|live route| LV
  R -->|controller route| LV

  LV --> C
  C --> DB
  C --> AS
  AS -->|presign URL| A
  A -->|direct upload (presigned)| S3
  S3 -->|upload callback / notify| C
  C --> DB
  C -->|publish| LV
  LV -->|push_event / diff| A

  classDef storage fill:#f8f9fa,stroke:#333
  class S3 storage
```

Notes:

- The client obtains a presigned URL from the Attachment Service (via a LiveView event or controller endpoint). The client uploads directly to storage and then the server validates/stores metadata.
- LiveView pushes updates (diffs, broadcasts) back to the client after DB or attachment metadata changes.

## 2) LiveView Collection Management (Streams)

```mermaid
flowchart TD
  subgraph LiveView
    M[Mount]
    F[Fetch items from Context]
    S[stream(:items, items, reset: false)]
    T[Template: <div id="items" phx-update="stream">]
    UI[Rendered DOM per item (id)]
  end

  subgraph Events
    Append[Client/Server: append new item]
    Reset[Apply filter or replace collection]
    Delete[Delete item]
  end

  M --> F --> S --> T --> UI

  Append -->|stream(:items, [new_item])| S
  Reset -->|stream(:items, new_items, reset: true)| S
  Delete -->|stream_delete(:items, item)| S

  note right of S
    Streams maintain an internal id->item mapping.
    Templates must iterate @streams.items as {id, item}.
  end

  classDef lv fill:#eef6ff,stroke:#2b6cb0
  class LiveView lv
```

Key points for collection management with streams:

- Use `stream/3` for append/prepend/reset/delete operations to avoid rebuilding large lists in memory.
- The template must have `phx-update="stream"` on the parent container and use the stream IDs as DOM ids for children.
- Streams are not enumerable; maintain separate assigns for counts or other aggregates.

---

File: `/docs/data_flow_mermaid.md` — contains diagrams and short guidance for contributors.
