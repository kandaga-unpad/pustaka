# Voile Data Migration Guide

This guide explains how to migrate data from SLiMS to Voile using the unified migration system.

## 📋 Overview

The Voile migration system supports two data sources:

1. **CSV Files** (default) - Import from exported CSV files
2. **MySQL Database** - Import directly from SLiMS MySQL database

## 🚀 Quick Start

### CSV Migration (Default)

1. **Prepare CSV files** in the following structure:

   ```
   scripts/csv_data/
   ├── biblio/       # Bibliography data
   │   ├── biblio.csv
   │   ├── biblio_8.csv
   │   ├── biblio_20.csv
   │   ├── biblio_author_8.csv
   │   ├── biblio_author_20.csv
   │   └── ...
   ├── items/        # Item/copy data
   │   ├── item.csv
   │   ├── item_8.csv
   │   ├── item_20.csv
   │   └── ...
   ├── member/       # Member data
   │   ├── member.csv
   │   ├── member_8.csv
   │   ├── member_20.csv
   │   └── ...
   ├── mst/          # Master data
   │   ├── mst_author_8.csv
   │   ├── mst_publisher_8.csv
   │   ├── mst_author_20.csv
   │   ├── mst_publisher_20.csv
   │   └── ...
   └── user/         # Staff user data
       ├── user.csv
       └── ...
   ```

2. **Run migration**:

   ```bash
   # Import all data types
   mix voile.migrate

   # Import specific data type
   mix voile.migrate --only biblio
   mix voile.migrate --only items
   mix voile.migrate --only members
   mix voile.migrate --only users
   mix voile.migrate --only masters
   ```

### MySQL/MariaDB Migration

1. **Configure database** in `config/dev.exs`:

   ```elixir
   config :voile, :mysql_source,
     hostname: "localhost",
     port: 3306,                    # Default port for MySQL/MariaDB
     username: "slims_user",
     password: "slims_password",
     database: "slims_database"
   ```

   **Note**: Both MySQL and MariaDB are fully supported using the same configuration.

2. **Install MySQL dependency**:

   ```bash
   mix deps.get
   ```

3. **Run migration**:

   ```bash
   # Import all data from MySQL/MariaDB
   mix voile.migrate --source mysql

   # Import specific data type from MySQL/MariaDB
   mix voile.migrate --source mysql --only biblio
   mix voile.migrate --source mysql --only items
   ```

## 📚 Command Reference

### Basic Commands

```bash
# Show help
mix voile.migrate --help

# Full migration from CSV (default)
mix voile.migrate

# Full migration from MySQL/MariaDB
mix voile.migrate --source mysql

# Validate migration results
mix voile.migrate --validate
```

### Partial Migration

```bash
# Import only master data (authors, publishers)
mix voile.migrate --only masters

# Import only bibliography data
mix voile.migrate --only biblio

# Import only physical items
mix voile.migrate --only items

# Import only library members
mix voile.migrate --only members

# Import only staff users
mix voile.migrate --only users
```

### Advanced Options

```bash
# Skip image downloads (faster)
mix voile.migrate --only biblio --skip-images

# Custom batch size
mix voile.migrate --batch-size 1000

# MySQL source with validation
mix voile.migrate --source mysql --validate

# Combined options
mix voile.migrate --source mysql --only biblio --skip-images --batch-size 500
```

## 🗂️ Data Types & Dependencies

The system imports data in dependency order:

1. **Masters** (authors, publishers) - No dependencies
2. **Bibliography** (collections) - Depends on masters
3. **Items** (physical copies) - Depends on bibliography
4. **Users** (staff accounts) - No dependencies
5. **Members** (library members) - No dependencies

## 🔧 Configuration

### CSV Configuration

No additional configuration needed. Just ensure CSV files are in the correct directory structure.

### MySQL Configuration

Add to your `config/dev.exs`:

```elixir
config :voile, :mysql_source,
  hostname: "localhost",        # MySQL server hostname
  port: 3306,                  # MySQL port (default: 3306)
  username: "slims_user",      # MySQL username
  password: "slims_password",  # MySQL password
  database: "slims_database"   # SLiMS database name
```

## 📊 Expected Data Formats

### Bibliography Data (biblio table/CSV)

- `biblio_id`, `title`, `sor`, `edition`, `isbn_issn`, `publisher_id`, etc.

### Item Data (item table/CSV)

- `item_id`, `biblio_id`, `call_number`, `item_code`, etc.

### Member Data (member table/CSV)

- `member_id`, `member_name`, `gender`, `birth_date`, etc.

### User Data (user table/CSV)

- `user_id`, `username`, `realname`, `user_type`, etc.

### Master Data

- **Authors**: `author_id`, `author_name`, `author_type`, etc.
- **Publishers**: `publisher_id`, `publisher_name`, etc.
- **Relationships**: `biblio_id`, `author_id`, `level`

## ✅ Validation

After migration, validate data integrity:

```bash
mix voile.migrate --validate
```

This checks:

- Data counts and integrity
- Required relationships
- Data consistency
- Sample record preview

## 🚨 Troubleshooting

### CSV Issues

- **Missing files**: Ensure CSV files exist in correct directories
- **Invalid format**: Check CSV headers match expected format
- **Encoding**: Ensure CSV files use UTF-8 encoding

### MySQL/MariaDB Issues

- **Connection failed**: Check database credentials and network connectivity
- **Table not found**: Ensure SLiMS database schema is complete
- **Permission denied**: Verify database user has SELECT permissions
- **Port issues**: MariaDB typically uses port 3306 (same as MySQL)
- **Version compatibility**: Both MySQL 5.7+ and MariaDB 10.0+ are supported

### Common Errors

- **Dependency errors**: Run masters before other data types
- **Memory issues**: Reduce batch size: `--batch-size 100`
- **Timeout**: Process data in smaller chunks using `--only` option

## 🔄 Migration Strategies

### Full Migration (Recommended)

```bash
# CSV source
mix voile.migrate

# MySQL/MariaDB source
mix voile.migrate --source mysql
```

### Incremental Migration

```bash
# Step 1: Master data
mix voile.migrate --only masters

# Step 2: Bibliography
mix voile.migrate --only biblio

# Step 3: Items
mix voile.migrate --only items

# Step 4: Users & Members
mix voile.migrate --only users
mix voile.migrate --only members

# Step 5: Validate
mix voile.migrate --validate
```

### Performance Migration

```bash
# Large datasets - skip images, increase batch size
mix voile.migrate --skip-images --batch-size 1000

# MySQL/MariaDB with chunked processing
mix voile.migrate --source mysql --batch-size 2000
```

## 📝 Notes

- **Backup**: Always backup your Voile database before migration
- **Idempotency**: The system handles duplicates gracefully
- **Logging**: Check console output for progress and errors
- **Performance**: MySQL/MariaDB direct connection is typically faster than CSV
- **Database Support**: Both MySQL and MariaDB are fully supported with identical configuration
- **Safety**: Both modes include transaction safety and rollback on errors

## 🤝 Support

For issues or questions:

1. Check console output for detailed error messages
2. Run validation to identify specific problems: `mix voile.migrate --validate`
3. Review this guide for configuration examples
4. Check database connections and permissions
