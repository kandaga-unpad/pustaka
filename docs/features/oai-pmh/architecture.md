# OAI-PMH Architecture in Voile

## System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    External Harvesters                       │
│  (Digital Libraries, Aggregators, Research Platforms)        │
└────────────────────┬────────────────────────────────────────┘
                     │ HTTP GET/POST
                     │ /api/oai?verb=...
                     ▼
┌─────────────────────────────────────────────────────────────┐
│              Phoenix Router (Public API)                     │
│  Route: GET/POST /api/oai                                    │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│         OaiPmhController (HTTP Layer)                        │
│  - Parse verb & parameters                                   │
│  - Validate inputs                                           │
│  - Route to verb handlers                                    │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│         Voile.OaiPmh (Business Logic)                        │
│  - Query database (Items, Collections)                       │
│  - Apply filters (date, set)                                 │
│  - Format metadata (Dublin Core)                             │
│  - Generate resumption tokens                                │
└────────────────────┬────────────────────────────────────────┘
                     │
        ┌────────────┴────────────┐
        ▼                         ▼
┌──────────────┐         ┌──────────────────┐
│   Database   │         │  XmlBuilder      │
│              │         │                  │
│ - Items      │         │ - Build XML      │
│ - Collections│         │ - Apply schemas  │
│ - Nodes      │         │ - Format DC      │
└──────────────┘         └────────┬─────────┘
                                  │
                                  ▼
                         ┌──────────────────┐
                         │  XML Response    │
                         │  (OAI-PMH 2.0)   │
                         └──────────────────┘
```

## Data Flow

### Identify Request
```
User Request → OaiPmhController → Voile.OaiPmh.identify()
     ↓
Config + DB Query (earliest date)
     ↓
XmlBuilder.build_response()
     ↓
XML Response (repository info)
```

### ListRecords Request
```
User Request (with filters) → OaiPmhController
     ↓
Voile.OaiPmh.list_records([from: date, set: collection])
     ↓
Database Query:
  - Filter: collections.status = 'published'
  - Filter: items.updated_at >= from_date
  - Filter: collection_code = set
  - Paginate: LIMIT 50
     ↓
Format as Dublin Core metadata
     ↓
Generate resumption token (if more results)
     ↓
XmlBuilder.build_response()
     ↓
XML Response (records + token)
```

## Component Responsibilities

### 1. OaiPmhController
- HTTP request handling
- Parameter validation
- Error code mapping
- Content-type headers

### 2. Voile.OaiPmh
- Business logic
- Database queries
- Metadata mapping
- Token management
- Date/set filtering

### 3. XmlBuilder
- XML generation
- Schema compliance
- Namespace handling
- Dublin Core formatting

## Database Schema

```
┌─────────────────┐
│   collections   │
│─────────────────│
│ id              │◄────┐
│ collection_code │     │
│ title           │     │
│ description     │     │
│ status          │     │ (only 'published' exposed)
│ updated_at      │     │
└─────────────────┘     │
                        │
┌─────────────────┐     │
│     items       │     │
│─────────────────│     │
│ id              │     │
│ item_code       │     │
│ inventory_code  │     │
│ barcode         │     │
│ collection_id   │─────┘
│ status          │
│ updated_at      │ (used for date filtering)
└─────────────────┘
```

## OAI Identifier Format

```
oai:{repository-id}:item:{item-id}
 │       │            │      │
 │       │            │      └─ UUID from items.id
 │       │            └──────── Resource type (always "item")
 │       └───────────────────── From config: oai_pmh_repository_id
 └───────────────────────────── OAI-PMH standard prefix

Example: oai:library.university.edu:item:550e8400-e29b-41d4-a716-446655440000
```

## Set Specification Format

```
collection:{collection-code}
     │            │
     │            └─ From collections.collection_code
     └────────────── Static prefix

Example: collection:BK001
```

## Resumption Token Structure

```json
{
  "offset": 100,      // Database offset
  "cursor": 1,        // Current page number
  "timestamp": 1705320600  // Token creation time
}
```

Encoded as Base64 → `eyJvZmZzZXQiOjEwMCwi...`

Expires after 60 minutes.

## Request/Response Flow

### Example: Harvesting All Records

```
1. Initial Request:
   GET /api/oai?verb=ListRecords&metadataPrefix=oai_dc

2. Response:
   - 50 records (page 1)
   - <resumptionToken cursor="0" completeListSize="250">ABC123</resumptionToken>

3. Next Request:
   GET /api/oai?verb=ListRecords&resumptionToken=ABC123

4. Response:
   - 50 records (page 2)
   - <resumptionToken cursor="1" completeListSize="250">DEF456</resumptionToken>

5. Continue until no resumptionToken returned
```

## Security & Access Control

```
┌─────────────────────────────────────┐
│  OAI-PMH Endpoint (/api/oai)        │
│  - Public (no authentication)       │
│  - Rate limiting recommended        │
└─────────────────────────────────────┘
           │
           ▼
┌─────────────────────────────────────┐
│  Data Filtering                     │
│  - Only published collections       │
│  - No draft/archived collections    │
│  - No deleted items (transient)     │
└─────────────────────────────────────┘
```

## Performance Optimization

### Database Indexes
```sql
-- Required for date-based harvesting
CREATE INDEX idx_items_updated_at ON items(updated_at);

-- Required for filtering published collections
CREATE INDEX idx_collections_status ON collections(status);

-- Required for set filtering
CREATE INDEX idx_collections_collection_code ON collections(collection_code);
```

### Query Patterns
- Offset-based pagination (LIMIT/OFFSET)
- Selective preloading (only when needed)
- WHERE clause filtering at DB level
- Efficient date range queries

## Error Handling

```
User Request
    │
    ▼
Validation
    │
    ├─ Valid ──────────► Process Request ──► XML Response
    │
    └─ Invalid ────────► Map Error Code ───► Error XML
                            │
                            ├─ badArgument
                            ├─ badVerb
                            ├─ cannotDisseminateFormat
                            ├─ idDoesNotExist
                            ├─ noRecordsMatch
                            └─ badResumptionToken
```
