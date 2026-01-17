# Leftover Migration Guide

This guide explains how to run the leftover migration scripts for importing collections and items that were missed during the initial migration process.

## 📋 Overview

The leftover migration consists of two scripts:

1. **LeftoverBiblioImporter** - Imports missing collections (bibliographic records)
2. **LeftoverItemImporter** - Imports missing items that reference the newly imported collections

These scripts are designed to handle data that couldn't be imported initially due to incomplete or mismatched records in the CSV files.

## ⚠️ Important Safety Notes

- **Always run LeftoverBiblioImporter first** - Items depend on collections existing
- **Test in development first** - Never run directly in production without testing
- **Backup your database** - Although the scripts use safe upsert operations, always have a backup
- **Check logs carefully** - Monitor for "skipped" or "not found" messages indicating data issues
- **Run in off-peak hours** - These operations can be resource-intensive
- **Scripts are idempotent** - They won't create duplicates if run multiple times

## 📋 Prerequisites

1. **CSV Data Files**: Ensure all CSV files are present in the correct directory structure:

   ```
   scripts/csv_data/
   ├── biblio/
   │   ├── biblio.csv
   │   ├── biblio_1.csv to biblio_20.csv
   │   └── biblio_author_*.csv
   ├── items/
   │   ├── item.csv
   │   └── item_1.csv to item_20.csv
   ├── mst/
   │   ├── mst_author_*.csv
   │   └── mst_publisher_*.csv
   ```

2. **Missing Item Codes CSV**: Prepare a CSV file with one column:

   ```csv
   item_code
   01001022400056
   01001092400003
   ... (other missing item codes)
   ```

3. **Database Access**: Ensure the application can connect to the database

4. **Application Running**: The Phoenix application should be running (for database connections)

## 🚀 Step-by-Step Migration Process

### Step 1: Prepare Your Environment

1. **Navigate to the application directory**:

   ```bash
   cd /path/to/voile/application
   ```

2. **Ensure the application is running** (or start it):

   ```bash
   mix phx.server
   ```

   Or if using Docker/production setup:

   ```bash
   # Your production startup command
   ```

3. **Verify CSV data location**:
   ```bash
   ls -la scripts/csv_data/
   ```

### Step 2: Run Leftover Biblio Importer

This imports collections for items that couldn't be imported initially.

```bash
mix run -e "Voile.Migration.LeftoverBiblioImporter.import_from_item_codes_csv(\"path/to/your/missing_item_codes.csv\")"
```

**Expected Output**:

```
📚 Starting leftover biblio import from item_codes CSV: path/to/your/missing_item_codes.csv...
📋 Found X item_codes to process
🔍 Found Y unique biblio_ids to import collections for
🔄 Initializing leftover biblio cache...
✅ Inserted collection for biblio_id: ZZZ
==================================================
LEFTOVER BIBLIO IMPORT SUMMARY
==================================================
Collections Inserted: A
Collections Skipped: B
Fields Inserted: C
==================================================
```

**What to watch for**:

- **Collections Inserted**: Number of new collections created
- **Collections Skipped**: Usually means they already exist (safe)
- **"Biblio row not found"**: Indicates missing data in biblio CSVs - investigate these
- **Insert errors**: Check database constraints or data format issues

### Step 3: Run Leftover Item Importer

After collections are imported, import the items.

```bash
mix run -e "Voile.Migration.LeftoverItemImporter.import_from_csv(\"path/to/your/missing_item_codes.csv\")"
```

**Expected Output**:

```
📦 Starting leftover item import from path/to/your/missing_item_codes.csv...
🔄 Initializing leftover cache...
✅ Cache initialized
🔗 Built biblio_id → collection_id map (X entries)
📋 Found Y item_codes to process
✅ Inserted item: ITEM_CODE
==================================================
LEFTOVER ITEM IMPORT SUMMARY
==================================================
Items Inserted: A
Items Skipped: B
Items Not Found in CSVs: C
==================================================
```

**What to watch for**:

- **Items Inserted**: Number of new items created
- **Items Not Found in CSVs**: Item codes not present in item CSV files - may indicate data issues
- **"Missing biblio_id"**: Items without corresponding collections - should be resolved by Step 2

### Step 4: Verification

After running both scripts:

1. **Check database counts**:

   ```bash
   # In iex console
   iex> Voile.Repo.aggregate(Voile.Schema.Catalog.Collection, :count)
   iex> Voile.Repo.aggregate(Voile.Schema.Catalog.Item, :count)
   ```

2. **Verify specific records**:

   ```bash
   # Check if your test item codes now exist
   iex> Voile.Repo.get_by(Voile.Schema.Catalog.Item, legacy_item_code: "01001022400056")
   ```

3. **Check for orphaned records**:
   ```bash
   # Items without collections (should be 0)
   iex> from(i in Voile.Schema.Catalog.Item, where: is_nil(i.collection_id), select: count(i.id)) |> Voile.Repo.one()
   ```

## 🔧 Recent Fixes

**Version Notes**: The scripts have been updated to prevent duplicate imports:

- **Duplicate Prevention**: LeftoverItemImporter now checks for existing items by `legacy_item_code` before inserting
- **Creator Fallback**: LeftoverBiblioImporter uses default creator when no primary creator is found
- **Field Validation**: Collection fields include all required attributes (name, label, type_value, etc.)

These fixes ensure the scripts are safe to run multiple times without creating duplicate data.

### Common Issues

1. **"CSV file not found"**
   - Check the file path is correct
   - Ensure file permissions allow reading
   - In production, verify the CSV directory is mounted correctly

2. **"Biblio row not found for biblio_id: XXX"**
   - The biblio CSV files are missing data for this ID
   - Check if the biblio*id exists in any biblio*\*.csv file
   - May indicate incomplete CSV export from SLiMS

3. **"Not found in CSVs: ITEM_CODE"**
   - The item code doesn't exist in any item\_\*.csv file
   - Verify the item code is spelled correctly
   - May indicate the item was never exported from SLiMS

4. **Database connection errors**
   - Ensure the application is running and can connect to the database
   - Check database credentials in config files

5. **Permission errors**
   - Ensure the application has write access to the database
   - Check database user permissions

### Data Integrity Checks

Before running in production:

1. **Test with a small CSV** (1-2 item codes):

   ```csv
   item_code
   01001022400056
   ```

2. **Verify the test imports correctly**

3. **Check that existing data is not modified**:
   - Run counts before and after
   - Spot-check existing records remain unchanged

4. **Monitor database performance**:
   - Large imports may take time
   - Watch for database locks or timeouts

## 📊 Expected Results

- **Collections**: Should be created for previously missing biblio_ids
- **Items**: Should be created for the specified item codes
- **No duplicates**: Existing records should not be modified (scripts check for existing legacy_item_codes)
- **Data consistency**: All items should have valid collection references

## 🔄 Rollback Plan

If issues occur:

1. **Stop the application**
2. **Restore from database backup**
3. **Investigate the cause** using the logged error messages
4. **Fix the underlying data issue** (missing CSVs, incorrect paths, etc.)
5. **Re-run the migration**

## 📞 Support

If you encounter issues:

1. Check the application logs for detailed error messages
2. Verify CSV file integrity and paths
3. Test with known good data first
4. Contact the development team with specific error messages and item codes that failed

## ✅ Production Checklist

- [ ] Database backup completed
- [ ] Test run successful in development
- [ ] CSV files verified and accessible
- [ ] Application running and database connected
- [ ] Off-peak hours scheduled
- [ ] Monitoring tools ready
- [ ] Rollback plan prepared
