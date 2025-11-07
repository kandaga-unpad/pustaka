# Environment Configuration Guide

This project supports multiple environment configurations for different use cases.

## Environment Files

### `.env.dev` - Containerized Development

Use this when running the application with **podman-compose** or **docker-compose**.

- Database hostname: `db` (container network)
- Used by: `podman-compose.yml`
- Command: `podman-compose up -d`

### `.env.local` - Local Development

Use this when running the application **directly on your machine** with `mix phx.server`.

- Database hostname: `localhost`
- Requires: PostgreSQL running locally
- Command: `source .env.local && mix phx.server`

### `.env.prod` - Production

Use this for production deployments.

- Copy from: `.env.prod.example`
- Update all values with production credentials
- Used by: `podman-compose.prod.yml`
- Command: `podman-compose -f podman-compose.prod.yml up -d`

## Usage

### Development with Containers (Recommended)

```bash
# Start development environment
podman-compose up -d

# View logs
podman logs -f voile_web_1

# Stop environment
podman-compose down

# Access database from host
# Host: localhost
# Port: 5432
# Database: voile_dev
# Username: voile
# Password: voile
```

### Local Development (Without Containers)

```bash
# Load environment variables
source .env.local

# Start PostgreSQL locally (if not already running)
# Make sure it's configured with the credentials in .env.local

# Run migrations
mix ecto.setup

# Start Phoenix server
mix phx.server
```

### Production Deployment

```bash
# 1. Copy and configure production environment
cp .env.prod.example .env.prod
# Edit .env.prod with your production values

# 2. Generate a new secret key base
mix phx.gen.secret

# 3. Update SECRET_KEY_BASE in .env.prod

# 4. Build and start production containers
podman-compose -f podman-compose.prod.yml build
podman-compose -f podman-compose.prod.yml up -d
```

## Configuration Differences

| Setting       | `.env.local` | `.env.dev`          | `.env.prod`     |
| ------------- | ------------ | ------------------- | --------------- |
| Database Host | `localhost`  | `db`                | `db`            |
| MIX_ENV       | `dev`        | `dev`               | `prod`          |
| Container     | No           | Yes                 | Yes             |
| Dockerfile    | -            | `Containerfile.dev` | `Containerfile` |

## Important Notes

1. **Never commit** `.env`, `.env.local`, `.env.dev`, or `.env.prod` files to git
2. **Always commit** `.env.*.example` files as templates
3. **Database hostname** is the key difference:
   - `localhost` for local development
   - `db` for containerized environments (dev and prod)
4. **Production** requires all secrets to be updated with real production values

## Switching Between Environments

### From Local to Container Development

```bash
# Stop local PostgreSQL (optional)
sudo systemctl stop postgresql

# Start containers
podman-compose up -d
```

### From Container to Local Development

```bash
# Stop containers
podman-compose down

# Start local PostgreSQL
sudo systemctl start postgresql

# Load local env
source .env.local && mix phx.server
```
