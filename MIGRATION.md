# Voile Migration System

This document describes the migration system for importing data from SLiMS to Voile.

## Directory Structure

The migration system expects CSV files to be organized in the following structure:

```
scripts/csv_data/
├── biblio/          # Bibliography/collection data
│   ├── biblio_1.csv
│   ├── biblio_2.csv
│   └── ...
├── items/           # Item data
│   ├── item_1.csv
│   ├── item_2.csv
│   └── ...
├── member/          # Member data
│   ├── member_1.csv
│   ├── member_2.csv
│   └── ...
├── mst/            # Master data (authors, publishers)
│   ├── mst_author_1.csv
│   ├── mst_publisher_1.csv
│   ├── biblio_author_1.csv
│   └── ...
└── user/           # User/staff data
    └── user.csv
```

## Usage

### Full Migration
```bash
mix voile.migrate
```

### Partial Migration
```bash
# Import only specific data types
mix voile.migrate --only masters     # Authors and publishers
mix voile.migrate --only biblio      # Bibliography/collections
mix voile.migrate --only items       # Items
mix voile.migrate --only users       # Staff users
mix voile.migrate --only members     # Library members
```

### Options
```bash
# Skip image downloads during biblio import
mix voile.migrate --only biblio --skip-images

# Set custom batch size for bulk inserts
mix voile.migrate --batch-size 1000

# Run validation after migration
mix voile.migrate --validate

# Run only validation
mix voile.migrate --only validate
```

## Migration Order

The system automatically imports data in the correct dependency order:

1. **Master Data** (Authors & Publishers)
2. **Bibliography Data** (Collections)
3. **Item Data** (Physical items linked to collections)
4. **User Data** (Staff users)
5. **Member Data** (Library members with profiles)

## CSV File Formats

### Master Data Files

#### mst_author_*.csv
```csv
author_id,author_name,author_year,authority_type,auth_list,input_date,last_update
1,"John Doe","1980","p","","2024-01-01 00:00:00","2024-01-01 00:00:00"
```

#### mst_publisher_*.csv
```csv
publisher_id,publisher_name,...
1,"Academic Press",...
```

### Bibliography Files (biblio_*.csv)
```csv
biblio_id,title,sor,edition,isbn_issn,publisher_id,publish_year,collation,series_title,call_number,source,publish_place,classification,notes,image,...
1,"Sample Book","John Doe","1st","978-0123456789","1","2024","300p","Series 1","001.1","online","New York","Computer Science","Sample notes","cover.jpg",...
```

### Item Files (item_*.csv)
```csv
item_id,biblio_id,call_number,coll_type_id,item_code,inventory_code,received_date,supplier_id,order_no,location_id,order_date,item_status_id,site,source,invoice,price,price_currency,invoice_date,input_date,last_update,uid
1,1,"001.1","1","B001","INV001","2024-01-01","1","ORD001","1","2024-01-01","1","Main","purchase","INV001","100000","IDR","2024-01-01","2024-01-01 00:00:00","2024-01-01 00:00:00","1"
```

### User Files (user.csv)
```csv
user_id,username,realname,passwd,email,user_type,user_image,social_media,last_login,last_login_ip,groups,node_id,input_date,last_update,show_on_profile
1,"admin","Administrator","password123","admin@library.ac.id","1","","","2024-01-01 00:00:00","192.168.1.1","","1","2024-01-01 00:00:00","2024-01-01 00:00:00","1"
```

### Member Files (member_*.csv)
```csv
member_id,member_name,gender,birth_date,member_type_id,member_address,member_mail_address,member_email,postal_code,inst_name,is_new,member_image,pin,member_phone,member_fax,member_since_date,register_date,expire_date,member_notes,is_pending,...
1,"John Student","1","1995-01-01","1","Student Address","Mailing Address","john@student.ac.id","12345","University","0","","1234","+62123456789","",2024-01-01","2024-01-01","2025-01-01","Active student","0",...
```

## Features

- **Batch Processing**: Configurable batch sizes for optimal performance
- **Progress Tracking**: Real-time progress indicators during import
- **Error Handling**: Comprehensive error reporting with line numbers
- **Deduplication**: Automatic duplicate detection and skipping
- **Data Validation**: Built-in validation checks after migration
- **Flexible File Patterns**: Support for numbered files and flexible naming
- **Transaction Safety**: Database transactions for data integrity
- **Image Downloads**: Optional image downloading for bibliography records

## Validation

After migration, you can run comprehensive validation checks:

```bash
mix voile.migrate --validate
```

The validation includes:
- Master data completeness
- User count summaries by role and type
- Data integrity checks (duplicates, missing fields)
- Profile data analysis
- Sample data preview

## Troubleshooting

### Common Issues

1. **Missing CSV Files**: Ensure files are in the correct directory structure
2. **Permission Errors**: Check file permissions on CSV directories
3. **Memory Issues**: Reduce batch size for large files
4. **Database Constraints**: Ensure proper database setup and migrations

### Debug Mode

For detailed debugging, you can examine the import modules individually or add custom logging to track specific issues.

## Development

The migration system is modular with separate importers for each data type:

- `Voile.Migration.MasterImporter` - Authors and publishers
- `Voile.Migration.BiblioImporter` - Bibliography/collections
- `Voile.Migration.ItemImporter` - Physical items
- `Voile.Migration.UserImporter` - Staff users
- `Voile.Migration.MemberImporter` - Library members
- `Voile.Migration.Validator` - Post-migration validation

Each module can be extended or customized based on specific requirements.
