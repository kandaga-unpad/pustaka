# Attachment presigned URL and fallback behavior

This document explains how presigned URLs are generated for attachments and
what the application does when a presigned URL is not available.

## Overview

We support storing attachment files either locally (served from
`priv/static/uploads`) or on an S3-compatible service (AWS S3, MinIO,
Backblaze B2, etc.). To allow efficient direct downloads from S3 while
still enforcing application-level authorization we generate short-lived
presigned GET URLs.

When a user requests an attachment via the app (e.g. the e-book reader),
the app will:

- If the attachment is local (path starting with `/uploads`), stream the
  file from the local filesystem via the existing download controller.
- If the attachment references an `http(s)` URL, the app will try to
  generate a presigned URL using the configured storage adapter.
  - If a presigned URL is returned, the app redirects the client to that
    URL (the browser downloads directly from S3/MinIO). This saves server
    bandwidth.
  - If presign is not supported or fails, the app will fall back to proxying
    the file: it fetches the remote file and returns it to the client. This
    ensures compatibility but consumes server bandwidth.

## Configuration

The S3 adapter reads these config values at runtime (set them in `config/*.exs` or
via environment variables):

- `:s3_access_key_id` - S3 access key
- `:s3_secret_key_access` - S3 secret key
- `:s3_bucket_name` - S3 bucket name
- `:s3_public_url` - Public endpoint/host (e.g. `https://s3.example.com`)
- `:s3_public_url_format` - URL format, defaults to `"{endpoint}/{bucket}/{key}"`.
  - You can set `"https://{bucket}.{endpoint}/{key}"` for virtual-hosted style.

Example environment variables (for local development with MinIO):

```
VOILE_S3_ACCESS_KEY_ID=MINIO_ACCESS_KEY
VOILE_S3_SECRET_KEY_ACCESS=MINIO_SECRET_KEY
VOILE_S3_BUCKET_NAME=glam-storage
VOILE_S3_PUBLIC_URL=https://minio.local:9000
VOILE_S3_PUBLIC_URL_FORMAT={endpoint}/{bucket}/{key}
```

## TTL and security

- Presigned URLs default to 900 seconds (15 minutes). This can be changed
  by passing the `expires` option to `Client.Storage.presign/2`.
- Presigned URLs allow direct access for their TTL. The app only issues
  presigned URLs to authorized users (the e-book reader requires Admin or
  Staff member types by default), so exposure is limited.

### Example presigned URL

When the S3 adapter generates a presigned GET URL it will look similar to
the following (values shortened for readability):

```
https://my-bucket.s3.amazonaws.com/path/to/object.pdf?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=MINIOACCESS%2F20251107%2Fus-east-1%2Fs3%2Faws4_request&X-Amz-Date=20251107T120000Z&X-Amz-Expires=900&X-Amz-SignedHeaders=host&X-Amz-Signature=abcdef1234567890...
```

The important query parameters are:

- `X-Amz-Algorithm` — signing algorithm (always `AWS4-HMAC-SHA256`).
- `X-Amz-Credential` — credential scope containing access key, date, region and service.
- `X-Amz-Date` — signing timestamp.
- `X-Amz-Expires` — TTL in seconds (defaults to 900).
- `X-Amz-SignedHeaders` — headers included in the signature.
- `X-Amz-Signature` — final signature bytes.

If you use a path-style endpoint (for example with some MinIO setups) the
URL hostname may instead be the endpoint and the path includes the bucket
name, e.g. `https://minio.local:9000/my-bucket/path/to/object.pdf?...`.

### Streaming fallback behaviour

If the adapter cannot return a presigned URL the download controller will
fall back to proxying the remote file through the application. To avoid
buffering large files in memory this proxy uses a chunked HTTP response
and streams the remote body to the client as it downloads. This preserves
authorization but consumes server bandwidth and is slower than a direct
S3 download.

## Developer notes

- The presign implementation uses AWS Signature Version 4 and supports both
  path-style and virtual-hosted-style URL formats based on
  `:s3_public_url_format`.
- `Client.Storage.presign/2` delegates to the configured adapter. If the
  adapter doesn't implement presign it returns `{:error, :not_supported}`.
- The download controller will try `Client.Storage.presign/2` first and
  redirect to the presigned URL if available; otherwise it will fetch the
  remote resource and stream it back to the client.

If you want stricter auditing (log every download) or the ability to revoke
access immediately, consider proxying all downloads through the app rather
than using presigned URLs.
