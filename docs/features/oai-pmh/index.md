# OAI-PMH Implementation for Voile

## Overview

Voile now includes a complete implementation of the **Open Archives Initiative Protocol for Metadata Harvesting (OAI-PMH) v2.0**. This enables other systems to harvest your catalog metadata in a standardized way, allowing for:

- Integration with digital library aggregators
- Federated search across multiple repositories
- Data sharing with research platforms
- Interoperability with other library systems

## Quick Links

- **[Quick Start Guide](quickstart.md)** - Get started in 5 minutes
- **[Full Implementation Guide](implementation.md)** - Complete technical documentation
- **[Implementation Summary](architecture.md)** - What was built and how

## What is OAI-PMH?

OAI-PMH is a protocol that allows data providers (like Voile) to expose their metadata for harvesting by service providers. It's widely used in digital libraries, archives, and museums to enable:

- **Metadata sharing** between institutions
- **Discovery** through aggregated search portals
- **Preservation** through distributed copies
- **Research** by providing standardized access to collections

## Features

✅ **Complete OAI-PMH v2.0 implementation**
- All 6 required verbs (Identify, ListMetadataFormats, ListSets, ListIdentifiers, ListRecords, GetRecord)
- Dublin Core metadata format (required by spec)
- Resumption tokens for large result sets
- Selective harvesting by date and collection
- Proper error handling with OAI error codes

✅ **Production-ready**
- Configurable repository settings
- Performance optimized with pagination
- Comprehensive test suite
- Full documentation

✅ **Standards compliant**
- OAI-PMH Protocol v2.0
- Dublin Core Metadata Element Set
- ISO 8601 date formats
- UTF-8 encoding

## Quick Start

### 1. Configuration

For development, the default configuration works out of the box:

```elixir
# config/dev.exs
config :voile,
  oai_pmh_repository_id: "localhost:4000"
```

For production, set environment variable:

```bash
export OAI_REPOSITORY_ID="library.university.edu"
```

**Admin Email**: The admin email shown in OAI-PMH responses is automatically read from the database setting `app_contact_email`. Set this in the admin interface at **Settings > App Profile** (`/manage/settings/app-profile`).

### 2. Test the Endpoint

Start your server:

```bash
mix phx.server
```

Test with curl:

```bash
curl "http://localhost:4000/api/oai?verb=Identify"
```

You should see XML output with your repository information!

### 3. Basic Usage

```bash
# Get repository information
curl "http://localhost:4000/api/oai?verb=Identify"

# List all collections (sets)
curl "http://localhost:4000/api/oai?verb=ListSets"

# List all item identifiers
curl "http://localhost:4000/api/oai?verb=ListIdentifiers&metadataPrefix=oai_dc"

# Get full metadata records
curl "http://localhost:4000/api/oai?verb=ListRecords&metadataPrefix=oai_dc"

# Get a single record
curl "http://localhost:4000/api/oai?verb=GetRecord&identifier=oai:domain.com:item:ID&metadataPrefix=oai_dc"
```

## OAI-PMH Verbs

| Verb | Purpose | Example |
|------|---------|---------|
| **Identify** | Repository information | `?verb=Identify` |
| **ListMetadataFormats** | Available formats | `?verb=ListMetadataFormats` |
| **ListSets** | Collection hierarchy | `?verb=ListSets` |
| **ListIdentifiers** | Item IDs with dates | `?verb=ListIdentifiers&metadataPrefix=oai_dc` |
| **ListRecords** | Full metadata records | `?verb=ListRecords&metadataPrefix=oai_dc` |
| **GetRecord** | Single record | `?verb=GetRecord&identifier=ID&metadataPrefix=oai_dc` |

## How Voile Data Maps to OAI-PMH

### Collections → Sets

Only **published collections** are exposed as OAI sets:

- Collections with `status = "published"` become harvestable sets
- Set specification: `collection:{collection_code}`
- Example: `collection:BK001` for a book collection

### Items → Records

Items in published collections become OAI records:

- Each item gets a unique OAI identifier: `oai:your-domain.com:item:{item_id}`
- Metadata is provided in Dublin Core format
- Updated timestamps enable incremental harvesting

### Metadata Format

Voile data is mapped to Dublin Core elements:

| Voile Field | Dublin Core |
|-------------|-------------|
| collection.title | dc:title |
| item_code, inventory_code, barcode | dc:identifier |
| collection.description | dc:description |
| acquisition_date | dc:date |
| location | dc:coverage |
| Static: "Physical Object" | dc:type |

## Advanced Features

### Selective Harvesting by Date

```bash
# Records updated after specific date
curl "http://localhost:4000/api/oai?verb=ListRecords&metadataPrefix=oai_dc&from=2024-01-01T00:00:00Z"

# Records within date range
curl "http://localhost:4000/api/oai?verb=ListRecords&metadataPrefix=oai_dc&from=2024-01-01T00:00:00Z&until=2024-12-31T23:59:59Z"
```

### Filtering by Collection (Set)

```bash
# Only records from specific collection
curl "http://localhost:4000/api/oai?verb=ListRecords&metadataPrefix=oai_dc&set=collection:BK001"
```

### Pagination with Resumption Tokens

When results exceed the page size, you'll receive a resumption token:

```xml
<resumptionToken cursor="0" completeListSize="500">eyJvZmZzZXQiOjEwMH0=</resumptionToken>
```

Use it to fetch the next page:

```bash
curl "http://localhost:4000/api/oai?verb=ListRecords&resumptionToken=eyJvZmZzZXQiOjEwMH0="
```

## Production Deployment

### Checklist

- [ ] Set `OAI_REPOSITORY_ID` environment variable to your domain
- [ ] Set `app_contact_email` in system settings (via admin interface)
- [ ] Add database indexes for performance:
  ```sql
  CREATE INDEX idx_items_updated_at ON items(updated_at);
  CREATE INDEX idx_collections_status ON collections(status);
  CREATE INDEX idx_collections_collection_code ON collections(collection_code);
  ```
- [ ] Ensure published collections exist
- [ ] Test all verbs with production URL
- [ ] Consider rate limiting for public API
- [ ] Register with OAI registries (optional)

### Configuration Example

```elixir
# config/runtime.exs (automatically configured)
config :voile,
  oai_pmh_repository_id: System.get_env("OAI_REPOSITORY_ID") || host
  
# Admin email is read from database setting 'app_contact_email'
```

## Testing

### Run Tests

```bash
# Run OAI-PMH tests
mix test test/voile_web/controllers/oai_pmh_controller_test.exs

# Run all tests
mix test
```

### Manual Testing

```bash
# Test with curl
curl "http://localhost:4000/api/oai?verb=Identify"

# Format output nicely
curl "http://localhost:4000/api/oai?verb=Identify" | xmllint --format -
```

### Validation

Validate your implementation with the official OAI-PMH validator:

**http://www.openarchives.org/Register/ValidateSite**

## Integration Examples

### Python (using Sickle)

```python
from sickle import Sickle

sickle = Sickle('http://localhost:4000/api/oai')

# Get repository info
identify = sickle.Identify()
print(identify.repositoryName)

# Harvest all records
records = sickle.ListRecords(metadataPrefix='oai_dc')
for record in records:
    print(record.header.identifier)
    print(record.metadata)
```

### Bash Script (Incremental Harvest)

```bash
#!/bin/bash
BASE_URL="http://localhost:4000/api/oai"
FROM_DATE=$(date -u -d "yesterday" +"%Y-%m-%dT%H:%M:%SZ")

curl "${BASE_URL}?verb=ListRecords&metadataPrefix=oai_dc&from=${FROM_DATE}" \
  -o "harvest_$(date +%Y%m%d).xml"
```

## Troubleshooting

### No Records Found

**Problem**: `ListRecords` returns empty results

**Solution**:
1. Ensure collections have `status = "published"`
2. Verify items exist in published collections
3. Check database:
   ```sql
   SELECT COUNT(*) FROM collections WHERE status = 'published';
   SELECT COUNT(*) FROM items WHERE collection_id IN 
     (SELECT id FROM collections WHERE status = 'published');
   ```

### Invalid Date Format

**Problem**: Error when using date filters

**Solution**: Use ISO 8601 format `YYYY-MM-DDThh:mm:ssZ`

✅ Correct: `2024-01-15T10:30:00Z`  
❌ Wrong: `2024-01-15` or `2024-01-15 10:30:00`

### Token Expired

**Problem**: Resumption token invalid or expired

**Solution**: Tokens expire after 60 minutes. Restart harvesting from the beginning.

## Documentation

### Complete Documentation Set

1. **[quickstart.md](quickstart.md)** - Quick start guide with examples
2. **[implementation.md](implementation.md)** - Complete technical reference
3. **[architecture.md](architecture.md)** - Implementation summary

### API Reference

The implementation follows the official specification:

- **Protocol Spec**: https://www.openarchives.org/OAI/2.0/openarchivesprotocol.html
- **Guidelines**: https://www.openarchives.org/OAI/2.0/guidelines.htm
- **Dublin Core**: https://www.dublincore.org/specifications/dublin-core/dces/

## Files Added

### Core Implementation
- `lib/voile/oai_pmh.ex` - Context module with business logic
- `lib/voile/oai_pmh/xml_builder.ex` - XML response builder
- `lib/voile_web/controllers/oai_pmh_controller.ex` - HTTP controller

### Tests
- `test/voile_web/controllers/oai_pmh_controller_test.exs` - Test suite

### Configuration
- `config/dev.exs` - Development configuration
- `config/runtime.exs` - Production configuration

### Documentation
- `docs/README_OAI_PMH.md` - This file
- `docs/quickstart.md` - Quick start guide
- `docs/implementation.md` - Full documentation
- `docs/architecture.md` - Implementation summary

## Support

### Getting Help

- Check the **[Quick Start Guide](quickstart.md)** for common tasks
- Review **[Implementation Guide](implementation.md)** for technical details
- Consult the **[OAI-PMH Specification](https://www.openarchives.org/OAI/2.0/guidelines.htm)**

### Common Resources

- **OAI-PMH Official Site**: https://www.openarchives.org/pmh/
- **Dublin Core Initiative**: https://www.dublincore.org/
- **OAI Validator**: http://www.openarchives.org/Register/ValidateSite
- **OAI Registry**: http://www.openarchives.org/Register/BrowseSites

## Future Enhancements

Potential improvements for future versions:

1. **Additional Metadata Formats**
   - Full MARC21 implementation
   - MODS (Metadata Object Description Schema)
   - Qualified Dublin Core with refinements

2. **Advanced Features**
   - Soft delete support for tracking removed items
   - Response compression (gzip/deflate)
   - Provenance metadata in `<about>` containers
   - Enhanced set descriptions

3. **Performance**
   - Response caching
   - CDN integration
   - Query optimization
   - Analytics and monitoring

## License

This OAI-PMH implementation follows the OAI-PMH specification which is freely available for implementation. The Voile project license applies to this code.

---

**Ready to start?** Check out the **[Quick Start Guide](quickstart.md)** to get your OAI-PMH endpoint up and running in minutes!