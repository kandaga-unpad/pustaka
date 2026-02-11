# Storage Adapter Auto-Selection

## Overview

The storage adapter is now **automatically selected at runtime** based on whether S3/MinIO credentials are available.

## How It Works

### With S3 Credentials (MinIO/S3 Storage)

If these environment variables are set:
```bash
export VOILE_S3_ACCESS_KEY_ID="your-access-key"
export VOILE_S3_SECRET_ACCESS_KEY="your-secret-key"
```

→ **Uses `Client.Storage.S3`** (MinIO/S3 storage)

### Without S3 Credentials (Local Filesystem)

If the above credentials are **NOT** set:

→ **Uses `Client.Storage.Local`** (local filesystem)

## Configuration

### Automatic Selection (Recommended)

Just set or unset the S3 credentials:

```bash
# Option 1: Use MinIO/S3
export VOILE_S3_ACCESS_KEY_ID="access-key"
export VOILE_S3_SECRET_ACCESS_KEY="secret-key"
export VOILE_S3_BUCKET_NAME="glam-storage"
export VOILE_S3_PUBLIC_URL="https://library.unpad.ac.id"

# Option 2: Use Local Storage
# Simply don't set the S3 credentials, or unset them:
unset VOILE_S3_ACCESS_KEY_ID
unset VOILE_S3_SECRET_ACCESS_KEY
```

### Manual Override (Optional)

You can explicitly set the adapter:

```bash
export VOILE_STORAGE_ADAPTER="s3"    # Force S3
export VOILE_STORAGE_ADAPTER="local" # Force Local
```

## Benefits

1. **No recompilation needed** - Switch between storage backends by changing environment variables
2. **Development friendly** - Use local storage in development without S3 setup
3. **Production ready** - Automatically uses S3/MinIO when credentials are provided
4. **Safe defaults** - Falls back to local storage if credentials are missing

## Testing

Test which adapter is active:

```bash
# With credentials
source .env
mix run -e 'IO.inspect(Application.get_env(:voile, :storage_adapter))'
# => Client.Storage.S3

# Without credentials  
unset VOILE_S3_ACCESS_KEY_ID
unset VOILE_S3_SECRET_ACCESS_KEY
mix run -e 'IO.inspect(Application.get_env(:voile, :storage_adapter))'
# => Client.Storage.Local
```

## Migration Path

### Development → Production

1. **Development** (Local storage):
   ```bash
   # .env.development
   # S3 credentials not set - uses local filesystem
   ```

2. **Production** (MinIO/S3):
   ```bash
   # .env.production
   export VOILE_S3_ACCESS_KEY_ID="prod-access-key"
   export VOILE_S3_SECRET_ACCESS_KEY="prod-secret-key"
   export VOILE_S3_BUCKET_NAME="glam-storage"
   export VOILE_S3_PUBLIC_URL="https://library.unpad.ac.id"
   ```

No code changes needed - just set the environment variables!
