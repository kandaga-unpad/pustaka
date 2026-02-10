# OAI-PMH Implementation Guide

## Overview

This document describes the implementation of the Open Archives Initiative Protocol for Metadata Harvesting (OAI-PMH) v2.0 in the Voile GLAM management system.

OAI-PMH is a protocol developed for harvesting metadata descriptions of records in an archive so that services can be built using metadata from many archives. It enables data providers to expose their metadata for harvesting by service providers.

**Official Specification**: https://www.openarchives.org/OAI/2.0/guidelines.htm

## Architecture

The OAI-PMH implementation in Voile consists of three main components:

### 1. Context Module (`Voile.OaiPmh`)
- **Location**: `lib/voile/oai_pmh.ex`
- **Purpose**: Business logic for handling OAI-PMH operations
- **Responsibilities**:
  - Query database for items and collections
  - Format data according to OAI-PMH specification
  - Handle resumption tokens for pagination
  - Validate dates and parameters
  - Build OAI identifiers

### 2. XML Builder (`Voile.OaiPmh.XmlBuilder`)
- **Location**: `lib/voile/oai_pmh/xml_builder.ex`
- **Purpose**: Generate XML responses conforming to OAI-PMH schema
- **Responsibilities**:
  - Build complete OAI-PMH XML documents
  - Format error responses
  - Generate Dublin Core metadata XML
  - Handle XML namespaces and schemas

### 3. Controller (`VoileWeb.OaiPmhController`)
- **Location**: `lib/voile_web/controllers/oai_pmh_controller.ex`
- **Purpose**: HTTP endpoint for OAI-PMH requests
- **Responsibilities**:
  - Handle GET and POST requests
  - Validate request parameters
  - Route to appropriate verb handler
  - Return XML responses with proper content-type

## Endpoint

**URL**: `/api/oai`

**Methods**: GET, POST

Both GET and POST methods are supported as per OAI-PMH specification.

## OAI-PMH Verbs

The implementation supports all six required OAI-PMH verbs:

### 1. Identify

Returns information about the repository.

**Request**:
```
GET /api/oai?verb=Identify
```

**Response Elements**:
- `repositoryName`: Name of the repository
- `baseURL`: Base URL of the OAI-PMH endpoint
- `protocolVersion`: Always "2.0"
- `adminEmail`: Administrator email(s)
- `earliestDatestamp`: Earliest date of any record
- `deletedRecord`: Deletion policy (transient)
- `granularity`: Date granularity (YYYY-MM-DDThh:mm:ssZ)
- `compression`: Supported compression formats
- `description`: Repository descriptions (OAI-identifier scheme)

**Example**:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<OAI-PMH xmlns="http://www.openarchives.org/OAI/2.0/">
  <responseDate>2024-01-15T10:30:00Z</responseDate>
  <request verb="Identify">https://example.com/api/oai</request>
  <Identify>
    <repositoryName>Voile - Virtual Organized Information & Library Ecosystem</repositoryName>
    <baseURL>https://example.com/api/oai</baseURL>
    <protocolVersion>2.0</protocolVersion>
    <adminEmail>admin@example.com</adminEmail>
    <earliestDatestamp>2024-01-01T00:00:00Z</earliestDatestamp>
    <deletedRecord>transient</deletedRecord>
    <granularity>YYYY-MM-DDThh:mm:ssZ</granularity>
  </Identify>
</OAI-PMH>
```

### 2. ListMetadataFormats

Returns the metadata formats available from the repository.

**Request**:
```
GET /api/oai?verb=ListMetadataFormats
GET /api/oai?verb=ListMetadataFormats&identifier=oai:voile.example.com:item:123
```

**Parameters**:
- `identifier` (optional): Return formats available for a specific item

**Supported Formats**:
- **oai_dc**: Dublin Core (required by OAI-PMH)
- **oai_marc**: MARC format (basic implementation)

**Example**:
```xml
<OAI-PMH>
  <ListMetadataFormats>
    <metadataFormat>
      <metadataPrefix>oai_dc</metadataPrefix>
      <schema>http://www.openarchives.org/OAI/2.0/oai_dc.xsd</schema>
      <metadataNamespace>http://www.openarchives.org/OAI/2.0/oai_dc/</metadataNamespace>
    </metadataFormat>
  </ListMetadataFormats>
</OAI-PMH>
```

### 3. ListSets

Returns the set structure of the repository (collections in Voile).

**Request**:
```
GET /api/oai?verb=ListSets
GET /api/oai?verb=ListSets&resumptionToken=abc123
```

**Parameters**:
- `resumptionToken` (optional): Continue from previous request

**Sets in Voile**:
- Each published collection is exposed as a set
- Set spec format: `collection:{collection_code}`
- Example: `collection:BK001`

**Pagination**:
- 100 sets per page
- Resumption tokens valid for 60 minutes

**Example**:
```xml
<OAI-PMH>
  <ListSets>
    <set>
      <setSpec>collection:BK001</setSpec>
      <setName>General Book Collection</setName>
      <setDescription>Main library book collection</setDescription>
    </set>
    <resumptionToken cursor="0" completeListSize="250">eyJvZmZzZXQiOjEwMH0=</resumptionToken>
  </ListSets>
</OAI-PMH>
```

### 4. ListIdentifiers

Returns headers (identifiers with datestamps) for records.

**Request**:
```
GET /api/oai?verb=ListIdentifiers&metadataPrefix=oai_dc
GET /api/oai?verb=ListIdentifiers&metadataPrefix=oai_dc&from=2024-01-01T00:00:00Z
GET /api/oai?verb=ListIdentifiers&metadataPrefix=oai_dc&set=collection:BK001
```

**Required Parameters**:
- `metadataPrefix`: Format of metadata (e.g., oai_dc)

**Optional Parameters**:
- `from`: Harvest records from this date
- `until`: Harvest records until this date
- `set`: Limit to specific set (collection)
- `resumptionToken`: Continue from previous request

**Date Format**: ISO 8601 (YYYY-MM-DDThh:mm:ssZ)

**Pagination**: 100 identifiers per page

**Example**:
```xml
<OAI-PMH>
  <ListIdentifiers>
    <header>
      <identifier>oai:voile.example.com:item:uuid-123</identifier>
      <datestamp>2024-01-15T10:30:00Z</datestamp>
      <setSpec>collection:BK001</setSpec>
    </header>
    <resumptionToken cursor="0" completeListSize="500">eyJvZmZzZXQiOjEwMH0=</resumptionToken>
  </ListIdentifiers>
</OAI-PMH>
```

### 5. ListRecords

Returns complete metadata records for items.

**Request**:
```
GET /api/oai?verb=ListRecords&metadataPrefix=oai_dc
GET /api/oai?verb=ListRecords&metadataPrefix=oai_dc&from=2024-01-01T00:00:00Z&until=2024-12-31T23:59:59Z
GET /api/oai?verb=ListRecords&metadataPrefix=oai_dc&set=collection:BK001
```

**Required Parameters**:
- `metadataPrefix`: Format of metadata (e.g., oai_dc)

**Optional Parameters**:
- `from`: Harvest records from this date
- `until`: Harvest records until this date
- `set`: Limit to specific set (collection)
- `resumptionToken`: Continue from previous request

**Pagination**: 50 records per page (smaller than ListIdentifiers due to full metadata)

**Example**:
```xml
<OAI-PMH>
  <ListRecords>
    <record>
      <header>
        <identifier>oai:voile.example.com:item:uuid-123</identifier>
        <datestamp>2024-01-15T10:30:00Z</datestamp>
        <setSpec>collection:BK001</setSpec>
      </header>
      <metadata>
        <oai_dc:dc xmlns:oai_dc="http://www.openarchives.org/OAI/2.0/oai_dc/"
                   xmlns:dc="http://purl.org/dc/elements/1.1/">
          <dc:title>Example Book Title</dc:title>
          <dc:identifier>ITEM-001</dc:identifier>
          <dc:type>Physical Object</dc:type>
          <dc:format>Item</dc:format>
        </oai_dc:dc>
      </metadata>
    </record>
  </ListRecords>
</OAI-PMH>
```

### 6. GetRecord

Returns a single metadata record by identifier.

**Request**:
```
GET /api/oai?verb=GetRecord&identifier=oai:voile.example.com:item:uuid-123&metadataPrefix=oai_dc
```

**Required Parameters**:
- `identifier`: OAI identifier of the item
- `metadataPrefix`: Format of metadata (e.g., oai_dc)

**Example**:
```xml
<OAI-PMH>
  <GetRecord>
    <record>
      <header>
        <identifier>oai:voile.example.com:item:uuid-123</identifier>
        <datestamp>2024-01-15T10:30:00Z</datestamp>
        <setSpec>collection:BK001</setSpec>
      </header>
      <metadata>
        <oai_dc:dc>
          <dc:title>Example Book Title</dc:title>
        </oai_dc:dc>
      </metadata>
    </record>
  </GetRecord>
</OAI-PMH>
```

## Error Handling

The implementation follows OAI-PMH error codes:

### Error Codes

| Code | Description | When It Occurs |
|------|-------------|----------------|
| `badArgument` | Illegal or missing arguments | Missing required parameters, invalid date format |
| `badResumptionToken` | Invalid or expired token | Token expired (>60 minutes) or malformed |
| `badVerb` | Invalid or missing verb | Unknown verb or verb parameter missing |
| `cannotDisseminateFormat` | Unsupported metadata format | Requested format not available |
| `idDoesNotExist` | Identifier does not exist | Item not found in repository |
| `noRecordsMatch` | No records match criteria | Empty result set for query |
| `noSetHierarchy` | Repository does not support sets | Sets feature disabled |

**Error Response Example**:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<OAI-PMH xmlns="http://www.openarchives.org/OAI/2.0/">
  <responseDate>2024-01-15T10:30:00Z</responseDate>
  <request verb="GetRecord">https://example.com/api/oai</request>
  <error code="idDoesNotExist">The value of the identifier argument is unknown or illegal</error>
</OAI-PMH>
```

## Data Mapping

### OAI Identifiers

Format: `oai:{repository-identifier}:item:{item-id}`

Example: `oai:voile.example.com:item:550e8400-e29b-41d4-a716-446655440000`

### Dublin Core Mapping

Voile item fields are mapped to Dublin Core elements:

| DC Element | Voile Source | Notes |
|------------|--------------|-------|
| `dc:title` | collection.title | Collection title |
| `dc:identifier` | item_code, inventory_code, barcode | Multiple identifiers |
| `dc:type` | Static: "Physical Object" | Resource type |
| `dc:format` | Static: "Item" | Format |
| `dc:description` | collection.description | Collection description |
| `dc:date` | acquisition_date | Date acquired |
| `dc:language` | Static: "en" | Default language |
| `dc:relation` | collection_code | Related collection |
| `dc:coverage` | location | Physical location |
| `dc:rights` | Static rights statement | Access information |

### Sets (Collections)

- Only **published** collections are exposed as sets
- Set spec: `collection:{collection_code}`
- Set name: Collection title
- Set description: Collection description

## Configuration

### Environment Variables

Set these in your configuration:

```elixir
# config/runtime.exs or config/prod.exs
config :voile,
  oai_pmh_repository_id: System.get_env("OAI_REPOSITORY_ID", "voile.example.com")
```

### Application Configuration

```elixir
# config/dev.exs or config/prod.exs
config :voile,
  oai_pmh_repository_id: "voile.example.com"
```

**Note**: Admin email is automatically read from the database setting `app_contact_email`. You can set this in the admin settings interface at `/manage/settings/app-profile`.

## Testing

### Manual Testing with cURL

#### Test Identify:
```bash
curl "http://localhost:4000/api/oai?verb=Identify"
```

#### Test ListMetadataFormats:
```bash
curl "http://localhost:4000/api/oai?verb=ListMetadataFormats"
```

#### Test ListSets:
```bash
curl "http://localhost:4000/api/oai?verb=ListSets"
```

#### Test ListIdentifiers:
```bash
curl "http://localhost:4000/api/oai?verb=ListIdentifiers&metadataPrefix=oai_dc"
```

#### Test ListRecords with date range:
```bash
curl "http://localhost:4000/api/oai?verb=ListRecords&metadataPrefix=oai_dc&from=2024-01-01T00:00:00Z"
```

#### Test GetRecord:
```bash
curl "http://localhost:4000/api/oai?verb=GetRecord&identifier=oai:voile.example.com:item:YOUR-ITEM-ID&metadataPrefix=oai_dc"
```

#### Test with set filter:
```bash
curl "http://localhost:4000/api/oai?verb=ListRecords&metadataPrefix=oai_dc&set=collection:BK001"
```

### Testing with OAI-PMH Clients

#### OAI-PMH Validator
Use the official validator: http://www.openarchives.org/Register/ValidateSite

#### Harvesting Tools
- **OAI-Harvester**: Python-based harvesting tool
- **JHOVE**: Java-based validation tool
- **OAICat**: Java OAI-PMH implementation with testing tools

### Automated Tests

Create test files in `test/voile_web/controllers/oai_pmh_controller_test.exs`:

```elixir
defmodule VoileWeb.OaiPmhControllerTest do
  use VoileWeb.ConnCase
  
  describe "Identify" do
    test "returns repository information", %{conn: conn} do
      conn = get(conn, ~p"/api/oai?verb=Identify")
      
      assert response(conn, 200)
      assert response_content_type(conn, :xml) =~ "text/xml"
      
      body = response(conn, 200)
      assert body =~ "<repositoryName>"
      assert body =~ "Voile"
    end
  end
  
  describe "ListMetadataFormats" do
    test "returns available formats", %{conn: conn} do
      conn = get(conn, ~p"/api/oai?verb=ListMetadataFormats")
      
      assert response(conn, 200)
      body = response(conn, 200)
      assert body =~ "<metadataPrefix>oai_dc</metadataPrefix>"
    end
  end
  
  # Add more tests...
end
```

## Performance Considerations

### Database Queries

1. **Indexes**: Ensure proper indexes on:
   - `items.updated_at` (for date-based harvesting)
   - `collections.status` (filtering published collections)
   - `collections.collection_code` (set filtering)

```sql
CREATE INDEX idx_items_updated_at ON items(updated_at);
CREATE INDEX idx_collections_status ON collections(status);
CREATE INDEX idx_collections_collection_code ON collections(collection_code);
```

2. **Pagination**: Uses offset-based pagination with resumption tokens
   - ListIdentifiers: 100 items per page
   - ListRecords: 50 items per page
   - ListSets: 100 sets per page

3. **Preloading**: Only loads required associations
   - ListIdentifiers: No preloading (minimal data)
   - ListRecords: Preloads collection and node

### Resumption Tokens

- Encoded as Base64 JSON
- Contains: offset, cursor, timestamp
- Expires after 60 minutes
- Stateless (no database storage)

Token format:
```json
{
  "offset": 100,
  "cursor": 1,
  "timestamp": 1705320600
}
```

### Caching Recommendations

Consider caching for high-traffic deployments:

1. **Repository information** (Identify response) - Cache for 24 hours
2. **Metadata formats** - Cache indefinitely
3. **Sets list** - Cache for 1 hour
4. **Recent records** - Cache for 15 minutes with ETag

Example with Phoenix cache:

```elixir
def identify(base_url) do
  Cachex.fetch(:oai_cache, "identify", fn ->
    {:commit, compute_identify(base_url), ttl: :timer.hours(24)}
  end)
end
```

## Deployment

### Production Checklist
### Checklist

- [ ] Set `OAI_REPOSITORY_ID` environment variable
- [ ] Set `app_contact_email` in system settings (database)
- [ ] Run migration to add database indexes
- [ ] Ensure published collections exist
- [ ] Test with OAI-PMH validator
- [ ] Register with OAI-PMH registries (optional)
- [ ] Configure rate limiting if needed
- [ ] Set up monitoring for endpoint

### Rate Limiting

Consider adding rate limiting for the OAI-PMH endpoint:

```elixir
# In router.ex
pipeline :oai_pmh do
  plug :accepts, ["xml"]
  plug VoileWeb.Plugs.RateLimiter, limit: 100, scale_ms: 60_000
end

scope "/api", VoileWeb do
  pipe_through :oai_pmh
  get "/oai", OaiPmhController, :index
  post "/oai", OaiPmhController, :index
end
```

### Monitoring

Monitor these metrics:
- Request rate by verb
- Response times
- Error rates by error code
- Resumption token usage
- Most harvested sets

## Compliance

This implementation complies with:

✅ OAI-PMH Protocol Version 2.0  
✅ Dublin Core Metadata (oai_dc) - Required  
✅ All six protocol verbs  
✅ Resumption tokens for pagination  
✅ Selective harvesting by date  
✅ Set hierarchy (collections)  
✅ Proper error handling  
✅ UTF-8 encoding  
✅ XML schema validation  

## Future Enhancements

### Additional Metadata Formats

Consider implementing:
- **MARC21**: Full MARC bibliographic records
- **MODS**: Metadata Object Description Schema
- **Qualified Dublin Core**: Extended Dublin Core with qualifiers

### Advanced Features

1. **Soft Deletes Support**:
   - Track deleted items
   - Return `status="deleted"` in headers
   - Change `deletedRecord` policy to "persistent"

2. **Provenance Tracking**:
   - Add `<about>` containers with provenance data
   - Track harvesting history

3. **Compressed Responses**:
   - Implement gzip/deflate compression
   - Reduce bandwidth usage

4. **Set Descriptions**:
   - Add Dublin Core metadata to set descriptions
   - Include collection-level metadata

5. **Incremental Harvesting**:
   - Optimize date-based queries
   - Add last-modified tracking

## Troubleshooting

### Common Issues

**Issue**: "No records found"
- **Solution**: Ensure collections have `status = "published"`
- Check that items exist in published collections

**Issue**: Resumption token expired
- **Solution**: Tokens expire after 60 minutes; restart harvest
- Consider increasing `@token_expiry_minutes` in `oai_pmh.ex`

**Issue**: Invalid XML response
- **Solution**: Check for special characters in metadata
- Ensure all text fields are properly escaped

**Issue**: Slow query performance
- **Solution**: Add database indexes (see Performance section)
- Reduce page size if needed

**Issue**: Wrong datestamp format
- **Solution**: Use ISO 8601: `YYYY-MM-DDThh:mm:ssZ`
- Example: `2024-01-15T10:30:00Z`

## Support and Resources

### Official Resources
- [OAI-PMH Specification v2.0](https://www.openarchives.org/OAI/openarchivesprotocol.html)
- [Implementation Guidelines](https://www.openarchives.org/OAI/2.0/guidelines.htm)
- [Dublin Core Metadata Element Set](https://www.dublincore.org/specifications/dublin-core/dces/)

### Registration
Register your repository (optional):
- [OAI Registry](http://www.openarchives.org/Register/BrowseSites)

### Community
- [OAI-PMH Mailing List](https://groups.google.com/g/oai-implementers)
- [Digital Library Federation](https://www.diglib.org/)

## License

This implementation follows the OAI-PMH specification which is freely available for implementation.