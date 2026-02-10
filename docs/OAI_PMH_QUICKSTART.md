# OAI-PMH Quick Start Guide

## What is OAI-PMH?

OAI-PMH (Open Archives Initiative Protocol for Metadata Harvesting) is a protocol for sharing metadata between repositories. It allows other systems to "harvest" your catalog data in a standardized way.

**Use Cases:**
- Share your library catalog with aggregators
- Enable federated search across multiple repositories
- Provide metadata to digital library platforms
- Support research and discovery tools

## Quick Setup

### 1. Install Dependencies

Add to your `mix.exs` (already done):

```elixir
{:xml_builder, "~> 2.2"}
```

Run:

```bash
mix deps.get
```

### 2. Configure Repository

Edit `config/runtime.exs` or `config/prod.exs`:

```elixir
config :voile,
  oai_pmh_repository_id: "your-domain.com"
```

For development, you can use `config/dev.exs`:

```elixir
config :voile,
  oai_pmh_repository_id: "localhost:4000"
```

**Admin Email**: The admin email shown in OAI-PMH responses is automatically read from the database setting `app_contact_email`. Set this in the admin interface at **Settings > App Profile** (`/manage/settings/app-profile`).

### 3. Ensure Database Has Data

OAI-PMH exposes:
- **Collections** (with status = "published") as **Sets**
- **Items** in published collections as **Records**

Make sure you have:
- At least one published collection
- Items in that collection

### 4. Test the Endpoint

Start your Phoenix server:

```bash
mix phx.server
```

Test the OAI-PMH endpoint:

```bash
curl "http://localhost:4000/api/oai?verb=Identify"
```

You should see XML output with repository information.

## Basic Usage Examples

### 1. Get Repository Information

```bash
curl "http://localhost:4000/api/oai?verb=Identify"
```

**Returns:** Repository name, contact, earliest record date, etc.

### 2. List Available Metadata Formats

```bash
curl "http://localhost:4000/api/oai?verb=ListMetadataFormats"
```

**Returns:** Available formats (oai_dc, oai_marc)

### 3. List All Collections (Sets)

```bash
curl "http://localhost:4000/api/oai?verb=ListSets"
```

**Returns:** All published collections as OAI sets

### 4. List All Item Identifiers

```bash
curl "http://localhost:4000/api/oai?verb=ListIdentifiers&metadataPrefix=oai_dc"
```

**Returns:** List of item identifiers with timestamps

### 5. Get Full Records

```bash
curl "http://localhost:4000/api/oai?verb=ListRecords&metadataPrefix=oai_dc"
```

**Returns:** Complete metadata records for all items

### 6. Get Single Record

First, get an identifier from ListIdentifiers, then:

```bash
curl "http://localhost:4000/api/oai?verb=GetRecord&identifier=oai:your-domain.com:item:ITEM-ID&metadataPrefix=oai_dc"
```

## Advanced Queries

### Filter by Date

Harvest only records updated after a specific date:

```bash
curl "http://localhost:4000/api/oai?verb=ListRecords&metadataPrefix=oai_dc&from=2024-01-01T00:00:00Z"
```

### Filter by Date Range

```bash
curl "http://localhost:4000/api/oai?verb=ListRecords&metadataPrefix=oai_dc&from=2024-01-01T00:00:00Z&until=2024-12-31T23:59:59Z"
```

### Filter by Collection (Set)

```bash
curl "http://localhost:4000/api/oai?verb=ListRecords&metadataPrefix=oai_dc&set=collection:BK001"
```

Replace `BK001` with your actual collection code.

### Handle Pagination

If results exceed page size, you'll get a resumption token:

```xml
<resumptionToken cursor="0" completeListSize="500">eyJvZmZzZXQiOjEwMH0=</resumptionToken>
```

Use it to get the next page:

```bash
curl "http://localhost:4000/api/oai?verb=ListRecords&resumptionToken=eyJvZmZzZXQiOjEwMH0="
```

## Testing with Tools

### 1. Browser Testing

Just paste the URL in your browser:

```
http://localhost:4000/api/oai?verb=Identify
```

Your browser will display the XML response.

### 2. Command Line with xmllint

Format the XML output nicely:

```bash
curl "http://localhost:4000/api/oai?verb=Identify" | xmllint --format -
```

### 3. Python OAI-PMH Client

Install the Sickle library:

```bash
pip install sickle
```

Use it to harvest:

```python
from sickle import Sickle

sickle = Sickle('http://localhost:4000/api/oai')

# Get repository info
identify = sickle.Identify()
print(identify.repositoryName)

# List all records
records = sickle.ListRecords(metadataPrefix='oai_dc')
for record in records:
    print(record.metadata)
```

### 4. OAI-PMH Validator

Validate your implementation online:
http://www.openarchives.org/Register/ValidateSite

## Common Issues

### No Records Found

**Problem:** `ListRecords` returns empty results

**Solution:**
1. Check that collections have `status = "published"`
2. Verify items exist in those collections
3. Run in your database:

```sql
SELECT * FROM collections WHERE status = 'published';
SELECT * FROM items WHERE collection_id IN (SELECT id FROM collections WHERE status = 'published');
```

### Invalid Date Format Error

**Problem:** Error when using date filters

**Solution:** Use ISO 8601 format: `YYYY-MM-DDThh:mm:ssZ`

**Correct:**
```
2024-01-15T10:30:00Z
```

**Incorrect:**
```
2024-01-15
2024-01-15 10:30:00
2024-01-15T10:30:00
```

### Identifier Not Found

**Problem:** `GetRecord` returns `idDoesNotExist` error

**Solution:**
1. Get valid identifiers from `ListIdentifiers` first
2. Make sure you're using the full OAI identifier format:
   ```
   oai:your-domain.com:item:UUID
   ```

### Resumption Token Expired

**Problem:** Token invalid or expired error

**Solution:**
- Tokens expire after 60 minutes
- Start harvesting from the beginning
- Process records faster or increase token expiry in code

## Integration Examples

### Example: Harvest All Records

Bash script to download all records:

```bash
#!/bin/bash

BASE_URL="http://localhost:4000/api/oai"
OUTPUT_DIR="./harvested"
mkdir -p "$OUTPUT_DIR"

# Get first batch
curl "${BASE_URL}?verb=ListRecords&metadataPrefix=oai_dc" > "${OUTPUT_DIR}/batch_0.xml"

# Extract resumption token and continue
# (Full implementation would parse XML and loop until no more tokens)
```

### Example: Daily Incremental Harvest

```bash
#!/bin/bash

BASE_URL="http://localhost:4000/api/oai"
FROM_DATE=$(date -u -d "yesterday" +"%Y-%m-%dT%H:%M:%SZ")

curl "${BASE_URL}?verb=ListRecords&metadataPrefix=oai_dc&from=${FROM_DATE}"
```

### Example: Harvest Specific Collection

```bash
#!/bin/bash

BASE_URL="http://localhost:4000/api/oai"
COLLECTION_CODE="BK001"

curl "${BASE_URL}?verb=ListRecords&metadataPrefix=oai_dc&set=collection:${COLLECTION_CODE}"
```

## Production Deployment

### Checklist

- [ ] Set environment variables in production config
- [ ] Update `oai_pmh_repository_id` to your domain
- [ ] Set correct admin email addresses
- [ ] Test all verbs with production URL
- [ ] Add database indexes for performance:
  ```sql
  CREATE INDEX idx_items_updated_at ON items(updated_at);
  CREATE INDEX idx_collections_status ON collections(status);
  ```
- [ ] Consider rate limiting for public access
- [ ] Monitor endpoint performance
- [ ] Register with OAI-PMH registries (optional)

### Performance Tips

1. **Database Indexes:** Essential for date-based queries
2. **Caching:** Cache repository info and sets list
3. **Page Sizes:** Default is 50-100, adjust if needed
4. **Monitoring:** Track request rates and response times

### Security Notes

- OAI-PMH endpoint is **public by default** (as per protocol)
- Only **published** collections are exposed
- No authentication required (standard practice)
- Consider rate limiting to prevent abuse
- Monitor for unusual traffic patterns

## Next Steps

1. **Read Full Documentation:** See `OAI_PMH_IMPLEMENTATION.md`
2. **Customize Metadata:** Extend Dublin Core mapping
3. **Add MARC Format:** Implement full MARC21 support
4. **Monitor Usage:** Track harvesting patterns
5. **Register Repository:** List in OAI registries

## Support

For issues or questions:
- Check the full documentation: `docs/OAI_PMH_IMPLEMENTATION.md`
- Review the OAI-PMH specification: https://www.openarchives.org/OAI/2.0/guidelines.htm
- Test with the official validator: http://www.openarchives.org/Register/ValidateSite

## Resources

- **OAI-PMH Protocol**: https://www.openarchives.org/pmh/
- **Dublin Core**: https://www.dublincore.org/
- **Sickle (Python client)**: https://github.com/mloesch/sickle
- **OAI Registry**: http://www.openarchives.org/Register/BrowseSites