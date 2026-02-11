# OAI-PMH Metadata Mapping Documentation

## Overview

The Voile OAI-PMH implementation uses a flexible metadata mapping system that extracts metadata from your collection fields and maps them to standard Dublin Core elements based on vocabulary prefixes and local names.

## Architecture

### Data Flow

```
Collection
  ├─> mst_creator (primary creator from mst_creator table)
  └─> Collection Fields (metadata definitions)
       └─> Metadata Properties
            └─> Vocabulary (dcterms, bibo, foaf, etc.)

Item
  └─> belongs to Collection
       ├─> inherits primary creator from Collection.mst_creator
       └─> inherits additional metadata from Collection Fields
```

### Key Components

1. **Master Creator (mst_creator)**: Primary creator/author associated with collection (Person, Organization, etc.)
2. **Collection Fields**: Field definitions at the collection level (stored in `collection_fields` table)
3. **Metadata Properties**: Define the semantic meaning of fields (stored in `metadata_properties` table)
4. **Vocabularies**: Define the namespace and prefix (Dublin Core, BIBO, FOAF, etc.)
5. **OAI-PMH Mapper**: Transforms collection metadata into Dublin Core elements

## Supported Vocabularies

### 1. Dublin Core Terms (dcterms)

The primary vocabulary for basic resource metadata.

| Property Local Name | Maps to DC Element | Example |
|---------------------|-------------------|---------|
| `title` | dc:title | Book title |
| `creator` | dc:creator | Author name |
| `subject` | dc:subject | Topic/keyword |
| `description` | dc:description | Abstract/summary |
| `publisher` | dc:publisher | Publishing house |
| `contributor` | dc:contributor | Editor, translator |
| `date` | dc:date | Publication date |
| `type` | dc:type | Resource type |
| `format` | dc:format | Physical format |
| `identifier` | dc:identifier | ISBN, DOI, etc. |
| `source` | dc:source | Original source |
| `language` | dc:language | Language code |
| `relation` | dc:relation | Related resources |
| `coverage` | dc:coverage | Spatial/temporal |
| `rights` | dc:rights | Rights information |
| `audience` | dc:audience | Target audience |
| `alternative` | dc:title | Alternative title |
| `tableOfContents` | dc:description | Table of contents |
| `abstract` | dc:description | Abstract text |
| `created` | dc:date | Creation date |
| `valid` | dc:date | Validity date |
| `available` | dc:date | Availability date |
| `issued` | dc:date | Issue date |
| `modified` | dc:date | Modification date |
| `extent` | dc:format | Size/duration |
| `medium` | dc:format | Physical medium |
| `isVersionOf` | dc:relation | Version relation |
| `hasVersion` | dc:relation | Has version |
| `isReplacedBy` | dc:relation | Replaced by |
| `replaces` | dc:relation | Replaces |
| `isRequiredBy` | dc:relation | Required by |
| `requires` | dc:relation | Requires |
| `isPartOf` | dc:relation | Part of |
| `hasPart` | dc:relation | Has part |
| `isReferencedBy` | dc:relation | Referenced by |
| `references` | dc:relation | References |
| `isFormatOf` | dc:relation | Format of |
| `hasFormat` | dc:relation | Has format |

### 2. Bibliographic Ontology (bibo)

Specialized vocabulary for bibliographic resources.

| Property Local Name | Maps to DC Element | Example |
|---------------------|-------------------|---------|
| `isbn` | dc:identifier | ISBN number |
| `issn` | dc:identifier | ISSN number |
| `doi` | dc:identifier | DOI |
| `author` | dc:creator | Book author |
| `editor` | dc:contributor | Editor |
| `abstract` | dc:description | Abstract |
| `pages` | dc:format | Page count |
| `volume` | dc:relation | Volume number |
| `issue` | dc:relation | Issue number |

### 3. Friend of a Friend (foaf)

Vocabulary for people and organizations.

| Property Local Name | Maps to DC Element | Example |
|---------------------|-------------------|---------|
| `name` | dc:creator | Person/org name |
| `title` | dc:title | Title/position |
| `homepage` | dc:source | Website URL |

### 4. Custom Vocabularies (kandaga_book, etc.)

Custom vocabularies map common field names to Dublin Core elements.

| Field Name | Maps to DC Element | Notes |
|------------|-------------------|-------|
| `title` | dc:title | Universal title field |
| `creator` / `author` | dc:creator | Creator/author |
| `description` / `abstract` / `notes` | dc:description | Descriptive text |
| `publisher` | dc:publisher | Publisher name |
| `date` / `publishedYear` | dc:date | Date fields |
| `subject` / `keywords` / `classification` | dc:subject | Subject/topic |
| `language` | dc:language | Language |
| `identifier` / `isbn` / `issn` / `callNumber` | dc:identifier | Identifiers |
| `format` / `collation` / `extent` | dc:format | Format info |
| `edition` / `seriesTitle` | dc:relation | Relations |
| `location` | dc:coverage | Location |

## Item-Level Metadata

Each OAI-PMH record includes both collection-level and item-level metadata:

### Collection-Level Metadata

#### Primary Creator (dc:creator)
- Extracted from `collection.mst_creator.creator_name`
- The main creator/author from the `mst_creator` table
- Types include: Person, Organization, Group, Conference, Event, Project, Institution

#### Additional Metadata (dc:creator, dc:contributor, etc.)
- Extracted from `collection_fields` table
- Mapped via `metadata_properties` and `vocabularies`
- Includes bibliographic information (additional creators, publisher, etc.)
- Multiple creators can exist (primary from mst_creator + additional from collection_fields)

### Item-Level Metadata
- **Identifiers**: `item_code`, `inventory_code`, `barcode`
- **Relation**: Collection relationship
- **Coverage**: Physical location

## Example Mapping

### Collection Fields in Database

```csv
id,name,label,value,property_id
uuid-1,title,Title,"INSEMINASI BUATAN PADA SAPI",182
uuid-2,publisher,Publisher,"SINERGI PUSTAKA INDONESIA",187
uuid-3,publishedYear,Published Year,"2010",188
uuid-4,callNumber,Call Number,"636.082 45 Zum i",193
uuid-5,classification,Classification,"636.082 45",196
```

### Metadata Properties

```csv
id,label,local_name,vocabulary_id
182,Title,title,1
187,Publisher,publisher,1
188,Published Year,publishedYear,1
193,Call Number,callNumber,5
196,Classification,classification,5
```

### Vocabularies

```csv
id,label,prefix,namespace_url
1,Dublin Core,dcterms,http://purl.org/dc/terms/
5,Kandaga Book Vocabulary,kandaga_book,https://kandaga.unpad.ac.id/vocab/book/
```

### Resulting OAI-PMH Record

```xml
<oai_dc:dc xmlns:oai_dc="http://www.openarchives.org/OAI/2.0/oai_dc/"
           xmlns:dc="http://purl.org/dc/elements/1.1/"
           xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
           xsi:schemaLocation="http://www.openarchives.org/OAI/2.0/oai_dc/ 
                               http://www.openarchives.org/OAI/2.0/oai_dc.xsd">
  <dc:title>INSEMINASI BUATAN PADA SAPI</dc:title>
  <dc:creator>Zumrotun</dc:creator><!-- from mst_creator -->
  <dc:publisher>SINERGI PUSTAKA INDONESIA</dc:publisher>
  <dc:date>2010</dc:date>
  <dc:format>iv, 60 hlm, ilus; 25 cm</dc:format>
  <dc:identifier>636.082 45 Zum i</dc:identifier>
  <dc:identifier>978-979-046-737-8</dc:identifier>
  <dc:subject>636.082 45</dc:subject>
  <dc:identifier>fapet-book-50be757e-eccb-4530-8850-9b4768891bf4-1762502344-001</dc:identifier>
  <dc:identifier>INV/FAPET/Book/50be757e-eccb-4530-8850-9b4768891bf4/001</dc:identifier>
  <dc:identifier>9b4768891bf4001</dc:identifier>
  <dc:relation>collection:COLLECTION-FAPET-LIB-1762500585-84cdc6</dc:relation>
  <dc:coverage>Fakultas Peternakan</dc:coverage>
</oai_dc:dc>
```

**Note**: The `dc:creator` element "Zumrotun" comes from the collection's linked `mst_creator` record. If there were additional creators in the collection_fields, they would also appear as separate `dc:creator` elements.

## Implementation Details

### Code Location

- **Main OAI-PMH Module**: `lib/voile/oai_pmh.ex`
- **XML Builder**: `lib/voile/oai_pmh/xml_builder.ex`
- **Controller**: `lib/voile_web/controllers/oai_pmh_controller.ex`

### Key Functions

#### `extract_dublin_core_from_collection_fields/1`

Extracts metadata from collection fields and builds a Dublin Core map.

```elixir
defp format_metadata(item, "oai_dc") do
  # Start with item-level metadata
  base_metadata = %{
    identifier: [item.item_code, item.inventory_code, item.barcode] |> Enum.reject(&is_nil/1),
    relation: ["collection:#{item.collection.collection_code}"],
    coverage: [item.location]
  }

  # Add collection's primary creator from mst_creator
  base_metadata =
    if item.collection.mst_creator do
      Map.put(base_metadata, :creator, [item.collection.mst_creator.creator_name])
    else
      base_metadata
    end

  # Extract metadata from collection fields (includes additional creators)
  field_metadata = extract_dublin_core_from_collection_fields(item.collection)

  # Merge base and field metadata, concatenating arrays for same keys
  Map.merge(base_metadata, field_metadata, fn _k, v1, v2 ->
    List.wrap(v1) ++ List.wrap(v2)
  end)
  |> Enum.reject(fn {_k, v} -> v == [] || v == [nil] end)
  |> Map.new()
end

defp extract_dublin_core_from_collection_fields(collection) do
  collection.collection_fields
  |> Enum.reduce(%{}, fn field, acc ->
    case map_collection_field_to_dublin_core(field) do
      {dc_field, value} when not is_nil(value) and value != "" ->
        Map.update(acc, dc_field, [value], fn existing -> existing ++ [value] end)
      _ ->
        acc
    end
  end)
end
```

#### `map_collection_field_to_dublin_core/1`

Maps a collection field to a Dublin Core element based on vocabulary prefix and property local name.

```elixir
defp map_collection_field_to_dublin_core(field) do
  property = field.metadata_properties
  vocabulary = property.vocabulary
  
  dc_field = case {vocabulary.prefix, property.local_name} do
    {"dcterms", "title"} -> :title
    {"dcterms", "creator"} -> :creator
    # ... more mappings
    {_prefix, "title"} -> :title  # Generic mapping
    _ -> nil
  end
  
  if dc_field, do: {dc_field, field.value}, else: nil
end
```

## Adding New Mappings

To add support for new metadata properties:

1. **Create the vocabulary** (if needed):
   ```sql
   INSERT INTO metadata_vocabularies (label, prefix, namespace_url, information)
   VALUES ('My Vocabulary', 'myprefix', 'http://example.org/vocab/', 'Description');
   ```

2. **Create metadata properties**:
   ```sql
   INSERT INTO metadata_properties (label, local_name, vocabulary_id, type_value, information)
   VALUES ('My Field', 'myfield', vocabulary_id, 'text', 'Description');
   ```

3. **Add mapping in `oai_pmh.ex`**:
   ```elixir
   defp map_collection_field_to_dublin_core(field) do
     # ... existing code
     dc_field = case {vocabulary.prefix, property.local_name} do
       # ... existing mappings
       {"myprefix", "myfield"} -> :appropriate_dc_element
       # ... rest of mappings
     end
   end
   ```

4. **Test the mapping**:
   ```bash
   curl "http://localhost:4000/api/oai?verb=GetRecord&identifier=oai:domain:item:item_id&metadataPrefix=oai_dc"
   ```

## Best Practices

1. **Use Standard Vocabularies**: Prefer Dublin Core Terms (dcterms) for common fields
2. **Consistent Naming**: Use consistent local names across vocabularies
3. **Complete Metadata**: Fill in as many Dublin Core elements as possible
4. **Quality Control**: Ensure metadata values are clean and well-formatted
5. **Multiple Values**: Dublin Core allows multiple values for most elements

## Testing Metadata Mapping

### Test Single Record
```bash
curl "http://localhost:4000/api/oai?verb=GetRecord&identifier=oai:localhost:4000:item:ITEM_ID&metadataPrefix=oai_dc"
```

### Test Multiple Records
```bash
curl "http://localhost:4000/api/oai?verb=ListRecords&metadataPrefix=oai_dc"
```

### Validate XML
```bash
curl "http://localhost:4000/api/oai?verb=ListRecords&metadataPrefix=oai_dc" | xmllint --format -
```

## Troubleshooting

### Missing Metadata

**Problem**: Some fields don't appear in OAI-PMH output

**Solutions**:
1. **For primary creator**: Check if collection has `creator_id` linked to `mst_creator` table
2. **For collection fields**: Check if `collection_fields` exist for the collection
3. Verify `property_id` links to valid metadata property
4. Ensure vocabulary prefix is recognized in mapping function
5. Check that field `value` is not null or empty
6. Verify preloading includes `:mst_creator` association

### Incorrect Mapping

**Problem**: Field maps to wrong Dublin Core element

**Solutions**:
1. Review vocabulary prefix and local_name combination
2. Check mapping priority (specific prefix mappings override generic ones)
3. Verify vocabulary configuration in database

### Duplicate Values

**Problem**: Same value appears multiple times

**Solutions**:
1. Check if multiple collection fields map to same DC element
2. Review merge logic in `extract_dublin_core_from_collection_fields`
3. Consider if duplication is intentional (e.g., multiple creators: one from mst_creator + additional from collection_fields)
4. This is often correct behavior - Dublin Core allows multiple values for creator, contributor, etc.

## References

- [Dublin Core Metadata Terms](https://www.dublincore.org/specifications/dublin-core/dcmi-terms/)
- [OAI-PMH v2.0 Specification](https://www.openarchives.org/OAI/openarchivesprotocol.html)
- [Dublin Core OAI-PMH Guidelines](https://www.openarchives.org/OAI/2.0/guidelines-oai_dc.htm)
- [BIBO Vocabulary](http://purl.org/ontology/bibo/)
- [FOAF Vocabulary](http://xmlns.com/foaf/spec/)

## Related Documentation

- [OAI-PMH Implementation Guide](implementation.md)
- [OAI-PMH Quick Start](quickstart.md)
- [OAI-PMH Architecture](architecture.md)