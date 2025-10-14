# Simplified CSV Import Guide for Collections

## 📝 New Simplified Format

Instead of complex column naming like `collection_field_1_name`, `collection_field_1_label`, etc., 
the new format uses **property names directly as column headers**.

## ✨ Key Improvement

**OLD FORMAT (Complex):**
```csv
collection_code,title,...,collection_field_1_name,collection_field_1_label,collection_field_1_value,...
COL001,Book Title,...,author,Author,José Valim,...
```

**NEW FORMAT (Simple):**
```csv
collection_code,title,...,author,subject,publisher,...
COL001,Book Title,...,José Valim,Programming,Pragmatic,...
```

Just add property names as column headers and fill in the values directly!

---

## Required Columns

These columns must always be present:

| Column | Description | Example |
|--------|-------------|---------|
| `title` | Collection title | "Introduction to Elixir" |
| `description` | Detailed description | "A comprehensive guide..." |
| `status` | Publication status | draft, pending, **published**, archived |
| `access_level` | Access control | **public**, private, restricted |
| `thumbnail` | Image URL | https://example.com/image.jpg |
| `creator_id` | Creator ID number | 1 |

---

## Optional Collection Columns

| Column | Description | Example |
|--------|-------------|---------|
| `collection_code` | Unique identifier | COL001 |
| `collection_type` | Type of collection | book, series, movie, album, course |
| `sort_order` | Display order | 1, 2, 3... |
| `parent_id` | Parent collection UUID | 550e8400-e29b-... |
| `type_id` | Resource class ID | 1 |
| `template_id` | Resource template ID | 1 |
| `unit_id` | Node/unit ID | 1 |

---

## Dynamic Property Columns

**The Magic Part!** 🎉

You can add ANY property column by using its property name. The system will automatically:
1. Recognize the property
2. Create a collection field
3. Link it to the correct property

### Common Properties

| Property Name | Description | Example Value |
|--------------|-------------|---------------|
| `author` | Author name | José Valim |
| `subject` | Subject/topic | Programming Languages |
| `publisher` | Publisher name | Pragmatic Bookshelf |
| `isbn` | ISBN number | 978-1-68050-252-7 |
| `edition` | Edition number | 2nd Edition |
| `publication_year` | Year published | 2024 |
| `language` | Language | English, Indonesian |
| `pages` | Number of pages | 350 |

**You can use ANY property that exists in your system!**

---

## Item Columns (Optional)

To add physical items (copies), use these columns for each item:

### Item 1
- `item_1_item_code` - Unique item code (required if adding item)
- `item_1_inventory_code` - Inventory code (required)
- `item_1_location` - Physical location (required)
- `item_1_status` - active, inactive, lost, damaged, discarded
- `item_1_condition` - excellent, good, fair, poor, damaged
- `item_1_availability` - available, loaned, reserved, etc.
- `item_1_price` - Price in numbers (299000)
- `item_1_acquisition_date` - Date (YYYY-MM-DD)
- `item_1_rfid_tag` - RFID tag ID
- `item_1_unit_id` - Unit ID
- `item_1_item_location_id` - Location ID

### Item 2, 3, 4... (up to 50 items)
Just replace the number: `item_2_item_code`, `item_3_item_code`, etc.

---

## Simple Example

### Minimal CSV (Just required fields)
```csv
title,description,status,access_level,thumbnail,creator_id
My First Book,This is a test book,published,public,https://img.jpg,1
```

### With Properties
```csv
title,description,status,access_level,thumbnail,creator_id,author,subject,publisher
Elixir Book,A programming guide,published,public,https://img.jpg,1,José Valim,Programming,Pragmatic
```

### With Items
```csv
title,description,status,access_level,thumbnail,creator_id,author,subject,item_1_item_code,item_1_inventory_code,item_1_location,item_1_status,item_1_condition,item_1_availability
Elixir Book,A guide,published,public,https://img.jpg,1,José Valim,Programming,ITEM001,INV001,Section A,active,excellent,available
```

### Complete Example
```csv
collection_code,title,description,status,access_level,thumbnail,creator_id,collection_type,author,subject,publisher,isbn,item_1_item_code,item_1_inventory_code,item_1_location,item_1_status,item_1_condition,item_1_availability,item_1_price
COL001,Introduction to Elixir,A comprehensive guide,published,public,https://img.jpg,1,book,José Valim,Programming,Pragmatic,978-1-234567-89-0,ITEM001,INV001,Section A,active,excellent,available,299000
```

---

## Step-by-Step Instructions

### 1. Download Template
- Go to the Import page in dashboard
- Click "Download Template" button
- Template includes all available properties as columns

### 2. Open in Excel/Google Sheets
- Open the downloaded CSV file
- You'll see all columns ready to fill

### 3. Fill Your Data
- Fill required columns (title, description, etc.)
- Fill any property columns you want (author, subject, etc.)
- Leave unused columns empty (not "NULL" or "N/A", just empty)
- Add item columns if you have physical copies

### 4. Save as CSV
- **Excel:** Save As → CSV (Comma delimited) (*.csv)
- **Google Sheets:** File → Download → Comma Separated Values (.csv)
- Make sure encoding is UTF-8

### 5. Upload & Import
- Go back to Import page
- Upload your CSV file
- Click "Preview" to check (optional)
- Click "Import Now"
- Done! ✅

---

## Tips & Best Practices

### ✅ DO:
- Use exact property names as shown in template
- Leave empty cells blank (no spaces)
- Use dates as YYYY-MM-DD (2024-01-15)
- Use dots for decimals (299000.50)
- Enclose text with commas in quotes: "Title, with comma"

### ❌ DON'T:
- Don't add spaces in empty cells
- Don't use NULL, N/A, or - for empty values
- Don't use commas in numbers (299,000 → 299000)
- Don't change column names
- Don't mix up required values (status: "Published" → should be "published")

---

## Value Options Reference

### Status (Choose one)
- `draft` - Not yet ready
- `pending` - Waiting for approval
- `published` - ✅ Available to users
- `archived` - No longer active

### Access Level (Choose one)
- `public` - ✅ Everyone can access
- `private` - Restricted access
- `restricted` - Limited access

### Collection Type (Choose one)
- `book` - Books
- `series` - Series/Collections
- `movie` - Movies/Films
- `album` - Music albums
- `course` - Course materials
- `other` - Other types

### Item Status (Choose one)
- `active` - ✅ In circulation
- `inactive` - Not in use
- `lost` - Missing
- `damaged` - Damaged
- `discarded` - Removed from collection

### Item Condition (Choose one)
- `excellent` - Like new
- `good` - ✅ Minor wear
- `fair` - Noticeable wear
- `poor` - Significant wear
- `damaged` - Damaged

### Item Availability (Choose one)
- `available` - ✅ Ready to borrow
- `loaned` - Currently borrowed
- `reserved` - Reserved by someone
- `reference_only` - Cannot be borrowed
- `non_circulating` - For reference only
- `maintenance` - Under maintenance
- `in_processing` - Being processed
- And more...

---

## Need Help?

### Getting Property Names
1. Go to dashboard
2. Click "Import Collections"
3. Look at the "Available Properties" list in the sidebar
4. Use those exact names as column headers

### Common Errors

**"Unknown property columns"**
- Check spelling of property names
- Use exact names from Available Properties list
- Properties are case-sensitive

**"title: can't be blank"**
- Make sure required fields are filled
- Required: title, description, status, access_level, thumbnail, creator_id

**"Invalid status"**
- Use lowercase: published, not Published
- Only use: draft, pending, published, archived

**"Duplicate item_code"**
- Each item code must be unique across the entire system
- Use a prefix: ITEM001, ITEM002, etc.

---

## Example: Real World Use Case

### Importing a Book Collection

**You have:** 
- 5 books
- 2 copies of each book
- Metadata: author, subject, publisher, ISBN

**CSV Structure:**
```csv
title,description,status,access_level,thumbnail,creator_id,author,subject,publisher,isbn,item_1_item_code,item_1_inventory_code,item_1_location,item_1_status,item_1_condition,item_1_availability,item_2_item_code,item_2_inventory_code,item_2_location,item_2_status,item_2_condition,item_2_availability
Elixir in Action,Learn Elixir programming,published,public,https://img1.jpg,1,Saša Jurić,Programming,Manning,978-1-61729-201-5,ITEM001,INV001,Shelf A1,active,excellent,available,ITEM002,INV002,Shelf A1,active,good,available
Programming Phoenix,Build web apps,published,public,https://img2.jpg,1,Chris McCord,Web Dev,Pragmatic,978-1-68050-252-7,ITEM003,INV003,Shelf A2,active,excellent,available,ITEM004,INV004,Shelf A2,active,excellent,available
```

**Result:**
- 2 collections created
- 8 collection fields (4 per collection)
- 4 items created (2 per collection)

---

## Success! 🎉

You're now ready to import collections with the simplified CSV format!

Remember:
1. Download template from dashboard
2. Use property names as column headers
3. Fill in your data
4. Upload and import
5. Enjoy! ✨
